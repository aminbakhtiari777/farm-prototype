class_name Herding
extends Node3D
## v6b "herding" module: a small flock grazes in the west meadow every
## morning. Sheep shy away from the farmer (flee radius) and keep together,
## so you can walk behind them and herd them through the gate into the pen.
## When the whole flock is inside, the shepherd's fee is paid once a day
## (and the yard routine's "pen the sheep" job is done). Saved in WorldMemory.

const SHEEP_SCENE := preload("res://scenes/animals/Sheep.tscn")

var flock: Array[Sheep] = []
var pen_body: StaticBody3D
var penned_today: bool = false
signal penned(count: int)


func style() -> HerdingStyle:
	return Modules.style("herding") as HerdingStyle


func _ready() -> void:
	add_to_group(&"herding")
	_build()
	Modules.on_swap("herding", self, func(_m: Resource) -> void: _build())
	TimeManager.day_started.connect(func(_d: int) -> void: release_to_meadow())
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "all":
			_from_memory())


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _build() -> void:
	for c in get_children():
		c.queue_free()
	flock.clear()
	var st := style()
	if st == null:
		return
	_build_pen(st)
	for i in st.flock:
		var s := SHEEP_SCENE.instantiate() as Sheep
		s.name = "HerdSheep%d" % i
		s.display_name = Lang.tt("گوسفند گله", "Flock sheep")
		s.wander_radius = 2.5
		add_child(s)
		s.add_to_group(&"herd_sheep")
		flock.append(s)
	_from_memory()


func _build_pen(st: HerdingStyle) -> void:
	var r := st.pen
	var wood := _mat(Color(0.5, 0.36, 0.22))
	pen_body = StaticBody3D.new()
	pen_body.name = "PenFence"
	add_child(pen_body)
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	# Sides: 0 north (z min), 1 east, 2 south, 3 west. Gate = a gap in one side.
	var gate: int = {"north": 0, "east": 1, "south": 2, "west": 3}.get(st.gate_side, 3)
	for i in 4:
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var segs: Array = [[a, b]]
		if i == gate:
			var mid := (a + b) * 0.5
			var dir := (b - a).normalized()
			segs = [[a, mid - dir * 1.4], [mid + dir * 1.4, b]]
			for gp in [mid - dir * 1.4, mid + dir * 1.4]:
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.16, 1.3, 0.16)
				post.mesh = pm
				post.material_override = wood
				post.position = Vector3(gp.x, Terrain.height_at(gp.x, gp.y) + 0.65, gp.y)
				add_child(post)
		for sg in segs:
			var p0: Vector2 = sg[0]
			var p1: Vector2 = sg[1]
			var length := p0.distance_to(p1)
			var mid2 := (p0 + p1) * 0.5
			var yaw := atan2(p1.x - p0.x, p1.y - p0.y)
			var y := Terrain.height_at(mid2.x, mid2.y)
			for h: float in [0.35, 0.75]:
				var rail := MeshInstance3D.new()
				var bm := BoxMesh.new()
				bm.size = Vector3(0.07, 0.1, length)
				rail.mesh = bm
				rail.material_override = wood
				rail.position = Vector3(mid2.x, y + h, mid2.y)
				rail.rotation.y = yaw
				add_child(rail)
			var posts := int(length / 1.6) + 1
			for k in posts + 1:
				var pp := p0.lerp(p1, float(k) / maxf(posts, 1))
				var post2 := MeshInstance3D.new()
				var pm2 := BoxMesh.new()
				pm2.size = Vector3(0.1, 0.95, 0.1)
				post2.mesh = pm2
				post2.material_override = wood
				post2.position = Vector3(pp.x, Terrain.height_at(pp.x, pp.y) + 0.47, pp.y)
				add_child(post2)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.14, 1.0, length)
			cs.shape = bs
			cs.position = Vector3(mid2.x, y + 0.5, mid2.y)
			cs.rotation.y = yaw
			pen_body.add_child(cs)
	# Water trough + hay inside.
	var c := r.get_center()
	var trough := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(1.6, 0.4, 0.5)
	trough.mesh = tm
	trough.material_override = wood
	trough.position = Vector3(c.x + r.size.x * 0.3, Terrain.height_at(c.x, c.y) + 0.2, c.y - r.size.y * 0.3)
	add_child(trough)
	var hay := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.55
	hm.bottom_radius = 0.55
	hm.height = 0.9
	hay.mesh = hm
	hay.material_override = _mat(Color(0.86, 0.74, 0.4))
	hay.rotation.z = PI * 0.5
	hay.position = Vector3(c.x + r.size.x * 0.3, Terrain.height_at(c.x, c.y) + 0.55, c.y + r.size.y * 0.25)
	add_child(hay)
	var sign := Label3D.new()
	Lang.setup_label3d(sign, 36)
	sign.text = Lang.tt("آغل گوسفندها", "Sheep pen")
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.pixel_size = 0.005
	sign.visibility_range_end = 25.0
	var gp2: Vector2 = (corners[gate] + corners[(gate + 1) % 4]) * 0.5
	sign.position = Vector3(gp2.x, Terrain.height_at(gp2.x, gp2.y) + 1.7, gp2.y)
	add_child(sign)


func _from_memory() -> void:
	var st := style()
	if st == null:
		return
	penned_today = int(WorldMemory.herd.get("penned_day", -1)) == TimeManager.day
	if penned_today:
		_place_in(st.pen.get_center(), 2.0)
	else:
		release_to_meadow()


func _place_in(c: Vector2, r: float) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	for s in flock:
		var p := c + Vector2(rng.randf_range(-r, r), rng.randf_range(-r, r))
		s.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.1, p.y)
		s.set("_home", s.global_position)
		s.velocity = Vector3.ZERO


## Morning: the flock goes back out to graze.
func release_to_meadow() -> void:
	var st := style()
	if st == null:
		return
	penned_today = false
	_place_in(st.meadow, st.meadow_radius * 0.5)
	for s in flock:
		s.wander_radius = 3.0


func in_pen(s: Sheep) -> bool:
	var st := style()
	return st != null and st.pen.grow(-0.2).has_point(Vector2(s.global_position.x, s.global_position.z))


func count_in_pen() -> int:
	var n := 0
	for s in flock:
		if in_pen(s):
			n += 1
	return n


func _physics_process(_delta: float) -> void:
	var st := style()
	if st == null or flock.is_empty():
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var center := Vector3.ZERO
	for s in flock:
		center += s.global_position
	center /= flock.size()
	for s in flock:
		var inside := in_pen(s)
		var flee := false
		if player and not inside:
			var away := s.global_position - player.global_position
			away.y = 0.0
			if away.length() < st.flee_radius:
				flee = true
				# Away from the farmer, a little toward the flock (they stick together).
				var to_c := center - s.global_position
				to_c.y = 0.0
				var dir := away.normalized() * 1.0 + to_c.normalized() * (0.35 if to_c.length() > 2.0 else 0.0)
				var tgt := s.global_position + dir.normalized() * 2.5
				s.set("state", Sheep.State.WANDER)
				s.set("_target", tgt)
				s.set("_state_timer", 1.5)
				s.walk_speed = st.flee_speed
				s.set("_home", tgt)
		if not flee:
			s.walk_speed = 0.9
		if inside:
			s.set("_home", Vector3(st.pen.get_center().x, s.global_position.y, st.pen.get_center().y))
			s.wander_radius = 2.0
	if not penned_today and count_in_pen() == flock.size():
		penned_today = true
		WorldMemory.herd["penned_day"] = TimeManager.day
		WorldMemory.herd["pens"] = int(WorldMemory.herd.get("pens", 0)) + 1
		WorldMemory.changed.emit("herd")
		Economy.add_money(st.reward)
		GameEvents.notification_requested.emit(Lang.tt("همه‌ی گوسفندها در آغل‌اند! +%s سکه" % Lang.digits(str(st.reward)), "All the sheep are in the pen! +%d G" % st.reward))
		penned.emit(flock.size())
