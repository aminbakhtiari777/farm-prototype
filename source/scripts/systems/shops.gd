class_name Shops
extends RefCounted
## v5a shop rules shared by every counter and market stall. A shop is a
## dictionary from a module: WorkplaceStyle.shops[id] (carpenter, jeweller...)
## or MarketStyle.stalls (id "stall:<id>"). Keys: title, greeting,
## sells [item ids / "type:x"], buys [ids / "type:x" / "category:x"], buy_mult.
## Categories: "crop" (any crop produce), "fruit" (tree/palm/bush fruit),
## "fish", "shell", "crafted".


static func shop(shop_id: String) -> Dictionary:
	var out := _shop(shop_id)
	if not out.is_empty():
		out = out.duplicate()
		out["id"] = shop_id
		_v6a_extend(shop_id, out)
	return out


## v6a: modules that add goods to existing counters - fishing rods at the
## carpenter (fishing_gear), the carpenter buys firewood / dry wood (dry_trees)
## and the steel axe at the tool shop + carpenter (tool_types).
static func _v6a_extend(shop_id: String, out: Dictionary) -> void:
	var sells: Array = (out.get("sells", []) as Array).duplicate()
	var buys_l: Array = (out.get("buys", []) as Array).duplicate()
	var gear := Modules.style("fishing_gear") as FishingGearStyle
	if gear and shop_id in gear.sold_at:
		for r in gear.rods:
			if not r in sells:
				sells.append(r)
	if shop_id == "fruit_shop":
		buys_l.append_array(["mango", "guava", "coconut"])
	if shop_id == "tool_shop":
		sells.append_array(["spade", "pickaxe", "fishing_net"])
	if shop_id in ["carpenter", "tool_shop"]:
		if not "steel_axe" in sells:
			sells.append("steel_axe")
	if shop_id == "carpenter" and Modules.style("dry_trees") != null:
		if not "category:wood" in buys_l:
			buys_l.append("category:wood")
	out["sells"] = sells
	out["buys"] = buys_l


## v5c: localized shop title.
static func title_of(s: Dictionary) -> String:
	if Lang.is_fa():
		if str(s.get("title_fa", "")) != "":
			return str(s["title_fa"])
		var st := Dialogue.style()
		var sid := str(s.get("id", ""))
		if st and st.places_fa.has(sid):
			return str(st.places_fa[sid])
		if sid.begins_with("stall:"):
			return "غرفه " + str({"produce": "میوه و تره‌بار", "fish": "ماهی", "crafts": "صنایع دستی", "bakery": "نان", "flowers": "گل", "seeds": "بذر"}.get(sid.substr(6), "بازار"))
	return str(s.get("title", "Shop"))


static func _shop(shop_id: String) -> Dictionary:
	# v5b: the supermarket grocery counter sells the cooking ingredients.
	if shop_id == "grocery":
		return {"title": "Supermarket", "title_fa": "سوپرمارکت", "greeting": "Fresh chicken, eggs and vegetables!",
			"greeting_fa": "مرغ و تخم‌مرغ و سبزی تازه داریم!",
			"sells": ["sold_at:grocery"], "buys": ["category:crop", "eggs", "milk"], "buy_mult": 1.0}
	# v5c: the carpenter's livestock desk (feed; buildings + animals in LivestockPanel).
	if shop_id == "livestock":
		return {"title": "Livestock desk", "title_fa": "میز دامداری", "greeting": "Coops, barns, animals and feed.",
			"greeting_fa": "مرغدانی، طویله، دام و علوفه.", "sells": [], "buys": ["eggs", "milk", "wool"], "buy_mult": 1.0}
	# v6a: the hypermarket (hypermarket module) - kitchenware + groceries.
	if shop_id == "hypermarket":
		var hs := Modules.style("hypermarket") as HypermarketStyle
		if hs == null:
			return {}
		return {"title": hs.title, "title_fa": hs.title_fa, "greeting": hs.greeting, "greeting_fa": hs.greeting_fa,
			"sells": hs.sells.duplicate(), "buys": hs.buys.duplicate() + ["hamour", "black_pomfret", "mango", "guava", "coconut"], "buy_mult": 1.0}
	if shop_id.begins_with("stall:"):
		var ms := Modules.style("market") as MarketStyle
		if ms:
			for st in ms.stalls:
				var d: Dictionary = st
				if "stall:" + str(d.get("id", "")) == shop_id:
					var out := d.duplicate()
					out["buy_mult"] = ms.sell_bonus
					# v5b: ingredients sold at this stall (ingredients module).
					var sells: Array = (out.get("sells", []) as Array).duplicate()
					sells.append("sold_at:" + shop_id)
					out["sells"] = sells
					return out
		return {}
	var ws := Modules.style("workplaces") as WorkplaceStyle
	if ws and ws.shops.has(shop_id):
		return ws.shops[shop_id]
	return {}


## v5c: goods the producers deliver to this shop (producers module).
static func produced_here(shop_id: String) -> Array[String]:
	var out: Array[String] = []
	for p in Market.producers_for_shop(shop_id):
		for k in p.outputs:
			if not str(k) in out and not GameData.item(str(k)).is_empty():
				out.append(str(k))
	return out


static func matches(item_id: String, pattern: String) -> bool:
	var it := GameData.item(item_id)
	if it.is_empty():
		return false
	if pattern.begins_with("sold_at:"):
		if not AssetRegistry.variants("ingredients").has(item_id):
			return false
		var ing := AssetRegistry.load_variant("ingredients", item_id) as IngredientDef
		return ing != null and pattern.substr(8) in ing.sold_at
	if pattern.begins_with("type:"):
		return str(it.get("type", "")) == pattern.substr(5)
	if pattern.begins_with("category:"):
		var cat := pattern.substr(9)
		if cat == "crop":
			return it.has("crop_of")
		if cat == "fruit":
			var crop := GameData.crop_def(str(it.get("crop_of", "")))
			return crop != null and crop.shape in ["tree", "palm", "bush"]
		return str(it.get("category", "")) == cat
	return pattern == item_id


## Items this shop sells right now (tools: not owned yet and unlocked).
static func stock(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var items := GameData.items()
	var pats: Array = (s.get("sells", []) as Array).duplicate()
	for id in produced_here(str(s.get("id", ""))):
		pats.append(id)
	for pat_v in pats:
		var pat := str(pat_v)
		for id: String in items:
			if not matches(id, pat) or id in out:
				continue
			var it: Dictionary = items[id]
			if not it.has("buy") and not Market.is_tracked(id):
				continue
			if it.get("type") == "tool" and (Economy.has(id) or not Economy.tool_unlocked(id)):
				continue
			# v6a kitchenware: owned once; upgrades need the basic item first.
			if it.get("type") == "kitchenware" and (Economy.has(id) or (str(it.get("requires", "")) != "" and not Economy.has(str(it.get("requires", ""))))):
				continue
			out.append(id)
	return out


## Items the shop buys from the player (known items; owned ones first).
static func buys(s: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var items := GameData.items()
	for pat_v in s.get("buys", []):
		var pat := str(pat_v)
		for id: String in items:
			if matches(id, pat) and not id in out and Economy.is_sellable(id):
				out.append(id)
	out.sort_custom(func(a: String, b: String) -> bool:
		return Economy.count(a) > Economy.count(b) if (Economy.count(a) > 0) != (Economy.count(b) > 0) else a < b)
	return out


static func buy_price(id: String) -> int:
	# v5c: market goods follow supply and demand.
	if Market.is_tracked(id):
		return Market.buy_price(id)
	return int(GameData.item(id).get("buy", 0))


static func _t(fa: String, en: String) -> String:
	return fa if Lang.is_fa() else en


static func sell_price(id: String, s: Dictionary) -> int:
	return int(round(Economy.sell_price(id) * float(s.get("buy_mult", 1.0))))


## Buys `amount` of an item from a shop. Outfits are worn at once, food is
## eaten at once (stamina), everything else goes into the bag.
static func purchase(id: String, amount: int, s: Dictionary, tree: SceneTree) -> String:
	if not id in stock(s):
		return _t("اینجا فروخته نمی‌شود", "Not for sale here")
	var it := GameData.item(id)
	var price := buy_price(id)
	if Economy.money < price * amount:
		return _t("سکه کافی نیست", "Not enough money")
	# v5c: market goods come out of the town stock - shortages sell out.
	if Market.is_tracked(id) and Market.available(id) < amount:
		return _t("%s تمام شده! (موجودی %s)" % [Market.local_name(id), Lang.digits(str(Market.available(id)))],
			"Sold out! Only %d %s left" % [Market.available(id), GameData.item_name(id)])
	match str(it.get("type", "")):
		"outfit":
			Economy.add_money(-price)
			wear(it, tree)
			return _t("لباس نو پوشیدی: %s" % Market.local_name(id), "You changed into the %s" % str(it.get("name", id)))
		"food":
			Economy.add_money(-price * amount)
			Market.on_player_bought(id, amount, price * amount)
			var player := tree.get_first_node_in_group(&"player")
			if player and player.has_method("restore_stamina"):
				player.call("restore_stamina", float(it.get("stamina", 10)) * amount)
			return _t("نوش جان! +%s انرژی" % Lang.digits(str(int(float(it.get("stamina", 10)) * amount))), "Delicious! +%d stamina" % int(float(it.get("stamina", 10)) * amount))
	if Economy.buy_at(id, amount, price):
		Market.on_player_bought(id, amount, price * amount)
		Economy.item_bought.emit(id, amount, price * amount)
		return _t("خریدی: %s %s" % [Lang.digits(str(amount)), Market.local_name(id)], "Bought %d %s" % [amount, GameData.item_name(id)])
	return _t("سکه کافی نیست", "Not enough money")


static func wear(it: Dictionary, tree: SceneTree) -> void:
	var player := tree.get_first_node_in_group(&"player") as Player
	if player == null:
		return
	if it.has("shirt"):
		player.outfit["shirt"] = it["shirt"]
	if it.has("pants"):
		player.outfit["pants"] = it["pants"]
	player.apply_outfit()


static func sell(id: String, amount: int, s: Dictionary) -> int:
	if not id in buys(s):
		return 0
	return Economy.sell_with_bonus(id, amount, float(s.get("buy_mult", 1.0)))
