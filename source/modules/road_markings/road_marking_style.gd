class_name RoadMarkingStyle
extends AssetModule
## v7b.1 road markings painted over the (wider) asphalt: stop lines at signals and
## STOP signs, solid centre lines near junctions, lane edge lines, parking bays on
## Main St, turn arrows before the signals, 'SCHOOL' / 'مدرسه' text by the school
## and give-way triangles at the roundabout. (Dashed centre lines and zebra
## crossings come from TownBuilder.) One merged mesh. Consumer: RoadMarkings.

@export var name_fa: String = ""
## white paint
@export var paint: Color = Color(0.95, 0.94, 0.88)
## solid centre lines near junctions
@export var center_paint: Color = Color(0.96, 0.78, 0.18)
@export var stop_line_w: float = 0.45
@export var line_w: float = 0.14
## edge line inset from the kerb
@export var edge_offset: float = 0.35
@export var edge_lines: bool = true
## Main St parking strip
@export var parking_bays: bool = true
@export var bay_length: float = 6.0
@export var arrows: bool = true
## {en, fa, pos, yaw}
@export var school_text: Dictionary = {}
## m of solid centre line before a signal / stop
@export var solid_near_junction: float = 14.0
