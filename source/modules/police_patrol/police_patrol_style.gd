class_name PolicePatrolStyle
extends AssetModule
## v6b police car: patrols the town loop (Main St, Oak Ave, Maple St, Pine Ln)
## with two officers, stops for people in front of it. Hook for v7 justice
## (fruit theft reports). Consumer: PolicePatrol.

@export var name_fa: String = ""
@export var model: String = "police"
@export var speed: float = 6.5
## V2 points (loop)
@export var route: Array = []
## on patrol between
@export var hours: Vector2 = Vector2(6, 23)
@export var lights: bool = true
@export var base: Vector2 = Vector2(-27.0, -53.9)
