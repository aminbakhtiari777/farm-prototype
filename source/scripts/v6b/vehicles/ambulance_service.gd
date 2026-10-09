class_name AmbulanceService
extends Node3D
## v6b "ambulance" module: when a townsperson falls ill (Needs.fell_ill) the
## ambulance may be dispatched (chance per illness). It drives with lights on
## to the patient, the crew steps out, the patient is helped in, it drives to
## the hospital, the patient is dropped at the door and goes to the doctor
## (the Needs hospital flow), then the ambulance returns to its bay.

enum State { IDLE, TO_PATIENT, LOADING, TO_HOSPITAL, UNLOADING, RETURNING }

var car: RoadCar
var state: State = State.IDLE
var patient: TownspersonBot
var crew: Array[HumanoidModelVisual] = []
var calls: int = 0
var delivered: int = 0
var queue: Array = []
## Off = only explicit call_patient() (tests); on = sick townspeople may be picked up.
var auto_dispatch: bool = true
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()


class RideController extends BotController:
	## Takes over the patient while the ambulance handles them.
	var original: BotController
	var stage: String = "wait"   # wait | walk | ride
	var target: Vector3
	func tick(bot: Node3D, _delta: float) -> Dictionary:
		match stage:
			"ride":
				return {"hidden": true}
			"walk":
				var to := target - bot.global_position
				to.y = 0.0
				if to.length() < 0.8:
					return {"move": Vector3.ZERO, "face": atan2(to.x, to.z)}
				return {"move": to.normalized() * 0.9}
		var t2 := target - bot.global_position
		return {"move": Vector3.ZERO, "face": atan2(t2.x, t2.z)}
	func on_greeted(_bot: Node3D, _player: Node3D) -> String:
		return Lang.tt("آمبولانس آمده... حالم خوب نیست.", "The ambulance is here... I don't feel well.")
	func describe() -> String:
		return "ambulance:" + stage


func style() -> AmbulanceStyle:
	return Modules.style("ambulance") as AmbulanceStyle


func _ready() -> void:
	_rng.randomize()
	_spawn()
	Needs.fell_ill.connect(_on_fell_ill)
	Modules.on_swap("ambulance", self, func(_m: Resource) -> void:
		_finish_patient(true)
		if car:
			car.queue_free()
		_spawn())


func base_pos() -> Vector3:
	var st := style()
	var b := st.base if st else Vector2(41.5, -53.9)
	return Vector3(b.x, Terrain.height_at(b.x, b.y), b.y)


func _spawn() -> void:
	var st := style()
	if st == null:
		return
	car = RoadCar.new()
	car.name = "Ambulance"
	car.model_name = st.model
	car.speed = st.speed
	add_child(car)
	car.build_model()
	car.add_lightbar(Color(1.0, 0.15, 0.1), Color(0.95, 0.95, 1.0))
	car.place(base_pos(), -PI * 0.5)
	car.arrived.connect(_on_arrived)
	state = State.IDLE
	for c in crew:
		c.queue_free()
	crew.clear()


func _bot_by_key(key: String) -> TownspersonBot:
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var b := n as TownspersonBot
		if b and Friendship.key_of(b) == key:
			return b
	return null


func dispatch_chance(illness: String) -> float:
	var st := style()
	if st == null:
		return 0.0
	return float(st.dispatch.get(illness, st.dispatch.get("*", 0.0)))


func _on_fell_ill(who: String, illness: String) -> void:
	if who == "" or who == "player" or not auto_dispatch:
		return
	if _rng.randf() >= dispatch_chance(illness):
		return
	var b := _bot_by_key(who)
	if b == null:
		return
	call_patient(b)


## Sends the ambulance to this townsperson (queued if it is busy).
func call_patient(b: TownspersonBot) -> bool:
	if car == null or b == null:
		return false
	if state != State.IDLE and state != State.RETURNING:
		if not queue.has(b) and b != patient:
			queue.append(b)
		return false
	patient = b
	calls += 1
	var rc := RideController.new()
	rc.original = b.controller
	rc.target = b.global_position
	b.set_controller(rc)
	state = State.TO_PATIENT
	car.set_flashing(true)
	car.drive_to(b.global_position, false)
	if not b.hidden_inside:
		b.say(Lang.tt("کمک! حالم بد است...", "Help... I feel awful."), 3.0)
	WorldMemory.npc_remember(Friendship.key_of(b), "ambulance", "The ambulance took me to hospital.", "آمبولانس مرا به بیمارستان برد.")
	return true


func _ride() -> RideController:
	return patient.controller as RideController if patient and is_instance_valid(patient) else null


func _on_arrived() -> void:
	match state:
		State.TO_PATIENT:
			state = State.LOADING
			_timer = 0.0
			_show_crew(true)
			var rc := _ride()
			if rc:
				rc.stage = "walk"
				rc.target = _rear()
		State.TO_HOSPITAL:
			state = State.UNLOADING
			_timer = 0.0
			_show_crew(true)
			_drop_patient()
		State.RETURNING:
			state = State.IDLE
			car.set_flashing(false)
			car.place(base_pos(), -PI * 0.5)
			if not queue.is_empty():
				var nb: TownspersonBot = queue.pop_front()
				if is_instance_valid(nb) and Needs.npc_is_ill(nb):
					call_patient(nb)


func _rear() -> Vector3:
	return car.global_position - car.forward() * (car.size.z * 0.5 + 0.9)


func _physics_process(delta: float) -> void:
	if car == null:
		return
	match state:
		State.LOADING:
			_timer += delta
			var rc := _ride()
			if rc == null:
				_go_back()
				return
			rc.target = _rear()
			var near := patient.global_position.distance_to(_rear()) < 1.6
			# Patients inside a building / far off the road are carried out.
			if near or _timer > 10.0 or patient.hidden_inside:
				if _timer > 2.0:
					rc.stage = "ride"
					patient.global_position = _rear()
					_show_crew(false)
					state = State.TO_HOSPITAL
					var door := TownNav.spot_position(Townspeople._spot_for("hospital", "door:"))
					if door == Vector3.INF:
						door = base_pos()
					car.drive_to(door, false)
		State.UNLOADING:
			_timer += delta
			if _timer > 2.5:
				_show_crew(false)
				_go_back()


func _drop_patient() -> void:
	var rc := _ride()
	if rc == null:
		return
	var door := TownNav.spot_position(Townspeople._spot_for("hospital", "door:"))
	if door == Vector3.INF:
		door = _rear()
	patient.global_position = door + Vector3(0, 0.1, 0)
	_finish_patient(false)
	delivered += 1


## Hands the patient back to their routine (and the Needs doctor flow).
func _finish_patient(_cancel: bool) -> void:
	if patient == null or not is_instance_valid(patient):
		patient = null
		return
	var rc := patient.controller as RideController
	if rc:
		patient.set_controller(rc.original)
		if Needs.npc_is_ill(patient):
			Needs._send_to_doctor(patient)
	patient = null


## Back to base, idle, nothing queued (tests / module swap).
func reset() -> void:
	_finish_patient(true)
	queue.clear()
	state = State.IDLE
	if car:
		car.stop()
		car.set_flashing(false)
		car.place(base_pos(), -PI * 0.5)
	_show_crew(false)


func _go_back() -> void:
	state = State.RETURNING
	car.set_flashing(false)
	car.drive_to(base_pos())


func _show_crew(on: bool) -> void:
	var st := style()
	var n := st.crew if st else 2
	while crew.size() < n:
		var v := HumanoidModelVisual.new()
		v.name = "Paramedic%d" % crew.size()
		v.body_type = "male" if crew.size() % 2 == 0 else "female"
		v.shirt_color = st.crew_shirt if st else Color(0.92, 0.94, 0.95)
		v.pants_color = st.crew_pants if st else Color(0.2, 0.3, 0.55)
		v.top_style = "jacket"
		v.hair_style = "Hair_Buzzed" if crew.size() % 2 == 0 else "Hair_Buns"
		v.visible = false
		add_child(v)
		crew.append(v)
	var right := Vector3(-car.forward().z, 0, car.forward().x)
	for i in crew.size():
		var c := crew[i]
		c.visible = on
		if on:
			var p := _rear() + right * (0.7 if i == 0 else -0.7) - car.forward() * 0.3
			c.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
			var face := patient.global_position - c.global_position if patient and is_instance_valid(patient) else -car.forward()
			c.rotation.y = atan2(face.x, face.z)


func status() -> String:
	return ["idle", "to_patient", "loading", "to_hospital", "unloading", "returning"][state]
