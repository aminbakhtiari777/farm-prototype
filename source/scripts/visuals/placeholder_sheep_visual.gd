class_name PlaceholderSheepVisual
extends CharacterVisual
## Procedural animation for the primitive-based sheep: trotting legs, body
## sway, grazing (head down + chewing), hop reaction, bleat, ear flicks and a
## wagging tail.

@export var stride_frequency: float = 2.2
@export var leg_swing: float = 0.45

@onready var _rig: Node3D = $Rig
@onready var _head: Node3D = $Rig/HeadPivot
@onready var _jaw: Node3D = $Rig/HeadPivot/Jaw
@onready var _ear_l: Node3D = $Rig/HeadPivot/EarL
@onready var _ear_r: Node3D = $Rig/HeadPivot/EarR
@onready var _tail: Node3D = $Rig/Tail
@onready var _legs: Array[Node3D] = [$Rig/LegFL, $Rig/LegFR, $Rig/LegBL, $Rig/LegBR]

var _speed_ratio: float = 0.0
var _smoothed_speed: float = 0.0
var _phase: float = 0.0
var _time: float = 0.0
var _graze_timer: float = 0.0
var _hop_active: bool = false
var _bleat_timer: float = 0.0
var _ear_timer: float = 1.5
var _ear_l_rest: Vector3
var _ear_r_rest: Vector3
var _look_target: Vector3 = Vector3.INF
var _look_timer: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_phase = _rng.randf() * TAU
	_ear_l_rest = _ear_l.rotation
	_ear_r_rest = _ear_r.rotation


func set_locomotion(speed_ratio: float) -> void:
	_speed_ratio = speed_ratio
	if speed_ratio > 0.2:
		_graze_timer = 0.0


func set_look_target(world_position: Vector3) -> void:
	_look_target = world_position
	_look_timer = 2.0


func play_action(action: StringName) -> float:
	match action:
		&"graze":
			_graze_timer = _rng.randf_range(2.0, 4.0)
			return _graze_timer
		&"hop":
			return _play_hop()
		&"bleat":
			_graze_timer = 0.0
			_bleat_timer = 0.6
			return 0.6
	return 0.0


func _process(delta: float) -> void:
	_time += delta
	_smoothed_speed = lerpf(_smoothed_speed, _speed_ratio, 1.0 - exp(-8.0 * delta))
	var moving := clampf(_smoothed_speed, 0.0, 1.5)
	_phase = fmod(_phase + delta * TAU * stride_frequency * minf(moving, 1.5) * 0.5, TAU)

	# Diagonal gait: front-left with back-right.
	var s := sin(_phase) * leg_swing * clampf(moving, 0.0, 1.0)
	_legs[0].rotation.x = s
	_legs[3].rotation.x = s
	_legs[1].rotation.x = -s
	_legs[2].rotation.x = -s

	if not _hop_active:
		_rig.position.y = absf(sin(_phase)) * 0.025 * clampf(moving, 0.0, 1.0) + sin(_time * 1.3) * 0.004
		_rig.rotation.z = sin(_phase) * 0.03 * clampf(moving, 0.0, 1.0)

	# Head: graze, bleat, look at target, or neutral.
	_graze_timer = maxf(_graze_timer - delta, 0.0)
	_bleat_timer = maxf(_bleat_timer - delta, 0.0)
	_look_timer = maxf(_look_timer - delta, 0.0)
	var head_x := 0.0
	var head_y := sin(_time * 0.4) * 0.15
	var jaw := 0.0
	if _bleat_timer > 0.0:
		head_x = -0.35
		jaw = 0.35 * absf(sin(_bleat_timer * 12.0))
	elif _graze_timer > 0.0:
		head_x = 0.85
		jaw = 0.12 * (0.5 + 0.5 * sin(_time * 9.0))
	elif _look_timer > 0.0 and _look_target != Vector3.INF:
		var local := to_local(_look_target) - (_rig.position + _head.position)
		head_y = clampf(atan2(local.x, local.z), -0.9, 0.9)
		head_x = clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.5, 0.5)
	var k := 1.0 - exp(-4.0 * delta)
	_head.rotation.x = lerp_angle(_head.rotation.x, head_x, k)
	_head.rotation.y = lerp_angle(_head.rotation.y, head_y, k)
	_jaw.rotation.x = lerp_angle(_jaw.rotation.x, jaw, 1.0 - exp(-20.0 * delta))

	# Ear flicks and tail wag.
	_ear_timer -= delta
	var flick := 0.0
	if _ear_timer < 0.0:
		flick = sin(-_ear_timer * 25.0) * 0.4
		if _ear_timer < -0.25:
			_ear_timer = _rng.randf_range(1.5, 4.5)
	_ear_l.rotation = _ear_l_rest + Vector3(0.0, 0.0, flick)
	_ear_r.rotation = _ear_r_rest + Vector3(0.0, 0.0, -flick * 0.5)
	_tail.rotation.y = sin(_time * (3.0 + moving * 6.0)) * (0.15 + 0.25 * moving)


func _play_hop() -> float:
	_hop_active = true
	var tween := create_tween()
	# Anticipation squash, jump with stretch, landing squash, settle.
	tween.tween_property(_rig, "scale", Vector3(1.08, 0.88, 1.08), 0.1)
	tween.tween_property(_rig, "position:y", 0.32, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_rig, "scale", Vector3(0.95, 1.08, 0.95), 0.2)
	tween.tween_property(_rig, "position:y", 0.0, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(_rig, "scale", Vector3.ONE, 0.2)
	tween.tween_property(_rig, "scale", Vector3(1.06, 0.92, 1.06), 0.08)
	tween.tween_property(_rig, "scale", Vector3.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func() -> void: _hop_active = false)
	return 0.95
