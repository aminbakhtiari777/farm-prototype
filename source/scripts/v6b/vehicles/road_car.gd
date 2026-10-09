class_name RoadCar
extends AnimatableBody3D
## v6b AI vehicle (ambulance, police car, wood pickup): follows a list of
## waypoints on the road graph at a steady speed, slows for corners, and
## stops when the farmer or a townsperson is just ahead. A solid body
## (layer 1) so people walk around it. Subclasses drive the jobs.

signal arrived

var model_name: String = "sedan"
var speed: float = 7.0
var path: PackedVector3Array = PackedVector3Array()
var path_i: int = 0
var moving: bool = false
var yaw: float = 0.0
var cur_speed: float = 0.0
var size: Vector3 = Vector3(1.9, 1.6, 4.2)
var blocked_time: float = 0.0
var distance_driven: float = 0.0
var model_root: Node3D
var _blocked_timer: float = 0.0
var _stop_for_people: bool = true
## v7b.1 traffic: (car, want m/s) -> capped m/s (TrafficRules.ai_gate).
static var traffic_gate: Callable
## v7b.1 police: (car, want m/s) -> capped m/s so the car stops before people
## on its route (RoadSafety.people_gate). Replaces _people_ahead() (which drove
## on through a person after 12 s).
static var people_gate: Callable


func _init() -> void:
	sync_to_physics = false
	collision_layer = 1
	collision_mask = 0


func build_model() -> void:
	var m := VehicleKit.model(model_name)
	if m.is_empty():
		return
	model_root = m[0]
	size = m[1]
	add_child(model_root)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x, maxf(size.y - 0.3, 0.6), size.z)
	cs.shape = bs
	cs.position = Vector3(0, 0.3 + bs.size.y * 0.5, 0)
	add_child(cs)


func place(p: Vector3, yaw_rad: float) -> void:
	yaw = yaw_rad
	global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
	rotation = Vector3(0, yaw, 0)


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


## Drive to a world point along the roads (right-hand lane), finishing with
## a short off-road leg to the exact spot.
func drive_to(target: Vector3, final_leg: bool = true) -> void:
	var r := VehicleKit.lane(VehicleKit.route(global_position, target))
	if final_leg:
		r.append(Vector3(target.x, 0.0, target.z))
	follow(r)


func follow(points: PackedVector3Array) -> void:
	path = points
	path_i = 0
	# Skip points behind us at the start.
	while path_i < path.size() - 1 and _flat(path[path_i]).distance_to(_flat(global_position)) < 2.5:
		path_i += 1
	moving = path.size() > 0


func stop() -> void:
	moving = false
	cur_speed = 0.0


static func _flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


func _people_ahead() -> bool:
	if not _stop_for_people:
		return false
	var fwd := forward()
	var me := _flat(global_position)
	for g: StringName in [&"player", &"townspeople"]:
		for n in get_tree().get_nodes_in_group(g):
			var b := n as Node3D
			if b == null or not b.is_visible_in_tree():
				continue
			if b is TownspersonBot and (b as TownspersonBot).hidden_inside:
				continue
			if b is Player and (b as Player).vehicle != null:
				continue
			var d := _flat(b.global_position) - me
			var ahead := d.dot(fwd)
			if ahead > 0.0 and ahead < size.z * 0.5 + 3.2 and absf(d.dot(Vector3(-fwd.z, 0, fwd.x))) < size.x * 0.5 + 0.6:
				return true
	return false


func _physics_process(delta: float) -> void:
	if not moving:
		return
	_blocked_timer -= delta
	if people_gate.is_valid():
		_blocked = false
	elif _blocked_timer <= 0.0:
		_blocked_timer = 0.25
		var blocked := _people_ahead()
		if blocked:
			blocked_time += 0.25
		_blocked = blocked and blocked_time < 12.0  # never deadlock forever
		if not blocked:
			blocked_time = 0.0
	var target := path[path_i]
	var to := _flat(target) - _flat(global_position)
	var dist := to.length()
	if dist < 1.2:
		path_i += 1
		if path_i >= path.size():
			stop()
			arrived.emit()
			return
		return
	# Slow down for sharp corners and at the end of the route.
	var want := speed
	if path_i < path.size() - 1:
		var nxt := (_flat(path[path_i + 1]) - _flat(target)).normalized()
		var turn := 1.0 - maxf(nxt.dot(to.normalized()), 0.0)
		want *= lerpf(1.0, 0.45, clampf(turn * 1.5, 0.0, 1.0)) if dist < 8.0 else 1.0
	else:
		want *= clampf(dist / 8.0, 0.3, 1.0)
	if _blocked:
		want = 0.0
	# v7b.1 traffic: lights, STOP signs, speed limits, gap to the car in front.
	if traffic_gate.is_valid():
		want = minf(want, float(traffic_gate.call(self, want)))
	if people_gate.is_valid() and _stop_for_people:
		want = minf(want, float(people_gate.call(self, want)))
	cur_speed = move_toward(cur_speed, want, (6.0 if want > cur_speed else 9.0) * delta)
	var goal_yaw := atan2(to.x, to.z)
	yaw = lerp_angle(yaw, goal_yaw, 1.0 - exp(-(2.5 + cur_speed * 0.25) * delta))
	var step := forward() * cur_speed * delta
	# Head towards the point even if the yaw lags a bit (no orbiting).
	if forward().dot(to.normalized()) < 0.2:
		step *= 0.3
	var p := global_position + step
	p.y = Terrain.height_at(p.x, p.z)
	distance_driven += step.length()
	global_transform = Transform3D(Basis(Vector3.UP, yaw), p)


var _blocked: bool = false


# ------------------------------------------------------------------ light bar
var _bar: Array[MeshInstance3D] = []
var _bar_mats: Array[StandardMaterial3D] = []
var _bar_light: OmniLight3D
var flashing: bool = false
var _flash_t: float = 0.0


## Roof light bar (police blue/red, ambulance red/white); flashes while on duty.
func add_lightbar(a: Color, b: Color, height: float = -1.0) -> void:
	var y := (size.y if height < 0.0 else height) + 0.06
	for i in 2:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = a if i == 0 else b
		mat.emission_enabled = true
		mat.emission = a if i == 0 else b
		mat.emission_energy_multiplier = 0.2
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(size.x * 0.28, 0.12, 0.22)
		mi.mesh = bm
		mi.material_override = mat
		mi.position = Vector3((i - 0.5) * size.x * 0.3, y, -size.z * 0.08)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_bar.append(mi)
		_bar_mats.append(mat)
	_bar_light = OmniLight3D.new()
	_bar_light.omni_range = 6.0
	_bar_light.light_energy = 0.0
	_bar_light.position = Vector3(0, y + 0.3, 0)
	_bar_light.visible = false
	add_child(_bar_light)


func set_flashing(on: bool) -> void:
	flashing = on
	if _bar_light:
		_bar_light.visible = on
	if not on:
		for m in _bar_mats:
			m.emission_energy_multiplier = 0.2


func _process(delta: float) -> void:
	if not flashing or _bar_mats.is_empty():
		return
	_flash_t += delta
	var phase := int(_flash_t * 5.0) % 2
	for i in _bar_mats.size():
		_bar_mats[i].emission_energy_multiplier = 3.5 if i == phase else 0.2
	_bar_light.light_color = _bar_mats[phase].albedo_color
	_bar_light.light_energy = 1.6
