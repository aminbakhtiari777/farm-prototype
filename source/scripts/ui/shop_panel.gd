extends PanelContainer
## Town market shop. Opens on GameEvents.shop_requested (market stall).
## Buy: seeds available this season + tools. Sell: today's market prices for
## all produce (seasonal demand x weather), with the change vs. base price.
## Close with the Close button, E or Esc.

var _info: Label
var _title: Label
## v5a: "" = the classic seed/tool market shop; otherwise a Shops id
## (workplace counter "carpenter", market stall "stall:fish", ...).
var shop_id: String = ""
var _buy_list: VBoxContainer
var _sell_list: VBoxContainer
var _money: Label
var _buy_head: Label
var _sell_head: Label
var _close: Button
var _cols: HBoxContainer


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.96, 0.92, 0.82, 0.97)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(18)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 10
	add_theme_stylebox_override(&"panel", style)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	add_child(v)
	var title := _label(v, "Town Market", 26, Color(0.3, 0.18, 0.1))
	_title = title
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_info = _label(v, "", 15, Color(0.35, 0.28, 0.2))
	_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cols := HBoxContainer.new()
	_cols = cols
	cols.add_theme_constant_override(&"separation", 24)
	v.add_child(cols)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 380
	cols.add_child(left)
	_buy_head = _label(left, "BUY", 18, Color(0.25, 0.4, 0.2))
	_buy_list = VBoxContainer.new()
	left.add_child(_scroll(_buy_list))
	var right := VBoxContainer.new()
	right.custom_minimum_size.x = 400
	cols.add_child(right)
	_sell_head = _label(right, "SELL  (today's prices)", 18, Color(0.55, 0.3, 0.15))
	_sell_list = VBoxContainer.new()
	right.add_child(_scroll(_sell_list))
	var footer := HBoxContainer.new()
	v.add_child(footer)
	_money = _label(footer, "", 20, Color(0.55, 0.38, 0.05))
	_money.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var close := Button.new()
	close.text = "Close (E / Esc)"
	close.focus_mode = Control.FOCUS_NONE
	close.pressed.connect(close_shop)
	footer.add_child(close)
	_close = close
	# v5c: prices move with the market; Persian by default.
	Market.prices_changed.connect(func() -> void:
		if visible:
			_refresh.call_deferred())
	GameEvents.shop_requested.connect(open_shop)
	GameEvents.shop_requested_for.connect(open_shop_for)
	Economy.money_changed.connect(func(_m: int) -> void: _refresh())
	Economy.inventory_changed.connect(_refresh)


func _scroll(list: VBoxContainer) -> ScrollContainer:
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 330
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(list)
	return sc


func _label(parent: Control, text: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", font_size)
	l.add_theme_color_override(&"font_color", color)
	parent.add_child(l)
	return l


func open_shop() -> void:
	shop_id = ""
	_title.text = "Town Market"
	_show()


func open_shop_for(id: String) -> void:
	var s := Shops.shop(id)
	if s.is_empty() or bool(s.get("legacy", false)):
		open_shop()
		return
	shop_id = id
	_title.text = Shops.title_of(s)
	_show()


func _show() -> void:
	visible = true
	GameEvents.open_modal("shop")
	GameEvents.interaction_prompt_changed.emit("")
	_refresh()


func close_shop() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("shop")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"menu"):
		close_shop()
		get_viewport().set_input_as_handled()


func _row(parent: Control, text: String, price_text: String, price_color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override(&"separation", 8)
	parent.add_child(h)
	var name_label := _label(h, text, 16, Color(0.2, 0.15, 0.1))
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var price := _label(h, price_text, 16, price_color)
	price.custom_minimum_size.x = 120
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return h


func _small_button(parent: Control, text: String, enabled: bool, callback: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.disabled = not enabled
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size.x = 58
	b.pressed.connect(callback)
	parent.add_child(b)


func _t(fa: String, en: String) -> String:
	return fa if Lang.is_fa() else en


func _n(v: Variant) -> String:
	return Lang.digits(str(v))


func _refresh() -> void:
	if not visible:
		return
	_buy_head.text = _t("خرید", "BUY")
	_sell_head.text = _t("فروش (قیمت امروز بازار)", "SELL  (today's market prices)")
	_close.text = _t("بستن (E / Esc)", "Close (E / Esc)")
	_cols.layout_direction = Control.LAYOUT_DIRECTION_RTL if Lang.is_fa() else Control.LAYOUT_DIRECTION_INHERITED
	if shop_id != "":
		_refresh_shop()
		return
	var wmult := Economy.weather_multiplier()
	_info.text = "%s  ·  %s  ·  weather price effect x%.2f   (in-season crops: base price, out-of-season: +%d%%)" % [
			TimeManager.date_text(), TimeManager.weather_name(), wmult,
			int(round((float(GameData.data.get("pricing", {}).get("out_of_season_mult", 1.5)) - 1.0) * 100.0))]
	_money.text = "Money: %d G" % Economy.money
	for c in _buy_list.get_children():
		c.queue_free()
	for c in _sell_list.get_children():
		c.queue_free()
	var stock := Economy.shop_stock()
	if stock.is_empty():
		_label(_buy_list, "Nothing for sale this season.", 15, Color(0.4, 0.3, 0.2))
	for id in stock:
		var item := GameData.item(id)
		var label := GameData.item_name(id)
		if item.get("type") == "seed":
			var crop := GameData.crop(str(item.get("crop", "")))
			label += "  (%d days, %s m²)" % [int(crop.get("days", 0)), str(crop.get("footprint", 0.5))]
		var row := _row(_buy_list, label, "%d G" % Economy.buy_price(id), Color(0.3, 0.25, 0.15))
		row.tooltip_text = str(item.get("description", ""))
		_small_button(row, "Buy", Economy.can_buy(id), func() -> void: _buy(id, 1))
		if item.get("type") != "tool":
			_small_button(row, "x5", Economy.can_buy(id, 5), func() -> void: _buy(id, 5))
	if Economy.season_id_is_winter():
		_label(_buy_list, "Winter: nothing grows outdoors.", 14, Color(0.35, 0.4, 0.55))
	var items := GameData.items()
	for id in items:
		if items[id].get("type") != "produce":
			continue
		var base := int(items[id].get("sell", 0))
		var price := Economy.sell_price(id)
		var change := int(round((float(price) / maxf(base, 1) - 1.0) * 100.0))
		var change_text := "" if change == 0 else ("  +%d%%" % change if change > 0 else "  %d%%" % change)
		var colr := Color(0.25, 0.45, 0.15) if change > 0 else (Color(0.65, 0.2, 0.15) if change < 0 else Color(0.3, 0.25, 0.15))
		var owned := Economy.count(id)
		var row := _row(_sell_list, "%s  (have %d)" % [GameData.item_name(id), owned], "%d G%s" % [price, change_text], colr)
		_small_button(row, "Sell 1", owned > 0, func() -> void: Economy.sell(id, 1))
		_small_button(row, "All", owned > 0, func() -> void: Economy.sell(id))


func _buy(id: String, amount: int) -> void:
	if Economy.buy(id, amount):
		GameEvents.notification_requested.emit("Bought %d %s" % [amount, GameData.item_name(id)])


## v5a: a workplace counter or market stall (stock + what it buys, with bonus).
## v5c: prices follow supply and demand (Market); stock counts, sold-out goods
## and the change since yesterday are shown.
func _refresh_shop() -> void:
	var s := Shops.shop(shop_id)
	var mult := float(s.get("buy_mult", 1.0))
	var greet := str(s.get("greeting_fa", "")) if Lang.is_fa() and str(s.get("greeting_fa", "")) != "" else str(s.get("greeting", "Welcome!"))
	_info.text = "\"%s\"   ·   %s%s   ·   %s" % [greet, Lang.date_text(),
			(_t("   ·   %s٪ بیشتر برای کالاهایش می‌دهد" % _n(int(round((mult - 1.0) * 100.0))), "   ·   pays +%d%% for its goods" % int(round((mult - 1.0) * 100.0)))) if mult > 1.001 else "",
			_t("قیمت‌ها با عرضه و تقاضا تغییر می‌کنند", "prices follow supply and demand")]
	_money.text = _t("سکه: %s" % _n(Economy.money), "Money: %d G" % Economy.money)
	for c in _buy_list.get_children():
		c.queue_free()
	for c in _sell_list.get_children():
		c.queue_free()
	var stock := Shops.stock(s)
	if stock.is_empty():
		_label(_buy_list, _t("اینجا چیزی برای فروش نیست.", "Nothing for sale here."), 15, Color(0.4, 0.3, 0.2))
	for id in stock:
		var item := GameData.item(id)
		var price := Shops.buy_price(id)
		var tracked := Market.is_tracked(id)
		var avail := Market.available(id) if tracked else 999
		var label := Market.local_name(id)
		if Economy.count(id) > 0:
			label += _t("  (داری %s)" % _n(Economy.count(id)), "  (have %d)" % Economy.count(id))
		if tracked:
			label += _t("  · موجودی %s" % _n(avail), "  · stock %d" % avail) if avail > 0 else _t("  · تمام شد!", "  · SOLD OUT")
		var ch := Market.change_pct(id) if tracked else 0
		var ptxt := _t("%s سکه" % _n(price), "%d G" % price)
		if ch != 0:
			ptxt += "  (%s)" % Market.trend_text(ch)
		var pcol := Color(0.7, 0.2, 0.15) if ch > 0 or (tracked and Market.is_shortage(id)) else (Color(0.2, 0.5, 0.2) if ch < 0 else Color(0.3, 0.25, 0.15))
		var row := _row(_buy_list, label, ptxt, pcol)
		row.tooltip_text = str(item.get("description", ""))
		_small_button(row, _t("خرید", "Buy"), Economy.money >= price and avail >= 1, func() -> void: _shop_buy(id, 1))
		if not str(item.get("type", "")) in ["tool", "outfit", "gift", "tool_item", "kitchenware"]:
			_small_button(row, "×" + _n(5), Economy.money >= price * 5 and avail >= 5, func() -> void: _shop_buy(id, 5))
	var buys := Shops.buys(s)
	if buys.is_empty():
		_label(_sell_list, _t("این مغازه چیزی نمی‌خرد.", "This shop doesn't buy anything."), 15, Color(0.4, 0.3, 0.2))
	for id in buys:
		var owned := Economy.count(id)
		var sp := Shops.sell_price(id, s)
		var m := Market.mult(id)
		var hint := ""
		if Market.is_tracked(id) and absf(m - 1.0) > 0.05:
			var pct := int(round(absf(m - 1.0) * 100.0))
			hint = "  " + (_t("(%s٪ بالاتر از عادی)" % _n(pct), "(+%d%% vs normal)" % pct) if m > 1.0 else _t("(%s٪ پایین‌تر از عادی)" % _n(pct), "(-%d%% vs normal)" % pct))
		var row := _row(_sell_list, "%s  %s" % [Market.local_name(id), _t("(داری %s)" % _n(owned), "(have %d)" % owned)],
			_t("%s سکه" % _n(sp), "%d G" % sp) + hint, Color(0.25, 0.45, 0.15) if m > 1.01 or mult > 1.001 else (Color(0.65, 0.2, 0.15) if m < 0.99 else Color(0.3, 0.25, 0.15)))
		_small_button(row, _t("فروش ۱", "Sell 1"), owned > 0, func() -> void: _shop_sell(id, 1))
		_small_button(row, _t("همه", "All"), owned > 0, func() -> void: _shop_sell(id, -1))
	Lang.apply_dir(_cols)


func _shop_buy(id: String, amount: int) -> void:
	GameEvents.notification_requested.emit(Shops.purchase(id, amount, Shops.shop(shop_id), get_tree()))
	_refresh()


func _shop_sell(id: String, amount: int) -> void:
	var got := Shops.sell(id, amount, Shops.shop(shop_id))
	if got > 0:
		GameEvents.notification_requested.emit(_t("فروختی: %s سکه" % _n(got), "Sold for %d G" % got))
	_refresh()
