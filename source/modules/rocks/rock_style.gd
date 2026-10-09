class_name RockStyle
extends AssetModule
## Rocks / stones scattered in the fields. Consumer: NatureScatter.

@export_dir var model_dir: String = "res://assets/third_party/quaternius/nature/"
@export var model_ext: String = ".gltf"
## Each entry: [model, count, min scale, max scale, clearance]
@export var kinds: Array = []
@export var tint: Color = Color.WHITE
@export var view_distance: float = 110.0


func asset_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for k in kinds:
		out.append(model_dir.path_join(str(k[0]) + model_ext))
	return out
