extends Node
## v5c livestock (autoload "Ranch"). Modules: "animal_housing" (HousingDef:
## coop, barn - ordered from the carpenter for gold + wood, built over days)
## and "livestock" (LivestockDef: chicken, cow, sheep - bought at the
## carpenter's livestock desk). Feed every animal daily (feed from the same
## desk): fed animals get happier and give eggs / milk / wool, unfed ones get
## unhappy and produce less, then nothing. Two happy adults of a kind breed a
## young one that grows up after a few days. Products go into the bag and on
## to the market (Market) and the kitchen (eggs, milk).
## The world side (buildings, paddocks, troughs, animals) is RanchWorld.

signal changed
signal animal_born(uid: int)
signal building_ready(housing_id: String)

var sim_enabled: bool = true
## housing id -> {"state": "ordered" | "built", "ready_day": int, "ordered_day": int}
var buildings: Dictionary = {}
## Array of {uid, kind, name, born_day, age, adult, happiness, fed_today, petted_today, product_ready, product_timer}
var animals: Array = []
var next_uid: int = 1
var last_birth: Dictionary = {}  ## kind -> day
var collected: Dictionary = {}  ## item -> total collected
var born_total: int = 0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	rng.seed = 4242
	TimeManager.day_started.connect(_on_day)


func _t(fa: String, en: String) -> String:
	return fa if Lang.is_fa() else en


func _n(v: Variant) -> String:
	return Lang.digits(str(v))


# ------------------------------------------------------------------ definitions
func housing_defs() -> Array[HousingDef]:
	var out: Array[HousingDef] = []
	for id: String in AssetRegistry.variants("animal_housing"):
		var h := AssetRegistry.load_variant("animal_housing", id) as HousingDef
		if h:
			out.append(h)
	return out


func housing_def(id: String) -> HousingDef:
	if not AssetRegistry.variants("animal_housing").has(id):
		return null
	return AssetRegistry.load_variant("animal_housing", id) as HousingDef


func animal_defs() -> Array[LivestockDef]:
	var out: Array[LivestockDef] = []
	for id: String in AssetRegistry.variants("livestock"):
		var d := AssetRegistry.load_variant("livestock", id) as LivestockDef
		if d:
			out.append(d)
	return out


func animal_def(kind: String) -> LivestockDef:
	if not AssetRegistry.variants("livestock").has(kind):
		return null
	return AssetRegistry.load_variant("livestock", kind) as LivestockDef


func def_name(d: AssetModule) -> String:
	if d == null:
		return ""
	var fa := str(d.get("name_fa"))
	return fa if Lang.is_fa() and fa != "" else d.display_name


# ------------------------------------------------------------------ housing
func housing_state(id: String) -> String:
	return str((buildings.get(id, {}) as Dictionary).get("state", "none"))


func is_built(id: String) -> bool:
	return housing_state(id) == "built"


func ready_day(id: String) -> int:
	return int((buildings.get(id, {}) as Dictionary).get("ready_day", 0))


func cost_text(h: HousingDef) -> String:
	var parts: Array = [_t("%s سکه" % _n(h.cost_gold), "%d G" % h.cost_gold)]
	for k in h.cost_items:
		parts.append("%s %s" % [_n(h.cost_items[k]), Market.local_name(str(k))])
	return " + ".join(parts)


## "" if the player can order it now, otherwise the reason.
func order_problem(id: String) -> String:
	var h := housing_def(id)
	if h == null:
		return _t("نامعلوم", "Unknown building")
	if housing_state(id) == "built":
		return _t("ساخته شده", "Already built")
	if housing_state(id) == "ordered":
		return _t("در حال ساخت", "Under construction")
	if Economy.money < h.cost_gold:
		return _t("سکه کافی نیست", "Not enough gold")
	for k in h.cost_items:
		if Economy.count(str(k)) < int(h.cost_items[k]):
			return _t("%s کافی نیست (%s/%s)" % [Market.local_name(str(k)), _n(Economy.count(str(k))), _n(h.cost_items[k])],
				"Not enough %s (%d/%d)" % [GameData.item_name(str(k)).to_lower(), Economy.count(str(k)), int(h.cost_items[k])])
	return ""


## Orders a coop / barn from the carpenter. Returns the message.
func order(id: String) -> String:
	var why := order_problem(id)
	if why != "":
		return why
	var h := housing_def(id)
	Economy.add_money(-h.cost_gold)
	for k in h.cost_items:
		Economy.remove_item(str(k), int(h.cost_items[k]))
	buildings[id] = {"state": "ordered", "ordered_day": TimeManager.day, "ready_day": TimeManager.day + h.build_days}
	Market.ledger["construction"] = int(Market.ledger.get("construction", 0)) + h.cost_gold
	changed.emit()
	return _t("نجار ساخت %s را شروع کرد؛ روز %s آماده است." % [h.name_fa, _n(TimeManager.day + h.build_days)],
		"The carpenter starts building your %s - ready on day %d." % [h.display_name.to_lower(), TimeManager.day + h.build_days])


## Finishes construction at once (smoke test / demo).
func finish_now(id: String) -> void:
	if housing_def(id) == null:
		return
	buildings[id] = {"state": "built", "ordered_day": TimeManager.day, "ready_day": TimeManager.day}
	building_ready.emit(id)
	changed.emit()


func animals_in(housing_id: String) -> Array:
	var out: Array = []
	for a: Dictionary in animals:
		var d := animal_def(str(a["kind"]))
		if d and d.housing == housing_id:
			out.append(a)
	return out


func free_space(housing_id: String) -> int:
	var h := housing_def(housing_id)
	return (h.capacity - animals_in(housing_id).size()) if h else 0


# ------------------------------------------------------------------ animals
func animal(uid: int) -> Dictionary:
	for a: Dictionary in animals:
		if int(a["uid"]) == uid:
			return a
	return {}


func count_kind(kind: String, adults_only: bool = false) -> int:
	var n := 0
	for a: Dictionary in animals:
		if str(a["kind"]) == kind and (not adults_only or bool(a["adult"])):
			n += 1
	return n


func buy_problem(kind: String) -> String:
	var d := animal_def(kind)
	if d == null:
		return _t("نامعلوم", "Unknown animal")
	if not is_built(d.housing):
		return _t("اول %s بساز" % housing_def(d.housing).name_fa, "Build the %s first" % housing_def(d.housing).display_name.to_lower())
	if free_space(d.housing) <= 0:
		return _t("جا نیست", "No room left")
	if Economy.money < d.price:
		return _t("سکه کافی نیست", "Not enough gold")
	return ""


func buy_animal(kind: String) -> String:
	var why := buy_problem(kind)
	if why != "":
		return why
	var d := animal_def(kind)
	Economy.add_money(-d.price)
	Market.ledger["livestock"] = int(Market.ledger.get("livestock", 0)) + d.price
	var a := _new_animal(d, true)
	changed.emit()
	return _t("%s «%s» به %s اضافه شد. هر روز غذایش بده!" % [d.name_fa, a["name"], housing_def(d.housing).name_fa],
		"%s \"%s\" moved into your %s. Feed it every day!" % [d.display_name, a["name"], housing_def(d.housing).display_name.to_lower()])


func _new_animal(d: LivestockDef, adult: bool) -> Dictionary:
	var names: PackedStringArray = d.names_fa if Lang.is_fa() else d.names_en
	var nm := d.display_name
	if not names.is_empty():
		nm = names[(next_uid + count_kind(d.id)) % names.size()]
	var a := {"uid": next_uid, "kind": d.id, "name": nm, "born_day": TimeManager.day, "age": d.adult_days if adult else 0,
		"adult": adult, "happiness": d.start_happiness, "fed_today": false, "petted_today": false, "product_ready": 0,
		"product_timer": 0}
	next_uid += 1
	animals.append(a)
	return a


func product_name(d: LivestockDef) -> String:
	return d.product_fa if Lang.is_fa() and d.product_fa != "" else GameData.item_name(d.product_item)


## Feeds every hungry animal in a housing (trough). Returns the message.
func feed_housing(housing_id: String) -> String:
	var fed := 0
	var missing := ""
	for a: Dictionary in animals_in(housing_id):
		if bool(a["fed_today"]):
			continue
		var r := _feed(a)
		if r == "":
			fed += 1
		else:
			missing = r
	changed.emit()
	if fed == 0 and missing != "":
		return missing
	if fed == 0:
		return _t("همه امروز غذا خورده‌اند.", "Everyone has eaten today.")
	return _t("%s حیوان غذا خوردند و خوشحال‌اند." % _n(fed), "Fed %d animal%s - they look happy." % [fed, "" if fed == 1 else "s"]) + ("" if missing == "" else "  " + missing)


func _feed(a: Dictionary) -> String:
	var d := animal_def(str(a["kind"]))
	if d == null:
		return "?"
	if Economy.count(d.feed_item) < d.feed_per_day:
		return _t("%s نداری - از میز دامداری نجاری بخر." % Market.local_name(d.feed_item),
			"No %s - buy some at the carpenter's livestock desk." % GameData.item_name(d.feed_item).to_lower())
	Economy.remove_item(d.feed_item, d.feed_per_day)
	a["fed_today"] = true
	return ""


func feed_animal(uid: int) -> String:
	var a := animal(uid)
	if a.is_empty():
		return ""
	if bool(a["fed_today"]):
		return _t("%s سیر است." % a["name"], "%s has eaten today." % a["name"])
	var r := _feed(a)
	changed.emit()
	return r if r != "" else _t("به %s غذا دادی." % a["name"], "You fed %s." % a["name"])


## Collects the product (needs the tool for cows / sheep).
func collect(uid: int) -> String:
	var a := animal(uid)
	var d := animal_def(str(a.get("kind", "")))
	if a.is_empty() or d == null:
		return ""
	var n := int(a["product_ready"])
	if n <= 0:
		return _t("فعلاً %s ندارد." % product_name(d), "No %s yet." % GameData.item_name(d.product_item).to_lower())
	if d.tool_item != "" and not Economy.has(d.tool_item):
		return _t("برای گرفتن %s، %s لازم داری (آهنگری)." % [product_name(d), Market.local_name(d.tool_item)],
			"You need a %s for that (blacksmith)." % GameData.item_name(d.tool_item).to_lower())
	Economy.add_item(d.product_item, n)
	a["product_ready"] = 0
	collected[d.product_item] = int(collected.get(d.product_item, 0)) + n
	changed.emit()
	return _t("%s %s از %s گرفتی." % [_n(n), product_name(d), a["name"]], "Got %d %s from %s." % [n, GameData.item_name(d.product_item).to_lower(), a["name"]])


func pet(uid: int) -> String:
	var a := animal(uid)
	var d := animal_def(str(a.get("kind", "")))
	if a.is_empty() or d == null:
		return ""
	if not bool(a["petted_today"]):
		a["petted_today"] = true
		a["happiness"] = minf(float(a["happiness"]) + d.pet_gain, 100.0)
		changed.emit()
	return _t("%s را نوازش کردی. شادی %s٪" % [a["name"], _n(int(a["happiness"]))], "You pet %s. Happiness %d%%" % [a["name"], int(a["happiness"])])


## E on an animal: collect > feed > pet.
func interact(uid: int) -> String:
	var a := animal(uid)
	if a.is_empty():
		return ""
	if int(a["product_ready"]) > 0:
		return collect(uid)
	if not bool(a["fed_today"]):
		return feed_animal(uid)
	return pet(uid)


func action_text(uid: int) -> String:
	var a := animal(uid)
	var d := animal_def(str(a.get("kind", "")))
	if a.is_empty() or d == null:
		return "pet"
	var nm := str(a["name"])
	if int(a["product_ready"]) > 0:
		match d.shape:
			"cow":
				return _t("دوشیدن شیر %s" % nm, "milk %s" % nm)
			"sheep":
				return _t("چیدن پشم %s" % nm, "shear %s" % nm)
		return _t("برداشتن تخم‌مرغ %s" % nm, "collect %s's egg" % nm)
	if not bool(a["fed_today"]):
		return _t("غذا دادن به %s" % nm, "feed %s" % nm)
	return _t("نوازش %s" % nm, "pet %s" % nm)


func mood(a: Dictionary) -> String:
	var d := animal_def(str(a.get("kind", "")))
	var h := float(a.get("happiness", 0.0))
	if d and h >= d.happy_above:
		return "happy"
	if d and h >= d.content_above:
		return "content"
	return "unhappy"


# ------------------------------------------------------------------ daily
func _on_day(day: int) -> void:
	if not sim_enabled:
		return
	advance_day(day)


func advance_day(day: int = -1) -> void:
	if day < 0:
		day = TimeManager.day
	for id in buildings:
		var b: Dictionary = buildings[id]
		if str(b["state"]) == "ordered" and day >= int(b["ready_day"]):
			b["state"] = "built"
			building_ready.emit(str(id))
			var h := housing_def(str(id))
			if h:
				GameEvents.notification_requested.emit(_t("%s آماده شد! حالا دام بخر." % h.name_fa, "Your %s is ready! Time to buy animals." % h.display_name.to_lower()))
	for a: Dictionary in animals:
		var d := animal_def(str(a["kind"]))
		if d == null:
			continue
		var fed := bool(a["fed_today"])
		a["happiness"] = clampf(float(a["happiness"]) + (d.fed_gain if fed else -d.unfed_loss), 0.0, 100.0)
		a["age"] = int(a["age"]) + 1
		if not bool(a["adult"]) and int(a["age"]) >= d.adult_days:
			a["adult"] = true
			GameEvents.notification_requested.emit(_t("%s بزرگ شد!" % a["name"], "%s has grown up!" % a["name"]))
		if bool(a["adult"]):
			a["product_timer"] = int(a.get("product_timer", 0)) + 1
			if int(a["product_timer"]) >= d.product_every_days:
				a["product_timer"] = 0
				var q := daily_yield(d, float(a["happiness"]), fed)
				a["product_ready"] = mini(int(a["product_ready"]) + q, d.product_qty * 2)
		a["fed_today"] = false
		a["petted_today"] = false
	for d in animal_defs():
		try_breed(d.id)
	changed.emit()


## Product units for one day: full when happy, half when content, none when unhappy.
func daily_yield(d: LivestockDef, happiness: float, fed: bool) -> int:
	if happiness >= d.happy_above and fed:
		return d.product_qty
	if happiness >= d.content_above:
		return maxi(d.product_qty / 2, 1) if fed else d.product_qty / 2
	return 0


## Two happy adults of a kind + room + enough days since the last birth.
func can_breed(kind: String) -> bool:
	var d := animal_def(kind)
	if d == null or not is_built(d.housing) or free_space(d.housing) <= 0:
		return false
	var happy := 0
	for a: Dictionary in animals:
		if str(a["kind"]) == kind and bool(a["adult"]) and float(a["happiness"]) >= d.happy_above:
			happy += 1
	if happy < 2:
		return false
	return TimeManager.day - int(last_birth.get(kind, -999)) >= d.breed_every_days


func try_breed(kind: String, force: bool = false) -> Dictionary:
	if not can_breed(kind):
		return {}
	var d := animal_def(kind)
	if not force and rng.randf() >= d.breed_chance:
		return {}
	var a := _new_animal(d, false)
	last_birth[kind] = TimeManager.day
	born_total += 1
	animal_born.emit(int(a["uid"]))
	GameEvents.notification_requested.emit(_t("یک %s کوچولو به دنیا آمد: %s!" % [d.name_fa, a["name"]], "A baby %s was born: %s!" % [d.display_name.to_lower(), a["name"]]))
	changed.emit()
	return a


# ------------------------------------------------------------------ save
func reset() -> void:
	buildings.clear()
	animals.clear()
	next_uid = 1
	last_birth.clear()
	collected.clear()
	born_total = 0
	changed.emit()


func to_save() -> Dictionary:
	return {"buildings": buildings.duplicate(true), "animals": animals.duplicate(true), "next_uid": next_uid,
		"last_birth": last_birth.duplicate(), "collected": collected.duplicate(), "born_total": born_total}


func from_save(d: Dictionary) -> void:
	buildings = (d.get("buildings", {}) as Dictionary).duplicate(true)
	animals = []
	for a: Dictionary in d.get("animals", []):
		var c := a.duplicate()
		c["uid"] = int(c.get("uid", 0))
		c["age"] = int(c.get("age", 0))
		c["product_ready"] = int(c.get("product_ready", 0))
		c["product_timer"] = int(c.get("product_timer", 0))
		animals.append(c)
	next_uid = int(d.get("next_uid", animals.size() + 1))
	last_birth = (d.get("last_birth", {}) as Dictionary).duplicate()
	collected = (d.get("collected", {}) as Dictionary).duplicate()
	born_total = int(d.get("born_total", 0))
	changed.emit()
