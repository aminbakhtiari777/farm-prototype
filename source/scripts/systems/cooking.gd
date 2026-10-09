class_name Cooking
extends RefCounted
## v5b hands-on cooking at a home kitchen. Modules: "dishes" (DishDef
## collection: ingredients, hunger), "ingredients" (IngredientDef collection:
## shop items), "cooking" (CookingStyle: the ordered cooking actions - prepare,
## add salt, add spices, cook, eat). A Cooking session walks through the steps
## in order; eating counts as the day's meal (Needs).

signal step_done(step_id: String)
signal finished(dish_id: String)

var dish: DishDef
var stove: Node3D
var step_index: int = 0
var seasoned_salt: bool = false
var seasoned_spices: bool = false
var done: bool = false
var log_lines: PackedStringArray = PackedStringArray()


static func style() -> CookingStyle:
	return Modules.style("cooking") as CookingStyle


static func dishes() -> Array[DishDef]:
	var out: Array[DishDef] = []
	for id: String in AssetRegistry.variants("dishes"):
		var d := AssetRegistry.load_variant("dishes", id) as DishDef
		if d:
			out.append(d)
	out.sort_custom(func(a: DishDef, b: DishDef) -> bool: return a.sort_order < b.sort_order)
	return out


static func dish_by_id(id: String) -> DishDef:
	if not AssetRegistry.variants("dishes").has(id):
		return null
	return AssetRegistry.load_variant("dishes", id) as DishDef


static func ingredient(id: String) -> IngredientDef:
	if not AssetRegistry.variants("ingredients").has(id):
		return null
	return AssetRegistry.load_variant("ingredients", id) as IngredientDef


static func ingredient_name(id: String) -> String:
	if id.begins_with("category:"):
		return Kitchenware.input_name(id)
	var ing := ingredient(id)
	if ing == null:
		return GameData.item_name(id)
	return ing.name_fa if Lang.is_fa() and ing.name_fa != "" else ing.display_name


static func dish_name(d: DishDef) -> String:
	return d.name_fa if Lang.is_fa() and d.name_fa != "" else d.display_name


static func steps() -> Array:
	var st := style()
	return st.steps if st else []


static func step_label(s: Dictionary) -> String:
	return str(s.get("fa" if Lang.is_fa() else "en", s.get("id", "?")))


## What is missing to start this dish ("" = ready).
static func missing(d: DishDef) -> String:
	for k in d.inputs:
		var need := int(d.inputs[k])
		if Kitchenware.count_input(str(k)) < need:
			return ("%s %s لازم است" % [Lang.digits(str(need)), ingredient_name(str(k))]) if Lang.is_fa() else "need %d %s (have %d)" % [need, ingredient_name(str(k)), Kitchenware.count_input(str(k))]
	var tool_why := Kitchenware.missing_tool(d)
	if tool_why != "":
		return tool_why
	var st := style()
	var has_salt := false
	var has_spices := false
	for s in steps():
		has_salt = has_salt or str(s.get("id")) == "salt"
		has_spices = has_spices or str(s.get("id")) == "spices"
	if (has_salt or (st and st.auto_season)) and Economy.count("salt") < d.salt:
		return "نمک لازم است" if Lang.is_fa() else "need salt"
	if (has_spices or (st and st.auto_season)) and Economy.count("spices") < d.spices:
		return "ادویه لازم است" if Lang.is_fa() else "need spices"
	var ks := Modules.style("kitchen") as KitchenStyle
	if ks and ks.needs_power() and not PowerGrid.power_on:
		return "اجاق برقی برق ندارد" if Lang.is_fa() else "the electric stove has no power"
	return ""


static func can_cook(d: DishDef) -> bool:
	return missing(d) == ""


func _init(d: DishDef, at_stove: Node3D = null) -> void:
	dish = d
	stove = at_stove


func current_step() -> Dictionary:
	var list := steps()
	return list[step_index] if step_index < list.size() else {}


func current_id() -> String:
	return str(current_step().get("id", ""))


## Performs a step. Steps must be done in order; returns the message.
func do_step(step_id: String, tree: SceneTree) -> String:
	if done:
		return ""
	var cur := current_id()
	if step_id != cur:
		var want := step_label(current_step())
		return ("اول باید: %s" % want) if Lang.is_fa() else "First: %s" % want
	var s := current_step()
	var st := style()
	var msg := ""
	match step_id:
		"prepare":
			var why := missing(dish)
			if why != "":
				return ("نمی‌شود: %s" % why) if Lang.is_fa() else "Can't cook %s: %s" % [dish.display_name, why]
			for k in dish.inputs:
				Kitchenware.remove_input(str(k), int(dish.inputs[k]))
			if st and st.auto_season:
				Economy.remove_item("salt", dish.salt)
				Economy.remove_item("spices", dish.spices)
				seasoned_salt = true
				seasoned_spices = true
			msg = "مواد را شستی و خرد کردی." if Lang.is_fa() else "You wash and chop the ingredients."
		"salt":
			if not Economy.remove_item("salt", dish.salt):
				return "نمک نداری!" if Lang.is_fa() else "You have no salt!"
			seasoned_salt = true
			msg = "کمی نمک زدی." if Lang.is_fa() else "A pinch of salt."
		"spices":
			if not Economy.remove_item("spices", dish.spices):
				return "ادویه نداری!" if Lang.is_fa() else "You have no spices!"
			seasoned_spices = true
			msg = "زردچوبه و ادویه زدی." if Lang.is_fa() else "Turmeric and spices go in."
		"cook":
			var ks := Modules.style("kitchen") as KitchenStyle
			if ks and ks.needs_power() and not PowerGrid.power_on:
				return "اجاق برقی برق ندارد" if Lang.is_fa() else "The electric stove has no power"
			msg = ("%s دارد می‌پزد..." % dish_name(dish)) if Lang.is_fa() else "%s sizzles in the pan..." % dish.display_name
		"eat":
			var bonus := st.seasoned_bonus if st and seasoned_salt and seasoned_spices else 0.0
			bonus += Kitchenware.meal_bonus()
			Needs.eat(dish.hunger + bonus, true)
			var player := tree.get_first_node_in_group(&"player")
			if player and player.has_method("restore_stamina"):
				player.call("restore_stamina", dish.stamina)
			done = true
			msg = ("%s را خوردی. نوش جان! وعده‌ی امروز خورده شد (+%s انرژی)." % [dish_name(dish), Lang.digits(str(int(dish.stamina)))]) if Lang.is_fa() else "You eat the %s. Delicious! Today's meal done (+%d stamina)." % [dish.display_name, int(dish.stamina)]
			msg = msg.replace(" ✓", "")
	TimeManager.advance_minutes(float(s.get("minutes", 1.0)) * Kitchenware.step_mult(step_id))
	var player2 := tree.get_first_node_in_group(&"player")
	if player2 and float(s.get("stamina", 0.0)) > 0.0 and player2.has_method("spend_stamina"):
		player2.call("spend_stamina", float(s.get("stamina", 0.0)))
	var snd := str(s.get("sound", ""))
	if snd != "":
		if stove:
			Sfx.play_at(StringName(snd), stove.global_position + Vector3(0, 1.0, 0), -4.0)
		else:
			Sfx.play(StringName(snd), -6.0)
	step_index += 1
	log_lines.append(msg)
	step_done.emit(step_id)
	if done:
		finished.emit(dish.id)
	return msg
