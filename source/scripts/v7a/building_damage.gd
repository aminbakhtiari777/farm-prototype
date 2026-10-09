class_name BuildingDamage
extends RefCounted
## v7a: how damage looks on a Building (fire / demolition / rebuilding):
##   ok          - normal (a "rebuilt" plaque for a couple of days after repair)
##   burning     - char overlay grows with the burn (fire particles: FireService)
##   burned      - blackened walls, roof gone above 55% burn, debris
##   demolished  - walls + roof down, a rubble pile, no collision
##   rebuilding  - scaffolding + sign; carpenter and mason at work
## Driven by CityState.damage (saved), applied by FireService.

static var _char_mats: Dictionary = {}


static func _char(alpha: float) -> StandardMaterial3D:
	var k := snappedi(int(alpha * 20.0), 1)
	if not _char_mats.has(k):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.07, 0.05, 0.04, float(k) / 20.0)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 1.0
		_char_mats[k] = m
	return _char_mats[k]


static func _meshes(b: Building) -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	for part in [b.get_node_or_null(^"ExteriorParts"), b.get_node_or_null(^"RoofParts")]:
		if part:
			for g in (part as Node).find_children("*", "GeometryInstance3D", true, false):
				out.append(g as GeometryInstance3D)
	return out


static func _child(b: Building, nm: String) -> Node3D:
	var n := b.get_node_or_null(NodePath(nm)) as Node3D
	return n


static func _clear_extras(b: Building) -> void:
	for nm in ["V7aDebris", "V7aRubble", "V7aScaffold", "V7aRebuilt"]:
		var n := _child(b, nm)
		if n:
			b.remove_child(n)
			n.queue_free()


static func apply(b: Building, state: String, burn: float, days_left: int = 0) -> void:
	if b == null or not is_instance_valid(b):
		return
	_clear_extras(b)
	var ext := b.get_node_or_null(^"ExteriorParts") as Node3D
	var roof := b.get_node_or_null(^"RoofParts") as Node3D
	var body := b.get("_body") as StaticBody3D
	var show_walls := state != "demolished"
	var show_roof := state not in ["demolished"] and not (state == "burned" and burn >= 0.55)
	if state == "rebuilding" and days_left > 1 and burn >= 0.55:
		show_roof = false
	if ext:
		ext.visible = show_walls
	if roof:
		roof.visible = show_roof
	b.wrecked = not show_walls
	if b.interior_root and not show_walls:
		b.interior_root.visible = false
	if body:
		body.collision_layer = 1 if show_walls else 0
	var alpha := 0.0
	match state:
		"burning", "burned":
			alpha = clampf(burn * 0.9, 0.0, 0.82)
		"rebuilding":
			alpha = clampf(burn * 0.35, 0.0, 0.3)
	for g in _meshes(b):
		g.material_overlay = _char(alpha) if alpha > 0.04 else null
	var w := b.size.x
	var d := b.size.z
	match state:
		"burned":
			_debris(b, w, d, burn)
		"demolished":
			_rubble(b, w, d)
		"rebuilding":
			_scaffold(b, w, d, b.size.y)
		"ok":
			pass


static func rebuilt_plaque(b: Building) -> void:
	var n := Node3D.new()
	n.name = "V7aRebuilt"
	b.add_child(n)
	var l := Label3D.new()
	Lang.setup_label3d(l, 40)
	l.text = Lang.tt("بازسازی شد - نجاری و سنگ‌تراشی شهر", "Rebuilt by the town carpenter and mason")
	l.modulate = Color(0.2, 0.45, 0.25)
	l.outline_size = 8
	l.outline_modulate = Color(1, 1, 1, 0.9)
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, b.size.y + b.roof_height + 1.4, b.size.z * 0.5)
	n.add_child(l)


static func _debris(b: Building, w: float, d: float, burn: float) -> void:
	var n := Node3D.new()
	n.name = "V7aDebris"
	b.add_child(n)
	var charred := V7aKit.mat(Color(0.12, 0.09, 0.07))
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b.name)
	var count := int(4 + burn * 8)
	for i in count:
		var p := Vector3(rng.randf_range(-w * 0.45, w * 0.45), 0.35 + rng.randf() * 0.2, rng.randf_range(-d * 0.45, d * 0.45))
		var mi := V7aKit.box(n, Vector3(rng.randf_range(1.0, 2.6), 0.14, 0.18), p, charred, false)
		mi.rotation = Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.4, 0.4))
	if burn >= 0.55:
		# Charred rafters where the roof was.
		for k in 4:
			var x := -w * 0.4 + k * w * 0.27
			var r := V7aKit.box(n, Vector3(0.16, 0.16, d * 0.9), Vector3(x, b.size.y + 0.4 + rng.randf() * 0.3, 0), charred, false)
			r.rotation.x = rng.randf_range(-0.25, 0.25)


static func _rubble(b: Building, w: float, d: float) -> void:
	var n := Node3D.new()
	n.name = "V7aRubble"
	b.add_child(n)
	var wall := V7aKit.mat(b.wall_color.darkened(0.15))
	var wood := V7aKit.mat(Color(0.45, 0.32, 0.2))
	var roofm := V7aKit.mat(b.roof_color)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(b.name) + 7
	V7aKit.box(n, Vector3(w + 0.2, 0.3, d + 0.2), Vector3(0, 0.15, 0), V7aKit.mat(Color(0.52, 0.5, 0.47)))
	for i in 18:
		var s := Vector3(rng.randf_range(0.5, 1.6), rng.randf_range(0.15, 0.5), rng.randf_range(0.4, 1.2))
		var p := Vector3(rng.randf_range(-w * 0.42, w * 0.42), 0.3 + s.y * 0.5 + rng.randf() * 0.4, rng.randf_range(-d * 0.42, d * 0.42))
		var m: Material = [wall, wood, roofm][i % 3]
		var mi := V7aKit.box(n, s, p, m)
		mi.rotation = Vector3(rng.randf_range(-0.5, 0.5), rng.randf() * TAU, rng.randf_range(-0.5, 0.5))
	# A stub of the corners still standing.
	for sx in [-1.0, 1.0]:
		V7aKit.box(n, Vector3(0.3, 1.1, 0.3), Vector3(sx * (w * 0.5 - 0.15), 0.85, -d * 0.5 + 0.15), wall)


static func _scaffold(b: Building, w: float, d: float, h: float) -> void:
	var n := Node3D.new()
	n.name = "V7aScaffold"
	b.add_child(n)
	var steel := V7aKit.mat(Color(0.55, 0.57, 0.6), 0.4)
	var wood := V7aKit.mat(Color(0.62, 0.48, 0.3))
	var hh := h + 1.2
	for k in 5:
		var x := -w * 0.5 - 0.2 + k * (w + 0.4) / 4.0
		for z in [d * 0.5 + 0.5, d * 0.5 + 1.2]:
			V7aKit.box(n, Vector3(0.07, hh, 0.07), Vector3(x, hh * 0.5, z), steel)
	for y in [1.3, 2.6]:
		V7aKit.box(n, Vector3(w + 0.6, 0.06, 0.8), Vector3(0, y, d * 0.5 + 0.85), wood)
		V7aKit.box(n, Vector3(w + 0.6, 0.05, 0.05), Vector3(0, y + 0.9, d * 0.5 + 1.2), steel)
	# Bricks + planks waiting.
	for k in 3:
		V7aKit.box(n, Vector3(1.0, 0.45, 0.7), Vector3(w * 0.5 + 1.3, 0.25 + k * 0.45, -0.6), V7aKit.mat(Color(0.7, 0.36, 0.26)))
	for k in 4:
		V7aKit.box(n, Vector3(2.4, 0.06, 0.22), Vector3(-w * 0.5 - 1.3, 0.05 + k * 0.07, 0.4), wood)
	var l := Label3D.new()
	Lang.setup_label3d(l, 40)
	l.text = Lang.tt("در حال بازسازی", "Rebuilding")
	l.modulate = Color(0.95, 0.75, 0.2)
	l.outline_size = 10
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = Vector3(0, hh + 0.5, d * 0.5 + 1.0)
	n.add_child(l)
