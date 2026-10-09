class_name TownNav
extends RefCounted
## Walking graph for townspeople built from TownLayout: points along every
## road / path (on the sidewalk side of paved roads), joined at junctions,
## plus each building's door (outside + inside) and named spots (benches,
## square, beach, pier, pond, lookout). A* (AStar3D) finds routes.

static var _astar: AStar3D
static var _spots: Dictionary = {}  ## name -> point id
static var _next_id: int = 0


static func graph() -> AStar3D:
	if _astar == null:
		_build()
	return _astar


static func _add(p: Vector2) -> int:
	var id := _next_id
	_next_id += 1
	_astar.add_point(id, Vector3(p.x, 0.0, p.y))
	return id


static func _nearest(p: Vector2, max_dist: float = INF) -> int:
	var id := _astar.get_closest_point(Vector3(p.x, 0.0, p.y))
	if id < 0:
		return -1
	var q := _astar.get_point_position(id)
	return id if Vector2(q.x, q.z).distance_to(p) <= max_dist else -1


static func _build() -> void:
	_astar = AStar3D.new()
	_next_id = 0
	var road_ids: Array = []
	for road in TownLayout.ROADS:
		var pts: Array = road["points"]
		var paved: bool = road["kind"] == "paved"
		var offset := float(road["half"]) + 0.9 if paved else 0.0
		var ids: Array[int] = []
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / length
			var nrm := Vector2(-dir.y, dir.x)
			var steps := maxi(int(length / 5.0), 1)
			for s in steps + (1 if i == pts.size() - 2 else 0):
				var c := a + dir * (length * s / steps)
				var id := _add(c + nrm * offset)
				if not ids.is_empty():
					_astar.connect_points(ids[ids.size() - 1], id)
				ids.append(id)
		road_ids.append(ids)
	# Junctions: connect points of different roads that are close.
	var all := _astar.get_point_ids()
	for i in all.size():
		for j in range(i + 1, all.size()):
			var pa := _astar.get_point_position(all[i])
			var pb := _astar.get_point_position(all[j])
			if pa.distance_to(pb) < 8.5 and not _astar.are_points_connected(all[i], all[j]):
				_astar.connect_points(all[i], all[j])
	# Farmyard hub: the three farm gates (north / east / west) meet inside
	# the fence, so the farm paths join one network.
	var hub := _add(Vector2(1.0, 0.5))
	for gate: Vector2 in [Vector2(-14.5, 0.5), Vector2(14.5, 2.0), Vector2(0.0, -13.5), Vector2(-1.6, 3.5)]:
		var gid := _nearest_except(gate, [hub], 3.0)
		if gid >= 0:
			var mid := _add((gate + Vector2(1.0, 0.5)) * 0.5)
			_astar.connect_points(gid, mid)
			_astar.connect_points(mid, hub)
	# Town square ring.
	var ring: Array[int] = []
	for k in 12:
		var a := TAU * k / 12.0
		var id := _add(TownLayout.TOWN_CENTER + Vector2(sin(a), cos(a)) * 7.5)
		if not ring.is_empty():
			_astar.connect_points(ring[ring.size() - 1], id)
		ring.append(id)
		var near := _nearest_except(TownLayout.TOWN_CENTER + Vector2(sin(a), cos(a)) * 13.0, ring, 7.0)
		if near >= 0:
			_astar.connect_points(id, near)
	_astar.connect_points(ring[0], ring[ring.size() - 1])
	_spots["square"] = ring[0]
	_spots["fountain"] = ring[3]
	# Buildings: outside door -> inside.
	for b in TownLayout.BUILDINGS:
		var door := TownLayout.door_point(b, 1.6)
		var outside := _add(Vector2(door.x, door.z))
		var link := _nearest_except(Vector2(door.x, door.z), [outside], 18.0)
		if link >= 0:
			_astar.connect_points(outside, link)
		var inside_p := TownLayout.door_point(b, -float((b["size"] as Vector3).z) * 0.5 - 0.3)
		var inside := _add(Vector2(inside_p.x, inside_p.z))
		_astar.connect_points(outside, inside)
		_spots["door:" + str(b["id"])] = outside
		_spots["in:" + str(b["id"])] = inside
	# Leisure spots.
	var extra := {
		"pier": BeachBuilder.PIER_START + BeachBuilder.PIER_DIR * (BeachBuilder.PIER_LENGTH - 2.0),
		"pier_start": BeachBuilder.PIER_START - BeachBuilder.PIER_DIR * 2.6,
		"beach": Vector2(46.0, 9.0), "beach2": Vector2(56.0, -2.0),
		"pond": Vector2(-27.0, 13.0), "lookout": Vector2(52.0, -112.0), "farm_gate": Vector2(0.0, -16.0),
		# v5a: central market plaza on Farm Rd.
		"market": TownLayout.MARKET_CENTER + Vector2(-2.6, 0.0),
		# v6a: sunbathing beach (sunbathing module).
		"sun_beach": Vector2(60.0, -12.0),
	}
	for spot_name: String in extra:
		var p: Vector2 = extra[spot_name]
		var id := _add(p)
		var link := _nearest_except(p, [id], 30.0)
		if link >= 0:
			_astar.connect_points(id, link)
		_spots[spot_name] = id
	_astar.connect_points(_spots["pier"], _spots["pier_start"])
	_astar.connect_points(_spots["beach"], _spots["pier_start"])
	_astar.connect_points(_spots["beach"], _spots["beach2"])
	_astar.connect_points(_spots["sun_beach"], _spots["beach2"])


static func _nearest_except(p: Vector2, skip: Array, max_dist: float) -> int:
	var best := -1
	var best_d := max_dist
	for id in _astar.get_point_ids():
		if id in skip:
			continue
		var q := _astar.get_point_position(id)
		var d := Vector2(q.x, q.z).distance_to(p)
		if d < best_d:
			best_d = d
			best = id
	return best


static func spot_position(spot: String) -> Vector3:
	graph()
	if not _spots.has(spot):
		return Vector3.INF
	var p := _astar.get_point_position(_spots[spot])
	return Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)


## Public outdoor spots (no "in:" / "door:" spots) - used for random detours.
static func public_spots() -> Array[String]:
	graph()
	var out: Array[String] = []
	for k: String in _spots:
		if not k.begins_with("in:") and not k.begins_with("door:"):
			out.append(k)
	out.sort()
	return out


static func has_spot(spot: String) -> bool:
	graph()
	return _spots.has(spot)


## World-space waypoints from `from` to the named spot.
static func route(from: Vector3, spot: String) -> PackedVector3Array:
	graph()
	var out := PackedVector3Array()
	if not _spots.has(spot):
		return out
	var start := _astar.get_closest_point(Vector3(from.x, 0.0, from.z))
	var path := _astar.get_point_path(start, _spots[spot])
	for p in path:
		out.append(Vector3(p.x, Terrain.height_at(p.x, p.z), p.z))
	return out


static func edge_count() -> int:
	graph()
	var n := 0
	for id in _astar.get_point_ids():
		n += _astar.get_point_connections(id).size()
	@warning_ignore("integer_division")
	return n / 2
