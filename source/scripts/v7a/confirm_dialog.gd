class_name V7aConfirmDialog
extends PanelContainer
## v7a confirmation dialog for destructive acts (Persian by default, English
## toggle). ask(title, body, on_yes) - Yes runs the callable, No / Esc cancels.

var _title: Label
var _body: Label
var _yes: Button
var _no: Button
var _cb: Callable
var answered: String = ""


func _ready() -> void:
	name = "ConfirmDialog"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(UIKit.PAPER, 14, 20, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(520, 0)
	offset_left = -260
	offset_right = 260
	offset_top = -110
	offset_bottom = 110
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 12)
	add_child(v)
	_title = UIKit.label(v, "", 24, Color(0.7, 0.15, 0.1))
	_body = UIKit.label(v, "", 17, UIKit.INK)
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size.x = 480
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_yes = UIKit.button(row, "", func() -> void: answer(true), "", 17)
	_no = UIKit.button(row, "", func() -> void: answer(false), "", 17)


func ask(title: String, body: String, on_yes: Callable) -> void:
	_cb = on_yes
	answered = ""
	_title.text = title
	_body.text = body
	_yes.text = Lang.tt("بله، انجام بده", "Yes, do it")
	_no.text = Lang.tt("نه، منصرف شدم", "No, cancel")
	Lang.apply_dir(get_child(0) as Control)
	for l: Label in [_title, _body]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if Lang.is_fa() else HORIZONTAL_ALIGNMENT_LEFT
	visible = true
	GameEvents.open_modal("confirm")
	reset_size()


func answer(yes: bool) -> void:
	if not visible:
		return
	visible = false
	answered = "yes" if yes else "no"
	GameEvents.close_modal("confirm")
	if yes and _cb.is_valid():
		_cb.call()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		answer(false)
		get_viewport().set_input_as_handled()
