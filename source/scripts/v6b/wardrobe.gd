class_name WardrobePanel
extends PanelContainer
## v6b "wardrobe" module UI: opened at the wardrobe in the farmhouse. Pick a
## top (shape) and the colours of shirt and trousers; the farmer changes
## live; Done keeps it (saved with the player's outfit + look.top).

var _top_lbl: Label
var _title: Label
var _shirts: HBoxContainer
var _pants: HBoxContainer
var _labels: Dictionary = {}
var _before: Dictionary = {}
var changes: int = 0


func _ready() -> void:
	name = "WardrobePanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(UIKit.PAPER, 14, 16, true))
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -470
	offset_right = -24
	offset_top = -190
	offset_bottom = 190
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 9)
	add_child(v)
	_title = UIKit.label(v, "", 24, UIKit.INK)
	var row := HBoxContainer.new()
	v.add_child(row)
	_labels["top"] = UIKit.label(row, "", 16, UIKit.INK)
	(_labels["top"] as Label).custom_minimum_size.x = 100
	_ltr(UIKit.button(row, ">" if Lang.is_fa() else "<", func() -> void: step_top(-1), "", 16))
	_top_lbl = UIKit.label(row, "", 16, Color(0.35, 0.2, 0.1))
	_top_lbl.custom_minimum_size.x = 170
	_top_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ltr(UIKit.button(row, "<" if Lang.is_fa() else ">", func() -> void: step_top(1), "", 16))
	_labels["shirt"] = UIKit.label(v, "", 16, UIKit.INK)
	_shirts = HBoxContainer.new()
	v.add_child(_shirts)
	_labels["pants"] = UIKit.label(v, "", 16, UIKit.INK)
	_pants = HBoxContainer.new()
	v.add_child(_pants)
	var b := HBoxContainer.new()
	v.add_child(b)
	_labels["done"] = UIKit.button(b, "", close, "", 16)
	_labels["cancel"] = UIKit.button(b, "", cancel, "", 16)


func style() -> WardrobeStyle:
	return Modules.style("wardrobe") as WardrobeStyle


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func open() -> void:
	var p := _player()
	if p == null:
		return
	_before = {"outfit": p.outfit.duplicate(), "top": str(p.appearance.get("top", (p.get_node(^"Visual") as HumanoidModelVisual).top_style))}
	visible = true
	GameEvents.open_modal("wardrobe")
	GameEvents.interaction_prompt_changed.emit("")
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	if rig:
		var r := (p.get_node(^"Visual") as Node3D).rotation.y
		rig.snap_view(rad_to_deg(r), -10.0, 3.4)
	_build_swatches()
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("wardrobe")
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	if rig:
		rig.reset_behind_target()


func cancel() -> void:
	var p := _player()
	if p:
		p.outfit = _before["outfit"]
		p.appearance["top"] = _before["top"]
		p.apply_outfit()
	close()


func _build_swatches() -> void:
	var st := style()
	for box: HBoxContainer in [_shirts, _pants]:
		for c in box.get_children():
			c.queue_free()
	if st == null:
		return
	for c: Color in st.shirt_colors:
		_swatch(_shirts, c, func() -> void: set_shirt(c))
	for c: Color in st.pants_colors:
		_swatch(_pants, c, func() -> void: set_pants(c))


func _swatch(parent: HBoxContainer, c: Color, cb: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(30, 30)
	b.focus_mode = Control.FOCUS_NONE
	var sb := UIKit.style(c, 6, 2)
	b.add_theme_stylebox_override(&"normal", sb)
	b.add_theme_stylebox_override(&"hover", UIKit.style(c.lightened(0.2), 6, 2))
	b.add_theme_stylebox_override(&"pressed", UIKit.style(c.darkened(0.2), 6, 2))
	b.pressed.connect(cb)
	parent.add_child(b)


func step_top(dir: int) -> void:
	var st := style()
	var p := _player()
	if st == null or p == null or st.tops.is_empty():
		return
	var cur := str(p.appearance.get("top", (p.get_node(^"Visual") as HumanoidModelVisual).top_style))
	var i := 0
	for k in st.tops.size():
		if str(st.tops[k].get("id", "")) == cur:
			i = k
	i = wrapi(i + dir, 0, st.tops.size())
	p.appearance["top"] = str(st.tops[i].get("id", "work_shirt"))
	p.apply_outfit()
	changes += 1
	refresh()


func set_shirt(c: Color) -> void:
	var p := _player()
	if p:
		p.outfit["shirt"] = c
		p.apply_outfit()
		changes += 1


func set_pants(c: Color) -> void:
	var p := _player()
	if p:
		p.outfit["pants"] = c
		p.apply_outfit()
		changes += 1


func refresh() -> void:
	_title.text = Lang.tt("کمد لباس", "Wardrobe")
	(_labels["top"] as Label).text = Lang.tt("بالاتنه", "Top")
	(_labels["shirt"] as Label).text = Lang.tt("رنگ پیراهن", "Shirt colour")
	(_labels["pants"] as Label).text = Lang.tt("رنگ شلوار", "Trousers colour")
	(_labels["done"] as Button).text = Lang.tt("پوشیدن", "Wear it")
	(_labels["cancel"] as Button).text = Lang.tt("انصراف", "Cancel")
	var st := style()
	var p := _player()
	if st and p:
		var cur := str(p.appearance.get("top", "work_shirt"))
		for t: Dictionary in st.tops:
			if str(t.get("id", "")) == cur:
				_top_lbl.text = str(t.get("fa" if Lang.is_fa() else "en", cur))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		cancel()
		get_viewport().set_input_as_handled()


## Arrow buttons keep their direction in the Persian (RTL) layout.
static func _ltr(b: Button) -> Button:
	b.text_direction = Control.TEXT_DIRECTION_LTR
	return b
