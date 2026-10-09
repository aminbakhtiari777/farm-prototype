class_name MechanicPanel
extends PanelContainer
## v7b mechanic counter (mechanic module): the car's condition and fuel,
## repair and fill-up prices, and the upgrades (installed ones are marked).

var shop: MechanicShop
var _title: Label
var _info: Label
var _actions: VBoxContainer
var _status: Label


func _ready() -> void:
	name = "MechanicPanel"
	theme = V6bWorld.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.1, 0.11, 0.13, 0.96), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(620, 470)
	offset_left = -310
	offset_right = 310
	offset_top = -235
	offset_bottom = 235
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title = UIKit.label(v, "", 24, UIKit.GOLD)
	_info = UIKit.label(v, "", 16, Color(0.92, 0.95, 1.0))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_actions = VBoxContainer.new()
	_actions.add_theme_constant_override(&"separation", 5)
	v.add_child(_actions)
	_status = UIKit.label(v, "", 15, Color(0.85, 1.0, 0.85))
	UIKit.button(v, Lang.tt("بستن", "Close"), close, "", 16)


func open() -> void:
	visible = true
	GameEvents.open_modal("mechanic")
	_status.text = ""
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("mechanic")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func _do(what: String, id: String = "") -> void:
	var ok := false
	match what:
		"repair":
			ok = shop.repair()
		"fuel":
			ok = shop.fill_up(shop.target_car())
		"install":
			ok = shop.install(id)
	_status.text = Lang.tt("انجام شد.", "Done.") if ok else Lang.tt("انجام نشد.", "Not done.")
	refresh()


func refresh() -> void:
	var fa := Lang.is_fa()
	Lang.apply_dir(get_child(0) as Control)
	_title.text = Lang.tt("تعمیرگاه - تعمیر، سوخت، ارتقا", "Mechanic - repairs, fuel, upgrades")
	V7bKit.clear_children(_actions)
	var st := shop.style() if shop else null
	var car := shop.target_car() if shop else null
	if st == null or car == null:
		_info.text = Lang.tt("ماشینی این نزدیکی نیست. ماشینت را جلوی تعمیرگاه پارک کن.", "No car nearby. Park your car in front of the garage.")
		return
	var s := TownLife.car(car.key)
	var who := shop.mechanic()
	var mech := ""
	if who:
		mech = Lang.tt("مکانیک: %s%s" % [Dialogue.name_of(who.resident), " (جانشین)" if shop.staffing.is_standin("mechanic") else ""],
			"Mechanic: %s%s" % [Dialogue.name_of(who.resident), " (stand-in)" if shop.staffing.is_standin("mechanic") else ""])
	_info.text = "%s\n%s" % [mech, Lang.tt("سلامت ماشین %s٪ · بنزین %s٪" % [Lang.digits(str(int(s["condition"]))), Lang.digits(str(int(s["fuel"])))],
		"Car condition %d%% · fuel %d%%" % [int(s["condition"]), int(s["fuel"])])]
	var rc := shop.repair_cost(car)
	var fc := shop.fuel_cost(car)
	var b1 := UIKit.button(_actions, Lang.tt("تعمیر کامل - %s سکه" % V7bKit.num(rc), "Full repair - %d G" % rc), _do.bind("repair", ""), "", 16)
	b1.disabled = rc <= 0
	var b2 := UIKit.button(_actions, Lang.tt("پر کردن باک - %s سکه" % V7bKit.num(fc), "Fill the tank - %d G" % fc), _do.bind("fuel", ""), "", 16)
	b2.disabled = fc <= 0
	var ups: Array = s.get("upgrades", [])
	for u: Dictionary in st.upgrades:
		var id := str(u.get("id", ""))
		var have := id in ups
		var txt := "%s - %s" % [str(u.get("fa" if fa else "en", id)), Lang.tt("نصب شده", "installed") if have else "%s %s" % [V7bKit.num(int(u.get("cost", 0))), Lang.tt("سکه", "G")]]
		var b := UIKit.button(_actions, txt, _do.bind("install", id), "", 15)
		b.disabled = have
	for b in _actions.get_children():
		(b as Button).alignment = HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
