class_name HumanoidModelVisual
extends AnimatedModelVisual
## Rigged, skinned humanoid (Quaternius "Universal Base Characters", CC0) driven
## by the Quaternius "Universal Animation Library" (CC0) through an AnimationTree:
##   * locomotion = BlendSpace1D (idle / walk / jog / sprint) keyed by real
##     ground speed in m/s, so the feet plant instead of sliding;
##   * one-shots / poses in a state machine: jump (start/loop/land), sit
##     (enter/idle/exit), ground sit, interact, pick up, kneel, talk;
##   * a filtered Blend2 that holds the arms forward while carrying something.
##
## Clothes: the base body mesh is split ONCE per body type into surfaces
## (skin / shirt / trousers / boots / belt) by region, so every character gets
## its own outfit colours through cheap per-instance material overrides
## (no extra textures). Hair is a separate CC0 mesh on a BoneAttachment3D.
##
## Gameplay never touches any of this: it calls the CharacterVisual API
## (set_locomotion, play_action, set_look_target) plus the optional extras
## below (set_ground_speed, set_airborne, set_pose, set_carrying).

## Hip height of the animation rig's rest pose (the library was authored on it).
const ANIM_PELVIS_REST := 0.9167

## Ground speed (m/s) at which each locomotion clip's feet stay planted.
## Measured from the clips (see tools note in README).
const WALK_CLIP_SPEED := 1.45
const JOG_CLIP_SPEED := 3.3
const SPRINT_CLIP_SPEED := 5.6

@export_enum("male", "female") var body_type: String = "male"
@export_range(0, 1) var skin_tone: int = 0
@export var skin_tint: Color = Color(1, 1, 1)
@export var hair_style: String = "Hair_SimpleParted"
@export var hair_color: Color = Color(0.25, 0.16, 0.09)
@export var beard: bool = false
@export_enum("work_shirt", "tshirt", "jacket") var top_style: String = "work_shirt"
@export var shirt_color: Color = Color(0.36, 0.45, 0.58)
@export var pants_color: Color = Color(0.17, 0.24, 0.38)
@export var boots_color: Color = Color(0.27, 0.17, 0.1)
@export var belt_color: Color = Color(0.2, 0.13, 0.08)
## Uniform scale (1.0 = 1.82 m tall male base).
@export var body_scale: float = 0.96
## v6b character creator / npc_looks: body width (slim < 1 < sturdy) and
## height multipliers, eyebrow mesh ("" = none), head size (face shape).
@export var body_width: float = 1.0
@export var body_height: float = 1.0
@export var brows: String = ""
@export var head_scale: float = 1.0

## v6b wardrobe tops: sleeve end (|x|/h) and neckline per shape.
const TOP_SHAPES := {"work_shirt": [0.315, 0.82], "tshirt": [0.2, 0.805], "jacket": [0.36, 0.83], "polo": [0.205, 0.82],
	"long_sleeve": [0.355, 0.815], "tank": [0.135, 0.79]}

static var _split_cache: Dictionary = {}  ## "male/work_shirt" -> ArrayMesh
static var _library_cache: Dictionary = {}  ## body -> AnimationLibrary with hips fixed
static var _material_cache: Dictionary = {}


## Drops cached meshes / animation libraries / materials (style swap, exit).
static func clear_caches() -> void:
	_split_cache.clear()
	_library_cache.clear()
	_material_cache.clear()

var model: Node3D
var skeleton: Skeleton3D
var anim_tree: AnimationTree
var hold_point: Node3D  ## carried objects attach here (in front of the chest)
var hand_point: BoneAttachment3D  ## right hand (fishing rod...)
var _playback: AnimationNodeStateMachinePlayback
var _speed: float = 0.0
var _lift_t: float = 0.0
var _airborne: bool = false
var _pose: StringName = &""
var _carry_amount: float = 0.0
var _carry_target: float = 0.0
var _body_mesh: MeshInstance3D
var outfit_material: ShaderMaterial
var _leg_modifier: GroundSitModifier



func _char_style() -> CharacterStyle:
	return Modules.style("characters") as CharacterStyle


func _style_models() -> Dictionary:
	var st := _char_style()
	return st.models if st else {"male": "res://assets/third_party/quaternius/characters/Superhero_Male_FullBody.gltf", "female": "res://assets/third_party/quaternius/characters/Superhero_Female_FullBody.gltf"}


func _style_skins() -> Dictionary:
	var st := _char_style()
	if st and not st.skins.is_empty():
		return st.skins
	var d := "res://assets/third_party/quaternius/characters/"
	return {"male": [d + "T_Superhero_Male_Ligh.png", d + "T_Superhero_Male_Dark.png"],
		"female": [d + "T_Superhero_Female_Light_BaseColor.png", d + "T_Superhero_Female_Dark_BaseColor.png"]}


func _style_shader() -> Shader:
	var st := _char_style()
	return load(st.outfit_shader) as Shader if st else preload("res://assets/shaders/humanoid_outfit.gdshader")


func _style_anim() -> String:
	var st := _char_style()
	return st.animation_library if st else "res://assets/third_party/quaternius/animations/UAL1_Standard.glb"


func _style_hair() -> String:
	var st := _char_style()
	return st.hair_dir if st else "res://assets/third_party/quaternius/characters/hair/"


func _ready() -> void:
	var st0 := _char_style()
	if st0:
		body_scale = st0.body_scale

	_build_model()
	_build_tree()


# ------------------------------------------------------------------ building
func _build_model() -> void:
	var scene: PackedScene = load(str(_style_models().get(body_type, _style_models()["male"])))
	model = scene.instantiate() as Node3D
	model.name = "Model"
	model.scale = Vector3(body_scale * body_width, body_scale * body_height, body_scale * body_width)
	add_child(model)
	skeleton = model.find_child("Skeleton3D", true, false) as Skeleton3D
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("SuperHero") or m.name.begins_with("Superhero"):
			_body_mesh = m
	if _body_mesh:
		_body_mesh.mesh = _prepare_mesh(_body_mesh.mesh)
		_apply_outfit()
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_attach_boots()
	if hair_style != "":
		_attach_hair(hair_style)
	if beard:
		_attach_hair("Hair_Beard")
	if brows != "":
		_attach_hair(brows)
	if not is_equal_approx(head_scale, 1.0):
		var hm := HeadScaleModifier.new()
		hm.name = "HeadScaleModifier"
		hm.head_scale = head_scale
		skeleton.add_child(hm)
	# Hold point for carried props: in front of the chest, follows the upper body.
	var chest := BoneAttachment3D.new()
	chest.name = "ChestAttachment"
	chest.bone_name = "spine_03"
	skeleton.add_child(chest)
	hold_point = Node3D.new()
	hold_point.name = "HoldPoint"
	add_child(hold_point)
	hold_point.position = Vector3(0, 1.05, 0.42)
	hand_point = BoneAttachment3D.new()
	hand_point.name = "RightHand"
	hand_point.bone_name = "hand_r"
	skeleton.add_child(hand_point)
	_leg_modifier = GroundSitModifier.new()
	_leg_modifier.name = "GroundSitModifier"
	skeleton.add_child(_leg_modifier)
	_leg_modifier.active = false


func _attach_hair(style: String) -> void:
	var path := _style_hair() + style + ".gltf"
	if not ResourceLoader.exists(path) or skeleton == null:
		return
	var head := skeleton.find_bone("Head")
	if head < 0:
		return
	var attach := BoneAttachment3D.new()
	attach.name = "Hair_" + style
	attach.bone_name = "Head"
	skeleton.add_child(attach)
	var hair := (load(path) as PackedScene).instantiate() as Node3D
	# The hair meshes are modelled in body space ("origin at 0").
	hair.transform = skeleton.get_bone_global_rest(head).affine_inverse()
	attach.add_child(hair)
	var mat := _hair_material(hair_color)
	for mi in hair.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			m.set_surface_override_material(s, mat)


## Simple leather boots over the feet (the base mesh has modelled toes), built
## once per body type from the foot's bind-pose bounds and attached to the foot bones.
func _attach_boots() -> void:
	if _body_mesh == null:
		return
	var mat := _boot_material(boots_color)
	for side in ["l", "r"]:
		var bone := skeleton.find_bone("foot_" + side)
		if bone < 0:
			continue
		var attach := BoneAttachment3D.new()
		attach.name = "Boot_" + side
		attach.bone_name = "foot_" + side
		skeleton.add_child(attach)
		var mi := MeshInstance3D.new()
		mi.mesh = _boot_mesh(side)
		mi.material_override = mat
		mi.transform = skeleton.get_bone_global_rest(bone).affine_inverse()
		attach.add_child(mi)


func _boot_mesh(side: String) -> Mesh:
	var key := "boot_%s_%s" % [body_type, side]
	if _split_cache.has(key):
		return _split_cache[key]
	var verts: PackedVector3Array = _body_mesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var lo := Vector3(INF, INF, INF)
	var hi := -lo
	var sign_x := 1.0 if side == "l" else -1.0
	for v in verts:
		if v.y < 0.105 and v.x * sign_x > 0.03:
			lo = lo.min(v)
			hi = hi.max(v)
	var size := hi - lo
	var center := (lo + hi) * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Foot part: a rounded ellipsoid shell, flattened at the sole.
	var foot := SphereMesh.new()
	foot.radius = 0.5
	foot.height = 1.0
	foot.radial_segments = 14
	foot.rings = 8
	var foot_basis := Basis.from_scale(Vector3(size.x * 1.22, size.y * 1.5, size.z * 1.1))
	st.append_from(foot, 0, Transform3D(foot_basis, Vector3(center.x, lo.y + size.y * 0.55, center.z + size.z * 0.02)))
	var sole := BoxMesh.new()
	sole.size = Vector3(size.x * 1.18, 0.025, size.z * 1.08)
	st.append_from(sole, 0, Transform3D(Basis.IDENTITY, Vector3(center.x, lo.y + 0.004, center.z + size.z * 0.02)))
	# Shaft around the ankle.
	var shaft := CylinderMesh.new()
	shaft.top_radius = size.x * 0.5
	shaft.bottom_radius = size.x * 0.56
	shaft.height = 0.12
	shaft.radial_segments = 14
	shaft.rings = 1
	st.append_from(shaft, 0, Transform3D(Basis.IDENTITY, Vector3(center.x, lo.y + 0.12, lo.z + size.z * 0.3)))
	st.generate_normals()
	var mesh := st.commit()
	_split_cache[key] = mesh
	return mesh


func _boot_material(color: Color) -> Material:
	var key := "boot_" + color.to_html()
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.45
	m.albedo_texture = preload("res://assets/materials/detail_noise_tex.tres")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 6.0
	_material_cache[key] = m
	return m


func _hair_material(color: Color) -> Material:
	var key := "hair_" + color.to_html()
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(_style_hair() + "T_Hair_1_BaseColor.png")
	m.albedo_color = color * 2.2
	m.normal_enabled = true
	m.normal_texture = load(_style_hair() + "T_Hair_1_Normal.png")
	m.roughness = 0.62
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_material_cache[key] = m
	return m


## Adds UV2 = bind-pose (height, |x|) / body height to the body mesh (once per
## body type). The outfit shader paints clothes from it per pixel.
func _prepare_mesh(source: Mesh) -> ArrayMesh:
	if _split_cache.has(body_type):
		return _split_cache[body_type]
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var h := source.get_aabb().size.y
	var uv2 := PackedVector2Array()
	uv2.resize(verts.size())
	for i in verts.size():
		uv2[i] = Vector2(verts[i].y / h, absf(verts[i].x) / h)
	arrays[Mesh.ARRAY_TEX_UV2] = uv2
	var fmt: int = source.surface_get_format(0)
	var flags: int = fmt & ~Mesh.ARRAY_FLAG_COMPRESS_ATTRIBUTES
	var out := ArrayMesh.new()
	out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
	_split_cache[body_type] = out
	return out


func _apply_outfit() -> void:
	var m := ShaderMaterial.new()
	m.shader = (_style_shader())
	var tex_path: String = _style_skins()[body_type][clampi(skin_tone, 0, 1)]
	var kind := "Male" if body_type == "male" else "Female"
	m.set_shader_parameter(&"skin_albedo", load(tex_path))
	m.set_shader_parameter(&"skin_normal", load(tex_path.get_base_dir() + "/T_Superhero_%s_Normal.png" % kind))
	m.set_shader_parameter(&"skin_roughness", load(tex_path.get_base_dir() + "/T_Superhero_%s_Roughness.png" % kind))
	m.set_shader_parameter(&"fabric_noise", preload("res://assets/materials/detail_noise_tex.tres"))
	m.set_shader_parameter(&"fabric_normal", preload("res://assets/materials/detail_normal_tex.tres"))
	m.set_shader_parameter(&"skin_tint", skin_tint)
	m.set_shader_parameter(&"shirt_color", shirt_color)
	m.set_shader_parameter(&"pants_color", pants_color)
	m.set_shader_parameter(&"boots_color", boots_color)
	m.set_shader_parameter(&"belt_color", belt_color)
	var shape: Array = TOP_SHAPES.get(top_style, TOP_SHAPES["work_shirt"])
	m.set_shader_parameter(&"sleeve_end", float(shape[0]))
	m.set_shader_parameter(&"collar", float(shape[1]))
	m.set_shader_parameter(&"pants_check", 1.0 if pants_color.b > pants_color.r * 1.3 else 0.0)
	_body_mesh.material_override = m
	outfit_material = m


## v6b: change the top shape (wardrobe) without rebuilding the model.
func set_top_style(style_id: String) -> void:
	top_style = style_id
	if outfit_material:
		var shape: Array = TOP_SHAPES.get(top_style, TOP_SHAPES["work_shirt"])
		outfit_material.set_shader_parameter(&"sleeve_end", float(shape[0]))
		outfit_material.set_shader_parameter(&"collar", float(shape[1]))


## v6b character creator: rebuilds the model with the current exports (body
## type, width, hair, beard, brows, head, skin). Pose resets to standing.
var rebuilds: int = 0


func rebuild() -> void:
	if model:
		remove_child(model)
		model.queue_free()
	if hold_point:
		remove_child(hold_point)
		hold_point.queue_free()
	model = null
	skeleton = null
	anim_tree = null
	_body_mesh = null
	_pose = &""
	_carry_amount = 0.0
	_carry_target = 0.0
	_build_model()
	_build_tree()
	rebuilds += 1


## Recolour at runtime (e.g. NPC uniforms, customisation screen later).
func set_outfit_colors(shirt: Color, pants: Color, boots: Color = boots_color) -> void:
	shirt_color = shirt
	pants_color = pants
	boots_color = boots
	if outfit_material:
		outfit_material.set_shader_parameter(&"shirt_color", shirt)
		outfit_material.set_shader_parameter(&"pants_color", pants)
		outfit_material.set_shader_parameter(&"boots_color", boots)


func _library() -> AnimationLibrary:
	if _library_cache.has(body_type):
		return _library_cache[body_type]
	var src: AnimationLibrary = load(_style_anim())
	var lib := AnimationLibrary.new()
	# Hips: scale the pelvis translation to this body's leg length so the feet
	# touch the ground (the clips only animate hip position + bone rotations).
	var ratio := 1.0
	if skeleton:
		var pelvis := skeleton.find_bone("pelvis")
		ratio = skeleton.get_bone_rest(pelvis).origin.z / ANIM_PELVIS_REST
	for anim_name in src.get_animation_list():
		var a := (src.get_animation(anim_name) as Animation).duplicate(true) as Animation
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				for k in a.track_get_key_count(t):
					var v: Vector3 = a.track_get_key_value(t, k)
					a.track_set_key_value(t, k, v * ratio)
		if String(anim_name) in ["Idle", "Walk", "Jog_Fwd", "Sprint", "Jump", "Sitting_Idle", "Crouch_Idle", "Idle_Talking", "Push", "Walk_Formal"]:
			a.loop_mode = Animation.LOOP_LINEAR
		else:
			a.loop_mode = Animation.LOOP_NONE
		lib.add_animation(anim_name, a)
	_library_cache[body_type] = lib
	return lib


func _clip(clip: String) -> AnimationNodeAnimation:
	var n := AnimationNodeAnimation.new()
	n.animation = StringName(clip)
	return n


func _build_tree() -> void:
	animation_player = AnimationPlayer.new()
	animation_player.name = "AnimationPlayer"
	model.add_child(animation_player)
	animation_player.root_node = ^".."
	animation_player.add_animation_library(&"", _library())

	var sm := AnimationNodeStateMachine.new()
	var loco := AnimationNodeBlendSpace1D.new()
	loco.add_blend_point(_clip("Idle"), 0.0, -1, &"idle")
	loco.add_blend_point(_clip("Walk"), WALK_CLIP_SPEED, -1, &"walk")
	loco.add_blend_point(_clip("Jog_Fwd"), JOG_CLIP_SPEED, -1, &"jog")
	loco.add_blend_point(_clip("Sprint"), SPRINT_CLIP_SPEED, -1, &"sprint")
	loco.min_space = 0.0
	loco.max_space = 8.0
	loco.sync = true
	var loco_tree := AnimationNodeBlendTree.new()
	loco_tree.add_node(&"space", loco)
	var time_scale := AnimationNodeTimeScale.new()
	loco_tree.add_node(&"scale", time_scale)
	loco_tree.connect_node(&"scale", 0, &"space")
	loco_tree.connect_node(&"output", 0, &"scale")
	sm.add_node(&"loco", loco_tree)
	var clips := {
		&"jump_start": "Jump_Start", &"jump_loop": "Jump", &"jump_land": "Jump_Land",
		&"sit_enter": "Sitting_Enter", &"sit_idle": "Sitting_Idle", &"sit_exit": "Sitting_Exit",
		&"ground_sit": "Sitting_Idle", &"interact": "Interact", &"pickup": "PickUp_Table",
		&"kneel": "Fixing_Kneeling", &"talk": "Idle_Talking",
	}
	for state in clips:
		sm.add_node(state, _clip(clips[state]))
	_link(sm, &"Start", &"loco", true, 0.0)
	for state in clips:
		_link(sm, &"loco", state, false, 0.15)
		_link(sm, state, &"loco", false, 0.2)
	_link(sm, &"jump_start", &"jump_loop", true, 0.1)
	_link(sm, &"jump_start", &"jump_land", false, 0.08)
	_link(sm, &"jump_loop", &"jump_land", false, 0.08)
	# v7b.1: leave the landing early (see _process) so walking resumes at once.
	_link(sm, &"jump_land", &"loco", false, 0.15)
	_link(sm, &"sit_enter", &"sit_idle", true, 0.1)
	_link(sm, &"sit_idle", &"sit_exit", false, 0.1)
	_link(sm, &"sit_exit", &"loco", true, 0.2)
	_link(sm, &"interact", &"loco", true, 0.2)
	_link(sm, &"pickup", &"loco", true, 0.2)

	var root := AnimationNodeBlendTree.new()
	root.add_node(&"sm", sm)
	var carry_pose := AnimationNodeBlendTree.new()
	carry_pose.add_node(&"clip", _clip("Push"))
	var freeze := AnimationNodeTimeScale.new()
	carry_pose.add_node(&"freeze", freeze)
	carry_pose.connect_node(&"freeze", 0, &"clip")
	carry_pose.connect_node(&"output", 0, &"freeze")
	root.add_node(&"carry_pose", carry_pose)
	var carry := AnimationNodeBlend2.new()
	carry.filter_enabled = true
	for bone in ["clavicle_l", "upperarm_l", "lowerarm_l", "hand_l", "clavicle_r", "upperarm_r", "lowerarm_r", "hand_r"]:
		carry.set_filter_path(NodePath("Armature/Skeleton3D:" + bone), true)
	root.add_node(&"carry", carry)
	root.connect_node(&"carry", 0, &"sm")
	root.connect_node(&"carry", 1, &"carry_pose")
	root.connect_node(&"output", 0, &"carry")

	anim_tree = AnimationTree.new()
	anim_tree.name = "AnimationTree"
	anim_tree.tree_root = root
	model.add_child(anim_tree)
	anim_tree.root_node = ^".."
	anim_tree.anim_player = anim_tree.get_path_to(animation_player)
	anim_tree.active = true
	anim_tree.set(&"parameters/sm/loco/scale/scale", 1.0)
	anim_tree.set(&"parameters/carry_pose/freeze/scale", 0.0)
	anim_tree.set(&"parameters/carry/blend_amount", 0.0)
	_playback = anim_tree.get(&"parameters/sm/playback") as AnimationNodeStateMachinePlayback


func _link(sm: AnimationNodeStateMachine, from: StringName, to: StringName, at_end: bool, xfade: float) -> void:
	if sm.has_transition(from, to):
		sm.remove_transition(from, to)
	var t := AnimationNodeStateMachineTransition.new()
	t.xfade_time = xfade
	if at_end:
		t.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_AT_END
		t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_AUTO
	else:
		t.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
	sm.add_transition(from, to, t)


# ------------------------------------------------------------------ runtime
func _process(delta: float) -> void:
	if anim_tree == null:
		return
	_carry_amount = move_toward(_carry_amount, _carry_target, delta * 4.0)
	anim_tree.set(&"parameters/carry/blend_amount", _carry_amount)
	# v6a poses: jogging on a treadmill (run in place), lifting (repeat the
	# interact clip), lying on a towel / bench (whole body tipped back).
	var spd := _speed
	if _pose == &"jog":
		spd = 3.2
	elif _pose == &"lift":
		_lift_t += delta
		if _lift_t > 1.3:
			_lift_t = 0.0
			_playback.start(&"interact")
	anim_tree.set(&"parameters/sm/loco/space/blend_position", spd)
	_unstick(delta)
	var lie := _pose == &"lie"
	model.rotation.x = move_toward(model.rotation.x, -PI * 0.5 if lie else 0.0, delta * 4.0)
	# Above the sprint clip's speed, play faster instead of sliding.
	anim_tree.set(&"parameters/sm/loco/scale/scale", maxf(1.0, _speed / SPRINT_CLIP_SPEED))
	# Lower the whole body while sitting on the ground (the chair pose's hips
	# are ~0.45 m up; the modifier straightens the legs forward).
	var ground := _pose == &"ground_sit"
	model.position.y = move_toward(model.position.y, -0.4 if ground else (0.14 if lie else 0.0), delta * 1.5)
	_leg_modifier.active = ground


## v7b.1 watchdog: whatever order jump / land / pose calls arrive in, never stay
## frozen in a jump or pose clip once the character is back on the ground and
## standing (Space used to leave the jump pose stuck).
var _state_name: StringName = &""
var _state_t: float = 0.0
## Times the watchdog had to rescue a stuck state (smoke / diagnostics).
var unsticks: int = 0
const _POSE_STATES := {&"kneel": &"kneel", &"ground_sit": &"ground_sit", &"talk": &"talk",
	&"sit_enter": &"sit", &"sit_idle": &"sit"}


func _unstick(delta: float) -> void:
	if _playback == null:
		return
	var cur := _playback.get_current_node()
	if cur != _state_name:
		_state_name = cur
		_state_t = 0.0
	_state_t += delta
	if _airborne:
		return
	match cur:
		&"jump_start", &"jump_loop":
			if _state_t > 0.12:
				_playback.travel(&"jump_land")
			if _state_t > 0.6:
				unsticks += 1
				_playback.start(&"loco")
		&"jump_land":
			# Short landing: walk away after 0.25 s, standing still after 0.5 s.
			if _state_t > (0.25 if _speed > 0.6 else 0.5):
				_playback.travel(&"loco")
			if _state_t > 1.6:
				unsticks += 1
				_playback.start(&"loco")
		_:
			if _POSE_STATES.has(cur) and _POSE_STATES[cur] != _pose and _state_t > 0.4:
				# A pose clip with no pose set (e.g. stood up mid-jump): back to walking.
				if _state_t > 1.2:
					unsticks += 1
					_playback.start(&"loco")
				else:
					_playback.travel(&"loco")


func is_airborne() -> bool:
	return _airborne


## CharacterVisual API: 0 idle, 1 walk, 2 run (ratio of walk speed). Prefer set_ground_speed().
func set_locomotion(speed_ratio: float) -> void:
	_speed = speed_ratio * WALK_CLIP_SPEED


## Real horizontal speed in m/s (keeps the feet planted).
func set_ground_speed(meters_per_second: float) -> void:
	_speed = meters_per_second


func current_state() -> StringName:
	return _playback.get_current_node() if _playback else &""


func set_airborne(value: bool) -> void:
	if value == _airborne or _playback == null:
		return
	_airborne = value
	if value:
		_playback.travel(&"jump_start")
	else:
		_playback.travel(&"jump_land")


## Persistent poses: &"sit" (chair/bench), &"ground_sit", &"kneel", &"talk" or &"" (stand).
func set_pose(pose: StringName) -> void:
	if _playback == null or pose == _pose:
		return
	var old := _pose
	_pose = pose
	match pose:
		&"sit":
			_playback.travel(&"sit_enter")
		&"ground_sit":
			_playback.travel(&"ground_sit")
		&"kneel":
			_playback.travel(&"kneel")
		&"talk":
			_playback.travel(&"talk")
		&"lie", &"jog":
			_playback.travel(&"loco")
		&"lift":
			_lift_t = 0.0
			_playback.travel(&"interact")
		_:
			if old == &"sit":
				_playback.travel(&"sit_exit")
			else:
				_playback.travel(&"loco")


func get_pose() -> StringName:
	return _pose


func set_carrying(value: bool) -> void:
	_carry_target = 1.0 if value else 0.0


func play_action(action: StringName) -> float:
	if _playback == null:
		return 0.0
	if _pose != &"" or _airborne:
		return 0.0
	match action:
		&"pet", &"interact", &"use":
			_playback.travel(&"interact")
			return 0.9
		&"pickup":
			_playback.travel(&"pickup")
			return 0.8
	return 0.0
