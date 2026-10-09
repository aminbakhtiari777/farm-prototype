class_name ControlsMenu
extends Control
## Controls reference (F1, "?" or the Controls button in Settings; Esc
## closes). Built from the live InputMap, so rebinding an action in
## project.godot updates this screen automatically. Every non-ui_ action
## must be listed in CATEGORIES (the smoke test checks it); anything missing
## would still show up under "Other".

const CATEGORIES := [
	["Movement", [["move_forward", "Walk forward"], ["move_back", "Walk back"], ["move_left", "Walk left"], ["move_right", "Walk right"],
		["sprint", "Sprint (uses stamina)"], ["jump", "Jump"], ["sit", "Sit on the ground / stand up"]]],
	["Camera", [["camera_orbit", "Orbit (hold + drag)"], ["camera_left", "Orbit left"], ["camera_right", "Orbit right"],
		["camera_up", "Tilt up"], ["camera_down", "Tilt down"], ["zoom_in", "Zoom in"], ["zoom_out", "Zoom out"], ["camera_reset", "Reset behind farmer"]]],
	["Interaction & Tools", [["interact", "Interact: farm, talk, doors, sit on benches, TV, fish at water"], ["pick_up", "Pick up / place carryable"],
		["cycle_seed", "Choose seed"], ["toggle_inventory", "Inventory (bag)"], ["people_panel", "Town directory (people, families, jobs)"], ["market_prices", "Market prices board (price trends, town economy)"]]],
	["Time & World", [["time_pause", "Pause / resume clock"], ["time_slower", "Slower clock"], ["time_faster", "Faster clock"],
		["toggle_day_night", "Day/night cycle on/off"], ["next_season", "Jump to next season"], ["toggle_minimap", "Minimap on/off"]]],
	["Voice", [["push_to_talk", "Push to talk (hold)"], ["voice_panel", "Voice status & mute list"]]],
	["Online (beta)", [["online_panel", "Online panel: connect / go offline, players, module updates"], ["chat", "Chat (type, Enter to send)"]]],
	["Character & Car", [["character_panel", "Character creator (look, name, job)"], ["horn", "Car horn (while driving)"],
		["dig", "Dig a hole / fill it in (on foot)"], ["headlights", "Headlights on / off (while driving)"],
		["gear_mode", "Gearbox automatic / manual (while driving)"], ["gear_up", "Shift up (manual gearbox)"], ["gear_down", "Shift down (manual gearbox)"],
		["camp", "Set up / pack a camp (tent + campfire) at a camp spot"], ["car_camera", "Cockpit / chase camera (while driving)"]]],
	["Town Life", [["possess", "Play as the townsperson next to you / return (F2)"], ["role_demolish", "While playing a resident: demolish your own house (asks first)"],
		["role_fire", "While playing a resident: start a fire (asks first)"], ["city_panel", "City Hall panel: city fund, fines, public works"],
		["newspaper", "Read the newspaper"], ["chat_log", "Chat log on / off (what people say)"], ["haggle", "Haggle / trade with the townsperson next to you"], ["license_panel", "Driver license / traffic fines"]]],
	["System", [["menu", "Settings menu / close panels"], ["open_settings", "Settings"], ["open_controls", "This controls screen"],
		["quick_save", "Save"], ["quick_load", "Load"], ["toggle_sound", "Sound on/off"], ["toggle_shadows", "Shadow quality"],
		["toggle_hints", "Contextual prompts on/off"], ["quit", "Quit (desktop)"]]],
]

const NOTES := {
	"Interaction & Tools": "Fishing: stand at the beach, pier or pond with a fishing rod and press Interact; press it again when the bobber dips (\"!\").\nCarrying: E or F picks up crates, buckets, pumpkins...; the blue ghost shows where it will be placed.\nCrafting: buy planks / iron / stone / wire in town, craft at the farm Workshop bench; cook meals at any home stove.",
	"Movement": "Stamina drains while sprinting and jumping. At 0 you're exhausted (slow walk) until it recovers - rest by sitting (X or a bench).",
	"Time & World": "Lights switch on at sunset. The main power switch is on the farmhouse wall (and on the pole at the town entrance): cut it and homes use candles, lanterns and the fireplace.",
	"Online (beta)": "Single player and offline by default. Press U, enter a server address (wss://...) and Connect to play together. If the server drops, you keep playing and your save syncs when it is back.",
	"Voice": "Voice chat is client-only for now: no server is configured yet (see docs/VOICE_SETUP.md).",
	"Town Life": "Stand next to a townsperson and press F2 to live their life for a while: you keep their name, job, home and memories. Destructive choices ask first and have consequences - fines go to the city fund, the police take a report, people remember. Press E on two people arguing to calm them down. The fire brigade (125) and the electricity crew answer emergencies. The terrace cafe next to the Cafe opens in the afternoon (DJ at night); buy the daily paper at the newsstand by the square.",
	"Character & Car": "Cars: walk to a parked car's driver door and press E. W/S drive, A/D steer, Space handbrake, E get out. H headlights (needed at night), 3 manual/auto gearbox, Shift/Ctrl change gear. Fuel and repairs at the mechanic on Main St; pick up waving passengers (yellow beam) for coins. Change clothes at the farmhouse wardrobe; the mirror next to it opens the character creator.",
}

var tabs: TabContainer
var _panel: PanelContainer
var _title: Label
var _close: Button


func _ready() -> void:
	name = "ControlsMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.4)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := UIKit.modal_panel("Controls", Vector2(820, 560))
	_panel = m["panel"]
	_title = m.get("title") as Label
	_close = m.get("close") as Button
	add_child(_panel)
	(m["close"] as Button).pressed.connect(close)
	var body: VBoxContainer = m["body"]
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.focus_mode = Control.FOCUS_NONE
	# Light "paper" page behind the rows (the default dark panel made brown text unreadable).
	tabs.add_theme_stylebox_override(&"panel", UIKit.style(Color(1.0, 0.98, 0.93, 1.0), 6, 10))
	body.add_child(tabs)
	_build()
	# v6b: Persian / English labels, rebuilt when the language changes.
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			_build())


func _build() -> void:
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	if _title:
		_title.text = Lang.t("Controls")
	if _close:
		_close.text = Lang.t("Close (Esc)")
	for cat in CATEGORIES:
		_add_tab(str(cat[0]), cat[1])
	# v7b.1: GTA-style mouse / touch controls tab.
	ControlsHelp.build_tab(tabs)
	var other := uncategorized_actions()
	if not other.is_empty():
		var rows: Array = []
		for a in other:
			rows.append([a, a.capitalize()])
		_add_tab("Other", rows)


func _add_tab(title: String, rows: Array) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	tabs.add_child(scroll)
	tabs.set_tab_title(tabs.get_tab_count() - 1, Lang.t(title))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override(&"separation", 6)
	scroll.add_child(v)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override(&"h_separation", 18)
	grid.add_theme_constant_override(&"v_separation", 6)
	v.add_child(grid)
	for h in ["Action", "Keyboard / mouse", "Gamepad"]:
		UIKit.label(grid, Lang.t(h), 15, Color(0.45, 0.28, 0.12))
	for r in rows:
		var action := StringName(r[0])
		if not InputMap.has_action(action):
			continue
		var l := UIKit.label(grid, Lang.t(str(r[1])), 16, UIKit.INK)
		l.custom_minimum_size.x = 330
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var k := UIKit.label(grid, " / ".join(events_text(action, false)), 16, Color(0.1, 0.25, 0.45))
		k.custom_minimum_size.x = 220
		UIKit.label(grid, " / ".join(events_text(action, true)), 16, Color(0.2, 0.4, 0.2))
	if NOTES.has(title):
		var n := UIKit.label(v, Lang.t(NOTES[title]), 14, Color(0.35, 0.28, 0.2))
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		n.custom_minimum_size.x = 760


static func listed_actions() -> Array[StringName]:
	var out: Array[StringName] = []
	for cat in CATEGORIES:
		for r in cat[1]:
			out.append(StringName(r[0]))
	return out


static func uncategorized_actions() -> Array[StringName]:
	var listed := listed_actions()
	var out: Array[StringName] = []
	for a in InputMap.get_actions():
		if str(a).begins_with("ui_") or a in listed:
			continue
		out.append(a)
	return out


static func events_text(action: StringName, gamepad: bool) -> PackedStringArray:
	var out := PackedStringArray()
	for e in InputMap.action_get_events(action):
		var t := ""
		if gamepad:
			if e is InputEventJoypadButton:
				t = _joy_button_name((e as InputEventJoypadButton).button_index)
			elif e is InputEventJoypadMotion:
				var jm := e as InputEventJoypadMotion
				t = _joy_axis_name(jm.axis, jm.axis_value)
		else:
			if e is InputEventKey:
				var k := e as InputEventKey
				var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
				t = ("Ctrl+" if k.ctrl_pressed else "") + _key_name(code)
			elif e is InputEventMouseButton:
				t = _mouse_name((e as InputEventMouseButton).button_index)
		if t != "" and t not in out:
			out.append(t)
	if out.is_empty():
		out.append("-")
	return out


static func _key_name(code: Key) -> String:
	match code:
		KEY_SPACE:
			return "Space"
		KEY_COMMA:
			return ","
		KEY_PERIOD:
			return "."
		KEY_SLASH:
			return "? (/)"
		KEY_BRACKETLEFT:
			return "["
		KEY_BRACKETRIGHT:
			return "]"
		KEY_EQUAL:
			return "+ (=)"
		KEY_MINUS:
			return "-"
	return OS.get_keycode_string(code)


static func _mouse_name(b: MouseButton) -> String:
	match b:
		MOUSE_BUTTON_LEFT:
			return "Left mouse"
		MOUSE_BUTTON_RIGHT:
			return "Right mouse"
		MOUSE_BUTTON_MIDDLE:
			return "Middle mouse"
		MOUSE_BUTTON_WHEEL_UP:
			return "Wheel up"
		MOUSE_BUTTON_WHEEL_DOWN:
			return "Wheel down"
	return "Mouse %d" % b


static func _joy_button_name(b: JoyButton) -> String:
	var names := {JOY_BUTTON_A: "A", JOY_BUTTON_B: "B", JOY_BUTTON_X: "X", JOY_BUTTON_Y: "Y", JOY_BUTTON_BACK: "Back/View",
		JOY_BUTTON_START: "Start/Menu", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3", JOY_BUTTON_LEFT_SHOULDER: "LB",
		JOY_BUTTON_RIGHT_SHOULDER: "RB", JOY_BUTTON_DPAD_UP: "D-pad up", JOY_BUTTON_DPAD_DOWN: "D-pad down",
		JOY_BUTTON_DPAD_LEFT: "D-pad left", JOY_BUTTON_DPAD_RIGHT: "D-pad right"}
	return names.get(b, "Button %d" % b)


static func _joy_axis_name(axis: JoyAxis, value: float) -> String:
	match axis:
		JOY_AXIS_LEFT_X:
			return "Left stick " + ("right" if value > 0 else "left")
		JOY_AXIS_LEFT_Y:
			return "Left stick " + ("down" if value > 0 else "up")
		JOY_AXIS_RIGHT_X:
			return "Right stick " + ("right" if value > 0 else "left")
		JOY_AXIS_RIGHT_Y:
			return "Right stick " + ("down" if value > 0 else "up")
		JOY_AXIS_TRIGGER_LEFT:
			return "LT"
		JOY_AXIS_TRIGGER_RIGHT:
			return "RT"
	return "Axis %d" % axis


func open() -> void:
	visible = true
	GameEvents.open_modal("controls")
	GameEvents.interaction_prompt_changed.emit("")


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("controls")
