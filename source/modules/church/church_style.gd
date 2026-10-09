class_name ChurchStyle
extends AssetModule
## Church (v5a): steep roof, bell tower with spire and cross, stained-glass
## windows, pews and an altar inside; the bell rings at `bell_hours`.
## Volume: Settings "bell_volume". Consumers: Building (ChurchBuilder),
## InteriorBuilder (nave), BellPlayer.

@export var wall_color: Color = Color(0.82, 0.78, 0.7)
@export var roof_color: Color = Color(0.32, 0.3, 0.34)
@export var spire_color: Color = Color(0.3, 0.32, 0.36)
@export var tower_height: float = 11.0
@export var glass_colors: Array = [Color(0.8, 0.2, 0.25), Color(0.2, 0.4, 0.85), Color(0.95, 0.8, 0.25)]
@export var pew_color: Color = Color(0.42, 0.28, 0.16)
@export var bell_sound: String = "res://assets/audio/sfx/church_bell.ogg"
@export var bell_db: float = -12.0
@export var bell_hours: PackedInt32Array = PackedInt32Array([9, 12, 18])
@export var max_distance: float = 90.0


func asset_paths() -> PackedStringArray:
	return PackedStringArray([bell_sound])
