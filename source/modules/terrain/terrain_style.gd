class_name TerrainStyle
extends AssetModule
## Ground / terrain look: shader parameter overrides on the terrain material
## plus the colour palette used for vertex colours. Consumer: Terrain (live).

@export var material_path: String = "res://assets/materials/terrain.tres"
@export var shader_overrides: Dictionary = {}  ## param -> value
@export var grass_color: Color = Color(1, 1, 1)  ## multiplies the meadow colour
@export var dirt_color: Color = Color(1, 1, 1)
@export var sand_color: Color = Color(1, 1, 1)


func asset_paths() -> PackedStringArray:
	return PackedStringArray([material_path])
