class_name Sheep
extends CharacterBody3D
## Sheep gameplay: a tiny state machine (IDLE / WANDER / REACT) plus petting.
##
## Visuals are delegated to the child "Visual" node (CharacterVisual), so a
## realistic sheep model can replace the placeholder without changing this file.

enum State { IDLE, WANDER, REACT }

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/ui/FloatingText.tscn")
const BLEATS: Array[String] = ["Baa!", "Baaa~", "Meeh!", "Baa baa!"]

@export var display_name: String = "Sheep"
@export var walk_speed: float = 0.9
@export var turn_speed: float = 4.0
## Wander targets are chosen within this radius of the spawn point.
@export var wander_radius: float = 6.0
@export var idle_time_range: Vector2 = Vector2(2.0, 5.0)
@export var max_affection: int = 10
## Bleat variants; one is picked at random (with random pitch) on each bleat.
@export var bleat_sounds: Array[AudioStream] = []
@export var bleat_pitch_range: Vector2 = Vector2(0.92, 1.08)
## Chance to bleat on its own when it stops to idle.
@export_range(0.0, 1.0) var idle_bleat_chance: float = 0.12
@export var affection: int = 0
## Wool grows once per in-game day when affection is at least this high.
@export var wool_affection: int = 3
## How many bleat sounds have been started (used by the smoke test).
var bleats_played: int = 0
## True when there is wool to collect (pressing E collects it instead of petting).
var wool_ready: bool = false

@onready var _visual: Node3D = get_node_or_null(^"Visual")
@onready var _interaction_zone: Interactable = $InteractionZone
@onready var _text_anchor: Marker3D = $TextAnchor
@onready var _bleat_player: AudioStreamPlayer3D = get_node_or_null(^"BleatPlayer")

var state: State = State.IDLE
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _home: Vector3
var _target: Vector3
var _state_timer: float = 0.0
var _stuck_timer: float = 0.0
var _face_yaw_target: float = 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_apply_animal_style()
	Modules.on_swap("animals", self, func(_m: AssetModule) -> void: _apply_animal_style())

	add_to_group(&"animals")
	_rng.randomize()
	_home = global_position
	_face_yaw_target = rotation.y
	_interaction_zone.interacted.connect(_on_interacted)
	TimeManager.day_started.connect(_on_day_started)
	_enter_idle()
	# Let the HUD show the starting value.
	_emit_affection.call_deferred()


func _physics_process(delta: float) -> void:
	_state_timer -= delta
	var desired := Vector3.ZERO

	match state:
		State.IDLE:
			if _state_timer <= 0.0:
				_enter_wander()
		State.WANDER:
			var to_target := _target - global_position
			to_target.y = 0.0
			if to_target.length() < 0.3 or _state_timer <= 0.0:
				_enter_idle()
			else:
				desired = to_target.normalized() * walk_speed
				_face_yaw_target = atan2(to_target.x, to_target.z)
				# Pick a new target if we are blocked (fence, player...).
				if get_real_velocity().length() < walk_speed * 0.2:
					_stuck_timer += delta
					if _stuck_timer > 1.0:
						_enter_idle()
				else:
					_stuck_timer = 0.0
		State.REACT:
			if _state_timer <= 0.0:
				_enter_idle()

	rotation.y = lerp_angle(rotation.y, _face_yaw_target, 1.0 - exp(-turn_speed * delta))
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(desired, 3.0 * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	velocity.y = -0.5 if is_on_floor() else velocity.y - _gravity * delta
	move_and_slide()

	if _visual is CharacterVisual:
		(_visual as CharacterVisual).set_locomotion(horizontal.length() / maxf(walk_speed, 0.01))


func _enter_idle() -> void:
	state = State.IDLE
	_stuck_timer = 0.0
	_state_timer = _rng.randf_range(idle_time_range.x, idle_time_range.y)
	# Sometimes graze (or bleat) while idling.
	if _rng.randf() < idle_bleat_chance and is_node_ready():
		bleat()
		if _visual is CharacterVisual:
			(_visual as CharacterVisual).play_action(&"bleat")
	elif _rng.randf() < 0.6 and _visual is CharacterVisual:
		(_visual as CharacterVisual).play_action(&"graze")


func _enter_wander() -> void:
	state = State.WANDER
	_stuck_timer = 0.0
	var angle := _rng.randf() * TAU
	var dist := sqrt(_rng.randf()) * wander_radius
	_target = _home + Vector3(cos(angle), 0.0, sin(angle)) * dist
	_state_timer = 12.0


func _on_day_started(_day: int) -> void:
	if affection >= wool_affection:
		wool_ready = true
		_interaction_zone.set_action_text("collect wool")


func _on_interacted(interactor: Node3D) -> void:
	if wool_ready:
		wool_ready = false
		Economy.add_item("wool", 1)
		GameEvents.notification_requested.emit("Got 1 Wool - sell it at the bin or the market")
		_interaction_zone.set_action_text("pet the %s" % display_name.to_lower())
	state = State.REACT
	velocity.x = 0.0
	velocity.z = 0.0
	var to_player := interactor.global_position - global_position
	to_player.y = 0.0
	if to_player.length() > 0.01:
		_face_yaw_target = atan2(to_player.x, to_player.z)

	var duration := 1.2
	if _visual is CharacterVisual:
		var v := _visual as CharacterVisual
		v.set_look_target(interactor.global_position + Vector3.UP * 1.5)
		duration = maxf(duration, v.play_action(&"hop"))
		v.play_action(&"bleat")
	_state_timer = duration
	bleat()

	var previous := affection
	affection = mini(affection + 1, max_affection)
	_emit_affection()
	if affection == max_affection and previous != max_affection:
		GameEvents.notification_requested.emit("%s loves you!" % display_name)
	_spawn_floating_text(BLEATS[_rng.randi() % BLEATS.size()])


## Plays a random bleat variant with a random pitch. Returns true if a sound started.
func bleat() -> bool:
	if _bleat_player == null or bleat_sounds.is_empty():
		return false
	_bleat_player.stream = bleat_sounds[_rng.randi() % bleat_sounds.size()]
	_bleat_player.pitch_scale = _rng.randf_range(bleat_pitch_range.x, bleat_pitch_range.y)
	_bleat_player.play()
	bleats_played += 1
	return true


func _emit_affection() -> void:
	GameEvents.affection_changed.emit(display_name, affection, max_affection)


func _spawn_floating_text(text: String) -> void:
	var label := FLOATING_TEXT_SCENE.instantiate() as Label3D
	label.text = text
	var parent := get_parent()
	# Position is set before entering the tree so the rise tween starts from here.
	label.position = (parent as Node3D).to_local(_text_anchor.global_position) if parent is Node3D else _text_anchor.global_position
	parent.add_child(label)


func _apply_animal_style() -> void:
	var style := Modules.style("animals") as AnimalStyle
	if style == null:
		return
	var vis := get_node_or_null(^"Visual") as Node3D
	if vis == null:
		return
	for mi in vis.find_children("*", "MeshInstance3D", true, false):
		var mat := (mi as MeshInstance3D).get_active_material(0)
		if mat is StandardMaterial3D:
			var name_l := str(mi.name).to_lower()
			if "body" in name_l or "wool" in name_l or "fleece" in name_l:
				(mat as StandardMaterial3D).albedo_color = style.wool_color
			elif "head" in name_l or "face" in name_l:
				(mat as StandardMaterial3D).albedo_color = style.face_color
