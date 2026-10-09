class_name Kitchenware
extends RefCounted
## v6a kitchenware helpers ("kitchenware" collection, KitchenwareDef). Owned
## kitchenware is just items in the bag. Cooking asks here how fast a step is
## and whether a dish is unlocked; electric pieces only help with power on.


static func defs() -> Array[KitchenwareDef]:
	var out: Array[KitchenwareDef] = []
	for m in Modules.all("kitchenware"):
		if m is KitchenwareDef:
			out.append(m)
	out.sort_custom(func(a: KitchenwareDef, b: KitchenwareDef) -> bool: return a.sort_order < b.sort_order)
	return out


static func def_for_item(item_id: String) -> KitchenwareDef:
	for d in defs():
		if d.item_id == item_id:
			return d
	return null


static func owned() -> Array[KitchenwareDef]:
	var out: Array[KitchenwareDef] = []
	for d in defs():
		if Economy.has(d.item_id):
			out.append(d)
	return out


static func _works(d: KitchenwareDef) -> bool:
	return not d.needs_power or PowerGrid.power_on


## Minutes multiplier for a cooking step. Per slot only the best piece counts.
static func step_mult(step_id: String) -> float:
	var best := {}
	for d in owned():
		if not _works(d) or not d.speed.has(step_id):
			continue
		var m := float(d.speed[step_id])
		var key := d.slot
		best[key] = minf(float(best.get(key, 1.0)), m)
	var out := 1.0
	for k in best:
		out *= float(best[k])
	return clampf(out, 0.25, 1.0)


static func meal_bonus() -> float:
	var best := {}
	for d in owned():
		if _works(d):
			best[d.slot] = maxf(float(best.get(d.slot, 0.0)), d.meal_bonus)
	var out := 0.0
	for k in best:
		out += float(best[k])
	return out


## "" when the dish needs no special tool or you own a working one.
static func missing_tool(dish: DishDef) -> String:
	if dish == null or dish.requires == "":
		return ""
	var d := def_for_item(dish.requires)
	if d == null:
		for k in defs():
			if k.slot == dish.requires:
				d = k
				break
	var have := false
	for o in owned():
		if o.item_id == dish.requires or o.slot == dish.requires:
			have = have or _works(o)
	if have:
		return ""
	var nm := (d.name_fa if Lang.is_fa() and d and d.name_fa != "" else (d.display_name if d else dish.requires))
	return Lang.tt("%s لازم است (هایپرمارکت)" % nm, "need a %s (hypermarket)" % nm)


## Ingredient keys may be "category:<cat>" (any item of that category).
static func count_input(key: String) -> int:
	if not key.begins_with("category:"):
		return Economy.count(key)
	var cat := key.substr(9)
	var n := 0
	for id in Economy.inventory:
		if Economy.item_category(str(id)) == cat:
			n += int(Economy.inventory[id])
	return n


## Removes amount; for categories the cheapest items go first.
static func remove_input(key: String, amount: int) -> bool:
	if not key.begins_with("category:"):
		return Economy.remove_item(key, amount)
	var cat := key.substr(9)
	var ids: Array = []
	for id in Economy.inventory:
		if Economy.item_category(str(id)) == cat:
			ids.append(str(id))
	ids.sort_custom(func(a: String, b: String) -> bool: return Economy.sell_price(a) < Economy.sell_price(b))
	var left := amount
	for id in ids:
		while left > 0 and Economy.count(id) > 0:
			Economy.remove_item(id, 1)
			left -= 1
	return left <= 0


static func input_name(key: String) -> String:
	if key == "category:fish":
		return Lang.tt("ماهی (هر نوع)", "fish (any)")
	if key.begins_with("category:"):
		return key.substr(9)
	return ""
