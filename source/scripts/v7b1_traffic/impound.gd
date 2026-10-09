class_name Impound
extends Node3D
## v7b.1 impound lot (driving_license module): after the 2nd offence a tow
## truck hooks the car and drags it here. It is released at the gate for
## `impound_fee` (to the city fund) - but only once you have your licence back
## (the confiscation wait has passed AND you passed the re-test).

const SLOTS := 4
var lot: Node3D
var gate_spot: ActionSpot
var tows: Array = []          ## [{truck: RoadCar, car: DrivableCar, t}]


func style() -> LicenseStyle:
	return Modules.style("driving_license") as LicenseStyle


func _ready() -> void:
	_build.call_deferred()
	Modules.on_swap("driving_license", self, func(_m: Resource) -> void: _build())
	TrafficState.changed.connect(func(k: String) -> void:
		if k == "all":
			_restore.call_deferred())


func centre() -> Vector3:
	var st := style()
	var p := st.impound_pos if st else Vector2(-60, -24)
	return TrafficKit.ground(p)


func slot_xform(i: int) -> Transform3D:
	var st := style()
	var yaw := deg_to_rad(st.impound_yaw if st else 0.0)
	var b := Basis(Vector3.UP, yaw)
	var local := Vector3(-4.2 + (i % SLOTS) * 2.8, 0, 0.6)
	var p := centre() + b * local
	p.y = Terrain.height_at(p.x, p.z)
	return Transform3D(b, p)


func _build() -> void:
	if lot:
		lot.queue_free()
	var st := style()
	if st == null:
		return
	lot = Node3D.new()
	lot.name = "ImpoundLot"
	add_child(lot)
	var c := centre()
	V7bKit.clear_trees(get_tree(), Rect2(Vector2(c.x - 8.0, c.z - 5.0), Vector2(16.0, 10.0)))
	lot.position = c
	lot.rotation.y = deg_to_rad(st.impound_yaw)
	# Gravel pad + chain-link fence (posts + see-through mesh) + gate.
	var pad := V7aKit.box(lot, Vector3(12.4, 0.06, 7.0), Vector3(0, 0.03, 0.4), TrafficKit.mat(Color(0.5, 0.48, 0.44), 0.95), false)
	pad.name = "Pad"
	var post := TrafficKit.mat(Color(0.45, 0.46, 0.48), 0.5)
	var mesh := TrafficKit.mat(Color(0.6, 0.62, 0.64, 0.35), 0.5)
	mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side in [[Vector3(0, 0, -3.1), 12.4, 0.0], [Vector3(-6.2, 0, 0.4), 7.0, PI * 0.5], [Vector3(6.2, 0, 0.4), 7.0, PI * 0.5]]:
		var p: Vector3 = side[0]
		var length: float = side[1]
		var f := V7aKit.box(lot, Vector3(length, 1.8, 0.03), p + Vector3(0, 0.95, 0), mesh, false)
		f.rotation.y = side[2]
		var n := int(length / 2.0)
		for k in n + 1:
			var off := -length * 0.5 + k * length / n
			var q := p + (Vector3(off, 0, 0) if side[2] == 0.0 else Vector3(0, 0, off))
			V7aKit.cyl(lot, 0.04, 1.9, q + Vector3(0, 0.95, 0), post)
	# Front fence with a gate gap in the middle.
	for sx: float in [-1.0, 1.0]:
		var f2 := V7aKit.box(lot, Vector3(4.4, 1.8, 0.03), Vector3(sx * 4.0, 0.95, 3.9), mesh, false)
		f2.name = "FrontFence"
	V7aKit.box(lot, Vector3(3.6, 0.1, 0.1), Vector3(0, 1.0, 3.9), TrafficKit.mat(Color(0.95, 0.75, 0.1), 0.5))
	var sign := V7bKit.sign(lot, Vector3(4.0, 0.0, 4.3), 0.0, "پارکینگ توقیف خودرو - پلیس راهنمایی و رانندگی", "Impound lot - traffic police", Color(0.12, 0.2, 0.45), 3.6)
	sign.remove_from_group(&"v7b_signs")
	sign.text = "پارکینگ توقیف خودرو\nImpound lot"
	sign.position.y = 1.95
	gate_spot = ActionSpot.make(lot, Vector3(0, 0, 4.6), 1.3, _gate_text, _gate_use)
	gate_spot.name = "ImpoundGate"
	_restore()


func _gate_text() -> String:
	var key := _first_impounded()
	if key == "":
		return Lang.tt("پارکینگ توقیف (خالی)", "impound lot (empty)")
	var st := style()
	return Lang.tt("ترخیص ماشین توقیفی - %s سکه" % Lang.digits(str(st.impound_fee if st else 120)),
		"release the impounded car - %d G" % (st.impound_fee if st else 120))


func _first_impounded() -> String:
	for k in TrafficState.impounded:
		return str(k)
	return ""


func _gate_use(_who: Node3D) -> void:
	release(_first_impounded())


## Release a car: needs the licence back and the fee. Returns true on success.
func release(key: String) -> bool:
	if key == "" or not TrafficState.is_impounded(key):
		return false
	var st := style()
	if not TrafficState.licensed("player"):
		var msg := Lang.tt("اول گواهینامه‌ات را پس بگیر: %s روز صبر + امتحان دوباره در دفتر راهنمایی و رانندگی (اداره‌ی پلیس)." % Lang.digits(str(TrafficState.days_left())),
			"Get your licence back first: wait %d day(s) + retake the test at the traffic desk (police station)." % TrafficState.days_left())
		GameEvents.notification_requested.emit(msg)
		return false
	var fee := st.impound_fee if st else 120
	if Economy.money < fee:
		GameEvents.notification_requested.emit(Lang.tt("پول کافی نداری (%s سکه)." % Lang.digits(str(fee)), "Not enough money (%d G)." % fee))
		return false
	Economy.add_money(-fee)
	CityState.add_income("impound", fee, "Impound release fee", "هزینه‌ی ترخیص خودرو از پارکینگ")
	TrafficState.impounded.erase(key)
	TrafficState.stat("releases")
	var car := car_by_key(key)
	if car:
		_unlock(car)
		var out := centre() + Basis(Vector3.UP, lot.rotation.y) * Vector3(0, 0, 5.4)
		car.global_position = Vector3(out.x, Terrain.height_at(out.x, out.z), out.z)
		car.yaw = lot.rotation.y
		car.rotation = Vector3(0, car.yaw, 0)
		WorldMemory.park(car.key, car.global_position, car.yaw)
	TrafficState.changed.emit("impound")
	GameEvents.notification_requested.emit(Lang.tt("ماشین ترخیص شد. با احتیاط برو!", "Car released. Drive carefully!"))
	return true


func car_by_key(key: String) -> DrivableCar:
	for n in get_tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		if c and c.key == key:
			return c
	return null


## Tow `car` to the lot. instant = no tow truck drive (tests / loading).
func take(car: DrivableCar, instant: bool = false) -> void:
	if car == null:
		return
	if car.driver:
		car.get_out()
	var st := style()
	var idx := TrafficState.impounded.size()
	TrafficState.impounded[car.key] = {"day": TimeManager.day, "fee": st.impound_fee if st else 120, "slot": idx}
	_lock(car)
	if instant or not is_inside_tree():
		_park_in_slot(car, idx)
		return
	# A tow truck pulls up in front, hooks the car and drives it to the lot.
	var truck := RoadCar.new()
	truck.model_name = "delivery"
	truck.name = "TowTruck"
	truck.speed = 8.0
	add_child(truck)
	truck.build_model()
	truck.add_lightbar(Color(1.0, 0.6, 0.05), Color(1.0, 0.85, 0.2))
	truck.set_flashing(true)
	truck.set_meta(&"voice", "delivery")
	truck.add_to_group(&"road_cars")
	var f := car.forward()
	truck.place(car.global_position + f * (car.size.z * 0.5 + 3.0), car.yaw)
	var lbl := TrafficKit.label(truck, "یدک‌کش پلیس", "Police tow", Vector3(0, 2.6, 0), 0.0, 0.004, 48, Color(1, 0.9, 0.4), 8)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var holder := car.get_parent()
	# The hooked car rides along: no own physics / collisions while towed.
	car.set_meta(&"tow_layers", [car.collision_layer, car.collision_mask])
	car.collision_layer = 0
	car.collision_mask = 0
	car.set_physics_process(false)
	truck.add_collision_exception_with(car)
	car.reparent(truck)
	car.position = Vector3(0, 0.25, -(truck.size.z * 0.5 + car.size.z * 0.5 + 0.3))
	car.rotation = Vector3(0.06, 0, 0)
	var tw := {"truck": truck, "car": car, "holder": holder, "t": 0.0, "slot": idx}
	tows.append(tw)
	truck.drive_to(slot_xform(idx).origin + Vector3(0, 0, 9.0), true)
	truck.arrived.connect(func() -> void: _finish_tow(tw), CONNECT_ONE_SHOT)
	GameEvents.notification_requested.emit(Lang.tt("یدک‌کش پلیس ماشین را به پارکینگ توقیف می‌برد.", "The police tow truck takes the car to the impound lot."))


func _finish_tow(tw: Dictionary) -> void:
	if not tows.has(tw):
		return
	tows.erase(tw)
	var car := tw["car"] as DrivableCar
	var truck := tw["truck"] as RoadCar
	if is_instance_valid(car):
		var holder: Node = tw["holder"] if is_instance_valid(tw["holder"]) else get_tree().current_scene
		car.reparent(holder)
		var layers: Array = car.get_meta(&"tow_layers", [car.collision_layer, car.collision_mask])
		car.collision_layer = int(layers[0])
		car.collision_mask = int(layers[1])
		car.remove_meta(&"tow_layers")
		car.set_physics_process(true)
		_park_in_slot(car, int(tw["slot"]))
	if is_instance_valid(truck):
		truck.queue_free()


func _process(delta: float) -> void:
	for tw: Dictionary in tows.duplicate():
		tw["t"] = float(tw["t"]) + delta
		if float(tw["t"]) > 45.0:   # never get stuck: finish the tow
			_finish_tow(tw)


func _park_in_slot(car: DrivableCar, idx: int) -> void:
	var xf := slot_xform(idx)
	car.global_position = xf.origin
	car.yaw = xf.basis.get_euler().y
	car.rotation = Vector3(0, car.yaw, 0)
	WorldMemory.park(car.key, car.global_position, car.yaw)


func _lock(car: DrivableCar) -> void:
	if car.door_spot:
		if not car.has_meta(&"door_can"):
			car.set_meta(&"door_can", car.door_spot.can_fn)
		car.door_spot.can_fn = func() -> bool: return car.driver == null and not TrafficState.is_impounded(car.key)
	car.set_meta(&"impounded", true)


func _unlock(car: DrivableCar) -> void:
	if car.door_spot:
		var orig: Variant = car.get_meta(&"door_can") if car.has_meta(&"door_can") else null
		if orig is Callable and (orig as Callable).is_valid():
			car.door_spot.can_fn = orig
		else:
			car.door_spot.can_fn = func() -> bool: return car.driver == null
		car.remove_meta(&"door_can")
	car.remove_meta(&"impounded")


## After loading / module swaps: impounded cars stand in the lot, locked.
func _restore() -> void:
	var i := 0
	for key in TrafficState.impounded:
		var car := car_by_key(str(key))
		if car:
			_lock(car)
			_park_in_slot(car, i)
		i += 1
	for n in get_tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		if c and c.has_meta(&"impounded") and not TrafficState.is_impounded(c.key):
			_unlock(c)
