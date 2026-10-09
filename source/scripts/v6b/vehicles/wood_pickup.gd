class_name WoodPickup
extends Node3D
## v6b "wood_pickup" module: the carpenter's red pickup works the dry trees.
## At its start hours it drives from the carpenter's yard to the forest edge,
## the woodcutter fells the nearest dry tree (it becomes a stump - the same
## trees the farmer chops, Lifestyle.felled), the logs are loaded into the bed
## (visible), and it drives them back: the carpenter's log pile grows and the
## market gets the dry wood (Market.add) - more supply, steadier prices.

enum State { PARKED, TO_FOREST, CHOPPING, TO_YARD, UNLOADING }

var car: RoadCar
var state: State = State.PARKED
var logs_loaded: int = 0
var logs_delivered: int = 0
var trips: int = 0
var trips_today: int = 0
var tree_index: int = -1
var worker: HumanoidModelVisual
var _bed_logs: Node3D
var _pile: Node3D
var _timer: float = 0.0
var _chop_t: float = 0.0
var _last_hour: int = -1
var _day: int = -1


func style() -> WoodPickupStyle:
	return Modules.style("wood_pickup") as WoodPickupStyle


func _ready() -> void:
	_spawn()
	Modules.on_swap("wood_pickup", self, func(_m: Resource) -> void:
		for c in get_children():
			c.queue_free()
		worker = null
		_spawn())


func yard_pos() -> Vector3:
	var st := style()
	var y := st.yard if st else Vector2(-28, -45.2)
	return Vector3(y.x, Terrain.height_at(y.x, y.y), y.y)


func forest_pos() -> Vector3:
	var st := style()
	var f := st.forest_stop if st else Vector2(-70, -46)
	return Vector3(f.x, Terrain.height_at(f.x, f.y), f.y)


func _spawn() -> void:
	var st := style()
	if st == null:
		return
	car = RoadCar.new()
	car.name = "WoodPickup"
	car.speed = st.speed
	add_child(car)
	_build_pickup(st.color)
	car.place(yard_pos(), -PI * 0.5)
	car.arrived.connect(_on_arrived)
	_pile = Node3D.new()
	_pile.name = "LogPile"
	add_child(_pile)
	var yp := yard_pos() + Vector3(2.6, 0, 1.6)
	_pile.global_position = yp
	state = State.PARKED
	logs_loaded = 0
	_refresh_bed()
	_refresh_pile()


static func _mat(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
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


## v7b.1: use the car_bodies pickup (opaque paint, glass, interior) so it is
## not pink; bed logs still sit in the open bed.
func _build_pickup(color: Color) -> void:
	car.model_name = "pickup"
	var m := CarBody.build("pickup", 5.0, 4)  # palette red
	if m.is_empty():
		m = VehicleKit.model("pickup", 5.0)
	if m.is_empty():
		push_warning("WoodPickup: no pickup body")
		return
	var root: Node3D = m[0]
	# Tint body panels to the wood_pickup module colour (still opaque, no tex).
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var mat := mi.material_override as StandardMaterial3D
		if mat and mat.albedo_texture == null and mat.albedo_color.a > 0.9 and mat.roughness >= 0.25 and mat.roughness <= 0.55 and mat.metallic <= 0.35:
			var nm := mat.duplicate() as StandardMaterial3D
			nm.albedo_color = Color(color.r, color.g, color.b, 1.0)
			mi.material_override = nm
	car.add_child(root)
	car.model_root = root
	car.size = m[1] if m.size() > 1 else Vector3(1.9, 1.7, 5.0)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(car.size.x, maxf(car.size.y - 0.4, 1.0), car.size.z)
	cs.shape = bs
	cs.position = Vector3(0, bs.size.y * 0.5 + 0.2, 0)
	car.add_child(cs)
	_bed_logs = Node3D.new()
	_bed_logs.name = "BedLogs"
	car.add_child(_bed_logs)


static func _log_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.17
	m.bottom_radius = 0.19
	m.height = 1.9
	m.radial_segments = 8
	return m


func _refresh_bed() -> void:
	if _bed_logs == null:
		return
	for c in _bed_logs.get_children():
		c.queue_free()
	var bark := _mat(Color(0.36, 0.25, 0.16), 0.95)
	var lm := _log_mesh()
	for i in logs_loaded:
		var mi := MeshInstance3D.new()
		mi.mesh = lm
		mi.material_override = bark
		mi.rotation.x = PI * 0.5
		mi.position = Vector3(-0.5 + (i % 3) * 0.42 + (0.2 if i >= 3 else 0.0), 1.0 + 0.32 * int(i / 3), -1.25)
		_bed_logs.add_child(mi)


func _refresh_pile() -> void:
	if _pile == null:
		return
	for c in _pile.get_children():
		c.queue_free()
	var bark := _mat(Color(0.4, 0.28, 0.17), 0.95)
	var lm := _log_mesh()
	var n := mini(logs_delivered, 15)
	var row := 0
	var placed := 0
	while placed < n:
		var in_row := 5 - row
		for k in in_row:
			if placed >= n:
				break
			var mi := MeshInstance3D.new()
			mi.mesh = lm
			mi.material_override = bark
			mi.rotation.z = PI * 0.5
			mi.position = Vector3(0, 0.19 + row * 0.33, (k - (in_row - 1) * 0.5) * 0.4)
			_pile.add_child(mi)
			placed += 1
		row += 1


func _physics_process(delta: float) -> void:
	if car == null:
		return
	var st := style()
	if TimeManager.day != _day:
		_day = TimeManager.day
		trips_today = 0
	var h := TimeManager.hour()
	if h != _last_hour:
		_last_hour = h
		if state == State.PARKED and st and h in st.start_hours and trips_today < st.trips_per_day:
			start_trip()
	match state:
		State.CHOPPING:
			_timer += delta
			_chop_t -= delta
			if _chop_t <= 0.0:
				_chop_t = 0.7
				if worker:
					worker.play_action(&"use")
				Sfx.play_at(&"chop", forest_pos(), -10.0)
			if _timer >= (st.chop_seconds if st else 4.0):
				_fell_and_load()
		State.UNLOADING:
			_timer += delta
			if _timer >= 1.5:
				_deliver()


## Leave for the forest now (also used by the tests).
func start_trip() -> bool:
	if car == null or state != State.PARKED:
		return false
	tree_index = _pick_tree()
	state = State.TO_FOREST
	trips_today += 1
	car.drive_to(forest_pos())
	return true


func _pick_tree() -> int:
	var dt := get_tree().get_first_node_in_group(&"dry_trees") as DryTrees
	var spots: Array[Vector2] = dt.spots if dt else DryTrees.compute_spots(30)
	var best := -1
	var bd := INF
	var f := forest_pos()
	for i in spots.size():
		if Lifestyle.is_felled(i):
			continue
		var d := spots[i].distance_to(Vector2(f.x, f.z))
		if d < bd:
			bd = d
			best = i
	return best


func _on_arrived() -> void:
	match state:
		State.TO_FOREST:
			state = State.CHOPPING
			_timer = 0.0
			_chop_t = 0.0
			_show_worker(true)
		State.TO_YARD:
			state = State.UNLOADING
			_timer = 0.0
			_show_worker(true)


func _tree_pos() -> Vector3:
	var dt := get_tree().get_first_node_in_group(&"dry_trees") as DryTrees
	if dt and tree_index >= 0 and tree_index < dt.spots.size():
		var p := dt.spots[tree_index]
		return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	return forest_pos() + Vector3(-3, 0, 0)


func _show_worker(on: bool) -> void:
	if worker == null:
		worker = HumanoidModelVisual.new()
		worker.name = "Woodcutter"
		worker.shirt_color = Color(0.6, 0.18, 0.15)
		worker.pants_color = Color(0.25, 0.22, 0.18)
		worker.top_style = "work_shirt"
		worker.beard = true
		worker.hair_style = "Hair_Buzzed"
		add_child(worker)
	worker.visible = on
	if not on:
		return
	var at: Vector3
	var look: Vector3
	if state == State.CHOPPING:
		var t := _tree_pos()
		var away := (car.global_position - t)
		away.y = 0.0
		at = t + away.normalized() * 1.1
		look = t
	else:
		at = car.global_position - car.forward() * (car.size.z * 0.5 + 0.8)
		look = _pile.global_position
	worker.global_position = Vector3(at.x, Terrain.height_at(at.x, at.z), at.z)
	var d := look - worker.global_position
	worker.rotation.y = atan2(d.x, d.z)


func _fell_and_load() -> void:
	var st := style()
	if tree_index >= 0 and not Lifestyle.is_felled(tree_index):
		Lifestyle.felled[tree_index] = TimeManager.day
		Lifestyle.trees_changed.emit()
	logs_loaded = st.logs_per_trip if st else 3
	_refresh_bed()
	_show_worker(false)
	state = State.TO_YARD
	car.drive_to(yard_pos())


func _deliver() -> void:
	var n := logs_loaded
	logs_loaded = 0
	logs_delivered += n
	trips += 1
	_refresh_bed()
	_refresh_pile()
	Market.add("dry_wood", float(n))
	Market.add("wood_plank", float(n))
	_show_worker(false)
	state = State.PARKED
	car.place(yard_pos(), -PI * 0.5)


func status() -> String:
	return ["parked", "to_forest", "chopping", "to_yard", "unloading"][state]
