extends Node
## Money, inventory, buying and selling. Autoload "Economy".
##
## Prices come from data/game_data.json:
##   sell price = base "sell" x seasonal demand x weather price multiplier
##   seasonal demand = item "demand"[season] if given, otherwise
##   in-season crops 1.0 and out-of-season crops `out_of_season_mult` (rarer).
## Shipping (bin at the farmhouse or the town market) pays instantly.

signal money_changed(money: int)
signal inventory_changed
signal selected_seed_changed(item_id: String)
signal item_sold(item_id: String, count: int, total: int)
## v5c: emitted by Shops.purchase (Market takes the units from the town stock).
signal item_bought(item_id: String, count: int, total: int)

var money: int = 0
var inventory: Dictionary = {}  ## item_id -> count
var selected_seed: String = ""
## Water left in the watering can; refill at the well, pond, sea or a tool rack.
var water: int = 20

signal water_changed(water: int, capacity: int)


func _ready() -> void:
	reset()


func reset() -> void:
	var start: Dictionary = GameData.data.get("start", {})
	money = int(start.get("money", 500))
	inventory = {}
	var inv: Dictionary = start.get("inventory", {})
	for id in inv:
		inventory[id] = int(inv[id])
	selected_seed = ""
	water = can_capacity()
	_fix_selected_seed()
	money_changed.emit(money)
	inventory_changed.emit()


# ---------------------------------------------------------------- inventory
func count(id: String) -> int:
	return int(inventory.get(id, 0))


func has(id: String, amount: int = 1) -> bool:
	return count(id) >= amount


func add_item(id: String, amount: int = 1) -> void:
	if amount <= 0:
		return
	inventory[id] = count(id) + amount
	_fix_selected_seed()
	inventory_changed.emit()


func remove_item(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	inventory[id] = count(id) - amount
	if inventory[id] <= 0:
		inventory.erase(id)
	_fix_selected_seed()
	inventory_changed.emit()
	return true


func item_type(id: String) -> String:
	return str(GameData.item(id).get("type", ""))


func owned_seeds() -> Array[String]:
	var out: Array[String] = []
	for id in inventory:
		if item_type(id) == "seed" and count(id) > 0:
			out.append(id)
	out.sort()
	return out


func sellable_items() -> Array[String]:
	var out: Array[String] = []
	for id in inventory:
		if item_type(id) in ["produce", "animal_product"] and count(id) > 0:
			out.append(id)
	out.sort()
	return out


func cycle_seed() -> void:
	var seeds := owned_seeds()
	if seeds.is_empty():
		_set_selected("")
		return
	var i := seeds.find(selected_seed)
	_set_selected(seeds[(i + 1) % seeds.size()])


func _fix_selected_seed() -> void:
	if selected_seed != "" and count(selected_seed) > 0:
		return
	var seeds := owned_seeds()
	_set_selected(seeds[0] if not seeds.is_empty() else "")


func _set_selected(id: String) -> void:
	if id != selected_seed:
		selected_seed = id
		selected_seed_changed.emit(id)


func season_id_is_winter() -> bool:
	return TimeManager.season_id() == "winter"


# ---------------------------------------------------------------- prices
## Crops that can be planted in the current season.
## Season hook: asks the active "garden_rules" module (v8 extends it).
func crop_in_season(crop_id: String, season_id: String = "") -> bool:
	if season_id == "":
		season_id = TimeManager.season_id()
	var rules := Modules.style("garden_rules") as GardenRules
	var def := GameData.crop_def(crop_id)
	if rules and def:
		return rules.can_plant(def, season_id)
	return season_id in GameData.crop(crop_id).get("seasons", [])


## Seasonal demand multiplier for selling an item.
func demand_multiplier(id: String) -> float:
	var item := GameData.item(id)
	var season := TimeManager.season_id()
	var demand: Dictionary = item.get("demand", {})
	if demand.has(season):
		return float(demand[season])
	var pricing: Dictionary = GameData.data.get("pricing", {})
	var crop_id := str(item.get("crop_of", id))
	if not GameData.crop(crop_id).is_empty():
		if crop_in_season(crop_id, season):
			return float(pricing.get("in_season_mult", 1.0))
		return float(pricing.get("out_of_season_mult", 1.5))
	return 1.0


func weather_multiplier() -> float:
	return float(GameData.weather(TimeManager.weather_id).get("price_mult", 1.0))


func price_multiplier(id: String) -> float:
	# v5c: x supply and demand (Market, "market_economy" module).
	return demand_multiplier(id) * weather_multiplier() * Market.mult(id)


func sell_price(id: String) -> int:
	return int(round(Market.base_sell(id) * price_multiplier(id)))


## v5c: what the farmer can sell: produce, animal products (milk), and
## market goods with a sell price (eggs from your hens, furniture...).
func is_sellable(id: String) -> bool:
	var t := item_type(id)
	if t in ["produce", "animal_product"]:
		return true
	return t in ["ingredient", "furniture", "feed"] and Market.is_tracked(id) and Market.base_sell(id) > 0.0


func buy_price(id: String) -> int:
	return int(GameData.item(id).get("buy", 0))


## Items the shop offers right now: seeds for the current season + tools.
func shop_stock() -> Array[String]:
	var out: Array[String] = []
	var items := GameData.items()
	for id in items:
		var item: Dictionary = items[id]
		if not item.has("buy"):
			continue
		if item.get("type") == "seed" and not crop_in_season(str(item.get("crop", ""))):
			continue
		if item.get("type") == "tool" and has(id):
			continue
		if item.get("type") == "tool" and not tool_unlocked(id):
			continue
		out.append(id)
	return out


func can_buy(id: String, amount: int = 1) -> bool:
	return id in shop_stock() and money >= buy_price(id) * amount


func buy(id: String, amount: int = 1) -> bool:
	if not can_buy(id, amount):
		return false
	money -= buy_price(id) * amount
	add_item(id, amount)
	money_changed.emit(money)
	return true


## Sells `amount` of an item (all if amount < 0). Returns the money earned.
func sell(id: String, amount: int = -1) -> int:
	var n := count(id) if amount < 0 else mini(amount, count(id))
	if n <= 0 or not is_sellable(id):
		return 0
	var total := sell_price(id) * n
	remove_item(id, n)
	money += total
	money_changed.emit(money)
	item_sold.emit(id, n, total)
	return total


func sell_all() -> int:
	var total := 0
	for id in sellable_items():
		total += sell(id)
	return total


## v5a shops: buy at an explicit price (shop stock is checked by Shops).
func buy_at(id: String, amount: int, unit_price: int) -> bool:
	if amount <= 0 or money < unit_price * amount:
		return false
	money -= unit_price * amount
	add_item(id, amount)
	money_changed.emit(money)
	return true


## v5a shops / market stalls: sell with a price multiplier (stall bonus).
func sell_with_bonus(id: String, amount: int, mult: float) -> int:
	var n := count(id) if amount < 0 else mini(amount, count(id))
	if n <= 0 or not is_sellable(id):
		return 0
	var total := int(round(sell_price(id) * mult)) * n
	remove_item(id, n)
	money += total
	money_changed.emit(money)
	item_sold.emit(id, n, total)
	return total


func add_money(amount: int) -> void:
	money += amount
	money_changed.emit(money)


# ---------------------------------------------------------------- watering can
func can_capacity() -> int:
	var cfg: Dictionary = GameData.data.get("watering_can", {})
	if has("copper_can"):
		return int(cfg.get("copper_capacity", 40))
	return int(cfg.get("capacity", 20))


## Uses one charge of water. Returns false when the can is empty.
func use_water() -> bool:
	if water <= 0:
		return false
	water -= 1
	water_changed.emit(water, can_capacity())
	return true


func refill_can() -> void:
	water = can_capacity()
	water_changed.emit(water, can_capacity())


func set_water(value: int) -> void:
	water = clampi(value, 0, can_capacity())
	water_changed.emit(water, can_capacity())


## Fish/shell category of an item ("fish", "shell" or "").
func item_category(id: String) -> String:
	return str(GameData.item(id).get("category", ""))


## Snapshot for SaveGame.
func to_save() -> Dictionary:
	return {"money": money, "inventory": inventory.duplicate(), "selected_seed": selected_seed, "water": water}


func from_save(data: Dictionary) -> void:
	money = int(data.get("money", money))
	inventory = {}
	var inv: Dictionary = data.get("inventory", {})
	for id in inv:
		if int(inv[id]) > 0:
			inventory[str(id)] = int(inv[id])
	selected_seed = str(data.get("selected_seed", ""))
	_fix_selected_seed()
	water = int(data.get("water", can_capacity()))
	money_changed.emit(money)
	inventory_changed.emit()
	selected_seed_changed.emit(selected_seed)
	water_changed.emit(water, can_capacity())


## Tool unlocks (tool_types modules): sold from `unlock_day`, and an upgrade
## is only offered to players who own the tool it upgrades.
func tool_unlocked(id: String) -> bool:
	var item := GameData.item(id)
	if TimeManager.day < int(item.get("unlock_day", 1)):
		return false
	var req := str(item.get("requires", ""))
	return req == "" or has(req)


## Best owned tool (highest tier) of a kind, or the starter tool; null if none.
func best_tool(kind: String) -> ToolDef:
	var best: ToolDef = null
	for tid: String in GameData.tools:
		var t := GameData.tools[tid] as ToolDef
		if t.kind != kind or not (t.starter or has(t.item_id)):
			continue
		if best == null or t.tier > best.tier:
			best = t
	return best
