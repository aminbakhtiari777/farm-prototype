class_name MeshMerger
extends RefCounted
## Bakes many static MeshInstance3D nodes (primitive boxes, imported Kenney
## furniture, ...) into ONE MeshInstance3D with one surface per distinct
## material. A house drops from ~150 draw calls to ~10. Materials are
## de-duplicated by look (colour, roughness, texture), so identical colours
## coming from different .glb files share a surface.
##
## Shared materials (e.g. the night-glowing window glass) are kept as the same
## resource, so changing them at runtime still affects the merged mesh.

static var _dedupe: Dictionary = {}
static var _baked: Dictionary = {}  ## bake key -> shared vertex-colour material
## v5a: when true, plain colour materials are baked into vertex colours so a
## whole building exterior needs only a few surfaces (draw calls).
static var _bake: bool = false


## Like merge_children(), but plain StandardMaterial3D colours (no emission,
## opaque) that share texture / roughness bucket become ONE surface with the
## colour stored per vertex (shared material across all buildings).
static func merge_children_baked(source: Node3D, relative_to: Node3D, mesh_name: String = "Merged") -> MeshInstance3D:
	_bake = true
	var out := merge_children(source, relative_to, mesh_name)
	_bake = false
	return out


static func _bake_key(mat: Material) -> String:
	if not _bake or not (mat is StandardMaterial3D):
		return ""
	var m := mat as StandardMaterial3D
	if m.emission_enabled or m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED or m.cull_mode != BaseMaterial3D.CULL_BACK:
		return ""
	if m.shading_mode != BaseMaterial3D.SHADING_MODE_PER_PIXEL or m.metallic > 0.3:
		return ""
	var tex_id := m.albedo_texture.get_rid().get_id() if m.albedo_texture else 0
	var nrm_id := m.normal_texture.get_rid().get_id() if m.normal_enabled and m.normal_texture else 0
	return "bake|%d|%d|%s|%s|%.1f" % [tex_id, nrm_id, m.uv1_triplanar, m.uv1_scale, snappedf(m.roughness, 0.25)]


static func _baked_material(key: String, src: StandardMaterial3D) -> StandardMaterial3D:
	if not _baked.has(key):
		var m := src.duplicate() as StandardMaterial3D
		m.albedo_color = Color.WHITE
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.roughness = snappedf(src.roughness, 0.25)
		_baked[key] = m
	return _baked[key]


## Copy of one surface with every vertex coloured `color` (times its own
## vertex colours if the material already used them).
static func _colored_surface(mesh: Mesh, s: int, color: Color, keep_vc: bool) -> ArrayMesh:
	var arr := mesh.surface_get_arrays(s)
	var n := (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	var cols := PackedColorArray()
	cols.resize(n)
	var old: Variant = arr[Mesh.ARRAY_COLOR]
	for i in n:
		cols[i] = color * (old as PackedColorArray)[i] if keep_vc and old is PackedColorArray and (old as PackedColorArray).size() == n else color
	arr[Mesh.ARRAY_COLOR] = cols
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am


## Collects every visible MeshInstance3D below `source` (relative to `relative_to`),
## merges them, frees the originals and returns the merged instance (not added).
static func merge_children(source: Node3D, relative_to: Node3D, mesh_name: String = "Merged") -> MeshInstance3D:
	var tools: Dictionary = {}  ## key -> [SurfaceTool, Material]
	var order: Array = []
	var victims: Array[Node] = []
	_collect(source, relative_to, tools, order, victims)
	var out := MeshInstance3D.new()
	out.name = mesh_name
	if order.is_empty():
		return out
	var mesh := ArrayMesh.new()
	for key in order:
		var pair: Array = tools[key]
		var st := pair[0] as SurfaceTool
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, pair[1])
	out.mesh = mesh
	for v in victims:
		if is_instance_valid(v):
			v.get_parent().remove_child(v)
			v.queue_free()
	return out


static func _relative_xform(node: Node3D, relative_to: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var n: Node = node
	while n != null and n != relative_to:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t


static func _collect(node: Node, relative_to: Node3D, tools: Dictionary, order: Array, victims: Array[Node]) -> void:
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible and (child as MeshInstance3D).mesh != null \
				and not (child as Node).has_meta(&"no_merge"):
			var mi := child as MeshInstance3D
			var xform := _relative_xform(mi, relative_to)
			for s in mi.mesh.get_surface_count():
				if mi.mesh is ArrayMesh and (mi.mesh as ArrayMesh).surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
					continue
				var mat := mi.material_override
				if mat == null:
					mat = mi.get_surface_override_material(s)
				if mat == null:
					mat = mi.mesh.surface_get_material(s)
				mat = canonical(mat)
				var bk := _bake_key(mat)
				if bk != "":
					var sm := mat as StandardMaterial3D
					if not tools.has(bk):
						var stb := SurfaceTool.new()
						stb.begin(Mesh.PRIMITIVE_TRIANGLES)
						tools[bk] = [stb, _baked_material(bk, sm)]
						order.append(bk)
					var colored := _colored_surface(mi.mesh, s, sm.albedo_color, sm.vertex_color_use_as_albedo)
					(tools[bk][0] as SurfaceTool).append_from(colored, 0, xform)
					continue
				var key := str(mat.get_instance_id()) if mat else "none"
				if not tools.has(key):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[key] = [st, mat]
					order.append(key)
				(tools[key][0] as SurfaceTool).append_from(mi.mesh, s, xform)
			victims.append(mi)
		if child is CollisionObject3D or child is Light3D or (child as Node).has_meta(&"no_merge"):
			continue
		_collect(child, relative_to, tools, order, victims)


## Returns one shared material per distinct look.
static func canonical(mat: Material) -> Material:
	if not (mat is StandardMaterial3D):
		return mat
	var m := mat as StandardMaterial3D
	if m.emission_enabled:
		return mat  # glowing window glass etc. stays unique (animated at runtime)
	var tex_id := m.albedo_texture.get_rid().get_id() if m.albedo_texture else 0
	var key := "%s|%.2f|%.2f|%d|%s|%d" % [m.albedo_color.to_html(), m.roughness, m.metallic, tex_id, m.uv1_triplanar, m.transparency]
	if _dedupe.has(key):
		return _dedupe[key]
	_dedupe[key] = mat
	return mat
