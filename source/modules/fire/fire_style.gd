class_name FireStyle
extends AssetModule
## v7a fire + emergencies: a fire station with a red fire truck and a crew of
## three. A fire grows on a building, spreads slowly to nearby flammable things
## (houses, trees, wood piles), and damages what it burns. The truck drives out
## with lights, the crew hoses it down. Burned buildings are rebuilt over days by
## the carpenter and the mason. Whoever caused it pays a fine + damages (city
## fund, police report, the ambulance checks the residents). Consumer: FireService.

@export var name_fa: String = ""
@export var station_pos: Vector2 = Vector2(46.5, -39.5)
@export var station_yaw: float = 180.0
@export var truck_base: Vector2 = Vector2(46.5, -46.1)
@export var truck_speed: float = 10.0
@export var crew: int = 3
## until fully ablaze
@export var grow_seconds: float = 25.0
## m
@export var spread_radius: float = 11.0
## a full fire ignites a neighbour after this
@export var spread_seconds: float = 45.0
## hosing time
@export var extinguish_seconds: float = 12.0
## 0..1 per second at full fire
@export var damage_per_second: float = 0.012
@export var rebuild_days: int = 2
## fine for causing a fire
@export var fine: int = 300
## damages at 100% burned
@export var damage_cost: int = 800
@export var truck_color: Color = Color(0.82, 0.08, 0.06)
