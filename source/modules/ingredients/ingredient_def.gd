class_name IngredientDef
extends AssetModule
## A cooking ingredient (collection "ingredients", v5b): bought at the shops,
## used by the hands-on dishes. Registered as a GameData item
## (type "ingredient", category "ingredient"). Consumers: GameData, Shops
## (grocery counter in the supermarket, market stalls), Cooking.

@export var name_fa: String = ""
@export var price: int = 10
## Shop ids that sell it ("grocery" = supermarket counter, "stall:<id>").
@export var sold_at: PackedStringArray = PackedStringArray(["grocery"])
@export var color: Color = Color(0.9, 0.9, 0.9)
## Visual on the cutting board / in the pan: "drumstick", "egg", "veg", "grain", "leaf", "powder".
@export var shape: String = "veg"
## "main" ingredients go into the pan; "seasoning" are added in their own step.
@export var role: String = "main"


func to_items() -> Dictionary:
	return {id: {"name": display_name, "name_fa": name_fa, "type": "ingredient", "category": "ingredient", "buy": price,
		"description": description, "module_item": true}}
