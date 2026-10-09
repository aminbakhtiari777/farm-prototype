class_name AnimatedModelVisual
extends CharacterVisual
## Adapter for a REAL imported model (e.g. a .glb from Blender or Mixamo).
##
## Usage: make a Node3D named "Visual", attach this script, instance your .glb
## as its child, then fill in the animation names below. Gameplay scripts keep
## working unchanged because they only call the CharacterVisual methods.
## Any action without an animation falls back to a small procedural bounce.

## Leave empty to auto-detect the first AnimationPlayer inside the model.
@export var animation_player: AnimationPlayer
@export var idle_animation: StringName = &"idle"
@export var walk_animation: StringName = &"walk"
@export var run_animation: StringName = &"run"
## Speed ratio above which the run animation is used.
@export var run_threshold: float = 1.4
## Map gameplay actions to clip names, e.g. { &"pet": &"interact", &"hop": &"jump" }.
@export var action_animations: Dictionary = {}
@export var blend_time: float = 0.2

var _action_playing: bool = false


func _ready() -> void:
	if animation_player == null:
		animation_player = _find_animation_player(self)
	if animation_player:
		animation_player.animation_finished.connect(func(_n: StringName) -> void: _action_playing = false)
		_play_loop(idle_animation)


func set_locomotion(speed_ratio: float) -> void:
	if animation_player == null or _action_playing:
		return
	var clip := idle_animation
	if speed_ratio > run_threshold:
		clip = run_animation
	elif speed_ratio > 0.1:
		clip = walk_animation
	_play_loop(clip)
	if clip == walk_animation:
		animation_player.speed_scale = clampf(speed_ratio, 0.6, 1.4)
	else:
		animation_player.speed_scale = 1.0


func play_action(action: StringName) -> float:
	if animation_player and action_animations.has(action):
		var clip: StringName = action_animations[action]
		if animation_player.has_animation(clip):
			_action_playing = true
			animation_player.play(clip, blend_time)
			return animation_player.get_animation(clip).length
	if action == &"hop" or action == &"pet":
		return _procedural_bounce()
	return 0.0


func _play_loop(clip: StringName) -> void:
	if animation_player.has_animation(clip) and animation_player.current_animation != clip:
		animation_player.play(clip, blend_time)


func _procedural_bounce() -> float:
	if get_child_count() == 0:
		return 0.0
	var model := get_child(0) as Node3D
	if model == null:
		return 0.0
	var base_y := model.position.y
	var tween := create_tween()
	tween.tween_property(model, "position:y", base_y + 0.25, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(model, "position:y", base_y, 0.18).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return 0.4


static func _find_animation_player(node: Node) -> AnimationPlayer:
	for child in node.get_children():
		if child is AnimationPlayer:
			return child
		var found := _find_animation_player(child)
		if found:
			return found
	return null
