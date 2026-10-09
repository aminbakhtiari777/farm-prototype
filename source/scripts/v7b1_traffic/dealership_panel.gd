class_name DealershipPanel
extends PanelContainer
## v7b.1 dealership panel: the cars with prices and top speeds, the licence
## rule, and Buy buttons (disabled without a licence or the money).

var dealer: Dealership
var _title: Label
var _info: Label
var _list: VBoxContainer
var _status: Label


func _ready() -> void:
	name = "DealershipPanel"
	theme = V6bWorld.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.12, 0.09, 0.09, 0.96), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(620, 440)
	offset_left = -310
	offset_right = 310
	offset_top = -220
	offset_bottom = 220
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title = UIKit.label(v, "", 24, UIKit.GOLD)
	_info = UIKit.label(v, "", 16, Color(0.95, 0.92, 0.88))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.custom_minimum_size = Vector2(560, 0)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 5)
	v.add_child(_list)
	_status = UIKit.label(v, "", 15, Color(1.0, 0.9, 0.7))
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIKit.button(v, Lang.tt("بستن", "Close"), close, "", 16)


func open() -> void:
	visible = true
	GameEvents.open_modal("dealership")
	_status.text = ""
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("dealership")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	Lang.apply_dir(get_child(0) as Control)
	V7bKit.clear_children(_list)
	var st := dealer.style() if dealer else null
	if st == null:
		return
	_title.text = str(st.name.get("fa" if Lang.is_fa() else "en", ""))
	var lic := TrafficState.licensed("player")
	_info.text = Lang.tt("پول تو: %s سکه · گواهینامه: %s\nبرای خرید ماشین گواهینامه لازم است (امتحان در اداره‌ی پلیس)." % [Lang.digits(str(Economy.money)), "دارد" if lic else "ندارد"],
		"Your money: %d G · licence: %s\nYou need a driving licence to buy a car (test at the police station)." % [Economy.money, "yes" if lic else "no"])
	for c: Dictionary in st.cars:
		var price := int(c.get("price", 0))
		var txt := Lang.tt("%s - %s سکه - حداکثر %s کیلومتر" % [str(c.get("fa", "")), Lang.digits(str(price)), Lang.digits(str(int(c.get("top_kmh", 40))))],
			"%s - %d G - top %d km/h" % [str(c.get("en", "")), price, int(c.get("top_kmh", 40))])
		var b := UIKit.button(_list, txt, _buy.bind(str(c.get("id", ""))), "", 16)
		b.disabled = (st.requires_license and not lic) or Economy.money < price
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT if Lang.is_fa() else HORIZONTAL_ALIGNMENT_LEFT


func _buy(id: String) -> void:
	var r := dealer.buy(id)
	match r:
		"":
			_status.text = Lang.tt("خریدی! ماشین جلوی نمایشگاه است.", "Bought! The car is parked at the lot.")
		"license":
			_status.text = Lang.tt("بدون گواهینامه نمی‌شود ماشین خرید.", "You can't buy a car without a licence.")
		"money":
			_status.text = Lang.tt("پول کافی نداری.", "Not enough money.")
		_:
			_status.text = "-"
	refresh()
