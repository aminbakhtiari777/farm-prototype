class_name NewspaperPanel
extends PanelContainer
## v7b newspaper reader (newspaper module): a paper-coloured page with the
## masthead, the day, the news items, the weather line; older issues via
## the archive buttons. Persian (RTL) by default; issues keep both languages.

var news: Newspaper
var issue: Dictionary = {}
var _mast: Label
var _date: Label
var _items: VBoxContainer
var _weather: Label
var _prev: Button
var _next: Button


func _ready() -> void:
	name = "NewspaperPanel"
	theme = V6bWorld.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.95, 0.93, 0.86, 0.99), 6, 22, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(720, 560)
	offset_left = -360
	offset_right = 360
	offset_top = -280
	offset_bottom = 280
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	add_child(v)
	var ink := Color(0.1, 0.09, 0.08)
	_mast = UIKit.label(v, "", 34, ink)
	_mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_date = UIKit.label(v, "", 15, Color(0.3, 0.28, 0.25))
	_date.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sep := ColorRect.new()
	sep.color = ink
	sep.custom_minimum_size = Vector2(0, 3)
	v.add_child(sep)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 340)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	_items = VBoxContainer.new()
	_items.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_items.add_theme_constant_override(&"separation", 9)
	sc.add_child(_items)
	_weather = UIKit.label(v, "", 17, Color(0.1, 0.3, 0.5))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override(&"separation", 10)
	v.add_child(row)
	_prev = UIKit.button(row, "", func() -> void: _step(-1), "", 15)
	_next = UIKit.button(row, "", func() -> void: _step(1), "", 15)
	UIKit.button(row, Lang.tt("بستن", "Close"), close, "", 15)


func open_issue(d: Dictionary) -> void:
	issue = d
	visible = true
	GameEvents.open_modal("newspaper")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("newspaper")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"menu") or event.is_action_pressed(&"newspaper"):
		close()
		get_viewport().set_input_as_handled()


func _index() -> int:
	return TownLife.papers.find(issue)


func _step(d: int) -> void:
	var i := _index() + d
	if i >= 0 and i < TownLife.papers.size():
		issue = TownLife.papers[i]
		refresh()


func refresh() -> void:
	var st := news.style() if news else (Modules.style("newspaper") as NewspaperStyle)
	var fa := Lang.is_fa()
	var col := get_child(0) as Control
	Lang.apply_dir(col)
	_mast.text = (st.paper_fa if fa else st.paper_en) if st else ""
	_date.text = Lang.tt("روز %s · شماره‌ی %s" % [Lang.digits(str(int(issue.get("day", 0)))), Lang.digits(str(_index() + 1))],
		"Day %d · issue %d" % [int(issue.get("day", 0)), _index() + 1])
	V7bKit.clear_children(_items)
	var ink := Color(0.12, 0.1, 0.09)
	var items: Array = issue.get("items", [])
	if bool(issue.get("quiet", false)) and st:
		var q := UIKit.label(_items, "• " + str(st.quiet.get("fa" if fa else "en", "")), 19, ink)
		q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	for it: Dictionary in items:
		var l := UIKit.label(_items, "• " + str(it.get("fa" if fa else "en", "")), 19 if items.find(it) == 0 else 17, ink)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(640, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
	var w: Dictionary = issue.get("weather", {})
	_weather.text = str(w.get("fa" if fa else "en", ""))
	_weather.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
	_prev.text = Lang.tt("شماره‌ی قبلی", "Previous issue")
	_next.text = Lang.tt("شماره‌ی بعدی", "Next issue")
	_prev.disabled = _index() <= 0
	_next.disabled = _index() < 0 or _index() >= TownLife.papers.size() - 1
