class_name V7b1Visual
extends Node
## v7b.1 visual pass (Amin's 9 items): realistic procedural cars (CarBody via
## VehicleKit.model), resident looks (ResidentLooks via Townspeople.outfit_for),
## door plaques + house variety (Building hooks), the player's home on the
## minimap, street plants (StreetPlants), the square guard (no one lies on
## the square's paving), the City Hall interior with the fund, the fire truck
## siren (FireSiren via FireService). Everything is a swappable module.

var plants: StreetPlants
var city_hall: CityHallInterior
var guard: SquareGuard
var home_marker: HomeMarker
var looks_attached: int = 0
var _t: float = 0.0


func _ready() -> void:
	name = "V7b1Visual"
	plants = StreetPlants.new()
	var scene := get_tree().current_scene
	# Plants live in 3D space: under the scene root (Node3D), not this Node.
	if scene:
		scene.add_child.call_deferred(plants)
	guard = SquareGuard.new()
	add_child(guard)
	_late_setup.call_deferred()
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			DoorPlaques.refresh(get_tree()))
	Modules.on_swap("resident_looks", self, func(_m: Resource) -> void: _relook())


func _late_setup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(plants) and plants.is_inside_tree():
		plants.rebuild()
	var b := CityHallInterior.city_hall(get_tree())
	var fund: CityFund = null
	var v7a: Node = get_tree().current_scene.find_child("V7aWorld", true, false) if get_tree().current_scene else null
	if v7a and "fund" in v7a:
		fund = v7a.get("fund") as CityFund
	if b and CityHallInterior.active():
		city_hall = CityHallInterior.new()
		add_child(city_hall)
		city_hall.setup(b, fund)
	var mm := get_tree().get_first_node_in_group(&"minimap") as Minimap
	if mm and mm.get_node_or_null(^"HomeMarker") == null:
		home_marker = HomeMarker.new()
		home_marker.minimap = mm
		mm.add_child(home_marker)


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	_attach_looks()


## Face features (hijab, moustache, glasses, cap) on every townsperson body.
func _attach_looks() -> void:
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var bot := n as TownspersonBot
		if bot == null or bot.visual == null or bot.has_meta(&"v7b1_looks"):
			continue
		if bot.visual.get("skeleton") == null:
			continue
		bot.set_meta(&"v7b1_looks", true)
		if ResidentLooks.attach_features(bot.visual, bot.outfit):
			looks_attached += 1


func _relook() -> void:
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		if n.has_meta(&"v7b1_looks"):
			n.remove_meta(&"v7b1_looks")
