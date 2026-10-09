class_name StreetPlantsStyle
extends AssetModule
## v7b.1 varied street trees, bushes, flowers and planters along sidewalks and
## beside houses (deterministic per spot). MultiMesh where possible. Placed
## outside the asphalt + sidewalk band so they don't collide with traffic
## paint / lights. Consumer: StreetPlants.

@export var name_fa: String = ""
@export var enabled: bool = true
## m beyond (half + sidewalk)
@export var road_margin: float = 0.4
## m (matches TownBuilder.SIDEWALK_W)
@export var sidewalk: float = 1.8
## m along a road
@export var tree_spacing: float = 9.5
## {id, kind (tree/bush/flowers/planter), color, size}
@export var species: Array = []
## replace the pink ball 'ice cream' flower beds in the square
@export var clear_old_flowers: bool = true
