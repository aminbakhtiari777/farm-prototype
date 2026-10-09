class_name NatureScatter
extends Node3D
## Scatters the countryside: CC0 Quaternius trees (broadleaf + pines + a dead
## tree), bushes, ferns, flower clumps and rocks, plus wind-blown grass blades
## and small wildflowers. Everything is MultiMesh, split into chunks with
## visibility ranges so only nearby grass is drawn and far tree chunks drop
## out, which keeps the web build's draw calls and triangle counts down.
## A forest edge of trees rings the play area (except on the sea side).
##
## Seasons: apply_season() tints the shared leaf materials (fresh green,
## deep green, orange/red) and hides broadleaf leaves in winter (bare
## branches); pines keep their needles with a frosty tint. Grass/flower counts
## shrink in autumn/winter (set_grass_fraction / set_flower_fraction).

## Model paths / lists come from AssetRegistry (modules/trees, rocks, plants).
const TREE_CHUNK := 40.0
const GRASS_CHUNK := 20.0

@export var random_seed: int = 42
@export var tree_count: int = 190
@export var edge_tree_count: int = 260
@export var meadow_size: Vector2 = Vector2(27.0, 27.0)
@export var grass_count: int = 42000  ## inside the fenced meadow
@export var outer_grass_count: int = 48000  ## the rest of the play area
@export var flower_count: int = 900
@export var grass_view_distance: float = 55.0
@export var tree_view_distance: float = 150.0
## Areas where nothing should grow (x, z, width, depth), e.g. the crop plot.
@export var clear_areas: Array[Rect2] = []
@export_group("Materials")
@export var grass_material: Material
@export var flower_material: Material

var leaf_material: StandardMaterial3D
var pine_material: StandardMaterial3D
var bark_material: StandardMaterial3D
var tree_positions: PackedVector3Array = PackedVector3Array()
var _models: Dictionary = {}  ## name -> ArrayMesh
var _leaf_nodes: Array[MultiMeshInstance3D] = []  ## broadleaf (with leaves) instances
var _bare_nodes: Array[MultiMeshInstance3D] = []  ## same trees without leaves (winter)
var _grass: Array[MultiMeshInstance3D] = []
var _flowers: Array[MultiMeshInstance3D] = []
var _full_counts: Dictionary = {}  ## MultiMeshInstance3D -> instance count
var _body: StaticBody3D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	var scale_setting: float = ProjectSettings.get_setting("farm/nature_density", 1.0)
	grass_count = int(grass_count * scale_setting)
	outer_grass_count = int(outer_grass_count * scale_setting)
	flower_count = int(flower_count * clampf(scale_setting * 1.5, 0.3, 1.0))
	_rng.seed = random_seed
	_body = StaticBody3D.new()
	_body.name = "TreeCollision"
	add_child(_body)
	_build_all()
	for t: String in ["trees", "rocks", "plants"]:
		Modules.on_swap(t, self, func(_m: AssetModule) -> void: _rebuild_nature())


func _build_all() -> void:
	_build_trees()
	_build_ground_cover()
	var plant := Modules.style("plants") as PlantStyle
	var dens := float(plant.grass_density) if plant else 1.0
	_build_grass("MeadowGrass", int(grass_count * dens), Rect2(-meadow_size * 0.5, meadow_size), Rect2(), 1.0)
	_build_grass("FieldGrass", int(outer_grass_count * dens), Terrain.PLAY_AREA, Rect2(-meadow_size * 0.5, meadow_size).grow(0.5), 0.9)
	_build_flowers()


## Live style swap: drop everything and scatter again with the new modules.
func _rebuild_nature() -> void:
	for c in get_children():
		if c != _body:
			remove_child(c)
			c.queue_free()
	for c in _body.get_children():
		c.queue_free()
	_leaf_nodes.clear()
	_bare_nodes.clear()
	_grass.clear()
	_flowers.clear()
	_full_counts.clear()
	_models.clear()
	tree_positions.clear()
	_rng.seed = random_seed
	_build_all()
	apply_season(TimeManager.season_id())


# ------------------------------------------------------------------ assets
func _model(model_name: String) -> ArrayMesh:
	if _models.has(model_name):
		return _models[model_name]
	var tstyle := Modules.style("trees") as TreeStyle
	var scene := load(tstyle.model_path(model_name) if tstyle else "res://assets/third_party/quaternius/nature/" + model_name + ".gltf") as PackedScene
	var root := scene.instantiate() as Node3D
	var out := ArrayMesh.new()
	for mi_node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := mi_node as MeshInstance3D
		var xf := MeshMerger._relative_xform(mi, root)
		for s in mi.mesh.get_surface_count():
			var st := SurfaceTool.new()
			st.append_from(mi.mesh, s, xf)
			var mat := mi.get_active_material(s)
			out = st.commit(out)
			out.surface_set_material(out.get_surface_count() - 1, _shared_material(mat))
	root.free()
	_models[model_name] = out
	return out


## Bark/leaf materials are shared across all models so seasons can tint them in one place.
func _shared_material(mat: Material) -> Material:
	var std := mat as StandardMaterial3D
	if std == null:
		return mat
	var tex_path := std.albedo_texture.resource_path if std.albedo_texture else ""
	if tex_path.contains("Leaves_NormalTree") or tex_path.contains("Leaves_TwistedTree"):
		if leaf_material == null:
			leaf_material = std.duplicate() as StandardMaterial3D
			leaf_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return leaf_material
	if tex_path.contains("Leaf_Pine"):
		if pine_material == null:
			pine_material = std.duplicate() as StandardMaterial3D
			pine_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		return pine_material
	if tex_path.contains("Bark_NormalTree"):
		if bark_material == null:
			bark_material = std.duplicate() as StandardMaterial3D
			bark_material.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
			bark_material.cull_mode = BaseMaterial3D.CULL_BACK
		return bark_material
	if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and (tex_path.contains("Rocks") or tex_path.contains("Bark_DeadTree")):
		var opaque := std.duplicate() as StandardMaterial3D
		opaque.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		return opaque
	return std


## Copy of a tree mesh without its leaf surface (winter: bare branches).
func _bare(model_name: String) -> ArrayMesh:
	var key := model_name + "#bare"
	if _models.has(key):
		return _models[key]
	var full := _model(model_name)
	var out := ArrayMesh.new()
	for s in full.get_surface_count():
		if full.surface_get_material(s) == leaf_material:
			continue
		var st := SurfaceTool.new()
		st.append_from(full, s, Transform3D.IDENTITY)
		out = st.commit(out)
		out.surface_set_material(out.get_surface_count() - 1, full.surface_get_material(s))
	_models[key] = out
	return out


# ------------------------------------------------------------------ placement rules
func _is_clear(p: Vector2) -> bool:
	for r in clear_areas:
		if r.has_point(p):
			return true
	return false


func _blocked(p: Vector2, margin: float) -> bool:
	if _is_clear(p):
		return true
	if Terrain.road_at(p.x, p.y) > 0.02 or Terrain.dirt_at(p.x, p.y) > 0.5:
		return true
	if TownLayout.MARKET_RECT.grow(margin + 1.5).has_point(p):
		return true  # v5a market plaza
	if p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + margin + 2.0:
		return true
	if TownLayout.sea_distance(p.x, p.y) > -TownLayout.SAND_WIDTH - 1.0:
		return true
	if p.distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS + margin:
		return true
	for b in TownLayout.BUILDINGS:
		if (b["pos"] as Vector2).distance_to(p) < 16.0 and TownLayout.footprint_distance(b, p, margin) < 0.0:
			return true
	# Yards in front of houses stay open.
	for b in TownLayout.BUILDINGS:
		var d := TownLayout.door_point(b, 2.5)
		if Vector2(d.x, d.z).distance_to(p) < margin + 3.0:
			return true
	return false


func _spacing_ok(p: Vector2, min_dist: float) -> bool:
	for t in tree_positions:
		if Vector2(t.x, t.z).distance_to(p) < min_dist:
			return false
	return true


# ------------------------------------------------------------------ trees
func _build_trees() -> void:
	var style := Modules.style("trees") as TreeStyle
	if style == null:
		push_warning("NatureScatter: no 'trees' module registered")
		return
	var groups: Dictionary = {}  ## "model|chunk|edge" -> Array[Transform3D]
	var area := Terrain.PLAY_AREA
	var noise := FastNoiseLite.new()
	noise.seed = random_seed
	noise.frequency = 0.025
	# Inside the play area: groves where the noise is high, scattered elsewhere.
	var placed := 0
	var attempts := 0
	while placed < tree_count and attempts < tree_count * 40:
		attempts += 1
		var p := Vector2(_rng.randf_range(area.position.x + 2, area.end.x - 2), _rng.randf_range(area.position.y + 2, area.end.y - 2))
		var density := noise.get_noise_2d(p.x, p.y) * 0.5 + 0.5
		if _rng.randf() > density * density * 1.6 + 0.08:
			continue
		# Keep the farm meadow fairly open.
		if absf(p.x) < 17.0 and absf(p.y) < 17.0:
			continue
		if _blocked(p, 2.8) or not _spacing_ok(p, 5.0):
			continue
		var pf := style.pine_fraction
		var pine := _rng.randf() < (maxf(pf, 0.55) if p.y < -95.0 or p.x < -50.0 else pf)
		var model: String = style.pines[_rng.randi() % style.pines.size()] if pine else style.broadleaf[_rng.randi() % style.broadleaf.size()]
		if style.dead_tree != "" and _rng.randf() < 0.025:
			model = style.dead_tree
		_add_tree(groups, model, p, _rng.randf_range(style.scale_range.x, style.scale_range.y), false)
		placed += 1
	# Street trees on the residential streets.
	for road in TownLayout.ROADS:
		if road["name"] not in ["Maple St", "Oak Ave", "Pine Ln"]:
			continue
		var pts: Array = road["points"]
		var a: Vector2 = pts[0]
		var b: Vector2 = pts[pts.size() - 1]
		var dir := (b - a).normalized()
		var nrm := Vector2(-dir.y, dir.x)
		var along := 9.0
		while along < a.distance_to(b) - 4.0:
			for sgn: float in [-1.0, 1.0]:
				var p := a + dir * along + nrm * sgn * (float(road["half"]) + TownBuilder.SIDEWALK_W + 1.6)
				if not _blocked_street_tree(p) and _spacing_ok(p, 6.0):
					_add_tree(groups, style.broadleaf[(int(along / 13.0)) % style.broadleaf.size()], p, 0.7, false)
			along += 13.0
	# Forest edge outside the play area (no collision; the world walls stop you first).
	placed = 0
	attempts = 0
	var outer := area.grow(26.0)
	while placed < edge_tree_count and attempts < edge_tree_count * 30:
		attempts += 1
		var p := Vector2(_rng.randf_range(outer.position.x, outer.end.x), _rng.randf_range(outer.position.y, outer.end.y))
		if area.grow(3.0).has_point(p):
			continue
		if TownLayout.sea_distance(p.x, p.y) > -TownLayout.SAND_WIDTH - 2.0:
			continue
		if TownLayout.river_distance(p) < TownLayout.RIVER_HALF + 3.0 or not _spacing_ok(p, 4.2):
			continue
		_add_tree(groups, style.edge_models[_rng.randi() % style.edge_models.size()], p, _rng.randf_range(0.9, 1.3), true)
		placed += 1
	for key: String in groups:
		var parts := key.split("|")
		var model := parts[0]
		var edge := parts[2] == "1"
		var xforms: Array = groups[key]
		var mmi := _multimesh(key.replace("|", "_"), _model(model), xforms, tree_view_distance if not edge else tree_view_distance + 60.0)
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if not edge else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		if model in style.broadleaf:
			_leaf_nodes.append(mmi)
			var bare := _multimesh("Bare_" + key.replace("|", "_"), _bare(model), xforms, mmi.visibility_range_end)
			bare.cast_shadow = mmi.cast_shadow
			bare.visible = false
			add_child(bare)
			_bare_nodes.append(bare)


func _blocked_street_tree(p: Vector2) -> bool:
	if Terrain.road_at(p.x, p.y) > 0.9:
		return true
	for b in TownLayout.BUILDINGS:
		if (b["pos"] as Vector2).distance_to(p) < 16.0 and TownLayout.footprint_distance(b, p, 1.5) < 0.0:
			return true
		var d := TownLayout.door_point(b, 2.0)
		if Vector2(d.x, d.z).distance_to(p) < 4.0:
			return true
	return p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 4.0 or TownLayout.MARKET_RECT.grow(2.5).has_point(p)


func _add_tree(groups: Dictionary, model: String, p: Vector2, s: float, edge: bool) -> void:
	var y := Terrain.height_at(p.x, p.y) - 0.1
	var xf_basis := Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s)
	var chunk := Vector2i(floori(p.x / TREE_CHUNK), floori(p.y / TREE_CHUNK))
	var key := "%s|%d,%d|%d" % [model, chunk.x, chunk.y, 1 if edge else 0]
	if not groups.has(key):
		groups[key] = []
	(groups[key] as Array).append(Transform3D(xf_basis, Vector3(p.x, y, p.y)))
	tree_positions.append(Vector3(p.x, y, p.y))
	if not edge:
		var shape := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.32 * s
		cyl.height = 3.0
		shape.shape = cyl
		shape.position = Vector3(p.x, y + 1.5, p.y)
		_body.add_child(shape)


func _multimesh(node_name: String, mesh: Mesh, xforms: Array, view_distance: float) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.visibility_range_end = view_distance
	mmi.visibility_range_end_margin = 12.0
	mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	return mmi


# ------------------------------------------------------------------ bushes, rocks, flowers
func _build_ground_cover() -> void:
	var plant := Modules.style("plants") as PlantStyle
	var rock := Modules.style("rocks") as RockStyle
	var kinds: Array = []
	if plant:
		kinds.append_array(plant.ground_cover)
	if rock:
		kinds.append_array(rock.kinds)
	var area := Terrain.PLAY_AREA
	for k in kinds:
		var model: String = k[0]
		var count: int = k[1]
		var groups: Dictionary = {}
		var placed := 0
		var attempts := 0
		while placed < count and attempts < count * 30:
			attempts += 1
			var p := Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
			if _blocked(p, float(k[4])):
				continue
			if model.begins_with("Flower") and absf(p.x) < 14.0 and absf(p.y) < 14.0 and _rng.randf() < 0.5:
				continue
			# Bushes and ferns like to sit near trees.
			if (model.begins_with("Bush") or model == "Fern_1") and _rng.randf() < 0.6 and not tree_positions.is_empty():
				var t := tree_positions[_rng.randi() % tree_positions.size()]
				p = Vector2(t.x, t.z) + Vector2.from_angle(_rng.randf() * TAU) * _rng.randf_range(2.5, 4.5)
				if _blocked(p, 0.8) or not area.has_point(p):
					continue
			var s := _rng.randf_range(float(k[2]), float(k[3]))
			var y := Terrain.height_at(p.x, p.y) - (0.15 * s if model.begins_with("Rock") else 0.02)
			var chunk := Vector2i(floori(p.x / TREE_CHUNK), floori(p.y / TREE_CHUNK))
			if not groups.has(chunk):
				groups[chunk] = []
			(groups[chunk] as Array).append(Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3.ONE * s), Vector3(p.x, y, p.y)))
			placed += 1
		for chunk: Vector2i in groups:
			var mmi := _multimesh("%s_%d_%d" % [model, chunk.x, chunk.y], _model(model), groups[chunk], 70.0 if not model.begins_with("Rock") else 110.0)
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if model.begins_with("Flower") or model == "Fern_1" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			add_child(mmi)
			if model.begins_with("Flower"):
				_flowers.append(mmi)
				_full_counts[mmi] = mmi.multimesh.instance_count


# ------------------------------------------------------------------ grass
func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var w := 0.011
	var h := 0.2
	var verts: Array[Vector3] = [
		Vector3(-w, 0, 0), Vector3(w, 0, 0),
		Vector3(-w * 0.7, h * 0.55, 0.02), Vector3(w * 0.7, h * 0.55, 0.02),
		Vector3(0, h, 0.06),
	]
	var cols: Array[Color] = [
		Color(0.12, 0.19, 0.06), Color(0.12, 0.19, 0.06),
		Color(0.26, 0.38, 0.12), Color(0.26, 0.38, 0.12),
		Color(0.44, 0.52, 0.22),
	]
	for idx: int in [0, 1, 2, 1, 3, 2, 2, 3, 4]:
		st.set_color(cols[idx])
		st.set_normal(Vector3.UP)
		st.add_vertex(verts[idx])
	return st.commit()


func _build_grass(prefix: String, count: int, region: Rect2, exclude: Rect2, size_scale: float) -> void:
	if count <= 0:
		return
	var blade := _blade_mesh()
	var chunks: Dictionary = {}  ## Vector2i -> [transforms, colors]
	var placed := 0
	var attempts := 0
	while placed < count and attempts < count * 3:
		attempts += 1
		var p := Vector2(_rng.randf_range(region.position.x, region.end.x), _rng.randf_range(region.position.y, region.end.y))
		if exclude.has_area() and exclude.has_point(p):
			continue
		if _is_clear(p) or Terrain.dirt_at(p.x, p.y) > 0.35:
			continue
		if p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 1.0 or TownLayout.MARKET_RECT.grow(1.0).has_point(p):
			continue
		var near_building := false
		for b in TownLayout.BUILDINGS:
			if (b["pos"] as Vector2).distance_to(p) < 9.0 and TownLayout.footprint_distance(b, p, 0.3) < 0.0:
				near_building = true
				break
		if near_building:
			continue
		var s := _rng.randf_range(0.55, 1.35) * size_scale
		var blade_basis := Basis(Vector3.UP, _rng.randf() * TAU)
		blade_basis = blade_basis.rotated(Vector3.RIGHT, _rng.randf_range(-0.25, 0.25)).scaled(Vector3(s, s * _rng.randf_range(0.7, 1.3), s))
		var key := Vector2i(floori(p.x / GRASS_CHUNK), floori(p.y / GRASS_CHUNK))
		if not chunks.has(key):
			chunks[key] = [[], []]
		(chunks[key][0] as Array).append(Transform3D(blade_basis, Vector3(p.x, Terrain.height_at(p.x, p.y) - 0.01, p.y)))
		var tint := _rng.randf_range(0.75, 1.05)
		var dry := _rng.randf() < 0.12
		(chunks[key][1] as Array).append(Color(tint * (1.35 if dry else _rng.randf_range(0.9, 1.05)), tint, tint * (0.7 if dry else 0.95)))
		placed += 1
	for key: Vector2i in chunks:
		var xforms: Array = chunks[key][0]
		var colors: Array = chunks[key][1]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = blade
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, colors[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "%s_%d_%d" % [prefix, key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = grass_material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = grass_view_distance
		mmi.visibility_range_end_margin = 8.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		add_child(mmi)
		_grass.append(mmi)
		_full_counts[mmi] = xforms.size()


func _build_flowers() -> void:
	if flower_count <= 0:
		return
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.05
	mesh.radial_segments = 6
	mesh.rings = 3
	var plant := Modules.style("plants") as PlantStyle
	var palette: Array[Color] = [Color(0.97, 0.95, 0.9), Color(0.98, 0.85, 0.3)]
	if plant and not plant.flower_colors.is_empty():
		palette.clear()
		for c in plant.flower_colors:
			palette.append(c)
	var chunks: Dictionary = {}
	var placed := 0
	var attempts := 0
	var area := Terrain.PLAY_AREA
	while placed < flower_count and attempts < flower_count * 10:
		attempts += 1
		var meadow := _rng.randf() < 0.45
		var p: Vector2
		if meadow:
			p = Vector2(_rng.randf_range(-13.0, 13.0), _rng.randf_range(-13.0, 13.0))
		else:
			p = Vector2(_rng.randf_range(area.position.x, area.end.x), _rng.randf_range(area.position.y, area.end.y))
		if _is_clear(p) or Terrain.dirt_at(p.x, p.y) > 0.3 or _blocked(p, 0.5) and not meadow:
			continue
		var key := Vector2i(floori(p.x / TREE_CHUNK), floori(p.y / TREE_CHUNK))
		if not chunks.has(key):
			chunks[key] = [[], []]
		var y := Terrain.height_at(p.x, p.y) + _rng.randf_range(0.1, 0.22)
		(chunks[key][0] as Array).append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * _rng.randf_range(0.8, 1.3)), Vector3(p.x, y, p.y)))
		(chunks[key][1] as Array).append(palette[_rng.randi() % palette.size()])
		placed += 1
	for key: Vector2i in chunks:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		var xforms: Array = chunks[key][0]
		mm.instance_count = xforms.size()
		for i in xforms.size():
			mm.set_instance_transform(i, xforms[i])
			mm.set_instance_color(i, chunks[key][1][i])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Wildflowers_%d_%d" % [key.x, key.y]
		mmi.multimesh = mm
		mmi.material_override = flower_material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = grass_view_distance
		add_child(mmi)
		_flowers.append(mmi)
		_full_counts[mmi] = xforms.size()


# ------------------------------------------------------------------ seasons
func apply_season(season_id: String) -> void:
	var style := Modules.style("trees") as TreeStyle
	var look: Dictionary = style.get_variant(season_id) if style else {}
	if leaf_material:
		leaf_material.albedo_color = look.get("leaf_tint", Color.WHITE)
	if pine_material:
		pine_material.albedo_color = look.get("pine_tint", Color.WHITE)
	set_canopy_visible(not bool(look.get("bare", season_id == "winter")))


## Broadleaf crowns on/off (bare branches in winter).
func set_canopy_visible(value: bool) -> void:
	for n in _leaf_nodes:
		n.visible = value
	for n in _bare_nodes:
		n.visible = not value


func canopy_visible() -> bool:
	return _leaf_nodes.is_empty() or _leaf_nodes[0].visible


## Fraction (0..1) of flowers shown.
func set_flower_fraction(fraction: float) -> void:
	for mmi in _flowers:
		mmi.multimesh.visible_instance_count = int(_full_counts.get(mmi, 0) * clampf(fraction, 0.0, 1.0))
		mmi.visible = fraction > 0.0


## Fraction (0..1) of grass blades shown (fewer under the winter snow).
func set_grass_fraction(fraction: float) -> void:
	for mmi in _grass:
		mmi.multimesh.visible_instance_count = int(_full_counts.get(mmi, 0) * clampf(fraction, 0.0, 1.0))


func grass_instance_total() -> int:
	var total := 0
	for mmi in _grass:
		total += int(_full_counts.get(mmi, 0))
	return total
