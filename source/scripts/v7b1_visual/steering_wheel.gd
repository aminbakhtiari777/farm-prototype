class_name SteeringWheel
extends Node3D
## v7b.1 car interior: a steering wheel (rim, three spokes, hub) that turns with
## the car's steering - DrivableCar.steer_amount (-1..1, + = left) when the
## controls patch exposes it, else steer / max steer. The front wheels of the
## procedural body (group "car_front_wheels") turn with it.

var turn_deg: float = 140.0
var amount: float = 0.0  ## last applied steering (-1..1), for tests
var _rim: Node3D
var _car: Node3D
var _front: Array[Node3D] = []


func build(trim: Material, chrome: Material) -> void:
	_rim = Node3D.new()
	_rim.name = "Rim"
	add_child(_rim)
	var tm := TorusMesh.new()
	tm.inner_radius = 0.16
	tm.outer_radius = 0.19
	tm.rings = 20
	tm.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = tm
	mi.material_override = trim
	mi.rotation.x = PI * 0.5  # torus lies in XZ -> stand it up facing the driver (-Z)
	_rim.add_child(mi)
	for a: float in [PI * 0.5, PI * 0.5 + TAU / 3.0, PI * 0.5 - TAU / 3.0]:
		var sp := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.025, 0.16, 0.02)
		sp.mesh = bm
		sp.material_override = trim
		sp.position = Vector3(cos(a + PI) * 0.09, sin(a + PI) * 0.09, 0)
		sp.rotation.z = a + PI * 0.5
		_rim.add_child(sp)
	var hub := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.06
	cm.bottom_radius = 0.07
	cm.height = 0.05
	hub.mesh = cm
	hub.material_override = chrome
	hub.rotation.x = PI * 0.5
	_rim.add_child(hub)


func _ready() -> void:
	var n: Node = get_parent()
	while n != null and not (n is DrivableCar or n is RoadCar):
		n = n.get_parent()
	_car = n as Node3D
	for w in get_parent().get_children():
		if w is Node3D and (w as Node3D).is_in_group(&"car_front_wheels"):
			_front.append(w)


func steer_of(car: Node) -> float:
	if car == null:
		return 0.0
	var v: Variant = car.get(&"steer_amount")
	if v != null:
		return clampf(float(v), -1.0, 1.0)
	var s: Variant = car.get(&"steer")
	if s == null:
		return 0.0
	var vs := Modules.style("vehicles") as VehicleStyle
	var mx := deg_to_rad(vs.steer_deg if vs else 34.0)
	return clampf(float(s) / maxf(mx, 0.01), -1.0, 1.0)


func _process(_delta: float) -> void:
	if _car == null:
		return
	var a := steer_of(_car)
	if not is_equal_approx(a, amount):
		set_amount(a)


func set_amount(a: float) -> void:
	amount = a
	if _rim:
		# + = turning left: the top of the wheel moves left (towards +X) -> negative z-roll seen from the driver.
		_rim.rotation.z = -a * deg_to_rad(turn_deg)
	for w in _front:
		if is_instance_valid(w):
			w.rotation.y = a * deg_to_rad(30.0)
