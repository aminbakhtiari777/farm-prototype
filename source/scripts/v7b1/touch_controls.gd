class_name TouchControls
extends CanvasLayer
## v7b.1 "controls_touch" module UI (GTA-mobile style twin sticks):
##  - LEFT half: movement stick (camera-relative; in a car up/down = gas/brake,
##    left/right steers). RIGHT half: look stick (turns the camera and the
##    character; in a car it steers, in the cockpit it looks around).
##  - Sticks are semi-transparent, appear where the thumb lands (floating
##    variant) and track their own finger index, so both work at once.
##  - Buttons (bottom right): E / get in / get out, jump (brake in a car),
##    sprint (toggle), play-as (F2) + dig / demolish / fire while playing a
##    resident, horn / lights / cockpit camera in a car; Controls (?) and Menu
##    (Esc: closes panels / settings) at the right edge.
## Every touch is handled here first (the emulated mouse click of a touch that
## lands on a stick / button is swallowed, so nothing underneath fires twice).
## Only shown when ControlInput.touch_active (touch screens / Settings).

class Stick:
	var finger: int = -1
	var origin: Vector2 = Vector2.ZERO
	var home: Vector2 = Vector2.ZERO
	var knob: Vector2 = Vector2.ZERO
	var value: Vector2 = Vector2.ZERO


class TButton extends Control:
	var id: String = ""
	var action: StringName = &""
	var mode: String = "tap"  # tap | hold | toggle
	var fa: String = ""
	var en: String = ""
	var on: bool = false
	var down: bool = false
	var dia: float = 100.0
	var tint: Color = Color(1, 1, 1)
	var alpha: float = 0.5
	var label: Label
	func setup(theme_: Theme) -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		label = Label.new()
		label.theme = theme_
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_color_override(&"font_color", Color(1, 1, 1, 0.95))
		label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.8))
		label.add_theme_constant_override(&"outline_size", 4)
		add_child(label)
	func set_text(t: String) -> void:
		if label.text != t:
			label.text = t
	func place(center: Vector2, d: float) -> void:
		dia = d
		size = Vector2(d, d)
		position = center - size * 0.5
		label.size = size
		label.position = Vector2.ZERO
		label.add_theme_font_size_override(&"font_size", int(clampf(d * (0.3 if label.text.length() <= 2 else 0.22), 12.0, 64.0)))
		queue_redraw()
	func center() -> Vector2:
		return position + size * 0.5
	func hit(p: Vector2) -> bool:
		return visible and p.distance_to(center()) <= dia * 0.5 + dia * 0.08
	func _draw() -> void:
		var r := dia * 0.5
		var lit := down or on
		draw_circle(Vector2(r, r), r, Color(0.06, 0.08, 0.1, alpha * (1.25 if lit else 0.85)))
		draw_arc(Vector2(r, r), r - 2.0, 0.0, TAU, 48, Color(tint.r, tint.g, tint.b, minf(1.0, alpha + (0.45 if lit else 0.25))), maxf(2.0, dia * 0.035), true)


var pad: Control
var left := Stick.new()
var right := Stick.new()
var buttons: Dictionary = {}  # id -> TButton
var _fingers: Dictionary = {}  # finger index -> "L" | "R" | button id
var _emu_grab: bool = false
var _t: float = 0.0
var radius: float = 100.0
var btn: float = 110.0
## Diagnostics (smoke test / web console).
var grabs: int = 0
var max_fingers: int = 0
var _walk_start: Vector3 = Vector3.INF
var _last_state: Array = []

const BUTTONS := [
	# id, action, mode, fa, en, tint
	["interact", &"interact", "tap", "E", "E", Color(1.0, 0.85, 0.35)],
	["jump", &"jump", "tap", "پرش", "Jump", Color(0.6, 0.9, 1.0)],
	["sprint", &"sprint", "toggle", "دو", "Run", Color(0.6, 1.0, 0.6)],
	["possess", &"possess", "tap", "نقش", "Play as", Color(0.95, 0.6, 1.0)],
	["dig", &"dig", "tap", "کندن", "Dig", Color(0.85, 0.7, 0.5)],
	["demolish", &"role_demolish", "tap", "تخریب", "Demolish", Color(1.0, 0.55, 0.4)],
	["fire", &"role_fire", "tap", "آتش", "Fire", Color(1.0, 0.4, 0.25)],
	["horn", &"horn", "tap", "بوق", "Horn", Color(1.0, 0.9, 0.5)],
	["lights", &"headlights", "tap", "چراغ", "Lights", Color(1.0, 1.0, 0.75)],
	["camera", &"car_camera", "tap", "دوربین", "Camera", Color(0.7, 0.85, 1.0)],
	["help", &"open_controls", "tap", "؟", "?", Color(0.85, 0.85, 0.85)],
	["menu", &"menu", "tap", "منو", "Menu", Color(0.85, 0.85, 0.85)],
]


func style() -> TouchControlsStyle:
	return Modules.style("controls_touch") as TouchControlsStyle


func _ready() -> void:
	name = "TouchControls"
	layer = 9
	process_mode = Node.PROCESS_MODE_ALWAYS
	pad = Control.new()
	pad.name = "Sticks"
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pad.draw.connect(_draw_sticks)
	add_child(pad)
	var th := V6bWorld.ui_theme()
	for b in BUTTONS:
		var t := TButton.new()
		t.name = "Btn_" + str(b[0])
		t.id = str(b[0])
		t.action = b[1]
		t.mode = str(b[2])
		t.fa = str(b[3])
		t.en = str(b[4])
		t.tint = b[5]
		t.setup(th)
		add_child(t)
		buttons[t.id] = t
	visible = ControlInput.touch_active
	ControlInput.scheme_changed.connect(func(on: bool) -> void:
		visible = on
		_reset_all())
	get_viewport().size_changed.connect(_layout)
	Modules.on_swap("controls_touch", self, func(_m: AssetModule) -> void: _layout())
	_layout()


func _reset_all() -> void:
	for f in _fingers.keys():
		_release_finger(int(f))
	_fingers.clear()
	_emu_grab = false
	ControlInput.touch_move = Vector2.ZERO
	ControlInput.touch_look = Vector2.ZERO
	var sp := buttons.get("sprint") as TButton
	if sp and sp.on:
		sp.on = false
		ControlInput.press_action(&"sprint", false)
	pad.queue_redraw()


func screen_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _layout() -> void:
	var st := style()
	var s := screen_size()
	var short := minf(s.x, s.y)
	radius = short * (st.stick_radius if st else 0.11)
	btn = short * (st.button_size if st else 0.115)
	left.home = Vector2(short * 0.3, s.y - short * 0.3)
	right.home = Vector2(s.x - btn * 3.0 - radius * 1.35, s.y - short * 0.3)
	if not _stick_active(left):
		left.origin = left.home
	if not _stick_active(right):
		right.origin = right.home
	var a := st.opacity if st else 0.5
	for t: TButton in buttons.values():
		t.alpha = a
	_place_buttons()
	pad.queue_redraw()


func _stick_active(k: Stick) -> bool:
	return k.finger >= 0


## Bottom-right cluster; slots fill with the buttons that apply right now.
func _place_buttons() -> void:
	var s := screen_size()
	var b := btn
	var lift := _dash_lift()
	var base := {
		"interact": [Vector2(s.x - 0.85 * b, s.y - 0.85 * b - lift), 1.3],
		"jump": [Vector2(s.x - 2.25 * b, s.y - 0.6 * b - lift), 1.0],
		"sprint": [Vector2(s.x - 0.7 * b, s.y - 2.25 * b - lift), 1.0],
		"help": [Vector2(s.x - 0.6 * b, s.y * 0.5 - 0.62 * b), 0.8],
		"menu": [Vector2(s.x - 0.6 * b, s.y * 0.5 - 1.6 * b), 0.8],
	}
	var slots := [Vector2(s.x - 0.7 * b, s.y - 3.45 * b - lift), Vector2(s.x - 1.95 * b, s.y - 1.75 * b - lift),
		Vector2(s.x - 1.95 * b, s.y - 2.95 * b - lift), Vector2(s.x - 0.7 * b, s.y - 4.65 * b - lift)]
	var si := 0
	for id in ["possess", "dig", "demolish", "fire", "horn", "lights", "camera"]:
		var t := buttons[id] as TButton
		if t.visible and si < slots.size():
			base[id] = [slots[si], 0.9]
			si += 1
	for id in base:
		var t := buttons[id] as TButton
		t.place(base[id][0], b * float(base[id][1]))


## The v7b driving dashboard (bottom centre, -200..-142, 720 wide): lift the
## cluster when it would overlap (narrow / portrait screens).
func _dash_lift() -> float:
	if not ControlInput.driving():
		return 0.0
	var s := screen_size()
	var dash := Rect2(s.x * 0.5 - 360.0, s.y - 214.0, 720.0, 86.0)
	var cluster := Rect2(s.x - 3.0 * btn, s.y - 5.3 * btn, 3.0 * btn, 5.3 * btn)
	if not cluster.intersects(dash):
		return 0.0
	return s.y - dash.position.y + 8.0


func dash_overlap() -> bool:
	var s := screen_size()
	var dash := Rect2(s.x * 0.5 - 360.0, s.y - 214.0, 720.0, 86.0)
	for t: TButton in buttons.values():
		if t.visible and Rect2(t.position, t.size).intersects(dash):
			return true
	return false


# ------------------------------------------------------------------ context
func _possession() -> Possession:
	var w: Node = get_tree().current_scene.find_child("V7aWorld", true, false) if get_tree().current_scene else null
	return w.get("possession") as Possession if w else null


func _near_car(p: Player) -> bool:
	for c in get_tree().get_nodes_in_group(&"drivable_cars"):
		var car := c as DrivableCar
		if car and car.driver == null and car.door_spot and car.door_spot.global_position.distance_to(p.global_position) < 2.6:
			return true
	return false


func refresh_context() -> void:
	var p := get_tree().get_first_node_in_group(&"player") as Player
	var ui := ControlInput.blocked()
	var car := p != null and p.vehicle != null
	var ps := _possession()
	var possessed := ps != null and ps.is_active()
	var can_possess := ps != null and not car and (possessed or ps.nearest_resident() != null)
	var show := {
		"interact": not ui, "jump": not ui, "sprint": not ui and not car,
		"possess": not ui and can_possess,
		"dig": not ui and possessed and not car and ps.allowed("dig"),
		"demolish": not ui and possessed and not car and ps.allowed("demolish"),
		"fire": not ui and possessed and not car and ps.allowed("fire"),
		"horn": not ui and car, "lights": not ui and car, "camera": not ui and car,
		"help": not ui, "menu": true,
	}
	var fa := Lang.is_fa()
	for id in show:
		var t := buttons[id] as TButton
		if t.visible != bool(show[id]):
			t.visible = bool(show[id])
			if not t.visible and t.down:
				_button_up(t)
		var txt := t.fa if fa else t.en
		match id:
			"interact":
				if car:
					txt = Lang.tt("پیاده", "Exit")
				elif p and _near_car(p):
					txt = Lang.tt("سوار", "Get in")
			"jump":
				if car:
					txt = Lang.tt("ترمز", "Brake")
			"possess":
				if possessed:
					txt = Lang.tt("بازگشت", "Return")
		t.mode = "hold" if (id == "jump" and car) else ("toggle" if id == "sprint" else "tap")
		t.set_text(txt)
	if ui:
		_release_sticks()
	_place_buttons()


func _process(delta: float) -> void:
	if not visible:
		return
	_t -= delta
	var state := [ControlInput.blocked(), ControlInput.driving()]
	if _t <= 0.0 or state != _last_state:
		_t = 0.2
		_last_state = state
		refresh_context()
		pad.queue_redraw()


# ------------------------------------------------------------------ touch input
func _button_at(p: Vector2) -> TButton:
	for t: TButton in buttons.values():
		if t.hit(p):
			return t
	return null


## Which control a new touch at p would grab ("" = none, let the GUI have it).
func _would_grab(p: Vector2) -> String:
	if not visible:
		return ""
	var t := _button_at(p)
	if t:
		return t.id
	if ControlInput.blocked():
		return ""
	var st := style()
	var s := screen_size()
	if p.y < s.y * (st.zone_top if st else 0.28):
		return ""
	if p.x < s.x * 0.45 and left.finger < 0:
		return "L"
	if p.x > s.x * 0.5 and right.finger < 0:
		return "R"
	return ""


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		var e := event as InputEventScreenTouch
		if e.pressed:
			var what := _would_grab(e.position)
			if what == "":
				return
			_fingers[e.index] = what
			max_fingers = maxi(max_fingers, _fingers.size())
			grabs += 1
			if what == "L" or what == "R":
				var k := left if what == "L" else right
				k.finger = e.index
				var st := style()
				k.origin = e.position if (st == null or st.floating) else k.home
				_update_stick(k, e.position)
				if what == "L":
					var p := get_tree().get_first_node_in_group(&"player") as Player
					_walk_start = p.global_position if p else Vector3.INF
			else:
				_button_down(buttons[what] as TButton)
			get_viewport().set_input_as_handled()
		elif _fingers.has(e.index):
			_release_finger(e.index)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _fingers.has(d.index):
			return
		var what2 := str(_fingers[d.index])
		if what2 == "L":
			_update_stick(left, d.position)
		elif what2 == "R":
			_update_stick(right, d.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		# Godot emulates a mouse click for the first finger *before* the touch
		# event arrives: swallow it when that touch belongs to a stick / button.
		var mb := event as InputEventMouseButton
		if mb.pressed:
			_emu_grab = _would_grab(mb.position) != ""
			if _emu_grab:
				get_viewport().set_input_as_handled()
		elif _emu_grab:
			_emu_grab = false
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.device == InputEvent.DEVICE_ID_EMULATION and _emu_grab:
		get_viewport().set_input_as_handled()


func _update_stick(k: Stick, p: Vector2) -> void:
	var off := p - k.origin
	if off.length() > radius:
		var st := style()
		if st == null or st.floating:
			# Drag past the rim: the base follows the thumb (GTA mobile feel).
			k.origin = p - off.normalized() * radius
		off = off.limit_length(radius)
	k.knob = off
	k.value = off / maxf(radius, 1.0)
	if k == left:
		ControlInput.touch_move = k.value
	else:
		ControlInput.touch_look = k.value
	pad.queue_redraw()


func _release_finger(index: int) -> void:
	var what := str(_fingers.get(index, ""))
	_fingers.erase(index)
	if what == "L" or what == "R":
		var k := left if what == "L" else right
		k.finger = -1
		k.knob = Vector2.ZERO
		k.value = Vector2.ZERO
		k.origin = k.home
		if what == "L":
			ControlInput.touch_move = Vector2.ZERO
			var p := get_tree().get_first_node_in_group(&"player") as Player
			if p and _walk_start != Vector3.INF:
				print("TouchControls: left stick released, player moved %.2f m" % Vector2(p.global_position.x - _walk_start.x, p.global_position.z - _walk_start.z).length())
			_walk_start = Vector3.INF
		else:
			ControlInput.touch_look = Vector2.ZERO
		pad.queue_redraw()
	elif buttons.has(what):
		_button_up(buttons[what] as TButton)


func _release_sticks() -> void:
	for f in _fingers.keys():
		var what := str(_fingers[f])
		if what == "L" or what == "R":
			_release_finger(int(f))


func _button_down(t: TButton) -> void:
	t.down = true
	t.queue_redraw()
	if t.mode == "toggle":
		t.on = not t.on
		ControlInput.press_action(t.action, t.on)
	else:
		ControlInput.press_action(t.action, true)


func _button_up(t: TButton) -> void:
	t.down = false
	t.queue_redraw()
	if t.mode != "toggle":
		ControlInput.press_action(t.action, false)


func _draw_sticks() -> void:
	if not visible or ControlInput.blocked():
		return
	var st := style()
	var a := st.opacity if st else 0.5
	for k: Stick in [left, right]:
		var active := k.finger >= 0
		var o := k.origin
		pad.draw_circle(o, radius, Color(0.05, 0.07, 0.09, a * (0.55 if active else 0.3)))
		pad.draw_arc(o, radius, 0.0, TAU, 64, Color(1, 1, 1, a * (0.9 if active else 0.5)), maxf(2.0, radius * 0.03), true)
		pad.draw_circle(o + k.knob, radius * 0.42, Color(1, 1, 1, a * (0.75 if active else 0.35)))
