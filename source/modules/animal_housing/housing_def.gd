class_name HousingDef
extends AssetModule
## v5c animal housing (collection "animal_housing"): ordered from the
## carpenter (gold + wood), built in `build_days`, holds `capacity` animals of
## the listed kinds, with a fenced paddock and a feed trough.
## Consumers: Ranch autoload, RanchWorld (construction site / building /
## paddock / trough), LivestockPanel.

@export var name_fa: String = ""
@export var kinds: PackedStringArray = PackedStringArray()
@export var capacity: int = 6
@export var cost_gold: int = 500
## item id -> count (planks, nails...).
@export var cost_items: Dictionary = {}
@export var build_days: int = 1
## Farm position (x, z), facing (deg, 0 = door to +z) and building size.
@export var position: Vector2 = Vector2.ZERO
@export var yaw_deg: float = 0.0
@export var size: Vector3 = Vector3(3, 2.4, 2.5)
## Fenced paddock (centre offset from position, size x/z).
@export var paddock_offset: Vector2 = Vector2(0, 3.5)
@export var paddock_size: Vector2 = Vector2(6, 5)
@export var wall_color: Color = Color(0.72, 0.3, 0.22)
@export var roof_color: Color = Color(0.35, 0.3, 0.28)
@export var trim_color: Color = Color(0.95, 0.93, 0.88)
