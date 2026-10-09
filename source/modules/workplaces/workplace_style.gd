class_name WorkplaceStyle
extends AssetModule
## Town workplaces (v5a): carpenter, blacksmith, mason, fruit shop, clothing
## shop, jeweller, tool shop, electrical shop. Defines what each shop sells and
## buys (item definitions live here too) and the shopfront look (awnings).
## Consumers: Building (shopfronts), InteriorBuilder (workshop interiors),
## ShopPanel (stock), GameData (items).

## shop id -> {title, greeting, sells: [ids / "type:x"], buys: ["category:x"/ids], buy_mult}
@export var shops: Dictionary = {}
## item id -> GameData item dictionary (materials, outfits, jewellery...).
@export var items: Dictionary = {}
@export var awnings: bool = true
@export var awning_colors: Array = [Color(0.8, 0.3, 0.25), Color(0.25, 0.5, 0.35), Color(0.3, 0.4, 0.7), Color(0.85, 0.65, 0.2)]
@export var wall_tint: Color = Color(1, 1, 1)
@export var flat_roofs: bool = false
