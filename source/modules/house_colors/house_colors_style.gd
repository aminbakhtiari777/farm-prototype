class_name HouseColorsStyle
extends AssetModule
## v6b house colours tied to the owner: each family's house is painted in the
## family's colour (stable per surname); the farmhouse follows the player's
## choice. Consumer: Building._apply_layout.

@export var name_fa: String = ""
## wall colours
@export var palette: Array = []
## 0 = layout colour, 1 = family colour
@export var strength: float = 0.85
@export var farmhouse_color: Color = Color(0.88, 0.82, 0.7)
