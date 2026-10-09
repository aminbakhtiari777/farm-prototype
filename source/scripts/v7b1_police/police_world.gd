class_name V7b1PoliceWorld
extends Node3D
## v7b.1 police / road-safety wiring (police workstream, "road_safety" module):
## every AI vehicle yields to people (RoadCar.people_gate -> RoadSafety), walkers
## wait at the kerb / step aside (TownspersonBot.move_filter), and hits get
## reactions + the ambulance / police / crowd response (AccidentResponse).

var accidents: AccidentResponse


func _ready() -> void:
	name = "V7b1PoliceWorld"
	RoadCar.people_gate = RoadSafety.people_gate
	TownspersonBot.move_filter = RoadSafety.pedestrian_filter
	accidents = AccidentResponse.new()
	accidents.name = "AccidentResponse"
	add_child(accidents)
	Modules.on_swap("road_safety", self, func(_m: Resource) -> void:
		RoadSafety._st_frame = -1)


func _exit_tree() -> void:
	RoadCar.people_gate = Callable()
	TownspersonBot.move_filter = Callable()
