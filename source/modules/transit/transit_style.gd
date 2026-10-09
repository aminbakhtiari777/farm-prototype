class_name TransitStyle
extends AssetModule
## v7b.1 vehicle module (first entry: the city bus). `vehicles` describes each
## vehicle type (size, colours, engine sound id, seats) so more vehicles can be
## added as data. The bus line drives a loop with stops (shelter + Persian sign +
## timetable), obeys lights and limits, residents get on and off, and you can
## ride it (E at the door, pay the fare, E again to get off at the next stop).
## A second bus stands at the terminal on Main St for you to drive (licence
## rules apply). Consumers: Transit, BusLine, BusStop, DrivableBus, CarAudio.

@export var name_fa: String = ""
## id -> {en, fa, length, width, height, color, stripe, engine, seats, top_kmh}
@export var vehicles: Dictionary = {}
## {id, en, fa, vehicle, route: [V2], stops: [{id, pos (road centre), side (V2 shelter), en, fa}], dwell_s, speed}
@export var line: Dictionary = {}
@export var fare: int = 5
## timetable: a bus every N minutes
@export var interval_min: int = 30
## service hours
@export var hours: Vector2 = Vector2(6.0, 23.0)
## {pos, yaw, vehicle, en, fa} drivable bus parking
@export var terminal: Dictionary = {}
@export var residents_ride: bool = true
@export var max_riders: int = 6
