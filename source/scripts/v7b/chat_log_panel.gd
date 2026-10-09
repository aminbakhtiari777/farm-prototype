class_name ChatLogPanel
extends PanelContainer
## v7b optional chat log (chatter module, key 5): the last things people
## around you said, newest at the bottom, in the current language (right to
## left in Persian). Unobtrusive: no input capture, semi-transparent.

const SHOWN := 8
var _title: Label
var _body: Label


func _ready() -> void:
	name = "ChatLogPanel"
	theme = V6bWorld.ui_theme()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.05, 0.06, 0.08, 0.62), 10, 10))
	set_anchors_preset(Control.PRESET_CENTER_LEFT)
	offset_left = 12
	offset_right = 432
	offset_top = -60
	offset_bottom = 170
	custom_minimum_size = Vector2(420, 0)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = UIKit.label(v, "", 15, UIKit.GOLD)
	_body = UIKit.label(v, "", 14, Color(0.95, 0.95, 0.92))
	_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_body.custom_minimum_size = Vector2(400, 0)
	TownLife.changed.connect(func(k: String) -> void:
		if k == "chat" or k == "all":
			refresh())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			refresh())
	visible = TownLife.show_log
	refresh()


func toggle() -> void:
	TownLife.show_log = not TownLife.show_log
	visible = TownLife.show_log
	refresh()
	GameEvents.notification_requested.emit(Lang.tt("گزارش گفتگوها %s" % ("روشن" if visible else "خاموش"), "Chat log %s" % ("on" if visible else "off")))


func refresh() -> void:
	if not visible:
		return
	var fa := Lang.is_fa()
	_title.text = Lang.tt("گفتگوهای اطراف (۵)", "What people say (5)")
	var lines: PackedStringArray = []
	var log: Array = TownLife.chat_log
	for i in range(maxi(0, log.size() - SHOWN), log.size()):
		var e: Dictionary = log[i]
		var t := Lang.hour_text(float(e.get("h", 0.0)))
		lines.append("[%s] %s: %s" % [t, str(e.get("who", "")), str(e.get("fa" if fa else "en", ""))])
	_body.text = "\n".join(lines) if not lines.is_empty() else Lang.tt("هنوز کسی چیزی نگفته.", "Nobody has said anything yet.")
	var al := HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
	_title.horizontal_alignment = al
	_body.horizontal_alignment = al
	_body.text_direction = Control.TEXT_DIRECTION_RTL if fa else Control.TEXT_DIRECTION_LTR
