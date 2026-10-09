class_name NewCityRoad
extends Node3D
## v7b.1 "road to the new city": New City Rd continues Main St east out of
## town and climbs into the hills past the map edge. It is under construction:
## a striped barrier with flashing lamps closes it at the edge, cones and a
## parked roller stand behind it, and a big board reads
## "به سوی شهر جدید - در دست ساخت" (Towards the New City - under construction).
## Part of the traffic_signs module family (consumer of road_markings paint).

const START := Vector2(72.0, -50.0)
const EDGE_X := 78.6          ## barrier just inside the world bounds (x = 80)
const END_X := 128.0          ## visual road towards the horizon
const HALF := 4.2

var barrier: Node3D
var board: Node3D
var _blink: Array[StandardMaterial3D] = []
var _t: float = 0.0


func _ready() -> void:
	_build.call_deferred()


func _build() -> void:
	for c in get_children():
		c.queue_free()
	_blink.clear()
	VehicleKit.graph()   # make sure the road graph is up (no-op if built)
	V7bKit.clear_trees(get_tree(), Rect2(Vector2(74.0, -57.0), Vector2(END_X - 74.0, 14.0)))
	# Asphalt beyond the town road entry (79.5 .. END_X), following the hills.
	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x := 79.0
	while x < END_X:
		var x1 := minf(x + 1.0, END_X)
		_strip(asphalt, x, x1, -HALF, HALF, 0.09)
		_strip(asphalt, x, x1, -HALF - 1.2, -HALF, 0.05, Color(0.45, 0.42, 0.36))
		_strip(asphalt, x, x1, HALF, HALF + 1.2, 0.05, Color(0.45, 0.42, 0.36))
		if int(x) % 3 == 0:
			_strip(paint, x, minf(x + 1.4, END_X), -0.07, 0.07, 0.11)
		for e: float in [-HALF + 0.3, HALF - 0.3]:
			_strip(paint, x, x1, e - 0.07, e + 0.07, 0.11)
		x = x1
	var road := MeshInstance3D.new()
	road.name = "NewCityAsphalt"
	road.mesh = asphalt.commit()
	road.material_override = _vertex_mat()
	road.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(road)
	var pm := MeshInstance3D.new()
	pm.name = "NewCityPaint"
	pm.mesh = paint.commit()
	pm.material_override = TrafficKit.mat(Color(0.95, 0.94, 0.88), 0.7)
	pm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pm)
	_build_barrier()
	_build_board()
	_build_site()


func _y(x: float, z: float) -> float:
	return Terrain.height_at(x, z)


func _strip(st: SurfaceTool, x0: float, x1: float, z0: float, z1: float, lift: float, col: Color = Color(0.2, 0.2, 0.22)) -> void:
	var v := [Vector3(x0, _y(x0, START.y + z0) + lift, START.y + z0), Vector3(x1, _y(x1, START.y + z0) + lift, START.y + z0),
		Vector3(x1, _y(x1, START.y + z1) + lift, START.y + z1), Vector3(x0, _y(x0, START.y + z1) + lift, START.y + z1)]
	for i: int in [0, 2, 1, 0, 3, 2]:
		st.set_color(col)
		st.set_normal(Vector3.UP)
		st.add_vertex(v[i])


func _vertex_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.92
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _build_barrier() -> void:
	barrier = Node3D.new()
	barrier.name = "Barrier"
	barrier.position = Vector3(EDGE_X, _y(EDGE_X, START.y), START.y)
	add_child(barrier)
	var red := TrafficKit.mat(Color(0.85, 0.1, 0.08), 0.6)
	var white := TrafficKit.mat(Color(0.96, 0.96, 0.94), 0.6)
	# Two A-frame stands + a striped beam across the whole road.
	for z in [-HALF - 0.6, -1.5, 1.5, HALF + 0.6]:
		V7aKit.box(barrier, Vector3(0.12, 1.1, 0.12), Vector3(0, 0.55, z), Color(0.3, 0.3, 0.32))
		V7aKit.box(barrier, Vector3(0.7, 0.08, 0.12), Vector3(0, 0.05, z), Color(0.3, 0.3, 0.32))
	var n := 12
	var w := (HALF * 2.0 + 1.4) / n
	for i in n:
		var z2 := -HALF - 0.7 + w * (i + 0.5)
		V7aKit.box(barrier, Vector3(0.1, 0.32, w), Vector3(0.06, 0.95, z2), red if i % 2 == 0 else white, false)
		V7aKit.box(barrier, Vector3(0.1, 0.24, w), Vector3(0.06, 0.45, z2), white if i % 2 == 0 else red, false)
	# Flashing amber lamps on top.
	for z3 in [-HALF, 0.0, HALF]:
		var m := V7aKit.mat(Color(1.0, 0.6, 0.05), 0.4, 0.0)
		m.emission_enabled = true
		m.emission = Color(1.0, 0.6, 0.05)
		V7aKit.ball(barrier, 0.11, Vector3(0.06, 1.2, z3), m)
		_blink.append(m)
	# Invisible wall so cars stop here (the world bounds are just behind).
	var body := StaticBody3D.new()
	body.name = "BarrierBody"
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.4, 1.4, HALF * 2.0 + 2.8)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	body.add_child(cs)
	barrier.add_child(body)
	var l := TrafficKit.label(barrier, "جاده بسته است - در دست ساخت", "Road closed - under construction", Vector3(-0.08, 0.95, 0), -PI * 0.5, 0.0032, 48, Color(0.05, 0.05, 0.05))
	l.position.y = 1.45
	l.modulate = Color(1, 0.95, 0.75)
	l.outline_size = 8
	l.outline_modulate = Color(0.1, 0.1, 0.1)
	# Cones in front.
	for i in 6:
		var cz := -HALF + 0.6 + i * (HALF * 2.0 - 1.2) / 5.0
		_cone(Vector3(EDGE_X - 1.6 - (i % 2) * 0.8, 0, START.y + cz))


func _cone(p: Vector3) -> void:
	var y := _y(p.x, p.z)
	V7aKit.cyl(self, 0.18, 0.62, Vector3(p.x, y + 0.31 + 0.09, p.z), Color(1.0, 0.45, 0.05), 0.03)
	V7aKit.cyl(self, 0.13, 0.1, Vector3(p.x, y + 0.48, p.z), Color(0.97, 0.97, 0.97), 0.1)
	V7aKit.box(self, Vector3(0.42, 0.04, 0.42), Vector3(p.x, y + 0.11, p.z), Color(0.15, 0.15, 0.15))


func _build_board() -> void:
	# Big board on the north verge before the barrier, facing traffic heading east.
	board = Node3D.new()
	board.name = "NewCityBoard"
	var bp := Vector2(EDGE_X - 4.5, START.y - HALF - 1.9)
	board.position = Vector3(bp.x, _y(bp.x, bp.y), bp.y)
	board.rotation.y = -PI * 0.5 + 0.35   # faces west (towards drivers), slightly angled to the road
	add_child(board)
	for sx in [-1.5, 1.5]:
		V7aKit.cyl(board, 0.07, 3.4, Vector3(sx, 1.7, 0), Color(0.5, 0.52, 0.55))
	V7aKit.box(board, Vector3(3.8, 1.5, 0.06), Vector3(0, 2.7, 0.03), TrafficKit.mat(Color(0.08, 0.36, 0.2), 0.5))
	V7aKit.box(board, Vector3(3.9, 1.6, 0.04), Vector3(0, 2.7, 0.0), TrafficKit.mat(Color(0.96, 0.96, 0.96), 0.5))
	var l := TrafficKit.label(board, "به سوی شهر جدید", "", Vector3(0, 3.05, 0.07), 0.0, 0.0062, 64, Color.WHITE)
	l.remove_from_group(&"v7b_signs")
	var l2 := TrafficKit.label(board, "Towards the New City", "", Vector3(0, 2.62, 0.07), 0.0, 0.0034, 64, Color.WHITE)
	l2.remove_from_group(&"v7b_signs")
	# Under-construction plate.
	V7aKit.box(board, Vector3(3.0, 0.42, 0.05), Vector3(0, 2.15, 0.06), TrafficKit.mat(Color(0.98, 0.78, 0.08), 0.5))
	var l3 := TrafficKit.label(board, "در دست ساخت", "Under construction", Vector3(0, 2.15, 0.1), 0.0, 0.0032, 56, Color(0.08, 0.08, 0.08))
	l3.text = "در دست ساخت  -  Under construction"
	l3.remove_from_group(&"v7b_signs")
	# Speed limit 60 on the new road (traffic_rules).
	var lim := Node3D.new()
	lim.name = "Limit60"
	var lp := Vector2(73.6, START.y + HALF + 1.0)
	lim.position = Vector3(lp.x, _y(lp.x, lp.y), lp.y)
	lim.rotation.y = -PI * 0.5
	add_child(lim)
	V7aKit.cyl(lim, 0.045, 2.4, Vector3(0, 1.2, 0), Color(0.62, 0.64, 0.66))
	var d1 := V7aKit.cyl(lim, 0.31, 0.03, Vector3(0, 2.4, 0.04), TrafficKit.mat(Color(0.85, 0.1, 0.1), 0.5))
	d1.rotation.x = PI * 0.5
	var d2 := V7aKit.cyl(lim, 0.25, 0.03, Vector3(0, 2.4, 0.06), TrafficKit.mat(Color(0.98, 0.98, 0.98), 0.5))
	d2.rotation.x = PI * 0.5
	var kmh := int(TrafficKit.limit_for_road("New City Rd"))
	TrafficKit.label(lim, Lang.digits(str(kmh)), str(kmh), Vector3(0, 2.4, 0.085), 0.0, 0.006, 64, Color(0.05, 0.05, 0.05))


func _build_site() -> void:
	# Beyond the barrier: gravel piles, a road roller and a site hut (visual only).
	var gx := EDGE_X + 9.0
	for i in 3:
		var p := Vector3(gx + i * 4.5, 0, START.y + (2.0 if i % 2 == 0 else -2.0))
		var y := _y(p.x, p.z)
		var pile := V7aKit.cyl(self, 1.4, 1.0, Vector3(p.x, y + 0.45, p.z), Color(0.55, 0.5, 0.44), 0.2)
		pile.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var rp := Vector3(EDGE_X + 6.0, 0, START.y - 1.8)
	var ry := _y(rp.x, rp.z)
	var roller := Node3D.new()
	roller.name = "RoadRoller"
	roller.position = Vector3(rp.x, ry, rp.z)
	add_child(roller)
	var drum := V7aKit.cyl(roller, 0.6, 1.8, Vector3(1.2, 0.6, 0), Color(0.3, 0.3, 0.32))
	drum.rotation.x = PI * 0.5
	V7aKit.box(roller, Vector3(2.0, 1.0, 1.6), Vector3(-0.4, 0.95, 0), Color(0.95, 0.75, 0.1))
	V7aKit.box(roller, Vector3(1.0, 0.9, 1.3), Vector3(-0.6, 1.9, 0), Color(0.25, 0.3, 0.33))
	for z in [-0.75, 0.75]:
		var w := V7aKit.cyl(roller, 0.5, 0.3, Vector3(-0.9, 0.5, z), Color(0.1, 0.1, 0.1))
		w.rotation.x = PI * 0.5
	var hut := Vector3(EDGE_X + 14.0, 0, START.y + HALF + 4.0)
	V7aKit.box(self, Vector3(4.0, 2.4, 2.4), Vector3(hut.x, _y(hut.x, hut.z) + 1.2, hut.z), Color(0.9, 0.9, 0.88))
	V7aKit.box(self, Vector3(4.2, 0.12, 2.6), Vector3(hut.x, _y(hut.x, hut.z) + 2.45, hut.z), Color(0.3, 0.42, 0.6))


func _process(delta: float) -> void:
	_t += delta
	var on := fmod(_t, 1.0) < 0.5
	for m in _blink:
		m.emission_energy_multiplier = 3.0 if on else 0.2
