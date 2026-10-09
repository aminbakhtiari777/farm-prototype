extends "res://scripts/tools/dev_shots.gd"
## v7b.1 visual screenshots (reuses the DevShots staging helpers):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --vis-shots=/workspace/farm-v7b1 [--only=cars,car-front]

const VIS_SHOTS: Array[String] = ["cars", "car-front", "street-cars", "fire-truck", "faces", "plaque", "plants",
	"city-hall", "minimap-home", "families"]

var _cam: Camera3D
var _temp: Array[Node] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prefix = "/workspace/farm-v7b1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--vis-shots="):
			_prefix = arg.substr(12)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
	_run_vis.call_deferred()


func _run_vis() -> void:
	await _frames(20)
	if not _find():
		push_error("VisualShots: scene actors missing")
		get_tree().quit(1)
		return
	Settings.set_value("dialogue_language", "fa")
	Settings.set_value("prompts", false)
	for shot in VIS_SHOTS:
		if not _want(shot):
			continue
		_clean_ui()
		_rig.target_offset = Vector3.ZERO
		await call("_vis_" + shot.replace("-", "_"))
		_restore()
	print("VISUAL SHOTS DONE")
	get_tree().quit(0)


## A free camera looking from `from` at `at` (made current until _restore).
func _look(from: Vector3, at: Vector3, fov: float = 60.0) -> void:
	if _cam == null:
		_cam = Camera3D.new()
		_cam.name = "VisShotCam"
		get_tree().current_scene.add_child(_cam)
	_cam.fov = fov
	_cam.global_position = from
	_cam.look_at(at, Vector3.UP)
	_cam.make_current()


func _restore() -> void:
	for n in _temp:
		if is_instance_valid(n):
			n.queue_free()
	_temp.clear()
	if _cam:
		_cam.clear_current()
	for r in get_tree().get_nodes_in_group(&"car_roof"):
		(r as Node3D).visible = true


func _hide_hud(on: bool) -> void:
	if _hud is CanvasLayer:
		(_hud as CanvasLayer).visible = not on
	elif _hud is CanvasItem:
		(_hud as CanvasItem).visible = not on


func _model(kind: String, at: Vector3, yaw: float, paint: int = -1) -> Node3D:
	var r := CarBody.build(kind, -1.0, paint)
	var h := r[0] as Node3D
	var holder := Node3D.new()
	holder.add_child(h)
	get_tree().current_scene.add_child(holder)
	holder.global_position = at
	holder.rotation.y = yaw
	_temp.append(holder)
	return h


func _ground(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z), z)


# ------------------------------------------------------------------ shots
func _vis_cars() -> void:
	_time(3, 11.0)
	var c := _ground(14.0, -40.0)
	_place(Vector2(c.x - 6.0, c.z + 4.0), 0.0)
	# Face +Z so local +X (driver side) is world +X; look in over the door at the wheel.
	var m := _model("sedan", c, 0.0, 3)
	_hide_hud(true)
	for r in m.find_children("*", "", true, false):
		if r.is_in_group(&"car_roof"):
			(r as Node3D).visible = false
	var sw := m.find_child("SteeringWheel", true, false) as SteeringWheel
	await _frames(10)
	if sw:
		sw.set_process(false)
		sw.set_amount(0.6)
	var holder := m.get_parent() as Node3D
	var eye := holder.global_transform * Vector3(2.15, 1.55, 0.15)
	var look := holder.global_transform * Vector3(0.05, 0.95, 0.45)
	_look(eye, look, 55.0)
	await _frames(20)
	await _capture("cars")
	_hide_hud(false)


func _vis_car_front() -> void:
	_time(3, 10.5)
	var c := _ground(14.0, -40.0)
	_place(Vector2(c.x - 8.0, c.z + 6.0), 0.0)
	var m := _model("sedan", c, 0.0, 4)
	var holder := m.get_parent() as Node3D
	_hide_hud(true)
	_look(holder.global_transform * Vector3(-1.7, 1.15, 4.4), holder.global_transform * Vector3(0, 0.6, 1.4), 50.0)
	await _frames(20)
	await _capture("car-front")
	_hide_hud(false)


func _vis_street_cars() -> void:
	_time(3, 10.0)
	var z := -50.0 - 3.9
	var kinds := ["sedan", "sedan", "taxi", "suv", "sedan", "police", "hatch", "sedan", "van", "sedan"]
	for i in kinds.size():
		var x := 20.0 + i * 5.6
		_model(kinds[i], _ground(x, z if i % 2 == 0 else -50.0 + 3.9), PI * 0.5 if i % 2 == 0 else -PI * 0.5, i)
	_place(Vector2(16.0, -43.5), 90.0)
	_hide_hud(true)
	_look(_ground(14.0, -47.0) + Vector3(0, 4.2, 0), _ground(36.0, -51.0) + Vector3(0, 0.6, 0), 62.0)
	await _frames(30)
	await _capture("street-cars")
	_hide_hud(false)


func _vis_fire_truck() -> void:
	_time(3, 17.5)
	var w := get_tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld
	if w == null or w.fire == null or w.fire.truck == null:
		return
	var t := w.fire.truck
	t.set_flashing(true)
	var p := t.global_position
	_place(Vector2(p.x + 7.0, p.z + 7.0), 0.0)
	_hide_hud(true)
	var f := t.global_transform.basis.z
	var side := t.global_transform.basis.x
	_look(p + f * 7.0 + side * 5.0 + Vector3(0, 2.6, 0), p + Vector3(0, 1.4, 0) + f * 0.5, 58.0)
	await _frames(30)
	await _capture("fire-truck")
	t.set_flashing(false)
	_hide_hud(false)


func _vis_faces() -> void:
	_time(3, 11.0)
	var base := _ground(-20.0, -40.0)
	_place(Vector2(base.x, base.z + 6.0), 180.0)
	var picks := ["Mina", "Reza", "Leila", "Parvin", "Hooshang", "Nasrin", "Kamran", "Amina", "Shirin", "Bahram"]
	var bots: Array = []
	for nm in picks:
		for b in V7aKit.bots(get_tree()):
			if b.display_name == nm:
				bots.append(b)
	var i := 0
	for b: TownspersonBot in bots:
		var sc := V7aKit.ScriptController.new()
		sc.original = b.controller
		sc.tag = "shot"
		var x := base.x - 4.05 + i * 0.9
		b.set_controller(sc)
		b.global_position = _ground(x, base.z + (0.0 if i % 2 == 0 else 0.15))
		sc.target = b.global_position
		sc.face_to = b.global_position + Vector3(0, 0, 5)
		b.visual.rotation.y = 0.0
		i += 1
	_hide_hud(true)
	await _frames(40)
	_look(base + Vector3(0, 1.62, 3.3), base + Vector3(0, 1.4, 0), 64.0)
	await _frames(20)
	await _capture("faces")
	for b: TownspersonBot in bots:
		var sc := b.controller as V7aKit.ScriptController
		if sc:
			b.set_controller(sc.original)
			b.snap_to_schedule()
	_hide_hud(false)


func _vis_plaque() -> void:
	_time(3, 10.5)
	var b := _town.buildings.get("maple3") as Building
	if b == null:
		return
	var dp := b.door_world_position(2.6)
	_place(Vector2(dp.x, dp.z) + Vector2(3, 3), 0.0)
	_hide_hud(true)
	var at := b.global_transform * Vector3(b.door_offset + 1.0, Building.FOUNDATION_HEIGHT + 1.6, b.size.z * 0.5)
	var from := b.global_transform * Vector3(b.door_offset + 0.3, Building.FOUNDATION_HEIGHT + 1.7, b.size.z * 0.5 + 2.6)
	_look(from, at, 55.0)
	await _frames(30)
	await _capture("plaque")
	_hide_hud(false)


func _vis_plants() -> void:
	_time(3, 10.0)
	_place(Vector2(-3.0, -95.0), 0.0)
	_hide_hud(true)
	_look(_ground(-8.0, -95.5) + Vector3(0, 3.0, 0), _ground(-36.0, -90.0) + Vector3(0, 1.2, 0), 64.0)
	await _frames(30)
	await _capture("plants")
	_hide_hud(false)


func _vis_city_hall() -> void:
	_time(3, 10.5)
	var vis := get_tree().current_scene.find_child("V7b1Visual", true, false) as V7b1Visual
	if vis == null or vis.city_hall == null:
		return
	var ch := vis.city_hall
	var b := ch.building
	var inside := b.global_transform * Vector3(1.6, Building.FOUNDATION_HEIGHT, b.size.z * 0.5 - 0.9)
	_place(Vector2(inside.x, inside.z), b.rotation_degrees.y + 180.0)
	_player.global_position.y = b.global_position.y + b.floor_y() + 0.05
	ch.ensure_built()
	ch.staffing.auto = false
	ch.staffing.tick()
	await _frames(10)
	for role in ch.staffing.posts:
		var h := ch.staffing.holder(role)
		if h:
			h.global_position = ch.staffing.posts[role]["spot"] + Vector3(0, 0.05, 0)
			var f: Vector3 = ch.staffing.posts[role]["face"] - h.global_position
			h.visual.rotation.y = atan2(f.x, f.z)
	b._set_inside(true)
	_player.visible = false
	_hide_hud(true)
	await _frames(30)
	var from := b.global_transform * Vector3(0.9, Building.FOUNDATION_HEIGHT + 1.85, b.size.z * 0.5 - 0.45)
	var at := b.global_transform * Vector3(-0.4, Building.FOUNDATION_HEIGHT + 1.2, -b.size.z * 0.5 + 0.4)
	_look(from, at, 74.0)
	await _frames(20)
	await _capture("city-hall")
	_player.visible = true
	ch.staffing.auto = true
	_hide_hud(false)


func _vis_minimap_home() -> void:
	_time(3, 11.0)
	_place(Vector2(-6.0, -14.0), 180.0)
	_view(Vector2(0.3, -1.0), -24.0, 7.0)
	await _frames(30)
	await _capture("minimap-home")


func _vis_families() -> void:
	_time(3, 11.0)
	_place(Vector2(6.0, -40.0), 0.0)
	var pp := get_tree().current_scene.find_child("PeoplePanel", true, false) as PeoplePanel
	if pp == null:
		return
	pp.open()
	await _frames(12)
	await _capture("families")
	pp.close()
