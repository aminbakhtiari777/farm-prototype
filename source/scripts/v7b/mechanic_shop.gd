class_name MechanicShop
extends Node3D
## v7b "mechanic" module: a garage on Main St (east) with a car lift, tools,
## a counter (E: repair / fuel / upgrades for the car parked nearby or the
## one you drove last) and a fuel pump out front (E: fill up). The mechanic
## is a Staffing post - a stand-in covers when the mechanic is away.

var staffing: Staffing
var driving: Driving
var panel: MechanicPanel
var root: Node3D
var counter_spot: ActionSpot
var pump_spot: ActionSpot
var repairs: int = 0
var fills: int = 0
var installs: int = 0
var _sign: Label3D


func style() -> MechanicStyle:
	return Modules.style("mechanic") as MechanicStyle


func _ready() -> void:
	rebuild()
	Modules.on_swap("mechanic", self, func(_m: Resource) -> void: rebuild())


func at(local: Vector3) -> Vector3:
	return root.global_transform * local if root else local


func rebuild() -> void:
	if staffing:
		staffing.remove_post("mechanic")
	if root:
		root.queue_free()
		root = null
	var st := style()
	if st == null:
		return
	root = Node3D.new()
	root.name = "Garage"
	root.position = Vector3(st.pos.x, Terrain.height_at(st.pos.x, st.pos.y), st.pos.y)
	root.rotation.y = deg_to_rad(st.yaw)
	add_child(root)
	V7bKit.clear_trees(get_tree(), Rect2(st.pos - Vector2(6.0, 6.0), Vector2(12.0, 12.0)))
	_build()
	if staffing:
		staffing.add_post("mechanic", Array(st.staff), at(Vector3(2.6, 0, -1.6)), at(Vector3(2.6, 0, 2.0)), st.hours)


func _build() -> void:
	var w := 8.5
	var d := 6.5
	var wall := V7aKit.mat(Color(0.72, 0.74, 0.76))
	var trim := V7aKit.mat(Color(0.85, 0.35, 0.12))
	var metal := V7aKit.mat(Color(0.2, 0.21, 0.23), 0.4)
	var body := StaticBody3D.new()
	body.name = "GarageBody"
	root.add_child(body)
	V7aKit.box(root, Vector3(w + 2.0, 0.06, d + 3.0), Vector3(0, 0.03, 0.8), V7aKit.mat(Color(0.45, 0.45, 0.46), 0.95))
	V7aKit.box(root, Vector3(w, 3.4, 0.2), Vector3(0, 1.7, -d * 0.5), wall)
	_col(body, Vector3(w, 3.4, 0.2), Vector3(0, 1.7, -d * 0.5))
	for sx: float in [-w * 0.5, w * 0.5]:
		V7aKit.box(root, Vector3(0.2, 3.4, d), Vector3(sx, 1.7, 0), wall)
		_col(body, Vector3(0.2, 3.4, d), Vector3(sx, 1.7, 0))
	V7aKit.box(root, Vector3(w + 0.6, 0.25, d + 0.6), Vector3(0, 3.5, 0), V7aKit.mat(Color(0.3, 0.3, 0.33)))
	V7aKit.box(root, Vector3(w + 0.2, 0.55, 0.12), Vector3(0, 3.1, d * 0.5), trim)
	# Car lift (two posts + arms) on the left bay.
	for zz: float in [-1.6, 1.4]:
		V7aKit.box(root, Vector3(0.22, 2.6, 0.22), Vector3(-2.9, 1.3, zz), V7aKit.mat(Color(0.15, 0.35, 0.75), 0.4))
		V7aKit.box(root, Vector3(1.6, 0.1, 0.15), Vector3(-2.2, 0.35, zz), metal)
	# Tool wall, workbench, tyres, oil drums.
	V7aKit.box(root, Vector3(3.0, 1.4, 0.05), Vector3(1.8, 1.9, -d * 0.5 + 0.13), V7aKit.mat(Color(0.35, 0.3, 0.25)))
	for k in 7:
		V7aKit.box(root, Vector3(0.06, 0.4, 0.04), Vector3(0.6 + k * 0.38, 2.0, -d * 0.5 + 0.17), metal)
	V7aKit.box(root, Vector3(2.6, 0.9, 0.7), Vector3(2.6, 0.45, -2.6), V7aKit.mat(Color(0.4, 0.28, 0.18)))
	_col(body, Vector3(2.6, 0.9, 0.7), Vector3(2.6, 0.45, -2.6))
	for k in 4:
		var tyre := V7aKit.cyl(root, 0.36, 0.24, Vector3(3.6, 0.13 + k * 0.25, 1.2), V7aKit.mat(Color(0.06, 0.06, 0.06), 0.9), 0.36)
		tyre.name = "Tyre%d" % k
	for k in 2:
		V7aKit.cyl(root, 0.3, 0.9, Vector3(3.6, 0.45, 2.2 + k * 0.7), V7aKit.mat([Color(0.1, 0.35, 0.6), Color(0.75, 0.2, 0.1)][k], 0.5))
	# Counter: talk to the mechanic.
	counter_spot = ActionSpot.make(root, Vector3(2.6, 0, -1.4), 1.6, _counter_text, func(_w: Node3D) -> void: open_panel())
	counter_spot.name = "MechanicCounter"
	# Fuel pump out front (right).
	var pump := Node3D.new()
	pump.name = "FuelPump"
	pump.position = Vector3(w * 0.5 + 0.8, 0, d * 0.5 + 1.6)
	root.add_child(pump)
	V7aKit.box(pump, Vector3(0.7, 1.7, 0.5), Vector3(0, 0.85, 0), V7aKit.mat(Color(0.9, 0.15, 0.1), 0.5))
	V7aKit.box(pump, Vector3(0.5, 0.35, 0.05), Vector3(0, 1.35, 0.26), V7aKit.mat(Color(0.8, 0.95, 1.0), 0.2, 0.6))
	V7aKit.box(pump, Vector3(0.9, 0.12, 0.7), Vector3(0, 1.76, 0), V7aKit.mat(Color(0.95, 0.95, 0.95)))
	var pc := StaticBody3D.new()
	pump.add_child(pc)
	_col(pc, Vector3(0.7, 1.7, 0.5), Vector3(0, 0.85, 0))
	pump_spot = ActionSpot.make(pump, Vector3(0, 0, 0.9), 1.8, _pump_text, func(_w: Node3D) -> void: fill_up())
	pump_spot.name = "PumpSpot"
	_sign = V7bKit.sign(root, Vector3(-w * 0.5 - 0.9, 0, d * 0.5 + 1.0), 0.0, "تعمیرگاه و پمپ بنزین", "Mechanic & Fuel", Color(0.75, 0.3, 0.1), 3.4)


func _col(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


func _counter_text() -> String:
	return Lang.loc_ui("talk to the mechanic (repair, fuel, upgrades)") if is_open() else Lang.tt("تعمیرگاه بسته است", "the garage is closed")


func _pump_text() -> String:
	return Lang.loc_ui("fill up the car")


func is_open() -> bool:
	var st := style()
	return st != null and Staffing.open_at(st.hours, TimeManager.hours_float())


func mechanic() -> TownspersonBot:
	return staffing.holder("mechanic") if staffing else null


## The car the mechanic works on: parked nearby, else the one you drove last.
func target_car(radius: float = 14.0) -> DrivableCar:
	var best: DrivableCar = null
	var bd := radius
	for c in get_tree().get_nodes_in_group(&"drivable_cars"):
		var car := c as DrivableCar
		if car == null:
			continue
		var d := V7aKit.flat(car.global_position).distance_to(V7aKit.flat(root.global_position))
		if d < bd:
			bd = d
			best = car
	if best == null and driving and driving.last_car and is_instance_valid(driving.last_car):
		best = driving.last_car
	return best


func _say(kind: String) -> void:
	var st := style()
	var m := mechanic()
	if st and m:
		V7bKit.say_small(m, V7bKit.line(st.lines.get(kind, [])))


func repair_cost(car: DrivableCar) -> int:
	var st := style()
	if st == null or car == null:
		return 0
	return int(ceil((100.0 - float(TownLife.car(car.key).get("condition", 100.0))) * st.repair_per_pct))


func fuel_cost(car: DrivableCar) -> int:
	var st := style()
	if st == null or car == null:
		return 0
	return int(ceil((100.0 - float(TownLife.car(car.key).get("fuel", 100.0))) * st.fuel_per_pct))


func _pay(cost: int) -> bool:
	if Economy.money < cost:
		_say("poor")
		GameEvents.notification_requested.emit(Lang.tt("پول کافی نداری (%s سکه لازم است)." % Lang.digits(str(cost)), "Not enough money (%d G needed)." % cost))
		return false
	Economy.add_money(-cost)
	CityState.add_income("tax", int(ceil(cost * 0.1)), "Garage tax", "مالیات تعمیرگاه")
	return true


func repair(car: DrivableCar = null) -> bool:
	car = car if car else target_car()
	if car == null or not is_open():
		return false
	var cost := repair_cost(car)
	if cost <= 0 or not _pay(cost):
		return false
	TownLife.car(car.key)["condition"] = 100.0
	var sys := car.get_node_or_null(^"CarSystems") as CarSystems
	if sys:
		sys._update_smoke()
	repairs += 1
	_say("repaired")
	GameEvents.notification_requested.emit(Lang.tt("ماشین تعمیر شد (%s سکه)." % Lang.digits(str(cost)), "Car repaired (%d G)." % cost))
	return true


func fill_up(car: DrivableCar = null) -> bool:
	car = car if car else target_car(10.0)
	if car == null:
		GameEvents.notification_requested.emit(Lang.tt("ماشینی کنار پمپ نیست.", "No car at the pump."))
		return false
	var cost := fuel_cost(car)
	if cost <= 0:
		GameEvents.notification_requested.emit(Lang.tt("باک پر است.", "The tank is full."))
		return false
	if not _pay(cost):
		return false
	TownLife.car(car.key)["fuel"] = 100.0
	fills += 1
	_say("fueled")
	GameEvents.notification_requested.emit(Lang.tt("باک پر شد (%s سکه)." % Lang.digits(str(cost)), "Tank filled (%d G)." % cost))
	return true


func install(id: String, car: DrivableCar = null) -> bool:
	var st := style()
	car = car if car else target_car()
	if st == null or car == null or not is_open():
		return false
	var ups: Array = TownLife.car(car.key).get("upgrades", [])
	if id in ups:
		return false
	for u: Dictionary in st.upgrades:
		if str(u.get("id", "")) == id:
			if not _pay(int(u.get("cost", 0))):
				return false
			ups.append(id)
			TownLife.car(car.key)["upgrades"] = ups
			installs += 1
			_say("upgraded")
			GameEvents.notification_requested.emit(Lang.tt("نصب شد: %s" % str(u.get("fa", id)), "Installed: %s" % str(u.get("en", id))))
			return true
	return false


func open_panel() -> bool:
	if not is_open():
		GameEvents.notification_requested.emit(Lang.tt("تعمیرگاه ساعت %s تا %s باز است." % [Lang.hour_text(style().hours.x), Lang.hour_text(style().hours.y)],
			"The garage is open %s-%s." % [Lang.hour_text(style().hours.x), Lang.hour_text(style().hours.y)]))
		return false
	if staffing:
		staffing.tick()
	_say("greet")
	if staffing and staffing.is_standin("mechanic") and mechanic():
		mechanic().say(V7bKit.line(style().lines.get("standin", [])), 3.5)
	panel.open()
	return true
