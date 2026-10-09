class_name BeachBuilder
extends Node3D
## The south-east beach corner and the farm pond: animated water meshes (shore
## foam + depth baked per vertex), a wooden pier, palms, dune grass, rocks, a
## parasol, positional wave sounds along the shoreline (louder as you walk
## closer), the pond's own water sound, an invisible wall a few metres into
## the sea, and the daily shell spawner.

const PIER_START := Vector2(35.0, 21.0)
const PIER_DIR := Vector2(0.7071, 0.7071)
const PIER_LENGTH := 17.0
const PIER_WIDTH := 2.4

var water_material: ShaderMaterial
var pier_deck_height: float = 0.0
var wave_players: Array[AudioStreamPlayer3D] = []
var _body: StaticBody3D
var _static: Node3D


func _nature_path(model: String) -> String:
	var t := Modules.style("trees") as TreeStyle
	return t.model_path(model) if t else "res://assets/third_party/quaternius/nature/" + model + ".gltf"


func _apply_params(mat: ShaderMaterial, params: Dictionary) -> void:
	for k in params:
		mat.set_shader_parameter(StringName(k), params[k])


func _apply_water(style: WaterStyle) -> void:
	if style == null or water_material == null:
		return
	_apply_params(water_material, style.sea)
	for n in find_children("*", "MeshInstance3D", true, false):
		if n.name == "Pond" and n.material_override is ShaderMaterial:
			_apply_params(n.material_override, style.pond)


func _ready() -> void:
	Modules.on_swap("water", self, func(m: AssetModule) -> void: _apply_water(m as WaterStyle))
	add_to_group(&"beach")
	_body = StaticBody3D.new()
	_body.name = "BeachCollision"
	add_child(_body)
	_static = Node3D.new()
	add_child(_static)
	water_material = ShaderMaterial.new()
	var wstyle := Modules.style("water") as WaterStyle
	water_material.shader = load(wstyle.shader_path if wstyle else "res://assets/shaders/water.gdshader")
	_apply_params(water_material, wstyle.sea if wstyle else {})
	_build_sea()
	_build_pond()
	_build_pier()
	_build_palms()
	_build_dunes_and_rocks()
	_build_beach_props()
	_build_sea_wall()
	_build_audio()
	var merged := MeshMerger.merge_children(_static, self, "BeachProps")
	merged.visibility_range_end = 140.0
	add_child(merged)
	var shells := ShellSpawner.new()
	shells.name = "ShellSpawner"
	add_child(shells)


# ------------------------------------------------------------------ water
func _build_sea() -> void:
	# Fine grid near the shore + coarse grid out to the horizon.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := TownLayout.WATER_LEVEL
	_water_grid(st, Rect2(-10.0, -60.0, 170.0, 170.0), 2.0, y, true)
	# v6a: open water between the fine shore grid and the far ocean (where the
	# boats go deep-sea fishing) - coarser cells, a hair lower, no gap.
	_open_water_grid(st, Rect2(-40.0, -150.0, 300.0, 300.0), 6.0, y - 0.01, 22.0)
	var mi := MeshInstance3D.new()
	mi.name = "Sea"
	mi.mesh = st.commit()
	mi.material_override = water_material
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# Far ocean plane to the horizon (no per-vertex shore data needed).
	var far := MeshInstance3D.new()
	far.name = "OceanFar"
	var st2 := SurfaceTool.new()
	st2.begin(Mesh.PRIMITIVE_TRIANGLES)
	_water_grid(st2, Rect2(40.0, -200.0, 500.0, 600.0), 25.0, y - 0.02, false)
	far.mesh = st2.commit()
	far.material_override = water_material
	far.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(far)


func _water_grid(st: SurfaceTool, rect: Rect2, cell: float, y: float, near: bool) -> void:
	var nx := int(rect.size.x / cell)
	var nz := int(rect.size.y / cell)
	for iz in nz:
		for ix in nx:
			var x0 := rect.position.x + ix * cell
			var z0 := rect.position.y + iz * cell
			var corners: Array[Vector2] = [Vector2(x0, z0), Vector2(x0 + cell, z0), Vector2(x0 + cell, z0 + cell), Vector2(x0, z0 + cell)]
			var any_water := false
			var all_inner := true
			for c in corners:
				var sd := TownLayout.sea_distance(c.x, c.y)
				if sd > -2.5:
					any_water = true
				if sd < 30.0:
					all_inner = false
			if not any_water:
				continue
			if near and all_inner:
				continue  # deep water: the far ocean grid covers it
			if not near and not _all_beyond(corners, 26.0):
				continue
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var c := corners[idx]
				var ground := Terrain.height_at(c.x, c.y)
				var depth := clampf((y - ground) / 3.0, 0.0, 1.0)
				var foam := 1.0 - clampf((y - ground) / 0.6, 0.0, 1.0)
				if not near:
					depth = 1.0
					foam = 0.0
				st.set_color(Color(foam, depth, 0.0))
				st.set_normal(Vector3.UP)
				st.set_uv(c * 0.1)
				st.add_vertex(Vector3(c.x, y, c.y))


func _open_water_grid(st: SurfaceTool, rect: Rect2, cell: float, y: float, min_sd: float) -> void:
	var nx := int(rect.size.x / cell)
	var nz := int(rect.size.y / cell)
	for iz in nz:
		for ix in nx:
			var x0 := rect.position.x + ix * cell
			var z0 := rect.position.y + iz * cell
			var corners: Array[Vector2] = [Vector2(x0, z0), Vector2(x0 + cell, z0), Vector2(x0 + cell, z0 + cell), Vector2(x0, z0 + cell)]
			if not _all_beyond(corners, min_sd):
				continue
			for idx: int in [0, 1, 2, 0, 2, 3]:
				var c := corners[idx]
				st.set_color(Color(0.0, 1.0, 0.0))
				st.set_normal(Vector3.UP)
				st.set_uv(c * 0.1)
				st.add_vertex(Vector3(c.x, y, c.y))


func _all_beyond(corners: Array[Vector2], sd: float) -> bool:
	for c in corners:
		if TownLayout.sea_distance(c.x, c.y) < sd:
			return false
	return true


func _build_pond() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var c := TownLayout.POND_CENTER
	var y := Terrain.pond_surface()
	var r := TownLayout.POND_RADIUS + 0.6
	var rings := 6
	var seg := 36
	for ring in rings:
		for s in seg:
			var a0 := TAU * s / seg
			var a1 := TAU * (s + 1) / seg
			var r0 := r * ring / rings
			var r1 := r * (ring + 1) / rings
			var pts: Array[Vector2] = [c + Vector2(cos(a0), sin(a0)) * r0, c + Vector2(cos(a0), sin(a0)) * r1,
					c + Vector2(cos(a1), sin(a1)) * r1, c + Vector2(cos(a1), sin(a1)) * r0]
			for idx: int in [0, 2, 1, 0, 3, 2]:
				var p := pts[idx]
				var ground := Terrain.height_at(p.x, p.y)
				st.set_color(Color(1.0 - clampf((y - ground) / 0.4, 0.0, 1.0), clampf((y - ground) / 1.6, 0.0, 1.0) * 0.6, 0.0))
				st.set_normal(Vector3.UP)
				st.add_vertex(Vector3(p.x, y, p.y))
	var mi := MeshInstance3D.new()
	mi.name = "Pond"
	mi.mesh = st.commit()
	var mat := water_material.duplicate() as ShaderMaterial
	_apply_params(mat, (Modules.style("water") as WaterStyle).pond if Modules.style("water") else {})
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# A few reeds + lily pads.
	var reed := ProceduralProp.color_material(Color(0.35, 0.45, 0.2), 0.9)
	var pad := ProceduralProp.color_material(Color(0.2, 0.45, 0.2), 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 40:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * (TownLayout.POND_RADIUS + rng.randf_range(-0.9, 0.4))
		var g := Terrain.height_at(p.x, p.y)
		_box(Vector3(0.03, rng.randf_range(0.7, 1.3), 0.03), Vector3(p.x, maxf(g, y) + 0.4, p.y), reed, rng.randf() * TAU, Vector3(rng.randf_range(-0.15, 0.15), 0, rng.randf_range(-0.15, 0.15)))
	for k in 9:
		var a := rng.randf() * TAU
		var p := c + Vector2(cos(a), sin(a)) * rng.randf_range(1.5, TownLayout.POND_RADIUS - 2.0)
		_cyl(0.35, 0.35, 0.02, Vector3(p.x, y + 0.02, p.y), pad)


# ------------------------------------------------------------------ pier
func _build_pier() -> void:
	var wood := ProceduralProp.color_material(Color(0.52, 0.38, 0.25), 0.85)
	var dark := ProceduralProp.color_material(Color(0.33, 0.24, 0.16), 0.9)
	var yaw := atan2(PIER_DIR.x, PIER_DIR.y)
	var start_ground := Terrain.height_at(PIER_START.x, PIER_START.y)
	pier_deck_height = maxf(start_ground + 0.35, TownLayout.WATER_LEVEL + 0.9)
	var right := Vector2(PIER_DIR.y, -PIER_DIR.x)
	var plank := 0.0
	while plank < PIER_LENGTH:
		var c := PIER_START + PIER_DIR * (plank + 0.15)
		_box(Vector3(PIER_WIDTH, 0.06, 0.26), Vector3(c.x, pier_deck_height, c.y), wood if int(plank / 0.3) % 3 != 0 else dark, yaw)
		plank += 0.3
	for k in 6:
		var along := 1.0 + k * (PIER_LENGTH - 1.5) / 5.0
		for sgn: float in [-1.0, 1.0]:
			var c := PIER_START + PIER_DIR * along + right * sgn * (PIER_WIDTH * 0.5 - 0.1)
			var g := Terrain.height_at(c.x, c.y)
			var h := pier_deck_height - g + 0.9
			_cyl(0.11, 0.12, h, Vector3(c.x, g + h * 0.5 - 0.3, c.y), dark)
	# Rails on both sides.
	for sgn: float in [-1.0, 1.0]:
		var c := PIER_START + PIER_DIR * (PIER_LENGTH * 0.5 + 0.5) + right * sgn * (PIER_WIDTH * 0.5 - 0.1)
		_box(Vector3(0.08, 0.08, PIER_LENGTH - 1.0), Vector3(c.x, pier_deck_height + 0.85, c.y), dark, yaw)
		_collider(Vector3(0.1, 1.2, PIER_LENGTH - 1.0), Vector3(c.x, pier_deck_height + 0.6, c.y), yaw)
	# Deck collision + a short ramp up from the sand.
	var mid := PIER_START + PIER_DIR * (PIER_LENGTH * 0.5)
	_collider(Vector3(PIER_WIDTH, 0.2, PIER_LENGTH), Vector3(mid.x, pier_deck_height - 0.1, mid.y), yaw)
	var ramp_len := 2.2
	var ramp_low := PIER_START - PIER_DIR * ramp_len
	var low_y := Terrain.height_at(ramp_low.x, ramp_low.y)
	var rise := pier_deck_height - low_y
	var rc := (PIER_START + ramp_low) * 0.5
	var angle := atan2(rise, ramp_len)
	_box(Vector3(PIER_WIDTH, 0.06, sqrt(ramp_len * ramp_len + rise * rise)), Vector3(rc.x, (pier_deck_height + low_y) * 0.5, rc.y), wood, yaw, Vector3(-angle, 0, 0))
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(PIER_WIDTH, 0.12, sqrt(ramp_len * ramp_len + rise * rise))
	cs.shape = bs
	cs.position = Vector3(rc.x, (pier_deck_height + low_y) * 0.5 - 0.06, rc.y)
	cs.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -angle)
	_body.add_child(cs)
	# Fishing sign + a bench at the end of the pier.
	var end := PIER_START + PIER_DIR * (PIER_LENGTH - 1.2)
	var l := Label3D.new()
	l.text = "Fishing Pier"
	l.font_size = 72
	l.pixel_size = 0.006
	l.outline_size = 10
	l.position = Vector3(PIER_START.x, pier_deck_height + 2.4, PIER_START.y) - Vector3(PIER_DIR.x, 0, PIER_DIR.y) * 1.2
	l.rotation.y = yaw + PI
	add_child(l)
	_box(Vector3(0.1, 2.4, 0.1), Vector3(PIER_START.x - right.x * 1.3 - PIER_DIR.x * 1.2, pier_deck_height + 1.0, PIER_START.y - right.y * 1.3 - PIER_DIR.y * 1.2), dark, yaw)
	_box(Vector3(0.1, 2.4, 0.1), Vector3(PIER_START.x + right.x * 1.3 - PIER_DIR.x * 1.2, pier_deck_height + 1.0, PIER_START.y + right.y * 1.3 - PIER_DIR.y * 1.2), dark, yaw)
	_box(Vector3(2.8, 0.5, 0.06), Vector3(PIER_START.x - PIER_DIR.x * 1.25, pier_deck_height + 2.4, PIER_START.y - PIER_DIR.y * 1.25), wood, yaw)
	var marker := Marker3D.new()
	marker.name = "PierEnd"
	marker.position = Vector3(end.x, pier_deck_height, end.y)
	add_child(marker)


## Is (x, z) on the pier deck?
static func on_pier(x: float, z: float) -> bool:
	var d := Vector2(x, z) - PIER_START
	var along := d.dot(PIER_DIR)
	var across := absf(d.dot(Vector2(PIER_DIR.y, -PIER_DIR.x)))
	return along > -0.5 and along < PIER_LENGTH and across < PIER_WIDTH * 0.5 + 0.2


# ------------------------------------------------------------------ palms, dunes, props
func _sand_point(rng: RandomNumberGenerator, sd_min: float, sd_max: float) -> Vector2:
	for attempt in 60:
		var p := Vector2(rng.randf_range(10.0, 82.0), rng.randf_range(-30.0, 42.0))
		var sd := TownLayout.sea_distance(p.x, p.y)
		if sd > sd_min and sd < sd_max and Terrain.PLAY_AREA.has_point(p) and not on_pier(p.x, p.y) \
				and Terrain.road_at(p.x, p.y) < 0.05 and p.distance_to(PIER_START) > 3.5:
			return p
	return Vector2.INF


func _build_palms() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var bark := ProceduralProp.color_material(Color(0.55, 0.43, 0.3), 0.9)
	var ring := ProceduralProp.color_material(Color(0.45, 0.34, 0.23), 0.9)
	var leaf := ProceduralProp.color_material(Color(0.25, 0.5, 0.18), 0.8)
	leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
	var coconut := ProceduralProp.color_material(Color(0.35, 0.25, 0.15), 0.7)
	for k in 14:
		var p := _sand_point(rng, -12.0, -5.0)
		if p == Vector2.INF:
			continue
		var base := Vector3(p.x, Terrain.height_at(p.x, p.y) - 0.1, p.y)
		var lean := Vector3(rng.randf_range(-1, 1), 0, rng.randf_range(-1, 1)).normalized() * rng.randf_range(0.08, 0.2)
		var height := rng.randf_range(5.0, 7.5)
		var segs := 9
		var pos := base
		var dir := (Vector3.UP + lean).normalized()
		for s in segs:
			var seg_len := height / segs
			var mid := pos + dir * seg_len * 0.5
			var r := lerpf(0.22, 0.14, float(s) / segs)
			var mi := _cyl(r * 0.92, r, seg_len, mid, bark if s % 2 == 0 else ring)
			mi.basis = Basis(_rot_between(Vector3.UP, dir))
			pos += dir * seg_len
			dir = (dir + lean * 0.35).normalized()
		# Fronds: drooping two-segment leaves.
		var crown := pos
		for f in 9:
			var a := TAU * f / 9.0 + rng.randf() * 0.3
			var out := Vector3(cos(a), 0, sin(a))
			var p1 := crown + out * 1.1 + Vector3(0, 0.35, 0)
			var p2 := crown + out * 2.4 + Vector3(0, -0.45, 0)
			_frond(crown, p1, 0.55, leaf)
			_frond(p1, p2, 0.45, leaf)
		for c in 3:
			var a := rng.randf() * TAU
			_sphere(0.14, crown + Vector3(cos(a) * 0.22, -0.2, sin(a) * 0.22), coconut)
		_collider(Vector3(0.4, 3.0, 0.4), base + Vector3(0, 1.5, 0))


func _frond(a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var d := b - a
	var mi := _box(Vector3(width, 0.02, d.length()), (a + b) * 0.5, mat)
	mi.basis = Basis.looking_at(d.normalized(), Vector3.UP).scaled(Vector3.ONE)
	mi.scale = Vector3.ONE


static func _rot_between(a: Vector3, b: Vector3) -> Quaternion:
	return Quaternion(a.normalized(), b.normalized())


func _build_dunes_and_rocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	var grass_scene := load(_nature_path("Grass_Wispy_Tall")) as PackedScene
	var rock_scenes: Array[PackedScene] = [load(_nature_path("Rock_Medium_1")), load(_nature_path("Rock_Medium_2")), load(_nature_path("Rock_Medium_3"))]
	var dune_tint := ProceduralProp.color_material(Color(0.68, 0.66, 0.42), 0.9)
	for k in 46:
		var p := _sand_point(rng, -14.5, -7.5)
		if p == Vector2.INF:
			continue
		var g := grass_scene.instantiate() as Node3D
		g.position = Vector3(p.x, Terrain.height_at(p.x, p.y) - 0.05, p.y)
		g.rotation.y = rng.randf() * TAU
		g.scale = Vector3.ONE * rng.randf_range(0.6, 0.95)
		for mi in g.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = dune_tint
		_static.add_child(g)
	for k in 12:
		var p := _sand_point(rng, -6.0, 3.0)
		if p == Vector2.INF:
			continue
		var r := rock_scenes[k % 3].instantiate() as Node3D
		var s := rng.randf_range(0.25, 0.6)
		r.position = Vector3(p.x, Terrain.height_at(p.x, p.y) - 0.25 * s, p.y)
		r.rotation.y = rng.randf() * TAU
		r.scale = Vector3.ONE * s
		_static.add_child(r)
		_collider(Vector3(2.4, 1.6, 2.4) * s, r.position + Vector3(0, 0.6 * s, 0))


func _build_beach_props() -> void:
	# Parasol + two towels, a lifebuoy post and a little boat on the sand.
	var spot := Vector2(44.0, 6.0)
	var g := Terrain.height_at(spot.x, spot.y)
	var pole := ProceduralProp.color_material(Color(0.9, 0.9, 0.88), 0.5)
	_cyl(0.035, 0.035, 2.4, Vector3(spot.x, g + 1.2, spot.y), pole)
	for k in 8:
		var a := TAU * k / 8.0
		var col := Color(0.9, 0.25, 0.2) if k % 2 == 0 else Color(0.97, 0.95, 0.9)
		var mi := _box(Vector3(0.9, 0.03, 1.15), Vector3(spot.x + cos(a) * 0.5, g + 2.3, spot.y + sin(a) * 0.5), ProceduralProp.color_material(col, 0.8, false), -a + PI * 0.5, Vector3(0.35, 0, 0))
		mi.rotation = Vector3(0, -a + PI * 0.5, 0)
		mi.rotate_object_local(Vector3.RIGHT, -0.32)
	var towel_cols := [Color(0.25, 0.5, 0.85), Color(0.95, 0.75, 0.2)]
	for k in 2:
		var tp := spot + Vector2(1.0 + k * 1.3, 0.9 - k * 0.4)
		_box(Vector3(0.8, 0.02, 1.8), Vector3(tp.x, Terrain.height_at(tp.x, tp.y) + 0.02, tp.y), ProceduralProp.color_material(towel_cols[k], 0.9), 0.6)
	# Rowing boat pulled up on the sand.
	var bp := Vector2(53.0, 1.0)
	var bg := Terrain.height_at(bp.x, bp.y)
	var hull := ProceduralProp.color_material(Color(0.25, 0.42, 0.6), 0.6)
	var inside := ProceduralProp.color_material(Color(0.6, 0.45, 0.3), 0.8)
	var by := 0.8
	_box(Vector3(1.3, 0.5, 3.6), Vector3(bp.x, bg + 0.3, bp.y), hull, by)
	_box(Vector3(1.1, 0.06, 3.3), Vector3(bp.x, bg + 0.52, bp.y), inside, by)
	_box(Vector3(1.2, 0.05, 0.25), Vector3(bp.x, bg + 0.6, bp.y), inside, by)
	_collider(Vector3(1.3, 0.6, 3.6), Vector3(bp.x, bg + 0.3, bp.y), by)


func _build_sea_wall() -> void:
	# Invisible wall where the water gets deep (~5 m out) so you can wade but not swim away.
	var x := -10.0
	while x < 160.0:
		# Solve x + z = SHORE_SUM + offset for z; the wobble is small enough to ignore with a 7 m offset.
		var z0 := TownLayout.SHORE_SUM + 8.5 - x
		var z1 := TownLayout.SHORE_SUM + 8.5 - (x + 4.0)
		var mid := Vector3(x + 2.0, 0.0, (z0 + z1) * 0.5)
		if mid.z > Terrain.PLAY_AREA.end.y + 5.0 or mid.z < Terrain.PLAY_AREA.position.y - 5.0:
			x += 4.0
			continue
		_collider(Vector3(5.8, 8.0, 0.6), mid, PI * 0.25)
		x += 4.0
	# The pier pokes past that line: block its far end with the rail + this.
	var end := PIER_START + PIER_DIR * (PIER_LENGTH + 0.3)
	_collider(Vector3(PIER_WIDTH + 0.4, 2.0, 0.3), Vector3(end.x, pier_deck_height + 0.6, end.y), atan2(PIER_DIR.x, PIER_DIR.y))


func _build_audio() -> void:
	var waves := load("res://assets/audio/ambience/waves_loop.ogg") as AudioStreamOggVorbis
	if waves:
		waves.loop = true
	# Emitters spread along the shoreline (positional: louder as you approach).
	var t := -24.0
	var k := 0
	while t <= 30.0:
		var p := Vector2(37.0, 25.0) + Vector2(0.7071, -0.7071) * t
		var sp := AudioStreamPlayer3D.new()
		sp.name = "WaveSound%d" % k
		sp.stream = waves
		sp.unit_size = 9.0
		sp.max_distance = 70.0
		sp.volume_db = -4.0
		sp.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		sp.position = Vector3(p.x, 0.5, p.y)
		sp.autoplay = true
		sp.add_to_group(&"wave_sounds")
		add_child(sp)
		wave_players.append(sp)
		# Offset the loops so the emitters don't phase together.
		sp.finished.connect(sp.play)
		t += 18.0
		k += 1
	var pond := load("res://assets/audio/ambience/pond_loop.ogg") as AudioStreamOggVorbis
	if pond:
		pond.loop = true
	var ps := AudioStreamPlayer3D.new()
	ps.name = "PondSound"
	ps.stream = pond
	ps.unit_size = 4.0
	ps.max_distance = 30.0
	ps.volume_db = -10.0
	ps.position = Vector3(TownLayout.POND_CENTER.x, 0.3, TownLayout.POND_CENTER.y)
	ps.autoplay = true
	add_child(ps)


func _process(_delta: float) -> void:
	# Night darkens the water a bit (the sky reflection is faked).
	var cycle := get_tree().get_first_node_in_group(&"day_night") as Node
	if cycle and water_material:
		water_material.set_shader_parameter(&"night", float(cycle.get("night_lights")) * 0.8)


# ------------------------------------------------------------------ helpers
func _box(size: Vector3, pos: Vector3, mat: Material, yaw: float = 0.0, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.basis = Basis(Vector3.UP, yaw) * Basis.from_euler(rot)
	_static.add_child(mi)
	return mi


func _cyl(top: float, bottom: float, height: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = 8
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	_static.add_child(mi)
	return mi


func _sphere(radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 8
	m.rings = 4
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	_static.add_child(mi)
	return mi


func _collider(size: Vector3, pos: Vector3, yaw: float = 0.0) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	cs.rotation.y = yaw
	_body.add_child(cs)
