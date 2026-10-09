class_name VoiceHud
extends Control
## Voice UI (client only): mic indicator + level meter + status line in the
## bottom-right corner while push-to-talk is held (and briefly after), and the
## voice panel (L) with the server status and the per-player mute list stub.

const DEMO_PEERS := ["Neighbor 1", "Neighbor 2", "Neighbor 3"]

var indicator: PanelContainer
var panel: PanelContainer
var _mic: Control
var _status: Label
var _meter: ProgressBar
var _panel_status: Label
var _mute_box: VBoxContainer
var _linger: float = 0.0


func _ready() -> void:
	name = "VoiceHud"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator = PanelContainer.new()
	indicator.name = "MicIndicator"
	indicator.add_theme_stylebox_override(&"panel", UIKit.style(UIKit.DARK, 10, 10))
	indicator.anchor_left = 1.0
	indicator.anchor_right = 1.0
	indicator.anchor_top = 1.0
	indicator.anchor_bottom = 1.0
	indicator.offset_left = -330.0
	indicator.offset_right = -16.0
	indicator.offset_top = -86.0
	indicator.offset_bottom = -16.0
	indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	indicator.grow_vertical = Control.GROW_DIRECTION_BEGIN  # taller content grows upwards, not off-screen
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator.visible = false
	add_child(indicator)
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 10)
	indicator.add_child(h)
	_mic = Control.new()
	_mic.custom_minimum_size = Vector2(30, 40)
	_mic.draw.connect(_draw_mic)
	h.add_child(_mic)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	_status = UIKit.label(v, "Talking...", 15, Color(1, 1, 1))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size.x = 250
	_meter = ProgressBar.new()
	_meter.custom_minimum_size = Vector2(240, 10)
	_meter.max_value = 1.0
	_meter.show_percentage = false
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fill := UIKit.style(Color(0.4, 0.9, 0.45), 4, 0)
	_meter.add_theme_stylebox_override(&"fill", fill)
	_meter.add_theme_stylebox_override(&"background", UIKit.style(Color(1, 1, 1, 0.15), 4, 0))
	v.add_child(_meter)
	_build_panel()
	VoiceClient.state_changed.connect(func(_s: String) -> void: _refresh())
	VoiceClient.level_changed.connect(func(l: float) -> void: _meter.value = l)


func _build_panel() -> void:
	panel = PanelContainer.new()
	panel.name = "VoicePanel"
	panel.visible = false
	panel.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.08, 0.07, 0.06, 0.86), 10, 14))
	panel.anchor_left = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = -360.0
	panel.offset_right = -16.0
	panel.offset_top = 64.0
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIKit.label(head, "Voice chat", 20, UIKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button(head, "x", func() -> void: panel.visible = false, "Close (L)")
	_panel_status = UIKit.label(v, "", 15, Color(1, 0.9, 0.8))
	_panel_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_panel_status.custom_minimum_size.x = 320
	var hint := UIKit.label(v, "Hold V (or D-pad down) to talk. Nearby players are louder; voices fade out by %d m." % int(VoiceClient.config.get("proximity", {}).get("max_distance", 25)), 13, Color(0.85, 0.85, 0.85))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.custom_minimum_size.x = 320
	v.add_child(HSeparator.new())
	UIKit.label(v, "Mute list (preview - no players online yet)", 14, Color(0.8, 0.9, 1.0))
	_mute_box = VBoxContainer.new()
	v.add_child(_mute_box)
	for peer: String in DEMO_PEERS:
		var cb := CheckButton.new()
		cb.text = peer
		cb.focus_mode = Control.FOCUS_NONE
		cb.button_pressed = VoiceClient.is_muted(peer)
		cb.toggled.connect(func(on: bool) -> void: VoiceClient.set_muted(peer, on))
		cb.tooltip_text = "Mute " + peer
		_mute_box.add_child(cb)
	UIKit.label(v, "(toggle = muted)", 12, Color(0.7, 0.7, 0.7))


func toggle_panel() -> void:
	panel.visible = not panel.visible
	_refresh()


func _process(delta: float) -> void:
	if VoiceClient.talking:
		_linger = 2.5
	else:
		_linger = maxf(_linger - delta, 0.0)
	var should_show := VoiceClient.talking or _linger > 0.0
	if indicator.visible != should_show:
		indicator.visible = should_show
		_refresh()
	if should_show:
		_mic.queue_redraw()


func _refresh() -> void:
	var talking := VoiceClient.talking
	var head := "Talking" if talking else "Mic off"
	if VoiceClient.state == "requesting_mic":
		head = "Requesting microphone..."
	_status.text = "%s - %s" % [head, VoiceClient.status_text()]
	_panel_status.text = "Status: %s\nMicrophone: %s\nServer: %s" % [VoiceClient.state.replace("_", " "), VoiceClient.mic_state,
		"configured" if VoiceClient.is_configured() else "Voice server not configured"]


func _draw_mic() -> void:
	var on := VoiceClient.talking and VoiceClient.mic_state == "granted"
	var col := Color(0.35, 0.95, 0.45) if on else (Color(1.0, 0.8, 0.3) if VoiceClient.talking else Color(0.7, 0.7, 0.7))
	var c := Vector2(15, 16)
	_mic.draw_rect(Rect2(c + Vector2(-5, -12), Vector2(10, 18)), col)
	_mic.draw_circle(c + Vector2(0, -12), 5.0, col)
	_mic.draw_circle(c + Vector2(0, 6), 5.0, col)
	_mic.draw_arc(c + Vector2(0, 2), 9.0, 0.0, PI, 12, col, 2.0, true)
	_mic.draw_line(c + Vector2(0, 11), c + Vector2(0, 18), col, 2.0)
	if VoiceClient.talking:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.01)
		_mic.draw_circle(c + Vector2(12, -12), 3.0 + pulse, Color(1, 0.3, 0.3))
