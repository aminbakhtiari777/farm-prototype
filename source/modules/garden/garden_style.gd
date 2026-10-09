class_name GardenStyle
extends AssetModule
## Look of the farm garden (beds, soil, row paths, garden fence).
## Consumer: Garden (scripts/world/garden/garden.gd), live swap.

@export var soil_dry: Color = Color(0.4, 0.27, 0.16)
@export var soil_wet: Color = Color(0.24, 0.16, 0.1)
@export var path_color: Color = Color(0.62, 0.55, 0.42)
@export var edge_color: Color = Color(0.45, 0.32, 0.2)
## Timber edging around each bed.
@export var raised_beds: bool = false
@export var fence_height: float = 1.0
## Price (G) of one extra bed row.
@export var expand_cost: int = 150
