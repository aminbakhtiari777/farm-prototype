class_name CivicStyle
extends AssetModule
## Civic buildings (v5a): water office, electricity office (tied to the v4
## PowerGrid), school, university (+ desks for hospital / city hall / police).
## Consumers: Building (porticos, substation), InteriorBuilder (classrooms,
## offices), InteriorItem (service desks).

## desk id -> {title, lines: [..]}
@export var desks: Dictionary = {}
@export var columns: bool = true
@export var column_color: Color = Color(0.95, 0.93, 0.88)
@export var flag_color: Color = Color(0.2, 0.55, 0.3)
@export var wall_tint: Color = Color(1, 1, 1)
## Electricity office: transformer yard + cable to the town power post.
@export var substation: bool = true
## Water office: water tower next to the building.
@export var water_tower: bool = true
