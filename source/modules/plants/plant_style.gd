class_name PlantStyle
extends AssetModule
## Grass, wildflowers and ground-cover plants (bushes, ferns, flower clumps).
## Consumer: NatureScatter (grass blades + ground cover, rebuilt live).

@export_dir var model_dir: String = "res://assets/third_party/quaternius/nature/"
@export var model_ext: String = ".gltf"
## Ground cover entries: [model, count, min scale, max scale, clearance]
@export var ground_cover: Array = []
@export var grass_height: Vector2 = Vector2(0.22, 0.42)  ## min / max blade height
@export var grass_width: float = 0.05
@export var grass_density: float = 1.0  ## multiplies grass counts
@export var flower_colors: PackedColorArray = PackedColorArray()


func asset_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for k in ground_cover:
		out.append(model_dir.path_join(str(k[0]) + model_ext))
	return out
