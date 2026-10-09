class_name SquareStyle
extends AssetModule
## Town square look (v5a "ornate town square"): centrepiece (tiered fountain or
## the old well), mosaic paving pattern, flower beds, ornamental lamps and a
## statue. Consumers: TownSquare (scripts/world/town/town_square.gd).

@export_enum("fountain", "well") var centerpiece: String = "fountain"
@export var fountain_tiers: int = 3
@export var stone_color: Color = Color(0.86, 0.82, 0.74)
@export var mosaic_a: Color = Color(0.78, 0.7, 0.56)
@export var mosaic_b: Color = Color(0.45, 0.55, 0.62)
@export var mosaic_c: Color = Color(0.7, 0.36, 0.28)
## 0 = plain cobbles, 1 = star rosette, 2 = rings.
@export var pattern: int = 1
@export var flower_colors: Array = [Color(0.9, 0.25, 0.35), Color(0.98, 0.8, 0.2), Color(0.6, 0.35, 0.85)]
@export var ornate_lamps: int = 8
@export var statue: bool = true
@export var hedges: bool = true
