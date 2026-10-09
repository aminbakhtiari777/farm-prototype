class_name AmbientSoundsStyle
extends AssetModule
## v7b.1 ambient beds from placed 3D emitters (not 2D): birds in trees by day,
## crickets in the fields at night, a crowd murmur around the town square by day,
## the river, distant traffic along the main streets, sea waves along the shore
## (BeachBuilder's emitters). Only the nearest few of each kind play; the rest are
## stopped (no mixing cost). Wind gusts blow past from a random direction overhead
## (sky / clouds); distant thunder only in rain / storms. The old 2D beds are
## turned down to a faint base. Consumers: AmbientEmitters, AmbienceManager (bed_scale).

@export var name_fa: String = ""
## kind -> {stream, count, active, db, unit, range, when}
@export var kinds: Dictionary = {}
@export var gusts: PackedStringArray = PackedStringArray()
## s between gusts (shorter in rain / storm)
@export var gust_interval: Vector2 = Vector2(8.0, 20.0)
@export var gust_db: float = -9.0
@export var thunder: PackedStringArray = PackedStringArray()
## s between rumbles in a storm (x3 in rain)
@export var thunder_interval: Vector2 = Vector2(12.0, 35.0)
@export var thunder_db: float = -2.0
## old non-positional bird / cricket beds kept at this level
@export var bed_2d_scale: float = 0.3
## s between nearest-emitter checks
@export var update_interval: float = 0.5
