class_name VehicleStyle
extends AssetModule
## v6b parked cars you can get into (E) and drive on the town roads (W/S gas +
## brake, A/D steer, Space handbrake, R horn, E get out). Replaces the static
## parked cars. Positions are remembered (WorldMemory). Consumer: Vehicles / Car.

@export var name_fa: String = ""
## {model, pos (V2), yaw (deg), drivable, color_en, color_fa}
@export var cars: Array = []
@export var models_dir: String = "res://assets/third_party/kenney/cars/"
## m/s
@export var max_speed: float = 11.0
@export var reverse_speed: float = 4.0
@export var accel: float = 5.5
@export var brake: float = 10.0
@export var steer_deg: float = 34.0
@export var dealership_note_en: String = ""
@export var dealership_note_fa: String = ""
