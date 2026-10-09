class_name Boats
extends Node3D
## v6a "boats" module: fishing boats moored at the pier. E on the pier next to
## a boat: pay the fuel and sail out to a deep-sea spot (deep_sea module) where
## rarer, pricier fish bite. E at the helm sails back. Storms keep boats in.

const PIER_START := BeachBuilder.PIER_START
const PIER_DIR := BeachBuilder.PIER_DIR

var boats: Array[FishingBoat] = []


func _ready() -> void:
	add_to_group(&"boats")
	Modules.on_swap("boats", self, func(_m: AssetModule) -> void: rebuild())
	rebuild()


func style() -> BoatStyle:
	return Modules.style("boats") as BoatStyle


func pier_deck() -> float:
	var b := get_tree().get_first_node_in_group(&"beach") if is_inside_tree() else null
	if b and b.get("pier_deck_height") != null:
		return float(b.get("pier_deck_height"))
	var g := Terrain.height_at(PIER_START.x, PIER_START.y)
	return maxf(g + 0.35, TownLayout.WATER_LEVEL + 0.9)


## Mooring slots: [pier side (+1 right / -1 left), distance along the pier].
static func moorings() -> Array:
	return [[1.0, 9.2], [-1.0, 9.2], [1.0, 14.8], [-1.0, 14.8]]


func rebuild() -> void:
	for b in boats:
		if is_instance_valid(b):
			b.queue_free()
	boats.clear()
	var st := style()
	if st == null:
		return
	var right := Vector2(PIER_DIR.y, -PIER_DIR.x)
	var slots := moorings()
	for i in mini(st.count, slots.size()):
		var side := float(slots[i][0])
		var along := float(slots[i][1])
		var c := PIER_START + PIER_DIR * along + right * side * (BeachBuilder.PIER_WIDTH * 0.5 + 1.55)
		var boat := FishingBoat.new()
		boat.name = "Boat%d" % i
		boat.index = i
		boat.owner_boats = self
		boat.hull_color = st.hull_colors[i % st.hull_colors.size()] if not st.hull_colors.is_empty() else Color.WHITE
		boat.has_cabin = st.cabin
		boat.mooring = Vector3(c.x, TownLayout.WATER_LEVEL + 0.15, c.y)
		boat.mooring_yaw = atan2(PIER_DIR.x, PIER_DIR.y)
		var sp: Vector2 = st.spots[i % st.spots.size()] if not st.spots.is_empty() else Vector2(84, 36)
		boat.sea_spot = Vector3(sp.x, TownLayout.WATER_LEVEL + 0.15, sp.y)
		var board := PIER_START + PIER_DIR * along + right * side * (BeachBuilder.PIER_WIDTH * 0.5 - 0.45)
		boat.board_point = Vector3(board.x, pier_deck(), board.y)
		add_child(boat)
		boats.append(boat)


func boat_with_player() -> FishingBoat:
	for b in boats:
		if is_instance_valid(b) and b.passenger != null:
			return b
	return null


func _physics_process(_delta: float) -> void:
	# Safety: fell overboard -> back on the nearest boat deck or the pier.
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p == null:
		return
	if p.global_position.y < TownLayout.WATER_LEVEL - 0.6 and TownLayout.sea_distance(p.global_position.x, p.global_position.z) > 6.0:
		var b := boat_with_player()
		if b:
			p.global_position = b.to_global(Vector3(0, 0.6, -1.0))
		else:
			p.global_position = Vector3(PIER_START.x, pier_deck() + 0.3, PIER_START.y) + Vector3(PIER_DIR.x, 0, PIER_DIR.y) * 4.0
		if p is CharacterBody3D:
			(p as CharacterBody3D).velocity = Vector3.ZERO
		GameEvents.notification_requested.emit(Lang.tt("شلپ! از آب بیرونت کشیدند.", "Splash! Someone pulled you out of the water."))
