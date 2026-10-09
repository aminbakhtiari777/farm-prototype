class_name StreetLighting
extends Node3D
## v7b.1 street_lighting module: a brighter town at night.
##  - extra lamps every `spacing` m on BOTH sides of every paved street (skips
##    spots near the existing TownBuilder lamps, doors, buildings, junctions),
##    tall lamps at the junction corners, a ring round the square, lamps along
##    paths / the market / park (`extra_points`) and a sconce by every shop door;
##  - all lamps are 3 MultiMeshes (pole / arm / lantern) - one draw call each;
##  - warm additive light pools on the ground (one merged mesh);
##  - only `pool_lights` real OmniLights follow the camera (web friendly);
##  - a gentle warm night-ambient floor (applied after DayNightCycle).

var lamp_points: PackedVector3Array = PackedVector3Array()   ## lantern positions
var _lights: Array[OmniLight3D] = []
var _pool_mesh: MeshInstance3D
var _pool_mat: StandardMaterial3D
var _timer: float = 0.0
var _env: Environment
var amount: float = 0.0
var _existing: PackedVector3Array = PackedVector3Array()


func style() -> StreetLightingStyle:
	return Modules.style("street_lighting") as StreetLightingStyle


func _ready() -> void:
	process_priority = 20   # after DayNightCycle / NightLights
	rebuild.call_deferred()
	Modules.on_swap("street_lighting", self, func(_m: Resource) -> void: rebuild())


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_lights.clear()
	lamp_points = PackedVector3Array()
	var st := style()
	if st == null:
		return
	var existing := PackedVector3Array()
	var town := get_tree().current_scene.get_node_or_null("Town") if get_tree().current_scene else null
	if town and "lamp_positions" in town:
		existing = town.get("lamp_positions")
	_existing = existing
	var spots: Array = []   # [Vector3 base, yaw, height]
	# Along every paved street, both sides.
	for r: Dictionary in TrafficKit.paved():
		var half := float(r["half"])
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			var d := (b - a) / length
			var n := Vector2(-d.y, d.x)
			for side: float in [-1.0, 1.0]:
				var t := 3.0 + (st.spacing * 0.5 if side > 0.0 else 0.0)
				while t < length - 1.0:
					var p := a + d * t + n * side * (half + TownBuilder.SIDEWALK_W - 0.3)
					if _free(p, r, existing, spots, 3.5):
						spots.append([p, atan2(-n.x * side, -n.y * side), 4.2])
					t += st.spacing
	# Junction corners (tall).
	if st.intersection_lamps:
		var rules := TrafficKit.rules()
		var js: Array = []
		if rules:
			for s: Dictionary in rules.signals:
				js.append(s["pos"])
			for s: Dictionary in rules.stops:
				js.append(s["pos"])
		for c: Vector2 in js:
			for diag: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
				var p2 := c + diag * 6.6
				if _free(p2, {}, existing, spots, 2.5):
					spots.append([p2, atan2(diag.x, diag.y), 5.2])
	# Ring round the square.
	for k in 10:
		var ang := TAU * k / 10.0 + 0.3
		var p3 := TownLayout.TOWN_CENTER + Vector2(sin(ang), cos(ang)) * (VehicleKit.SQUARE_RING + 4.4)
		if _free(p3, {}, existing, spots, 2.5, false):
			spots.append([p3, ang + PI, 4.2])
	for p4: Vector2 in st.extra_points:
		if _free(p4, {}, existing, spots, 1.5, false):
			spots.append([p4, 0.0, 3.4])
	_build_lamps(spots)
	if st.shop_sconces:
		_build_sconces()
	if st.ground_pools:
		_build_pools()
	for i in st.pool_lights:
		var l := OmniLight3D.new()
		l.name = "StreetPool%d" % i
		l.light_color = st.light_color
		l.omni_range = st.light_range
		l.omni_attenuation = 1.1
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_lights.append(l)
	_timer = 0.0


func _free(p: Vector2, road: Dictionary, existing: PackedVector3Array, spots: Array, min_d: float, check_roads: bool = true) -> bool:
	if p.x < TownLayout.PLAY_AREA.position.x + 1.0 or p.x > TownLayout.PLAY_AREA.end.x - 1.0:
		return false
	for e: Vector3 in existing:
		if Vector2(e.x, e.z).distance_to(p) < min_d:
			return false
	for s: Array in spots:
		if (s[0] as Vector2).distance_to(p) < min_d:
			return false
	for b in TownLayout.BUILDINGS:
		if (b["pos"] as Vector2).distance_to(p) < 14.0 and TownLayout.footprint_distance(b, p, 0.6) < 0.0:
			return false
		var dp := TownLayout.door_point(b, 2.0)
		if Vector2(dp.x, dp.z).distance_to(p) < 2.2:
			return false
	for r: Dictionary in TrafficKit.paved():
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var dd := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p)
			if dd < float(r["half"]) + 0.3:
				return false
			if check_roads and not road.is_empty() and r["name"] != road["name"] and dd < float(r["half"]) + TownBuilder.SIDEWALK_W + 2.6:
				return false
	if TrafficKit.in_square(p) and check_roads:
		return false
	return true


func _build_lamps(spots: Array) -> void:
	var pole_mm := _mm(_cyl_mesh(0.05, 1.0), TrafficKit.mat(Color(0.13, 0.13, 0.14), 0.5), spots.size())
	var arm_mm := _mm(_box_mesh(Vector3(0.05, 0.05, 0.7)), TrafficKit.mat(Color(0.13, 0.13, 0.14), 0.5), spots.size())
	var lan_mm := _mm(_box_mesh(Vector3(0.34, 0.16, 0.26)), StreetLamp.lantern_material(), spots.size())
	pole_mm.name = "LampPoles"
	arm_mm.name = "LampArms"
	lan_mm.name = "LampLanterns"
	for i in spots.size():
		var p: Vector2 = spots[i][0]
		var yaw: float = spots[i][1]
		var h: float = spots[i][2]
		var g := TrafficKit.ground(p)
		var basis := Basis(Vector3.UP, yaw)
		var f := basis.z
		pole_mm.multimesh.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(1, h, 1)), g + Vector3(0, h * 0.5, 0)))
		arm_mm.multimesh.set_instance_transform(i, Transform3D(basis, g + Vector3(0, h - 0.05, 0) + f * 0.32))
		var lp := g + Vector3(0, h - 0.18, 0) + f * 0.62
		lan_mm.multimesh.set_instance_transform(i, Transform3D(basis, lp))
		lamp_points.append(lp + Vector3(0, -0.15, 0))


func _build_sconces() -> void:
	var kinds := ["store", "cafe", "city_hall", "hospital", "police", "supermarket", "workshop", "workplace", "civic", "mosque", "church"]
	var pts: Array = []
	for b in TownLayout.BUILDINGS:
		if not str(b.get("kind", "")) in kinds or str(b.get("id", "")) in ["post"]:
			continue
		var yaw := deg_to_rad(float(b["yaw"]))
		var size: Vector3 = b["size"]
		var fwd := Vector3(sin(yaw), 0, cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var pos: Vector2 = b["pos"]
		var front := Vector3(pos.x, 0, pos.y) + fwd * (size.z * 0.5 + 0.08)
		for sx: float in [-1.0, 1.0]:
			var q := front + right * sx * 1.25
			pts.append([Vector3(q.x, Terrain.height_at(q.x, q.z) + 2.35, q.z), yaw])
	var mm := _mm(_box_mesh(Vector3(0.16, 0.24, 0.12)), StreetLamp.lantern_material(), pts.size())
	mm.name = "ShopSconces"
	for i in pts.size():
		mm.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, pts[i][1]), pts[i][0]))
		lamp_points.append(pts[i][0])


func _build_pools() -> void:
	var st := style()
	var s := SurfaceTool.new()
	s.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := st.pool_radius
	var all := lamp_points.duplicate()
	all.append_array(_existing)
	for lp: Vector3 in all:
		var c := Vector2(lp.x, lp.z)
		var y := Terrain.height_at(c.x, c.y)
		# Raise to the road / sidewalk top so the pool is not hidden.
		var lift := 0.16
		var corners := [Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		var v: Array[Vector3] = []
		for k in 4:
			var q: Vector2 = c + corners[k]
			v.append(Vector3(q.x, maxf(Terrain.height_at(q.x, q.y), y) + lift, q.y))
		for idx: int in [0, 2, 1, 0, 3, 2]:
			s.set_uv(uv[idx])
			s.set_normal(Vector3.UP)
			s.add_vertex(v[idx])
	_pool_mat = StandardMaterial3D.new()
	_pool_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pool_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pool_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pool_mat.albedo_texture = V7aKit.soft_texture()
	_pool_mat.albedo_color = Color(st.light_color.r, st.light_color.g, st.light_color.b, 0.0)
	_pool_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_pool_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_pool_mesh = MeshInstance3D.new()
	_pool_mesh.name = "LightPools"
	_pool_mesh.mesh = s.commit()
	_pool_mesh.material_override = _pool_mat
	_pool_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pool_mesh.visible = false
	add_child(_pool_mesh)


func _mm(mesh: Mesh, m: Material, count: int) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = count
	mmi.multimesh = mm
	mmi.material_override = m
	add_child(mmi)
	return mmi


func _cyl_mesh(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 1.3
	c.height = h
	c.radial_segments = 6
	c.rings = 1
	return c


func _box_mesh(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b


func _night() -> float:
	var nl := get_tree().get_first_node_in_group(&"night_lights_controller")
	var a := float(nl.get(&"amount")) if nl else 0.0
	return a if PowerGrid.power_on else 0.0


func _process(delta: float) -> void:
	var st := style()
	if st == null:
		return
	amount = _night()
	if _pool_mat:
		_pool_mat.albedo_color.a = st.pool_alpha * amount
		_pool_mesh.visible = amount > 0.02
	# Night ambient floor (DayNightCycle wrote this frame's value already).
	if _env == null:
		var dn := get_tree().get_first_node_in_group(&"day_night")
		var we: WorldEnvironment = dn.get(&"world_environment") if dn else null
		_env = we.environment if we else null
	if _env and amount > 0.0:
		_env.ambient_light_energy = maxf(_env.ambient_light_energy, st.night_ambient * amount)
		_env.ambient_light_color = _env.ambient_light_color.lerp(st.ambient_tint, 0.6 * amount)
	_timer -= delta
	for l in _lights:
		l.light_energy = 2.2 * st.light_energy * amount
		l.visible = amount > 0.02 and l.has_meta(&"used")
	if _timer > 0.0:
		return
	_timer = 0.4
	var cam := get_viewport().get_camera_3d()
	if cam == null or lamp_points.is_empty():
		return
	var origin := cam.global_position
	var order: Array = []
	for i in lamp_points.size():
		var dd := lamp_points[i].distance_squared_to(origin)
		if dd < 3600.0:
			order.append([dd, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in _lights.size():
		if k < order.size():
			_lights[k].global_position = lamp_points[order[k][1]]
			_lights[k].set_meta(&"used", true)
		else:
			_lights[k].remove_meta(&"used")
