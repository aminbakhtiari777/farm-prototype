class_name TrafficSignStyle
extends AssetModule
## v7b.1 traffic signs on poles: STOP (ایست), give way at the roundabout,
## speed-limit discs matching traffic_rules, no parking, one-way arrows on the
## roundabout, school zone, and Persian / English direction boards at the main
## junctions. Signs read the street names from TownLayout. Consumer: TrafficSigns.

@export var name_fa: String = ""
## English under the Persian text
@export var bilingual: bool = true
@export var pole_h: float = 2.4
## sign diameter (m)
@export var disc: float = 0.62
## m between repeated speed-limit signs
@export var limit_every: float = 45.0
## {pos, yaw}
@export var no_parking: Array = []
## {pos, yaw, lines: [{fa, en, arrow}]} direction boards
@export var directions: Array = []
