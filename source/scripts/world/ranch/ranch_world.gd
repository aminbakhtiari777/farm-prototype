class_name RanchWorld
extends Node3D
## v5c ranch south of the farm (node "Ranch" in Main.tscn). For every
## animal_housing module (coop, barn) it shows, depending on Ranch state:
##   none     - a staked-out plot with a sign ("order at the carpenter"),
##   ordered  - a construction site (foundation, frame, scaffolding, planks),
##   built    - the building, a fenced paddock and a feed trough (E: feed all).
## Animals (FarmAnimal) live in the paddock of their housing. Everything is
## rebuilt from Ranch / module data, so swapping a module restyles it.

const WOOD := Color(0.55, 0.4, 0.26)
const WOOD_DARK := Color(0.38, 0.27, 0.17)

var sites: Dictionary = {}  ## housing id -> Node3D
var troughs: Dictionary = {}  ## housing id -> Interactable
var animal_nodes: Dictionary = {}  ## uid -> FarmAnimal
var _states: Dictionary = {}
var _dirty: bool = false


func _ready() -> void:
	add_to_group(&"ranch_world")
	rebuild()
	Ranch.changed.connect(func() -> void: _dirty = true)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			rebuild())
	for t in ["animal_housing", "livestock"]:
		Modules.on_swap(t, self, func(_m: AssetModule) -> void: rebuild())


func _process(_delta: float) -> void:
	if _dirty:
		_dirty = false
		sync()


func _t(fa: String, en: String) -> String:
	return fa if Lang.is_fa() else en


## Full rebuild (module swap / language change).
func rebuild() -> void:
	for n in get_children():
		n.queue_free()
	sites.clear()
	troughs.clear()
	animal_nodes.clear()
	_states.clear()
	sync()


## Brings the world in line with Ranch (new states, new / removed animals).
func sync() -> void:
	for h in Ranch.housing_defs():
		var st := Ranch.housing_state(h.id) + ":" + str(Ranch.ready_day(h.id))
		if _states.get(h.id, "") != st:
			_states[h.id] = st
			if sites.has(h.id):
				(sites[h.id] as Node3D).queue_free()
			sites[h.id] = _build_site(h)
	var alive := {}
	for a: Dictionary in Ranch.animals:
		var uid := int(a["uid"])
		alive[uid] = true
		var d := Ranch.animal_def(str(a["kind"]))
		if d == null:
			continue
		var h := Ranch.housing_def(d.housing)
		if not animal_nodes.has(uid) or not is_instance_valid(animal_nodes[uid]):
			if h == null or not Ranch.is_built(h.id):
				continue
			var fa := FarmAnimal.new()
			add_child(fa)
			fa.setup(a, d, paddock_rect(h))
			animal_nodes[uid] = fa
		else:
			(animal_nodes[uid] as FarmAnimal).refresh()
	for uid in animal_nodes.keys():
		if not alive.has(uid):
			if is_instance_valid(animal_nodes[uid]):
				(animal_nodes[uid] as Node3D).queue_free()
			animal_nodes.erase(uid)
	for hid in troughs:
		var z := troughs[hid] as Interactable
		if is_instance_valid(z):
			z.set_action_text(_trough_text(str(hid)))
			var feed := z.get_parent().get_node_or_null(^"Feed") as Node3D
			if feed:
				var hungry := 0
				for a: Dictionary in Ranch.animals_in(str(hid)):
					if not bool(a["fed_today"]):
						hungry += 1
				feed.visible = hungry == 0 and not Ranch.animals_in(str(hid)).is_empty()


## Paddock rectangle in world x/z.
func paddock_rect(h: HousingDef) -> Rect2:
	var c := h.position + h.paddock_offset.rotated(-deg_to_rad(h.yaw_deg))
	return Rect2(c - h.paddock_size * 0.5, h.paddock_size)


func _y(x: float, z: float) -> float:
	return Terrain.height_at(x, z)


func _label(parent: Node3D, text: String, pos: Vector3, size: int = 48) -> Label3D:
	var l := Label3D.new()
	Lang.setup_label3d(l, size)
	l.text = text
	l.position = pos
	l.pixel_size = 0.004
	l.outline_size = 10
	l.modulate = Color(0.25, 0.16, 0.09)
	l.outline_modulate = Color(1, 0.96, 0.85, 0.9)
	parent.add_child(l)
	return l


func _zone(parent: Node3D, pos: Vector3, radius: float, text: String, cb: Callable) -> Interactable:
	var z := Interactable.new()
	z.collision_layer = 8
	z.collision_mask = 2
	z.position = pos
	var s := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = radius
	s.shape = sp
	z.add_child(s)
	z.action_text = text
	parent.add_child(z)
	z.interacted.connect(func(_who: Node3D) -> void: cb.call())
	return z


func _solid(parent: Node3D, size: Vector3, pos: Vector3) -> void:
	var body := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	s.shape = b
	body.position = pos
	body.add_child(s)
	parent.add_child(body)


func _sign(root: Node3D, pos: Vector3, text: String) -> void:
	FarmAnimal.box(root, Vector3(0.08, 1.2, 0.08), pos + Vector3(0, 0.6, 0), WOOD_DARK)
	FarmAnimal.box(root, Vector3(1.5, 0.62, 0.05), pos + Vector3(0, 1.3, 0), Color(0.86, 0.74, 0.55))
	_label(root, text, pos + Vector3(0, 1.3, 0.035), 30)


func _build_site(h: HousingDef) -> Node3D:
	var root := Node3D.new()
	root.name = "Site_" + h.id
	add_child(root)
	root.position = Vector3(h.position.x, _y(h.position.x, h.position.y), h.position.y)
	root.rotation.y = deg_to_rad(h.yaw_deg)
	var st := Ranch.housing_state(h.id)
	var nm := h.name_fa if Lang.is_fa() else h.display_name
	match st:
		"built":
			_build_house(root, h)
			_build_paddock(root, h)
		"ordered":
			_build_construction(root, h)
			_sign(root, Vector3(h.size.x * 0.5 + 1.2, 0, h.size.z * 0.5 + 0.8),
				_t("در حال ساخت: %s\nآماده: روز %s" % [nm, Lang.digits(str(Ranch.ready_day(h.id)))], "Building: %s\nReady on day %d" % [nm, Ranch.ready_day(h.id)]))
		_:
			# Staked-out plot.
			var hx := h.size.x * 0.5
			var hz := h.size.z * 0.5
			for c in [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]:
				FarmAnimal.box(root, Vector3(0.06, 0.5, 0.06), c + Vector3(0, 0.25, 0), WOOD)
			for i in 4:
				var a: Vector3 = [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)][i]
				var b: Vector3 = [Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz), Vector3(-hx, 0, -hz)][i]
				var mid := (a + b) * 0.5 + Vector3(0, 0.4, 0)
				FarmAnimal.box(root, Vector3(absf(b.x - a.x) + 0.01, 0.015, absf(b.z - a.z) + 0.01), mid, Color(0.9, 0.85, 0.3))
			_sign(root, Vector3(0, 0, hz + 0.8), _t("زمین %s\nسفارش در نجاری" % nm, "%s plot\nOrder at the carpenter" % nm))
	return root


func _build_house(root: Node3D, h: HousingDef) -> void:
	var w := h.size.x
	var hgt := h.size.y
	var d := h.size.z
	var wall_h := hgt * 0.62
	var barn := w > 4.0
	# Stone footing + walls.
	FarmAnimal.box(root, Vector3(w + 0.2, 0.25, d + 0.2), Vector3(0, 0.1, 0), Color(0.55, 0.53, 0.5))
	FarmAnimal.box(root, Vector3(w, wall_h, d), Vector3(0, 0.22 + wall_h * 0.5, 0), h.wall_color)
	# Gable roof (prism) + overhanging roof slabs.
	var roof_h := hgt - wall_h
	var gable := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(d, roof_h, w)
	gable.mesh = pm
	gable.material_override = FarmAnimal.mat(h.wall_color)
	gable.rotation.y = PI * 0.5
	gable.position = Vector3(0, 0.22 + wall_h + roof_h * 0.5, 0)
	root.add_child(gable)
	var slope := atan2(roof_h, d * 0.5)
	var slab_len := sqrt(roof_h * roof_h + d * d * 0.25) + 0.35
	for s in [-1.0, 1.0]:
		FarmAnimal.box(root, Vector3(w + 0.5, 0.1, slab_len),
			Vector3(0, 0.22 + wall_h + roof_h * 0.5 + 0.05, s * d * 0.25), h.roof_color, Vector3(s * slope, 0, 0))
	# Corner trims.
	for cx in [-w * 0.5, w * 0.5]:
		for cz in [-d * 0.5, d * 0.5]:
			FarmAnimal.box(root, Vector3(0.12, wall_h, 0.12), Vector3(cx, 0.22 + wall_h * 0.5, cz), h.trim_color)
	if barn:
		# Big double doors with white X braces.
		var dw := w * 0.42
		var dh := wall_h * 0.85
		FarmAnimal.box(root, Vector3(dw, dh, 0.06), Vector3(0, 0.22 + dh * 0.5, d * 0.5 + 0.02), h.wall_color.darkened(0.25))
		FarmAnimal.box(root, Vector3(dw + 0.12, 0.1, 0.08), Vector3(0, 0.22 + dh, d * 0.5 + 0.04), h.trim_color)
		for s in [-1.0, 1.0]:
			FarmAnimal.box(root, Vector3(0.08, dh, 0.08), Vector3(s * dw * 0.5, 0.22 + dh * 0.5, d * 0.5 + 0.04), h.trim_color)
			FarmAnimal.box(root, Vector3(0.07, sqrt(dh * dh + dw * dw * 0.25), 0.07), Vector3(s * dw * 0.25, 0.22 + dh * 0.5, d * 0.5 + 0.05),
				h.trim_color, Vector3(0, 0, s * atan2(dw * 0.5, dh)))
		FarmAnimal.box(root, Vector3(0.9, 0.7, 0.06), Vector3(0, 0.22 + wall_h + roof_h * 0.35, d * 0.5 - 0.02), h.trim_color)
		FarmAnimal.box(root, Vector3(0.7, 0.5, 0.07), Vector3(0, 0.22 + wall_h + roof_h * 0.35, d * 0.5), Color(0.2, 0.15, 0.1))
		# Hay bales by the door.
		for i in 3:
			var hb := FarmAnimal.box(root, Vector3(1.0, 0.5, 0.6), Vector3(w * 0.5 + 0.8, 0.25 + (0.5 if i == 2 else 0.0), -0.6 + (i % 2) * 0.7 + (0.35 if i == 2 else 0.0)), Color(0.88, 0.76, 0.4))
			hb.rotation.y = 0.2 * i
	else:
		# Coop: small door, ramp, window, nest boxes on the side.
		FarmAnimal.box(root, Vector3(0.6, 0.8, 0.06), Vector3(-w * 0.2, 0.22 + 0.55, d * 0.5 + 0.02), Color(0.2, 0.14, 0.1))
		FarmAnimal.box(root, Vector3(0.5, 0.05, 1.0), Vector3(-w * 0.2, 0.32, d * 0.5 + 0.45), WOOD, Vector3(-0.35, 0, 0))
		FarmAnimal.box(root, Vector3(0.6, 0.45, 0.06), Vector3(w * 0.22, 0.22 + wall_h * 0.6, d * 0.5 + 0.02), h.trim_color)
		FarmAnimal.box(root, Vector3(0.48, 0.34, 0.07), Vector3(w * 0.22, 0.22 + wall_h * 0.6, d * 0.5 + 0.03), Color(0.35, 0.5, 0.6))
		FarmAnimal.box(root, Vector3(0.5, 0.5, 1.6), Vector3(w * 0.5 + 0.25, 0.6, 0), WOOD)
		FarmAnimal.box(root, Vector3(0.6, 0.08, 1.7), Vector3(w * 0.5 + 0.28, 0.88, 0), h.roof_color, Vector3(0, 0, -0.25))
	_label(root, h.name_fa if Lang.is_fa() else h.display_name, Vector3(0, 0.22 + wall_h + roof_h * 0.15, d * 0.5 + 0.09), 44).modulate = h.trim_color
	_solid(root, Vector3(w, hgt, d), Vector3(0, hgt * 0.5, 0))


func _build_paddock(root: Node3D, h: HousingDef) -> void:
	var r := paddock_rect(h)
	# World-space child of the site (freed with it).
	var pad := Node3D.new()
	pad.name = "Paddock_" + h.id
	pad.top_level = true
	root.add_child(pad)
	pad.global_transform = Transform3D.IDENTITY
	# Fence: west, south, east sides + north pieces left of the gate / right of the house.
	var hw := h.size.x * 0.5 + 0.3
	var segs: Array = [
		[Vector2(r.position.x, r.position.y), Vector2(r.position.x, r.end.y)],
		[Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y)],
		[Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y)],
		[Vector2(h.position.x + hw, r.position.y), Vector2(r.end.x, r.position.y)],
	]
	var gate_w := 1.8
	if h.position.x - hw - r.position.x > gate_w + 0.4:
		segs.append([Vector2(r.position.x, r.position.y), Vector2(h.position.x - hw - gate_w, r.position.y)])
	for sg: Array in segs:
		_fence(pad, sg[0], sg[1])
	# Dirt floor patch for the run.
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = r.size
	floor_mi.mesh = pm
	floor_mi.material_override = FarmAnimal.mat(Color(0.52, 0.42, 0.28) if h.kinds.has("chicken") else Color(0.42, 0.55, 0.28))
	var c := r.get_center()
	floor_mi.position = Vector3(c.x, _y(c.x, c.y) + 0.03, c.y)
	pad.add_child(floor_mi)
	# Feed trough near the gate (inside the run).
	var tp := Vector2(r.position.x + 1.3, r.position.y + 1.2)
	var trough := Node3D.new()
	trough.name = "Trough"
	trough.position = Vector3(tp.x, _y(tp.x, tp.y), tp.y)
	pad.add_child(trough)
	FarmAnimal.box(trough, Vector3(1.4, 0.3, 0.5), Vector3(0, 0.3, 0), WOOD_DARK)
	FarmAnimal.box(trough, Vector3(1.25, 0.05, 0.36), Vector3(0, 0.42, 0), Color(0.18, 0.13, 0.09))
	for s in [-0.6, 0.6]:
		FarmAnimal.box(trough, Vector3(0.08, 0.18, 0.5), Vector3(s, 0.09, 0), WOOD_DARK)
	var feed := FarmAnimal.box(trough, Vector3(1.2, 0.06, 0.32), Vector3(0, 0.46, 0), Color(0.92, 0.78, 0.35) if h.kinds.has("chicken") else Color(0.6, 0.72, 0.3))
	feed.name = "Feed"
	feed.visible = false
	var hid := h.id
	var z := _zone(trough, Vector3(0, 0.6, 0), 1.6, _trough_text(hid), func() -> void:
		GameEvents.notification_requested.emit(Ranch.feed_housing(hid))
		Sfx.play(&"pickup", -8.0, 0.9))
	troughs[h.id] = z


func _trough_text(hid: String) -> String:
	var h := Ranch.housing_def(hid)
	var hungry := 0
	for a: Dictionary in Ranch.animals_in(hid):
		if not bool(a["fed_today"]):
			hungry += 1
	var nm := (h.name_fa if Lang.is_fa() else h.display_name.to_lower()) if h else hid
	if hungry == 0:
		return _t("نگاه به آبشخور %s (همه سیرند)" % nm, "check the %s trough (all fed)" % nm)
	return _t("ریختن علوفه در آبشخور %s (%s گرسنه)" % [nm, Lang.digits(str(hungry))], "fill the %s trough (%d hungry)" % [nm, hungry])


func _fence(parent: Node3D, a: Vector2, b: Vector2) -> void:
	var len := a.distance_to(b)
	if len < 0.2:
		return
	var n := maxi(int(ceil(len / 1.6)), 1)
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		FarmAnimal.box(parent, Vector3(0.1, 1.0, 0.1), Vector3(p.x, _y(p.x, p.y) + 0.45, p.y), WOOD_DARK)
	var dir := (b - a).normalized()
	var yaw := atan2(dir.x, dir.y)
	for i in n:
		var p0 := a.lerp(b, float(i) / n)
		var p1 := a.lerp(b, float(i + 1) / n)
		var mid := (p0 + p1) * 0.5
		var y0 := _y(p0.x, p0.y)
		var y1 := _y(p1.x, p1.y)
		var seg := p0.distance_to(p1)
		var tilt := atan2(y1 - y0, seg)
		for hgt in [0.45, 0.82]:
			FarmAnimal.box(parent, Vector3(0.05, 0.09, seg + 0.05), Vector3(mid.x, (y0 + y1) * 0.5 + hgt, mid.y), WOOD, Vector3(-tilt, yaw, 0))
	var body := StaticBody3D.new()
	var s := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(0.15, 1.6, len)
	s.shape = bx
	var m := (a + b) * 0.5
	body.position = Vector3(m.x, _y(m.x, m.y) + 0.6, m.y)
	body.rotation.y = yaw
	body.add_child(s)
	parent.add_child(body)


func _build_construction(root: Node3D, h: HousingDef) -> void:
	var w := h.size.x
	var d := h.size.z
	var hgt := h.size.y * 0.62
	FarmAnimal.box(root, Vector3(w + 0.2, 0.22, d + 0.2), Vector3(0, 0.1, 0), Color(0.6, 0.58, 0.55))
	for cx in [-w * 0.5, 0.0, w * 0.5]:
		for cz in [-d * 0.5, d * 0.5]:
			FarmAnimal.box(root, Vector3(0.14, hgt, 0.14), Vector3(cx, 0.2 + hgt * 0.5, cz), WOOD)
	for cz in [-d * 0.5, d * 0.5]:
		FarmAnimal.box(root, Vector3(w + 0.1, 0.14, 0.14), Vector3(0, 0.2 + hgt, cz), WOOD)
	for cx in [-w * 0.5, w * 0.5]:
		FarmAnimal.box(root, Vector3(0.14, 0.14, d + 0.1), Vector3(cx, 0.2 + hgt, 0), WOOD)
	# Half-built back wall (planks).
	for i in 5:
		FarmAnimal.box(root, Vector3(w, 0.16, 0.05), Vector3(0, 0.3 + i * 0.18, -d * 0.5), Color(0.72, 0.56, 0.36))
	# Scaffolding.
	for sx in [-w * 0.5 - 0.6, w * 0.5 + 0.6]:
		FarmAnimal.box(root, Vector3(0.06, hgt + 0.8, 0.06), Vector3(sx, (hgt + 0.8) * 0.5, -d * 0.3), Color(0.6, 0.6, 0.62))
		FarmAnimal.box(root, Vector3(0.06, hgt + 0.8, 0.06), Vector3(sx, (hgt + 0.8) * 0.5, d * 0.3), Color(0.6, 0.6, 0.62))
		FarmAnimal.box(root, Vector3(0.5, 0.05, d * 0.7), Vector3(sx, hgt * 0.6, 0), WOOD)
	# Plank stack + sawhorse.
	for i in 6:
		FarmAnimal.box(root, Vector3(2.0, 0.08, 0.25), Vector3(-w * 0.5 - 1.0, 0.05 + i * 0.09, d * 0.5 + 1.0 + (i % 2) * 0.03), Color(0.75, 0.58, 0.38))
	FarmAnimal.box(root, Vector3(0.9, 0.08, 0.1), Vector3(w * 0.5 + 0.4, 0.6, d * 0.5 + 1.4), WOOD_DARK)
	_solid(root, Vector3(w, hgt, d), Vector3(0, hgt * 0.5, 0))
