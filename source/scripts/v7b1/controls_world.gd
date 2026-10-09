class_name V7bControls
extends Node
## v7b.1 controls patch (GTA-style): builds the touch UI (TouchControls), the
## mouse-look hint, the gear indicator (A / 1-5 / R / N) and the in-car
## cockpit camera toggle (V / C while driving). The shared input values live
## in the ControlInput autoload. Modules: controls_mouse, controls_touch,
## controls_keyboard.

var touch: TouchControls
var hint: Label
var gear_panel: PanelContainer
var gear_big: Label
var gear_small: Label
var _hint_time: float = 0.0
var _ever_captured: bool = false
## Web diagnostics (?ctlprobe=1): prints "CTL:" lines to the browser console for
## Playwright (camera yaw/pitch, capture / pointer lock, touch sticks, jump state).
var _probe: bool = false
var _probe_t: float = 0.0
## ?ctlprobe=1&ctlcar=1: once the town is up, stand the player at the driver's door
## of the first parked car (web test of mouse steering / the cockpit; probe only).
var _probe_car: bool = false
var _probe_age: float = 0.0


func _ready() -> void:
	name = "V7bControls"
	_ensure_actions()
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		_probe = q is String and "ctlprobe" in str(q)
		_probe_car = _probe and "ctlcar" in str(q)
	touch = TouchControls.new()
	add_child(touch)
	var layer := CanvasLayer.new()
	layer.name = "ControlsUI"
	layer.layer = 6
	add_child(layer)
	hint = Label.new()
	hint.name = "MouseHint"
	hint.theme = V6bWorld.ui_theme()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.set_anchors_preset(Control.PRESET_CENTER_TOP)
	hint.offset_top = 52
	hint.offset_left = -360
	hint.offset_right = 360
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override(&"font_size", 15)
	hint.add_theme_color_override(&"font_color", Color(1, 1, 0.92, 0.92))
	hint.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.75))
	hint.add_theme_constant_override(&"outline_size", 4)
	hint.visible = false
	layer.add_child(hint)
	gear_panel = PanelContainer.new()
	gear_panel.name = "GearIndicator"
	gear_panel.theme = V6bWorld.ui_theme()
	gear_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gear_panel.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.06, 0.07, 0.09, 0.82), 10, 6, true))
	gear_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# left of the v7b dashboard (-360..360, -200..-142)
	gear_panel.offset_left = -470
	gear_panel.offset_right = -370
	gear_panel.offset_top = -222
	gear_panel.offset_bottom = -126
	gear_panel.visible = false
	layer.add_child(gear_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override(&"separation", 0)
	gear_panel.add_child(v)
	gear_big = UIKit.label(v, "N", 44, Color(0.55, 1.0, 0.6))
	gear_big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_small = UIKit.label(v, "", 12, Color(0.85, 0.9, 0.95))
	gear_small.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	gear_small.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gear_small.custom_minimum_size.x = 88
	ControlInput.capture_changed.connect(func(on: bool) -> void:
		if on:
			_ever_captured = true
		else:
			_hint_time = 5.0)
	_mark_cursor_panels.call_deferred()


## V / C toggle the cockpit camera while driving (C still orbits on foot).
func _ensure_actions() -> void:
	if not InputMap.has_action(&"car_camera"):
		InputMap.add_action(&"car_camera")
		for k in [KEY_V, KEY_C]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(&"car_camera", e)


## Non-modal panels that still need the cursor (mouse look pauses while open).
func _mark_cursor_panels() -> void:
	var hud: Node = get_tree().current_scene.get_node_or_null(^"HUD") if get_tree().current_scene else null
	if hud == null:
		return
	# (not the NPC card: it pops up by itself next to people and has no buttons)
	for prop in ["inventory_panel", "title_screen"]:
		var n: Variant = hud.get(prop)
		if n is CanvasItem:
			(n as CanvasItem).add_to_group(&"needs_cursor")
	var vh: Variant = hud.get("voice_hud")
	if vh is Node and (vh as Node).get("panel") is CanvasItem:
		((vh as Node).get("panel") as CanvasItem).add_to_group(&"needs_cursor")


func driven_car() -> DrivableCar:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	return p.vehicle as DrivableCar if p and p.vehicle is DrivableCar else null


func cockpit_of(car: DrivableCar, create: bool = true) -> CockpitCamera:
	if car == null:
		return null
	var c := car.get_node_or_null(^"CockpitCam") as CockpitCamera
	if c == null and create:
		c = CockpitCamera.new()
		c.name = "CockpitCam"
		car.add_child(c)
	return c


func toggle_cockpit() -> bool:
	var car := driven_car()
	if car == null:
		return false
	var c := cockpit_of(car)
	c.activate(not c.active)
	GameEvents.notification_requested.emit(Lang.tt("دوربین داخل ماشین" if c.active else "دوربین تعقیب (پشت ماشین)",
		"Cockpit camera" if c.active else "Chase camera"))
	return c.active


func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or not event.is_pressed() or GameEvents.ui_open:
		return
	if event.is_action(&"car_camera") and driven_car() != null:
		toggle_cockpit()
		get_viewport().set_input_as_handled()


static func gear_symbol(car: DrivableCar) -> PackedStringArray:
	var sys := car.get_node_or_null(^"CarSystems") as CarSystems
	if car.speed < -0.3:
		return PackedStringArray(["R", Lang.tt("دنده عقب", "Reverse")])
	var th := float(car.auto_input.get("throttle", 0.0)) if not car.auto_input.is_empty() else ControlInput.throttle()
	if absf(car.speed) < 0.3 and absf(th) < 0.05:
		return PackedStringArray(["N", Lang.tt("خلاص", "Neutral")])
	if sys == null:
		return PackedStringArray(["A", Lang.tt("خودکار", "Automatic")])
	if sys.is_auto():
		var vs := car.style()
		var g := sys.auto_gear(vs.max_speed if vs else 11.0)
		return PackedStringArray(["A", Lang.tt("خودکار · دنده %s" % Lang.digits(str(g)), "Auto · gear %d" % g)])
	return PackedStringArray([str(sys.gear), Lang.tt("دستی", "Manual")])


func probe_line() -> String:
	var fc := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	var p := get_tree().get_first_node_in_group(&"player") as Player
	var st := ""
	if p and p._visual is HumanoidModelVisual:
		st = str((p._visual as HumanoidModelVisual).current_state())
	return "CTL: yaw=%.1f pitch=%.1f captured=%s soft=%s lock=%s touch=%s move=%.2f,%.2f look=%.2f,%.2f pos=%.2f,%.2f jumps=%d anim=%s floor=%s" % [
		fc.yaw_degrees() if fc else 0.0, fc.pitch_degrees_now() if fc else 0.0,
		ControlInput.captured, ControlInput.soft_capture, Input.mouse_mode == Input.MOUSE_MODE_CAPTURED,
		ControlInput.touch_active, ControlInput.touch_move.x, ControlInput.touch_move.y,
		ControlInput.touch_look.x, ControlInput.touch_look.y,
		p.global_position.x if p else 0.0, p.global_position.z if p else 0.0,
		p.jumps if p else 0, st, p.is_on_floor() if p else false] + _probe_car_text(p)


func _probe_car_text(p: Player) -> String:
	var car := p.vehicle as DrivableCar if p and p.vehicle is DrivableCar else null
	if car == null:
		return " car=-"
	var c := cockpit_of(car, false)
	return " car=%s steer=%.2f mouse_steer=%.2f speed=%.2f car_yaw=%.1f cockpit=%s look=%.1f,%.1f gear=%s" % [car.key, car.steer_amount,
		ControlInput.mouse_steer, car.speed, rad_to_deg(car.yaw), c != null and c.active,
		c.look_yaw if c else 0.0, c.look_pitch if c else 0.0, gear_symbol(car)[0]]


func _probe_place_at_car() -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	var w := get_tree().current_scene.find_child("V6bWorld", true, false) as V6bWorld if get_tree().current_scene else null
	if p == null or w == null or w.vehicles == null or w.vehicles.cars.is_empty():
		return
	var car := w.vehicles.cars[0] as DrivableCar
	if car == null or car.door_spot == null:
		return
	_probe_car = false
	p.global_position = car.door_spot.global_position + Vector3(0, 0.3, 0)
	p.velocity = Vector3.ZERO
	print("CTL: placed at the driver's door of %s" % car.key)


func _process(delta: float) -> void:
	if _probe:
		_probe_t -= delta
		if _probe_t <= 0.0:
			_probe_t = 0.25
			print(probe_line())
		_probe_age += delta
		if _probe_car and _probe_age > 4.0:
			_probe_place_at_car()
	var car := driven_car()
	gear_panel.visible = car != null and not GameEvents.ui_open
	if gear_panel.visible:
		var g := gear_symbol(car)
		gear_big.text = g[0]
		gear_small.text = g[1]
		gear_big.add_theme_color_override(&"font_color", Color(1.0, 0.55, 0.45) if g[0] == "R" else (Color(0.95, 0.95, 0.6) if g[0] == "N" else Color(0.55, 1.0, 0.6)))
	_hint_time = maxf(_hint_time - delta, 0.0)
	var ms := ControlInput.mouse_style()
	hint.visible = ms != null and ms.show_hint and ms.capture_on_click and not ControlInput.touch_active \
			and not ControlInput.captured and not ControlInput.blocked() and (not _ever_captured or _hint_time > 0.0)
	if hint.visible:
		hint.text = Lang.tt("برای چرخاندن دوربین با ماوس روی بازی کلیک کن · Esc ماوس را آزاد می‌کند",
			"Click the game to look around with the mouse · Esc frees the cursor")
