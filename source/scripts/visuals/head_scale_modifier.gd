class_name HeadScaleModifier
extends SkeletonModifier3D
## v6b faces: scales the head bone after the animation (rounder / narrower
## face shapes from the character creator and npc_looks). Hair, beard and brows
## follow because they hang on the head bone.

var head_scale: float = 1.0
var _bone: int = -2


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if _bone == -2:
		_bone = sk.find_bone("Head")
	if _bone < 0:
		return
	sk.set_bone_pose_scale(_bone, Vector3(head_scale * 0.98, head_scale, head_scale * 1.02))
