class_name DeepSeaStyle
extends AssetModule
## v6a deep-sea fishing: water farther than `deep_distance` metres from the
## shore counts as "deep"; these rarer, pricier fish live there (Persian Gulf
## species). Consumers: FishingMinigame (_probe / pick_fish), GameData items.

@export var name_fa: String = ""
@export var deep_distance: float = 22.0
## id -> GameData item dictionary (type produce, category fish, fish{water: deep}).
@export var fish: Dictionary = {}


func to_items() -> Dictionary:
	var out := {}
	for k in fish:
		var it: Dictionary = (fish[k] as Dictionary).duplicate(true)
		it["module_item"] = true
		out[k] = it
	return out
