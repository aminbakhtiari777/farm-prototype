class_name CockpitCamera
extends Node3D
## v7b.1 in-car (cockpit) camera, a child "CockpitCam" of a DrivableCar.
## Toggle with V / C while driving (touch: the camera button). The mouse (or
## the right touch stick) looks around inside the car: left / right up to
## 150 deg and up through the roof to the sky - looking up clips the roof
## away (the near plane grows past the roof; nodes in group "car_roof" under
## the car hide too). Steering in the cockpit: A/D or the left touch stick
## (the mouse looks instead of steering). The view eases back to the road
## while driving. The chase camera (mouse steering) stays the default.
## For the car interior / steering wheel (visual worker): the driver's eye is
## at car.get_meta("driver_eye") (car-local, +Z forward, +X = driver's left
## side) and DrivableCar.steer_amount (-1..1, + = turning left) turns the wheel.

const YAW_LIMIT := 150.0
const PITCH_MIN := -55.0
const PITCH_MAX := 80.0

var car: DrivableCar
var cam: Camera3D
var active: bool = false
var look_yaw: float = 0.0  ## degrees from the car's forward (+ = left)
var look_pitch: float = -6.0
var roof_hidden: bool = false
var toggles: int = 0


static func eye_local_for(size: Vector3) -> Vector3:
	return Vector3(size.x * 0.2, clampf(size.y * 0.74, 0.95, 1.7), size.z * 0.02)


func _ready() -> void:
	car = get_parent() as DrivableCar
	position = eye_local_for(car.size if car else Vector3(1.9, 1.6, 4.2))
	cam = Camera3D.new()
	cam.name = "Camera3D"
	cam.near = 0.05
	cam.fov = 72.0
	add_child(cam)
	if car:
		car.set_meta(&"driver_eye", position)
	_apply()


func activate(on: bool) -> void:
	if on == active:
		return
	active = on
	toggles += 1
	if on:
		look_yaw = 0.0
		look_pitch = -6.0
		_apply()
		cam.make_current()
		ControlInput.cockpit = self
	else:
		if ControlInput.cockpit == self:
			ControlInput.cockpit = null
		var rig := get_tree().get_first_node_in_group(&"camera_rig")
		var c: Camera3D = rig.find_child("Camera3D", true, false) as Camera3D if rig else null
		if c:
			c.make_current()
		_set_roof_hidden(false)
	if car:
		car.set_meta(&"cockpit", on)


func look(yaw_deg: float, pitch_deg: float) -> void:
	look_yaw = clampf(look_yaw + yaw_deg, -YAW_LIMIT, YAW_LIMIT)
	look_pitch = clampf(look_pitch + pitch_deg, PITCH_MIN, PITCH_MAX)
	_apply()


func _apply() -> void:
	if cam == null:
		return
	cam.rotation = Vector3(deg_to_rad(look_pitch), PI + deg_to_rad(look_yaw), 0.0)
	# Looking up: the near plane grows past the roof (~0.3-0.5 m above the eyes) -> sky.
	var up := smoothstep(12.0, 38.0, look_pitch)
	cam.near = lerpf(0.05, 0.85, up)
	_set_roof_hidden(look_pitch > 25.0)


func _set_roof_hidden(h: bool) -> void:
	if h == roof_hidden or car == null:
		return
	roof_hidden = h
	for n in get_tree().get_nodes_in_group(&"car_roof"):
		if n is Node3D and car.is_ancestor_of(n):
			(n as Node3D).visible = not h


func _process(delta: float) -> void:
	if not active:
		return
	if car == null or car.driver == null:
		activate(false)
		return
	var lk := ControlInput.take_look(delta)
	var k_yaw := Input.get_action_strength(&"camera_left") - Input.get_action_strength(&"camera_right")
	var k_pitch := Input.get_action_strength(&"camera_up") - Input.get_action_strength(&"camera_down")
	lk += Vector2(k_yaw * 90.0, k_pitch * 60.0) * delta
	if lk != Vector2.ZERO:
		look(lk.x, lk.y)
	elif absf(car.speed) > 2.0 and not ControlInput.looking():
		look_yaw = move_toward(look_yaw, 0.0, 35.0 * delta)
		look_pitch = move_toward(look_pitch, -6.0, 25.0 * delta)
		_apply()
