class_name SpatialListener
extends AudioListener3D
## v7b.1 spatial_audio module consumer: the one current AudioListener3D. Every
## frame (late, after the cameras moved) it takes the rotation of whatever
## Camera3D is current - the follow camera, the cockpit camera, the camera on a
## possessed resident - and sits between that camera and the character it
## looks at (listener_pull). So AudioStreamPlayer3D sounds pan left / right by
## direction and fade by distance exactly as the player sees them.

var follows: String = ""     ## name of the camera being followed (debug / smoke)
var updates: int = 0


func style() -> SpatialAudioStyle:
	return Modules.style("spatial_audio") as SpatialAudioStyle


func _ready() -> void:
	name = "SpatialListener"
	process_priority = 1000
	process_physics_priority = 1000
	make_current.call_deferred()


func _process(_delta: float) -> void:
	follow_now()


func _physics_process(_delta: float) -> void:
	# Cameras moved with physics interpolation still end up current here.
	if not is_current():
		make_current()


func follow_now() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var st := style()
	var pull := st.listener_pull if st and st.enabled else 0.0
	var origin := cam.global_position
	var focus := focus_point()
	if pull > 0.0 and focus != Vector3.INF and focus.distance_to(origin) < 25.0:
		origin = origin.lerp(focus, pull)
	global_transform = Transform3D(cam.global_basis.orthonormalized(), origin)
	follows = String(cam.name)
	updates += 1


## Head of the character the camera is about: possessed resident, else the farmer.
func focus_point() -> Vector3:
	var scene := get_tree().current_scene
	if scene == null:
		return Vector3.INF
	var v7a := scene.get_node_or_null(^"V7aWorld")
	if v7a and "possession" in v7a:
		var pos: Node = v7a.get("possession")
		if pos and pos.has_method("is_active") and pos.call("is_active"):
			var b := pos.get("bot") as Node3D
			if b and is_instance_valid(b):
				return b.global_position + Vector3.UP * 1.6
	var pl := get_tree().get_first_node_in_group(&"player") as Node3D
	return pl.global_position + Vector3.UP * 1.6 if pl else Vector3.INF


## Stereo position of a world point: -1 = fully left, 0 = centre, 1 = right.
func pan_of(world_pos: Vector3) -> float:
	var local := global_transform.affine_inverse() * world_pos
	var l := local.length()
	return clampf(local.x / l, -1.0, 1.0) if l > 0.001 else 0.0


## Equal-power left / right gains for a world point (what the mixer does with
## panning_strength = 1): a sound on the left is louder in the left ear.
func gains_of(world_pos: Vector3) -> Vector2:
	var pan := pan_of(world_pos)
	return Vector2(sqrt(0.5 * (1.0 - pan)), sqrt(0.5 * (1.0 + pan)))
