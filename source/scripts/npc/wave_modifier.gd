class_name WaveModifier
extends SkeletonModifier3D
## v5a procedural wave (the UAL clip library has no wave): after the
## AnimationTree, raises the right upper arm up and out and swings the forearm
## side to side. Works in skeleton space, so it doesn't depend on the bone
## roll of the rig. `weight` (0..1) fades it in and out; `raise` scales the
## arm lift and `speed` is the wave frequency (GestureStyle).

var weight: float = 0.0
var raise: float = 1.0
var speed: float = 2.4
var _t: float = 0.0
## Skeleton-space hand height after the last modification (tests / debug:
## poses read from outside the modifier are the un-modified animation).
var last_hand_height: float = 0.0


func _process_modification_with_delta(delta: float) -> void:
	_t += delta
	var sk := get_skeleton()
	if sk == null or weight <= 0.001:
		return
	var upper := sk.find_bone("upperarm_r")
	var lower := sk.find_bone("lowerarm_r")
	var hand := sk.find_bone("hand_r")
	if upper < 0 or lower < 0 or hand < 0:
		return
	# Which side of the body this arm is on (skeleton origin is the body centre).
	var side := signf(sk.get_bone_global_pose(upper).origin.x)
	if side == 0.0:
		side = -1.0
	# Upper arm: out to the side and up (skeleton space, +y up, +z forward).
	var up_dir := Vector3(side * (0.9 - 0.45 * raise), 0.35 + 0.65 * raise, 0.0).normalized()
	_aim(sk, upper, lower, up_dir)
	# Forearm: mostly up, swinging left / right.
	var swing := sin(_t * TAU * speed) * 0.55
	var fore_dir := Vector3(side * 0.15 + swing, 1.0, 0.0).normalized()
	_aim(sk, lower, hand, fore_dir)
	last_hand_height = sk.get_bone_global_pose(hand).origin.y


## Rotates `bone` (blended by weight) so that the direction to `child` points along `dir`.
func _aim(sk: Skeleton3D, bone: int, child: int, dir: Vector3) -> void:
	var g := sk.get_bone_global_pose(bone)
	var cur := (sk.get_bone_global_pose(child).origin - g.origin).normalized()
	if cur.length() < 0.5:
		return
	var q := Quaternion(cur, dir.normalized())
	var target := Basis(q) * g.basis
	var parent := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(parent) if parent >= 0 else Transform3D.IDENTITY
	var local := (pg.basis.inverse() * target).get_rotation_quaternion()
	var now := sk.get_bone_pose_rotation(bone)
	sk.set_bone_pose_rotation(bone, now.slerp(local, clampf(weight, 0.0, 1.0)))
