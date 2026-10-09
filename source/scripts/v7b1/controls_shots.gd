extends "res://scripts/tools/dev_shots.gd"
## v7b.1 controls screenshots (reuses the DevShots staging helpers):
##   xvfb-run -a -s "-screen 0 1920x1080x24" godot --path . -- --ctl-shots=/workspace/farm-v7b1 [--only=touch-ui,cockpit]
## touch-ui + possess-touch use an iPhone-landscape-shaped window (1688x780).

const CTL_SHOTS: Array[String] = ["touch-ui", "mouse-look", "driving-steer", "cockpit", "possess-touch"]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prefix = "/workspace/farm-v7b1"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ctl-shots="):
			_prefix = arg.substr(12)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
	_run_ctl.call_deferred()


func _win(size: Vector2i) -> void:
	DisplayServer.window_set_size(size)
	get_tree().root.size = size
	await get_tree().process_frame
	await get_tree().process_frame


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	Input.parse_input_event(e)


func _run_ctl() -> void:
	await _frames(20)
	if not _find():
		push_error("ControlsShots: scene actors missing")
		get_tree().quit(1)
		return
	Settings.set_value("dialogue_language", "fa")
	for shot in CTL_SHOTS:
		if not _want(shot):
			continue
		_clean_ui()
		_rig.target_offset = Vector3.ZERO
		await _win(Vector2i(1600, 900))
		await call("_ctl_" + shot.replace("-", "_"))
		ControlInput.set_captured(false)
		ControlInput.set_touch_active(false)
		Input.action_release(&"move_forward")
	print("CONTROLS SHOTS DONE")
	get_tree().quit(0)


func _ctl() -> V7bControls:
	return get_tree().current_scene.find_child("V7bControls", true, false) as V7bControls


func _ctl_touch_ui() -> void:
	_time(3, 10.0)
	await _win(Vector2i(1688, 780))
	_place(Vector2(-3.0, 9.0), 160.0)
	_rig.reset_behind_target()
	_rig.snap_view(_rig.yaw_degrees(), -20.0, 6.5)
	ControlInput.set_touch_active(true)
	await _frames(8)
	var tc := _ctl().touch
	var s := tc.screen_size()
	var lp := Vector2(s.x * 0.17, s.y * 0.72)
	var rp := Vector2(s.x * 0.6, s.y * 0.66)
	_touch(0, lp, true)
	_drag(0, lp + Vector2(tc.radius * 0.35, -tc.radius * 0.9))
	_touch(1, rp, true)
	_drag(1, rp + Vector2(tc.radius * 0.55, -tc.radius * 0.15))
	await _frames(30)
	await _capture("touch-ui")
	_touch(0, lp, false)
	_touch(1, rp, false)
	await _frames(2)


func _ctl_mouse_look() -> void:
	_time(3, 10.5)
	_place(Vector2(2.0, 6.0), 180.0)
	_rig.reset_behind_target()
	_rig.snap_view(_rig.yaw_degrees(), -18.0, 6.0)
	await _frames(6)
	ControlInput.set_captured(true)
	for i in 30:
		ControlInput.handle_mouse_motion(Vector2(-14.0, 1.2))
		await get_tree().process_frame
	await _frames(12)
	await _capture("mouse-look")
	ControlInput.set_captured(false)


func _ctl_driving_steer() -> void:
	_time(3, 10.5)
	var w := _v6b()
	if w.vehicles.cars.is_empty():
		return
	var car := w.vehicles.cars[0]
	var home := car.global_transform
	var hy := car.yaw
	_place(Vector2(car.global_position.x - 2.0, car.global_position.z), 90.0)
	await _frames(6)
	car.get_in(_player)
	Input.action_press(&"move_forward")
	await _frames(40)
	ControlInput.set_captured(true)
	for i in 50:
		ControlInput.handle_mouse_motion(Vector2(8.0, 0.0))
		await get_tree().physics_frame
	car.frame_camera()
	_rig.snap_view(rad_to_deg(atan2(-car.forward().x, -car.forward().z)) - 28.0, -15.0, 8.0)
	for i in 6:
		ControlInput.handle_mouse_motion(Vector2(8.0, 0.0))
		await get_tree().process_frame
	await _capture("driving-steer")
	Input.action_release(&"move_forward")
	ControlInput.set_captured(false)
	car.speed = 0.0
	car.get_out()
	car.global_transform = home
	car.yaw = hy


func _ctl_cockpit() -> void:
	_time(3, 11.0)
	var w := _v6b()
	if w.vehicles.cars.is_empty():
		return
	var car := w.vehicles.cars[0]
	var home := car.global_transform
	var hy := car.yaw
	_place(Vector2(car.global_position.x - 2.0, car.global_position.z), 90.0)
	await _frames(6)
	car.get_in(_player)
	await _frames(4)
	_ctl().toggle_cockpit()
	var ck := _ctl().cockpit_of(car, false)
	ck.look(18.0, 4.0)
	Input.action_press(&"move_left")
	await _frames(20)
	await _capture("cockpit")
	ck.look(0.0, 50.0)
	await _frames(6)
	await _capture("cockpit-sky")
	Input.action_release(&"move_left")
	ck.activate(false)
	car.get_out()
	car.global_transform = home
	car.yaw = hy


func _ctl_possess_touch() -> void:
	_time(4, 11.0)
	await _win(Vector2i(1688, 780))
	var ps := _v7a().possession
	ps.release()
	var b := _adult()
	var house: Building = null
	var c := Vector2(-20.0, -47.8)
	_bot_doing(b, V7aKit.ground(c.x, c.y), "idle", "")
	_place(c + Vector2(1.0, 0.0), 0.0)
	await _frames(4)
	ps.possess(b)
	house = ps.home_building()
	if house:
		var d := house.door_world_position(3.5)
		_place(Vector2(d.x, d.z), house.rotation_degrees.y + 180.0)
	ControlInput.set_touch_active(true)
	_view(Vector2(0.5, 1.0).rotated(-house.rotation.y if house else 0.0), -14.0, 6.0, Vector3(0, 1.0, 0))
	await _frames(14)
	var tc := _ctl().touch
	var s := tc.screen_size()
	var lp := Vector2(s.x * 0.17, s.y * 0.72)
	_touch(0, lp, true)
	_drag(0, lp + Vector2(-tc.radius * 0.2, -tc.radius * 0.5))
	await _frames(16)
	_hide_card()
	await _capture("possess-touch")
	_touch(0, lp, false)
	ps.release()
