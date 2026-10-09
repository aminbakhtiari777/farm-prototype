class_name TreeStyle
extends AssetModule
## Trees: which models to scatter, seasonal tints, bare-in-winter behaviour.
## Consumer: NatureScatter (rebuilds live on swap).

@export_dir var model_dir: String = "res://assets/third_party/quaternius/nature/"
@export var model_ext: String = ".gltf"
@export var broadleaf: PackedStringArray = []
@export var pines: PackedStringArray = []
@export var edge_models: PackedStringArray = []  ## forest edge outside the play area
@export var dead_tree: String = ""
@export_range(0.0, 1.0) var pine_fraction: float = 0.3
@export var scale_range: Vector2 = Vector2(0.8, 1.15)
@export var leaf_tints: Dictionary = {}  ## season id -> Color
@export var pine_tints: Dictionary = {}
@export var bare_in_winter: bool = true


func model_path(model: String) -> String:
	return model_dir.path_join(model + model_ext)


func get_variant(season: String) -> Dictionary:
	return {"leaf_tint": leaf_tints.get(season, Color.WHITE), "pine_tint": pine_tints.get(season, Color.WHITE),
		"bare": bare_in_winter and season == "winter"}


func asset_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for m in broadleaf + pines + edge_models:
		out.append(model_path(m))
	if dead_tree != "":
		out.append(model_path(dead_tree))
	return out
