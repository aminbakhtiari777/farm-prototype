class_name KitchenwareDef
extends AssetModule
## v6a kitchenware (collection "kitchenware"): one item each - plates, pots,
## pans, forks, glasses, blender, microwave and their upgrades - sold at the
## hypermarket. Owning it speeds up cooking steps or unlocks dishes.
## Consumers: Kitchenware, Cooking, CookingPanel, Hypermarket, GameData.

@export var name_fa: String = ""
@export var item_id: String = ""
@export var price: int = 50
## "plates", "pot", "pan", "cutlery", "glasses", "blender", "microwave".
@export var slot: String = ""
## Higher tier replaces lower of the same slot (needs the lower one).
@export var tier: int = 1
@export var requires: String = ""
## cooking step id -> minutes multiplier (0.7 = 30 % faster).
@export var speed: Dictionary = {}
## Extra hunger / stamina when eating a home-cooked dish.
@export var meal_bonus: float = 0.0
## Dish ids this item unlocks.
@export var unlocks: PackedStringArray = PackedStringArray()
@export var needs_power: bool = false
@export var color: Color = Color(0.9, 0.9, 0.9)
## Visual on the shelf: "plate", "pot", "pan", "fork", "glass", "blender", "microwave".
@export var shape: String = "plate"
@export var sort_order: int = 0


func to_items() -> Dictionary:
	return {item_id: {"name": display_name, "name_fa": name_fa, "type": "kitchenware", "category": "kitchenware",
		"buy": price, "description": description, "module_item": true, "slot": slot, "tier": tier, "requires": requires}}
