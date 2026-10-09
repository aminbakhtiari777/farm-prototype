class_name LandmarkStyle
extends AssetModule
## v6b symbolic town-square landmark: a tall brick clock tower whose clock shows
## the game time and chimes on the hour (or a monument). Consumer: Landmark.

@export var name_fa: String = ""
## clock_tower | monument
@export var kind: String = "clock_tower"
@export var pos: Vector2 = Vector2(13.5, -55.5)
@export var height: float = 14.0
@export var brick: Color = Color(0.72, 0.42, 0.3)
@export var stone: Color = Color(0.88, 0.85, 0.78)
@export var roof: Color = Color(0.2, 0.45, 0.5)
@export var chime: bool = true
