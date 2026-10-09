class_name HouseVarietyStyle
extends AssetModule
## v7b.1: homes differ more - roof shape, wall tint, shutter colour, porch,
## window count and a small front planter - deterministic per home id.
## Consumer: HouseVariety (Building._apply_layout).

@export var name_fa: String = ""
@export var enabled: bool = true
@export var wall_tints: Array = []
@export var roof_tints: Array = []
@export var shutter_palette: Array = []
@export var porch_chance: float = 0.55
@export var timber_chance: float = 0.35
@export var tall_chance: float = 0.3
