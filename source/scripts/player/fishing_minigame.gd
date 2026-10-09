class_name FishingMinigame
extends Node3D
## Fishing: stand at the shore, on the pier or by the pond with a fishing rod
## and press E. Cast -> wait for a bite (the bobber bobs) -> when it dips and
## "!" shows, press E within the reaction window to hook the fish. Fish depend
## on the water (sea/pond), season, hour and weather (data/game_data.json ->
## items.*.fish). Pressing E early reels in empty; moving cancels.

enum State { IDLE, CASTING, WAITING, BITE, RESULT }

var state: State = State.IDLE
var active: bool = false
var water_kind: String = ""
var last_catch: String = ""
var catches: int = 0
var _timer: float = 0.0
var _target: Vector3
var _bobber: MeshInstance3D
var _line: MeshInstance3D
var _rod: Node3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_bobber = MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.07
	s.height = 0.14
	s.radial_segments = 10
	s.rings = 5
	_bobber.mesh = s
	_bobber.material_override = ProceduralProp.color_material(Color(0.9, 0.15, 0.12), 0.4, false)
	_bobber.top_level = true
	_bobber.visible = false
	add_child(_bobber)
	_line = MeshInstance3D.new()
	_line.top_level = true
	_line.mesh = ImmediateMesh.new()
	var lm := StandardMaterial3D.new()
	lm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lm.albedo_color = Color(0.9, 0.9, 0.9, 0.8)
	_line.material_override = lm
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_line)


## Point in front of the player where the bobber would land, and what water it is.
func _probe(player: Node3D) -> Dictionary:
	var fwd: Vector3 = player.call("facing_direction")
	for dist: float in [2.5, 3.5, 4.5]:
		var p: Vector3 = player.global_position + fwd * dist
		var sd := TownLayout.sea_distance(p.x, p.z)
		if sd > 0.6:
			var ds := Modules.style("deep_sea") as DeepSeaStyle
			var kind := "deep" if ds and sd > ds.deep_distance else "sea"
			return {"kind": kind, "point": Vector3(p.x, TownLayout.WATER_LEVEL, p.z)}
		if Vector2(p.x, p.z).distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS - 1.0:
			return {"kind": "pond", "point": Vector3(p.x, Terrain.pond_surface(), p.z)}
		if Terrain.is_river(p.x, p.z):
			return {"kind": "pond", "point": Vector3(p.x, Terrain.river_surface(p.x, p.z), p.z)}
	return {}


## Public: water in front of the player ({kind, point} or {}).
func probe_water(player: Node3D) -> Dictionary:
	return _probe(player)


func can_start(player: Node3D) -> bool:
	if active or not has_rod():
		return false
	return not _probe(player).is_empty()


## v6a: any rod works; the pro rod (fishing_gear module) bites faster and
## finds rare fish more often.
static func has_rod() -> bool:
	return Economy.has("fishing_rod") or has_pro_rod()


static func has_pro_rod() -> bool:
	var g := Modules.style("fishing_gear") as FishingGearStyle
	return g != null and Economy.has("pro_rod")


## Fishing beats far-away interactables but not ones right in front of you.
func priority_over(target: Interactable) -> bool:
	return target.global_position.distance_to(get_parent().global_position) > 1.6


func start(player: Node3D) -> void:
	var probe := _probe(player)
	if probe.is_empty():
		return
	active = true
	water_kind = probe["kind"]
	_target = probe["point"]
	state = State.CASTING
	_timer = 0.7
	_attach_rod(player)
	var visual := player.get_node_or_null(^"Visual")
	if visual is HumanoidModelVisual:
		(visual as HumanoidModelVisual).play_action(&"interact")
	GameEvents.fishing_state_changed.emit("casting")
	GameEvents.interaction_prompt_changed.emit("")


func tick(player: Node3D, delta: float) -> void:
	_timer -= delta
	var pressed := Input.is_action_just_pressed(&"interact")
	var moved := ControlInput.move_vector().length() > 0.3
	if moved or Input.is_action_just_pressed(&"jump"):
		_finish("")
		GameEvents.notification_requested.emit(Lang.tt("ماهیگیری را تمام کردی", "You stop fishing"))
		return
	match state:
		State.CASTING:
			if _timer <= 0.0:
				state = State.WAITING
				var wait: Array = GameData.data.get("fishing", {}).get("bite_wait", [2.5, 7.0])
				_timer = _rng.randf_range(float(wait[0]), float(wait[1]))
				if has_pro_rod():
					_timer *= (Modules.style("fishing_gear") as FishingGearStyle).pro_wait_mult
				_bobber.visible = true
				_bobber.global_position = _target
				Sfx.play_at(&"plop", _target, -6.0)
				GameEvents.fishing_state_changed.emit("waiting")
			else:
				# Bobber flies out along an arc.
				var t := 1.0 - _timer / 0.7
				var start_p: Vector3 = _rod_tip(player)
				_bobber.visible = true
				_bobber.global_position = start_p.lerp(_target, t) + Vector3.UP * sin(t * PI) * 1.2
		State.WAITING:
			_bobber.global_position = _target + Vector3.UP * sin(Time.get_ticks_msec() * 0.004) * 0.03
			if pressed:
				_finish("")
				GameEvents.notification_requested.emit(Lang.tt("زود بود - چیزی به قلاب نیست", "Too early - nothing on the hook"))
				return
			if _timer <= 0.0:
				state = State.BITE
				_timer = float(GameData.data.get("fishing", {}).get("reaction_window", 0.9))
				Sfx.play_at(&"splash", _target, -8.0, 1.3)
				GameEvents.fishing_state_changed.emit("bite")
				GameEvents.interaction_prompt_changed.emit(Lang.tt("!  الان E را بزن!", "!  Press E now!"))
		State.BITE:
			_bobber.global_position = _target + Vector3.DOWN * 0.12
			if pressed:
				var fish := pick_fish(water_kind)
				Sfx.play_at(&"reel", player.global_position, -6.0)
				Economy.add_item(fish, 1)
				last_catch = fish
				catches += 1
				GameEvents.item_collected.emit(fish)
				GameEvents.notification_requested.emit(Lang.tt("یک %s گرفتی! (حدود %s سکه می‌ارزد)" % [Market.local_name(fish), Lang.digits(str(Economy.sell_price(fish)))], "You caught a %s! (sells for ~%d G)" % [GameData.item_name(fish), Economy.sell_price(fish)]))
				GameEvents.fishing_state_changed.emit("caught")
				_finish(fish)
				return
			if _timer <= 0.0:
				GameEvents.notification_requested.emit(Lang.tt("در رفت...", "It got away..."))
				GameEvents.fishing_state_changed.emit("missed")
				_finish("")
				return
	_draw_line(player)


## Weighted random fish for this water type, season, hour and weather.
func pick_fish(kind: String) -> String:
	var season := TimeManager.season_id()
	var hour := TimeManager.hour()
	var weather := TimeManager.weather_id
	var pool: Array = []
	var total := 0.0
	var items := GameData.items()
	for id in items:
		var f: Dictionary = (items[id] as Dictionary).get("fish", {})
		if f.is_empty() or f.get("water") != kind:
			continue
		if season not in f.get("seasons", []):
			continue
		var hours: Array = f.get("hours", [0, 24])
		if hour < int(hours[0]) or hour >= int(hours[1]):
			continue
		var w := float(f.get("weight", 1.0))
		if has_pro_rod() and int((items[id] as Dictionary).get("sell", 0)) >= 150:
			w *= (Modules.style("fishing_gear") as FishingGearStyle).rare_bonus
		if weather not in f.get("weather", []):
			w *= 0.15
		pool.append([id, w])
		total += w
	if pool.is_empty():
		if kind == "deep":
			return "hamour" if items.has("hamour") else "sardine"
		return "sardine" if kind == "sea" else "carp"
	var r := _rng.randf() * total
	for entry in pool:
		r -= float(entry[1])
		if r <= 0.0:
			return entry[0]
	return pool[0][0]


func _finish(_fish: String) -> void:
	active = false
	state = State.IDLE
	_bobber.visible = false
	(_line.mesh as ImmediateMesh).clear_surfaces()
	if _rod:
		_rod.queue_free()
		_rod = null
	GameEvents.fishing_state_changed.emit("")


func _attach_rod(player: Node3D) -> void:
	var visual := player.get_node_or_null(^"Visual")
	var parent: Node3D = player
	if visual is HumanoidModelVisual and (visual as HumanoidModelVisual).hand_point:
		parent = (visual as HumanoidModelVisual).hand_point
	_rod = Node3D.new()
	_rod.name = "FishingRod"
	var pole := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.008
	cyl.bottom_radius = 0.018
	cyl.height = 1.9
	cyl.radial_segments = 6
	pole.mesh = cyl
	pole.material_override = ProceduralProp.color_material(Color(0.45, 0.32, 0.2), 0.6, false)
	pole.position = Vector3(0, 0.9, 0)
	_rod.add_child(pole)
	var tip := Marker3D.new()
	tip.name = "Tip"
	tip.position = Vector3(0, 1.85, 0)
	_rod.add_child(tip)
	parent.add_child(_rod)
	# Point the rod forward/up from the hand.
	_rod.rotation = Vector3(deg_to_rad(-60), 0, 0) if parent == player else Vector3(deg_to_rad(80), 0, 0)
	if parent == player:
		_rod.position = Vector3(0.25, 1.0, 0.2)


func _rod_tip(player: Node3D) -> Vector3:
	if _rod and _rod.has_node(^"Tip"):
		return (_rod.get_node(^"Tip") as Node3D).global_position
	return player.global_position + Vector3.UP * 2.0


func _draw_line(player: Node3D) -> void:
	var im := _line.mesh as ImmediateMesh
	im.clear_surfaces()
	if not _bobber.visible:
		return
	var a := _rod_tip(player)
	var b := _bobber.global_position
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	var prev := a
	for i in range(1, 9):
		var t := i / 8.0
		var p := a.lerp(b, t) + Vector3.DOWN * sin(t * PI) * 0.25
		im.surface_add_vertex(prev)
		im.surface_add_vertex(p)
		prev = p
	im.surface_end()
