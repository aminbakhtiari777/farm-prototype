class_name FishingGearStyle
extends AssetModule
## v6a fishing gear: which shop sells rods (the carpenter by default) and the
## better rod's bonuses. Consumers: Shops (extra stock), FishingMinigame.

@export var name_fa: String = ""
## Shop ids that sell the rods.
@export var sold_at: PackedStringArray = PackedStringArray(["carpenter"])
@export var rods: PackedStringArray = PackedStringArray(["fishing_rod", "pro_rod"])
## Pro rod: bite wait x this, rare fish weight x rare_bonus.
@export var pro_wait_mult: float = 0.6
@export var rare_bonus: float = 1.8
@export var items: Dictionary = {}


func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
