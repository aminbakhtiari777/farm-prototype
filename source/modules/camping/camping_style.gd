class_name CampingStyle
extends AssetModule
## v7b camping trip: drive (or walk) to the pine forest or the lookout hill and
## press 6 to set up a tent and a campfire (needs 1 firewood, or buys a bundle).
## E at the tent sleeps till morning (fully rested); the campfire warms and
## lights the night. Camps are remembered. Consumer: Camping.

@export var name_fa: String = ""
## {id, en, fa, pos (V2)}
@export var spots: Array = []
## m: how close to a spot you must be
@export var radius: float = 14.0
@export var tent_color: Color = Color(0.85, 0.45, 0.15)
## gold if you have no firewood
@export var firewood_cost: int = 6
## fatigue removed by a night in the tent (0..1)
@export var rest_bonus: float = 1.0
## setup, sleep, too_far, packed -> [{en, fa}]
@export var lines: Dictionary = {}
