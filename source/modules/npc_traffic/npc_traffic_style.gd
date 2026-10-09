class_name NpcTrafficStyle
extends AssetModule
## v7b.1 townsfolk traffic: a few cars drive loops on the road graph (right-hand
## lane), stop at red lights and STOP signs, keep the speed limit, keep a gap to
## the car in front and stop for people. Consumer: NpcTraffic (TrafficCar).

@export var name_fa: String = ""
## {model, color, loop: [V2 waypoints]}
@export var cars: Array = []
## m to the vehicle ahead
@export var gap: float = 7.0
## cars park outside these hours
@export var active_hours: Vector2 = Vector2(6.0, 23.5)
