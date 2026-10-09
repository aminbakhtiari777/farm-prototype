class_name Dealership
extends Node3D
## v7b.1 car_dealership module: "Town Motors" lot at the east end of Main St by
## the road to the new city. Display cars with price boards; E at a car (or the
## sales cabin) opens the DealershipPanel. Buying needs a valid driving licence
## and the money; the car is yours (TrafficState.owned, saved) and it is
## remembered where you park it (WorldMemory).

var panel: DealershipPanel
var lot: Node3D
var owned_cars: Array[DrivableCar] = []
var _n: int = 0


func style() -> DealershipStyle:
	return Modules.style("car_dealership") as DealershipStyle


func _ready() -> void:
	_build.call_deferred()
	Modules.on_swap("car_dealership", self, func(_m: Resource) -> void: _build())
	TrafficState.changed.connect(func(k: String) -> void:
		if k == "all":
			_spawn_owned.call_deferred())


func _t(d: Variant) -> String:
	return str((d as Dictionary).get("fa" if Lang.is_fa() else "en", "")) if d is Dictionary else str(d)


func _build() -> void:
	if lot:
		lot.queue_free()
	var st := style()
	if st == null:
		return
	lot = Node3D.new()
	lot.name = "DealershipLot"
	add_child(lot)
	lot.position = TrafficKit.ground(st.pos)
	lot.rotation.y = deg_to_rad(st.yaw)
	var w := st.size.x
	var d := st.size.y
	V7aKit.box(lot, Vector3(w, 0.08, d), Vector3(0, 0.04, 0), TrafficKit.mat(Color(0.32, 0.33, 0.35), 0.85), false)
	# Painted bays.
	for i in 4:
		V7aKit.box(lot, Vector3(w - 1.4, 0.01, 0.08), Vector3(0.0, 0.085, -d * 0.5 + 1.2 + i * 3.0), TrafficKit.mat(Color(0.95, 0.95, 0.9), 0.6), false)
	# Bunting poles + flags.
	var flag_cols := [Color(0.9, 0.15, 0.12), Color(0.95, 0.85, 0.2), Color(0.15, 0.45, 0.85), Color(0.2, 0.7, 0.35)]
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			V7aKit.cyl(lot, 0.05, 4.2, Vector3(sx * w * 0.5, 2.1, sz * d * 0.5), TrafficKit.mat(Color(0.85, 0.85, 0.88), 0.4))
	for k in 10:
		var t := float(k) / 9.0
		var f := V7aKit.box(lot, Vector3(0.02, 0.32, 0.28), Vector3(w * 0.5, 3.85 - sin(t * PI) * 0.4, -d * 0.5 + t * d), flag_cols[k % 4], false)
		f.rotation.z = 0.15
	# Big sign facing the road (south).
	var sign := V7bKit.sign(lot, Vector3(-w * 0.5 + 0.2, 0.0, d * 0.5 + 0.4), 0.0, _t(st.name), _t(st.name), Color(0.55, 0.08, 0.1), 3.2)
	sign.remove_from_group(&"v7b_signs")
	sign.text = "%s\n%s" % [str(st.name.get("fa", "")), str(st.name.get("en", ""))]
	sign.position.y = 1.95
	sign.font_size = 52
	sign.get_parent().position.x += 1.4
	# Sales cabin at the back.
	V7aKit.box(lot, Vector3(2.6, 2.5, 2.0), Vector3(w * 0.5 - 1.6, 1.25, -d * 0.5 + 1.2), TrafficKit.mat(Color(0.95, 0.95, 0.92), 0.6))
	V7aKit.box(lot, Vector3(2.8, 0.12, 2.2), Vector3(w * 0.5 - 1.6, 2.55, -d * 0.5 + 1.2), TrafficKit.mat(Color(0.55, 0.08, 0.1), 0.6))
	V7aKit.box(lot, Vector3(1.4, 0.9, 0.04), Vector3(w * 0.5 - 1.6, 1.4, -d * 0.5 + 2.21), TrafficKit.mat(Color(0.5, 0.7, 0.85, 0.6), 0.1))
	ActionSpot.make(lot, Vector3(w * 0.5 - 1.6, 0, -d * 0.5 + 2.9), 1.2,
		func() -> String: return Lang.tt("نمایشگاه خودرو - خرید ماشین", "car dealership - buy a car"),
		func(_w: Node3D) -> void: open()).name = "SalesSpot"
	# Display cars (models only) with price boards.
	var i := 0
	for c: Dictionary in st.cars:
		var z := -d * 0.5 + 2.7 + i * 3.0
		var m := VehicleKit.model(str(c.get("model", "sedan")))
		if not m.is_empty():
			var holder := m[0] as Node3D
			holder.name = "Display_%s" % str(c.get("id", i))
			holder.position = Vector3(-0.9, 0.08, z)
			holder.rotation.y = PI * 0.5
			lot.add_child(holder)
		var board := Node3D.new()
		board.position = Vector3(1.9, 0.0, z)
		board.rotation.y = PI * 0.5 - 0.6
		lot.add_child(board)
		V7aKit.cyl(board, 0.03, 1.1, Vector3(0, 0.55, 0), Color(0.3, 0.3, 0.32))
		V7aKit.box(board, Vector3(1.0, 0.5, 0.03), Vector3(0, 1.2, 0), TrafficKit.mat(Color(0.98, 0.97, 0.9), 0.6))
		var l := TrafficKit.label(board, "%s\n%s سکه" % [str(c.get("fa", "")), Lang.digits(str(int(c.get("price", 0))))],
			"%s\n%d G" % [str(c.get("en", "")), int(c.get("price", 0))], Vector3(0, 1.2, 0.02), 0.0, 0.0026, 44, Color(0.1, 0.1, 0.1))
		l.name = "Price"
		ActionSpot.make(lot, Vector3(1.1, 0, z), 1.0,
			func() -> String: return Lang.tt("خرید %s" % str(c.get("fa", "")), "buy the %s" % str(c.get("en", ""))),
			func(_w: Node3D) -> void: open()).name = "BuySpot%d" % i
		i += 1
	_spawn_owned.call_deferred()


func open() -> void:
	if panel:
		panel.open()


## Buy car `id`. Returns "" on success, else the reason ("license", "money", "unknown").
func buy(id: String) -> String:
	var st := style()
	if st == null:
		return "unknown"
	var spec := {}
	for c: Dictionary in st.cars:
		if str(c.get("id", "")) == id:
			spec = c
	if spec.is_empty():
		return "unknown"
	if st.requires_license and not TrafficState.licensed("player"):
		return "license"
	var price := int(spec.get("price", 0))
	if Economy.money < price:
		return "money"
	Economy.add_money(-price)
	var key := "owned_%s_%d" % [id, TrafficState.owned.size() + 1]
	TrafficState.owned.append({"key": key, "id": id, "model": str(spec.get("model", "sedan")), "price": price, "day": TimeManager.day,
		"top_kmh": float(spec.get("top_kmh", 40.0))})
	TrafficState.stat("cars_bought")
	TrafficState.add_news("A new %s left Town Motors today." % str(spec.get("en", "car")), "امروز یک %s نو از نمایشگاه خودروی شهر بیرون رفت." % str(spec.get("fa", "ماشین")))
	var car := _spawn_car(TrafficState.owned[TrafficState.owned.size() - 1], true)
	if car:
		WorldMemory.park(car.key, car.global_position, car.yaw)
	GameEvents.notification_requested.emit(Lang.tt("مبارک باشد! %s مال توست - جلوی نمایشگاه پارک است." % str(spec.get("fa", "")),
		"Congratulations! The %s is yours - parked at the lot." % str(spec.get("en", ""))))
	return ""


func delivery_xform(n: int) -> Transform3D:
	var st := style()
	var b := Basis(Vector3.UP, deg_to_rad(st.yaw if st else 0.0))
	var p := TrafficKit.ground(st.pos if st else Vector2(76, -63.5)) + b * Vector3(-2.6 + (n % 2) * 0.1, 0, (st.size.y if st else 11.0) * 0.5 - 1.4 - (n % 3) * 3.0)
	p.y = Terrain.height_at(p.x, p.z)
	return Transform3D(Basis(Vector3.UP, PI * 0.5), p)


func _spawn_car(o: Dictionary, fresh: bool) -> DrivableCar:
	var key := str(o.get("key", ""))
	for c in owned_cars:
		if is_instance_valid(c) and c.key == key:
			return c
	var car := DrivableCar.new()
	car.name = "Owned_%s" % key
	car.key = key
	car.model_name = str(o.get("model", "sedan"))
	var vs := Modules.style("vehicles") as VehicleStyle
	car.set_meta(&"top_mult", float(o.get("top_kmh", 40.0)) / 3.6 / (vs.max_speed if vs else 11.0))
	car.set_meta(&"owned", true)
	var xf := delivery_xform(_n)
	_n += 1
	var m := WorldMemory.cars.get(key, {}) as Dictionary
	if not fresh and not m.is_empty():
		xf.origin = WorldMemory.vec(m.get("p"))
		xf.basis = Basis(Vector3.UP, float(m.get("yaw", 0.0)))
	car.yaw = xf.basis.get_euler().y
	car.position = xf.origin
	car.set_meta(&"home_pos", car.position)
	car.set_meta(&"home_yaw", car.yaw)
	add_child(car)
	owned_cars.append(car)
	var v7b := get_tree().current_scene.find_child("V7bWorld", true, false) as V7bWorld if get_tree().current_scene else null
	if v7b and v7b.driving:
		v7b.driving.attach_all()
	return car


func _spawn_owned() -> void:
	# Remove cars no longer owned (new game / load), add missing ones.
	for c in owned_cars.duplicate():
		if not is_instance_valid(c) or not TrafficState.owns(c.key):
			if is_instance_valid(c):
				if c.driver:
					c.get_out()
				c.queue_free()
			owned_cars.erase(c)
	for o: Dictionary in TrafficState.owned:
		_spawn_car(o, false)
