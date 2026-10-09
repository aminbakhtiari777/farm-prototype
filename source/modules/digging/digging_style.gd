class_name DiggingStyle
extends AssetModule
## v6b digging: with the hoe (or a shovel) dig a hole in open ground (E while
## holding Shift... or the 'dig' prompt); holes stay (WorldMemory), sometimes
## turn up stones, worms or an old coin, and fill back in after some days.
## Consumer: Digging.

@export var name_fa: String = ""
## {item, chance, en, fa}
@export var finds: Array = []
@export var refill_days: int = 4
@export var max_holes: int = 24
@export var stamina: float = 6.0
@export var radius: float = 0.35
## finds as items (GameData)
@export var items: Dictionary = {}


func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
