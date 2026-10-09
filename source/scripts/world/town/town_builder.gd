class_name TownBuilder
extends Node3D
## Builds the whole town at runtime from TownLayout: the 16 buildings, paved
## roads (asphalt, raised sidewalks with curbs, dashed centre lines, zebra
## crossings), the cobbled square with its well and market stalls, and the
## street furniture: lamps, benches (sittable), trash bins, mailboxes,
## planters, hedges, picket fences, parked cars, the farm cart and the
## street-name signposts.
##
## Everything static is merged per 48 m chunk into a handful of meshes
## (MeshMerger) with visibility ranges, so the whole town costs roughly
## one draw call per material per chunk. Street lights use a small pool of
## OmniLight3Ds that follow the lamps closest to the camera.

const CHUNK := 48.0
const SIDEWALK_W := 1.8
const CURB_H := 0.11
const LAMP_SPACING := 17.0
const PROP_VISIBILITY := 120.0

## v4 yards module: number of fence runs built around front yards (tests).
var yard_runs: int = 0
var lamp_positions: PackedVector3Array = PackedVector3Array()
var buildings: Dictionary = {}  ## id -> Building
var _chunks: Dictionary = {}  ## Vector2i -> Node3D (static meshes to merge)
var _body: StaticBody3D
var _mat_cache: Dictionary = {}
var _pending_props: Array = []
var _merge_generation: int = 0


func _ready() -> void:
	_body = StaticBody3D.new()
	_body.name = "StreetCollision"
	add_child(_body)
	_build_buildings()
	_build_roads()
	_build_square()
	_build_walkways_and_yards()
	_build_yards()
	Modules.on_swap("yards", self, func(_m: Resource) -> void:
		_build_yards()
		yard_rebuilds += 1)
	_build_street_lamps()
	_build_street_furniture()
	_build_parked_vehicles()
	_build_street_signs()
	_merge_chunks()
	var pool := LampLightPool.new()
	pool.name = "LampLights"
	pool.lamp_positions = lamp_positions
	add_child(pool)


# ------------------------------------------------------------------ helpers
func _mat(key: String, color: Color, rough: float = 0.85, detail: bool = true) -> StandardMaterial3D:
	if not _mat_cache.has(key):
		_mat_cache[key] = ProceduralProp.color_material(color, rough, detail)
	return _mat_cache[key]


func _chunk_for(p: Vector3) -> Node3D:
	if _yard_holder:
		return _yard_holder
	var key := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if not _chunks.has(key):
		var n := Node3D.new()
		n.name = "Chunk_%d_%d" % [key.x, key.y]
		add_child(n)
		_chunks[key] = n
	return _chunks[key]


static func ground(x: float, z: float) -> float:
	return Terrain.height_at(x, z)


func _box(size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0, collide: bool = false, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = Vector3(rot.x, yaw + rot.y, rot.z)
	_chunk_for(pos).add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		cs.position = pos
		cs.rotation = mi.rotation
		(_yard_body if _yard_holder else _body).add_child(cs)
	return mi


func _collider(size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = yaw
	(_yard_body if _yard_holder else _body).add_child(cs)


func _cyl(top: float, bottom: float, height: float, pos: Vector3, mat: Material, segments: int = 10, collide: bool = false, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = segments
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	_chunk_for(pos).add_child(mi)
	if collide:
		var cs := CollisionShape3D.new()
		var c := CylinderShape3D.new()
		c.radius = maxf(top, bottom)
		c.height = height
		cs.shape = c
		cs.position = pos
		_body.add_child(cs)
	return mi


func _sphere(radius: float, pos: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 10
	m.rings = 5
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.scale = scale_v
	_chunk_for(pos).add_child(mi)
	return mi


## Unit vectors for a yaw: forward (+Z rotated) and right (+X rotated).
static func fwd_of(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


static func right_of(yaw: float) -> Vector3:
	return Vector3(cos(yaw), 0, -sin(yaw))


# ------------------------------------------------------------------ buildings
func _build_buildings() -> void:
	var holder := Node3D.new()
	holder.name = "Buildings"
	add_child(holder)
	for b in TownLayout.BUILDINGS:
		var bld := Building.new()
		bld.name = "Building_" + str(b["id"])
		bld.layout_id = b["id"]
		bld.random_seed = hash(b["id"]) % 1000
		holder.add_child(bld)
		buildings[b["id"]] = bld


# ------------------------------------------------------------------ roads
func _paved_roads() -> Array:
	var out: Array = []
	for r in TownLayout.ROADS:
		if r["kind"] == "paved":
			out.append(r)
	return out


## Distance from p to a road's centreline polyline.
static func road_distance(road: Dictionary, p: Vector2) -> float:
	var pts: Array = road["points"]
	var best := INF
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## True if p is on the asphalt of a paved road other than `skip`, or on the square.
func _on_other_asphalt(p: Vector2, skip: Dictionary, margin: float = 0.15) -> bool:
	if p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 0.3:
		return true
	for r in _paved_roads():
		if r == skip:
			continue
		if road_distance(r, p) < float(r["half"]) + margin:
			return true
	return false


func _in_building(p: Vector2, margin: float = 0.2) -> bool:
	for b in TownLayout.BUILDINGS:
		if (b["pos"] as Vector2).distance_to(p) < 12.0 and TownLayout.footprint_distance(b, p, margin) < 0.0:
			return true
	return false


func _build_roads() -> void:
	var asphalt := SurfaceTool.new()
	asphalt.begin(Mesh.PRIMITIVE_TRIANGLES)
	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	var curb := SurfaceTool.new()
	curb.begin(Mesh.PRIMITIVE_TRIANGLES)
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ri := 0
	for road in _paved_roads():
		ri += 1
		var half: float = road["half"]
		var pts: Array = road["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / length
			var nrm := Vector2(-dir.y, dir.x)
			var steps := maxi(int(ceil(length / 1.0)), 1)
			for s in steps:
				var t0 := float(s) / steps * length
				var t1 := float(s + 1) / steps * length
				var c0 := a + dir * t0
				var c1 := a + dir * t1
				# Asphalt strip (tiny per-road lift avoids z-fighting at crossings).
				var lift := 0.035 + ri * 0.002
				_quad_strip(asphalt, c0, c1, nrm, -half, half, lift, lift, 4)
				# Dashed centre line.
				var mid := (c0 + c1) * 0.5
				if s % 3 == 0 and not _on_other_asphalt(mid, road, 2.0):
					_quad_strip(paint, c0, c0 + dir * 1.4, nrm, -0.07, 0.07, lift + 0.01, lift + 0.01, 1)
				# Sidewalks + curbs on both sides.
				for side: float in [-1.0, 1.0]:
					var p_in := mid + nrm * side * (half + 0.2)
					var p_out := mid + nrm * side * (half + SIDEWALK_W)
					if _on_other_asphalt(p_in, road) or _on_other_asphalt(p_out, road) or _in_building(p_out):
						continue
					var inner := side * half
					var outer := side * (half + SIDEWALK_W)
					_quad_strip(walk, c0, c1, nrm, minf(inner, outer), maxf(inner, outer), CURB_H, CURB_H, 2)
					_curb_face(curb, c0, c1, nrm, inner, lift, CURB_H, side)
	# Zebra crossings.
	for cw in _crosswalks():
		var p: Vector2 = cw[0]
		var d: Vector2 = cw[1]
		var h: float = cw[2]
		var n := Vector2(-d.y, d.x)
		var k := -h + 0.35
		while k < h - 0.3:
			var c := p + n * k
			_quad_strip(paint, c - d * 1.2, c + d * 1.2, n, -0.22, 0.22, 0.06, 0.06, 1)
			k += 0.8
	_add_road_mesh(asphalt, "Asphalt", _road_material(Color(0.2, 0.2, 0.22), 0.92))
	_add_road_mesh(walk, "Sidewalks", _road_material(Color(0.66, 0.64, 0.6), 0.9, true))
	_add_road_mesh(curb, "Curbs", _mat("curb", Color(0.74, 0.73, 0.7), 0.85))
	_add_road_mesh(paint, "RoadPaint", _mat("paint", Color(0.95, 0.94, 0.88), 0.7, false))


## Ribbon between lateral offsets o0..o1 along c0->c1, following the terrain.
func _quad_strip(st: SurfaceTool, c0: Vector2, c1: Vector2, nrm: Vector2, o0: float, o1: float, lift0: float, lift1: float, cols: int) -> void:
	for j in cols:
		var la := lerpf(o0, o1, float(j) / cols)
		var lb := lerpf(o0, o1, float(j + 1) / cols)
		var q: Array[Vector3] = []
		for pair: Array in [[c0, la], [c1, la], [c1, lb], [c0, lb]]:
			var c: Vector2 = pair[0]
			var l: float = pair[1]
			var p := c + nrm * l
			q.append(Vector3(p.x, ground(p.x, p.y) + lerpf(lift0, lift1, 0.5), p.y))
		var up := (q[1] - q[0]).cross(q[3] - q[0]).normalized()
		if up.y < 0.0:
			q.reverse()
			up = -up
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_normal(up)
			st.set_uv(Vector2(q[idx].x, q[idx].z) * 0.25)
			st.add_vertex(q[idx])


func _curb_face(st: SurfaceTool, c0: Vector2, c1: Vector2, nrm: Vector2, offset: float, low: float, high: float, side: float) -> void:
	var p0 := c0 + nrm * offset
	var p1 := c1 + nrm * offset
	var g0 := ground(p0.x, p0.y)
	var g1 := ground(p1.x, p1.y)
	var v := [Vector3(p0.x, g0 + low - 0.02, p0.y), Vector3(p1.x, g1 + low - 0.02, p1.y), Vector3(p1.x, g1 + high, p1.y), Vector3(p0.x, g0 + high, p0.y)]
	var face_n := Vector3(-nrm.x * side, 0, -nrm.y * side)
	var n := ((v[1] as Vector3) - (v[0] as Vector3)).cross((v[3] as Vector3) - (v[0] as Vector3)).normalized()
	if n.dot(face_n) < 0.0:
		v.reverse()
	for idx: int in [0, 1, 2, 0, 2, 3]:
		st.set_normal(face_n)
		st.set_uv(Vector2((v[idx] as Vector3).x + (v[idx] as Vector3).z, (v[idx] as Vector3).y))
		st.add_vertex(v[idx])


func _add_road_mesh(st: SurfaceTool, mesh_name: String, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = mesh_name
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _road_material(color: Color, rough: float, tiles: bool = false) -> Material:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform vec3 base_color;
uniform float rough;
uniform float tiles;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n = noise(p * 3.0) * 0.5 + noise(p * 11.0) * 0.3 + noise(p * 0.4) * 0.2;
	vec3 c = base_color * (0.86 + n * 0.28);
	if (tiles > 0.5) {
		vec2 g = abs(fract(p / 0.9) - 0.5);
		float line = smoothstep(0.47, 0.49, max(g.x, g.y));
		c *= 1.0 - line * 0.25;
	} else {
		float patchy = smoothstep(0.62, 0.7, noise(p * 0.25 + 7.0));
		c = mix(c, c * 0.8, patchy * 0.5);
	}
	ALBEDO = c;
	ROUGHNESS = rough;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"base_color", Vector3(color.r, color.g, color.b))
	m.set_shader_parameter(&"rough", rough)
	m.set_shader_parameter(&"tiles", 1.0 if tiles else 0.0)
	return m


## [centre, road direction, road half width] for every zebra crossing:
## both sides of each junction and where roads enter the square.
func _crosswalks() -> Array:
	var out: Array = []
	var roads := _paved_roads()
	for r in roads:
		var pts: Array = r["points"]
		var half: float = r["half"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / length
			# Junctions: where another road's centreline meets this segment.
			for other in roads:
				if other == r:
					continue
				var opts: Array = other["points"]
				for k in opts.size() - 1:
					var hit: Variant = _segment_hit(a, b, opts[k], opts[k + 1], float(other["half"]) + 0.5)
					if hit == null:
						continue
					var t := ((hit as Vector2) - a).dot(dir)
					var off := float(other["half"]) + SIDEWALK_W + 1.3
					for sgn: float in [-1.0, 1.0]:
						var tt := t + sgn * off
						if tt > 2.0 and tt < length - 2.0:
							out.append([a + dir * tt, dir, half])
			# Entering the town square.
			for e: Vector2 in [a, b]:
				if e.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 2.0:
					var inward := 1.0 if e == a else -1.0
					out.append([e + dir * inward * 3.0, dir, half])
	return out


## Point where segment p0-p1 meets segment q0-q1 (or where q's endpoint
## touches p within `touch` metres); null otherwise.
static func _segment_hit(p0: Vector2, p1: Vector2, q0: Vector2, q1: Vector2, touch: float) -> Variant:
	var hit: Variant = Geometry2D.segment_intersects_segment(p0, p1, q0, q1)
	if hit != null:
		return hit
	for q: Vector2 in [q0, q1]:
		var c := Geometry2D.get_closest_point_to_segment(q, p0, p1)
		if c.distance_to(q) < touch:
			return c
	return null


# ------------------------------------------------------------------ square
func _build_square() -> void:
	var c := TownLayout.TOWN_CENTER
	# v5a: paving, centrepiece, flowers, ornate lamps, statue and hedges come
	# from the "town_square" module (TownSquare); the market stalls moved to
	# the central market area ("market" module, MarketArea).
	var square := TownSquare.new()
	square.name = "TownSquare"
	add_child(square)
	lamp_positions.append_array(square.lamp_positions)
	var market := MarketArea.new()
	market.name = "MarketArea"
	add_child(market)
	# Benches around the fountain / well, facing it.
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var bp := c + Vector2(sin(a), cos(a)) * 6.2
		bench(Vector3(bp.x, ground(bp.x, bp.y), bp.y), atan2(c.x - bp.x, c.y - bp.y))
		var tp := c + Vector2(sin(a + 0.32), cos(a + 0.32)) * 6.4
		trash_bin(Vector3(tp.x, ground(tp.x, tp.y), tp.y))
	for k in 6:
		var a := TAU * k / 6.0 + 0.2
		var pp := c + Vector2(sin(a), cos(a)) * 9.0
		if _on_other_asphalt(pp, {}, -0.2) and pp.distance_to(c) > TownLayout.SQUARE_RADIUS:
			continue
		if absf(pp.x - c.x) < 3.5 or absf(pp.y - c.y) < 3.5:
			continue
		planter(Vector3(pp.x, ground(pp.x, pp.y), pp.y))


func _cobble_material() -> Material:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz * 2.2;
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	vec2 cell = floor(p);
	vec2 f = fract(p) - 0.5;
	float edge = smoothstep(0.38, 0.48, max(abs(f.x), abs(f.y)));
	float h = hash(cell);
	vec3 stone = mix(vec3(0.58, 0.54, 0.48), vec3(0.47, 0.44, 0.4), h);
	ALBEDO = mix(stone, vec3(0.28, 0.26, 0.24), edge);
	ROUGHNESS = 0.9;
	NORMAL_MAP = vec3(0.5 + f.x * edge * 0.6, 0.5 + f.y * edge * 0.6, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


# ------------------------------------------------------------------ yards
## One straight fence run (yards module: post-and-rail with a top railing, or
## white pickets), with collision.
## Fenced back garden behind a home (side runs + back run with railing),
## shrunk or skipped where a road or another building is in the way.
func _back_yard(b: Dictionary, c: Vector2, yaw: float, size: Vector3) -> void:
	var f := fwd_of(yaw)
	var r := right_of(yaw)
	var back := Vector3(c.x, 0, c.y) - f * (size.z * 0.5)
	var hw := size.x * 0.5 + 0.6
	for depth: float in [5.0, 3.5, 2.2]:
		if _yard_clear(b, back, f, r, hw, depth):
			var bl := back - r * hw - f * depth
			var br := back + r * hw - f * depth
			_yard_run(back - r * hw - f * 0.2, bl)
			_yard_run(bl, br)
			_yard_run(br, back + r * hw - f * 0.2)
			return


func _yard_clear(b: Dictionary, back: Vector3, f: Vector3, r: Vector3, hw: float, depth: float) -> bool:
	for i in 9:
		for j in 5:
			var p3 := back - f * (0.3 + (depth + 0.6) * j / 4.0) + r * lerpf(-hw - 0.4, hw + 0.4, i / 8.0)
			var p := Vector2(p3.x, p3.z)
			if Terrain.road_at(p.x, p.y) > 0.05 or not TownLayout.PLAY_AREA.grow(-3.0).has_point(p):
				return false
			if TownLayout.sea_distance(p.x, p.y) > -TownLayout.SAND_WIDTH:
				return false
			for o in TownLayout.BUILDINGS:
				if o["id"] != b["id"] and (o["pos"] as Vector2).distance_to(p) < 20.0 and TownLayout.footprint_distance(o, p, 1.0) < 0.0:
					return false
	return true


## v5a live yard swap: the yard fences live in their own merged mesh +
## collision body ("Yards"), rebuilt from the recorded runs when the "yards"
## module changes - no world rebuild.
var _yard_list: Array = []
var _yard_holder: Node3D = null
var _yard_body: StaticBody3D = null
var yards_node: Node3D = null
var yard_rebuilds: int = 0


func _yard_run(a: Vector3, b: Vector3) -> void:
	_yard_list.append([a, b])


func _build_yards() -> void:
	if yards_node:
		remove_child(yards_node)
		yards_node.queue_free()
	yards_node = Node3D.new()
	yards_node.name = "Yards"
	add_child(yards_node)
	_yard_body = StaticBody3D.new()
	_yard_body.name = "YardCollision"
	yards_node.add_child(_yard_body)
	_yard_holder = Node3D.new()
	yards_node.add_child(_yard_holder)
	yard_runs = 0
	for ab in _yard_list:
		_yard_fence(ab[0], ab[1])
	var merged := MeshMerger.merge_children(_yard_holder, yards_node, "YardsMesh")
	merged.visibility_range_end = PROP_VISIBILITY
	yards_node.add_child(merged)
	_yard_holder.queue_free()
	_yard_holder = null


func _yard_fence(a: Vector3, b: Vector3) -> void:
	yard_runs += 1
	var ys := Modules.style("yards") as YardStyle
	var kind := ys.kind if ys else "rail"
	var h := ys.height if ys else 0.95
	var wood := _mat("yard_" + kind, ys.wood_color if ys else Color(0.5, 0.36, 0.22), 0.8)
	var d := Vector3(b.x - a.x, 0, b.z - a.z)
	var length := d.length()
	if length < 0.3:
		return
	var dir := d / length
	var yaw := atan2(dir.x, dir.z)
	var n := maxi(1, int(ceil(length / (ys.post_spacing if ys else 1.6))))
	for k in n + 1:
		var p := a + dir * (length * k / n)
		_box(Vector3(0.1, h + 0.1, 0.1), Vector3(p.x, ground(p.x, p.z) + (h + 0.1) * 0.5, p.z), wood, yaw)
	var mid := (a + b) * 0.5
	var g := ground(mid.x, mid.z)
	if kind == "picket":
		var count := int(length / 0.22)
		for k in count:
			var p := a + dir * ((k + 0.5) * length / count)
			_box(Vector3(0.08, h, 0.03), Vector3(p.x, ground(p.x, p.z) + h * 0.5, p.z), wood, yaw)
		_box(Vector3(0.04, 0.07, length), Vector3(mid.x, g + h * 0.4, mid.z), wood, yaw)
		_box(Vector3(0.04, 0.07, length), Vector3(mid.x, g + h * 0.78, mid.z), wood, yaw)
	else:
		_box(Vector3(0.05, 0.09, length), Vector3(mid.x, g + h * 0.4, mid.z), wood, yaw)
		_box(Vector3(0.05, 0.09, length), Vector3(mid.x, g + h * 0.75, mid.z), wood, yaw)
		_box(Vector3(0.13, 0.05, length + 0.08), Vector3(mid.x, g + h + 0.07, mid.z), wood, yaw)
	_collider(Vector3(0.12, h + 0.1, length), Vector3(mid.x, g + (h + 0.1) * 0.5, mid.z), yaw)


func _build_walkways_and_yards() -> void:
	var stone := _mat("walkway", Color(0.62, 0.58, 0.52), 0.9)
	var idx := 0
	for b in TownLayout.BUILDINGS:
		var yaw := deg_to_rad(float(b["yaw"]))
		var f := fwd_of(yaw)
		var r := right_of(yaw)
		var size: Vector3 = b["size"]
		var c: Vector2 = b["pos"]
		var front := Vector3(c.x, 0, c.y) + f * (size.z * 0.5 + (1.8 if b.get("porch", false) else 0.0))
		# Walkway: stepping stones from the door to the sidewalk / road.
		var reach := 0.0
		for k in 12:
			var p := front + f * (1.6 + k * 0.9)
			if Terrain.road_at(p.x, p.z) > 0.55 or _on_other_asphalt(Vector2(p.x, p.z), {}, 2.0):
				break
			_box(Vector3(1.1, 0.06, 0.7), Vector3(p.x, ground(p.x, p.z) + 0.03, p.z), stone, yaw)
			reach = 1.6 + k * 0.9
		idx += 1
		if b["kind"] == "home" and b["id"] != "farmhouse":
			_back_yard(b, c, yaw, size)
		if b["kind"] != "home" or b["id"] == "farmhouse":
			# Shops: two planters by the door.
			for sgn: float in [-1.0, 1.0]:
				var pp := front + f * 1.0 + r * sgn * (size.x * 0.5 - 0.6)
				planter(Vector3(pp.x, ground(pp.x, pp.z), pp.z))
			continue
		# Homes: front yard fence or hedge (alternating) with a gap for the path,
		# and a mailbox by the path.
		var yard := minf(reach, 4.5)
		if yard < 1.5:
			continue
		var line := front + f * yard
		# v4 yards module: wooden fence + railing around the front yard
		# (front run with a gate gap for the path, side runs back to the house).
		var hw_y := size.x * 0.5 + 0.4
		for sgn: float in [-1.0, 1.0]:
			var a := line + r * sgn * 0.9
			var corner := line + r * sgn * hw_y
			_yard_run(a, corner)
			_yard_run(corner, front + r * sgn * hw_y + f * 0.25)
		var mb := line + r * 1.3 + f * 0.55
		mailbox(Vector3(mb.x, ground(mb.x, mb.z), mb.z), yaw, str(b["address"]).get_slice(" ", 0))


# ------------------------------------------------------------------ street furniture
func bench(pos: Vector3, yaw: float) -> void:
	var wood := _mat("bench_wood", Color(0.55, 0.36, 0.2), 0.8)
	var iron := _mat("iron", Color(0.13, 0.13, 0.14), 0.5, false)
	var f := fwd_of(yaw)
	var r := right_of(yaw)
	for k in 3:
		var p := pos + Vector3(0, 0.46, 0) + f * (-0.12 + k * 0.13)
		_box(Vector3(1.6, 0.04, 0.11), p, wood, yaw)
	for k in 2:
		var p := pos + Vector3(0, 0.66 + k * 0.17, 0) - f * 0.24
		_box(Vector3(1.6, 0.11, 0.035), p, wood, yaw, false, Vector3(-0.2, 0, 0))
	for sgn: float in [-1.0, 1.0]:
		var p := pos + r * sgn * 0.7
		_box(Vector3(0.06, 0.46, 0.45), p + Vector3(0, 0.23, 0), iron, yaw)
		_box(Vector3(0.05, 0.42, 0.05), p + Vector3(0, 0.68, 0) - f * 0.26, iron, yaw)
	_collider(Vector3(1.6, 0.5, 0.5), pos + Vector3(0, 0.25, 0), yaw)
	var seat := Seat.new()
	seat.display_name = "bench"
	seat.position = pos + f * 0.05
	seat.rotation.y = yaw
	add_child(seat)


func trash_bin(pos: Vector3) -> void:
	var green := _mat("bin_green", Color(0.18, 0.33, 0.22), 0.6)
	var iron := _mat("iron", Color(0.13, 0.13, 0.14), 0.5, false)
	_cyl(0.24, 0.21, 0.8, pos + Vector3(0, 0.4, 0), green, 10, true)
	_cyl(0.26, 0.26, 0.05, pos + Vector3(0, 0.82, 0), iron, 10)
	_cyl(0.18, 0.18, 0.02, pos + Vector3(0, 0.85, 0), _mat("bin_hole", Color(0.05, 0.05, 0.05), 0.9, false), 10)


func mailbox(pos: Vector3, yaw: float, number: String) -> void:
	var wood := _mat("post_wood", Color(0.42, 0.3, 0.2), 0.85)
	var box_mat := _mat("mailbox", Color(0.2, 0.3, 0.55), 0.45)
	_box(Vector3(0.09, 1.05, 0.09), pos + Vector3(0, 0.52, 0), wood, yaw, true)
	_box(Vector3(0.26, 0.26, 0.46), pos + Vector3(0, 1.15, 0), box_mat, yaw)
	_cyl(0.13, 0.13, 0.46, pos + Vector3(0, 1.28, 0), box_mat, 10, false, Vector3(PI * 0.5, yaw, 0))
	_box(Vector3(0.03, 0.18, 0.05), pos + Vector3(0, 1.36, 0) + right_of(yaw) * 0.15, _mat("flag_red", Color(0.8, 0.15, 0.12), 0.6, false), yaw)
	var l := Label3D.new()
	l.text = number
	l.font_size = 48
	l.pixel_size = 0.004
	l.modulate = Color(1, 1, 1)
	l.outline_size = 8
	l.position = pos + Vector3(0, 1.17, 0) + right_of(yaw) * 0.14
	l.rotation.y = yaw + PI * 0.5
	l.visibility_range_end = 25.0
	add_child(l)


func planter(pos: Vector3) -> void:
	# v7b.1 street_plants: no planters on the (widened) asphalt, no loose flower balls.
	if StreetPlants.replaces_old() and StreetPlants.on_asphalt(Vector2(pos.x, pos.z), 0.3):
		return
	var stone := _mat("planter", Color(0.66, 0.6, 0.52), 0.9)
	var soil := _mat("soil_dark", Color(0.25, 0.18, 0.12), 1.0, false)
	var leaf := _mat("planter_leaf", Color(0.24, 0.45, 0.18), 0.9)
	_box(Vector3(0.9, 0.5, 0.9), pos + Vector3(0, 0.25, 0), stone, 0.0, true)
	_box(Vector3(0.78, 0.04, 0.78), pos + Vector3(0, 0.49, 0), soil)
	_sphere(0.38, pos + Vector3(0, 0.75, 0), leaf, Vector3(1, 0.8, 1))
	var flower := _mat("planter_flower_%d" % (int(absf(pos.x * 7.0 + pos.z)) % 3), [Color(0.9, 0.3, 0.35), Color(0.95, 0.8, 0.3), Color(0.75, 0.45, 0.85)][int(absf(pos.x * 7.0 + pos.z)) % 3], 0.6, false)
	if StreetPlants.replaces_old():
		_sphere(0.3, pos + Vector3(0, 0.95, 0), flower, Vector3(1, 0.3, 1))
		return
	for k in 5:
		var a := k * 1.3
		_sphere(0.07, pos + Vector3(cos(a) * 0.25, 0.98 - (k % 2) * 0.1, sin(a) * 0.25), flower)


func lamp(pos: Vector3, yaw: float) -> void:
	var iron := _mat("iron", Color(0.13, 0.13, 0.14), 0.5, false)
	var h := 3.4
	_cyl(0.12, 0.16, 0.3, pos + Vector3(0, 0.1, 0), _mat("lamp_base", Color(0.5, 0.48, 0.45), 0.9), 8)
	_cyl(0.045, 0.06, h, pos + Vector3(0, h * 0.5, 0), iron, 8, true)
	var f := fwd_of(yaw)
	_box(Vector3(0.05, 0.05, 0.55), pos + Vector3(0, h - 0.05, 0) + f * 0.25, iron, yaw)
	var lp := pos + Vector3(0, h - 0.32, 0) + f * 0.5
	_box(Vector3(0.26, 0.04, 0.26), lp + Vector3(0, 0.22, 0), iron, yaw)
	_box(Vector3(0.2, 0.32, 0.2), lp + Vector3(0, 0.04, 0), StreetLamp.lantern_material(), yaw)
	_box(Vector3(0.24, 0.04, 0.24), lp + Vector3(0, -0.13, 0), iron, yaw)
	_cyl(0.0, 0.2, 0.14, lp + Vector3(0, 0.31, 0), iron, 4)
	lamp_positions.append(lp + Vector3(0, -0.1, 0))


func _build_street_lamps() -> void:
	for road in _paved_roads():
		var half: float = road["half"]
		var pts: Array = road["points"]
		var along := 6.0
		var side := 1.0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			var dir := (b - a) / length
			var nrm := Vector2(-dir.y, dir.x)
			while along < length:
				var p := a + dir * along + nrm * side * (half + SIDEWALK_W - 0.35)
				if not _on_other_asphalt(p, road, 3.0) and not _in_building(p, 1.0) and not _near_door(p, 2.5):
					var face := -nrm * side
					lamp(Vector3(p.x, ground(p.x, p.y), p.y), atan2(face.x, face.y))
				side = -side
				along += LAMP_SPACING
			along -= length
	# Paths: a few lamps along Farm Rd and the beach path, around the square.
	for p: Vector2 in [Vector2(2.0, -20.0), Vector2(-2.2, -31.0), Vector2(1.9, -12.0), Vector2(24.0, 2.8), Vector2(35.0, 6.2), Vector2(-20.0, 10.5)]:
		lamp(Vector3(p.x, ground(p.x, p.y), p.y), 0.0)
	var c := TownLayout.TOWN_CENTER
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var p := c + Vector2(sin(a), cos(a)) * 9.2
		lamp(Vector3(p.x, ground(p.x, p.y), p.y), a + PI)


func _near_door(p: Vector2, dist: float) -> bool:
	for b in TownLayout.BUILDINGS:
		var d := TownLayout.door_point(b, 2.0)
		if Vector2(d.x, d.z).distance_to(p) < dist:
			return true
	return false


func _build_street_furniture() -> void:
	# Benches with a bin next to them along the main streets, at the viewpoint,
	# by the pond and on the beach promenade.
	var spots: Array = [
		[Vector2(-24.0, -44.4), PI], [Vector2(24.0, -44.4), PI], [Vector2(-24.0, -55.6), 0.0], [Vector2(46.0, -55.6), 0.0],
		[Vector2(-5.4, -76.0), PI * 0.5], [Vector2(5.4, -104.0), -PI * 0.5], [Vector2(-30.0, -95.4), 0.0], [Vector2(39.0, -84.6), PI],
		[Vector2(-40.6, -104.0), -PI * 0.5], [Vector2(50.6, -30.0), PI * 0.5],
		[Vector2(52.0, -114.0), PI], [Vector2(48.0, -116.5), PI * 0.75],
		[Vector2(-27.5, 4.5), PI * 0.8], [Vector2(-40.5, 9.0), -PI * 0.6],
		[Vector2(30.5, 12.5), PI * 0.75], [Vector2(40.5, 2.0), PI * 0.75],
	]
	for s in spots:
		var p: Vector2 = s[0]
		var yaw: float = s[1]
		_queue_prop(p, func() -> void:
			bench(Vector3(p.x, ground(p.x, p.y), p.y), yaw)
			var tp := p + Vector2(cos(yaw), -sin(yaw)) * 1.25
			trash_bin(Vector3(tp.x, ground(tp.x, tp.y), tp.y)))
	# Planters along Main St.
	for x: float in [-30.0, -18.0, 18.0, 30.0, 44.0, 64.0]:
		for z: float in [-45.4, -54.6]:
			if _near_door(Vector2(x, z), 3.0) or _in_building(Vector2(x, z), 0.8):
				continue
			_queue_prop(Vector2(x, z), func() -> void: planter(Vector3(x, ground(x, z), z)))
	# Hedge along the farm's north edge and the farm cart.
	var hedge := _mat("hedge", Color(0.2, 0.36, 0.14), 0.95)
	for k in 6:
		var x := -26.0 + k * 3.2
		if absf(x) < 2.5:
			continue
		_box(Vector3(3.0, 1.1, 0.8), Vector3(x, ground(x, -16.0) + 0.5, -16.0), hedge, 0.0, true)
	_farm_cart(Vector3(4.6, ground(4.6, 7.8), 7.8), 0.4)


func _farm_cart(pos: Vector3, yaw: float) -> void:
	var wood := _mat("cart_wood", Color(0.55, 0.38, 0.22), 0.85)
	var dark := _mat("cart_dark", Color(0.35, 0.24, 0.15), 0.85)
	var f := fwd_of(yaw)
	var r := right_of(yaw)
	_box(Vector3(1.5, 0.08, 2.2), pos + Vector3(0, 0.72, 0), wood, yaw)
	for sgn: float in [-1.0, 1.0]:
		_box(Vector3(0.06, 0.4, 2.2), pos + Vector3(0, 0.95, 0) + r * sgn * 0.72, wood, yaw)
		_box(Vector3(1.5, 0.4, 0.06), pos + Vector3(0, 0.95, 0) + f * sgn * 1.08, wood, yaw)
		_cyl(0.42, 0.42, 0.08, pos + Vector3(0, 0.42, 0) + r * sgn * 0.85, dark, 14, false, Vector3(0, yaw, PI * 0.5))
		_box(Vector3(0.07, 0.07, 1.6), pos + Vector3(0, 0.62, 0) + r * sgn * 0.35 + f * 1.8, dark, yaw)
	# A few pumpkins and a sack in the cart.
	var orange := _mat("cart_pumpkin", Color(0.9, 0.5, 0.12), 0.6)
	for k in 3:
		_sphere(0.22, pos + Vector3(0, 0.95, 0) + r * (-0.35 + k * 0.35) + f * (0.3 - k * 0.25), orange, Vector3(1, 0.8, 1))
	_collider(Vector3(1.6, 1.2, 2.3), pos + Vector3(0, 0.6, 0), yaw)


static func _v6b_vehicle_owned(model: String) -> bool:
	match model:
		"police":
			return Modules.style("police_patrol") != null
		"ambulance":
			return Modules.style("ambulance") != null
	return Modules.style("vehicles") != null


func _build_parked_vehicles() -> void:
	var fstyle := Modules.style("furniture") as FurnitureStyle
	var car_dir := fstyle.cars_dir if fstyle else "res://assets/third_party/kenney/cars/"
	var defaults: Array = [
		["police", Vector2(-27.0, -53.9), PI * 0.5], ["ambulance", Vector2(41.5, -53.9), -PI * 0.5],
		["delivery", Vector2(27.0, -46.1), PI * 0.5], ["sedan", Vector2(-12.0, -86.65), PI * 0.5],
		["van", Vector2(30.0, -93.35), -PI * 0.5], ["sedan", Vector2(3.35, -112.0), 0.0],
		["sedan", Vector2(51.65, -30.0), PI], ["tractor", Vector2(15.5, 11.5), -PI * 0.3],
	]
	var cars: Array = []
	if fstyle and not fstyle.parked_cars.is_empty():
		for i in fstyle.parked_cars.size():
			var d: Array = defaults[i % defaults.size()]
			cars.append([fstyle.parked_cars[i], d[1], d[2]])
	else:
		cars = defaults
	for c in cars:
		var path := car_dir + str(c[0]) + ".glb"
		if not ResourceLoader.exists(path):
			continue
		# v6b: the police car, ambulance and the town's cars are live vehicles
		# now (police_patrol / ambulance / vehicles modules own them).
		if _v6b_vehicle_owned(str(c[0])):
			continue
		var p: Vector2 = c[1]
		var yaw: float = c[2]
		var inst := (load(path) as PackedScene).instantiate() as Node3D
		var aabb := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var a := MeshMerger._relative_xform(mi as MeshInstance3D, inst) * (mi as MeshInstance3D).mesh.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		var length := 3.4 if c[0] == "tractor" else (4.6 if c[0] in ["ambulance", "delivery", "van"] else 4.2)
		var k := length / maxf(aabb.size.z, aabb.size.x)
		var holder := Node3D.new()
		holder.position = Vector3(p.x, ground(p.x, p.y), p.y)
		holder.rotation.y = yaw
		_chunk_for(holder.position).add_child(holder)
		inst.scale = Vector3.ONE * k
		inst.position = Vector3(-aabb.get_center().x * k, -aabb.position.y * k, -aabb.get_center().z * k)
		holder.add_child(inst)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = aabb.size * k
		cs.shape = bs
		cs.position = holder.position + Vector3(0, bs.size.y * 0.5, 0)
		cs.rotation.y = yaw
		_body.add_child(cs)


func _build_street_signs() -> void:
	var pole := _mat("sign_pole", Color(0.3, 0.32, 0.34), 0.5, false)
	var board := _mat("sign_board", Color(0.12, 0.38, 0.22), 0.6)
	for s in TownLayout.STREET_SIGNS:
		var p: Vector2 = s[0]
		var pos := Vector3(p.x, ground(p.x, p.y), p.y)
		_cyl(0.05, 0.05, 2.9, pos + Vector3(0, 1.45, 0), pole, 8, true)
		for k in 2:
			var yaw := 0.0 if k == 0 else PI * 0.5
			var y := 2.65 - k * 0.32
			_box(Vector3(1.6, 0.28, 0.04), pos + Vector3(0, y, 0), board, yaw)
			for sgn: float in [1.0, -1.0]:
				var l := Label3D.new()
				# v6b: street names in the current language (SignText).
				l.set_meta(&"en", str(s[1 + k]))
				Lang.setup_label3d(l, 64)
				l.text = SignText.street(str(s[1 + k]))
				l.font_size = 64
				l.pixel_size = 0.0036
				l.modulate = Color(1, 1, 1)
				l.outline_size = 0
				l.double_sided = false
				l.position = pos + Vector3(0, y, 0) + fwd_of(yaw) * 0.025 * sgn
				l.rotation.y = yaw + (0.0 if sgn > 0.0 else PI)
				l.visibility_range_end = 60.0
				l.add_to_group(&"street_signs")
				l.set_meta(&"street_sign", true)
				add_child(l)


## Keep distant furniture uninstantiated until the player approaches. Collision
## is created along with the visual, well outside interaction distance.
func _queue_prop(pos: Vector2, build: Callable) -> void:
	_pending_props.append({"pos": pos, "build": build})


func _process(delta: float) -> void:
	stream_buildings(delta)
	build_nearby_props()


func stream_buildings(delta: float) -> void:
	if not Building.lazy_exteriors():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var quality := PerfQuality.style()
	var radius := clampf(quality.stream_radius, 55.0, 110.0) if quality else 75.0
	var nearest: Building = null
	var distance := INF
	for b: Building in buildings.values():
		var d := Vector2(b.global_position.x - player.global_position.x, b.global_position.z - player.global_position.z).length()
		if b.player_inside or d < radius:
			b._exterior_far_time = 0.0
			if not b.exterior_built and d < distance:
				nearest = b
				distance = d
		elif b.exterior_built:
			b._exterior_far_time += delta
			if d > radius + 35.0 and b._exterior_far_time > 15.0:
				b.release_interior()
				b.release_exterior()
	if nearest:
		nearest.ensure_exterior()


func build_nearby_props(force: bool = false) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null and not force:
		return
	var centre := Vector2(player.global_position.x, player.global_position.z) if player else Vector2.ZERO
	var quality := PerfQuality.style()
	var radius := maxf(45.0, quality.stream_radius) if quality else 65.0
	var start := Time.get_ticks_usec()
	var changed := false
	for i in range(_pending_props.size() - 1, -1, -1):
		var job: Dictionary = _pending_props[i]
		if not force and centre.distance_to(job["pos"]) > radius:
			continue
		_pending_props.remove_at(i)
		(job["build"] as Callable).call()
		changed = true
		# One batch per frame; distant jobs stay pending, rather than catching up
		# all at once after a teleport.
		if not force and Time.get_ticks_usec() - start >= 1500:
			break
	if changed:
		_merge_chunks()


func _merge_chunks() -> void:
	_merge_generation += 1
	for key in _chunks:
		var n: Node3D = _chunks[key]
		var merged := MeshMerger.merge_children(n, self, "StreetProps_%d_%d_%d" % [key.x, key.y, _merge_generation])
		merged.visibility_range_end = PROP_VISIBILITY
		merged.visibility_range_end_margin = 10.0
		merged.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(merged)
		# The streamer's initial scan runs once. Later furniture batches must
		# register themselves so cell sleeping also covers these new meshes.
		var streamer := get_tree().get_first_node_in_group(&"world_streamer") as WorldStreamer
		if streamer and streamer._scanned:
			streamer.register(merged, merged.global_transform * merged.get_aabb().get_center(), true)
		n.queue_free()
	_chunks.clear()
