class_name TrafficRulesStyle
extends AssetModule
## v7b.1 traffic rules: signalised intersections with real cycles (green, yellow,
## all-red; actuated: a driver who waits ~5 s at red gets green soon after), STOP
## signs (full stop for stop_hold_s), speed limits per street (signs show the same
## numbers, the dashboard shows the current limit), red-light / speed cameras and a
## traffic officer. Offences: camera flash + fine (city fund) + police report +
## newspaper item; at `offences_to_confiscate` the licence is confiscated and the
## car is towed to the impound lot. Applies to the farmer and to a possessed
## townsperson; NPC cars obey. Consumers: TrafficSignals, TrafficRules, NpcTraffic,
## BusLine, RoadCar.traffic_gate, CarSystems dashboard.

@export var name_fa: String = ""
## street name -> km/h
@export var speed_limits: Dictionary = {}
## roundabout around the town square
@export var square_limit_kmh: float = 25.0
## anywhere else in town
@export var default_limit_kmh: float = 40.0
## x, z, radius (m) of the school zone
@export var school_zone: Vector3 = Vector3(42.0, -90.0, 22.0)
@export var school_limit_kmh: float = 25.0
## camera tolerance
@export var speed_tolerance_kmh: float = 5.0
## over the limit this long near a camera / officer = caught
@export var speeding_seconds: float = 1.5
## m around a camera or the officer
@export var enforcement_range: float = 30.0
## {id, pos, en, fa, camera, officer} signalised intersections
@export var signals: Array = []
## {id, pos, approaches ['n','s','e','w'], en, fa} STOP-sign junctions
@export var stops: Array = []
## {pos, yaw} extra speed cameras (poles)
@export var speed_cameras: Array = []
@export var green_s: float = 10.0
@export var yellow_s: float = 3.0
@export var all_red_s: float = 2.0
## a car waiting at red gets green after about this long (actuated)
@export var min_red_wait_s: float = 5.0
## full stop needed at a STOP sign
@export var stop_hold_s: float = 5.0
@export var red_light_fine: int = 150
@export var stop_sign_fine: int = 60
## 0 = use the v7a city fund speeding fine
@export var speeding_fine: int = 50
## driving without a licence (once per day)
@export var unlicensed_fine: int = 100
## 2nd offence: licence confiscated + car impounded
@export var offences_to_confiscate: int = 2
## whistle, wave, caught, ok -> [{en, fa}]
@export var officer_lines: Dictionary = {}
