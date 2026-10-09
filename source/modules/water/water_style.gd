class_name WaterStyle
extends AssetModule
## Sea + pond water. Consumer: BeachBuilder (live shader parameters).

@export var shader_path: String = "res://assets/shaders/water.gdshader"
@export var sea: Dictionary = {}  ## shader param -> value
@export var pond: Dictionary = {}


func asset_paths() -> PackedStringArray:
	return PackedStringArray([shader_path])
