extends Node
## v7b.1 shared input layer (autoload "ControlInput"). Every control scheme
## feeds the same values, and every mover reads them from here:
##   move_vector()  on-foot movement (x right, y back; camera-relative in Player)
##   take_look(dt)  camera yaw/pitch degrees this frame (FollowCamera / cockpit)
##   steer()        car steering -1..1 (+ = left), throttle() -1..1, brake()
## Schemes (swappable modules, all active side by side):
##   controls_mouse     desktop: click captures the mouse (pointer lock), mouse
##                      looks; in a car mouse X steers (virtual wheel). Esc or
##                      any open panel releases the mouse and shows the cursor.
##   controls_touch     phones: TouchControls (left stick moves, right stick
##                      looks / steers, action buttons). Auto on touch screens.
##   controls_keyboard  fallback: WASD / arrows, Z/C orbit, A/D steer.
## Used by Player (also while playing as a townsperson - possession moves the
## hidden farmer body), FollowCamera, DrivableCar, CockpitCamera, FishingMinigame.

signal scheme_changed(touch: bool)
signal capture_changed(captured: bool)

## Touch UI (joysticks + buttons) in use.
var touch_active: bool = false
## Mouse captured for mouse look (pointer lock on the web).
var captured: bool = false
## Left / right virtual sticks (-1..1, y down = back), written by TouchControls.
var touch_move: Vector2 = Vector2.ZERO
var touch_look: Vector2 = Vector2.ZERO
## Virtual steering wheel driven by mouse X while driving (-1..1, + = left).
var mouse_steer: float = 0.0
## Cockpit camera while it is active (it then owns look input; mouse looks, not steers).
var cockpit: Node = null
## Stats for the smoke test / diagnostics.
var captures: int = 0
var releases: int = 0
var touch_seen: bool = false
var _look_px: Vector2 = Vector2.ZERO
var _mouse_moved: bool = false
var _since_look: float = 99.0
var _capture_grace: float = 0.0
var _headless: bool = false
## Pointer lock was granted during this capture (losing it then = the player pressed Esc).
var _had_lock: bool = false
## The browser refused pointer lock (iframe / headless / old Safari): mouse look
## keeps working from relative motion with the cursor visible ("soft" capture).
var soft_capture: bool = false
## Space presses that were kept from re-pressing a focused UI button (diagnostics).
var space_guards: int = 0
var _touch_capability: int = -1
var _web_resize_callback: JavaScriptObject


func mouse_style() -> MouseControlsStyle:
	return Modules.style("controls_mouse") as MouseControlsStyle


func touch_style() -> TouchControlsStyle:
	return Modules.style("controls_touch") as TouchControlsStyle


func keyboard_style() -> KeyboardControlsStyle:
	return Modules.style("controls_keyboard") as KeyboardControlsStyle


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_headless = DisplayServer.get_name() == "headless"
	if OS.has_feature("web"):
		_web_resize_callback = JavaScriptBridge.create_callback(func(_args: Array) -> void: _fit_ui.call_deferred(touch_active))
		var window := JavaScriptBridge.get_interface("window")
		window.addEventListener("resize", _web_resize_callback)
		window.addEventListener("orientationchange", _web_resize_callback)
	refresh_touch_mode.call_deferred()
	get_tree().root.size_changed.connect(func() -> void: _fit_ui.call_deferred(touch_active))
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "touch_controls":
			refresh_touch_mode())


## Auto: touch UI on touch screens (or after the first touch); On / Off forced.
func refresh_touch_mode() -> void:
	match str(Settings.get_value("touch_controls")):
		"on":
			set_touch_active(true)
		"off":
			set_touch_active(false)
		_:
			set_touch_active(touch_seen or touch_device_available())


## iPadOS can identify itself as desktop Safari; use hardware capability.
func touch_device_available() -> bool:
	if _headless:
		return false
	if _touch_capability >= 0:
		return _touch_capability == 1
	_touch_capability = 1 if DisplayServer.is_touchscreen_available() else 0
	if OS.has_feature("web"):
		var points: Variant = JavaScriptBridge.eval("navigator.maxTouchPoints || 0", true)
		if points is float or points is int:
			if int(points) > 0:
				_touch_capability = 1
	return _touch_capability == 1


func set_touch_active(on: bool) -> void:
	if on == touch_active:
		return
	touch_active = on
	touch_move = Vector2.ZERO
	touch_look = Vector2.ZERO
	if on:
		set_captured(false)
	_fit_ui(on)
	scheme_changed.emit(on)


## Bound touch rendering in either orientation, including after rotation.
func _fit_ui(on: bool) -> void:
	if _headless or not is_inside_tree() or not (OS.has_feature("web") or OS.has_feature("mobile")):
		return
	var ts := touch_style()
	var root := get_tree().root
	if on and ts and ts.fit_ui:
		# Compatibility/WebGL ignores 3D scaling on some devices. Bound the
		# actual viewport as well, rather than rendering at Retina resolution.
		if root.content_scale_mode != Window.CONTENT_SCALE_MODE_VIEWPORT:
			root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
		if root.content_scale_aspect != Window.CONTENT_SCALE_ASPECT_EXPAND:
			root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
		var portrait := root.size.y > root.size.x
		if OS.has_feature("web"):
			portrait = bool(JavaScriptBridge.eval("window.innerHeight > window.innerWidth", true))
		var desired := Vector2i(720, 1280) if portrait else Vector2i(1280, 720)
		if root.content_scale_size != desired:
			root.content_scale_size = desired
			print("TOUCH VIEWPORT: %dx%d" % [desired.x, desired.y])
	else:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player if is_inside_tree() else null


func driving() -> bool:
	var p := _player()
	return p != null and p.vehicle != null


## Panels / dialogs that need the cursor (modal panels, title, plus any node in
## group "needs_cursor" that is visible).
func blocked() -> bool:
	if GameEvents.ui_open:
		return true
	for n in get_tree().get_nodes_in_group(&"needs_cursor"):
		if n is CanvasItem and (n as CanvasItem).is_visible_in_tree():
			return true
	return false


func set_captured(on: bool) -> void:
	if on == captured:
		return
	captured = on
	_look_px = Vector2.ZERO
	mouse_steer = 0.0
	_had_lock = false
	soft_capture = false
	if on:
		captures += 1
		_capture_grace = 1.2
		# A clicked HUD button keeps keyboard focus; Space (ui_accept) would press it again.
		if is_inside_tree():
			get_viewport().gui_release_focus()
	else:
		releases += 1
	if not _headless:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if on else Input.MOUSE_MODE_VISIBLE
	capture_changed.emit(on)


## A control under the mouse that wants the click itself (buttons, sliders, text...).
func _interactive_at_mouse() -> bool:
	var c := get_viewport().gui_get_hovered_control()
	while c:
		if c is BaseButton or c is Range or c is LineEdit or c is TextEdit or c is ItemList \
				or c is Tree or c is TabBar or c is GraphEdit or c.is_in_group(&"needs_cursor"):
			return true
		c = c.get_parent() as Control
	return false


func _input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key and key.pressed and not key.echo:
		if (key.physical_keycode == KEY_SPACE or key.keycode == KEY_SPACE) and not GameEvents.ui_open and not blocked():
			# v7b.1 fix: Space is Jump. Never let it also "press" a HUD button that
			# kept focus after a click (ui_accept), which froze / toggled things.
			var f := get_viewport().gui_get_focus_owner()
			if f is BaseButton:
				f.release_focus()
				space_guards += 1
		elif key.keycode == KEY_ESCAPE and captured:
			set_captured(false)
	if event is InputEventMouseMotion:
		if event.device != InputEvent.DEVICE_ID_EMULATION and captured:
			handle_mouse_motion((event as InputEventMouseMotion).relative)
	elif event is InputEventScreenTouch:
		if (event as InputEventScreenTouch).pressed and not touch_seen:
			touch_seen = true
			if str(Settings.get_value("touch_controls")) != "off":
				set_touch_active(true)
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		# A real mouse click (not one emulated from a touch) means desktop play.
		if mb.pressed and mb.device != InputEvent.DEVICE_ID_EMULATION and touch_active and not _headless \
				and str(Settings.get_value("touch_controls")) == "auto":
			if not touch_device_available():
				set_touch_active(false)
		# v7b.1: capture on a click into the game world even when a full-screen HUD
		# control would swallow the click before _unhandled_input (buttons excluded).
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT and mb.device != InputEvent.DEVICE_ID_EMULATION \
				and not captured and not touch_active and not blocked() and not _interactive_at_mouse():
			var ms := mouse_style()
			if ms and ms.capture_on_click:
				set_captured(true)


func _unhandled_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb == null or not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT or mb.device == InputEvent.DEVICE_ID_EMULATION:
		return
	var ms := mouse_style()
	if touch_active or captured or blocked() or ms == null or not ms.capture_on_click:
		return
	set_captured(true)


## Mouse motion while captured: look (on foot / cockpit) or steer (chase cam).
func handle_mouse_motion(rel: Vector2) -> void:
	var ms := mouse_style()
	if ms == null or blocked():
		return
	_mouse_moved = true
	var sens := float(Settings.get_value("camera_sensitivity"))
	# v7b.1 bug fix (camera yaw): mouse X only steers a car that is rolling; in a
	# parked / slow car it turns the chase camera like on foot (it used to do
	# nothing there, so only up/down worked).
	if driving() and cockpit == null and ms.mouse_steer and car_rolling():
		mouse_steer = clampf(mouse_steer - rel.x * ms.steer_per_px * sens, -1.0, 1.0)
		_look_px.y += rel.y
		if absf(rel.y) > 0.0:
			_since_look = 0.0
	else:
		_since_look = 0.0
		_look_px += rel


func _dz(v: Vector2) -> Vector2:
	var ts := touch_style()
	var dz := ts.deadzone if ts else 0.12
	var l := v.length()
	if l < dz:
		return Vector2.ZERO
	return v.normalized() * minf((l - dz) / (1.0 - dz), 1.0)


## Camera yaw / pitch in degrees for this frame (consumes the mouse delta).
func take_look(delta: float) -> Vector2:
	if blocked():
		_look_px = Vector2.ZERO
		return Vector2.ZERO
	var ms := mouse_style()
	var ts := touch_style()
	var ks := keyboard_style()
	var sens := float(Settings.get_value("camera_sensitivity"))
	var inv := -1.0 if bool(Settings.get_value("camera_invert_y")) else 1.0
	var dpp := (ms.look_deg_per_px if ms else 0.16) * sens
	var out := Vector2(-_look_px.x * dpp, -_look_px.y * dpp * inv)
	_look_px = Vector2.ZERO
	var lk := _dz(touch_look)
	if lk != Vector2.ZERO and ts:
		var yaw_part := lk.x
		if driving() and cockpit == null and ts.right_stick_steers and car_rolling():
			yaw_part = 0.0
		if yaw_part != 0.0 or absf(lk.y) > 0.5:
			_since_look = 0.0
		out.x += -yaw_part * ts.look_deg_per_sec * sens * delta
		out.y += -lk.y * ts.pitch_deg_per_sec * sens * delta * inv
	if ks and ks.ad_turns and not driving() and not GameEvents.ui_open:
		var t := Input.get_action_strength(&"move_right") - Input.get_action_strength(&"move_left")
		if absf(t) > 0.05:
			out.x += -t * ks.turn_deg_per_sec * delta
	return out


## v7b.1 bug fix: above this speed (m/s) mouse X / the right stick steer the car;
## below it they turn the chase camera.
const LOOK_STEER_SPEED := 1.5


func car_rolling() -> bool:
	var p := _player()
	return p != null and p.vehicle != null and absf(float(p.vehicle.get("speed"))) > LOOK_STEER_SPEED


## Seconds since the last mouse / right-stick look input (car chase cam waits).
func since_look() -> float:
	return _since_look


## On-foot movement (Input.get_vector convention: y < 0 = forward).
func move_vector() -> Vector2:
	var k := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var ks := keyboard_style()
	if ks and ks.ad_turns:
		k.x = 0.0
	return (k + _dz(touch_move)).limit_length(1.0)


## Car steering -1..1 (+ = left): A/D, mouse wheel (chase cam), touch sticks.
func steer() -> float:
	var s := Input.get_action_strength(&"move_left") - Input.get_action_strength(&"move_right")
	var ms := mouse_style()
	if captured and cockpit == null and ms and ms.mouse_steer:
		s += mouse_steer
	var ts := touch_style()
	if ts:
		if ts.right_stick_steers and cockpit == null:
			s -= _dz(touch_look).x
		if ts.left_stick_steers:
			s -= _dz(touch_move).x
	return clampf(s, -1.0, 1.0)


func throttle() -> float:
	var t := Input.get_action_strength(&"move_forward") - Input.get_action_strength(&"move_back")
	t -= _dz(touch_move).y
	return clampf(t, -1.0, 1.0)


func brake() -> bool:
	return Input.is_action_pressed(&"jump")


## True for a moment after mouse / right-stick look input (the farmer turns
## to face where the camera looks while standing still).
func looking() -> bool:
	var ms := mouse_style()
	return _since_look < 0.2 and (ms == null or ms.face_camera_idle)


## Sends an action through the normal input pipeline (touch buttons).
func press_action(action: StringName, pressed: bool) -> void:
	if not InputMap.has_action(action):
		return
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _process(delta: float) -> void:
	_since_look += delta
	var ms := mouse_style()
	if not _mouse_moved:
		mouse_steer = move_toward(mouse_steer, 0.0, (ms.steer_return if ms else 1.6) * delta)
	_mouse_moved = false
	if captured:
		_capture_grace = maxf(_capture_grace - delta, 0.0)
		if not _headless and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			_had_lock = true
		if blocked() or touch_active:
			set_captured(false)
		elif not _headless and _capture_grace <= 0.0 and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			if _had_lock:
				# The browser released the pointer lock (Esc).
				captured = false
				releases += 1
				mouse_steer = 0.0
				capture_changed.emit(false)
			elif not soft_capture:
				# Lock refused: keep mouse look from relative motion (Esc / panels release).
				soft_capture = true
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
