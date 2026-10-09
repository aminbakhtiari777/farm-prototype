class_name PolicePatrol
extends Node3D
## v6b "police_patrol" module: the police car leaves the station during duty
## hours and loops the patrol route on the roads (calm, lights off), parks
## back at the station at night. When a report is filed (WorldMemory
## file_report - e.g. fruit taken from a garden) it drives to the scene with
## lights on, then resumes the patrol. v7 police / justice builds on this.

var car: RoadCar
var loop: PackedVector3Array = PackedVector3Array()
var on_duty: bool = false
var laps: int = 0
var responding: bool = false
var responses: int = 0
var _check: float = 0.0


func style() -> PolicePatrolStyle:
	return Modules.style("police_patrol") as PolicePatrolStyle


func _ready() -> void:
	_spawn()
	Modules.on_swap("police_patrol", self, func(_m: Resource) -> void:
		if car:
			car.queue_free()
		_spawn())
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "reports":
			_respond())


func base_pos() -> Vector3:
	var st := style()
	var b := st.base if st else Vector2(-27, -53.9)
	return Vector3(b.x, Terrain.height_at(b.x, b.y), b.y)


func _spawn() -> void:
	var st := style()
	if st == null:
		return
	car = RoadCar.new()
	car.name = "PoliceCar"
	car.model_name = st.model
	car.speed = st.speed
	add_child(car)
	car.build_model()
	if st.lights:
		car.add_lightbar(Color(0.15, 0.3, 1.0), Color(1.0, 0.12, 0.1))
	car.place(base_pos(), PI * 0.5)
	car.arrived.connect(_on_arrived)
	_build_loop()
	on_duty = false
	responding = false


func _build_loop() -> void:
	var st := style()
	loop = PackedVector3Array()
	if st == null or st.route.size() < 2:
		return
	var center := PackedVector3Array()
	for i in st.route.size():
		var a: Vector2 = st.route[i]
		var b: Vector2 = st.route[(i + 1) % st.route.size()]
		var seg := VehicleKit.route(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y))
		for p in seg:
			if center.is_empty() or center[center.size() - 1].distance_to(p) > 0.5:
				center.append(p)
	loop = VehicleKit.lane(center)


func duty_now() -> bool:
	var st := style()
	if st == null:
		return false
	var h := TimeManager.hours_float()
	return h >= st.hours.x and h < st.hours.y


func _physics_process(delta: float) -> void:
	if car == null:
		return
	_check -= delta
	if _check > 0.0:
		return
	_check = 1.0
	var duty := duty_now()
	if duty and not on_duty:
		on_duty = true
		_start_lap()
	elif not duty and on_duty and not responding:
		on_duty = false
		car.drive_to(base_pos())


func _start_lap() -> void:
	if loop.is_empty():
		return
	# Join the loop at the nearest point, go round once.
	var best := 0
	var bd := INF
	for i in loop.size():
		var d := loop[i].distance_to(Vector3(car.global_position.x, 0, car.global_position.z))
		if d < bd:
			bd = d
			best = i
	var lap := PackedVector3Array()
	for k in loop.size() + 1:
		lap.append(loop[(best + k) % loop.size()])
	car.follow(lap)


func _on_arrived() -> void:
	if responding:
		responding = false
		car.set_flashing(false)
		responses += 1
		await get_tree().create_timer(6.0).timeout
		if not is_instance_valid(car):
			return
	if on_duty and duty_now():
		laps += 1
		_start_lap()
	else:
		car.place(base_pos(), PI * 0.5)


## Drive to the latest report (lights on).
func _respond() -> void:
	if car == null or WorldMemory.reports.is_empty():
		return
	var r: Dictionary = WorldMemory.reports[WorldMemory.reports.size() - 1]
	var home := str(r.get("home", ""))
	var target := TownNav.spot_position("door:" + home) if home != "" else Vector3.INF
	if target == Vector3.INF:
		return
	responding = true
	car.set_flashing(true)
	car.drive_to(target, false)
