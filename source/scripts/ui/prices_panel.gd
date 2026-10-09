class_name PricesPanel
extends PanelContainer
## v5c market prices (key B, or the board at the market): today's price of
## every board good (price_board module), the change since yesterday, stock
## level (shortage / normal / plenty) and a 7-day trend line, plus the town
## economy: wages paid, food and doctor spending, what each producer made and
## which workplaces stood idle. Persian by default; the fa/EN button toggles
## the language (Settings "dialogue_language").

var _title: Label
var _info: Label
var _grid: GridContainer
var _economy: Label
var _production: Label
var _body: VBoxContainer
var _lang_btn: Button


class Spark extends Control:
	var values: Array = []
	var color: Color = Color(1, 0.85, 0.35)

	func _draw() -> void:
		if values.size() < 2:
			draw_line(Vector2(0, size.y * 0.5), Vector2(size.x, size.y * 0.5), Color(1, 1, 1, 0.25), 2.0)
			return
		var lo := float(values.min())
		var hi := float(values.max())
		var span := maxf(hi - lo, 1.0)
		var pts := PackedVector2Array()
		for i in values.size():
			var x := size.x * float(i) / float(values.size() - 1)
			var y := size.y - 3.0 - (float(values[i]) - lo) / span * (size.y - 6.0)
			pts.append(Vector2(x, y))
		draw_polyline(pts, color, 2.0, true)
		draw_circle(pts[-1], 3.0, color)


func _ready() -> void:
	name = "PricesPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.1, 0.13, 0.11, 0.95), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(1040, 700)
	offset_left = -520
	offset_right = 520
	offset_top = -350
	offset_bottom = 350
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override(&"separation", 8)
	add_child(_body)
	GameEvents.ui_panel_requested.connect(func(p: String) -> void:
		if p == "prices":
			open())
	Market.prices_changed.connect(func() -> void:
		if visible:
			refresh.call_deferred())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language" and visible:
			refresh())


func _t(fa: String, en: String) -> String:
	return fa if Lang.is_fa() else en


func _n(v: Variant) -> String:
	return Lang.digits(str(v))


func open() -> void:
	if visible:
		return
	visible = true
	GameEvents.open_modal("prices")
	GameEvents.interaction_prompt_changed.emit("")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("prices")


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"interact") or event.is_action_pressed(&"market_prices")):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	var st := Modules.style("price_board") as PriceBoardStyle
	var head := HBoxContainer.new()
	_body.add_child(head)
	_title = UIKit.label(head, (st.title_fa if Lang.is_fa() else st.title_en) if st else "Market", 26, UIKit.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lang_btn = UIKit.button(head, "English" if Lang.is_fa() else "فارسی", func() -> void:
		Settings.set_value("dialogue_language", "en" if Lang.is_fa() else "fa"), "Language / زبان")
	UIKit.button(head, _t("بستن (Esc)", "Close (Esc)"), close, "Close")
	_info = UIKit.label(_body, "", 15, Color(0.85, 0.85, 0.78))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.text = _t("%s · قیمت‌ها با عرضه و تقاضا تغییر می‌کنند: فروش زیاد قیمت را پایین می‌آورد و کمبود آن را بالا می‌برد. هر صبح تولیدکننده‌ها مغازه‌ها را پر می‌کنند." % TimeManager.date_text(),
		"%s · Prices follow supply and demand: selling a lot pushes a price down, shortages push it up. Producers restock the shops every morning." % TimeManager.date_text())
	_grid = GridContainer.new()
	_grid.columns = 5
	_grid.add_theme_constant_override(&"h_separation", 18)
	_grid.add_theme_constant_override(&"v_separation", 3)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1000, 380)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.add_child(_grid)
	_body.add_child(sc)
	var hdr := Color(0.75, 0.8, 0.7)
	for h in [_t("کالا", "Good"), _t("قیمت امروز", "Today"), _t("تغییر از دیروز", "vs yesterday"), _t("موجودی شهر", "Town stock"), _t("روند ۷ روز", "7-day trend")]:
		var l := UIKit.label(_grid, h, 15, hdr)
		l.custom_minimum_size.x = 150
	if st:
		for id in st.items:
			if GameData.item(id).is_empty() or not Market.is_tracked(id):
				continue
			_row(id, st)
	_body.add_child(HSeparator.new())
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 30)
	_body.add_child(cols)
	_economy = UIKit.label(cols, _economy_text(), 14, Color(0.9, 0.92, 0.85))
	_economy.custom_minimum_size.x = 470
	_economy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_production = UIKit.label(cols, _production_text(), 14, Color(0.85, 0.9, 0.95))
	_production.custom_minimum_size.x = 500
	_production.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Lang.apply_dir(_body)


func _row(id: String, st: PriceBoardStyle) -> void:
	var name_l := UIKit.label(_grid, Market.local_name(id), 17, Color(0.97, 0.95, 0.9))
	name_l.custom_minimum_size.x = 210
	var price := Market.buy_price(id)
	UIKit.label(_grid, _t("%s سکه" % _n(price), "%d G" % price), 17, UIKit.GOLD).custom_minimum_size.x = 120
	var ch := Market.change_pct(id)
	var ch_txt := Market.trend_text(ch)
	UIKit.label(_grid, ch_txt, 16, st.up_color if ch > 0 else (st.down_color if ch < 0 else Color(0.8, 0.8, 0.75))).custom_minimum_size.x = 140
	var stock_txt := ""
	var col := Color(0.8, 0.85, 0.8)
	var r := Market.ratio(id)
	if Market.is_shortage(id):
		stock_txt = _t("کمبود! (%s)" % _n(Market.available(id)), "SHORTAGE (%d)" % Market.available(id))
		col = st.shortage_color
	elif r > 1.4:
		stock_txt = _t("فراوان (%s)" % _n(Market.available(id)), "plenty (%d)" % Market.available(id))
		col = st.down_color
	else:
		stock_txt = _t("عادی (%s)" % _n(Market.available(id)), "normal (%d)" % Market.available(id))
	UIKit.label(_grid, stock_txt, 16, col).custom_minimum_size.x = 150
	var sp := Spark.new()
	sp.custom_minimum_size = Vector2(170, 24)
	var vals: Array = (Market.history.get(id, []) as Array).duplicate()
	vals.append(price)
	sp.values = vals
	sp.color = st.up_color if ch > 0 else (st.down_color if ch < 0 else Color(0.9, 0.85, 0.5))
	_grid.add_child(sp)


func _economy_text() -> String:
	var y := Market.ledger_yesterday
	var t := Market.ledger
	var lines: Array = []
	lines.append(_t("اقتصاد شهر (دیروز / امروز)", "Town economy (yesterday / today)"))
	lines.append(_t("دستمزدها: %s / %s سکه" % [_n(y.get("wages", 0)), _n(t.get("wages", 0))], "Wages paid: %d / %d G" % [int(y.get("wages", 0)), int(t.get("wages", 0))]))
	lines.append(_t("خرج غذا: %s / %s سکه (%s وعده)" % [_n(y.get("food", 0)), _n(t.get("food", 0)), _n(int(y.get("meals", 0)) + int(t.get("meals", 0)))],
		"Spent on food: %d / %d G (%d meals)" % [int(y.get("food", 0)), int(t.get("food", 0)), int(y.get("meals", 0)) + int(t.get("meals", 0))]))
	var city := int(y.get("city_health", 0)) + int(t.get("city_health", 0))
	lines.append(_t("درمان: %s / %s سکه · سهم شهرداری: %s" % [_n(y.get("doctor", 0)), _n(t.get("doctor", 0)), _n(city)],
		"Doctor: %d / %d G · paid by the city: %d" % [int(y.get("doctor", 0)), int(t.get("doctor", 0)), city]))
	lines.append(_t("فروش تو: %s / %s سکه · صادرات: %s" % [_n(y.get("player_sales", 0)), _n(t.get("player_sales", 0)), _n(y.get("exports", 0))],
		"Your sales: %d / %d G · exports: %d G" % [int(y.get("player_sales", 0)), int(t.get("player_sales", 0)), int(y.get("exports", 0))]))
	lines.append(_t("پس‌انداز میانگین اهالی: %s سکه" % _n(Market.average_savings()), "Average savings per resident: %d G" % Market.average_savings()))
	return "\n".join(lines)


func _production_text() -> String:
	var lines: Array = [_t("تولید امروز صبح", "This morning's production")]
	var n := 0
	for p in Market.producers():
		var made: Dictionary = Market.last_production.get(p.id, {})
		var nm := p.name_fa if Lang.is_fa() and p.name_fa != "" else p.display_name
		if p.id in Market.idle_producers:
			lines.append(_t("%s: تعطیل (کارگر بیمار است)" % nm, "%s: closed (worker ill)" % nm))
			n += 1
			continue
		if made.is_empty():
			continue
		var parts: Array = []
		for k in made:
			parts.append("%s %s" % [_n(snappedf(float(made[k]), 0.1)), Market.local_name(str(k))])
		lines.append("%s: %s" % [nm, "، ".join(parts) if Lang.is_fa() else ", ".join(parts)])
		n += 1
		if n >= 7:
			break
	if n == 0:
		lines.append(_t("انبارها پر است؛ امروز تولیدی لازم نبود.", "Stock is full - nothing needed today."))
	return "\n".join(lines)
