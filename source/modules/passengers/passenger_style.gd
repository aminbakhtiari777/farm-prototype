class_name PassengerStyle
extends AssetModule
## v7b passengers: now and then a townsperson waits at a stop and waves for a
## ride. Stop next to them (in a car) and they get in; drive them to their
## destination (green ring + minimap direction) and stop: they pay the fare,
## generous people tip, everyone remembers a safe ride. Consumer: Passengers.

@export var name_fa: String = ""
## {id, en, fa, pos (V2)}
@export var stops: Array = []
@export var fare_base: int = 8
@export var fare_per_100m: float = 5.0
## game hours between new passengers
@export var every_hours: float = 1.5
@export var hours: Vector2 = Vector2(7.0, 23.0)
## m
@export var pickup_radius: float = 6.0
## real seconds a passenger waits
@export var max_wait: float = 240.0
## hail, board, arrive, tip, slow_down, gave_up -> [{en, fa}]
@export var lines: Dictionary = {}
