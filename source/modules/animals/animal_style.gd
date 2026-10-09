class_name AnimalStyle
extends AssetModule
## Farm animals (sheep for now): scene + colours. Consumer: Sheep (colours
## live; the scene path is used by spawners - see docs/MODULES.md).

@export var scene_path: String = "res://scenes/animals/Sheep.tscn"
@export var wool_color: Color = Color(0.96, 0.95, 0.9)
@export var face_color: Color = Color(0.25, 0.2, 0.18)


func asset_paths() -> PackedStringArray:
	return PackedStringArray([scene_path])
