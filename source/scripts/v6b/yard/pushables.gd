class_name Pushables
extends Node3D
## v6b "pushables" module: wooden boxes in the farmyard and at the
## carpenter's. E pushes a box one step away from you (along the closer
## axis); push it against another box and it climbs on top (stack up to
## max_stack). Walls / buildings block it. Every box's position is remembered
## (WorldMemory "moved", key "box:<i>") and saved.

const SIZE := 0.8
var boxes: Array[StaticBody3D] = []
var pushes: int = 0
var stacks_made: int = 0
signal box_moved(index: int, stacked: bool)


func style() -> PushableStyle:
	return Modules.style("pushables") as PushableStyle


func _ready() -> void:
	add_to_group(&"pushables")
	_build()
	Modules.on_swap("pushables", self, func(_m: Resource) -> void: _build())
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "all":
			_apply_memory())


static var _mesh_cache: Mesh


static func _crate_mesh() -> Mesh:
	if _mesh_cache:
		return _mesh_cache
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := SIZE * 0.5
	var bm := BoxMesh.new()
	bm.size = Vector3(SIZE, SIZE, SIZE)
	st.append_from(bm, 0, Transform3D.IDENTITY)
	# Plank battens on each side face (slightly proud).
	for axis in 4:
		var yaw := axis * PI * 0.5
		for k: float in [-0.28, 0.0, 0.28]:
			var b := BoxMesh.new()
			b.size = Vector3(SIZE * 0.96, 0.07, 0.03)
			var t := Transform3D(Basis(Vector3.UP, yaw), Vector3(0, k, 0).rotated(Vector3.UP, yaw) + Vector3(0, 0, h + 0.012).rotated(Vector3.UP, yaw))
			st.append_from(b, 0, t)
	_mesh_cache = st.commit()
	return _mesh_cache


func _build() -> void:
	for c in get_children():
		c.queue_free()
	boxes.clear()
	var st := style()
	if st == null:
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = st.color
	mat.roughness = 0.9
	var i := 0
	for d: Dictionary in st.boxes:
		var p: Vector2 = d.get("pos", Vector2.ZERO)
		var b := StaticBody3D.new()
		b.name = "Box%d" % i
		b.set_meta(&"index", i)
		b.set_meta(&"home", Vector3(p.x, Terrain.height_at(p.x, p.y), p.y))
		b.add_to_group(&"pushable_boxes")
		add_child(b)
		var mi := MeshInstance3D.new()
		mi.mesh = _crate_mesh()
		mi.material_override = mat
		mi.position.y = SIZE * 0.5
		b.add_child(mi)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3.ONE * SIZE
		cs.shape = bs
		cs.position.y = SIZE * 0.5
		b.add_child(cs)
		var idx := i
		b.global_position = b.get_meta(&"home")
		boxes.append(b)  # before the spot: ActionSpot reads its text in _ready
		var spot := ActionSpot.make(b, Vector3.ZERO, 1.05,
			func() -> String: return _text(idx),
			func(who: Node3D) -> void: push(idx, who),
			func() -> bool: return _is_top(idx))
		spot.zone.position.y = 0.4
		spot.name = "PushSpot"
		i += 1
	_apply_memory()


func _apply_memory() -> void:
	for b in boxes:
		var m := WorldMemory.pose_of("box:%d" % int(b.get_meta(&"index")))
		b.global_position = WorldMemory.vec(m.get("p")) if not m.is_empty() else (b.get_meta(&"home") as Vector3)


func _text(i: int) -> String:
	return Lang.tt("هل دادن جعبه (روی جعبه‌ی دیگر می‌رود)", "push the box (onto another box to stack)") if i >= 0 else ""


func _is_top(i: int) -> bool:
	var b := boxes[i]
	for o in boxes:
		if o != b and _flat(o.global_position).distance_to(_flat(b.global_position)) < SIZE * 0.6 and o.global_position.y > b.global_position.y + 0.3:
			return false
	return true


static func _flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


## Height (top) of the stack at a ground point, and how many boxes are there.
func _stack_at(p: Vector2, skip: StaticBody3D) -> Array:
	var top := -INF
	var n := 0
	for o in boxes:
		if o == skip:
			continue
		if _flat(o.global_position).distance_to(p) < SIZE * 0.75:
			n += 1
			top = maxf(top, o.global_position.y + SIZE)
	return [top, n]


## Push box `i` one step away from `who` (or along `dir`). Returns true if moved.
func push(i: int, who: Node3D = null, dir: Vector3 = Vector3.ZERO) -> bool:
	var st := style()
	if i < 0 or i >= boxes.size() or not _is_top(i):
		return false
	var b := boxes[i]
	if dir == Vector3.ZERO and who:
		dir = b.global_position - who.global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return false
	# Snap to the closer axis (boxes slide straight).
	dir = Vector3(signf(dir.x), 0, 0) if absf(dir.x) > absf(dir.z) else Vector3(0, 0, signf(dir.z))
	var step := st.push_step if st else 0.9
	var dest := b.global_position + dir * step
	var s := _stack_at(_flat(dest), b)
	var stacked := false
	if int(s[1]) > 0:
		# Pushed against another box: climb on top (full step onto it).
		var ms := st.max_stack if st else 3
		if int(s[1]) >= ms:
			GameEvents.notification_requested.emit(Lang.tt("بیشتر از این روی هم نمی‌رود.", "The stack can't get any higher."))
			return false
		var base := _base_box_at(_flat(dest), b)
		dest = Vector3(base.global_position.x, float(s[0]), base.global_position.z)
		stacked = true
	else:
		dest.y = Terrain.height_at(dest.x, dest.z)
		if _blocked(b, dest):
			GameEvents.notification_requested.emit(Lang.tt("جعبه گیر کرد.", "The box is stuck."))
			return false
	b.global_position = dest
	pushes += 1
	if stacked:
		stacks_made += 1
	if who and who.has_method("spend_stamina"):
		who.call("spend_stamina", 1.0)
	Sfx.play_at(&"land", dest, -6.0, 0.8)
	WorldMemory.remember_pose("box:%d" % i, dest, 0.0)
	box_moved.emit(i, stacked)
	return true


func _base_box_at(p: Vector2, skip: StaticBody3D) -> StaticBody3D:
	var best: StaticBody3D = null
	for o in boxes:
		if o != skip and _flat(o.global_position).distance_to(p) < SIZE * 0.75:
			if best == null or o.global_position.y < best.global_position.y:
				best = o
	return best


func _blocked(b: StaticBody3D, dest: Vector3) -> bool:
	if not is_inside_tree():
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(SIZE * 0.9, SIZE * 0.6, SIZE * 0.9)
	q.shape = bs
	q.transform = Transform3D(Basis.IDENTITY, dest + Vector3(0, SIZE * 0.5 + 0.12, 0))
	q.collision_mask = 1
	q.exclude = [b.get_rid()]
	for hit in space.intersect_shape(q, 8):
		var col: Object = hit.get("collider")
		if col is StaticBody3D and (col as Node).is_in_group(&"pushable_boxes"):
			continue
		return true
	return false


## Highest stack (boxes on top of each other) anywhere - yard routine "stack".
func tallest_stack() -> int:
	var best := 1 if not boxes.is_empty() else 0
	for b in boxes:
		var n := 1
		for o in boxes:
			if o != b and _flat(o.global_position).distance_to(_flat(b.global_position)) < SIZE * 0.6 and o.global_position.y > b.global_position.y + 0.3:
				n += 1
		best = maxi(best, n)
	return best
