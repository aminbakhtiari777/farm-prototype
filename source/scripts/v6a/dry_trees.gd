class_name DryTrees
extends Node3D
## v6a "dry_trees" module: dead, leafless trees along the west and north
## forest edges (inside the play area). Chop one with the axe (E, a few hits)
## for firewood + dry wood (+ sometimes a rough board). Felled trees leave a
## stump; Lifestyle regrows a few every morning so dry wood is always there.
## Drawn with one MultiMesh per mesh variant + one for the stumps (few draw
## calls on the web).

const VARIANTS := 3

var spots: Array[Vector2] = []
var yaws: PackedFloat32Array = PackedFloat32Array()
var scales: PackedFloat32Array = PackedFloat32Array()
var spots_ui: Array[ActionSpot] = []
var _mm: Array[MultiMeshInstance3D] = []
var _stumps: MultiMeshInstance3D
var _body: StaticBody3D
var _shapes: Array[CollisionShape3D] = []
var _meshes: Array[ArrayMesh] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"dry_trees")
	Modules.on_swap("dry_trees", self, func(_m: AssetModule) -> void: rebuild())
	Lifestyle.trees_changed.connect(_sync)
	rebuild()


func style() -> DryTreeStyle:
	return Modules.style("dry_trees") as DryTreeStyle


static func candidate_ok(p: Vector2) -> bool:
	if TownLayout.sea_distance(p.x, p.y) > -TownLayout.SAND_WIDTH - 3.0:
		return false
	if TownLayout.river_distance(p) < TownLayout.RIVER_HALF + 3.0:
		return false
	if p.distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS + 3.0:
		return false
	if Terrain.road_at(p.x, p.y) > 0.02:
		return false
	for b in TownLayout.BUILDINGS:
		if TownLayout.footprint_distance(b, p, 0.0) < 4.0:
			return false
	if TownLayout.GARDEN_MAX_RECT.grow(4.0).has_point(p):
		return false
	return true


## Deterministic spots: along the inside of the west and north edges.
static func compute_spots(count: int) -> Array[Vector2]:
	var rng := RandomNumberGenerator.new()
	rng.seed = 60601
	var area := TownLayout.PLAY_AREA
	var out: Array[Vector2] = []
	var tries := 0
	while out.size() < count and tries < 4000:
		tries += 1
		var p: Vector2
		if out.size() % 2 == 0:
			p = Vector2(area.position.x + rng.randf_range(4.0, 9.0), rng.randf_range(area.position.y + 12.0, area.end.y - 22.0))
		else:
			p = Vector2(rng.randf_range(area.position.x + 10.0, area.end.x - 34.0), area.position.y + rng.randf_range(4.0, 9.0))
		if not candidate_ok(p):
			continue
		var close := false
		for q in out:
			if q.distance_to(p) < 7.0:
				close = true
				break
		if not close:
			out.append(p)
	return out


## Procedural dead tree: tapered trunk + bare forked branches (~200 tris).
static func dead_tree_mesh(variant: int, bark: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + variant
	var dark := bark.darkened(0.25)
	var h := 4.2 + variant * 0.6
	_limb(st, Vector3.ZERO, Vector3(0.12 * (variant - 1), h, 0.08), 0.26, 0.09, dark, bark)
	var n := 5 + variant
	for i in n:
		var t := rng.randf_range(0.35, 0.9)
		var base := Vector3(0.12 * (variant - 1) * t, h * t, 0.08 * t)
		var a := rng.randf() * TAU
		var ln := rng.randf_range(1.0, 2.0) * (1.1 - t * 0.5)
		var tip := base + Vector3(cos(a) * ln, ln * rng.randf_range(0.5, 1.1), sin(a) * ln)
		_limb(st, base, tip, 0.08 * (1.2 - t), 0.02, dark, bark)
		# small fork
		var a2 := a + rng.randf_range(-0.9, 0.9)
		var mid := base.lerp(tip, 0.6)
		_limb(st, mid, mid + Vector3(cos(a2) * 0.6, 0.55, sin(a2) * 0.6), 0.035, 0.012, dark, bark)
	st.generate_normals()
	return st.commit()


static func stump_mesh(bark: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_limb(st, Vector3.ZERO, Vector3(0, 0.45, 0), 0.3, 0.26, bark.darkened(0.2), bark)
	# pale cut face
	var c := Color(0.82, 0.7, 0.5)
	for i in 8:
		var a0 := TAU * i / 8.0
		var a1 := TAU * (i + 1) / 8.0
		st.set_color(c); st.add_vertex(Vector3(0, 0.45, 0))
		st.set_color(c); st.add_vertex(Vector3(cos(a1) * 0.26, 0.45, sin(a1) * 0.26))
		st.set_color(c); st.add_vertex(Vector3(cos(a0) * 0.26, 0.45, sin(a0) * 0.26))
	st.generate_normals()
	return st.commit()


static func _limb(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, c0: Color, c1: Color) -> void:
	var axis := (b - a).normalized()
	var side := axis.cross(Vector3.FORWARD if absf(axis.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT).normalized()
	var up := axis.cross(side).normalized()
	var seg := 6
	for i in seg:
		var a0 := TAU * i / seg
		var a1 := TAU * (i + 1) / seg
		var d0 := side * cos(a0) + up * sin(a0)
		var d1 := side * cos(a1) + up * sin(a1)
		st.set_color(c0); st.add_vertex(a + d0 * r0)
		st.set_color(c1); st.add_vertex(b + d0 * r1)
		st.set_color(c0); st.add_vertex(a + d1 * r0)
		st.set_color(c0); st.add_vertex(a + d1 * r0)
		st.set_color(c1); st.add_vertex(b + d0 * r1)
		st.set_color(c1); st.add_vertex(b + d1 * r1)


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_mm.clear()
	_shapes.clear()
	spots_ui.clear()
	_meshes.clear()
	var st := style()
	if st == null:
		spots.clear()
		return
	spots = compute_spots(st.count)
	_rng.seed = 7
	yaws.resize(spots.size())
	scales.resize(spots.size())
	for i in spots.size():
		yaws[i] = _rng.randf() * TAU
		scales[i] = _rng.randf_range(0.85, 1.2)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	for v in VARIANTS:
		_meshes.append(dead_tree_mesh(v, st.bark_color))
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "DryTreesMM%d" % v
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _meshes[v]
		mm.instance_count = spots.size()
		mmi.multimesh = mm
		mmi.material_override = mat
		mmi.visibility_range_end = 150.0
		add_child(mmi)
		_mm.append(mmi)
	_stumps = MultiMeshInstance3D.new()
	_stumps.name = "StumpsMM"
	var smm := MultiMesh.new()
	smm.transform_format = MultiMesh.TRANSFORM_3D
	smm.mesh = stump_mesh(st.bark_color)
	smm.instance_count = spots.size()
	_stumps.multimesh = smm
	_stumps.material_override = mat
	add_child(_stumps)
	_body = StaticBody3D.new()
	_body.name = "DryTreeBodies"
	add_child(_body)
	for i in spots.size():
		var p := spots[i]
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = 0.3
		cyl.height = 3.0
		cs.shape = cyl
		cs.position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 1.5, p.y)
		_body.add_child(cs)
		_shapes.append(cs)
		var idx := i
		var spot := ActionSpot.make(self, Vector3(p.x, Terrain.height_at(p.x, p.y), p.y), 1.9,
			func() -> String: return _verb(idx),
			func(who: Node3D) -> void: chop(idx, who),
			func() -> bool: return not Lifestyle.is_felled(idx))
		spot.name = "DryTree%d" % i
		spots_ui.append(spot)
	_sync()


func _verb(i: int) -> String:
	var need := Lifestyle.hits_needed()
	var done := int(Lifestyle.hits.get(i, 0))
	if Lang.is_fa():
		return "بریدن درخت خشک با تبر (%s/%s)" % [Lang.digits(str(done)), Lang.digits(str(need))]
	return "chop the dry tree with the axe (%d/%d)" % [done, need]


## Shows standing trees / stumps from Lifestyle.felled.
func _sync() -> void:
	if _mm.is_empty():
		return
	for i in spots.size():
		var p := spots[i]
		var y := Terrain.height_at(p.x, p.y) - 0.15
		var down := Lifestyle.is_felled(i)
		var xf := Transform3D(Basis(Vector3.UP, yaws[i]).scaled(Vector3.ONE * scales[i]), Vector3(p.x, y, p.y))
		for v in VARIANTS:
			var show := v == i % VARIANTS and not down
			_mm[v].multimesh.set_instance_transform(i, xf if show else Transform3D(Basis().scaled(Vector3.ZERO), xf.origin))
		_stumps.multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, yaws[i]), Vector3(p.x, y + 0.1, p.y)) if down else Transform3D(Basis().scaled(Vector3.ZERO), xf.origin))
		if i < _shapes.size():
			_shapes[i].disabled = down
			_shapes[i].shape.set("height", 0.9 if down else 3.0)
		if i < spots_ui.size():
			spots_ui[i].refresh()


func standing_count() -> int:
	var n := 0
	for i in spots.size():
		if not Lifestyle.is_felled(i):
			n += 1
	return n


## One axe hit (E). Felling drops firewood + dry wood into the bag.
func chop(i: int, who: Node3D) -> Dictionary:
	if Lifestyle.is_felled(i):
		return {}
	var st := style()
	if who and who.has_method("play_tool"):
		who.call("play_tool", "axe")
	if who and who.has_method("spend_stamina"):
		who.call("spend_stamina", st.stamina_per_hit if st else 4.0)
	var res := Lifestyle.hit_tree(i, _rng)
	if bool(res.get("felled", false)):
		_fall_fx(i)
		var parts: PackedStringArray = []
		var items: Dictionary = res.get("items", {})
		for k in items:
			parts.append(("%s %s" % [Lang.digits(str(items[k])), Market.local_name(str(k))]) if Lang.is_fa() else "%d %s" % [int(items[k]), GameData.item_name(str(k))])
		GameEvents.notification_requested.emit(Lang.tt("درخت افتاد! گرفتی: %s" % "، ".join(parts), "Timber! You got %s" % ", ".join(parts)))
	return res


func _fall_fx(i: int) -> void:
	var p := spots[i]
	var mi := MeshInstance3D.new()
	mi.mesh = _meshes[i % VARIANTS]
	mi.material_override = _mm[0].material_override
	mi.position = Vector3(p.x, Terrain.height_at(p.x, p.y) - 0.15, p.y)
	mi.rotation.y = yaws[i]
	mi.scale = Vector3.ONE * scales[i]
	add_child(mi)
	var tw := mi.create_tween()
	tw.tween_property(mi, "rotation:x", deg_to_rad(84.0), 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_interval(1.2)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, 0.5)
	tw.tween_callback(mi.queue_free)
	Sfx.play_at(&"land", mi.position, -2.0, 0.6)
