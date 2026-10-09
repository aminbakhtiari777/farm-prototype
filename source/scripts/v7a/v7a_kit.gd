class_name V7aKit
extends RefCounted
## Small shared helpers for the v7a modules: boxes / cylinders, materials,
## flame + smoke particles (CPUParticles3D - fine on the web Compatibility
## renderer), and the townspeople lookup by name.

static var _soft_tex: GradientTexture2D


static func mat(c: Color, rough: float = 0.85, emissive: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	if emissive > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emissive
	return m


static func box(parent: Node, s: Vector3, p: Vector3, c: Variant, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = c if c is Material else mat(c)
	mi.position = p
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


static func cyl(parent: Node, r: float, h: float, p: Vector3, c: Variant, top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top < 0.0 else top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 10
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = c if c is Material else mat(c)
	mi.position = p
	parent.add_child(mi)
	return mi


static func ball(parent: Node, r: float, p: Vector3, c: Variant) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 10
	sm.rings = 6
	mi.mesh = sm
	mi.material_override = c if c is Material else mat(c)
	mi.position = p
	parent.add_child(mi)
	return mi


static func soft_texture() -> GradientTexture2D:
	if _soft_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		_soft_tex = GradientTexture2D.new()
		_soft_tex.gradient = g
		_soft_tex.fill = GradientTexture2D.FILL_RADIAL
		_soft_tex.fill_from = Vector2(0.5, 0.5)
		_soft_tex.fill_to = Vector2(0.5, 0.0)
		_soft_tex.width = 64
		_soft_tex.height = 64
	return _soft_tex


## Flames (additive, orange -> red) or smoke (grey, alpha blended).
static func particles(kind: String, amount: int, extents: Vector3) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.amount = amount
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = extents
	p.direction = Vector3.UP
	p.spread = 12.0
	var quad := QuadMesh.new()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_texture()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ramp := Gradient.new()
	match kind:
		"flame":
			quad.size = Vector2(0.9, 1.2)
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			p.lifetime = 0.9
			p.initial_velocity_min = 1.4
			p.initial_velocity_max = 2.6
			p.gravity = Vector3(0, 1.5, 0)
			p.scale_amount_min = 0.7
			p.scale_amount_max = 1.5
			ramp.set_color(0, Color(1.0, 0.85, 0.35, 1.0))
			ramp.set_color(1, Color(0.9, 0.15, 0.02, 0.0))
			ramp.add_point(0.4, Color(1.0, 0.45, 0.08, 0.9))
		"water":
			quad.size = Vector2(0.25, 0.25)
			p.lifetime = 0.8
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 10.0
			p.spread = 4.0
			p.gravity = Vector3(0, -6.0, 0)
			ramp.set_color(0, Color(0.85, 0.93, 1.0, 0.9))
			ramp.set_color(1, Color(0.8, 0.9, 1.0, 0.0))
		_:
			quad.size = Vector2(1.6, 1.6)
			p.lifetime = 3.2
			p.initial_velocity_min = 1.0
			p.initial_velocity_max = 1.8
			p.gravity = Vector3(0.4, 0.6, 0.1)
			p.scale_amount_min = 1.0
			p.scale_amount_max = 2.6
			ramp.set_color(0, Color(0.25, 0.23, 0.22, 0.55))
			ramp.set_color(1, Color(0.5, 0.5, 0.5, 0.0))
	p.color_ramp = ramp
	quad.material = m
	p.mesh = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return p


static func bots(tree: SceneTree) -> Array[TownspersonBot]:
	var out: Array[TownspersonBot] = []
	for n in tree.get_nodes_in_group(&"townspeople"):
		if n is TownspersonBot:
			out.append(n as TownspersonBot)
	return out


static func bot_named(tree: SceneTree, full_name: String) -> TownspersonBot:
	for b in bots(tree):
		if Population.full_name(b.resident) == full_name or b.display_name == full_name:
			return b
	return null


static func bot_with_job(tree: SceneTree, job_part: String) -> TownspersonBot:
	for b in bots(tree):
		if str(b.resident.get("job", "")).to_lower().contains(job_part):
			return b
	return null


static func flat(v: Vector3) -> Vector3:
	return Vector3(v.x, 0.0, v.z)


static func ground(x: float, z: float) -> Vector3:
	return Vector3(x, Terrain.height_at(x, z), z)


## Bubble text colour (heated arguments use red; reset with white).
static func bubble_color(b: TownspersonBot, c: Color) -> void:
	var l := b.get("_bubble") as Label3D
	if l:
		l.modulate = c


## A controller that walks to a point (or stands) with a pose / facing.
class ScriptController extends BotController:
	var original: BotController
	var target: Vector3 = Vector3.INF
	var speed: float = 1.4
	var pose: StringName = &""
	var face_to: Vector3 = Vector3.INF
	var hidden: bool = false
	var tag: String = "script"
	var greeted: Callable
	func tick(bot: Node3D, _delta: float) -> Dictionary:
		if hidden:
			return {"hidden": true}
		if target != Vector3.INF:
			var to := target - bot.global_position
			to.y = 0.0
			if to.length() > 0.6:
				return {"move": to.normalized() * speed, "pose": &""}
		var out := {"move": Vector3.ZERO, "pose": pose}
		if face_to != Vector3.INF:
			var f := face_to - bot.global_position
			out["face"] = atan2(f.x, f.z)
		return out
	func on_greeted(bot: Node3D, player: Node3D) -> String:
		if greeted.is_valid():
			greeted.call(bot, player)
		return ""
	func describe() -> String:
		return tag
