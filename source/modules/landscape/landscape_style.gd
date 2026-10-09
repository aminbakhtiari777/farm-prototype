class_name LandscapeStyle
extends AssetModule
## Scenery outside / around the play area: the dense tall forest belt,
## far tree rings (cheap impostors), mountains and the river.
## Consumer: Landscape (scripts/world/landscape.gd).

@export var forest_rings: int = 4
@export var forest_density: float = 1.0
## Random scale range of the edge forest trees.
@export var forest_scale: Vector2 = Vector2(1.5, 2.4)
## Low-poly impostor trees between the forest belt and the mountains.
@export var far_trees: int = 900
@export var mountain_height: float = 70.0
@export var mountain_count: int = 16
@export var mountain_color: Color = Color(0.38, 0.4, 0.42)
## Fraction of the mountain height where snow starts (>1 = no snow).
@export var snow_line: float = 0.62
@export var river: bool = true
@export var river_width: float = 4.0
@export var river_color: Color = Color(0.2, 0.42, 0.5)
