class_name CampfireStyle
extends AssetModule
## v6a beach campfire: lit with chopped firewood, burns for a few game hours,
## log seats around it, grill a fish to eat. Consumers: Campfire, Lifestyle.

@export var name_fa: String = ""
@export var firewood_cost: int = 2
@export var burn_hours: float = 3.0
@export var seats: int = 4
@export var grill_hunger: float = 45.0
@export var grill_stamina: float = 35.0
@export var flame_color: Color = Color(1.0, 0.55, 0.18)
@export var light_energy: float = 3.0
## Sitting by the fire recovers stamina faster (x).
@export var warmth_mult: float = 1.6
