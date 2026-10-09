class_name CarSoundStyle
extends AssetModule
## v7b.1 procedural car sounds (synthesised at start, no files): an engine loop
## per car model (firing frequency, cylinders, harmonics, roughness; diesel
## knock for the bus / truck / tractor) whose pitch and volume follow RPM from
## speed and gear; a horn per model; indicator ticks; tyre squeal on hard braking
## or sharp turns; door clunks. Consumers: CarAudio (DrivableCar + RoadCar).

@export var name_fa: String = ""
## model -> {hz, cyl, harm (Array), rough, diesel, idle_rpm, max_rpm, db, gears}
@export var engines: Dictionary = {}
## model -> [f1, f2] Hz
@export var horns: Dictionary = {}
@export var indicator_hz: float = 1800.0
## s
@export var indicator_period: float = 0.42
## m/s2 that makes the tyres squeal
@export var squeal_decel: float = 7.5
## model -> pitch
@export var door_pitch: Dictionary = {}
## NPC cars / bus / police have engines too (nearest few)
@export var npc_engines: bool = true
@export var max_npc_engines: int = 4
