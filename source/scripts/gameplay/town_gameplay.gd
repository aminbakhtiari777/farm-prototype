extends Node
## Shared, saved household interactions and the player's contextual actions.

var panel: PanelContainer
var rows: VBoxContainer
var _fridge: FridgeUnit
var _scene: Node
var _attack_cooldown: float = 0.0
var _hurt: Array = []
var _sleeping: bool = false
var _held_tween: Tween
var _held: Node3D
var island: Node3D
const ISLAND := Vector3(132, 0.8, 108)
const ISLAND_DOCK := Vector3(132, TownLayout.WATER_LEVEL + 0.15, 89)
const FRUITS := {"mango": ["Mango", "انبه", Color(1, 0.55, 0.08), 95], "guava": ["Guava", "گواوا", Color(0.45, 0.85, 0.2), 85], "coconut": ["Coconut", "نارگیل", Color(0.44, 0.28, 0.12), 110]}

func _ready() -> void:
	for action in {"attack": KEY_Y, "door_lock": KEY_SEMICOLON, "boat_menu": KEY_BACKSLASH, "use_tool": KEY_APOSTROPHE, "sleep_now": KEY_F8, "bag_actions": KEY_0}:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var event := InputEventKey.new()
			event.physical_keycode = {"attack": KEY_Y, "door_lock": KEY_SEMICOLON, "boat_menu": KEY_BACKSLASH, "use_tool": KEY_APOSTROPHE, "sleep_now": KEY_F8, "bag_actions": KEY_0}[action]
			InputMap.action_add_event(action, event)
	_register_items()
	GameEvents.ui_closed.connect(func() -> void:
		if is_instance_valid(panel):
			panel.visible = false
		_fridge = null)
	AssetRegistry.module_changed.connect(func(_kind: String, _module: AssetModule) -> void: _register_items.call_deferred())

func _register_items() -> void:
	for id in FRUITS:
		var entry: Array = FRUITS[id]
		GameData.data["items"][id] = {"name": entry[0], "name_fa": entry[1], "type": "produce", "category": "fruit", "sell": entry[3]}
	GameData.data["items"]["fishing_net"] = {"name": "Fishing net", "name_fa": "تور ماهیگیری", "type": "tool", "buy": 180}
	GameData.data["items"]["spade"] = {"name": "Spade", "name_fa": "بیل", "type": "tool", "buy": 90, "tool_kind": "hoe"}
	GameData.data["items"]["pickaxe"] = {"name": "Pickaxe", "name_fa": "کلنگ", "type": "tool", "buy": 140, "tool_kind": "hoe"}

func attach_world(scene: Node) -> void:
	_scene = scene
	_register_items()
	var layer := CanvasLayer.new()
	layer.layer = 20
	scene.add_child(layer)
	panel = PanelContainer.new()
	panel.name = "ContextActions"
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -190
	panel.offset_right = 190
	panel.offset_top = -190
	panel.offset_bottom = 190
	panel.add_theme_stylebox_override(&"panel", UIKit.style(UIKit.PAPER, 12, 14, true))
	layer.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(360, 330)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	rows = VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override(&"separation", 8)
	scroll.add_child(rows)
	panel.visible = false
	island = null
	_hurt.clear()
	_sleeping = false
	# The island is constructed only when a voyage actually needs it.

func player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player

func nearest_door() -> BuildingDoor:
	var p := player()
	if p == null:
		return null
	var best: BuildingDoor
	var distance := 2.8
	for node in get_tree().get_nodes_in_group(&"doors"):
		var door := node as BuildingDoor
		if door and door.get_parent() is Building:
			var d := door.global_position.distance_to(p.global_position)
			if d < distance:
				distance = d
				best = door
	return best

func lock_nearest() -> bool:
	var door := nearest_door()
	if door == null:
		return false
	var home := door.get_parent() as Building
	if not home.sleep_here:
		GameEvents.notification_requested.emit(Lang.tt("کلید این ساختمان را نداری.", "You do not have this building's key."))
		return false
	door.set_locked(not door.locked)
	GameEvents.notification_requested.emit(Lang.tt("در قفل شد." if door.locked else "قفل باز شد.", "Door locked." if door.locked else "Door unlocked."))
	return true

func _begin(title: String) -> void:
	if not is_instance_valid(panel):
		return
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	UIKit.label(rows, title, 20, UIKit.INK)
	UIKit.button(rows, Lang.tt("بستن", "Close"), close)
	panel.visible = true
	GameEvents.open_modal("context_actions")

func close() -> void:
	if is_instance_valid(panel):
		panel.visible = false
	_fridge = null
	GameEvents.close_modal("context_actions")

func open_fridge(fridge: FridgeUnit) -> void:
	_begin(Lang.tt("یخچال · مواد خوراکی خانه", "Fridge · household groceries"))
	_fridge = fridge
	var home := fridge.building.layout_id
	var stock := Economy.pantry(home)
	for id in stock:
		var key := str(id)
		if int(stock[id]) <= 0:
			continue
		UIKit.label(rows, "%s × %s" % [Market.local_name(key), Lang.digits(str(stock[id]))], 15, UIKit.INK)
		UIKit.button(rows, Lang.tt("برداشتن یکی", "Take one"), func() -> void: transfer_food(home, key, false); open_fridge(fridge))
		UIKit.button(rows, Lang.tt("خوردن یکی", "Eat one"), func() -> void: eat_food(key, home); open_fridge(fridge))
	for id in Economy.inventory:
		var key := str(id)
		if _edible(key) and Economy.count(key) > 0:
			UIKit.button(rows, Lang.tt("گذاشتن در یخچال: ", "Store: ") + Market.local_name(key), func() -> void: transfer_food(home, key, true); open_fridge(fridge))

func _edible(id: String) -> bool:
	var data := GameData.item(id)
	return str(data.get("type", "")) in ["ingredient", "food", "animal_product"] or str(data.get("category", "")) in ["fruit", "crop", "fish"] or id in FRUITS or id in ["apple", "banana_fruit", "strawberry", "orange", "pomegranate", "fig", "tomato", "potato", "rice"]

func transfer_food(home: String, id: String, storing: bool) -> bool:
	var stock := Economy.pantry(home)
	if storing:
		if not Economy.remove_item(id, 1):
			return false
		stock[id] = int(stock.get(id, 0)) + 1
	else:
		if int(stock.get(id, 0)) <= 0:
			return false
		stock[id] = int(stock[id]) - 1
		Economy.add_item(id, 1)
	animate_hands("place" if storing else "pickup", id)
	if is_instance_valid(_fridge):
		_fridge.refresh_contents()
	return true

func eat_food(id: String, home: String = "") -> bool:
	if not _edible(id):
		return false
	if home != "":
		var stock := Economy.pantry(home)
		if int(stock.get(id, 0)) <= 0:
			return false
		stock[id] = int(stock[id]) - 1
	elif not Economy.remove_item(id, 1):
		return false
	Needs.eat(18.0, false)
	var p := player()
	if p:
		p.restore_stamina(12.0)
	animate_hands("eat", id)
	return true

func animate_hands(action: String, id: String = "") -> void:
	var p := player()
	if p == null:
		return
	var visual := p.get_node_or_null(^"Visual") as HumanoidModelVisual
	if visual == null or not is_instance_valid(visual.hand_point):
		return
	if _held_tween and _held_tween.is_valid():
		_held_tween.kill()
	if is_instance_valid(_held):
		_held.queue_free()
	_held = Node3D.new()
	visual.hand_point.add_child(_held)
	V7aKit.box(_held, Vector3(0.11, 0.1, 0.1), Vector3.ZERO, ProceduralProp.color_material(FRUITS[id][2] if FRUITS.has(id) else Color(0.8, 0.6, 0.25), 0.7), false)
	visual.play_action(&"pickup" if action == "pickup" else &"interact")
	_held_tween = create_tween().bind_node(_held)
	_held_tween.tween_property(_held, "position", Vector3(0, 0.08, -0.08), 0.35).set_trans(Tween.TRANS_SINE)
	_held_tween.tween_interval(0.4)
	_held_tween.tween_property(_held, "position", Vector3(0, -0.08, 0.05), 0.35).set_trans(Tween.TRANS_SINE)
	_held_tween.tween_callback(func() -> void: if is_instance_valid(_held): _held.queue_free())

func open_bag() -> void:
	_begin(Lang.tt("کیف · ابزار و خوراکی", "Bag · tools and food"))
	for id in Economy.inventory.keys():
		var key := str(id)
		if Economy.item_type(key) == "tool":
			UIKit.button(rows, GameData.item_name(key) + (" ✓" if Economy.equipped_tool == key else ""), func() -> void: Economy.equipped_tool = key; close(); use_tool())
		elif _edible(key):
			UIKit.button(rows, "%s × %d · %s" % [Market.local_name(key), Economy.count(key), Lang.tt("خوردن", "Eat")], func() -> void: eat_food(key); open_bag())
		else:
			UIKit.label(rows, "%s × %d" % [GameData.item_name(key), Economy.count(key)], 14, UIKit.INK)

func use_tool() -> bool:
	var p := player()
	if p == null or not Economy.has(Economy.equipped_tool):
		return false
	var id := Economy.equipped_tool
	if id == "fishing_net":
		return cast_net()
	if id in ["spade", "pickaxe"]:
		var digger := _scene.find_child("Digging", true, false)
		if digger:
			digger.call("dig_at", p.global_position + p.facing_direction(), p)
			return true
	var tool := GameData.tools.get(id) as ToolDef
	if tool:
		p.play_tool(tool.kind)
		p._handle_interact()
		return true
	return false

func sleep_in(bed: InteriorItem, who: Node3D) -> bool:
	if _sleeping or bed.building == null or not bed.building.sleep_here:
		return false
	_sleeping = true
	if who.has_method("restore_stamina"):
		who.call("restore_stamina", 1000.0)
	Needs.begin_sleep()
	TimeManager.sleep_until_morning(6.0)
	Needs.end_sleep()
	GameEvents.notification_requested.emit(Lang.tt("صبح بخیر! روز %s · ساعت ۶" % Lang.digits(str(TimeManager.day)), "Good morning! Day %d · 06:00" % TimeManager.day))
	var curtain := ColorRect.new()
	curtain.color = Color(0.03, 0.04, 0.06, 0)
	curtain.mouse_filter = Control.MOUSE_FILTER_IGNORE
	curtain.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.get_parent().add_child(curtain)
	var tween := create_tween()
	tween.tween_property(curtain, "color:a", 0.95, 0.3)
	tween.tween_interval(0.45)
	tween.tween_property(curtain, "color:a", 0.0, 0.7)
	tween.tween_callback(func() -> void: curtain.queue_free(); _sleeping = false)
	return true

func attack() -> bool:
	var p := player()
	if p == null or p.vehicle or _attack_cooldown > 0.0:
		return false
	var victim: TownspersonBot
	var nearest := 1.8
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var bot := n as TownspersonBot
		if bot.hidden_inside or int(bot.resident.get("age", 30)) < 18 or bot.controller is HitReactController:
			continue
		var offset := bot.global_position - p.global_position
		offset.y = 0
		if offset.length() < nearest and p.facing_direction().dot(offset.normalized()) > 0.45:
			victim = bot
			nearest = offset.length()
	if victim == null:
		return false
	_attack_cooldown = 0.8
	var reaction := HitReactController.new()
	reaction.original = victim.controller
	reaction.push_dir = (victim.global_position - p.global_position).normalized()
	reaction.hold = 2.5
	reaction.mode = "fall" if int(victim.get_meta(&"injury", 0)) >= 2 else "stumble"
	victim.set_meta(&"injury", int(victim.get_meta(&"injury", 0)) + 1)
	victim.set_controller(reaction)
	_hurt.append([victim, reaction])
	Friendship.add_points(Friendship.key_of(victim), -20)
	WorldMemory.file_report("assault", victim.display_name, str(victim.resident.get("home", "")), 100)
	victim.say(Lang.tt("دست نگه دار!", "Stop!"), 2.0)
	var visual := p.get_node_or_null(^"Visual") as HumanoidModelVisual
	if visual:
		visual.play_action(&"attack")
	var wound := MeshInstance3D.new()
	var patch := SphereMesh.new()
	patch.radius = 0.045
	patch.height = 0.065
	patch.radial_segments = 6
	patch.rings = 3
	wound.mesh = patch
	wound.material_override = ProceduralProp.color_material(Color(0.48, 0.03, 0.025), 0.9, false)
	wound.position = Vector3(0.13, 1.2, 0.19)
	wound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	victim.visual.add_child(wound)
	var heal := create_tween().bind_node(wound)
	heal.tween_interval(25.0)
	heal.tween_callback(func() -> void: if is_instance_valid(wound): wound.queue_free())
	return true

func _process(delta: float) -> void:
	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)
	for hit in _hurt.duplicate():
		var bot: TownspersonBot = hit[0]
		var reaction: HitReactController = hit[1]
		if not is_instance_valid(bot):
			_hurt.erase(hit)
		elif reaction.finished:
			if bot.controller == reaction:
				bot.set_controller(reaction.original)
			_hurt.erase(hit)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not is_instance_valid(_scene):
		return
	if is_instance_valid(panel) and panel.visible:
		if event.is_action_pressed(&"menu") or event.is_action_pressed(&"interact"):
			close()
			get_viewport().set_input_as_handled()
		return
	if GameEvents.ui_open:
		return
	var handled := false
	if event.is_action_pressed(&"bag_actions"):
		open_bag()
		handled = true
	elif event.is_action_pressed(&"attack"):
		handled = attack()
	elif event.is_action_pressed(&"door_lock"):
		handled = lock_nearest()
	elif event.is_action_pressed(&"boat_menu"):
		handled = open_boat_menu()
	elif event.is_action_pressed(&"use_tool"):
		handled = use_tool()
	elif event.is_action_pressed(&"sleep_now"):
		var p := player()
		for bed in get_tree().get_nodes_in_group(&"interior_bed"):
			if p and (bed as Node3D).global_position.distance_to(p.global_position) < 3.0:
				(bed as InteriorItem)._on_interacted(p)
				handled = true
				break
	if handled:
		get_viewport().set_input_as_handled()

func open_boat_menu() -> bool:
	var p := player()
	if p == null:
		return false
	var boat: FishingBoat
	for n in get_tree().get_nodes_in_group(&"fishing_boats"):
		var candidate := n as FishingBoat
		if candidate.passenger == p or p.global_position.distance_to(candidate.board_point) < 4.0:
			boat = candidate
			break
	if boat == null:
		return false
	_begin(Lang.tt("قایق · مقصد و ماهیگیری", "Boat · destination and fishing"))
	if boat.state == FishingBoat.State.DOCKED:
		UIKit.button(rows, Lang.tt("روشن کردن موتور · آب عمیق", "Start engine · deep water"), func() -> void: close(); boat.island_trip = false; boat.board(p))
		UIKit.button(rows, Lang.tt("روشن کردن موتور · جزیرهٔ میوه", "Start engine · fruit island"), func() -> void: close(); boat.island_trip = true; boat.board(p))
	elif boat.state == FishingBoat.State.AT_SEA:
		UIKit.button(rows, Lang.tt("تور انداختن", "Cast fishing net"), func() -> void: close(); cast_net())
		UIKit.button(rows, Lang.tt("روشن کردن موتور · بازگشت", "Start engine · return"), func() -> void: close(); boat.helm(p))
	return true

func cast_net() -> bool:
	if not Economy.has("fishing_net"):
		GameEvents.notification_requested.emit(Lang.tt("تور را از ابزارفروشی بخر.", "Buy a net from the tool shop."))
		return false
	var p := player()
	var boat: FishingBoat
	for n in get_tree().get_nodes_in_group(&"fishing_boats"):
		if (n as FishingBoat).passenger == p:
			boat = n
	if boat == null or boat.state != FishingBoat.State.AT_SEA or boat.island_trip or TimeManager.weather_id == "storm":
		return false
	var last := int(boat.get_meta(&"net_last", -999))
	var now := TimeManager.day * 1440 + int(TimeManager.minutes)
	if now - last < 60:
		GameEvents.notification_requested.emit(Lang.tt("تور را دوباره بعد از یک ساعت بینداز.", "Cast again after one hour."))
		return false
	boat.set_meta(&"net_last", now)
	animate_hands("place", "fishing_net")
	var net := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(3.2, 3.2)
	net.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.75, 0.75, 0.63, 0.5)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	net.material_override = mat
	boat.add_child(net)
	net.position = Vector3(3.2, 0.2, 0)
	var tween := create_tween().bind_node(net)
	tween.tween_property(net, "position:y", -0.2, 0.8)
	tween.tween_interval(1.5)
	tween.tween_property(net, "position:y", 0.4, 0.8)
	tween.tween_callback(func() -> void:
		Economy.add_item("hamour", 2)
		Economy.add_item("black_pomfret", 1)
		TimeManager.advance_minutes(60.0)
		net.queue_free()
		GameEvents.notification_requested.emit(Lang.tt("۳ ماهی در تور؛ می‌توانی در هایپرمارکت بفروشی.", "Three fish in the net; sell them at the hypermarket.")))
	return true

func _build_island() -> void:
	if not is_instance_valid(_scene):
		return
	island = Node3D.new()
	island.name = "FruitIsland"
	island.position = ISLAND
	_scene.add_child(island)
	var ground := CylinderMesh.new()
	ground.top_radius = 17
	ground.bottom_radius = 20
	ground.height = 2.0
	ground.radial_segments = 24
	var land := MeshInstance3D.new()
	land.mesh = ground
	land.material_override = ProceduralProp.color_material(Color(0.5, 0.58, 0.25), 0.95, false)
	island.add_child(land)
	var body := StaticBody3D.new()
	island.add_child(body)
	var shape := CollisionShape3D.new()
	var cylinder := CylinderShape3D.new()
	cylinder.radius = 17
	cylinder.height = 2.0
	shape.shape = cylinder
	body.add_child(shape)
	var i := 0
	for fruit in FRUITS:
		var key := str(fruit)
		var tree := Node3D.new()
		tree.position = Vector3(-7 + i * 7, 1.0, -1 + (i % 2) * 5)
		island.add_child(tree)
		V7aKit.box(tree, Vector3(0.3, 2.5, 0.3), Vector3(0, 1.25, 0), ProceduralProp.color_material(Color(0.4, 0.27, 0.15), 0.9), false)
		for k in 4:
			V7aKit.box(tree, Vector3(1.8, 0.6, 1.3), Vector3(sin(k * PI * 0.5), 2.7 + k * 0.08, cos(k * PI * 0.5)), ProceduralProp.color_material(Color(0.2, 0.48, 0.2), 0.9), false)
		ActionSpot.make(tree, Vector3(0, 0, 1.2), 1.5, func() -> String: return Lang.tt("چیدن ", "Pick ") + str(FRUITS[key][1 if Lang.is_fa() else 0]), func(_who: Node3D) -> void: pick_island_fruit(key))
		i += 1
	ActionSpot.make(island, Vector3(0, 1.0, -14), 2.0, func() -> String: return Lang.tt("بازگشت با قایق", "Return by boat"), func(_who: Node3D) -> void: open_boat_menu())
	var marker := Label3D.new()
	Lang.setup_label3d(marker)
	marker.text = Lang.tt("جزیرهٔ میوه", "Fruit island")
	marker.position = Vector3(0, 3.0, -13)
	marker.font_size = 32
	marker.visibility_range_end = 25
	island.add_child(marker)

func pick_island_fruit(id: String) -> bool:
	var key := "island:" + id
	var record: Dictionary = WorldMemory.fruit.get(key, {})
	if int(record.get("day", -999)) + 3 > TimeManager.day:
		GameEvents.notification_requested.emit(Lang.tt("میوه‌ها سه روز دیگر می‌رسند.", "Fruit ripens again in three days."))
		return false
	WorldMemory.fruit[key] = {"day": TimeManager.day}
	Economy.add_item(id, 4)
	animate_hands("pickup", id)
	GameEvents.notification_requested.emit(Lang.tt("۴ میوه چیدی؛ از کیف بخور یا به میوه‌فروشی بفروش.", "Picked four fruits; eat from the bag or sell at the fruit shop."))
	return true


func near_adult() -> bool:
	var p := player()
	if p == null:
		return false
	for bot in get_tree().get_nodes_in_group(&"townspeople"):
		if int((bot as TownspersonBot).resident.get("age", 0)) >= 18 and not (bot as TownspersonBot).hidden_inside and (bot as Node3D).global_position.distance_to(p.global_position) < 2.0:
			return true
	return false

func near_bed() -> bool:
	var p := player()
	if p:
		for bed in get_tree().get_nodes_in_group(&"interior_bed"):
			if (bed as Node3D).global_position.distance_to(p.global_position) < 3.0:
				return true
	return false

func near_boat() -> bool:
	var p := player()
	if p:
		for boat in get_tree().get_nodes_in_group(&"fishing_boats"):
			if (boat as FishingBoat).passenger == p or (boat as FishingBoat).board_point.distance_to(p.global_position) < 4.0:
				return true
	return false
