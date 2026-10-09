class_name FruitGardenStyle
extends AssetModule
## v6b fruit gardens behind some townspeople's houses. The trees belong to the
## family: picking without asking is theft (a report is filed for the police -
## hook for v7 justice); asking the owner (greeting first today) makes it a gift.
## Consumer: FruitGardens.

@export var name_fa: String = ""
## {home, trees: [fruit ids], rows, cols}
@export var gardens: Array = []
## fruit id -> {en, fa, color, item}
@export var fruits: Dictionary = {}
@export var regrow_days: int = 3
## for v7 (recorded, not charged yet)
@export var theft_fine: int = 50
## fruit items (GameData)
@export var items: Dictionary = {}


func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
