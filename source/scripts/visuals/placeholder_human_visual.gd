class_name PlaceholderHumanVisual
extends CharacterVisual
## Procedural animation for the primitive-based farmer placeholder:
## walk cycle (legs/arms), body bob, breathing, blinking, head look-at and a
## "pet" gesture. Replace the whole Visual node with a real model + 
## animated_model_visual.gd when art is ready.

@export var stride_frequency: float = 1.7  ## steps per second at walk speed
@export var leg_swing: float = 0.55
@export var arm_swing: float = 0.45
@export var bob_height: float = 0.035
@export var head_turn_limit: float = 1.0
@export var blink_interval: Vector2 = Vector2(2.0, 5.0)

@onready var _body: Node3D = $Body
@onready var _head: Node3D = $Body/HeadPivot
@onready var _shoulder_l: Node3D = $Body/ShoulderL
@onready var _shoulder_r: Node3D = $Body/ShoulderR
@onready var _hip_l: Node3D = $HipL
@onready var _hip_r: Node3D = $HipR
@onready var _eyes: Array[Node3D] = [$Body/HeadPivot/EyeL, $Body/HeadPivot/EyeR]
@onready var _brows: Array[Node3D] = [$Body/HeadPivot/BrowL, $Body/HeadPivot/BrowR]

var _speed_ratio: float = 0.0
var _smoothed_speed: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _blink_timer: float = 3.0
var _look_target: Vector3 = Vector3.INF
var _gesture_active: bool = false
var _lean_extra: float = 0.0
var _body_rest_y: float
var _brow_rest_y: Array[float] = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_body_rest_y = _body.position.y
	for brow in _brows:
		_brow_rest_y.append(brow.position.y)


func set_locomotion(speed_ratio: float) -> void:
	_speed_ratio = speed_ratio


func set_look_target(world_position: Vector3) -> void:
	_look_target = world_position


func play_action(action: StringName) -> float:
	match action:
		&"pet":
			return _play_pet()
	return 0.0


func _process(delta: float) -> void:
	_time += delta
	_smoothed_speed = lerpf(_smoothed_speed, _speed_ratio, 1.0 - exp(-10.0 * delta))
	var moving := clampf(_smoothed_speed, 0.0, 1.0)
	var run := clampf(_smoothed_speed - 1.0, 0.0, 1.0)

	# Walk cycle.
	_phase = fmod(_phase + delta * TAU * stride_frequency * maxf(_smoothed_speed, 0.0) * 0.5, TAU)
	var swing := sin(_phase) * moving * (leg_swing + run * 0.25)
	_hip_l.rotation.x = swing
	_hip_r.rotation.x = -swing
	if not _gesture_active:
		_shoulder_l.rotation.x = -swing * (arm_swing / leg_swing)
		_shoulder_r.rotation.x = swing * (arm_swing / leg_swing)

	# Bob (two bobs per stride), breathing and a slight forward lean when running.
	var bob := absf(sin(_phase)) * bob_height * moving
	var breathe := sin(_time * 1.6) * 0.006 * (1.0 - moving)
	_body.position.y = _body_rest_y + bob + breathe
	_body.rotation.x = lerpf(_body.rotation.x, 0.06 * moving + 0.12 * run + _lean_extra, 1.0 - exp(-6.0 * delta))
	_body.rotation.y = sin(_phase) * 0.05 * moving

	_update_head(delta)
	_update_blink(delta)


func _update_head(delta: float) -> void:
	var yaw := 0.0
	var pitch := 0.0
	if _look_target != Vector3.INF:
		var local := to_local(_look_target) - (_body.position + _head.position)
		yaw = clampf(atan2(local.x, local.z), -head_turn_limit, head_turn_limit)
		pitch = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.4, 0.6)
	var k := 1.0 - exp(-5.0 * delta)
	_head.rotation.y = lerp_angle(_head.rotation.y, yaw, k)
	_head.rotation.x = lerp_angle(_head.rotation.x, pitch, k)


func _update_blink(delta: float) -> void:
	_blink_timer -= delta
	var open := 1.0
	if _blink_timer < 0.0:
		# 0.14 s blink: close then open.
		var t := -_blink_timer / 0.14
		open = absf(t * 2.0 - 1.0)
		if t >= 1.0:
			_blink_timer = _rng.randf_range(blink_interval.x, blink_interval.y)
			open = 1.0
	for eye in _eyes:
		eye.scale.y = maxf(open, 0.08)


func _play_pet() -> float:
	_gesture_active = true
	var duration := 1.0
	var tween := create_tween()
	# Reach forward/down with the right arm, pat twice, return.
	tween.tween_property(_shoulder_r, "rotation", Vector3(-0.85, 0.0, 0.2), 0.22).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "_lean_extra", 0.35, 0.22).set_trans(Tween.TRANS_SINE)
	for i in 2:
		tween.tween_property(_shoulder_r, "rotation:x", -0.6, 0.14).set_trans(Tween.TRANS_SINE)
		tween.tween_property(_shoulder_r, "rotation:x", -0.85, 0.14).set_trans(Tween.TRANS_SINE)
	tween.tween_property(_shoulder_r, "rotation", Vector3.ZERO, 0.28).set_trans(Tween.TRANS_SINE)
	tween.parallel().tween_property(self, "_lean_extra", 0.0, 0.28).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void: _gesture_active = false)

	# Happy face: raise the eyebrows for a moment.
	var brow_tween := create_tween().set_parallel(true)
	for i in _brows.size():
		brow_tween.tween_property(_brows[i], "position:y", _brow_rest_y[i] + 0.012, 0.15)
	brow_tween.chain()
	brow_tween.set_parallel(true)
	for i in _brows.size():
		brow_tween.tween_property(_brows[i], "position:y", _brow_rest_y[i], 0.4).set_delay(0.6)
	return duration
