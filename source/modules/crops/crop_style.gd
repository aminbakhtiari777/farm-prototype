class_name CropStyle
extends AssetModule
## Look of the procedural crops on the farm plot. Consumer: FarmPlot (live).

@export var plant_scale: float = 1.0
@export var leaf_tint: Color = Color.WHITE  ## multiplies each crop's leaf colour
@export var fruit_tint: Color = Color.WHITE
@export var roughness: float = 0.7
