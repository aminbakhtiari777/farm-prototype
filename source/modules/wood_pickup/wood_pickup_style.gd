class_name WoodPickupStyle
extends AssetModule
## v6b working pickup: a woodcutter drives to the dry trees, loads felled logs
## and brings them to the carpenter, who saws them into boards (Market stock:
## dry_wood -> wood_plank). Consumer: WoodPickup.

@export var name_fa: String = ""
@export var trips_per_day: int = 2
@export var logs_per_trip: int = 3
@export var speed: float = 7.0
@export var color: Color = Color(0.75, 0.2, 0.15)
## hours a trip starts
@export var start_hours: Array = []
## carpenter yard
@export var yard: Vector2 = Vector2(-28.0, -45.2)
@export var forest_stop: Vector2 = Vector2(-70.0, -46.0)
@export var chop_seconds: float = 4.0
