class_name CityFundPanel
extends PanelContainer
## v7a City Hall panel (city_fund module): balance, income and spending,
## the latest ledger lines (fines, taxes, subsidy, works) and the public works
## with their state; "Fund it" starts a planned project when the fund allows.

var _title: Label
var _summary: Label
var _ledger: Label
var _works: VBoxContainer
var _close: Button


func _ready() -> void:
	name = "CityFundPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.1, 0.13, 0.16, 0.95), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(760, 520)
	offset_left = -380
	offset_right = 380
	offset_top = -270
	offset_bottom = 270
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	add_child(v)
	_title = UIKit.label(v, "", 26, UIKit.GOLD)
	_summary = UIKit.label(v, "", 17, Color(0.95, 0.95, 0.9))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 24)
	v.add_child(cols)
	_ledger = UIKit.label(cols, "", 14, Color(0.85, 0.9, 0.92))
	_ledger.custom_minimum_size = Vector2(360, 0)
	_ledger.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_works = VBoxContainer.new()
	_works.custom_minimum_size = Vector2(330, 0)
	_works.add_theme_constant_override(&"separation", 6)
	cols.add_child(_works)
	_close = UIKit.button(v, "", close, "", 16)


func style() -> CityFundStyle:
	return Modules.style("city_fund") as CityFundStyle


func open() -> void:
	visible = true
	GameEvents.open_modal("city_fund")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("city_fund")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func _n(v: int) -> String:
	return Lang.digits(str(v)) if Lang.is_fa() else str(v)


func refresh() -> void:
	var fa := Lang.is_fa()
	Lang.apply_dir(get_child(0) as Control)
	var al := HORIZONTAL_ALIGNMENT_RIGHT if fa else HORIZONTAL_ALIGNMENT_LEFT
	_title.text = Lang.tt("شهرداری - صندوق شهر", "City Hall - municipality fund")
	_summary.text = Lang.tt(
		"موجودی: %s سکه\nدرآمد: %s سکه (جریمه‌ها %s) · هزینه‌ها: %s سکه\nآتش‌سوزی %s · قطعی برق %s · زلزله %s · دعوا %s (آرام‌شده %s)" % [
			_n(CityState.fund), _n(CityState.income_total()), _n(CityState.fines_total), _n(CityState.spending_total()),
			_n(CityState.fires), _n(CityState.outages), _n(CityState.quakes), _n(CityState.arguments), _n(CityState.calmed)],
		"Balance: %d G\nIncome: %d G (fines %d) · spending: %d G\nFires %d · outages %d · quakes %d · arguments %d (calmed %d)" % [
			CityState.fund, CityState.income_total(), CityState.fines_total, CityState.spending_total(),
			CityState.fires, CityState.outages, CityState.quakes, CityState.arguments, CityState.calmed])
	var lines: PackedStringArray = [Lang.tt("دفتر حساب (آخرین‌ها)", "Ledger (latest)")]
	var n := 0
	for i in range(CityState.ledger.size() - 1, -1, -1):
		var e: Dictionary = CityState.ledger[i]
		var amt := int(e.get("amount", 0))
		var sign_s := "+" if amt > 0 else ("-" if amt < 0 else "·")
		lines.append("%s%s  %s" % [sign_s, _n(absi(amt)), str(e.get("fa" if fa else "en", ""))])
		n += 1
		if n >= 9:
			break
	if n == 0:
		lines.append(Lang.tt("هنوز چیزی ثبت نشده.", "Nothing yet."))
	_ledger.text = "\n".join(lines)
	for c in _works.get_children():
		c.queue_free()
	var head := UIKit.label(_works, Lang.tt("کارهای عمومی", "Public works"), 18, UIKit.GOLD)
	head.horizontal_alignment = al
	var st := style()
	if st:
		for p: Dictionary in st.projects:
			var id := str(p.get("id", ""))
			var state := CityState.project_state(id)
			var row := HBoxContainer.new()
			_works.add_child(row)
			var state_txt: String = {"planned": Lang.tt("برنامه", "planned"), "building": Lang.tt("در حال ساخت", "being built"), "done": Lang.tt("ساخته شد", "done")}.get(state, state)
			var l := UIKit.label(row, "%s - %s سکه (%s)" % [str(p.get("fa", "")), _n(int(p.get("cost", 0))), state_txt] if fa
					else "%s - %d G (%s)" % [str(p.get("en", "")), int(p.get("cost", 0)), state_txt], 14,
					Color(0.6, 0.9, 0.6) if state == "done" else (Color(1.0, 0.8, 0.4) if state == "building" else Color(0.9, 0.9, 0.9)))
			l.custom_minimum_size.x = 250
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			if state == "planned":
				var b := UIKit.button(row, Lang.tt("تأمین کن", "Fund it"), func() -> void:
					CityState.start_project(id)
					refresh(), "", 13)
				b.disabled = CityState.fund < int(p.get("cost", 0))
		var sub := UIKit.label(_works, Lang.tt("یارانه‌ی درمان: %s٪ هزینه‌ی دکتر (تا %s سکه)" % [_n(int(st.doctor_subsidy * 100)), _n(st.subsidy_cap)],
				"Doctor subsidy: %d%% of the fee (up to %d G)" % [int(st.doctor_subsidy * 100), st.subsidy_cap]), 14, Color(0.75, 0.88, 1.0))
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.horizontal_alignment = al
	for lab: Label in [_title, _summary, _ledger, head]:
		lab.horizontal_alignment = al
		lab.text_direction = Control.TEXT_DIRECTION_RTL if fa else Control.TEXT_DIRECTION_LTR
	for row in _works.get_children():
		for l2 in row.get_children():
			if l2 is Label:
				(l2 as Label).text_direction = Control.TEXT_DIRECTION_RTL if fa else Control.TEXT_DIRECTION_LTR
	_close.text = Lang.tt("بستن (Esc)", "Close (Esc)")
