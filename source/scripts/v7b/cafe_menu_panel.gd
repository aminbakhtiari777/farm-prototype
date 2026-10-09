class_name CafeMenuPanel
extends PanelContainer
## v7b terrace cafe drinks menu (cafe module): every drink with its price;
## strong drinks are marked (mild, short tipsiness; daily limit; never drive).

var cafe: TerraceCafe
var _title: Label
var _note: Label
var _items: VBoxContainer
var _status: Label
var buttons: Dictionary = {}   ## drink id -> Button


func _ready() -> void:
	name = "CafeMenuPanel"
	theme = V6bWorld.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.16, 0.1, 0.08, 0.96), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(560, 500)
	offset_left = -280
	offset_right = 280
	offset_top = -250
	offset_bottom = 250
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title = UIKit.label(v, "", 24, UIKit.GOLD)
	_note = UIKit.label(v, "", 14, Color(0.9, 0.85, 0.75))
	_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_items = VBoxContainer.new()
	_items.add_theme_constant_override(&"separation", 5)
	v.add_child(_items)
	_status = UIKit.label(v, "", 15, Color(0.85, 1.0, 0.85))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.button(v, Lang.tt("بستن", "Close"), close, "", 16)


func open() -> void:
	visible = true
	GameEvents.open_modal("cafe_menu")
	_status.text = ""
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("cafe_menu")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func buy(id: String) -> String:
	var r := cafe.order(id) if cafe else "none"
	var m := cafe.menu_item(id) if cafe else {}
	match r:
		"ok":
			_status.text = Lang.tt("نوش جان! %s" % str(m.get("fa", "")), "Enjoy your %s!" % str(m.get("en", "")))
		"refused":
			_status.text = Lang.tt("بارمن دیگر نوشیدنی قوی نمی‌دهد - یک چای مهمانت کرد.", "The bartender won't serve more strong drinks - a tea on the house.")
		"poor":
			_status.text = Lang.tt("پول کافی نداری.", "Not enough money.")
		_:
			_status.text = Lang.tt("الان سرو نمی‌شود.", "Not served right now.")
	refresh()
	return r


func refresh() -> void:
	var st := cafe.style() if cafe else null
	var fa := Lang.is_fa()
	Lang.apply_dir(get_child(0) as Control)
	_title.text = Lang.tt("منوی کافه‌ی تراس", "Terrace cafe menu")
	_note.text = Lang.tt("نوشیدنی‌های قوی کمی سرگیجه می‌آورند (کوتاه). حداکثر %s تا در روز. بعدش رانندگی نکن - پلیس جریمه می‌کند." % Lang.digits(str(st.max_strong if st else 2)),
		"Strong drinks make you a little tipsy for a short while. Max %d a day. Don't drive afterwards - the police fine it." % (st.max_strong if st else 2))
	V7bKit.clear_children(_items)
	buttons.clear()
	if st == null:
		return
	for m: Dictionary in st.menu:
		var id := str(m.get("id", ""))
		var strong := str(m.get("kind", "")) == "strong"
		var label := "%s - %s %s%s" % [str(m.get("fa" if fa else "en", id)), V7bKit.num(int(m.get("price", 0))), Lang.tt("سکه", "G"),
			(Lang.tt("  (قوی)", "  (strong)") if strong else "")]
		var b := UIKit.button(_items, label, buy.bind(id), "", 16)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
		if strong:
			b.add_theme_color_override(&"font_color", Color(1.0, 0.7, 0.5))
		buttons[id] = b
