class_name FenceStyle
extends AssetModule
## Fences / poles. Consumer: Fence (rebuilds live).

@export var post_spacing: float = 2.2
@export var post_height: float = 1.15
@export var post_size: float = 0.13
@export var rails: int = 2
@export var rail_height: float = 0.09
@export var color: Color = Color(1, 1, 1)  ## tints the wood material
@export var material_path: String = "res://assets/materials/wood.tres"


func asset_paths() -> PackedStringArray:
	return PackedStringArray([material_path]) if material_path != "" else PackedStringArray()
