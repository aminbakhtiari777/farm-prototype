class_name UIKit
extends RefCounted
## Small helpers so every panel looks the same (warm, rounded, readable).

const DARK := Color(0.08, 0.07, 0.06, 0.72)
const PAPER := Color(0.96, 0.92, 0.83, 0.97)
const INK := Color(0.25, 0.16, 0.09)
const GOLD := Color(1.0, 0.85, 0.35)


static func style(bg: Color, radius: int = 10, margin: int = 10, shadow: bool = false) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(margin)
	if shadow:
		s.shadow_color = Color(0, 0, 0, 0.35)
		s.shadow_size = 10
	return s


static func label(parent: Node, text: String, size: int = 16, color: Color = Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if parent:
		parent.add_child(l)
	return l


static func button(parent: Node, text: String, callback: Callable, tooltip: String = "", size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tooltip
	b.focus_mode = Control.FOCUS_NONE  # keep Space/E for the game
	b.add_theme_font_size_override(&"font_size", size)
	b.pressed.connect(callback)
	if parent:
		parent.add_child(b)
	return b


static func modal_panel(title: String, min_size: Vector2) -> Dictionary:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override(&"panel", style(PAPER, 14, 18, true))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = min_size
	panel.offset_left = -min_size.x * 0.5
	panel.offset_right = min_size.x * 0.5
	panel.offset_top = -min_size.y * 0.5
	panel.offset_bottom = min_size.y * 0.5
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	panel.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := label(head, title, 24, INK)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := button(head, "Close (Esc)", func() -> void: pass, "Close")
	return {"panel": panel, "body": v, "close": close, "title": t}
