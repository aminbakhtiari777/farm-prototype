class_name DoorPlaqueStyle
extends AssetModule
## v7b.1: homes no longer get a big roof sign ('The X Family'). Instead a small
## brass / wood plaque by the front door shows 'خانواده آقای فلان' (or 'خانم'
## for a woman-led home). Business signs stay. The player's own house is
## highlighted on the minimap. Consumer: DoorPlaques (Building + Minimap).

@export var name_fa: String = ""
@export var enabled: bool = true
@export var hide_home_roof_signs: bool = true
## brass
@export var plaque_color: Color = Color(0.42, 0.32, 0.18)
## m
@export var plaque_w: float = 1.05
## m
@export var plaque_h: float = 0.28
@export var font_size: int = 36
## {surname} / {title}
@export var formula_fa: String = "خانواده آقای {surname}"
## woman-led home
@export var formula_fa_f: String = "خانواده خانم {surname}"
@export var formula_en: String = "The {surname} Family"
## minimap
@export var home_marker_color: Color = Color(0.15, 0.75, 0.35)
@export var home_pulse: bool = true
