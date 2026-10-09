class_name FarmAnimal
extends Node3D
## v5c farm animal in the world (one per Ranch animal). Low-poly procedural
## body from the LivestockDef shape ("bird" chicken, "cow", "sheep"); wanders
## inside its paddock, pecks / grazes when idle, shows its product (egg, milk
## pail, wool puff) when ready and a name tag nearby. E: collect > feed > pet
## (Ranch.interact). Young animals are smaller (chicks are yellow).

var uid: int = 0
var def: LivestockDef
var area: Rect2  ## paddock (world x/z)
var adult: bool = true
var zone: Interactable
var _body: Node3D
var _head: Node3D
var _legs: Array[Node3D] = []
var _icon: Node3D
var _tag: Label3D
var _target: Vector3
var _timer: float = 0.0
var _walking: bool = false
var _phase: float = 0.0
var _rng := RandomNumberGenerator.new()

static var _mats: Dictionary = {}


static func mat(c: Color) -> StandardMaterial3D:
	var key := c.to_html()
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.92
		_mats[key] = m
	return _mats[key]


static func box(parent: Node3D, size: Vector3, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


static func ball(parent: Node3D, radius: float, pos: Vector3, c: Color, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 12
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = mat(c)
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, pos: Vector3, c: Color, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r_top
	cm.bottom_radius = r_bot
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = mat(c)
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	return mi


func setup(a: Dictionary, d: LivestockDef, paddock: Rect2) -> void:
	uid = int(a["uid"])
	def = d
	area = paddock
	name = "Animal_%d" % uid
	_rng.seed = uid * 7919
	adult = bool(a["adult"])
	_build()
	var p := _random_point()
	position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	rotation.y = _rng.randf() * TAU
	_pick_target()
	zone = Interactable.new()
	zone.name = "Interaction"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.position = Vector3(0, 0.6, 0)
	var shape := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.0 if d.shape == "bird" else 1.6
	shape.shape = sp
	zone.add_child(shape)
	add_child(zone)
	zone.interacted.connect(func(_who: Node3D) -> void:
		GameEvents.notification_requested.emit(Ranch.interact(uid))
		Sfx.play(&"pickup", -10.0, 1.4 if def.shape == "bird" else 0.8)
		refresh())
	refresh()


func _build() -> void:
	if _body:
		_body.queue_free()
	_legs.clear()
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var young := not adult
	match def.shape:
		"cow":
			_build_cow(young)
		"sheep":
			_build_sheep(young)
		_:
			_build_bird(young)
	var s := def.size * (def.young_scale if young else 1.0)
	_body.scale = Vector3.ONE * s
	# Product icon (hidden until ready).
	_icon = Node3D.new()
	_icon.name = "ProductIcon"
	add_child(_icon)
	match def.shape:
		"cow":
			cyl(_icon, 0.13, 0.1, 0.22, Vector3.ZERO, Color(0.75, 0.77, 0.8))
			cyl(_icon, 0.115, 0.115, 0.02, Vector3(0, 0.1, 0), Color(1, 1, 1))
			_icon.position = Vector3(0, 2.0, 0)
		"sheep":
			ball(_icon, 0.14, Vector3.ZERO, Color(0.98, 0.97, 0.93))
			ball(_icon, 0.1, Vector3(0.1, 0.05, 0), Color(0.98, 0.97, 0.93))
			_icon.position = Vector3(0, 1.6, 0)
		_:
			ball(_icon, 0.07, Vector3.ZERO, Color(0.98, 0.95, 0.86), Vector3(1, 1.3, 1))
			_icon.position = Vector3(0, 0.95, 0)
	_icon.visible = false
	_tag = Label3D.new()
	_tag.name = "Tag"
	Lang.setup_label3d(_tag, 40)
	_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_tag.pixel_size = 0.004
	_tag.outline_size = 10
	_tag.modulate = Color(1, 0.97, 0.88)
	_tag.position = Vector3(0, (2.3 if def.shape == "cow" else (1.85 if def.shape == "sheep" else 1.2)) * (0.75 if young else 1.0), 0)
	add_child(_tag)


func _leg(parent: Node3D, pos: Vector3, h: float, w: float, c: Color) -> void:
	var pivot := Node3D.new()
	pivot.position = pos
	parent.add_child(pivot)
	box(pivot, Vector3(w, h, w), Vector3(0, -h * 0.5, 0), c)
	_legs.append(pivot)


func _build_bird(young: bool) -> void:
	var body_c := Color(0.98, 0.86, 0.35) if young else def.body_color
	ball(_body, 0.2, Vector3(0, 0.34, 0), body_c, Vector3(1.0, 0.95, 1.25))
	# Tail feathers.
	box(_body, Vector3(0.16, 0.2, 0.06), Vector3(0, 0.46, -0.24), body_c, Vector3(-0.5, 0, 0))
	# Wings.
	ball(_body, 0.11, Vector3(0.17, 0.35, -0.02), body_c.darkened(0.08), Vector3(0.45, 0.8, 1.3))
	ball(_body, 0.11, Vector3(-0.17, 0.35, -0.02), body_c.darkened(0.08), Vector3(0.45, 0.8, 1.3))
	_head = Node3D.new()
	_head.position = Vector3(0, 0.52, 0.18)
	_body.add_child(_head)
	ball(_head, 0.1, Vector3.ZERO, body_c)
	cyl(_head, 0.0, 0.035, 0.09, Vector3(0, -0.01, 0.12), Color(0.95, 0.6, 0.15), Vector3(PI * 0.5, 0, 0))
	ball(_head, 0.018, Vector3(0.065, 0.03, 0.06), Color(0.05, 0.05, 0.05))
	ball(_head, 0.018, Vector3(-0.065, 0.03, 0.06), Color(0.05, 0.05, 0.05))
	if not young:
		box(_head, Vector3(0.03, 0.08, 0.12), Vector3(0, 0.11, 0.0), def.accent_color)
		ball(_head, 0.03, Vector3(0, -0.07, 0.09), def.accent_color, Vector3(0.6, 1.2, 0.6))
	_leg(_body, Vector3(0.07, 0.2, 0), 0.2, 0.025, Color(0.95, 0.6, 0.15))
	_leg(_body, Vector3(-0.07, 0.2, 0), 0.2, 0.025, Color(0.95, 0.6, 0.15))


func _build_cow(young: bool) -> void:
	var c := def.body_color
	var spot := def.accent_color
	var bodyc := MeshInstance3D.new()
	var cap := CapsuleMesh.new()
	cap.radius = 0.38
	cap.height = 1.5
	cap.radial_segments = 14
	cap.rings = 4
	bodyc.mesh = cap
	bodyc.material_override = mat(c)
	bodyc.rotation = Vector3(PI * 0.5, 0, 0)
	bodyc.position = Vector3(0, 0.95, 0)
	bodyc.scale = Vector3(1.0, 1.0, 1.08)
	_body.add_child(bodyc)
	# Black patches.
	for p in [Vector3(0.3, 1.05, 0.25), Vector3(-0.31, 0.95, -0.3), Vector3(0.28, 0.9, -0.45), Vector3(-0.25, 1.2, 0.35), Vector3(0.0, 1.32, -0.1)]:
		ball(_body, 0.2, p, spot, Vector3(0.5 if absf(p.x) > 0.1 else 1.0, 0.8, 1.2))
	_head = Node3D.new()
	_head.position = Vector3(0, 1.15, 0.82)
	_body.add_child(_head)
	box(_head, Vector3(0.36, 0.38, 0.42), Vector3(0, 0, 0.05), c)
	box(_head, Vector3(0.32, 0.2, 0.16), Vector3(0, -0.1, 0.3), Color(0.95, 0.72, 0.7))
	ball(_head, 0.03, Vector3(0.12, 0.08, 0.27), Color(0.05, 0.05, 0.05))
	ball(_head, 0.03, Vector3(-0.12, 0.08, 0.27), Color(0.05, 0.05, 0.05))
	box(_head, Vector3(0.16, 0.06, 0.08), Vector3(0.25, 0.1, -0.05), spot)
	box(_head, Vector3(0.16, 0.06, 0.08), Vector3(-0.25, 0.1, -0.05), spot)
	if not young:
		cyl(_head, 0.012, 0.03, 0.16, Vector3(0.13, 0.25, -0.02), Color(0.92, 0.88, 0.75))
		cyl(_head, 0.012, 0.03, 0.16, Vector3(-0.13, 0.25, -0.02), Color(0.92, 0.88, 0.75))
		ball(_body, 0.13, Vector3(0, 0.6, -0.35), Color(0.95, 0.7, 0.72), Vector3(1.0, 0.7, 1.0))
	box(_body, Vector3(0.05, 0.6, 0.05), Vector3(0, 0.85, -0.95), c, Vector3(0.3, 0, 0))
	for p in [Vector3(0.22, 0.7, 0.5), Vector3(-0.22, 0.7, 0.5), Vector3(0.22, 0.7, -0.5), Vector3(-0.22, 0.7, -0.5)]:
		_leg(_body, p, 0.7, 0.14, c)


func _build_sheep(young: bool) -> void:
	var wool := def.body_color
	ball(_body, 0.42, Vector3(0, 0.7, 0), wool, Vector3(1.0, 0.9, 1.3))
	for p in [Vector3(0.25, 0.9, 0.2), Vector3(-0.25, 0.9, 0.2), Vector3(0.25, 0.9, -0.25), Vector3(-0.25, 0.9, -0.25), Vector3(0, 1.0, 0)]:
		ball(_body, 0.2, p, wool)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.9, 0.55)
	_body.add_child(_head)
	box(_head, Vector3(0.22, 0.26, 0.3), Vector3(0, 0, 0.05), def.accent_color)
	ball(_head, 0.14, Vector3(0, 0.12, -0.02), wool)
	box(_head, Vector3(0.14, 0.05, 0.08), Vector3(0.15, 0.04, -0.02), def.accent_color)
	box(_head, Vector3(0.14, 0.05, 0.08), Vector3(-0.15, 0.04, -0.02), def.accent_color)
	ball(_head, 0.025, Vector3(0.08, 0.04, 0.19), Color(0.95, 0.95, 0.9))
	ball(_head, 0.025, Vector3(-0.08, 0.04, 0.19), Color(0.95, 0.95, 0.9))
	for p in [Vector3(0.17, 0.42, 0.28), Vector3(-0.17, 0.42, 0.28), Vector3(0.17, 0.42, -0.28), Vector3(-0.17, 0.42, -0.28)]:
		_leg(_body, p, 0.42, 0.08, def.accent_color)


func _random_point() -> Vector2:
	var r := area.grow(-0.6)
	return Vector2(_rng.randf_range(r.position.x, r.end.x), _rng.randf_range(r.position.y, r.end.y))


func _pick_target() -> void:
	var p := _random_point()
	_target = Vector3(p.x, 0, p.y)
	_walking = true
	_timer = 8.0


## Re-reads the Ranch state (growth, product, tag, prompt).
func refresh() -> void:
	var a := Ranch.animal(uid)
	if a.is_empty():
		return
	if bool(a["adult"]) != adult:
		adult = bool(a["adult"])
		_build()
	var ready := int(a["product_ready"]) > 0
	_icon.visible = ready
	if def.shape == "sheep":
		_body.scale = Vector3.ONE * def.size * (def.young_scale if not adult else 1.0) * (1.0 if ready or not adult else 0.9)
	var mood := Ranch.mood(a)
	var mood_txt := ""
	if Lang.is_fa():
		mood_txt = {"happy": "خوشحال", "content": "راضی", "unhappy": "ناراحت"}.get(mood, "")
		if not bool(a["fed_today"]):
			mood_txt += " · گرسنه"
		if not adult:
			mood_txt = "کوچولو · " + mood_txt
	else:
		mood_txt = mood
		if not bool(a["fed_today"]):
			mood_txt += " · hungry"
		if not adult:
			mood_txt = "young · " + mood_txt
	_tag.text = "%s\n%s" % [str(a["name"]), mood_txt]
	_tag.modulate = Color(1, 0.97, 0.88) if mood == "happy" else (Color(1, 0.9, 0.6) if mood == "content" else Color(1, 0.6, 0.55))
	if zone:
		zone.set_action_text(Ranch.action_text(uid))


func _process(delta: float) -> void:
	_phase += delta
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p:
		_tag.visible = p.global_position.distance_to(global_position) < 9.0
	if _icon.visible:
		_icon.rotation.y += delta * 1.5
		_icon.position.y += sin(_phase * 3.0) * 0.002
	var speed := def.walk_speed * (0.8 if not adult else 1.0)
	if _walking:
		var to := _target - global_position
		to.y = 0.0
		if to.length() < 0.2 or _timer <= 0.0:
			_walking = false
			_timer = _rng.randf_range(2.0, 6.0)
		else:
			var dir := to.normalized()
			global_position += dir * speed * delta
			rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), 1.0 - exp(-5.0 * delta))
	elif _timer <= 0.0:
		_pick_target()
	_timer -= delta
	global_position.y = Terrain.height_at(global_position.x, global_position.z)
	# Walk cycle / idle peck or graze.
	var swing := sin(_phase * (10.0 if def.shape == "bird" else 6.0)) * (0.5 if _walking else 0.0)
	for i in _legs.size():
		_legs[i].rotation.x = swing * (1.0 if i % 2 == 0 else -1.0) * (1.0 if i < 2 or def.shape == "bird" else -1.0)
	if _head:
		var dip := 0.0
		if not _walking:
			dip = maxf(sin(_phase * (4.0 if def.shape == "bird" else 0.8)), 0.0) * (0.9 if def.shape == "bird" else 0.5)
		_head.rotation.x = dip
