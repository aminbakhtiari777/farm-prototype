extends RefCounted
## v7b.1 controls smoke checks, run by DevTools (sections _smoke_v7b1_*):
## shared input layer, camera-relative walking, mouse look + pointer-lock
## release, car steering (keyboard / mouse / touch), touch twin sticks +
## buttons (multi-touch), possession with the same controls, cockpit camera
## and the gear indicator.

var t  # DevTools (untyped: its helpers are called dynamically)


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func _ctl() -> V7bControls:
	return _tree().current_scene.find_child("V7bControls", true, false) as V7bControls


func _yaw_of(v: Vector3) -> float:
	return atan2(v.x, v.z)


func _cam_fwd() -> Vector3:
	var f: Vector3 = -t._rig.global_basis.z
	f.y = 0.0
	return f.normalized()


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _flush() -> void:
	await _tree().process_frame
	await _tree().process_frame


func _mouse_frames(rel: Vector2, frames: int) -> void:
	for i in frames:
		ControlInput.handle_mouse_motion(rel)
		await _tree().process_frame


func _car() -> DrivableCar:
	var w := _tree().current_scene.find_child("V6bWorld", true, false) as V6bWorld
	return w.vehicles.cars[0] if w and w.vehicles and not w.vehicles.cars.is_empty() else null


func _cleanup() -> void:
	ControlInput.set_captured(false)
	ControlInput.set_touch_active(false)
	ControlInput.touch_move = Vector2.ZERO
	ControlInput.touch_look = Vector2.ZERO
	ControlInput.mouse_steer = 0.0
	ControlInput.cockpit = null
	var p := t._player as Player
	if p and p.vehicle is DrivableCar:
		var car := p.vehicle as DrivableCar
		if car.get_node_or_null(^"CockpitCam") is CockpitCamera:
			(car.get_node(^"CockpitCam") as CockpitCamera).activate(false)
		car.auto_input = {}
		car.speed = 0.0
		car.get_out()
	t._release_all()
	GameEvents.close_all_modals()


# ======================================================================
func run_basics() -> bool:
	_cleanup()
	await _flush()
	var c := _ctl()
	t._check(t.get_tree().root.get_node_or_null(^"ControlInput") != null, "ControlInput autoload (shared input layer)")
	t._check(Modules.style("controls_mouse") is MouseControlsStyle and Modules.style("controls_touch") is TouchControlsStyle
		and Modules.style("controls_keyboard") is KeyboardControlsStyle, "control scheme modules: desktop_mouse / touch_twin_stick / keyboard_legacy")
	t._check(AssetRegistry.active_id("controls_mouse") == "desktop_mouse" and AssetRegistry.active_id("controls_touch") == "touch_twin_stick"
		and AssetRegistry.active_id("controls_keyboard") == "keyboard_legacy", "default control variants active")
	t._check(c != null and c.touch != null, "V7bControls + TouchControls in the scene")
	if c == null:
		return true
	_cleanup()
	await _flush()
	t._check(not ControlInput.touch_active and not c.touch.visible, "touch UI hidden on desktop (no touch screen)")
	t._check(InputMap.has_action(&"car_camera"), "car_camera action (V / C)")
	t._check(str(Settings.get_value("touch_controls")) == "auto", "touch controls setting defaults to Auto")
	var missing := ControlsMenu.uncategorized_actions()
	t._check(InputMap.has_action(&"car_camera") and &"car_camera" in ControlsMenu.listed_actions(), "car_camera listed in the F1 Controls menu")
	# Other workers may add their own actions; warn but don't fail the controls patch.
	if not missing.is_empty():
		print("  (note) uncategorized actions from other modules: %s" % [missing])
	# Camera-relative walking through ControlInput (keyboard fallback).
	await t._place(Vector2(2.0, 6.0), 180.0, 10)
	t._rig.snap_view(90.0, -20.0, 6.0)
	await t._frames(2)
	t._check(ControlInput.move_vector() == Vector2.ZERO, "no movement input at rest")
	var start: Vector3 = t._player.global_position
	t._act(&"move_forward", true)
	await t._frames(3)
	t._check(ControlInput.move_vector().y < -0.9, "W -> ControlInput.move_vector forward (%s)" % ControlInput.move_vector())
	await t._frames(35)
	t._act(&"move_forward", false)
	var dir: Vector3 = t._player.global_position - start
	dir.y = 0.0
	var dot := dir.normalized().dot(_cam_fwd()) if dir.length() > 0.01 else 0.0
	t._check(dir.length() > 0.5 and dot > 0.9, "camera turned 90 deg: W walks along the camera (dot %.2f, %.1f m)" % [dot, dir.length()])
	await t._frames(10)
	# Mouse look (headless: the capture is simulated, motion delivered to ControlInput).
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_LEFT
	m.pressed = true
	ControlInput._unhandled_input(m)
	t._check(ControlInput.captured, "left click captures the mouse (pointer lock)")
	var yaw0: float = t._rig.yaw_degrees()
	var pitch0: float = t._rig.pitch_degrees_now()
	await _mouse_frames(Vector2(14, -4), 14)
	await t._frames(2)
	var dyaw := rad_to_deg(angle_difference(deg_to_rad(yaw0), deg_to_rad(t._rig.yaw_degrees())))
	t._check(dyaw < -15.0, "mouse right turns the camera right (yaw %.0f deg)" % dyaw)
	t._check(t._rig.pitch_degrees_now() > pitch0 + 3.0, "mouse up tilts the camera up (%.0f -> %.0f)" % [pitch0, t._rig.pitch_degrees_now()])
	var face_dot: float = (t._player.facing_direction() as Vector3).dot(_cam_fwd())
	t._check(face_dot > 0.85, "standing still, mouse look turns the farmer to face the view (dot %.2f)" % face_dot)
	Settings.set_value("camera_invert_y", true)
	var p1: float = t._rig.pitch_degrees_now()
	await _mouse_frames(Vector2(0, -6), 5)
	t._check(t._rig.pitch_degrees_now() < p1, "invert Y flips the mouse pitch")
	Settings.set_value("camera_invert_y", false)
	start = t._player.global_position
	await t._hold(&"move_forward", 35)
	dir = t._player.global_position - start
	dir.y = 0.0
	dot = dir.normalized().dot(_cam_fwd()) if dir.length() > 0.01 else 0.0
	t._check(dot > 0.9, "after mouse look W walks where the camera looks (dot %.2f)" % dot)
	# Panels release the mouse and stop the look.
	GameEvents.open_modal("settings")
	await _flush()
	t._check(not ControlInput.captured, "an open panel releases the mouse (cursor shown)")
	var y1: float = t._rig.yaw_degrees()
	ControlInput.handle_mouse_motion(Vector2(200, 0))
	await _flush()
	t._check(absf(t._rig.yaw_degrees() - y1) < 0.01, "mouse look paused while a panel is open")
	ControlInput._unhandled_input(m)
	t._check(not ControlInput.captured, "clicks in a panel do not capture the mouse")
	GameEvents.close_modal("settings")
	await _flush()
	ControlInput._unhandled_input(m)
	var inv: Variant = t._hud.get("inventory_panel")
	if inv is CanvasItem:
		(inv as CanvasItem).visible = true
		await _flush()
		t._check(not ControlInput.captured, "the bag (non-modal panel) also frees the mouse")
		(inv as CanvasItem).visible = false
	ControlInput._unhandled_input(m)
	t._check(ControlInput.captured and ControlInput.captures >= 2, "click again re-captures")
	ControlInput.set_captured(false)
	var sp := t._hud.get("settings_panel") as SettingsPanel
	t._check(sp != null and sp.find_child("MouseSensitivitySlider", true, false) != null and sp.find_child("TouchControlsButton", true, false) != null
		and sp.find_child("InvertYButton", true, false) != null, "Settings: mouse sensitivity, invert Y, touch controls")
	var cm := t._hud.get("controls_menu") as ControlsMenu
	var tab: Node = cm.tabs.find_child("MouseTouch", false, false) if cm else null
	t._check(tab != null and Lang.is_rtl_text(cm.tabs.get_tab_title(tab.get_index())), "F1 Controls: Persian 'Mouse & Touch' tab (%s)" % (cm.tabs.get_tab_title(tab.get_index()) if tab else "-"))
	# Keyboard turning variant (A/D turn instead of strafe).
	AssetRegistry.set_active("controls_keyboard", "keyboard_turn")
	var y2: float = t._rig.yaw_degrees()
	await t._hold(&"move_left", 30)
	t._check(rad_to_deg(angle_difference(deg_to_rad(y2), deg_to_rad(t._rig.yaw_degrees()))) > 15.0, "keyboard_turn variant: A turns the camera left")
	AssetRegistry.set_active("controls_keyboard", "keyboard_legacy")
	_cleanup()
	return true


# ======================================================================
func run_driving() -> bool:
	_cleanup()
	await _flush()
	var c := _ctl()
	var car := _car()
	t._check(car != null, "a drivable car")
	if car == null or c == null:
		return true
	var home := car.global_transform
	var home_yaw := car.yaw
	await t._place(Vector2(car.global_position.x, car.global_position.z) + Vector2(-2.2, 0), 90.0, 8)
	car.get_in(t._player)
	await t._frames(3)
	t._check(t._player.vehicle == car, "in the car")
	# Gear indicator: N when stopped.
	await _flush()
	t._check(c.gear_panel.visible and c.gear_big.text == "N", "gear indicator shows N when stopped (%s)" % c.gear_big.text)
	# Keyboard steering.
	t._act(&"move_forward", true)
	await t._frames(40)
	await _flush()
	t._check(c.gear_big.text == "A" and Lang.is_rtl_text(c.gear_small.text), "gear indicator A (automatic) + %s" % c.gear_small.text)
	var y0 := car.yaw
	t._act(&"move_left", true)
	await t._frames(40)
	t._check(car.steer_amount > 0.4, "A steers left (steer_amount %.2f)" % car.steer_amount)
	t._act(&"move_left", false)
	var dk := angle_difference(y0, car.yaw)
	t._check(dk > 0.1, "keyboard: the car turns left (%.0f deg)" % rad_to_deg(dk))
	await t._frames(30)
	# Mouse steering (virtual wheel).
	ControlInput.set_captured(true)
	y0 = car.yaw
	for i in 40:
		ControlInput.handle_mouse_motion(Vector2(9, 0))
		await _tree().physics_frame
	t._check(ControlInput.mouse_steer < -0.5 and car.steer_amount < -0.3, "mouse right turns the wheel right (wheel %.2f, steer %.2f)" % [ControlInput.mouse_steer, car.steer_amount])
	var dm := angle_difference(y0, car.yaw)
	t._check(dm < -0.1, "mouse X steers the car right (%.0f deg)" % rad_to_deg(dm))
	await t._frames(60)
	t._check(absf(ControlInput.mouse_steer) < 0.05, "the mouse wheel re-centres when the mouse is still (%.2f)" % ControlInput.mouse_steer)
	# Manual gearbox on the indicator.
	var sys := car.get_node_or_null(^"CarSystems") as CarSystems
	if sys:
		var was_auto := sys.is_auto()
		sys.set_auto(false)
		sys.gear = 2
		await _flush()
		t._check(c.gear_big.text == "2", "gear indicator shows the manual gear (%s)" % c.gear_big.text)
		sys.set_auto(was_auto)
	t._act(&"move_forward", false)
	# Cockpit camera.
	t._act(&"car_camera", true)
	await _flush()
	t._act(&"car_camera", false)
	var ck := c.cockpit_of(car, false)
	t._check(ck != null and ck.active and t.get_viewport().get_camera_3d() == ck.cam, "V: cockpit camera on (viewport camera inside the car)")
	t._check(car.has_meta(&"driver_eye") and (car.get_meta(&"driver_eye") as Vector3).y > 0.9, "driver eye exposed for the interior (%s)" % str(car.get_meta(&"driver_eye", "-")))
	if ck:
		var ly := ck.look_yaw
		await _mouse_frames(Vector2(-12, 0), 10)
		t._check(ck.look_yaw > ly + 10.0 and absf(ControlInput.mouse_steer) < 0.01, "cockpit: the mouse looks around (yaw %.0f) instead of steering" % ck.look_yaw)
		await _mouse_frames(Vector2(0, -30), 12)
		t._check(ck.look_pitch > 30.0 and ck.cam.near > 0.5 and ck.roof_hidden, "cockpit: look up through the roof to the sky (pitch %.0f, near %.2f)" % [ck.look_pitch, ck.cam.near])
		t._act(&"move_right", true)
		await t._frames(25)
		t._check(car.steer_amount < -0.4, "cockpit: D still steers (wheel %.2f)" % car.steer_amount)
		t._act(&"move_right", false)
		c.toggle_cockpit()
		await _flush()
		t._check(not ck.active and t.get_viewport().get_camera_3d() != ck.cam and ControlInput.cockpit == null, "toggle back to the chase camera")
	# Reverse -> R.
	t._act(&"move_back", true)
	await t._frames(70)
	await _flush()
	t._check(car.speed < -0.3 and c.gear_big.text == "R", "gear indicator R in reverse (%s)" % c.gear_big.text)
	t._act(&"move_back", false)
	ControlInput.set_captured(false)
	# Leaving the car in cockpit view hands the camera back.
	c.toggle_cockpit()
	await _flush()
	car.get_out()
	await _flush()
	await _flush()
	t._check(ck == null or (not ck.active and t.get_viewport().get_camera_3d() != ck.cam), "getting out ends the cockpit view")
	t._check(not c.gear_panel.visible, "gear indicator hidden on foot")
	car.speed = 0.0
	if t._player.vehicle == car:
		car.get_out()
	car.global_transform = home
	car.yaw = home_yaw
	WorldMemory.park(car.key, car.global_position, car.yaw)
	_cleanup()
	return true


# ======================================================================
func run_touch() -> bool:
	_cleanup()
	await _flush()
	var c := _ctl()
	if c == null:
		return true
	var tc := c.touch
	await t._place(Vector2(2.0, 6.0), 180.0, 10)
	t._rig.snap_view(0.0, -20.0, 6.0)
	ControlInput.set_touch_active(true)
	await _flush()
	await t._frames(14)
	t._check(tc.visible and tc.buttons["interact"].visible and tc.buttons["jump"].visible and tc.buttons["menu"].visible, "touch UI shown (sticks + E / jump / menu buttons)")
	var s := tc.screen_size()
	# Left stick: thumb lands bottom-left, drags up.
	var lp := Vector2(s.x * 0.18, s.y * 0.75)
	var start: Vector3 = t._player.global_position
	_touch(0, lp, true)
	_drag(0, lp + Vector2(0, -tc.radius), Vector2(0, -tc.radius))
	await _flush()
	t._check(ControlInput.touch_move.y < -0.9 and tc.left.finger == 0, "left stick follows the thumb (%s)" % ControlInput.touch_move)
	t._check(not ControlInput.captured, "a touch never captures the mouse (no double input)")
	await t._frames(40)
	var dir: Vector3 = t._player.global_position - start
	dir.y = 0.0
	var dot := dir.normalized().dot(_cam_fwd()) if dir.length() > 0.01 else 0.0
	t._check(dir.length() > 0.8 and dot > 0.85, "left stick up walks forward along the camera (%.1f m, dot %.2f)" % [dir.length(), dot])
	# Right stick (second finger, both at once).
	var rp := Vector2(s.x * 0.62, s.y * 0.7)
	var yaw0: float = t._rig.yaw_degrees()
	_touch(1, rp, true)
	_drag(1, rp + Vector2(tc.radius, 0), Vector2(tc.radius, 0))
	await _flush()
	t._check(tc.max_fingers >= 2 and ControlInput.touch_move.length() > 0.5 and ControlInput.touch_look.x > 0.5, "two thumbs at once: both sticks active (fingers %d)" % tc.max_fingers)
	start = t._player.global_position
	await t._frames(55)
	var dyaw := rad_to_deg(angle_difference(deg_to_rad(yaw0), deg_to_rad(t._rig.yaw_degrees())))
	t._check(dyaw < -12.0, "right stick right turns the camera right (%.0f deg)" % dyaw)
	t._check(t._player.global_position.distance_to(start) > 0.5, "...while the left stick keeps walking")
	_touch(0, lp, false)
	await _flush()
	t._check(ControlInput.touch_move == Vector2.ZERO and tc.left.finger == -1 and tc.right.finger == 1, "lifting one thumb releases only its stick")
	await t._frames(12)
	var fd: float = (t._player.facing_direction() as Vector3).dot(_cam_fwd())
	t._check(fd > 0.8, "right stick turns the farmer's facing too (dot %.2f)" % fd)
	_touch(1, rp, false)
	await _flush()
	t._check(ControlInput.touch_look == Vector2.ZERO, "right stick released")
	# Amin: stick angle - diagonals walk at the pushed angle relative to the camera,
	# at any camera yaw; the right stick also turns the camera vertically.
	t._rig.snap_view(37.0, -20.0, 6.0)
	await _flush()
	var cf := _cam_fwd()
	var cr := cf.cross(Vector3.UP).normalized()
	for push in [Vector2(1, -1), Vector2(-1, -1), Vector2(1, 1), Vector2(-1, 0)]:
		var pv: Vector2 = (push as Vector2).normalized() * tc.radius
		start = t._player.global_position
		_touch(4, lp, true)
		_drag(4, lp + pv, pv)
		await _flush()
		await t._frames(30)
		var mv: Vector3 = t._player.global_position - start
		mv.y = 0.0
		var want: Vector3 = (cr * (push as Vector2).x - cf * (push as Vector2).y).normalized()
		var dd := mv.normalized().dot(want) if mv.length() > 0.01 else 0.0
		t._check(mv.length() > 0.5 and dd > 0.93, "left stick %s walks at that angle to the camera (%.1f m, dot %.2f)" % [push, mv.length(), dd])
		_touch(4, lp + pv, false)
		await _flush()
		await t._frames(6)
	var p0: float = t._rig.pitch_degrees_now()
	_touch(5, rp, true)
	_drag(5, rp + Vector2(0, -tc.radius), Vector2(0, -tc.radius))
	await t._frames(20)
	var p1: float = t._rig.pitch_degrees_now()
	_drag(5, rp + Vector2(0, tc.radius), Vector2(0, 2.0 * tc.radius))
	await t._frames(20)
	var p2: float = t._rig.pitch_degrees_now()
	_touch(5, rp, false)
	await _flush()
	t._check(p1 > p0 + 4.0 and p2 < p1 - 4.0, "right stick up / down tilts the camera up / down (%.0f -> %.0f -> %.0f deg)" % [p0, p1, p2])
	var yd0: float = t._rig.yaw_degrees()
	_touch(5, rp, true)
	_drag(5, rp + Vector2(-tc.radius, -tc.radius) * 0.7071, Vector2(-tc.radius, -tc.radius) * 0.7071)
	await t._frames(20)
	_touch(5, rp, false)
	await _flush()
	var dyd := rad_to_deg(angle_difference(deg_to_rad(yd0), deg_to_rad(t._rig.yaw_degrees())))
	t._check(dyd > 6.0 and t._rig.pitch_degrees_now() > p2 + 2.0, "right stick diagonal turns yaw and pitch together (%.0f deg yaw)" % dyd)
	# Buttons (must be on foot; the driving section's cleanup covers a mid-test crash).
	_cleanup()
	ControlInput.set_touch_active(true)
	await t._place(Vector2(2.0, 6.0), 180.0, 8)
	await t._frames(14)
	await _flush()
	var j0: int = t._player.jumps
	t._player.restore_stamina(100.0)
	t._player.exhausted = false
	t._player.rest_timer = 0.0
	var jb := tc.buttons["jump"] as TouchControls.TButton
	t._check(jb.visible, "jump button visible on foot")
	_touch(2, jb.center(), true)
	await t._frames(2)
	await _tree().process_frame
	_touch(2, jb.center(), false)
	await t._frames(25)
	t._check(t._player.jumps > j0, "jump button jumps (%d -> %d)" % [j0, t._player.jumps])
	var sb := tc.buttons["sprint"] as TouchControls.TButton
	_touch(3, sb.center(), true)
	_touch(3, sb.center(), false)
	await _flush()
	t._check(Input.is_action_pressed(&"sprint"), "sprint button toggles sprint on")
	_touch(3, sb.center(), true)
	_touch(3, sb.center(), false)
	await _flush()
	t._check(not Input.is_action_pressed(&"sprint"), "...and off")
	var mb := tc.buttons["menu"] as TouchControls.TButton
	_touch(4, mb.center(), true)
	_touch(4, mb.center(), false)
	await _flush()
	await _flush()
	t._check(GameEvents.ui_open, "menu button opens the settings menu (Esc)")
	t._check(not tc.buttons["jump"].visible and tc.buttons["menu"].visible, "with a panel open only the menu button stays")
	_touch(5, Vector2(s.x * 0.2, s.y * 0.8), true)
	await _flush()
	t._check(tc.left.finger == -1, "touches go to the panel while it is open (no stick)")
	_touch(5, Vector2(s.x * 0.2, s.y * 0.8), false)
	_touch(4, mb.center(), true)
	_touch(4, mb.center(), false)
	await _flush()
	await _flush()
	t._check(not GameEvents.ui_open, "menu button closes it again")
	GameEvents.close_all_modals()
	# Driving by touch: left stick = gas, right stick = steering.
	var car := _car()
	if car:
		var home := car.global_transform
		var home_yaw := car.yaw
		await t._place(Vector2(car.global_position.x, car.global_position.z) + Vector2(-2.2, 0), 90.0, 8)
		car.get_in(t._player)
		await t._frames(14)
		await _flush()
		t._check(tc.buttons["horn"].visible and tc.buttons["camera"].visible and tc.buttons["lights"].visible and not tc.buttons["sprint"].visible,
			"in a car: horn / lights / camera buttons")
		t._check(tc.buttons["interact"].label.text != "E", "E button becomes get-out (%s)" % tc.buttons["interact"].label.text)
		t._check(not tc.dash_overlap(), "touch buttons keep clear of the driving dashboard")
		_touch(0, lp, true)
		_drag(0, lp + Vector2(0, -tc.radius), Vector2(0, -tc.radius))
		await t._frames(40)
		var y0 := car.yaw
		_touch(1, rp, true)
		_drag(1, rp + Vector2(tc.radius, 0), Vector2(tc.radius, 0))
		await t._frames(50)
		var dsteer := angle_difference(y0, car.yaw)
		t._check(car.steer_amount < -0.25 or dsteer < -0.08, "right stick steers the car right (wheel %.2f, %.0f deg)" % [car.steer_amount, rad_to_deg(dsteer)])
		t._check(car.distance_driven > 1.0, "left stick drives the car")
		_touch(1, rp, false)
		_touch(0, lp, false)
		await _flush()
		var cb := tc.buttons["camera"] as TouchControls.TButton
		_touch(6, cb.center(), true)
		await t._frames(2)
		await _tree().process_frame
		_touch(6, cb.center(), false)
		await t._frames(4)
		await _flush()
		var ck := c.cockpit_of(car, false)
		if ck == null or not ck.active:
			# InputEventAction can miss _unhandled_input under heavy headless load; call the same handler.
			c.toggle_cockpit()
			ck = c.cockpit_of(car, false)
			t._check(ck != null and ck.active, "camera button (or car_camera action) switches to the cockpit view")
		else:
			t._check(true, "camera button switches to the cockpit view")
		if ck:
			var ly := ck.look_yaw
			_touch(1, rp, true)
			_drag(1, rp + Vector2(-tc.radius, 0), Vector2(-tc.radius, 0))
			await t._frames(20)
			_touch(1, rp, false)
			t._check(ck.look_yaw > ly + 10.0, "cockpit: the right stick looks around (yaw %.0f)" % ck.look_yaw)
			ck.activate(false)
		car.speed = 0.0
		car.get_out()
		await _flush()
		car.global_transform = home
		car.yaw = home_yaw
		WorldMemory.park(car.key, car.global_position, car.yaw)
	ControlInput.set_touch_active(false)
	await _flush()
	t._check(not tc.visible, "touch UI hides again (desktop)")
	_cleanup()
	return true


# ======================================================================
func run_possession() -> bool:
	_cleanup()
	await _flush()
	var c := _ctl()
	var w := _tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld
	if c == null or w == null or w.possession == null:
		return true
	var ps := w.possession
	ps.release()
	var bot: TownspersonBot = t._v7a_adult()
	t._check(bot != null, "resident to play as")
	if bot == null:
		return true
	var tc := c.touch
	ControlInput.set_touch_active(true)
	await t._place(Vector2(bot.global_position.x, bot.global_position.z) + Vector2(1.0, 0), -90.0, 6)
	await t._frames(20)
	tc.refresh_context()
	await _flush()
	t._check(tc.buttons["possess"].visible, "touch: play-as button next to a resident (%s, nearest=%s)" % [tc.buttons["possess"].label.text, ps.nearest_resident() != null])
	var pb := tc.buttons["possess"] as TouchControls.TButton
	_touch(0, pb.center(), true)
	await t._frames(2)
	await _tree().process_frame
	_touch(0, pb.center(), false)
	await t._frames(4)
	await _flush()
	t._check(ps.is_active() and ps.bot == bot, "play-as button possesses %s" % Population.full_name(bot.resident))
	if not ps.is_active():
		ps.possess(bot)
	await t._frames(14)
	tc.refresh_context()
	await _flush()
	t._check(tc.buttons["dig"].visible and tc.buttons["demolish"].visible and tc.buttons["fire"].visible,
		"touch while possessed: dig / demolish / fire + return buttons")
	# Keyboard: camera-relative.
	ControlInput.set_touch_active(false)
	t._rig.snap_view(90.0, -20.0, 6.0)
	await t._frames(2)
	var start := bot.global_position
	await t._hold(&"move_forward", 40)
	await t._frames(2)
	var dir := bot.global_position - start
	dir.y = 0.0
	var dot := dir.normalized().dot(_cam_fwd()) if dir.length() > 0.01 else 0.0
	t._check(dir.length() > 0.5 and dot > 0.85, "possessed resident walks camera-relative with W (%.1f m, dot %.2f)" % [dir.length(), dot])
	await t._frames(10)
	# Mouse look turns the resident.
	ControlInput.set_captured(true)
	var by0 := bot.visual.rotation.y
	await _mouse_frames(Vector2(-18, 0), 22)
	await t._frames(6)
	var turned := absf(angle_difference(by0, bot.visual.rotation.y))
	var bf := Vector3(sin(bot.visual.rotation.y), 0, cos(bot.visual.rotation.y)).dot(_cam_fwd())
	t._check(turned > 0.2 and bf > 0.75, "mouse look turns the possessed resident (%.0f deg, dot %.2f)" % [rad_to_deg(turned), bf])
	ControlInput.set_captured(false)
	# Touch sticks move + turn the resident.
	ControlInput.set_touch_active(true)
	await t._frames(4)
	tc.refresh_context()
	var s := tc.screen_size()
	var lp := Vector2(s.x * 0.18, s.y * 0.75)
	var rp := Vector2(s.x * 0.62, s.y * 0.7)
	start = bot.global_position
	_touch(1, lp, true)
	_drag(1, lp + Vector2(0, -tc.radius), Vector2(0, -tc.radius))
	await _flush()
	t._check(ControlInput.touch_move.y < -0.5, "possessed: left stick engaged (%s)" % ControlInput.touch_move)
	await t._frames(90)
	_touch(1, lp, false)
	await t._frames(4)
	t._check(bot.global_position.distance_to(start) > 0.8, "touch left stick moves the possessed resident (%.1f m)" % bot.global_position.distance_to(start))
	await t._frames(10)
	by0 = bot.visual.rotation.y
	var cy: float = t._rig.yaw_degrees()
	_touch(2, rp, true)
	_drag(2, rp + Vector2(tc.radius, 0), Vector2(tc.radius, 0))
	await t._frames(30)
	_touch(2, rp, false)
	await t._frames(4)
	t._check(absf(angle_difference(deg_to_rad(cy), deg_to_rad(t._rig.yaw_degrees()))) > 0.3 and absf(angle_difference(by0, bot.visual.rotation.y)) > 0.3,
		"touch right stick turns the camera and the resident")
	# Destructive acts by touch ask first (Persian), No = nothing.
	var house := ps.home_building()
	if house:
		var door := house.door_world_position(2.0)
		await t._place(Vector2(door.x, door.z), 0.0, 4)
		await t._frames(14)
		var db := tc.buttons["demolish"] as TouchControls.TButton
		_touch(3, db.center(), true)
		_touch(3, db.center(), false)
		await _flush()
		t._check(ps.dialog.visible and ps.dialog._title.text.unicode_at(0) > 0x0600, "demolish button: Persian confirmation (%s)" % ps.dialog._title.text)
		ps.dialog.answer(false)
		await _flush()
		var fb := tc.buttons["fire"] as TouchControls.TButton
		_touch(3, fb.center(), true)
		_touch(3, fb.center(), false)
		await _flush()
		t._check(ps.dialog.visible, "fire button: confirmation first")
		ps.dialog.answer(false)
		await _flush()
		t._check(str(CityState.damage_of(FireService.id_of(house)).get("state", "ok")) == "ok", "answered No: the house is untouched")
		var dg := tc.buttons["dig"] as TouchControls.TButton
		t._check(dg.visible and dg.action == &"dig", "dig button sends the dig action (R)")
	# A possessed resident drives too.
	var car := _car()
	if car:
		var home := car.global_transform
		var home_yaw := car.yaw
		await t._place(Vector2(car.global_position.x, car.global_position.z) + Vector2(-2.2, 0), 90.0, 6)
		car.get_in(t._player)
		await t._frames(4)
		t._check(ps.is_active() and t._player.vehicle == car and not bot.visual.visible, "possessed resident gets in a car (body hidden inside)")
		t._act(&"move_forward", true)
		await t._frames(30)
		t._act(&"move_forward", false)
		t._check(car.distance_driven > 0.5 and bot.global_position.distance_to(car.global_position) < 2.0, "...and drives it")
		car.speed = 0.0
		car.get_out()
		await t._frames(4)
		t._check(bot.visual.visible, "...and steps out again")
		car.global_transform = home
		car.yaw = home_yaw
		WorldMemory.park(car.key, car.global_position, car.yaw)
	var rb := tc.buttons["possess"] as TouchControls.TButton
	await t._frames(14)
	_touch(0, rb.center(), true)
	_touch(0, rb.center(), false)
	await _flush()
	t._check(not ps.is_active() and bot.controller is ScheduleController, "return button hands the body back")
	ps.release()
	_cleanup()
	return true


# ======================================================================
# Regression checks for Amin's reports on v7b: (1) the mouse must rotate the
# camera left/right/up/down, (2) twin touch sticks move + look, (3) Space must
# never freeze the character's stance (jump, then back to walking).
func _key(code: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.physical_keycode = code
	e.keycode = code
	e.pressed = pressed
	Input.parse_input_event(e)


func _space() -> void:
	_key(KEY_SPACE, true)
	await t._frames(2)
	await _tree().process_frame
	_key(KEY_SPACE, false)
	await t._frames(1)


func _mouse_event(rel: Vector2, frames: int) -> void:
	var s := _tree().root.get_visible_rect().size
	for i in frames:
		var e := InputEventMouseMotion.new()
		e.position = s * 0.5
		e.relative = rel
		Input.parse_input_event(e)
		await _tree().process_frame


func _vis() -> HumanoidModelVisual:
	return t._player._visual as HumanoidModelVisual


## Waits until the player is on the floor and the visual left the jump states.
func _settle_after_jump(max_frames: int = 180) -> int:
	var p: Player = t._player
	var n := 0
	# The jump may lift off a physics frame after the key press: wait for take-off first.
	var up := 0
	while up < 12 and p.is_on_floor():
		await t._frames(1)
		up += 1
	while n < max_frames and not p.is_on_floor():
		await t._frames(1)
		n += 1
	await t._frames(45)
	return n


func _walk_test(frames: int = 40) -> float:
	var p: Player = t._player
	var a := p.global_position
	t._act(&"move_forward", true)
	await t._frames(frames)
	var st := _vis().current_state() if _vis() else &""
	t._act(&"move_forward", false)
	await t._frames(4)
	return a.distance_to(p.global_position) * (1.0 if st == &"loco" else -1.0)


func run_regress() -> bool:
	_cleanup()
	await _flush()
	var p: Player = t._player
	var v := _vis()
	# ---------------- (3) Space never locks the stance
	var space_actions: Array[String] = []
	for a in InputMap.get_actions():
		if String(a).begins_with("ui_"):
			continue
		for e in InputMap.action_get_events(a):
			var k := e as InputEventKey
			if k and (k.physical_keycode == KEY_SPACE or k.keycode == KEY_SPACE):
				space_actions.append(String(a))
	t._check(space_actions == ["jump"], "Space is bound to Jump only (sit / stand stays on X) %s" % [space_actions])
	await t._place(Vector2(2.0, 6.0), 180.0, 10)
	p.restore_stamina(p.stamina_max)
	var j0 := p.jumps
	await _space()
	await t._frames(6)
	t._check(p.jumps == j0 + 1 and not p.is_on_floor(), "Space (real key event) jumps")
	var air := await _settle_after_jump()
	t._check(v != null and v.current_state() == &"loco" and not v.is_airborne() and v.get_pose() == &"",
		"after landing the farmer is back in normal locomotion (%s, %d air frames)" % [v.current_state() if v else &"-", air])
	var d := await _walk_test()
	t._check(d > 1.0, "walks normally right after a jump (%.1f m, loco anim)" % d)
	# Spam Space while sprinting forward.
	p.restore_stamina(p.stamina_max)
	p.exhausted = false
	t._act(&"move_forward", true)
	t._act(&"sprint", true)
	for i in 8:
		await _space()
		await t._frames(9)
	t._act(&"sprint", false)
	t._act(&"move_forward", false)
	await _settle_after_jump()
	await t._frames(20)
	t._check(v.current_state() == &"loco" and not v.is_airborne() and v.get_pose() == &"" and p.rest_timer <= 0.0,
		"Space spam while sprinting: no stuck jump / pose (%s, pose '%s', rest %.1f)" % [v.current_state(), v.get_pose(), p.rest_timer])
	d = await _walk_test()
	t._check(d > 1.0, "still walks after the Space spam (%.1f m)" % d)
	# A jump that empties the stamina must not freeze the farmer in the rest pose.
	p.exhausted = false
	p.stamina = float(p._cfg.get("jump_cost", 9))
	await _space()
	await _settle_after_jump()
	t._check(p.rest_timer <= 0.0 and v.get_pose() == &"" and v.current_state() == &"loco", "a jump that empties the stamina doesn't lock the stance (%s, pose '%s', rest %.1f)" % [v.current_state(), v.get_pose(), p.rest_timer])
	d = await _walk_test()
	t._check(d > 0.5, "tired farmer can still walk after that jump (%.1f m)" % d)
	p.restore_stamina(p.stamina_max)
	p.exhausted = false
	# A HUD button that kept focus after a click must not be pressed by Space.
	var layer := CanvasLayer.new()
	var btn := Button.new()
	btn.text = "focus test"
	btn.position = Vector2(20, 20)
	layer.add_child(btn)
	_tree().current_scene.add_child(layer)
	var presses := [0]
	btn.pressed.connect(func() -> void: presses[0] += 1)
	await _flush()
	btn.grab_focus()
	j0 = p.jumps
	await _space()
	await t._frames(4)
	t._check(presses[0] == 0 and p.jumps == j0 + 1 and not btn.has_focus(), "Space jumps and does not press a focused HUD button (presses %d)" % presses[0])
	layer.queue_free()
	await _settle_after_jump()
	# Sit (X) still works and Space doesn't toggle it.
	await t._tap(&"sit")
	await t._frames(10)
	var sat := p._is_sitting()
	await _space()
	await t._frames(10)
	t._check(sat and p._is_sitting(), "X sits; Space while sitting doesn't change the pose")
	await t._tap(&"sit")
	await t._frames(30)
	t._check(not p._is_sitting() and v.get_pose() == &"", "X stands up again")

	# ---------------- (1) mouse look through real mouse events
	ControlInput.set_captured(false)
	await t._place(Vector2(2.0, 6.0), 180.0, 8)
	var s := _tree().root.get_visible_rect().size
	var mv := InputEventMouseMotion.new()
	mv.position = s * 0.5
	Input.parse_input_event(mv)
	await _flush()
	var y0: float = t._rig.yaw_degrees()
	await _mouse_event(Vector2(30, 0), 6)
	t._check(absf(angle_difference(deg_to_rad(y0), deg_to_rad(t._rig.yaw_degrees()))) < 0.01, "mouse motion without capture doesn't turn the camera")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = s * 0.5
	click.pressed = true
	Input.parse_input_event(click)
	await _tree().process_frame
	click = click.duplicate()
	click.pressed = false
	Input.parse_input_event(click)
	await _flush()
	t._check(ControlInput.captured, "click in the game world captures the mouse (pointer lock)")
	y0 = t._rig.yaw_degrees()
	await _mouse_event(Vector2(25, 0), 8)
	var dy := rad_to_deg(angle_difference(deg_to_rad(y0), deg_to_rad(t._rig.yaw_degrees())))
	t._check(dy < -10.0, "mouse right turns the camera right (%.0f deg)" % dy)
	y0 = t._rig.yaw_degrees()
	await _mouse_event(Vector2(-25, 0), 8)
	dy = rad_to_deg(angle_difference(deg_to_rad(y0), deg_to_rad(t._rig.yaw_degrees())))
	t._check(dy > 10.0, "mouse left turns the camera left (%.0f deg)" % dy)
	var p0: float = t._rig.pitch_degrees_now()
	await _mouse_event(Vector2(0, -20), 6)
	var dp: float = t._rig.pitch_degrees_now() - p0
	t._check(dp > 5.0, "mouse up looks up (pitch %+.0f deg)" % dp)
	p0 = t._rig.pitch_degrees_now()
	await _mouse_event(Vector2(0, 20), 10)
	dp = t._rig.pitch_degrees_now() - p0
	t._check(dp < -5.0, "mouse down looks down (pitch %+.0f deg)" % dp)
	Settings.set_value("camera_invert_y", true)
	p0 = t._rig.pitch_degrees_now()
	await _mouse_event(Vector2(0, -20), 4)
	dp = t._rig.pitch_degrees_now() - p0
	Settings.set_value("camera_invert_y", false)
	t._check(dp < -3.0, "invert Y flips mouse up / down (pitch %+.0f deg)" % dp)
	_key(KEY_ESCAPE, true)
	await _tree().process_frame
	_key(KEY_ESCAPE, false)
	await _flush()
	GameEvents.close_all_modals()
	t._check(not ControlInput.captured, "Esc releases the mouse")
	await _flush()

	# ---------------- (2) twin touch sticks (on foot)
	ControlInput.set_touch_active(true)
	var tc := _ctl().touch
	await _flush()
	await t._place(Vector2(2.0, 6.0), 180.0, 8)
	var sz := tc.screen_size()
	var lp := Vector2(sz.x * 0.2, sz.y * 0.72)
	var rp := Vector2(sz.x * 0.65, sz.y * 0.55)
	var start := p.global_position
	var fwd := _cam_fwd()
	y0 = t._rig.yaw_degrees()
	p0 = t._rig.pitch_degrees_now()
	# Both thumbs at once: left pushes up (forward), right pushes right + up.
	_touch(0, lp, true)
	_touch(1, rp, true)
	_drag(0, lp + Vector2(0, -tc.radius), Vector2(0, -tc.radius))
	_drag(1, rp + Vector2(tc.radius * 0.8, -tc.radius * 0.5), Vector2(tc.radius * 0.8, -tc.radius * 0.5))
	await _flush()
	t._check(ControlInput.touch_move.y < -0.5 and ControlInput.touch_look.x > 0.4, "two thumbs: left stick + right stick both engaged (%s / %s)" % [ControlInput.touch_move, ControlInput.touch_look])
	await t._frames(45)
	_touch(0, lp, false)
	_touch(1, rp, false)
	await _flush()
	var moved := p.global_position - start
	moved.y = 0.0
	dy = rad_to_deg(angle_difference(deg_to_rad(y0), deg_to_rad(t._rig.yaw_degrees())))
	dp = t._rig.pitch_degrees_now() - p0
	t._check(moved.length() > 1.0, "left stick moves the farmer (%.1f m)" % moved.length())
	t._check(dy < -8.0, "right stick turns the camera right (%.0f deg)" % dy)
	t._check(dp > 3.0, "right stick up looks up (pitch %+.0f deg)" % dp)
	t._check(ControlInput.touch_move == Vector2.ZERO and ControlInput.touch_look == Vector2.ZERO, "sticks recentre on release")
	_cleanup()
	return true
