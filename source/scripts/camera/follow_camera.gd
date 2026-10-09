class_name FollowCamera
extends Node3D
## Third-person orbit camera on a SpringArm3D.
##
## - Full 360 degree orbit: hold the right mouse button and drag, or use
##   Z / C (also , and .), the right gamepad stick; PageUp/PageDown pitch.
## - Zoom: mouse wheel, + / -, LB/RB. Home (or middle mouse / R3) resets
##   the camera behind the farmer.
## - The SpringArm3D shortens the arm whenever walls, trees or roofs are in
##   the way, so the camera never clips through houses; inside a building
##   the arm is shortened further and the roof is hidden (Building).
## Movement is camera-relative (see Player._camera_relative).
## v7b.1: click captures the mouse -> mouse look; touch right stick looks (ControlInput).

@export var target: Node3D
@export var height: float = 1.45
@export var distance: float = 6.0
@export var min_distance: float = 1.8
@export var max_distance: float = 14.0
@export var indoor_max_distance: float = 3.4
@export var pitch_degrees: float = -24.0
@export var min_pitch: float = -78.0
@export var max_pitch: float = 40.0  ## v7b.1 bug fix: was 18 - the camera could barely look up
@export var mouse_sensitivity: float = 0.25
@export var key_yaw_speed: float = 120.0  ## degrees / second
@export var key_pitch_speed: float = 70.0
@export var follow_speed: float = 12.0

var yaw: float = 0.0  ## radians, 0 = looking along -Z
var pitch: float = deg_to_rad(-24.0)
var _zoom: float = 6.0
var _orbiting: bool = false
var _arm: SpringArm3D
var _camera: Camera3D
var _indoors: bool = false
## Extra offset from the target (screenshots / cut-scene framing only).
var target_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	add_to_group(&"camera_rig")
	pitch = deg_to_rad(pitch_degrees)
	_zoom = distance
	_arm = get_node_or_null(^"SpringArm3D") as SpringArm3D
	_camera = find_child("Camera3D", true, false) as Camera3D
	if _arm == null:
		_arm = SpringArm3D.new()
		_arm.name = "SpringArm3D"
		add_child(_arm)
		var cam := find_child("Camera3D", true, false) as Camera3D
		if cam:
			cam.get_parent().remove_child(cam)
			_arm.add_child(cam)
			cam.transform = Transform3D.IDENTITY
			_camera = cam
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	_arm.shape = sphere
	_arm.collision_mask = 1
	_arm.margin = 0.15
	_arm.spring_length = _zoom
	if target is CollisionObject3D:
		_arm.add_excluded_object((target as CollisionObject3D).get_rid())
	GameEvents.building_entered.connect(func(_b: Node3D) -> void: _indoors = true)
	GameEvents.building_exited.connect(func(_b: Node3D) -> void: _indoors = false)
	if target:
		global_position = target.global_position + Vector3.UP * height
		reset_behind_target()
	_apply_rotation()


func _unhandled_input(event: InputEvent) -> void:
	if ControlInput.blocked():
		_orbiting = false
		return
	if event.is_action_pressed(&"camera_orbit"):
		_orbiting = true
	elif event.is_action_released(&"camera_orbit"):
		_orbiting = false
	elif event.is_action_pressed(&"zoom_in"):
		zoom_by(-0.8)
	elif event.is_action_pressed(&"zoom_out"):
		zoom_by(0.8)
	elif event.is_action_pressed(&"camera_reset"):
		reset_behind_target()
	elif event is InputEventMouseMotion and _orbiting and not ControlInput.captured \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		var m := event as InputEventMouseMotion
		var sens := mouse_sensitivity * float(Settings.get_value("camera_sensitivity"))
		var invert := -1.0 if bool(Settings.get_value("camera_invert_y")) else 1.0
		orbit(-m.relative.x * sens, -m.relative.y * sens * invert)


func _process(delta: float) -> void:
	if not GameEvents.ui_open:
		var yaw_in := Input.get_action_strength(&"camera_right") - Input.get_action_strength(&"camera_left")
		var pitch_in := Input.get_action_strength(&"camera_up") - Input.get_action_strength(&"camera_down")
		if absf(yaw_in) > 0.01 or absf(pitch_in) > 0.01:
			orbit(-yaw_in * key_yaw_speed * delta, pitch_in * key_pitch_speed * delta)
		# v7b.1: mouse look (pointer lock) + right touch stick via ControlInput
		# (the cockpit camera takes the look input while it is active).
		if ControlInput.cockpit == null:
			var look := ControlInput.take_look(delta)
			if look != Vector2.ZERO:
				orbit(look.x, look.y)
	if target:
		# v7b.1 perf: follow the interpolated (rendered) position so the camera
		# moves smoothly between 60 Hz physics steps (PerfWorld smooth_motion).
		var tpos := target.get_global_transform_interpolated().origin if target.is_physics_interpolated_and_enabled() else target.global_position
		var goal := tpos + Vector3.UP * height + target_offset
		global_position = global_position.lerp(goal, 1.0 - exp(-follow_speed * delta))
	var max_len := indoor_max_distance if _indoors else max_distance
	var want := minf(_zoom, max_len)
	_arm.spring_length = lerpf(_arm.spring_length, want, 1.0 - exp(-8.0 * delta))


## Rotate the orbit by degrees (yaw left/right, pitch up/down).
func orbit(yaw_deg: float, pitch_deg: float) -> void:
	yaw = wrapf(yaw + deg_to_rad(yaw_deg), -PI, PI)
	pitch = clampf(pitch + deg_to_rad(pitch_deg), deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	_apply_rotation()


func zoom_by(amount: float) -> void:
	_zoom = clampf(_zoom + amount, min_distance, max_distance)


func set_zoom(value: float) -> void:
	_zoom = clampf(value, min_distance, max_distance)
	if _arm:
		_arm.spring_length = _zoom


func zoom() -> float:
	return _zoom


func yaw_degrees() -> float:
	return rad_to_deg(yaw)


func pitch_degrees_now() -> float:
	return rad_to_deg(pitch)


func arm_length() -> float:
	return _arm.get_hit_length() if _arm else _zoom


## Places the camera behind the farmer (models face +Z).
func reset_behind_target() -> void:
	var facing := Vector3.FORWARD
	if target and target.has_method("facing_direction"):
		facing = target.call("facing_direction")
	# The arm points along the rig's +Z, so +Z must point away from the facing.
	yaw = atan2(-facing.x, -facing.z)
	pitch = deg_to_rad(pitch_degrees)
	_apply_rotation()


## Instantly snap to the target (used after teleports / loading a save).
func snap() -> void:
	if target:
		global_position = target.global_position + Vector3.UP * height + target_offset
	if _arm:
		_arm.spring_length = minf(_zoom, indoor_max_distance if _indoors else max_distance)


func _apply_rotation() -> void:
	rotation = Vector3(0.0, yaw, 0.0)
	if _arm:
		_arm.rotation = Vector3(pitch, 0.0, 0.0)


## Absolute framing: yaw/pitch in degrees, arm length in metres, then snap.
func snap_view(yaw_deg: float, pitch_deg: float, dist: float) -> void:
	yaw = wrapf(deg_to_rad(yaw_deg), -PI, PI)
	pitch = clampf(deg_to_rad(pitch_deg), deg_to_rad(min_pitch), deg_to_rad(max_pitch))
	_apply_rotation()
	var old_max := max_distance
	max_distance = maxf(max_distance, dist)
	set_zoom(dist)
	max_distance = old_max if dist <= old_max else dist
	snap()
