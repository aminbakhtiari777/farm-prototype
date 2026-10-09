class_name LivestockDef
extends AssetModule
## v5c farm animal (collection "livestock"): chicken, cow, sheep. Bought from
## the carpenter's livestock desk once its housing (animal_housing module) is
## built. Feed it every day for its product; unfed animals get unhappy and
## produce less. Two happy adults breed young that grow up after `adult_days`.
## Consumers: Ranch autoload, RanchWorld / FarmAnimal (visual), LivestockPanel,
## GameData (product + feed items), Market (products are market goods).

@export var name_fa: String = ""
@export var housing: String = "coop"
@export var price: int = 100
@export var product_item: String = "eggs"
@export var product_fa: String = ""
## Product units per day when happy (>= happy_above); half (rounded down,
## at least 1) when content; none when unhappy (< content_above).
@export var product_qty: int = 1
## Days between products (sheep: wool every other day).
@export var product_every_days: int = 1
@export var happy_above: float = 60.0
@export var content_above: float = 30.0
## Tool needed to collect ("" = by hand): milk pail, shears (blacksmith).
@export var tool_item: String = ""
@export var feed_item: String = "chicken_feed"
@export var feed_per_day: int = 1
@export var fed_gain: float = 12.0
@export var unfed_loss: float = 25.0
@export var pet_gain: float = 5.0
@export var start_happiness: float = 70.0
## Young -> adult after this many days.
@export var adult_days: int = 3
## Days between births per kind; breed_chance per day once allowed.
@export var breed_every_days: int = 4
@export var breed_chance: float = 0.5
## Visual: "bird", "cow", "sheep".
@export var shape: String = "bird"
@export var body_color: Color = Color(0.95, 0.93, 0.88)
@export var accent_color: Color = Color(0.85, 0.15, 0.12)
@export var size: float = 1.0
@export var young_scale: float = 0.55
@export var walk_speed: float = 0.7
## Names given to new animals (Persian / English).
@export var names_fa: PackedStringArray = PackedStringArray()
@export var names_en: PackedStringArray = PackedStringArray()
## Product / feed / tool item definitions this animal introduces.
@export var items: Dictionary = {}


func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
