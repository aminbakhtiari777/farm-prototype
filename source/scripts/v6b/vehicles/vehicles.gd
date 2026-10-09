class_name Vehicles
extends Node3D
## v6b "vehicles" module: the town's parked cars become DrivableCars (they
## replace TownBuilder's static parked cars). Positions come from the module;
## wherever the farmer parks one is remembered (WorldMemory "cars") and
## restored on load. A car dealership comes later (v7+): see dealership_note.

var cars: Array[DrivableCar] = []


func style() -> VehicleStyle:
	return Modules.style("vehicles") as VehicleStyle


func _ready() -> void:
	_spawn()
	Modules.on_swap("vehicles", self, func(_m: Resource) -> void: _respawn())
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "all":
			var c := driven_car()
			if c:
				var keep := c.driver.global_position
				var who := c.driver
				c.get_out()
				who.global_position = keep
			_apply_memory())


func _respawn() -> void:
	for c in cars:
		if c.driver:
			c.get_out()
		c.queue_free()
	cars.clear()
	_spawn()


func _spawn() -> void:
	var st := style()
	if st == null:
		return
	var i := 0
	for d: Dictionary in st.cars:
		if not bool(d.get("drivable", true)):
			continue
		var car := DrivableCar.new()
		car.name = "Car%d" % i
		car.key = "car%d_%s" % [i, str(d.get("model", "sedan"))]
		car.model_name = str(d.get("model", "sedan"))
		var p: Vector2 = d.get("pos", Vector2.ZERO)
		car.yaw = deg_to_rad(float(d.get("yaw", 0.0)))
		car.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		car.set_meta(&"home_pos", car.position)
		car.set_meta(&"home_yaw", car.yaw)
		add_child(car)
		cars.append(car)
		i += 1
	_apply_memory()


func _apply_memory() -> void:
	for c in cars:
		if c.driver:
			continue
		var m := WorldMemory.cars.get(c.key, {}) as Dictionary
		if m.is_empty() or not WorldMemory.keeps("cars"):
			c.global_position = c.get_meta(&"home_pos")
			c.yaw = float(c.get_meta(&"home_yaw"))
		else:
			c.global_position = WorldMemory.vec(m.get("p"))
			c.yaw = float(m.get("yaw", 0.0))
		c.rotation = Vector3(0, c.yaw, 0)


func driven_car() -> DrivableCar:
	for c in cars:
		if c.driver:
			return c
	return null


func dealership_note() -> String:
	var st := style()
	if st == null:
		return ""
	return Lang.tt(st.dealership_note_fa, st.dealership_note_en)
