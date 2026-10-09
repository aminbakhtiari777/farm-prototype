class_name LivestockPanel
extends PanelContainer
## v5c carpenter's livestock desk: order a coop or a barn (gold + planks +
## nails, built over days - animal_housing module), buy chickens, cows and
## sheep once their housing is ready (livestock module), buy feed at today's
## market price, and see how your animals are doing. Persian by default.

var _body: VBoxContainer
var _msg: Label
var last_message: String = ""


func _ready() -> void:
	name = "LivestockPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.13, 0.1, 0.07, 0.94), 12, 16, true))
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 16
	offset_right = 676
	offset_top = 62
	offset_bottom = 860
	_body = VBoxContainer.new()
	_body.name = "Body"
	_body.add_theme_constant_override(&"separation", 5)
	add_child(_body)
	GameEvents.ui_panel_requested.connect(func(p: String) -> void:
		if p == "livestock":
			open())
	Ranch.changed.connect(func() -> void:
		if visible:
			refresh.call_deferred())
	Economy.money_changed.connect(func(_m: int) -> void:
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
	visible = true
	GameEvents.open_modal("livestock")
	GameEvents.interaction_prompt_changed.emit("")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("livestock")


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"interact"):
		close()
		get_viewport().set_input_as_handled()


func _say(m: String) -> void:
	last_message = m
	GameEvents.notification_requested.emit(m)
	refresh()


func _section(text: String) -> void:
	_body.add_child(HSeparator.new())
	UIKit.label(_body, text, 18, UIKit.GOLD)


func refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	var head := HBoxContainer.new()
	_body.add_child(head)
	var t := UIKit.label(head, _t("میز دامداری نجاری", "Carpenter - livestock desk"), 24, UIKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button(head, "English" if Lang.is_fa() else "فارسی", func() -> void:
		Settings.set_value("dialogue_language", "en" if Lang.is_fa() else "fa"), "Language / زبان")
	UIKit.button(head, _t("بستن (Esc)", "Close (Esc)"), close, "Close")
	UIKit.label(_body, _t("سکه: %s · تخته: %s · میخ: %s" % [_n(Economy.money), _n(Economy.count("wood_plank")), _n(Economy.count("iron_nails"))],
		"Gold: %d · planks: %d · nails: %d" % [Economy.money, Economy.count("wood_plank"), Economy.count("iron_nails")]), 15, Color(0.95, 0.88, 0.7))
	# Buildings.
	_section(_t("۱. سفارش ساخت جای دام", "1. Order animal housing"))
	for h in Ranch.housing_defs():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		_body.add_child(row)
		var st := Ranch.housing_state(h.id)
		var status := ""
		match st:
			"built":
				status = _t("ساخته شده · %s/%s دام" % [_n(Ranch.animals_in(h.id).size()), _n(h.capacity)], "built · %d/%d animals" % [Ranch.animals_in(h.id).size(), h.capacity])
			"ordered":
				status = _t("در حال ساخت · آماده روز %s" % _n(Ranch.ready_day(h.id)), "under construction · ready day %d" % Ranch.ready_day(h.id))
			_:
				status = _t("هزینه: %s · %s روز" % [Ranch.cost_text(h), _n(h.build_days)], "cost: %s · %d day(s)" % [Ranch.cost_text(h), h.build_days])
		var l := UIKit.label(row, "%s — %s" % [h.name_fa if Lang.is_fa() else h.display_name, status], 15, Color(0.95, 0.93, 0.88))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 420
		if st == "none":
			var why := Ranch.order_problem(h.id)
			var hid := h.id
			var b := UIKit.button(row, _t("سفارش ساخت", "Order"), func() -> void: _say(Ranch.order(hid)), why)
			b.disabled = why != ""
			if why != "":
				UIKit.label(_body, "   " + why, 13, Color(1, 0.6, 0.5))
	# Animals.
	_section(_t("۲. خرید دام", "2. Buy animals"))
	for d in Ranch.animal_defs():
		var row2 := HBoxContainer.new()
		row2.add_theme_constant_override(&"separation", 8)
		_body.add_child(row2)
		var h2 := Ranch.housing_def(d.housing)
		var info := _t("%s — %s سکه · %s روزانه · جا: %s%s" % [d.name_fa, _n(d.price), Ranch.product_name(d), h2.name_fa if h2 else "?",
			(" · ابزار: " + Market.local_name(d.tool_item)) if d.tool_item != "" else ""],
			"%s — %d G · gives %s · lives in the %s%s" % [d.display_name, d.price, GameData.item_name(d.product_item).to_lower(), h2.display_name.to_lower() if h2 else "?",
			(" · needs " + GameData.item_name(d.tool_item).to_lower()) if d.tool_item != "" else ""])
		var l2 := UIKit.label(row2, info, 15, Color(0.95, 0.93, 0.88))
		l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l2.custom_minimum_size.x = 420
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var why2 := Ranch.buy_problem(d.id)
		var kind := d.id
		var b2 := UIKit.button(row2, _t("خرید (%s)" % _n(Ranch.count_kind(d.id)), "Buy (%d)" % Ranch.count_kind(d.id)), func() -> void: _say(Ranch.buy_animal(kind)), why2)
		b2.disabled = why2 != ""
	# Feed (market goods).
	_section(_t("۳. علوفه (قیمت روز بازار)", "3. Feed (today's market price)"))
	var shop := Shops.shop("livestock")
	for id in Shops.stock(shop):
		var row3 := HBoxContainer.new()
		_body.add_child(row3)
		var price := Shops.buy_price(id)
		var ch := Market.change_pct(id)
		var l3 := UIKit.label(row3, _t("%s — %s سکه%s · داری: %s · موجودی: %s" % [Market.local_name(id), _n(price), (" (%s%s٪)" % ["+" if ch > 0 else "-", _n(absi(ch))]) if ch != 0 else "", _n(Economy.count(id)), _n(Market.available(id))],
			"%s — %d G%s · have %d · stock %d" % [GameData.item_name(id), price, (" (%+d%%)" % ch) if ch != 0 else "", Economy.count(id), Market.available(id)]), 15, Color(0.95, 0.93, 0.88))
		l3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var fid := id
		for n in [1, 5, 10]:
			var nn: int = n
			var bb := UIKit.button(row3, "×" + _n(n), func() -> void: _say(Shops.purchase(fid, nn, shop, get_tree())), "")
			bb.disabled = Economy.money < price * n or Market.available(id) < n
	UIKit.label(_body, _t("قیچی پشم‌چینی و سطل شیر را از آهنگری بخر.", "Buy shears and a milk pail at the blacksmith."), 13, Color(0.75, 0.8, 0.7))
	# Your animals.
	_section(_t("۴. دام‌های تو", "4. Your animals"))
	if Ranch.animals.is_empty():
		UIKit.label(_body, _t("هنوز دامی نداری.", "No animals yet."), 14, Color(0.8, 0.78, 0.7))
	var shown := 0
	for a: Dictionary in Ranch.animals:
		var d3 := Ranch.animal_def(str(a["kind"]))
		if d3 == null:
			continue
		shown += 1
		if shown > 8:
			UIKit.label(_body, "…", 14, Color(0.8, 0.78, 0.7))
			break
		var mood := Ranch.mood(a)
		var mood_txt := _t({"happy": "خوشحال", "content": "راضی", "unhappy": "ناراحت"}.get(mood, ""), mood)
		var txt := _t("%s %s · %s · شادی %s٪ · %s%s" % [d3.name_fa, a["name"], "بالغ" if bool(a["adult"]) else "کوچولو", _n(int(a["happiness"])), mood_txt,
			(" · %s آماده" % Ranch.product_name(d3)) if int(a["product_ready"]) > 0 else (" · گرسنه" if not bool(a["fed_today"]) else " · سیر")],
			"%s %s · %s · happiness %d%% · %s%s" % [d3.display_name, a["name"], "adult" if bool(a["adult"]) else "young", int(a["happiness"]), mood_txt,
			(" · %s ready" % GameData.item_name(d3.product_item).to_lower()) if int(a["product_ready"]) > 0 else (" · hungry" if not bool(a["fed_today"]) else " · fed")])
		UIKit.label(_body, txt, 14, Color(0.9, 1.0, 0.85) if mood == "happy" else (Color(1, 0.9, 0.6) if mood == "content" else Color(1, 0.6, 0.55)))
	_msg = UIKit.label(_body, last_message, 15, Color(1, 0.95, 0.75))
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.custom_minimum_size.x = 620
	Lang.apply_dir(_body)
