class_name GroundSitModifier
extends SkeletonModifier3D
## Turns the chair-sitting clip into "sitting on the ground": straightens the
## knees so the legs stretch forward along the ground. Runs after the
## AnimationTree each frame (SkeletonModifier3D), only while active.


func _process_modification_with_delta(_delta: float) -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	for side in ["l", "r"]:
		var calf := sk.find_bone("calf_" + side)
		var foot := sk.find_bone("foot_" + side)
		if calf >= 0:
			sk.set_bone_pose_rotation(calf, sk.get_bone_rest(calf).basis.get_rotation_quaternion())
		if foot >= 0:
			sk.set_bone_pose_rotation(foot, sk.get_bone_rest(foot).basis.get_rotation_quaternion())
