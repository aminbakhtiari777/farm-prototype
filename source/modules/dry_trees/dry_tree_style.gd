class_name DryTreeStyle
extends AssetModule
## v6a dry (dead) trees around the forest edges, always present: chopped ones
## regrow (a new dry tree appears) every morning. Chop with the axe (E) for
## firewood, dry wood (sold to the carpenter, who saws it into boards) and
## sometimes a rough board. Consumers: DryTrees, Lifestyle.

@export var name_fa: String = ""
@export var count: int = 14
@export var hits: int = 3
@export var regrow_per_day: int = 3
## item id -> amount per felled tree.
@export var yields: Dictionary = {"firewood": 3, "dry_wood": 2}
@export var board_chance: float = 0.35
@export var bark_color: Color = Color(0.42, 0.36, 0.3)
@export var stamina_per_hit: float = 4.0
## New items: id -> GameData item dictionary.
@export var items: Dictionary = {}


func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
