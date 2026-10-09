class_name Landscape
extends Node3D
## v4 landscape module: the scenery that makes the island feel endless - a
## dense belt of tall conifers around the play area, rings of cheap far trees,
## snow-capped mountains on the horizon (never on the sea side) and the river
## that runs from the western mountains through the pond to the beach.
## Everything is driven by the active "landscape" module (LandscapeStyle) and
## rebuilt when it is swapped. Group "landscape" (the minimap asks it for the
## river line).

const WATER_STEP := 2.0
const RIVER_RIBBON_HALF := 3.4

var forest_instances := 0
var far_instances := 0
var mountain_count := 0
var river_vertices := 0
var _vc_mat: StandardMaterial3D
var _river_mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group("landscape")
	Modules.on_swap("landscape", self, func(_m: AssetModule) -> void: rebuild())
	rebuild()


func style() -> LandscapeStyle:
	return Modules.style("landscape") as LandscapeStyle


## River centre line (the minimap draws it).
func river_points() -> Array:
	var st := style()
	return TownLayout.RIVER if st == null or st.river else []


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	forest_instances = 0
	far_instances = 0
	mountain_count = 0
	river_vertices = 0
	var st := style()
	if st == null:
		push_warning("Landscape: no 'landscape' module registered")
		return
	_rng.seed = 4242
	_vc_mat = StandardMaterial3D.new()
	_vc_mat.vertex_color_use_as_albedo = true
	_vc_mat.roughness = 0.95
	_build_forest(st)
	_build_mountains(st)
	if st.river:
		_build_river(st)


# ------------------------------------------------------------------ forest
static func _land_ok(p: Vector2, sea_margin: float) -> bool:
	if TownLayout.sea_distance(p.x, p.y) > -TownLayout.SAND_WIDTH - sea_margin:
		return false
	return TownLayout.river_distance(p) > TownLayout.RIVER_HALF + 3.0


## Low-poly conifer: trunk + three stacked cones, vertex coloured (~70 tris).
static func conifer_mesh(segments: int, tiers: int, dark: Color, light: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var trunk := Color(0.33, 0.22, 0.14)
	_cone(st, 0.0, 1.3, 0.22, 0.16, 6, trunk, trunk)
	for t in tiers:
		var f := float(t) / float(tiers)
		var y0 := 1.0 + f * 5.2
		var r := lerpf(2.1, 0.9, f)
		_cone(st, y0, y0 + lerpf(3.4, 2.6, f), r, 0.0, segments, dark.lerp(light, f * 0.6), light.lerp(dark, 0.25))
	st.generate_normals()
	return st.commit()


static func _cone(st: SurfaceTool, y0: float, y1: float, r0: float, r1: float, seg: int, c0: Color, c1: Color) -> void:
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var p00 := Vector3(cos(a0) * r0, y0, sin(a0) * r0)
		var p10 := Vector3(cos(a1) * r0, y0, sin(a1) * r0)
		var p01 := Vector3(cos(a0) * r1, y1, sin(a0) * r1)
		var p11 := Vector3(cos(a1) * r1, y1, sin(a1) * r1)
		st.set_color(c0); st.add_vertex(p00)
		st.set_color(c1); st.add_vertex(p01)
		st.set_color(c0); st.add_vertex(p10)
		if r1 > 0.0:
			st.set_color(c0); st.add_vertex(p10)
			st.set_color(c1); st.add_vertex(p01)
			st.set_color(c1); st.add_vertex(p11)
		# bottom cap (seen from below on slopes)
		st.set_color(c0.darkened(0.3)); st.add_vertex(Vector3(0, y0, 0))
		st.set_color(c0.darkened(0.3)); st.add_vertex(p10)
		st.set_color(c0.darkened(0.3)); st.add_vertex(p00)


func _build_forest(st: LandscapeStyle) -> void:
	var area := TownLayout.PLAY_AREA
	var near_mesh := conifer_mesh(8, 3, Color(0.11, 0.27, 0.15), Color(0.2, 0.42, 0.2))
	var far_mesh := conifer_mesh(5, 2, Color(0.12, 0.25, 0.17), Color(0.18, 0.33, 0.2))
	# Dense belt: rings just outside the play area (behind the edge trees).
	var belt: Array[Transform3D] = []
	var rings := maxi(st.forest_rings, 0)
	for ring in rings:
		var inner := 4.0 + ring * 11.0
		var rect := area.grow(inner)
		var perim := 2.0 * (rect.size.x + rect.size.y)
		var count := int(perim / 4.2 * st.forest_density)
		for i in count:
			var p := _point_on_rect(rect, _rng.randf() * perim) + Vector2(_rng.randf_range(-5.0, 5.0), _rng.randf_range(-5.0, 5.0))
			if area.grow(2.0).has_point(p) or not _land_ok(p, 4.0):
				continue
			var s := _rng.randf_range(st.forest_scale.x, st.forest_scale.y)
			belt.append(_tree_xf(p, s))
	forest_instances = belt.size()
	_add_mm("ForestBelt", near_mesh, belt, 0.0, true)
	# Far rings: cheap impostors out to the mountains.
	var far: Array[Transform3D] = []
	var tries := 0
	while far.size() < st.far_trees and tries < st.far_trees * 6:
		tries += 1
		var ang := _rng.randf() * TAU
		var rad := _rng.randf_range(70.0, 205.0)
		var p := area.get_center() + Vector2(cos(ang), sin(ang)) * rad
		if area.grow(4.0 + rings * 11.0).has_point(p) or not _land_ok(p, 8.0):
			continue
		far.append(_tree_xf(p, _rng.randf_range(st.forest_scale.x, st.forest_scale.y) * 1.15))
	far_instances = far.size()
	_add_mm("FarForest", far_mesh, far, 0.0, false)


func _point_on_rect(r: Rect2, d: float) -> Vector2:
	if d < r.size.x:
		return Vector2(r.position.x + d, r.position.y)
	d -= r.size.x
	if d < r.size.y:
		return Vector2(r.end.x, r.position.y + d)
	d -= r.size.y
	if d < r.size.x:
		return Vector2(r.end.x - d, r.end.y)
	d -= r.size.x
	return Vector2(r.position.x, r.end.y - d)


func _tree_xf(p: Vector2, s: float) -> Transform3D:
	var y := Terrain.height_at(p.x, p.y) - 0.2
	var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(s, s * _rng.randf_range(0.9, 1.25), s))
	return Transform3D(b, Vector3(p.x, y, p.y))


func _add_mm(node_name: String, mesh: Mesh, xforms: Array[Transform3D], view: float, shadows: bool) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = _vc_mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if view > 0.0:
		mmi.visibility_range_end = view
	add_child(mmi)


# ------------------------------------------------------------------ mountains
func _build_mountains(st: LandscapeStyle) -> void:
	if st.mountain_count <= 0:
		return
	var center := TownLayout.PLAY_AREA.get_center()
	var stool := SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var noise := FastNoiseLite.new()
	noise.seed = 77
	noise.frequency = 0.9
	var placed := 0
	var k := 0
	while placed < st.mountain_count and k < st.mountain_count * 8:
		k += 1
		var ang := TAU * float(k) / float(st.mountain_count * 2) + _rng.randf_range(-0.12, 0.12)
		var rad := _rng.randf_range(225.0, 262.0)
		var p := center + Vector2(cos(ang), sin(ang)) * rad
		if TownLayout.sea_distance(p.x, p.y) > -60.0:
			continue
		var h := st.mountain_height * _rng.randf_range(0.6, 1.25)
		var r := h * _rng.randf_range(1.3, 1.8)
		_mountain(stool, Vector3(p.x, Terrain.height_at(p.x, p.y) - 4.0, p.y), r, h, st, noise, float(k) * 13.0)
		placed += 1
	mountain_count = placed
	stool.generate_normals()
	var mi := MeshInstance3D.new()
	mi.name = "Mountains"
	mi.mesh = stool.commit()
	mi.material_override = _vc_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _mountain(stool: SurfaceTool, base: Vector3, r: float, h: float, st: LandscapeStyle, noise: FastNoiseLite, off: float) -> void:
	const SEG := 14
	const RINGS := 6
	var pts: Array = []
	for j in RINGS + 1:
		var f := float(j) / RINGS
		var row: Array = []
		for i in SEG:
			var a := TAU * i / SEG
			var jag := 1.0 + noise.get_noise_2d(cos(a) * 2.0 + off, f * 3.0) * 0.35
			var rr := r * (1.0 - f) * jag
			var yy := h * pow(f, 0.85) * (1.0 + noise.get_noise_2d(off + i, f * 5.0) * 0.12)
			row.append(base + Vector3(cos(a) * rr, yy, sin(a) * rr))
		pts.append(row)
	var peak := base + Vector3(0, h * 1.02, 0)
	var rock := st.mountain_color
	var grass := Color(0.24, 0.36, 0.2)
	var snow := Color(0.93, 0.95, 0.98)
	for j in RINGS:
		for i in SEG:
			var a0: Vector3 = pts[j][i]
			var a1: Vector3 = pts[j][(i + 1) % SEG]
			var b0: Vector3 = pts[j + 1][i] if j + 1 < RINGS else peak
			var b1: Vector3 = pts[j + 1][(i + 1) % SEG] if j + 1 < RINGS else peak
			for v: Vector3 in [a0, b0, a1, a1, b0, b1]:
				var t := (v.y - base.y) / h
				var c := grass.lerp(rock, smoothstep(0.08, 0.35, t))
				if t > st.snow_line:
					c = c.lerp(snow, smoothstep(st.snow_line, st.snow_line + 0.08, t))
				stool.set_color(c)
				stool.add_vertex(v)


# ------------------------------------------------------------------ river
func _build_river(st: LandscapeStyle) -> void:
	var sh := load("res://assets/shaders/river.gdshader") as Shader
	_river_mat = ShaderMaterial.new()
	_river_mat.shader = sh
	var col := st.river_color
	col.a = 0.82
	_river_mat.set_shader_parameter("water_color", col)
	var half := Terrain.RIVER_WATER_HALF * clampf(st.river_width / 4.0, 0.6, 1.0)
	var stool := SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var levels := Terrain.river_levels()
	# Sample the polyline every WATER_STEP metres (level interpolated).
	var samples: Array = []
	var ys: Array = []
	for i in TownLayout.RIVER.size() - 1:
		var a: Vector2 = TownLayout.RIVER[i]
		var b: Vector2 = TownLayout.RIVER[i + 1]
		var n := maxi(int(a.distance_to(b) / WATER_STEP), 1)
		for s in n:
			samples.append(a.lerp(b, float(s) / n))
			ys.append(lerpf(levels[i], levels[i + 1], float(s) / n))
	samples.append(TownLayout.RIVER[TownLayout.RIVER.size() - 1])
	ys.append(levels[levels.size() - 1])
	var dist := 0.0
	var prev_ok := false
	var prev_l := Vector3.ZERO
	var prev_r := Vector3.ZERO
	var prev_v := 0.0
	for i in samples.size():
		var p: Vector2 = samples[i]
		var dir: Vector2 = (samples[mini(i + 1, samples.size() - 1)] - samples[maxi(i - 1, 0)]).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		if i > 0:
			dist += p.distance_to(samples[i - 1])
		var in_pond := p.distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS - 1.0
		var in_sea := TownLayout.sea_distance(p.x, p.y) > -1.0
		var ok := not in_pond and not in_sea
		var y: float = ys[i] + 0.02
		var l := Vector3(p.x + nrm.x * half, y, p.y + nrm.y * half)
		var r := Vector3(p.x - nrm.x * half, y, p.y - nrm.y * half)
		if ok and prev_ok:
			for q: Array in [[prev_l, 0.0, prev_v], [r, 1.0, dist], [prev_r, 1.0, prev_v], [prev_l, 0.0, prev_v], [l, 0.0, dist], [r, 1.0, dist]]:
				stool.set_uv(Vector2(q[1], q[2]))
				stool.set_normal(Vector3.UP)
				stool.add_vertex(q[0])
				river_vertices += 1
		prev_ok = ok
		prev_l = l
		prev_r = r
		prev_v = dist
	var mi := MeshInstance3D.new()
	mi.name = "RiverWater"
	mi.mesh = stool.commit()
	mi.material_override = _river_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
