class_name VehicleKit
extends RefCounted
## v6b shared vehicle helpers: Kenney car models scaled to a real length, and
## the car road graph (paved road centre lines + a ring around the town
## square). Cars drive on the right lane (offset from the centre line).

const LANE := 1.7  # v7b1: wider streets (was 1.35)
const SQUARE_RING := 11.6
static var _astar: AStar3D
static var _next: int = 0
static var _road_of: Dictionary = {}


static func models_dir() -> String:
	var vs := Modules.style("vehicles") as VehicleStyle
	if vs and vs.models_dir != "":
		return vs.models_dir
	var fstyle := Modules.style("furniture") as FurnitureStyle
	return fstyle.cars_dir if fstyle else "res://assets/third_party/kenney/cars/"


static func length_of(model: String) -> float:
	match model:
		"tractor":
			return 3.4
		"ambulance", "delivery", "van", "truck", "garbageTruck", "firetruck":
			return 4.6
	return 4.2


## Instantiates a car model scaled to its length, centred on the origin with
## the wheels on y = 0. Returns [node, size] or [] when the model is missing.
static func model(name: String, length: float = -1.0) -> Array:
	# v7b.1 car_bodies module: self-made procedural bodies (paint, glass, interior).
	if CarBody.handles(name):
		return CarBody.build(name, length)
	var path := models_dir() + name + ".glb"
	if not ResourceLoader.exists(path):
		return []
	var inst := (load(path) as PackedScene).instantiate() as Node3D
	var aabb := AABB()
	var first := true
	for mi in inst.find_children("*", "MeshInstance3D", true, false):
		var a := MeshMerger._relative_xform(mi as MeshInstance3D, inst) * (mi as MeshInstance3D).mesh.get_aabb()
		aabb = a if first else aabb.merge(a)
		first = false
	var want := length if length > 0.0 else length_of(name)
	var k := want / maxf(aabb.size.z, aabb.size.x)
	inst.scale = Vector3.ONE * k
	inst.position = Vector3(-aabb.get_center().x * k, -aabb.position.y * k, -aabb.get_center().z * k)
	var holder := Node3D.new()
	holder.name = "Model"
	holder.add_child(inst)
	return [holder, aabb.size * k]


# ------------------------------------------------------------------ road graph
static func graph() -> AStar3D:
	if _astar == null:
		_build()
	return _astar


static func _add(p: Vector2, road: int) -> int:
	var id := _next
	_next += 1
	_astar.add_point(id, Vector3(p.x, 0.0, p.y))
	_road_of[id] = road
	return id


static func _build() -> void:
	_astar = AStar3D.new()
	_next = 0
	_road_of = {}
	var r := 0
	for road in TownLayout.ROADS:
		if road["kind"] != "paved":
			continue
		var pts: Array = road["points"]
		var prev := -1
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var steps := maxi(int(a.distance_to(b) / 6.0), 1)
			for s in steps + (1 if i == pts.size() - 2 else 0):
				var id := _add(a.lerp(b, float(s) / steps), r)
				if prev >= 0:
					_astar.connect_points(prev, id)
				prev = id
		r += 1
	# Ring around the square (one-way feel is not needed: two lanes).
	var ring: Array[int] = []
	for k in 16:
		var ang := TAU * k / 16.0
		var id := _add(TownLayout.TOWN_CENTER + Vector2(sin(ang), cos(ang)) * SQUARE_RING, 100)
		if not ring.is_empty():
			_astar.connect_points(ring[ring.size() - 1], id)
		ring.append(id)
	_astar.connect_points(ring[0], ring[ring.size() - 1])
	# Junctions: points of different roads that are close.
	var ids := _astar.get_point_ids()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if _road_of[ids[i]] == _road_of[ids[j]]:
				continue
			var pa := _astar.get_point_position(ids[i])
			var pb := _astar.get_point_position(ids[j])
			if pa.distance_to(pb) < 5.5 and not _astar.are_points_connected(ids[i], ids[j]):
				_astar.connect_points(ids[i], ids[j])


static func nearest(p: Vector3) -> Vector3:
	var g := graph()
	var id := g.get_closest_point(Vector3(p.x, 0.0, p.z))
	var q := g.get_point_position(id)
	return Vector3(q.x, Terrain.height_at(q.x, q.z), q.z)


## Centre-line waypoints from `from` to `to` (both snapped to the road graph).
static func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var g := graph()
	var a := g.get_closest_point(Vector3(from.x, 0.0, from.z))
	var b := g.get_closest_point(Vector3(to.x, 0.0, to.z))
	var out := PackedVector3Array()
	for p in g.get_point_path(a, b):
		out.append(Vector3(p.x, 0.0, p.z))
	return out


## Shifts a centre-line route onto the right-hand lane.
static func lane(path: PackedVector3Array, offset: float = LANE) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := path.size()
	for i in n:
		var d := Vector3.ZERO
		if i < n - 1:
			d += (path[i + 1] - path[i]).normalized()
		if i > 0:
			d += (path[i] - path[i - 1]).normalized()
		d.y = 0.0
		if d.length() < 0.01:
			out.append(path[i])
			continue
		d = d.normalized()
		var right := Vector3(-d.z, 0.0, d.x)
		out.append(path[i] + right * offset)
	return out


## Is (x, z) on (or right next to) a paved road or the square?
static func on_road(x: float, z: float, margin: float = 0.5) -> bool:
	var p := Vector2(x, z)
	if p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 3.0:
		return true
	for road in TownLayout.ROADS:
		if road["kind"] != "paved":
			continue
		var pts: Array = road["points"]
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			if q.distance_to(p) <= float(road["half"]) + margin:
				return true
	return false
