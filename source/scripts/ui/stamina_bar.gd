class_name StaminaBar
extends Control
## Bottom-left stamina bar + watering can level. Turns orange/red when low
## and shows "Exhausted" until the player has recovered.

var value: float = 1.0
var exhausted: bool = false
var _label: Label
var _water: Label


func _ready() -> void:
	name = "StaminaBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 20.0
	offset_right = 280.0
	offset_top = -64.0
	offset_bottom = -16.0
	_label = UIKit.label(self, Lang.tt("انرژی", "Stamina"), 14, Color(1, 1, 1, 0.95))
	_label.position = Vector2(0, -2)
	_label.add_theme_constant_override(&"outline_size", 4)
	_label.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	_water = UIKit.label(self, "", 14, Color(0.7, 0.9, 1.0))
	_water.position = Vector2(150, -2)
	_water.add_theme_constant_override(&"outline_size", 4)
	_water.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.7))
	GameEvents.stamina_changed.connect(_on_stamina)
	Economy.water_changed.connect(func(w: int, c: int) -> void: _water.text = _can_text(w, c))
	_water.text = _can_text(Economy.water, Economy.can_capacity())
	# v6a: Persian labels by default (Lang).
	GameEvents.setting_changed.connect(func(_k: String, _v: Variant) -> void:
		_water.text = _can_text(Economy.water, Economy.can_capacity())
		_on_stamina(_last[0], _last[1], exhausted))


var _last: Array = [100.0, 100.0]


static func _can_text(w: int, c: int) -> String:
	return Lang.tt("آبپاش %s/%s" % [Lang.digits(str(w)), Lang.digits(str(c))], "Can %d/%d" % [w, c])


func _on_stamina(current: float, maximum: float, is_exhausted: bool) -> void:
	value = clampf(current / maxf(maximum, 1.0), 0.0, 1.0)
	exhausted = is_exhausted
	_last = [current, maximum]
	if Lang.is_fa():
		_label.text = "خسته‌ای - استراحت کن!" if exhausted else "انرژی %s" % Lang.digits(str(roundi(current)))
	else:
		_label.text = "Exhausted - rest!" if exhausted else "Stamina %d" % roundi(current)
	queue_redraw()


func _draw() -> void:
	var r := Rect2(Vector2(0, 22), Vector2(240, 14))
	draw_rect(r.grow(2), Color(0, 0, 0, 0.45))
	var col := Color(0.45, 0.85, 0.35)
	if exhausted:
		col = Color(0.9, 0.25, 0.2)
	elif value < 0.35:
		col = Color(0.95, 0.6, 0.2)
	draw_rect(Rect2(r.position, Vector2(r.size.x * value, r.size.y)), col)
