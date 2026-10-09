@tool
class_name Terrain
extends StaticBody3D
## v3 terrain: ~2.7x the v2 area (160 x 180 m playable). Gentle noise,
## hills (one with a lookout), flattened pads under every building, paved
## roads + dirt paths from TownLayout, a sandy beach sloping into the sea in the
## south-east corner, a pond, and distant hills outside the play area.
##
## Everything that needs the ground uses the static API:
##   height_at(x, z), dirt_at(x, z), road_at(x, z), sand_at(x, z), is_water(x, z)
## Road influence is rasterised once into a 1 m grid (fast lookups for grass
## and tree placement).

const SEED := 1337
const TOWN_CENTER := TownLayout.TOWN_CENTER
const TOWN_SQUARE_RADIUS := TownLayout.SQUARE_RADIUS
const PLAY_AREA := TownLayout.PLAY_AREA
## Kept for older callers (v2 API).
const PATHS: Array = []

@export var outer_extent: float = 260.0
@export var outer_cell: float = 4.0
@export var material: Material:
	set(v):
		material = v
		_queue_rebuild()

static var _noise: FastNoiseLite
static var _noise_detail: FastNoiseLite
static var _road_grid: PackedFloat32Array  ## paved influence 0..1
static var _dirt_grid: PackedFloat32Array  ## dirt-path influence 0..1
static var _grid_w: int = 0
static var _grid_h: int = 0
static var _pad_heights: Array = []
static var _river_levels: PackedFloat32Array = PackedFloat32Array()  ## water level per TownLayout.RIVER point
const RIVER_WATER_HALF := 3.4  ## half-width of the water surface (m)
var _rebuild_queued := false


func _ready() -> void:
	_apply_style(Modules.style("terrain") as TerrainStyle)
	Modules.on_swap("terrain", self, func(m: AssetModule) -> void: _apply_style(m as TerrainStyle))

	_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


# ------------------------------------------------------------------ static API
static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = SEED
		_noise.frequency = 0.03
		_noise.fractal_octaves = 3
		_noise_detail = FastNoiseLite.new()
		_noise_detail.seed = SEED + 7
		_noise_detail.frequency = 0.09
		_noise_detail.fractal_octaves = 2
	return _noise


static func _ensure_grids() -> void:
	if _grid_w > 0:
		return
	_grid_w = int(PLAY_AREA.size.x) + 1
	_grid_h = int(PLAY_AREA.size.y) + 1
	_road_grid = PackedFloat32Array()
	_road_grid.resize(_grid_w * _grid_h)
	_dirt_grid = PackedFloat32Array()
	_dirt_grid.resize(_grid_w * _grid_h)
	for road in TownLayout.ROADS:
		var pts: Array = road["points"]
		var half: float = road["half"]
		var paved: bool = road["kind"] == "paved"
		# Paved roads also flatten the sidewalks next to them.
		var inner := half + (2.2 if paved else 0.0)
		var reach := inner + (2.5 if paved else 1.0)
		var grid := _road_grid if paved else _dirt_grid
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var x0 := maxi(int(floor(minf(a.x, b.x) - reach - PLAY_AREA.position.x)), 0)
			var x1 := mini(int(ceil(maxf(a.x, b.x) + reach - PLAY_AREA.position.x)), _grid_w - 1)
			var z0 := maxi(int(floor(minf(a.y, b.y) - reach - PLAY_AREA.position.y)), 0)
			var z1 := mini(int(ceil(maxf(a.y, b.y) + reach - PLAY_AREA.position.y)), _grid_h - 1)
			var ab := b - a
			for gz in range(z0, z1 + 1):
				for gx in range(x0, x1 + 1):
					var p := Vector2(PLAY_AREA.position.x + gx, PLAY_AREA.position.y + gz)
					var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
					var d := p.distance_to(a + ab * t)
					var w := 1.0 - smoothstep(inner * (0.8 if not paved else 1.0), reach, d)
					var k := gz * _grid_w + gx
					grid[k] = maxf(grid[k], w)
	# Building pads: flatten to the natural height at the centre.
	_pad_heights.clear()
	for b in TownLayout.BUILDINGS:
		var c: Vector2 = b["pos"]
		_pad_heights.append(_natural_height(c.x, c.y))


static func _grid_sample(grid: PackedFloat32Array, x: float, z: float) -> float:
	_ensure_grids()
	var fx := x - PLAY_AREA.position.x
	var fz := z - PLAY_AREA.position.y
	if fx < 0.0 or fz < 0.0 or fx >= _grid_w - 1 or fz >= _grid_h - 1:
		return 0.0
	var ix := int(fx)
	var iz := int(fz)
	var tx := fx - ix
	var tz := fz - iz
	var k := iz * _grid_w + ix
	return lerpf(lerpf(grid[k], grid[k + 1], tx), lerpf(grid[k + _grid_w], grid[k + _grid_w + 1], tx), tz)


## Paved-road influence 0..1 (road surface + sidewalks).
static func road_at(x: float, z: float) -> float:
	return _grid_sample(_road_grid, x, z)


static func _hills(x: float, z: float) -> float:
	var h := 0.0
	for hill in TownLayout.HILLS:
		var d := Vector2(x, z).distance_to(hill[0])
		var r: float = hill[1]
		if d < r:
			var t := 1.0 - d / r
			h += float(hill[2]) * t * t * (3.0 - 2.0 * t)
	# Distant hills outside the play area (not on the sea side).
	var outside := Vector2(maxf(maxf(PLAY_AREA.position.x - x, x - PLAY_AREA.end.x), 0.0),
			maxf(maxf(PLAY_AREA.position.y - z, z - PLAY_AREA.end.y), 0.0)).length()
	if outside > 0.0:
		var n := _n()
		var hill_noise := n.get_noise_2d(x * 0.18 + 300.0, z * 0.18) * 0.5 + 0.5
		var land := 1.0 - smoothstep(-34.0, -14.0, TownLayout.sea_distance(x, z))
		h += smoothstep(2.0, 70.0, outside) * (7.0 + 20.0 * hill_noise) * land
	return h


## Height before building pads / sea (used to compute the pads).
static func _natural_height(x: float, z: float) -> float:
	var n := _n()
	var p := Vector2(x, z)
	var farm := maxf(absf(x), absf(z))
	var town := p.distance_to(TOWN_CENTER)
	var amp := 0.25 + smoothstep(16.0, 34.0, farm) * 0.85
	amp *= lerpf(0.25, 1.0, smoothstep(14.0, 26.0, town))
	var h := n.get_noise_2d(x, z) * amp
	var road := maxf(road_at(x, z), _grid_sample(_dirt_grid, x, z) * 0.7)
	var hills := _hills(x, z)
	h = lerpf(h, h * 0.15, road) + hills
	return h


static func height_at(x: float, z: float) -> float:
	_ensure_grids()
	var h := _natural_height(x, z)
	var p := Vector2(x, z)
	# Town square: flat plaza.
	var sq := 1.0 - smoothstep(TOWN_SQUARE_RADIUS, TOWN_SQUARE_RADIUS + 5.0, p.distance_to(TOWN_CENTER))
	if sq > 0.0:
		h = lerpf(h, _natural_height(TOWN_CENTER.x, TOWN_CENTER.y), sq)
	# v5a market plaza: flat like the square.
	var mr := TownLayout.MARKET_RECT
	if x > mr.position.x - 5.0 and x < mr.end.x + 5.0 and z > mr.position.y - 5.0 and z < mr.end.y + 5.0:
		var md := maxf(maxf(mr.position.x - x, x - mr.end.x), maxf(mr.position.y - z, z - mr.end.y))
		h = lerpf(h, _natural_height(TownLayout.MARKET_CENTER.x, TownLayout.MARKET_CENTER.y), 1.0 - smoothstep(0.0, 4.0, md))
	# Building pads.
	for i in TownLayout.BUILDINGS.size():
		var b: Dictionary = TownLayout.BUILDINGS[i]
		var c: Vector2 = b["pos"]
		if absf(c.x - x) > 15.0 or absf(c.y - z) > 15.0:
			continue
		var d := TownLayout.footprint_distance(b, p, 0.6)
		if d < 4.0:
			h = lerpf(h, float(_pad_heights[i]), 1.0 - smoothstep(0.0, 4.0, d))
	# Farm garden: flat beds.
	var gr := TownLayout.GARDEN_MAX_RECT
	if x > gr.position.x - 3.0 and x < gr.end.x + 3.0 and z > gr.position.y - 3.0 and z < gr.end.y + 3.0:
		var gd := maxf(maxf(gr.position.x - x, x - gr.end.x), maxf(gr.position.y - z, z - gr.end.y))
		var gc := gr.get_center()
		h = lerpf(h, _natural_height(gc.x, gc.y), 1.0 - smoothstep(0.0, 2.5, gd))
	# Beach + sea floor.
	var sd := TownLayout.sea_distance(x, z)
	if sd > -TownLayout.SAND_WIDTH - 8.0:
		var profile := -sd * 0.085 if sd < 0.0 else -sd * 0.3
		profile = maxf(profile, -7.0)
		var w := smoothstep(-TownLayout.SAND_WIDTH - 8.0, -TownLayout.SAND_WIDTH + 1.0, sd)
		h = lerpf(h, minf(h, profile + 0.05) if sd < -6.0 else profile, w)
	# Pond bowl.
	var pd := p.distance_to(TownLayout.POND_CENTER)
	if pd < TownLayout.POND_RADIUS + 6.0:
		var base := _natural_height(TownLayout.POND_CENTER.x, TownLayout.POND_CENTER.y)
		var bowl := -1.4 * (1.0 - smoothstep(TownLayout.POND_RADIUS - 3.5, TownLayout.POND_RADIUS + 0.6, pd))
		var flat := 1.0 - smoothstep(TownLayout.POND_RADIUS + 1.0, TownLayout.POND_RADIUS + 6.0, pd)
		h = lerpf(h, base - 0.05, flat) + bowl
	# River channel (v4): carved below a water level that only falls downstream,
	# so the river cuts through rises (hills) instead of disappearing.
	if x < -15.0 and x > -180.0 and z > -20.0:
		var info := river_info(x, z)
		var rd: float = info.x
		if rd < 14.0:
			var channel: float = info.y - 0.7 + 0.75 * smoothstep(0.0, RIVER_WATER_HALF + 0.3, rd) + maxf(rd - RIVER_WATER_HALF - 0.3, 0.0) * 0.55
			h = minf(h, channel)
	return h


static func is_river(x: float, z: float) -> bool:
	if x >= -15.0 or z <= -20.0:
		return false
	if Vector2(x, z).distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS:
		return false
	return river_info(x, z).x < RIVER_WATER_HALF - 0.4


## Water surface height of the river at (x, z) (level of the nearest point
## on the river line).
static func river_surface(x: float, z: float) -> float:
	return river_info(x, z).y


## Water level at each river polyline point: natural ground - 0.45 m, never
## rising downstream, equal to the pond surface where it crosses the pond.
static func river_levels() -> PackedFloat32Array:
	if _river_levels.is_empty():
		var pts := TownLayout.RIVER
		var pond := pond_surface()
		var lv := PackedFloat32Array()
		var prev := INF
		var past_pond := false
		for i in pts.size():
			var q: Vector2 = pts[i]
			var l := minf(_natural_height(q.x, q.y) - 0.45, prev)
			var in_pond := q.distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS
			if in_pond:
				l = pond
				past_pond = true
			elif not past_pond:
				l = maxf(l, pond + 0.02)
			else:
				l = minf(l, pond - 0.02)
			if TownLayout.sea_distance(q.x, q.y) > -TownLayout.SAND_WIDTH:
				l = minf(l, TownLayout.WATER_LEVEL + 0.05)
			lv.append(l)
			prev = l
		_river_levels = lv
	return _river_levels


## Vector2(distance to the river line, water level there).
static func river_info(x: float, z: float) -> Vector2:
	var lv := river_levels()
	var p := Vector2(x, z)
	var best := INF
	var level := 0.0
	var pts := TownLayout.RIVER
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		var d := p.distance_to(a + ab * t)
		if d < best:
			best = d
			level = lerpf(lv[i], lv[i + 1], t)
	return Vector2(best, level)


static func pond_surface() -> float:
	return _natural_height(TownLayout.POND_CENTER.x, TownLayout.POND_CENTER.y) - 0.3


## Beach sand 0..1.
static func sand_at(x: float, z: float) -> float:
	var sd := TownLayout.sea_distance(x, z)
	return smoothstep(-TownLayout.SAND_WIDTH - 1.5, -TownLayout.SAND_WIDTH + 1.5, sd)


static func is_water(x: float, z: float) -> bool:
	if TownLayout.sea_distance(x, z) > 0.4:
		return true
	if is_river(x, z):
		return true
	return Vector2(x, z).distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS - 0.8


## 0 = grass, 1 = no grass (paths, roads, town square, sand, buildings, worn patches).
static func dirt_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := maxf(_grid_sample(_dirt_grid, x, z), road_at(x, z))
	d = maxf(d, square_at(x, z))
	d = maxf(d, sand_at(x, z))
	if p.distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS + 0.5:
		d = 1.0
	if x < -15.0 and z > -20.0 and TownLayout.river_distance(p) < RIVER_WATER_HALF + 1.2:
		d = 1.0
	_n()
	var patches := smoothstep(0.42, 0.6, _noise_detail.get_noise_2d(x + 50.0, z - 20.0))
	return maxf(d, patches * 0.8)


static func square_at(x: float, z: float) -> float:
	return 1.0 - smoothstep(TOWN_SQUARE_RADIUS - 0.5, TOWN_SQUARE_RADIUS + 0.4, Vector2(x, z).distance_to(TOWN_CENTER))


## v2 API: dirt-path influence only (used by older placement code).
static func path_mask(p: Vector2) -> float:
	return maxf(_grid_sample(_dirt_grid, p.x, p.y), road_at(p.x, p.y))


static func ground_color(x: float, z: float) -> Color:
	_n()
	var v := _noise_detail.get_noise_2d(x * 0.6, z * 0.6) * 0.5 + 0.5
	var lush := Color(0.26, 0.38, 0.13)
	var light := Color(0.38, 0.47, 0.18)
	var dry := Color(0.48, 0.47, 0.24)
	var grass := lush.lerp(light, smoothstep(0.3, 0.7, v))
	grass = grass.lerp(dry, smoothstep(0.62, 0.85, _noise.get_noise_2d(x * 1.7 - 40.0, z * 1.7) * 0.5 + 0.5) * 0.7)
	var dirt := Color(0.42, 0.31, 0.2).lerp(Color(0.5, 0.38, 0.25), v)
	var square := Color(0.55, 0.5, 0.43).lerp(Color(0.47, 0.43, 0.37), v)
	var sd := TownLayout.sea_distance(x, z)
	var sand := Color(0.86, 0.77, 0.58).lerp(Color(0.8, 0.7, 0.52), v)
	var wet := Color(0.55, 0.48, 0.36)
	sand = sand.lerp(wet, smoothstep(-2.5, 0.2, sd))
	var dirt_w := maxf(_grid_sample(_dirt_grid, x, z), road_at(x, z) * 0.9)
	var patches := smoothstep(0.42, 0.6, _noise_detail.get_noise_2d(x + 50.0, z - 20.0)) * 0.8
	dirt_w = maxf(dirt_w, patches)
	var square_w := square_at(x, z) * 0.85
	var sand_w := sand_at(x, z)
	var c := grass.lerp(dirt, dirt_w).lerp(square, square_w).lerp(sand, sand_w)
	var pd := Vector2(x, z).distance_to(TownLayout.POND_CENTER)
	if pd < TownLayout.POND_RADIUS + 1.5:
		c = c.lerp(Color(0.32, 0.27, 0.2), 1.0 - smoothstep(TownLayout.POND_RADIUS - 1.0, TownLayout.POND_RADIUS + 1.5, pd))
	if sd > 0.5:
		c = Color(0.62, 0.56, 0.42).lerp(Color(0.35, 0.36, 0.3), clampf(sd / 12.0, 0.0, 1.0))
	# Alpha = how grassy the spot is (the seasonal terrain shader tints/snows by it).
	c.a = (1.0 - dirt_w) * (1.0 - square_w) * (1.0 - sand_w)
	return c


# ------------------------------------------------------------------ building
func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	collision_layer = 1
	collision_mask = 0

	var fine := MeshInstance3D.new()
	fine.name = "PlayAreaMesh"
	fine.mesh = _build_fine_mesh()
	fine.material_override = material
	add_child(fine)

	var outer := MeshInstance3D.new()
	outer.name = "OuterMesh"
	outer.mesh = _build_outer_mesh()
	outer.material_override = material
	outer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(outer)

	var shape := CollisionShape3D.new()
	shape.name = "HeightCollision"
	shape.shape = _build_heightmap()
	shape.position = Vector3(PLAY_AREA.get_center().x, 0.0, PLAY_AREA.get_center().y)
	add_child(shape)


func _outer_height(x: float, z: float) -> float:
	var gx := floorf(x / outer_cell) * outer_cell
	var gz := floorf(z / outer_cell) * outer_cell
	var tx := (x - gx) / outer_cell
	var tz := (z - gz) / outer_cell
	var h00 := height_at(gx, gz)
	var h10 := height_at(gx + outer_cell, gz)
	var h01 := height_at(gx, gz + outer_cell)
	var h11 := height_at(gx + outer_cell, gz + outer_cell)
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func _build_fine_mesh() -> ArrayMesh:
	var x0 := PLAY_AREA.position.x
	var z0 := PLAY_AREA.position.y
	var nx := int(PLAY_AREA.size.x) + 1
	var nz := int(PLAY_AREA.size.y) + 1
	var heights := PackedFloat32Array()
	heights.resize(nx * nz)
	for j in nz:
		for i in nx:
			var x := x0 + i
			var z := z0 + j
			var edge := i == 0 or j == 0 or i == nx - 1 or j == nz - 1
			heights[j * nx + i] = _outer_height(x, z) if edge else height_at(x, z)
	return _grid_mesh(heights, nx, nz, x0, z0, 1.0, Rect2())


func _build_outer_mesh() -> ArrayMesh:
	var n := int(outer_extent * 2.0 / outer_cell) + 1
	var x0 := -outer_extent
	var z0 := -outer_extent - 52.0  # multiple of outer_cell, keeps lattice aligned with PLAY_AREA
	var heights := PackedFloat32Array()
	heights.resize(n * n)
	for j in n:
		for i in n:
			heights[j * n + i] = height_at(x0 + i * outer_cell, z0 + j * outer_cell)
	return _grid_mesh(heights, n, n, x0, z0, outer_cell, PLAY_AREA)


func _grid_mesh(h: PackedFloat32Array, nx: int, nz: int, x0: float, z0: float, cell: float, hole: Rect2) -> ArrayMesh:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	verts.resize(nx * nz)
	normals.resize(nx * nz)
	colors.resize(nx * nz)
	uvs.resize(nx * nz)
	for j in nz:
		for i in nx:
			var k := j * nx + i
			var x := x0 + i * cell
			var z := z0 + j * cell
			verts[k] = Vector3(x, h[k], z)
			var hl := h[j * nx + maxi(i - 1, 0)]
			var hr := h[j * nx + mini(i + 1, nx - 1)]
			var hd := h[maxi(j - 1, 0) * nx + i]
			var hu := h[mini(j + 1, nz - 1) * nx + i]
			normals[k] = Vector3(hl - hr, 2.0 * cell, hd - hu).normalized()
			colors[k] = ground_color(x, z)
			uvs[k] = Vector2(x, z) * 0.25
	var indices := PackedInt32Array()
	for j in nz - 1:
		for i in nx - 1:
			if hole.has_area():
				var cx := x0 + (i + 0.5) * cell
				var cz := z0 + (j + 0.5) * cell
				if hole.has_point(Vector2(cx, cz)):
					continue
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			indices.append_array([a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func _build_heightmap() -> HeightMapShape3D:
	var nx := int(PLAY_AREA.size.x) + 1
	var nz := int(PLAY_AREA.size.y) + 1
	var data := PackedFloat32Array()
	data.resize(nx * nz)
	for j in nz:
		for i in nx:
			data[j * nx + i] = height_at(PLAY_AREA.position.x + i, PLAY_AREA.position.y + j)
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = data
	return shape


func _apply_style(style: TerrainStyle) -> void:
	if style == null or material == null:
		return
	if material is ShaderMaterial:
		for k in style.shader_overrides:
			(material as ShaderMaterial).set_shader_parameter(StringName(k), style.shader_overrides[k])
