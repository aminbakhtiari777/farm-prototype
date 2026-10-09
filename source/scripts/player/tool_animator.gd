class_name ToolAnimator
extends Node
## Plays the farm tools (tool_types modules): when the player tills, waters,
## sows, harvests or hammers, the best owned tool of that kind appears in the
## right hand with its own animation and sound, then is put away.
## Child of the Player ("ToolAnimator"); Player.play_tool(kind) calls play().

signal played(tool: ToolDef)

var current: Node3D = null
var last_tool: ToolDef = null
var plays: int = 0
var _tween: Tween


func play(kind: String) -> ToolDef:
	var t := Economy.best_tool(kind)
	if t == null:
		return null
	var player := get_parent() as Node3D
	_clear()
	current = build_prop(t)
	current.name = "Tool_" + t.item_id
	var visual := player.get_node_or_null(^"Visual")
	var parent: Node3D = player
	if visual is HumanoidModelVisual and (visual as HumanoidModelVisual).hand_point:
		parent = (visual as HumanoidModelVisual).hand_point
	parent.add_child(current)
	var base := Vector3(deg_to_rad(80), 0, 0) if parent != player else Vector3(deg_to_rad(-30), 0, 0)
	if parent == player:
		current.position = Vector3(0.25, 1.0, 0.25)
	current.rotation = base
	_animate(t, base)
	Sfx.play_at(StringName(t.sound), player.global_position + Vector3(0, 0.5, 0), -5.0, randf_range(0.93, 1.07))
	last_tool = t
	plays += 1
	played.emit(t)
	return t


## Screenshot helper: hold the animation at `t` seconds.
func freeze_at(t: float) -> void:
	if _tween and _tween.is_valid():
		_tween.pause()
		_tween.custom_step(t)


func _clear() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	if is_instance_valid(current):
		current.queue_free()
	current = null


func _animate(t: ToolDef, base: Vector3) -> void:
	var secs := maxf(t.anim_seconds, 0.3)
	_tween = create_tween()
	var node := current
	match t.anim:
		"swing":
			# Raise, chop down into the soil, twice.
			for k in 2:
				_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(-70), 0, 0), secs * 0.22).set_trans(Tween.TRANS_SINE)
				_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(35), 0, 0), secs * 0.16).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		"pour":
			_tween.tween_property(node, "rotation", base + Vector3(0, 0, deg_to_rad(70)), secs * 0.3)
			_tween.tween_interval(secs * 0.45)
			_tween.tween_property(node, "rotation", base, secs * 0.25)
		"sow":
			for k in 3:
				_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(25), 0, deg_to_rad(15)), secs * 0.16)
				_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(-10), 0, deg_to_rad(-10)), secs * 0.16)
		"pick":
			_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(45), 0, 0), secs * 0.35)
			_tween.tween_property(node, "rotation", base, secs * 0.35)
		"hammer":
			for k in 3:
				_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(-60), 0, 0), secs * 0.15)
				_tween.tween_property(node, "rotation", base + Vector3(deg_to_rad(20), 0, 0), secs * 0.1)
	_tween.tween_callback(_clear)


## Procedural hand prop for a tool (shape + colours from the module).
static func build_prop(t: ToolDef) -> Node3D:
	var root := Node3D.new()
	var head := ProceduralProp.color_material(t.head_color, 0.45, t.shape in ["blade", "hammer", "can"])
	var wood := ProceduralProp.color_material(t.handle_color, 0.8, false)
	match t.shape:
		"blade":
			_part(root, _cyl(0.024, 1.2), wood, Vector3(0, 0.45, 0))
			_part(root, _box(Vector3(0.26, 0.04, 0.2)), head, Vector3(0, 1.04, 0.1))
		"can":
			_part(root, _cyl(0.1, 0.2), head, Vector3(0, 0.0, 0.12), Vector3.ZERO)
			_part(root, _cyl(0.014, 0.28), head, Vector3(0, 0.06, 0.3), Vector3(deg_to_rad(60), 0, 0))
			_part(root, _box(Vector3(0.03, 0.14, 0.03)), wood, Vector3(0, 0.15, 0.06))
		"pouch":
			var m := SphereMesh.new()
			m.radius = 0.09
			m.height = 0.16
			_part(root, m, head, Vector3(0, 0.05, 0.05))
		"basket":
			_part(root, _cyl(0.13, 0.12), head, Vector3(0, 0.0, 0.12))
			_part(root, _box(Vector3(0.02, 0.18, 0.02)), wood, Vector3(0, 0.12, 0.12))
		"hammer":
			_part(root, _cyl(0.016, 0.34), wood, Vector3(0, 0.12, 0))
			_part(root, _box(Vector3(0.14, 0.05, 0.05)), head, Vector3(0, 0.3, 0))
		"axe":
			# v6a: felling axe (dry trees).
			_part(root, _cyl(0.022, 0.8), wood, Vector3(0, 0.3, 0))
			_part(root, _box(Vector3(0.04, 0.16, 0.2)), head, Vector3(0, 0.66, 0.08))
	return root


static func _part(root: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)


static func _cyl(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = h
	c.radial_segments = 8
	return c


static func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b
