class_name MinimapStyle
extends AssetModule
## Colours / size of the HUD minimap (scripts/ui/minimap.gd), live swap.

@export var background: Color = Color(0.86, 0.8, 0.64, 0.92)
@export var grass: Color = Color(0.55, 0.66, 0.38)
@export var road: Color = Color(0.42, 0.4, 0.38)
@export var dirt: Color = Color(0.68, 0.56, 0.4)
@export var water: Color = Color(0.35, 0.58, 0.78)
@export var building: Color = Color(0.62, 0.36, 0.26)
@export var forest: Color = Color(0.25, 0.42, 0.22)
@export var player: Color = Color(0.9, 0.15, 0.1)
@export var npc: Color = Color(0.15, 0.3, 0.8)
## Widget size in pixels and how many metres it shows across.
@export var size: int = 220
@export var metres: float = 90.0
