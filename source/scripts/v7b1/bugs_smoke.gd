extends RefCounted
## v7b.1 bug-fix regression checks (Amin's reports, PROGRESS_BUGS.md), run by
## DevTools sections _smoke_v7b1_bugs_*: camera yaw with mouse / right stick
## (on foot, playing as a resident, parked + rolling car).

var t  # DevTools (untyped: its helpers are called dynamically)


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func _flush() -> void:
	await _tree().process_frame
	await _tree().process_frame


func _cleanup() -> void:
	ControlInput.set_captured(false)
	ControlInput.set_touch_active(false)
	ControlInput.touch_move = Vector2.ZERO
	ControlInput.touch_look = Vector2.ZERO
	ControlInput.mouse_steer = 0.0
	var p := t._player as Player
	if p and p.vehicle is DrivableCar:
		var car := p.vehicle as DrivableCar
		car.auto_input = {}
		car.speed = 0.0
		car.get_out()
	t._release_all()
	GameEvents.close_all_modals()


func _yaw() -> float:
	return t._rig.yaw_degrees()


func _dyaw(a: float, b: float) -> float:
	return rad_to_deg(angle_difference(deg_to_rad(a), deg_to_rad(b)))


func _mouse(rel: Vector2, frames: int) -> void:
	for i in frames:
		ControlInput.handle_mouse_motion(rel)
		await _tree().process_frame


func _stick(v: Vector2, frames: int) -> void:
	ControlInput.touch_look = v
	for i in frames:
		await _tree().process_frame
	ControlInput.touch_look = Vector2.ZERO
	await _flush()


## Mouse X + right stick X turn the camera left/right, mouse Y / stick Y tilt it.
func _look_both_axes(tag: String) -> void:
	ControlInput.set_captured(true)
	await _flush()
	t._rig.snap_view(0.0, -20.0, 6.0)
	var y0 := _yaw()
	await _mouse(Vector2(12, 0), 20)
	var dmx := _dyaw(y0, _yaw())
	t._check(dmx < -20.0, "%s: mouse right turns the camera right (yaw %.0f deg)" % [tag, dmx])
	y0 = _yaw()
	await _mouse(Vector2(-12, 0), 20)
	t._check(_dyaw(y0, _yaw()) > 20.0, "%s: mouse left turns the camera left (yaw %+.0f deg)" % [tag, _dyaw(y0, _yaw())])
	var p0: float = t._rig.pitch_degrees_now()
	await _mouse(Vector2(0, -10), 12)
	t._check(t._rig.pitch_degrees_now() > p0 + 8.0, "%s: mouse up tilts up (%.0f -> %.0f)" % [tag, p0, t._rig.pitch_degrees_now()])
	ControlInput.set_captured(false)
	await _flush()
	y0 = _yaw()
	await _stick(Vector2(0.9, 0.0), 30)
	var dsx := _dyaw(y0, _yaw())
	t._check(dsx < -15.0, "%s: right stick right turns the camera right (yaw %.0f deg)" % [tag, dsx])
	p0 = t._rig.pitch_degrees_now()
	await _stick(Vector2(0.0, 0.9), 20)
	t._check(absf(t._rig.pitch_degrees_now() - p0) > 5.0, "%s: right stick Y tilts the camera (%.0f -> %.0f)" % [tag, p0, t._rig.pitch_degrees_now()])


func run_camera() -> bool:
	_cleanup()
	await _flush()
	var rig := t._rig as FollowCamera
	await t._place(Vector2(-3.0, 9.0), 0.0)
	await _look_both_axes("on foot")
	rig.orbit(0.0, 500.0)
	t._check(rig.pitch_degrees_now() >= 35.0, "camera can look up (max pitch %.0f deg, was 18)" % rig.pitch_degrees_now())
	rig.snap_view(0.0, -24.0, 6.0)
	# Playing as a resident (possession moves the hidden farmer body).
	var w := _tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld
	var bot: TownspersonBot = t._v7a_adult() if t.has_method("_v7a_adult") else null
	if w and w.possession and bot:
		w.possession.release()
		await t._place(Vector2(bot.global_position.x, bot.global_position.z) + Vector2(1.0, 0.0), 0.0)
		w.possession.possess(bot)
		await t._frames(10)
		t._check(w.possession.is_active(), "playing as %s" % bot.display_name)
		await _look_both_axes("as a resident")
		w.possession.release()
		await t._frames(5)
	# Car: parked = mouse / stick look around; rolling = mouse X steers, camera swings behind.
	var vw := _tree().current_scene.find_child("V6bWorld", true, false) as V6bWorld
	var car: DrivableCar = vw.vehicles.cars[0] if vw and vw.vehicles and not vw.vehicles.cars.is_empty() else null
	t._check(car != null, "a drivable car")
	if car == null:
		return true
	await t._place(Vector2(car.door_spot.global_position.x, car.door_spot.global_position.z), 0.0)
	car.get_in(t._player)
	await t._frames(10)
	t._check(t._player.vehicle == car and absf(car.speed) < 0.5, "in a parked car")
	await _look_both_axes("parked car")
	var y_hold := _yaw()
	await t._frames(60)
	t._check(absf(_dyaw(y_hold, _yaw())) < 3.0, "parked car: the camera stays where the player looked (%.1f deg drift)" % _dyaw(y_hold, _yaw()))
	t._act(&"move_forward", true)
	await t._frames(70)
	t._check(absf(car.speed) > ControlInput.LOOK_STEER_SPEED, "car rolling (%.1f m/s)" % car.speed)
	ControlInput.set_captured(true)
	await _flush()
	for i in 30:
		ControlInput.handle_mouse_motion(Vector2(9, 0))
		await _tree().physics_frame
	t._check(ControlInput.mouse_steer < -0.4 and car.steer_amount < -0.2, "rolling car: mouse X still steers (wheel %.2f)" % ControlInput.mouse_steer)
	await t._frames(150)
	var behind := rad_to_deg(atan2(-car.forward().x, -car.forward().z))
	t._check(absf(_dyaw(behind, _yaw())) < 30.0, "rolling car: the chase camera swings back behind the car (%.0f deg off)" % _dyaw(behind, _yaw()))
	t._act(&"move_forward", false)
	_cleanup()
	await t._frames(10)
	return true
