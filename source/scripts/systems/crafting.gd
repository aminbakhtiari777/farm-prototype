class_name Crafting
extends RefCounted
## v5a crafting + cooking rules. Recipes are the "recipes" module collection
## (RecipeDef); the workbench (farm workshop, "crafting" module) crafts
## station "workbench", every home stove ("kitchen" module) cooks station
## "stove". Crafting takes game time (CraftingStyle.craft_minutes) and a bit
## of stamina; meals restore stamina right away.


static func recipes(station: String) -> Array[RecipeDef]:
	var out: Array[RecipeDef] = []
	for rid: String in GameData.recipes:
		var r := GameData.recipes[rid] as RecipeDef
		if r and r.station == station:
			out.append(r)
	out.sort_custom(func(a: RecipeDef, b: RecipeDef) -> bool: return a.sort_order < b.sort_order)
	return out


static func missing(r: RecipeDef) -> String:
	for k in r.inputs:
		var need := int(r.inputs[k])
		if Economy.count(str(k)) < need:
			return "need %d %s (have %d)" % [need, GameData.item_name(str(k)), Economy.count(str(k))]
	if r.station == "stove":
		var ks := Modules.style("kitchen") as KitchenStyle
		if ks and ks.needs_power() and not PowerGrid.power_on:
			return "the electric stove has no power"
	return ""


static func can_craft(r: RecipeDef) -> bool:
	return missing(r) == ""


## Crafts / cooks once. Returns the message for the HUD ("" = failed).
static func craft(r: RecipeDef, tree: SceneTree) -> String:
	var why := missing(r)
	if why != "":
		return "Can't make %s: %s" % [r.display_name, why]
	for k in r.inputs:
		Economy.remove_item(str(k), int(r.inputs[k]))
	var cs := Modules.style("crafting") as CraftingStyle
	var player := tree.get_first_node_in_group(&"player")
	var msg := ""
	if r.is_meal():
		if player and player.has_method("restore_stamina"):
			player.call("restore_stamina", r.stamina)
		TimeManager.advance_minutes(10.0)
		msg = "You cooked and ate %s. +%d stamina" % [r.display_name, int(r.stamina)]
	else:
		Economy.add_item(r.output_id, r.output_count)
		if player and player.has_method("spend_stamina") and cs:
			player.call("spend_stamina", cs.stamina_cost)
		TimeManager.advance_minutes(cs.craft_minutes if cs else 20.0)
		msg = "Crafted %d %s" % [r.output_count, GameData.item_name(r.output_id)]
		if player and player.has_method("play_tool"):
			player.call("play_tool", "hammer")
	GameEvents.crafted.emit(r.id)
	return msg
