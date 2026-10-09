@tool
class_name Fence
extends Node3D
## Generates a rustic wooden fence (posts + two rails) around a rectangle,
## following the terrain, with an opening (gate) on one side and invisible
## collision walls. Runs in the editor too (@tool); generated nodes are not
## saved into the scene. Later: replace with fence pieces from a .glb kit.

@export var size: Vector2 = Vector2(28.0, 28.0):
	set(v):
		size = v
		_queue_rebuild()
@export var post_spacing: float = 2.2:
	set(v):
		post_spacing = maxf(v, 0.5)
		_queue_rebuild()
@export var post_height: float = 1.15:
	set(v):
		post_height = v
		_queue_rebuild()
@export var wood_material: Material:
	set(v):
		wood_material = v
		_queue_rebuild()
@export var random_seed: int = 7:
	set(v):
		random_seed = v
		_queue_rebuild()
@export_group("Gate opening")
## Side with the opening (NORTH = -Z, toward the town).
@export_enum("North (-Z)", "East (+X)", "South (+Z)", "West (-X)") var gate_side: int = 0:
	set(v):
		gate_side = v
		_queue_rebuild()
## Opening centre along that side (local x for N/S, local z for E/W).
@export var gate_center: float = 0.0:
	set(v):
		gate_center = v
		_queue_rebuild()
## 0 = no opening.
@export var gate_width: float = 3.2:
	set(v):
		gate_width = v
		_queue_rebuild()

## Extra openings: Vector3(side, centre, width) (same side numbering).
@export var extra_gates: Array[Vector3] = []:
	set(v):
		extra_gates = v
		_queue_rebuild()

var _rebuild_queued: bool = false


func _gates(side: int) -> Array[Vector2]:
	var out: Array[Vector2] = []
	if side == gate_side and gate_width > 0.0:
		out.append(Vector2(gate_center, gate_width))
	for g in extra_gates:
		if int(g.x) == side and g.z > 0.0:
			out.append(Vector2(g.y, g.z))
	return out


func _ready() -> void:
	_apply_style(Modules.style("fences") as FenceStyle)
	Modules.on_swap("fences", self, func(m: AssetModule) -> void: _apply_style(m as FenceStyle))
	_rebuild()


var _base_wood: Material


func _apply_style(style: FenceStyle) -> void:
	if style == null:
		return
	post_spacing = style.post_spacing
	post_height = style.post_height
	if _base_wood == null:
		_base_wood = wood_material
	var mat: Material = _base_wood
	if style.material_path != "" and ResourceLoader.exists(style.material_path):
		mat = load(style.material_path)
	if style.color != Color.WHITE and mat is StandardMaterial3D:
		mat = mat.duplicate()  # never tint the shared original
		(mat as StandardMaterial3D).albedo_color = style.color
	wood_material = mat
	_queue_rebuild()


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_rebuild.call_deferred()


func _ground(local: Vector3) -> float:
	var g := global_transform * local
	return Terrain.height_at(g.x, g.z) - global_position.y


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var half := size * 0.5
	# Sides in order NORTH, EAST, SOUTH, WEST (clockwise seen from above).
	var corners: Array[Vector3] = [
		Vector3(-half.x, 0, -half.y), Vector3(half.x, 0, -half.y),
		Vector3(half.x, 0, half.y), Vector3(-half.x, 0, half.y),
	]
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	for side in 4:
		var a := corners[side]
		var b := corners[(side + 1) % 4]
		var length := a.distance_to(b)
		var cuts: Array[Vector2] = []
		for g in _gates(side):
			var ct := _fraction_of(a, b, g.x)
			var gp := g.y / length * 0.5
			cuts.append(Vector2(ct - gp, ct + gp))
		cuts.sort_custom(func(p: Vector2, q: Vector2) -> bool: return p.x < q.x)
		var start := 0.0
		for c in cuts:
			_build_run(a.lerp(b, start), a.lerp(b, c.x), rng, body)
			start = c.y
		_build_run(a.lerp(b, start), b, rng, body)
		for c in cuts:
			# Taller gate posts with a top beam.
			for tt: float in [c.x, c.y]:
				var p := a.lerp(b, tt)
				var gy := _ground(p)
				var post := MeshInstance3D.new()
				var m := BoxMesh.new()
				m.size = Vector3(0.2, 2.6, 0.2)
				post.mesh = m
				post.material_override = wood_material
				post.position = p + Vector3(0, gy + 1.2, 0)
				add_child(post); post.visibility_range_end = 70.0; post.visibility_range_end_margin = 8.0
			var pa := a.lerp(b, c.x)
			var pb := a.lerp(b, c.y)
			var beam := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.16, 0.2, pa.distance_to(pb) + 0.6)
			beam.mesh = bm
			beam.material_override = wood_material
			beam.position = (pa + pb) * 0.5 + Vector3(0, _ground((pa + pb) * 0.5) + 2.45, 0)
			beam.rotation.y = atan2((pb - pa).x, (pb - pa).z)
			add_child(beam); beam.visibility_range_end = 70.0; beam.visibility_range_end_margin = 8.0


func _fraction_of(a: Vector3, b: Vector3, centre: float) -> float:
	# Map the gate centre coordinate to a 0..1 fraction along a->b.
	var dir := b - a
	if absf(dir.x) > absf(dir.z):
		return clampf((centre - a.x) / dir.x, 0.0, 1.0)
	return clampf((centre - a.z) / dir.z, 0.0, 1.0)


func _build_run(a: Vector3, b: Vector3, rng: RandomNumberGenerator, body: StaticBody3D) -> void:
	var length := a.distance_to(b)
	if length < 0.3:
		return
	var count := maxi(int(round(length / post_spacing)), 1)
	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.13, post_height, 0.13)
	var tops: Array[float] = []
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		var gy := _ground(p)
		tops.append(gy)
		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = wood_material
		var h := post_height * rng.randf_range(0.93, 1.05)
		post.position = p + Vector3(0, gy + h * 0.5 - 0.08, 0)
		post.rotation = Vector3(rng.randf_range(-0.04, 0.04), rng.randf_range(-0.3, 0.3), rng.randf_range(-0.04, 0.04))
		post.scale = Vector3(1, h / post_height, 1)
		add_child(post); post.visibility_range_end = 70.0; post.visibility_range_end_margin = 8.0
	for rail_h in [0.45, 0.88]:
		for i in count:
			var p0 := a.lerp(b, float(i) / count) + Vector3(0, tops[i], 0)
			var p1 := a.lerp(b, float(i + 1) / count) + Vector3(0, tops[i + 1], 0)
			var rail := MeshInstance3D.new()
			var m := BoxMesh.new()
			m.size = Vector3(0.07, 0.11, p0.distance_to(p1) + 0.12)
			rail.mesh = m
			rail.material_override = wood_material
			var y: float = rail_h + rng.randf_range(-0.03, 0.03)
			rail.transform = Transform3D(Basis.looking_at(p1 - p0, Vector3.UP), (p0 + p1) * 0.5 + Vector3(0, y, 0))
			add_child(rail); rail.visibility_range_end = 70.0; rail.visibility_range_end_margin = 8.0
	# Collision wall for this run.
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.3, 2.4, length + 0.2)
	shape.shape = box
	shape.position = (a + b) * 0.5 + Vector3(0, 1.0, 0)
	shape.rotation.y = atan2((b - a).x, (b - a).z)
	body.add_child(shape)
