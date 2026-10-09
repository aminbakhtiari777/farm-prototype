extends Node
## v5c living economy (autoload "Market"). Modules: "market_economy"
## (MarketEconomyStyle: supply-and-demand rules), "producers" (ProducerDef
## collection: who makes what, which shop it restocks), "wages" (WagesStyle:
## jobs pay wages, townspeople spend on food and the doctor).
##
## Every traded good has a town-wide stock. Its price multiplier is
##   clamp((target / stock) ^ elasticity, min_mult, max_mult)
## so selling a lot lowers prices and shortages raise them. Each morning:
##   1. exports leave town (keeps demand alive),
##   2. producers restock their shop up to the target (inputs come from the
##      town stock; if all their workers are ill, they stay closed),
##   3. outside traders pull surpluses / gaps back toward the target,
##   4. the closing price goes into the 7-day history (trends board).
## Townspeople earn wages at payday and pay for their meals (food taken from
## the stock at today's price) and for the doctor (the city covers anyone who
## can't pay - nobody is refused treatment).

signal prices_changed
signal produced(day: int)
signal wallets_changed

## Turned off by the smoke test outside its own sections.
var sim_enabled: bool = true
var stock: Dictionary = {}  ## item id -> float units
var history: Dictionary = {}  ## item id -> Array of daily prices (oldest first)
var wallets: Dictionary = {}  ## resident full name -> int gold
var ledger: Dictionary = {}  ## today's flows
var ledger_yesterday: Dictionary = {}
var last_production: Dictionary = {}  ## producer id -> {item: units}
var idle_producers: PackedStringArray = PackedStringArray()
var rng := RandomNumberGenerator.new()
var _targets: Dictionary = {}
var _tracked_cache: Dictionary = {}

const LEDGER_KEYS := ["wages", "food", "meals", "doctor", "city_health", "player_sales", "player_buys", "exports", "construction", "livestock"]


func _ready() -> void:
	rng.seed = 9091
	_zero_ledger()
	ledger_yesterday = ledger.duplicate()
	TimeManager.day_started.connect(_on_day)
	TimeManager.hour_changed.connect(_on_hour)
	Economy.item_sold.connect(_on_player_sold)
	Needs.meal_eaten.connect(_on_meal)
	Needs.cured.connect(_on_cured)
	AssetRegistry.module_changed.connect(func(t: String, _m: AssetModule) -> void:
		if t in ["producers", "market_economy", "livestock", "ingredients", "workplaces", "crop_types", "recipes"]:
			_targets.clear()
			_tracked_cache.clear()
			prices_changed.emit())


func style() -> MarketEconomyStyle:
	return Modules.style("market_economy") as MarketEconomyStyle


func wages_style() -> WagesStyle:
	return Modules.style("wages") as WagesStyle


func producers() -> Array[ProducerDef]:
	var out: Array[ProducerDef] = []
	for id: String in AssetRegistry.variants("producers"):
		var p := AssetRegistry.load_variant("producers", id) as ProducerDef
		if p:
			out.append(p)
	out.sort_custom(func(a: ProducerDef, b: ProducerDef) -> bool: return a.sort_order < b.sort_order)
	return out


func producer(id: String) -> ProducerDef:
	if not AssetRegistry.variants("producers").has(id):
		return null
	return AssetRegistry.load_variant("producers", id) as ProducerDef


## Producers that restock this shop.
func producers_for_shop(shop_id: String) -> Array[ProducerDef]:
	var out: Array[ProducerDef] = []
	for p in producers():
		if p.shop == shop_id:
			out.append(p)
	return out


# ------------------------------------------------------------------ goods
func is_tracked(id: String) -> bool:
	if _tracked_cache.has(id):
		return bool(_tracked_cache[id])
	var it := GameData.item(id)
	var st := style()
	var ok := false
	if not it.is_empty() and st:
		var t := str(it.get("type", ""))
		ok = id in st.extra_tracked or t in st.tracked_types or (t == "tool_item")
		if t == "produce" and float(it.get("sell", 0)) <= 0.0:
			ok = false
	_tracked_cache[id] = ok
	return ok


## Base price the farmer gets (before supply/demand, season and weather).
func base_sell(id: String) -> float:
	var it := GameData.item(id)
	if it.has("sell"):
		return float(it["sell"])
	if it.has("buy"):
		return float(it["buy"]) * 0.6
	return 0.0


## Base shop price (retail): the item's buy price, or produce x markup.
func base_buy(id: String) -> float:
	var it := GameData.item(id)
	if it.has("buy"):
		return float(it["buy"])
	var st := style()
	return base_sell(id) * (st.retail_markup if st else 1.6)


func target(id: String) -> float:
	if _targets.is_empty():
		_build_targets()
	if _targets.has(id):
		return float(_targets[id])
	var st := style()
	return float(st.default_target if st else 20)


func _build_targets() -> void:
	var st := style()
	var buffer := st.buffer_days if st else 2.5
	var dflt := float(st.default_target if st else 20)
	for p in producers():
		for k in p.outputs:
			var t := maxf(float(p.outputs[k]) * buffer * 2.0, 6.0)
			_targets[k] = maxf(float(_targets.get(k, 0.0)), minf(t, dflt * 2.0))
	_targets["_built"] = 1.0


func stock_of(id: String) -> float:
	if not stock.has(id):
		return target(id)
	return float(stock[id])


func available(id: String) -> int:
	return int(floor(stock_of(id) + 0.001))


func ratio(id: String) -> float:
	return stock_of(id) / maxf(target(id), 0.01)


## Supply/demand price multiplier (1.0 for untracked goods).
func mult(id: String) -> float:
	if not is_tracked(id):
		return 1.0
	var st := style()
	if st == null:
		return 1.0
	var s := maxf(stock_of(id), 0.5)
	return clampf(pow(target(id) / s, st.elasticity), st.min_mult, st.max_mult)


func is_shortage(id: String) -> bool:
	var st := style()
	return is_tracked(id) and (available(id) <= 0 or ratio(id) < (st.shortage_below if st else 0.25))


## Today's shop price (retail) of a market good.
func buy_price(id: String) -> int:
	return maxi(int(round(base_buy(id) * mult(id))), 1)


## Price change vs yesterday's closing price, in percent (0 if no history).
func change_pct(id: String) -> int:
	var h: Array = history.get(id, [])
	if h.is_empty():
		return 0
	var prev := float(h[-1])
	return int(round((float(buy_price(id)) / maxf(prev, 1.0) - 1.0) * 100.0))


func take(id: String, n: float) -> bool:
	if not is_tracked(id):
		return true
	if stock_of(id) + 0.001 < n:
		return false
	stock[id] = stock_of(id) - n
	prices_changed.emit()
	return true


func add(id: String, n: float) -> void:
	if not is_tracked(id) or n <= 0.0:
		return
	stock[id] = stock_of(id) + n
	prices_changed.emit()


## Price change as words (Persian has no arrow glyphs in Vazirmatn, and +/- signs
## get reordered in right-to-left text): "۱۸٪ گران‌تر" / "+18%".
func trend_text(ch: int, same: bool = true) -> String:
	if ch == 0:
		return ("بدون تغییر" if Lang.is_fa() else "no change") if same else ""
	if Lang.is_fa():
		return "%s٪ %s" % [Lang.digits(str(absi(ch))), "گران‌تر" if ch > 0 else "ارزان‌تر"]
	return "%+d%%" % ch


func local_name(id: String) -> String:
	var it := GameData.item(id)
	if Lang.is_fa():
		if str(it.get("name_fa", "")) != "":
			return str(it["name_fa"])
		var st := style()
		if st and st.item_names_fa.has(id):
			return str(st.item_names_fa[id])
	return GameData.item_name(id)


# ------------------------------------------------------------------ player hooks
func _on_player_sold(id: String, count: int, total: int) -> void:
	var st := style()
	add(id, float(count) * (st.sell_impact if st else 1.0))
	ledger["player_sales"] = int(ledger.get("player_sales", 0)) + total


## Called by Shops.purchase after a successful buy.
func on_player_bought(id: String, count: int, total: int) -> void:
	take(id, float(count))
	ledger["player_buys"] = int(ledger.get("player_buys", 0)) + total


# ------------------------------------------------------------------ townspeople
func wallet(key: String) -> int:
	if not wallets.has(key):
		var ws := wages_style()
		wallets[key] = int(ws.start_savings if ws else 200) + absi(key.hash()) % 120
	return int(wallets[key])


func _spend(key: String, amount: int) -> int:
	var have := wallet(key)
	var paid := mini(have, amount)
	wallets[key] = have - paid
	return paid


func wage_of(r: Dictionary) -> int:
	var ws := wages_style()
	if ws == null:
		return 0
	var job := str(r.get("job", "")).to_lower()
	if ws.wages.has(job):
		var w := int(ws.wages[job])
		return w if w > 0 else ws.allowance
	return ws.default_wage


## Pays every resident's wage (payday). Returns the total.
func pay_wages() -> int:
	var total := 0
	for r: Dictionary in Population.residents():
		var key := Population.full_name(r)
		var w := wage_of(r)
		wallets[key] = wallet(key) + w
		total += w
	ledger["wages"] = int(ledger.get("wages", 0)) + total
	wallets_changed.emit()
	return total


func _on_hour(hour: int, day: int) -> void:
	if not sim_enabled:
		return
	var ws := wages_style()
	if ws and hour == ws.payday_hour and posmod(day, 7) != ws.day_off:
		pay_wages()


## A townsperson eats: one share of a basket food is bought at today's price.
func _on_meal(who: String, _hunger: float) -> void:
	if who == "player" or not sim_enabled:
		return
	npc_meal(who)


func npc_meal(who: String) -> String:
	var st := style()
	if st == null or st.npc_food_basket.is_empty():
		return ""
	var food := _pick_food(st)
	if food == "":
		return ""
	var units := st.npc_meal_units
	take(food, minf(units, stock_of(food)))
	var cost := maxi(int(round(float(buy_price(food)) * units)), 1)
	var paid := _spend(who, cost)
	ledger["food"] = int(ledger.get("food", 0)) + paid
	ledger["meals"] = int(ledger.get("meals", 0)) + 1
	return food


func _pick_food(st: MarketEconomyStyle) -> String:
	var total := 0.0
	var options: Array = []
	for k in st.npc_food_basket:
		if GameData.item(str(k)).is_empty() or stock_of(str(k)) < st.npc_meal_units:
			continue
		options.append(str(k))
		total += float(st.npc_food_basket[k])
	if options.is_empty():
		return ""
	var roll := rng.randf() * total
	for k: String in options:
		roll -= float(st.npc_food_basket[k])
		if roll <= 0.0:
			return k
	return options[-1]


func _on_cured(who: String, by_doctor: bool) -> void:
	if who == "player" or not by_doctor:
		return
	npc_pays_doctor(who, 0)


## The doctor's fee for a townsperson; the city pays what they can't.
func npc_pays_doctor(who: String, fee: int) -> int:
	if fee <= 0:
		var d := Needs.illness_def("cold")
		fee = Needs.fee_of(d.id) if d else 80
	var paid := _spend(who, fee)
	ledger["doctor"] = int(ledger.get("doctor", 0)) + paid
	ledger["city_health"] = int(ledger.get("city_health", 0)) + (fee - paid)
	wallets_changed.emit()
	return paid


## Average savings of the townsfolk.
func average_savings() -> int:
	var res := Population.residents()
	if res.is_empty():
		return 0
	var sum := 0
	for r: Dictionary in res:
		sum += wallet(Population.full_name(r))
	return int(round(float(sum) / res.size()))


# ------------------------------------------------------------------ daily cycle
func _zero_ledger() -> void:
	ledger = {}
	for k in LEDGER_KEYS:
		ledger[k] = 0


func _on_day(day: int) -> void:
	if not sim_enabled:
		return
	advance_day(day)


## One market morning (also called by the smoke test).
func advance_day(day: int = -1) -> void:
	ledger_yesterday = ledger.duplicate()
	_zero_ledger()
	_record_history()
	_exports()
	run_production()
	_recover()
	produced.emit(day if day >= 0 else TimeManager.day)
	prices_changed.emit()


func _record_history() -> void:
	var st := style()
	var keep := st.history_days if st else 7
	for id in tracked_goods():
		var h: Array = history.get(id, [])
		h.append(buy_price(id))
		while h.size() > keep:
			h.pop_front()
		history[id] = h


## Goods worth showing (board items + everything with a stock entry or producer).
func tracked_goods() -> PackedStringArray:
	var out := PackedStringArray()
	var pb := Modules.style("price_board") as PriceBoardStyle
	if pb:
		for id in pb.items:
			if is_tracked(id) and not id in out:
				out.append(id)
	for p in producers():
		for k in p.outputs:
			if is_tracked(str(k)) and not str(k) in out:
				out.append(str(k))
	for k in stock:
		if not str(k) in out:
			out.append(str(k))
	return out


func _exports() -> void:
	var st := style()
	if st == null:
		return
	var sold := 0
	for k in st.exports:
		var id := str(k)
		if not is_tracked(id):
			continue
		var n := minf(float(st.exports[k]), stock_of(id))
		if n > 0.0:
			stock[id] = stock_of(id) - n
			sold += int(round(n * float(buy_price(id)) * 0.6))
	ledger_yesterday["exports"] = sold


## True when at least one worker of the producer is healthy (or it needs none).
func producer_staffed(p: ProducerDef) -> bool:
	if p.worker_jobs.is_empty():
		return true
	var found := false
	for r: Dictionary in Population.residents():
		if str(r.get("job", "")) in p.worker_jobs:
			found = true
			var s: Dictionary = Needs.npc.get(Population.full_name(r), {})
			if str(s.get("illness", "")) == "":
				return true
	return not found


## Producers restock their goods up to the target (inputs from the stock).
func run_production() -> Dictionary:
	last_production = {}
	idle_producers = PackedStringArray()
	for p in producers():
		if not producer_staffed(p):
			idle_producers.append(p.id)
			continue
		# How much is wanted (gap to the target, at most the daily output).
		var want := 0.0
		for k in p.outputs:
			var gap := target(str(k)) - stock_of(str(k))
			want = maxf(want, clampf(gap / maxf(float(p.outputs[k]), 0.01), 0.0, 1.0))
		if want <= 0.0:
			last_production[p.id] = {}
			continue
		var factor := want
		for k in p.inputs:
			var need := float(p.inputs[k]) * want
			if need > 0.0:
				factor = minf(factor, want * clampf(stock_of(str(k)) / need, 0.0, 1.0))
		for k in p.inputs:
			var use := float(p.inputs[k]) * factor
			if use > 0.0:
				stock[str(k)] = stock_of(str(k)) - use
		var made := {}
		for k in p.outputs:
			var n := float(p.outputs[k]) * factor
			if n > 0.0:
				stock[str(k)] = stock_of(str(k)) + n
				made[str(k)] = snappedf(n, 0.1)
		last_production[p.id] = made
	return last_production


func _recover() -> void:
	var st := style()
	if st == null:
		return
	for k in stock.keys():
		var t := target(str(k))
		stock[k] = float(stock[k]) + (t - float(stock[k])) * st.recovery_per_day


# ------------------------------------------------------------------ save
func reset() -> void:
	stock.clear()
	history.clear()
	wallets.clear()
	last_production.clear()
	idle_producers = PackedStringArray()
	_zero_ledger()
	ledger_yesterday = ledger.duplicate()
	_targets.clear()
	_tracked_cache.clear()
	prices_changed.emit()


func to_save() -> Dictionary:
	return {"stock": stock.duplicate(), "history": history.duplicate(true), "wallets": wallets.duplicate(),
		"ledger": ledger.duplicate(), "ledger_yesterday": ledger_yesterday.duplicate(), "last_production": last_production.duplicate(true),
		"idle": Array(idle_producers)}


func from_save(d: Dictionary) -> void:
	reset()
	for k in (d.get("stock", {}) as Dictionary):
		stock[str(k)] = float(d["stock"][k])
	for k in (d.get("history", {}) as Dictionary):
		history[str(k)] = (d["history"][k] as Array).duplicate()
	for k in (d.get("wallets", {}) as Dictionary):
		wallets[str(k)] = int(d["wallets"][k])
	for k in (d.get("ledger", {}) as Dictionary):
		ledger[str(k)] = int(d["ledger"][k])
	ledger_yesterday = (d.get("ledger_yesterday", ledger_yesterday) as Dictionary).duplicate()
	last_production = (d.get("last_production", {}) as Dictionary).duplicate(true)
	idle_producers = PackedStringArray(d.get("idle", []))
	prices_changed.emit()
