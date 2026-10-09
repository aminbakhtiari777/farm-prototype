class_name BuildingStyle
extends AssetModule
## House / building look. Applied when a Building is built (new buildings and
## after a reload). Consumer: Building.

@export var wall_tint: Color = Color.WHITE  ## multiplies each building's wall colour
@export var roof_palette: PackedColorArray = PackedColorArray()  ## empty = keep layout colours
@export var trim_color: Color = Color(0.95, 0.93, 0.88)
@export var shutter_palette: PackedColorArray = PackedColorArray()
@export var detail_texture: String = "res://assets/materials/detail_noise_tex.tres"
@export var detail_normal: String = "res://assets/materials/detail_normal_tex.tres"


func roof_for(index: int, fallback: Color) -> Color:
	return roof_palette[index % roof_palette.size()] if not roof_palette.is_empty() else fallback


func asset_paths() -> PackedStringArray:
	return PackedStringArray([detail_texture, detail_normal])
