class_name TownLots
extends Node3D
## v6b "town_lots" module: a slight town expansion - a few extra lots along
## the existing streets: "built" (a new family's house, furnished inside),
## "construction" (foundation, scaffolding, a half-built frame, a sign) and
## "for_sale" (pegged-out plot with a "for sale" board). No new streets.

var lots: Dictionary = {}  ## id -> Node3D (Building for built lots)


func style() -> TownLotsStyle:
	return Modules.style("town_lots") as TownLotsStyle


func _ready() -> void:
	add_to_group(&"town_lots")
	_build()
	Modules.on_swap("town_lots", self, func(_m: Resource) -> void: _build())


static func _mat(c: Color, rough: float = 0.85) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _box(parent: Node3D, s: Vector3, p: Vector3, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	return mi


func _build() -> void:
	for c in get_children():
		if c is Building and (c as Building).player_inside:
			continue
		c.queue_free()
	lots.clear()
	var st := style()
	if st == null:
		return
	for d: Dictionary in st.lots:
		var id := str(d.get("id", "lot"))
		var p: Vector2 = d.get("pos", Vector2.ZERO)
		var yaw := deg_to_rad(float(d.get("yaw", 0.0)))
		match str(d.get("state", "for_sale")):
			"built":
				lots[id] = _built(id, p, yaw, d)
			"construction":
				lots[id] = _construction(id, p, yaw, d)
			_:
				lots[id] = _for_sale(id, p, yaw, d)


func _built(id: String, p: Vector2, yaw: float, d: Dictionary) -> Node3D:
	var b := Building.new()
	b.name = "Lot_" + id
	b.size = Vector3(7.0, 3.0, 6.0)
	b.roof_height = 1.9
	b.wall_color = d.get("wall", Color(0.9, 0.85, 0.7))
	b.roof_color = d.get("roof", Color(0.4, 0.25, 0.2))
	b.kind = "home"
	b.interior_theme = "home_b"
	b.address = str(d.get("address", ""))
	b.owner_name = str(d.get("family", "Hosseini"))
	b.sign_text = "The %s Family" % b.owner_name
	b.has_porch = true
	b.random_seed = absi(hash(id)) % 1000
	b.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	b.rotation.y = yaw
	b.wall_color = HouseColors.wall_for(b, b.wall_color)
	add_child(b)
	return b


func _construction(id: String, p: Vector2, yaw: float, d: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Lot_" + id
	root.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	root.rotation.y = yaw
	add_child(root)
	var conc := _mat(Color(0.7, 0.7, 0.68))
	var wood := _mat(Color(0.62, 0.48, 0.3))
	var steel := _mat(Color(0.55, 0.57, 0.6), 0.4)
	var block := _mat(d.get("wall", Color(0.85, 0.85, 0.85)))
	_box(root, Vector3(7.4, 0.35, 6.4), Vector3(0, 0.17, 0), conc)
	# Half-built walls (back + sides) with a gap where the door goes.
	_box(root, Vector3(7.0, 1.6, 0.25), Vector3(0, 1.15, -3.0), block)
	for sx: float in [-1, 1]:
		_box(root, Vector3(0.25, 1.1 if sx < 0 else 1.9, 6.0), Vector3(sx * 3.4, 0.9 if sx < 0 else 1.3, 0), block)
	_box(root, Vector3(2.4, 0.9, 0.25), Vector3(-2.2, 0.8, 3.0), block)
	# Scaffolding poles + planks along the front.
	for k in 5:
		var x := -3.6 + k * 1.8
		_box(root, Vector3(0.07, 3.6, 0.07), Vector3(x, 1.8 + 0.35, 3.6), steel)
		_box(root, Vector3(0.07, 3.6, 0.07), Vector3(x, 1.8 + 0.35, 4.3), steel)
	for y: float in [1.4, 2.8]:
		_box(root, Vector3(7.4, 0.06, 0.8), Vector3(0, y, 3.95), wood)
		_box(root, Vector3(7.4, 0.05, 0.05), Vector3(0, y + 0.9, 4.3), steel)
	# Stacked bricks + sand pile + sign.
	for k in 3:
		_box(root, Vector3(1.0, 0.5, 0.7), Vector3(4.6, 0.25 + k * 0.5, -1.0 + k * 0.05), _mat(Color(0.7, 0.36, 0.26)))
	var sand := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.1
	cm.bottom_radius = 1.0
	cm.height = 0.8
	sand.mesh = cm
	sand.material_override = _mat(Color(0.86, 0.76, 0.55))
	sand.position = Vector3(4.6, 0.4, 1.6)
	root.add_child(sand)
	_sign(root, Vector3(-3.0, 0, 5.2), Lang.tt("در حال ساخت - خانه‌ی تازه", "Under construction - new home"), Color(0.95, 0.75, 0.2))
	var body := StaticBody3D.new()
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(7.2, 2.0, 6.4)
	cs.shape = bs
	cs.position = Vector3(0, 1.0, 0)
	body.add_child(cs)
	return root


func _for_sale(id: String, p: Vector2, yaw: float, _d: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Lot_" + id
	root.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	root.rotation.y = yaw
	add_child(root)
	var peg := _mat(Color(0.75, 0.6, 0.38))
	var tape := _mat(Color(0.95, 0.45, 0.1), 0.6)
	for c in [Vector2(-3.5, -3), Vector2(3.5, -3), Vector2(3.5, 3), Vector2(-3.5, 3)]:
		_box(root, Vector3(0.08, 0.6, 0.08), Vector3(c.x, 0.3, c.y), peg)
	for e in [[Vector3(0, 0.5, -3), Vector3(7, 0.03, 0.03)], [Vector3(0, 0.5, 3), Vector3(7, 0.03, 0.03)],
			[Vector3(-3.5, 0.5, 0), Vector3(0.03, 0.03, 6)], [Vector3(3.5, 0.5, 0), Vector3(0.03, 0.03, 6)]]:
		_box(root, e[1], e[0], tape)
	_sign(root, Vector3(0, 0, 3.6), Lang.tt("زمین فروشی - شهرداری", "Lot for sale - City Hall"), Color(0.2, 0.55, 0.3))
	return root


func _sign(root: Node3D, pos: Vector3, text: String, color: Color) -> void:
	var wood := _mat(Color(0.5, 0.36, 0.22))
	_box(root, Vector3(0.1, 1.6, 0.1), pos + Vector3(-0.7, 0.8, 0), wood)
	_box(root, Vector3(0.1, 1.6, 0.1), pos + Vector3(0.7, 0.8, 0), wood)
	_box(root, Vector3(1.9, 0.8, 0.06), pos + Vector3(0, 1.45, 0), _mat(color))
	var l := Label3D.new()
	Lang.setup_label3d(l, 40)
	l.text = text
	l.font_size = 40
	l.pixel_size = 0.0045
	l.width = 380.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.modulate = Color(0.1, 0.08, 0.05)
	l.outline_size = 0
	l.position = pos + Vector3(0, 1.45, 0.04)
	root.add_child(l)
