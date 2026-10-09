class_name CropModelBuilder
extends RefCounted
## Builds the procedural model of a crop (CropDef) at one growth stage:
##   0 planted  - seed dimple (+ a stake for trees)
##   1 growing  - a sprout that gets bigger through the stage
##   2 leaves   - the leafy plant
##   3 flowers  - full-size plant with flowers
##   4 fruit    - fruit / root / cob / bunch, ready to harvest
## The garden merges the result into one mesh per plant (MeshMerger).

static var _mats: Dictionary = {}


static func mat(c: Color, rough: float = 0.75) -> StandardMaterial3D:
	var key := "%s|%.2f" % [c.to_html(), rough]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = rough
		_mats[key] = m
	return _mats[key]


static func size_factor(stage: int, p: float) -> float:
	match stage:
		0: return 0.1
		1: return lerpf(0.16, 0.36, p)
		2: return lerpf(0.45, 0.82, p)
		3: return lerpf(0.86, 1.0, p)
	return 1.0


static func build(crop: CropDef, stage: int, progress: float, dead: bool, plant_scale: float = 1.0) -> Node3D:
	var root := Node3D.new()
	root.name = "Plant"
	var leaf := mat(Color(0.42, 0.33, 0.2) if dead else crop.leaf_color)
	var g := size_factor(stage, progress) * plant_scale
	var h := crop.height * g
	if stage == 0:
		_seed_dimple(root, crop)
		return root
	if stage == 1 and crop.shape != "tree" and crop.shape != "palm":
		_sprout(root, leaf, g)
		return root
	match crop.shape:
		"root", "tuber":
			_rosette(root, leaf, g, crop.shape == "tuber", crop.height)
			if stage >= 3 and not dead:
				_flowers(root, crop, 4, 0.08 * g, h * 0.9 + 0.05, 0.02)
			if stage == 4 and not dead:
				if crop.shape == "tuber":
					for k in 4:
						var a := k * 1.7 + 0.3
						sphere(root, crop.fruit_size, Vector3(cos(a) * 0.17, crop.fruit_size * 0.35, sin(a) * 0.17), mat(crop.fruit_color, 0.9), Vector3(1.2, 0.8, 1.0))
				else:
					sphere(root, crop.fruit_size, Vector3(0, crop.fruit_size * 0.45, 0), mat(crop.fruit_color, 0.5), Vector3(1, 0.95, 1))
		"bush":
			_bush(root, leaf, h, g)
			if stage == 3 and not dead:
				_flowers(root, crop, 7, 0.13 * g + 0.04, h * 0.6, 0.025)
			if stage == 4 and not dead:
				for k in crop.fruit_count:
					var a := k * 1.7 + 0.4
					sphere(root, crop.fruit_size, Vector3(cos(a) * 0.14, h * (0.3 + 0.12 * (k % 4)), sin(a) * 0.14), mat(crop.fruit_color, 0.4),
							Vector3(1, 1.6, 1) if crop.id == "eggplant" else Vector3.ONE)
		"stalk":
			_stalk(root, leaf, h, g)
			if stage >= 3 and not dead:
				if crop.id == "sunflower":
					var head := Vector3(0, h + 0.02, 0.06)
					cyl(root, 0.0, 0.16 * g, 0.05, head, mat(crop.flower_color, 0.6), Vector3(deg_to_rad(70), 0, 0))
					sphere(root, 0.08 * g, head + Vector3(0, 0.0, 0.02), mat(Color(0.3, 0.2, 0.1)), Vector3(1, 1, 0.4))
				else:
					sphere(root, 0.03, Vector3(0, h + 0.05, 0), mat(crop.flower_color), Vector3(1, 3.2, 1))
			if stage == 4 and not dead and crop.id != "sunflower":
				for k in 2:
					var a := k * PI + 0.5
					sphere(root, crop.fruit_size, Vector3(cos(a) * 0.07, h * 0.55, sin(a) * 0.07), mat(crop.fruit_color, 0.5),
							Vector3(0.75, 2.4, 0.75), Vector3(0, 0, 15 if k == 0 else -15))
		"vine":
			for k in 7:
				var a := k * TAU / 7.0
				var r := 0.3 * g
				sphere(root, 0.11, Vector3(cos(a) * r, 0.06 * g + 0.03, sin(a) * r), leaf, Vector3(1.2, 0.35, 1.2) * maxf(g, 0.3))
			if stage == 3 and not dead:
				_flowers(root, crop, 4, 0.3 * g, 0.12, 0.04)
			if stage == 4 and not dead:
				sphere(root, crop.fruit_size, Vector3(0.08, crop.fruit_size * 0.7, 0.05), mat(crop.fruit_color, 0.55), Vector3(1, 0.75, 1))
				cyl(root, 0.015, 0.02, 0.08, Vector3(0.08, crop.fruit_size * 1.4, 0.05), mat(Color(0.35, 0.3, 0.15)))
		"tree":
			_tree(root, crop, stage, progress, dead, plant_scale)
		"palm":
			_palm(root, crop, stage, progress, dead, plant_scale)
		_:
			_bush(root, leaf, h, g)
	return root


static func _seed_dimple(root: Node3D, crop: CropDef) -> void:
	sphere(root, 0.09, Vector3(0, 0.0, 0), mat(Color(0.2, 0.14, 0.09), 0.95), Vector3(1.4, 0.25, 1.4))
	for k in 2:
		sphere(root, 0.018, Vector3(-0.03 + k * 0.06, 0.02, 0.01), mat(Color(0.85, 0.75, 0.5)))
	if crop.shape == "tree" or crop.shape == "palm":
		cyl(root, 0.012, 0.015, 0.5, Vector3(0.12, 0.25, 0), mat(Color(0.6, 0.48, 0.3)))  # support stake


static func _sprout(root: Node3D, leaf: Material, g: float) -> void:
	var s := clampf(g * 2.6, 0.5, 1.0)
	cyl(root, 0.006, 0.009, 0.06 * s, Vector3(0, 0.03 * s, 0), leaf)
	for k in 2:
		sphere(root, 0.04 * s, Vector3((k * 2 - 1) * 0.03 * s, 0.065 * s, 0), leaf, Vector3(1.4, 0.35, 0.8), Vector3(0, 0, (k * 2 - 1) * -25))
	if g > 0.26:
		sphere(root, 0.03 * s, Vector3(0, 0.09 * s, 0.025), leaf, Vector3(0.8, 0.35, 1.4))


static func _rosette(root: Node3D, leaf: Material, g: float, bushy: bool, height: float) -> void:
	var n := 9 if bushy else 6
	for k in n:
		var a := k * TAU / n
		var r := (0.1 if bushy else 0.06) * g + 0.02
		sphere(root, 0.05, Vector3(cos(a) * r, height * 0.45 * g, sin(a) * r), leaf, Vector3(0.6, 2.4, 0.25) * g * (1.3 if bushy else 1.0),
				Vector3(0, -rad_to_deg(a) + 90, 30))


static func _bush(root: Node3D, leaf: Material, h: float, g: float) -> void:
	cyl(root, 0.012, 0.02, h, Vector3(0, h * 0.5, 0), leaf)
	for k in 6:
		var a := k * 2.2
		var y := h * (0.3 + k * 0.12)
		sphere(root, 0.08 * g + 0.025, Vector3(cos(a) * 0.09, y, sin(a) * 0.09), leaf, Vector3(1.25, 0.7, 1.25))


static func _stalk(root: Node3D, leaf: Material, h: float, g: float) -> void:
	cyl(root, 0.022, 0.032, h, Vector3(0, h * 0.5, 0), leaf)
	for k in 6:
		var a := k * 2.4
		sphere(root, 0.05, Vector3(cos(a) * 0.12, h * (0.22 + k * 0.11), sin(a) * 0.12), leaf, Vector3(0.35, 3.0, 0.12) * maxf(g, 0.3),
				Vector3(0, -rad_to_deg(a), 55))


static func _flowers(root: Node3D, crop: CropDef, count: int, radius: float, y: float, size: float) -> void:
	for k in count:
		var a := k * TAU / count + 0.3
		sphere(root, size, Vector3(cos(a) * radius, y + (k % 3) * 0.03, sin(a) * radius), mat(crop.flower_color, 0.5))


static func _tree(root: Node3D, crop: CropDef, stage: int, p: float, dead: bool, s: float) -> void:
	var g := [0.1, lerpf(0.18, 0.32, p), lerpf(0.4, 0.75, p), lerpf(0.8, 1.0, p), 1.0][stage] as float
	g *= s
	var h := crop.height * g
	var bark := mat(Color(0.38, 0.27, 0.17), 0.9)
	var leaf := mat(Color(0.42, 0.33, 0.2) if dead else crop.leaf_color)
	cyl(root, 0.03 * g + 0.01, 0.06 * g + 0.012, h * 0.55, Vector3(0, h * 0.275, 0), bark)
	var crown := Vector3(0, h * 0.7, 0)
	var cr := maxf(0.5 * g, 0.08)
	var blobs := [Vector3(0, 0, 0), Vector3(0.45, -0.1, 0.1), Vector3(-0.4, -0.05, -0.15), Vector3(0.05, 0.3, -0.3), Vector3(-0.1, 0.1, 0.42)]
	for k in (2 if stage == 1 else 5):
		sphere(root, cr, crown + (blobs[k] as Vector3) * g, leaf, Vector3(1, 0.85, 1))
	if dead:
		return
	if stage == 3:
		for k in 14:
			var a := k * 2.39
			var dir := Vector3(cos(a), 0.4 + 0.5 * sin(k * 1.3), sin(a)).normalized()
			sphere(root, 0.035, crown + dir * cr * 1.05, mat(crop.flower_color, 0.5))
	elif stage == 4:
		for k in crop.fruit_count:
			var a := k * 2.39
			var dir := Vector3(cos(a), 0.1 + 0.6 * sin(k * 1.7), sin(a)).normalized()
			sphere(root, crop.fruit_size, crown + dir * cr * 1.02, mat(crop.fruit_color, 0.4))


static func _palm(root: Node3D, crop: CropDef, stage: int, p: float, dead: bool, s: float) -> void:
	var g := [0.1, lerpf(0.2, 0.35, p), lerpf(0.45, 0.8, p), lerpf(0.85, 1.0, p), 1.0][stage] as float
	g *= s
	var h := crop.height * g
	var trunk := mat(Color(0.45, 0.42, 0.26), 0.9)
	var leaf := mat(Color(0.42, 0.33, 0.2) if dead else crop.leaf_color)
	cyl(root, 0.05 * g + 0.01, 0.08 * g + 0.015, h * 0.7, Vector3(0, h * 0.35, 0), trunk)
	var top := Vector3(0, h * 0.7, 0)
	var n := 3 if stage == 1 else 7
	for k in n:
		var a := k * TAU / n
		var dir := Vector3(cos(a), 0.0, sin(a))
		sphere(root, 0.12, top + dir * 0.32 * g + Vector3(0, 0.1 * g, 0), leaf, Vector3(0.7, 0.18, 3.6) * g,
				Vector3(-25, -rad_to_deg(a) + 90, 0))
	if dead:
		return
	if stage == 3:
		sphere(root, 0.07 * g + 0.02, top + Vector3(0.1, -0.15 * g, 0), mat(crop.flower_color, 0.5), Vector3(1, 1.8, 1))
	elif stage == 4:
		for k in crop.fruit_count:
			var a := k * TAU / crop.fruit_count
			var row := k % 3
			sphere(root, crop.fruit_size, top + Vector3(0.12 + cos(a) * 0.08, -0.12 - row * 0.09, sin(a) * 0.08), mat(crop.fruit_color, 0.5),
					Vector3(0.6, 2.6, 0.6), Vector3(0, -rad_to_deg(a), 35))


# ------------------------------------------------------------------ primitives
static func sphere(parent: Node3D, radius: float, pos: Vector3, m: Material, scale_v: Vector3 = Vector3.ONE, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 10
	sm.rings = 5
	mi.mesh = sm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scale_v
	parent.add_child(mi)


static func cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = maxf(h, 0.005)
	cm.radial_segments = 7
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
