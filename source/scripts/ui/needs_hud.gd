class_name NeedsHud
extends Control
## v5b needs HUD (bottom-left, above stamina): hunger meter (how full you
## are + meals today), fatigue meter and health status (healthy / cold:
## sneezing, unwell, slower). Persian or English labels.

var _hunger_l: Label
var _fatigue_l: Label
var _status_l: Label
var _timer: float = 0.0


func _ready() -> void:
	name = "NeedsHud"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 20.0
	offset_right = 300.0
	offset_top = -178.0
	offset_bottom = -66.0
	_hunger_l = _lbl(Vector2(0, -2))
	_fatigue_l = _lbl(Vector2(0, 36))
	_status_l = _lbl(Vector2(0, 74))
	Needs.changed.connect(refresh)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			refresh())
	refresh()


func _lbl(p: Vector2) -> Label:
	var l := UIKit.label(self, "", 14, Color(1, 1, 1, 0.95))
	l.position = p
	l.add_theme_constant_override(&"outline_size", 4)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.75))
	return l


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		refresh()


func refresh() -> void:
	var fa := Lang.is_fa()
	var dir := Control.TEXT_DIRECTION_RTL if fa else Control.TEXT_DIRECTION_AUTO
	for l: Label in [_hunger_l, _fatigue_l, _status_l]:
		l.text_direction = dir
	var st := Needs.style()
	var per_day := st.meals_per_day if st else 1
	var meals := "%d/%d" % [Needs.meals_today, per_day]
	if fa:
		_hunger_l.text = "سیری %s٪، وعده امروز %s%s" % [Lang.digits(str(int(Needs.hunger))), Lang.digits(meals), " — گرسنه!" if Needs.is_hungry() else ""]
		_fatigue_l.text = "خستگی %s٪%s" % [Lang.digits(str(int(Needs.fatigue))), " — خسته!" if Needs.is_tired() else ""]
	else:
		_hunger_l.text = "Hunger: %d%% full · meals today %s%s" % [int(Needs.hunger), meals, " - hungry!" if Needs.is_hungry() else ""]
		_fatigue_l.text = "Fatigue %d%%%s" % [int(Needs.fatigue), " - tired!" if Needs.is_tired() else ""]
	var d := Needs.illness_def(Needs.illness)
	if d:
		var slow := int(round((1.0 - Needs.player_speed_factor()) * 100.0))
		_status_l.text = ("%s: %s (%s٪ کندتر) — دکتر بیمارستان" % [d.name_fa, d.symptoms_fa, Lang.digits(str(slow))]) if fa else "%s: %s (-%d%% speed) - see the doctor" % [d.display_name, d.symptoms_en, slow]
		_status_l.add_theme_color_override(&"font_color", Color(1.0, 0.65, 0.5))
	else:
		_status_l.text = "سالم" if fa else "Healthy"
		_status_l.add_theme_color_override(&"font_color", Color(0.7, 1.0, 0.7))
	queue_redraw()


func _bar(y: float, v: float, col: Color) -> void:
	var r := Rect2(Vector2(0, y), Vector2(240, 10))
	draw_rect(r.grow(2), Color(0, 0, 0, 0.45))
	draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(v, 0.0, 1.0), r.size.y)), col)


func _draw() -> void:
	var hc := Color(0.95, 0.65, 0.2) if not Needs.is_hungry() else Color(0.95, 0.3, 0.2)
	_bar(22, Needs.hunger / 100.0, hc)
	_bar(60, Needs.fatigue / 100.0, Color(0.6, 0.45, 0.9) if not Needs.is_tired() else Color(0.85, 0.35, 0.75))
