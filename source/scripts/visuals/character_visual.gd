class_name CharacterVisual
extends Node3D
## Base class / interface for the "Visual" node of a character or animal.
##
## Gameplay scripts (player.gd, sheep.gd) ONLY talk to the visual through these
## methods, so the placeholder primitives can be replaced by a real model
## (e.g. a Blender/Mixamo .glb) without touching gameplay code:
##   * placeholder_human_visual.gd / placeholder_sheep_visual.gd  -> procedural animation of primitives
##   * animated_model_visual.gd                                    -> drives an imported model's AnimationPlayer
##
## Convention: the model faces +Z (glTF / Blender / Mixamo default).


## Called every physics frame. 0 = standing, 1 = walking, ~2 = running.
func set_locomotion(_speed_ratio: float) -> void:
	pass


## Play a one-shot action such as &"pet", &"hop", &"graze", &"bleat".
## Returns the action's duration in seconds (0 if unsupported).
func play_action(_action: StringName) -> float:
	return 0.0


## Optional: point the head/eyes at a world position (Vector3.INF = look ahead).
func set_look_target(_world_position: Vector3) -> void:
	pass
