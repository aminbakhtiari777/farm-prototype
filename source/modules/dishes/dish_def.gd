class_name DishDef
extends AssetModule
## A hands-on home dish (collection "dishes", v5b): ingredients + the cooking
## steps from the "cooking" module. Eating it counts as the day's meal.
## Consumers: Cooking (session rules), CookingPanel, CookingStation (visuals).

@export var name_fa: String = ""
## ingredient id -> count (main ingredients).
@export var inputs: Dictionary = {}
## Seasonings used by the salt / spices steps.
@export var salt: int = 1
@export var spices: int = 1
@export var hunger: float = 70.0
@export var stamina: float = 50.0
@export var cooked_color: Color = Color(0.85, 0.65, 0.3)
@export var raw_color: Color = Color(0.95, 0.85, 0.6)
@export var sort_order: int = 0
## v6a: kitchenware item needed to make it ("blender"). Inputs may use
## "category:fish" (any fish).
@export var requires: String = ""
