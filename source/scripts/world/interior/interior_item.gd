class_name InteriorItem
extends Node3D
## Interactive furniture: TV, fridge, bed, tool rack, workbench, shop counter,
## coffee counter, reception desk, post counter, office clerk. One script,
## switched by `kind`, so new items are one match-case away.

@export var kind: String = "tv"
@export var radius: float = 1.3
## Owner building (sleeping only works in your own farmhouse).
var building: Building
## v5a: shop this counter opens ("shop_desk").
var shop_id: String = ""
var is_on: bool = false
var _glow: OmniLight3D
var _glow_timer: float = 0.0
var zone: Interactable
var _screen: MeshInstance3D
var _screen_light: OmniLight3D
var _uses_today: int = 0

const TV_SHADER := """
shader_type spatial;
render_mode unshaded;
uniform float on = 0.0;
void fragment() {
	vec2 uv = UV;
	float t = TIME * 0.6;
	vec3 sky = mix(vec3(0.25, 0.55, 0.95), vec3(0.95, 0.75, 0.45), 0.5 + 0.5 * sin(t * 0.7));
	vec3 ground = mix(vec3(0.2, 0.55, 0.25), vec3(0.35, 0.3, 0.6), 0.5 + 0.5 * sin(t * 0.4 + 1.0));
	float horizon = 0.45 + 0.08 * sin(uv.x * 9.0 + t * 2.0);
	vec3 c = uv.y < horizon ? sky : ground;
	float sun = smoothstep(0.12, 0.1, distance(uv, vec2(0.5 + 0.3 * sin(t), 0.25)));
	c = mix(c, vec3(1.0, 0.95, 0.7), sun);
	c *= 0.9 + 0.1 * sin(uv.y * 300.0 + TIME * 20.0);
	ALBEDO = mix(vec3(0.02, 0.025, 0.03), c * 1.6, on);
	EMISSION = c * 1.4 * on;
}
"""

static var _tv_shader: Shader


func _ready() -> void:
	add_to_group(&"interior_items")
	add_to_group(&"interior_" + kind)
	zone = Interactable.new()
	zone.name = "Interaction"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.position = Vector3(0, 0.9, 0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)
	add_child(zone)
	zone.interacted.connect(_on_interacted)
	zone.action_text = _action_text()
	if Engine.is_editor_hint():
		return
	TimeManager.day_started.connect(func(_d: int) -> void: _uses_today = 0)
	if kind == "tv":
		PowerGrid.power_changed.connect(func(on: bool) -> void:
			if not on and is_on:
				set_on(false))
	if kind == "stove":
		GameEvents.crafted.connect(_on_crafted)
		set_process(false)


## For the TV: the screen quad (local transform, size) built by InteriorBuilder.
func setup_screen(screen_size: Vector2, local_pos: Vector3) -> void:
	if _tv_shader == null:
		_tv_shader = Shader.new()
		_tv_shader.code = TV_SHADER
	_screen = MeshInstance3D.new()
	_screen.name = "Screen"
	var quad := QuadMesh.new()
	quad.size = screen_size
	_screen.mesh = quad
	var mat := ShaderMaterial.new()
	mat.shader = _tv_shader
	_screen.material_override = mat
	_screen.position = local_pos
	_screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_screen.set_meta(&"no_merge", true)
	add_child(_screen)
	_screen_light = OmniLight3D.new()
	_screen_light.light_color = Color(0.6, 0.75, 1.0)
	_screen_light.light_energy = 0.0
	_screen_light.omni_range = 3.5
	_screen_light.position = local_pos + Vector3(0, 0, 0.6)
	_screen_light.visible = false
	add_child(_screen_light)


func screen_emission() -> float:
	if _screen == null:
		return 0.0
	var v: Variant = (_screen.material_override as ShaderMaterial).get_shader_parameter(&"on")
	return 0.0 if v == null else float(v)


func _action_text() -> String:
	if kind.begins_with("v6_"):
		return InteriorV6a.item_text(self)
	match kind:
		"tv":
			return "turn off the TV" if is_on else "turn on the TV"
		"fridge":
			var fu := (get_meta(&"fridge_unit") if has_meta(&"fridge_unit") else null) as FridgeUnit
			if fu and is_instance_valid(fu):
				return Lang.tt("برداشتن خوراکی و بستن یخچال", "take a snack and close the fridge") if fu.is_open else Lang.tt("باز کردن یخچال", "open the fridge")
			return "have a snack from the fridge"
		"bed":
			return "sleep until morning" if building and building.sleep_here else "rest on the bed"
		"tool_rack":
			return "take tools (refill can / fishing rod)"
		"workbench":
			return "build a wooden crate"
		"shop_counter":
			return "shop at the counter"
		"coffee":
			return "buy a coffee (10 G, +stamina)"
		"reception":
			return "ask for a check-up (restores stamina)"
		"post_counter":
			return "post a letter"
		"clerk":
			return "talk to the clerk"
		# v5a
		"craft_bench":
			return "craft at the workbench"
		"stove":
			return "cook on the stove"
		"shop_desk":
			var sh := Shops.shop(shop_id)
			return "shop at the %s" % str(sh.get("title", "counter")).to_lower() if not sh.is_empty() else "shop at the counter"
		"water_desk":
			return "ask the Water Office (refill your can)"
		"power_desk":
			return "ask about the power grid"
		"teacher":
			return "talk to the teacher"
		"lecture":
			return "listen to the lecture"
		"registry":
			return "look up the town directory"
		"prayer":
			return "sit quietly for a moment"
		# v5b
		"livestock_desk":
			return "سفارش مرغدانی، طویله و خرید دام" if Lang.is_fa() else "order a coop / barn, buy animals and feed"
		"doctor":
			if Needs.is_ill():
				return "see the doctor (treat your %s: %d G)" % [Needs.illness_def(Needs.illness).display_name.to_lower(), Needs.fee_of(Needs.illness)]
			return "see the doctor (check-up)"
	return "use"


## v5b: which opening hours (shop_hours module) apply to this counter.
func hours_id() -> String:
	match kind:
		"shop_desk":
			return shop_id
		"livestock_desk":
			return "carpenter"
		"shop_counter", "coffee", "water_desk", "power_desk", "post_counter", "clerk", "registry":
			return building.layout_id if building else ""
	return ""


func _closed_check() -> bool:
	var hid := hours_id()
	if hid == "" or ShopHours.is_open(hid):
		return false
	var title := hid.capitalize()
	if kind == "shop_desk" and not Shops.shop(shop_id).is_empty():
		title = str(Shops.shop(shop_id).get("title", title))
	elif building:
		title = building.sign_text if building.sign_text != "" else title
	if Lang.is_fa():
		var st := Dialogue.style()
		var key := building.layout_id if building and kind == "shop_desk" else hid
		title = str(st.places_fa.get(key, st.places_fa.get(hid, "اینجا"))) if st else title
	GameEvents.notification_requested.emit(ShopHours.closed_message(hid, title))
	return true


func _on_interacted(who: Node3D) -> void:
	if _closed_check():
		return
	if kind.begins_with("v6_"):
		InteriorV6a.item_use(self, who)
		return
	match kind:
		"tv":
			if not is_on and not PowerGrid.power_on:
				GameEvents.notification_requested.emit(Lang.tt("برق نیست - تلویزیون روشن نمی‌شود (کلید اصلی در خانه‌ی مزرعه است)", "No power - the TV won't turn on (main switch at the farmhouse)"))
			else:
				set_on(not is_on)
		"fridge":
			var fu := (get_meta(&"fridge_unit") if has_meta(&"fridge_unit") else null) as FridgeUnit
			if fu and is_instance_valid(fu) and not fu.is_open:
				fu.open_door()
				GameEvents.notification_requested.emit(fu.contents_text())
				return
			if fu and is_instance_valid(fu):
				fu.close_door()
			_restore(who, 25.0, "A crisp apple from the fridge. +25 stamina")
			Needs.eat(8.0, false)
		"bed":
			if building and building.sleep_here:
				if who.has_method("restore_stamina"):
					who.call("restore_stamina", 1000.0)
				# v5b: sleeping resets fatigue (Needs).
				Needs.begin_sleep()
				TimeManager.sleep_until_morning(6.0)
				Needs.end_sleep()
				GameEvents.notification_requested.emit("Good morning! %s, %s" % [TimeManager.date_text(), TimeManager.weather_name()])
			else:
				_restore(who, 40.0, "You rest for a moment. +40 stamina")
				Needs.fatigue = maxf(Needs.fatigue - 10.0, 0.0)
		"tool_rack":
			_tool_rack()
		"workbench":
			_workbench()
		"shop_counter":
			GameEvents.shop_requested.emit()
		"coffee":
			if Economy.money >= 10:
				Economy.add_money(-10)
				_restore(who, 50.0, "Fresh coffee! +50 stamina")
			else:
				GameEvents.notification_requested.emit("Not enough money for coffee")
		"reception":
			_restore(who, 100.0, "\"You look healthy!\" Stamina fully restored")
		"post_counter":
			GameEvents.notification_requested.emit("Letter posted. The clerk smiles.")
		"clerk":
			GameEvents.notification_requested.emit(["\"Welcome to City Hall!\"", "\"The mayor is busy, sorry.\"", "\"Fill in form 27B, please.\""][randi() % 3])
		# v5a
		"craft_bench":
			GameEvents.crafting_requested.emit("workbench")
		"stove":
			# v5b: hands-on cooking (CookingPanel); quick v5a recipes from there.
			GameEvents.cooking_requested.emit(self)
		"doctor":
			GameEvents.notification_requested.emit(Needs.treat_player())
			Sfx.play(&"pickup", -10.0, 1.3)
		"shop_desk":
			GameEvents.shop_requested_for.emit(shop_id)
		"livestock_desk":
			GameEvents.ui_panel_requested.emit("livestock")
		"water_desk":
			Economy.refill_can()
			GameEvents.notification_requested.emit("\"Clean water for the whole town.\" Your watering can is full (%d/%d)" % [Economy.water, Economy.can_capacity()])
		"power_desk":
			_power_desk()
		"teacher":
			GameEvents.notification_requested.emit(_desk_line("school", "\"Class is in session!\""))
		"lecture":
			_restore(who, 10.0, _desk_line("university", "\"Today's lecture: soil chemistry.\"") + " +10 stamina")
		"registry":
			GameEvents.ui_panel_requested.emit("people")
		"prayer":
			_restore(who, 20.0, "A quiet, peaceful moment. +20 stamina")
	zone.set_action_text(_action_text())


func _desk_line(desk: String, fallback: String) -> String:
	var cs := Modules.style("civic") as CivicStyle
	if cs and cs.desks.has(desk):
		var lines: Array = (cs.desks[desk] as Dictionary).get("lines", [])
		if not lines.is_empty():
			return "\"%s\"" % str(lines[randi() % lines.size()])
	return fallback


## Electricity office (ties to the v4 electricity module): reports the grid
## and switches the town power back on after a cut.
func _power_desk() -> void:
	var homes := get_tree().get_nodes_in_group(&"buildings").size()
	if not PowerGrid.power_on:
		PowerGrid.set_power(true)
		GameEvents.notification_requested.emit("\"Outage fixed - the grid is back on.\" %d buildings powered" % homes)
	else:
		GameEvents.notification_requested.emit("\"The grid is humming.\" %d buildings powered%s" % [homes,
				"" if (Modules.style("kitchen") as KitchenStyle) == null or not (Modules.style("kitchen") as KitchenStyle).needs_power() else ", electric stoves on"])


func _on_crafted(recipe_id: String) -> void:
	var r := GameData.recipes.get(recipe_id) as RecipeDef
	if r == null or r.station != "stove":
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or player.global_position.distance_to(global_position) > 3.0:
		return
	if _glow == null:
		_glow = OmniLight3D.new()
		_glow.light_color = Color(1.0, 0.45, 0.15)
		_glow.omni_range = 2.2
		_glow.shadow_enabled = false
		_glow.position = Vector3(0, 1.0, -0.55)
		add_child(_glow)
	_glow.light_energy = 1.4
	_glow.visible = true
	_glow_timer = 4.0
	set_process(true)


func _process(delta: float) -> void:
	if _glow == null:
		set_process(false)
		return
	_glow_timer -= delta
	_glow.light_energy = 1.2 + 0.3 * sin(Time.get_ticks_msec() * 0.02)
	if _glow_timer <= 0.0:
		_glow.visible = false
		set_process(false)


func set_on(value: bool) -> void:
	is_on = value
	if _screen:
		(_screen.material_override as ShaderMaterial).set_shader_parameter(&"on", 1.0 if value else 0.0)
		_screen_light.visible = value
		_screen_light.light_energy = 0.8 if value else 0.0
	zone.set_action_text(_action_text())


func _restore(who: Node3D, amount: float, message: String) -> void:
	if who.has_method("restore_stamina"):
		who.call("restore_stamina", amount)
	GameEvents.notification_requested.emit(Lang.loc(message))


func _tool_rack() -> void:
	var msgs: PackedStringArray = []
	if Economy.has("watering_can"):
		Economy.refill_can()
		msgs.append("Watering can refilled")
	if not Economy.has("fishing_rod") and building and building.sleep_here:
		Economy.add_item("fishing_rod", 1)
		msgs.append("took the old fishing rod")
	if not Economy.has("hoe"):
		Economy.add_item("hoe", 1)
		msgs.append("took a hoe")
	GameEvents.notification_requested.emit(", ".join(msgs) if not msgs.is_empty() else "Nothing to take")


func _workbench() -> void:
	if _uses_today >= 3:
		GameEvents.notification_requested.emit("You're out of planks for today")
		return
	_uses_today += 1
	var crate := Carryable.make_crate()
	get_tree().current_scene.add_child(crate)
	crate.global_position = global_position + global_basis.z * 1.0 + Vector3(0, 0.05, 0)
	GameEvents.notification_requested.emit("Built a wooden crate - press E to pick it up")
