class_name RoadSafetyStyle
extends AssetModule
## v7b.1 road safety: AI cars brake and yield for people along their path
## (look-ahead = nose + stop margin + reaction + braking distance, curved along
## the route), pedestrians wait at the kerb for close moving cars, hit
## reactions (stumble / fall + Persian exclamation, get up), and for a hard hit
## an ambulance + police response, a talking crowd and a fine / offence for the
## driver. Non-graphic, nobody dies. Consumers: RoadSafety, AccidentResponse.

@export var name_fa: String = ""
## false = the old v6b 3 m box (not recommended)
@export var enabled: bool = true
## m/s2 planned braking (cars can do 9)
@export var brake_decel: float = 6.0
## s of travel before braking starts
@export var reaction_s: float = 0.35
## m kept between the bumper and a person
@export var stop_margin: float = 1.6
## m added to half the car width for the yield corridor
@export var lane_margin: float = 0.55
## s: people walking towards the path count where they will be
@export var predict_s: float = 1.2
## m from the camera: cars nearer check every frame
@export var near_radius: float = 90.0
## s between checks for cars farther away
@export var far_interval: float = 0.3
## a townsperson blocking a waiting car this long steps aside
@export var step_aside_s: float = 2.5
## townspeople wait at the kerb for close moving cars
@export var pedestrian_wait: bool = true
## m: moving cars this close make walkers wait
@export var pedestrian_look: float = 14.0
## slower contacts are only a bump
@export var hit_min_kmh: float = 3.0
## at / above this the person stays down: ambulance + police + crowd
@export var hard_hit_kmh: float = 25.0
## s on one knee after a light hit
@export var stumble_s: float = 2.2
## s on the ground after a medium hit (>= fall_kmh) before getting up
@export var fall_s: float = 4.0
@export var fall_kmh: float = 14.0
## s the paramedics need on the spot
@export var treat_s: float = 6.0
## fallback: recover after this long even if no ambulance came
@export var down_max_s: float = 90.0
## m: townspeople this close come to look
@export var crowd_radius: float = 35.0
@export var crowd_min: int = 3
@export var crowd_max: int = 6
## m from the person
@export var crowd_ring: float = 2.6
## s between crowd lines
@export var chat_every_s: float = 2.8
## s the crowd stays after the person is back up
@export var crowd_stay_s: float = 8.0
## hard hit (driver)
@export var hit_fine: int = 250
## light hit (0 = warning only)
@export var light_hit_fine: int = 0
## exclaim, hurt, recovered, crowd, police, paramedic, player_hit, driver_sorry -> [{en, fa}]
@export var lines: Dictionary = {}
