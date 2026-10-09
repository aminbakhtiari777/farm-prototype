class_name RecipeDef
extends AssetModule
## One crafting / cooking recipe (collection type "recipes": every recipe is
## active). station "workbench" = farm workshop, "stove" = any home kitchen.
## Output items are registered in GameData (type produce = sellable).

@export_enum("workbench", "stove") var station: String = "workbench"
## item_id -> count
@export var inputs: Dictionary = {}
@export var output_id: String = ""
@export var output_name: String = ""
@export var output_count: int = 1
## Sell price of the output (0 = not sellable / already defined elsewhere).
@export var output_sell: int = 0
@export var output_category: String = "crafted"
## Meals (station stove): eaten right away, restoring this much stamina.
@export var stamina: float = 0.0
@export var sort_order: int = 0


func is_meal() -> bool:
	return stamina > 0.0


## Items this recipe adds to GameData (its output, if not a known item).
func to_items() -> Dictionary:
	if output_id == "" or is_meal():
		return {}
	var it := {"name": output_name if output_name != "" else output_id.capitalize(), "type": "produce" if output_sell > 0 else "misc",
			"category": output_category, "description": description, "recipe": id}
	if output_sell > 0:
		it["sell"] = output_sell
	return {output_id: it}


func inputs_text() -> String:
	var parts: PackedStringArray = []
	for k in inputs:
		parts.append("%d %s" % [int(inputs[k]), GameData.item_name(str(k))])
	return ", ".join(parts) if not parts.is_empty() else "nothing"
