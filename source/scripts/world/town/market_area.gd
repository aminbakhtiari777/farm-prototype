class_name MarketArea
extends Node3D
## v5a central market ("market" module, MarketStyle): a paved plaza on Farm Rd
## (TownLayout.MARKET_RECT) with stalls on both sides of the road. All stalls
## share ONE frame mesh and ONE canopy mesh drawn through MultiMeshInstance3D
## (per-instance canopy colours), the produce on the counters is one more
## MultiMesh and the bunting another - ~5 draw calls for the whole market.
## Each stall is a small shop: Shops.shop("stall:<id>") (sells / buys with
## the module's sell bonus); the "legacy" stall is the classic seed shop.

const STALL_W := 2.6
var stall_nodes: Array[Node3D] = []
var multimesh_count: int = 0


func _ready() -> void:
	var st := Modules.style("market") as MarketStyle
	if st == null:
		return
	_build(st)


static func stall_transforms(count: int) -> Array[Transform3D]:
	var out: Array[Transform3D] = []
	var c := TownLayout.MARKET_CENTER
	for i in count:
		var west := i % 2 == 0
		var row := int(i / 2)
		var x := c.x + (-5.6 if west else 5.6)
		var z := c.y - 3.6 + row * 3.6
		var yaw := PI * 0.5 if west else -PI * 0.5
		out.append(Transform3D(Basis(Vector3.UP, yaw), Vector3(x, Terrain.height_at(x, z), z)))
	return out


func _build(st: MarketStyle) -> void:
	_paving(st)
	var xs := stall_transforms(st.stalls.size())
	var body := StaticBody3D.new()
	body.name = "MarketCollision"
	add_child(body)
	# Shared meshes.
	var frame_mm := _multimesh(_frame_mesh(st), xs, [])
	frame_mm.name = "StallFrames"
	var cols: Array = []
	for i in xs.size():
		cols.append(st.awning_colors[i % st.awning_colors.size()] if not st.awning_colors.is_empty() else Color(0.8, 0.3, 0.25))
	var canopy := _multimesh(_canopy_mesh(st), xs, cols)
	canopy.name = "StallCanopies"
	# Produce on the counters (one MultiMesh of spheres).
	var goods_xf: Array[Transform3D] = []
	var goods_col: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var palette := [Color(0.85, 0.2, 0.15), Color(0.95, 0.6, 0.15), Color(0.5, 0.7, 0.2), Color(0.6, 0.3, 0.55), Color(0.95, 0.85, 0.3), Color(0.7, 0.75, 0.8)]
	for i in xs.size():
		for crate in 3:
			var c: Color = palette[rng.randi() % palette.size()]
			for k in 9:
				var local := Vector3(-0.85 + crate * 0.85 - 0.22 + (k % 3) * 0.22, 1.2, -0.1 + floorf(k / 3.0) * 0.13)
				goods_xf.append(xs[i] * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.075), local))
				goods_col.append(c)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 8
	sphere.rings = 4
	var goods := _multimesh(sphere, goods_xf, goods_col, true)
	goods.name = "StallGoods"
	# Per-stall: collision, interaction, name board.
	for i in xs.size():
		var d: Dictionary = st.stalls[i]
		var anchor := Node3D.new()
		anchor.name = "MarketStall%d" % (i + 1)
		anchor.transform = xs[i]
		anchor.set_meta(&"stall_id", str(d.get("id", "")))
		add_child(anchor)
		stall_nodes.append(anchor)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2.8, 2.4, 1.2)
		shape.shape = box
		shape.transform = xs[i] * Transform3D(Basis.IDENTITY, Vector3(0, 1.2, 0))
		body.add_child(shape)
		var zone := Interactable.new()
		zone.collision_layer = 8
		zone.collision_mask = 2
		zone.position = Vector3(0, 0.9, 1.3)
		var zs := CollisionShape3D.new()
		var sp := SphereShape3D.new()
		sp.radius = 1.6
		zs.shape = sp
		zone.add_child(zs)
		var legacy := bool(d.get("legacy", false))
		zone.action_text = "shop at the market" if legacy else "trade at the %s" % str(d.get("title", "stall")).to_lower()
		var sid := "stall:" + str(d.get("id", ""))
		zone.interacted.connect(func(_who: Node3D) -> void:
			# v5b: market opening hours (shop_hours module).
			if not ShopHours.is_open(sid):
				GameEvents.notification_requested.emit(ShopHours.closed_message(sid, str(d.get("title", "Stall"))))
				return
			if legacy:
				GameEvents.shop_requested.emit()
			else:
				GameEvents.shop_requested_for.emit(sid))
		anchor.add_child(zone)
		var label := Label3D.new()
		label.text = str(d.get("title", "Stall"))
		label.font_size = 44
		label.pixel_size = 0.006
		label.outline_size = 8
		label.position = Vector3(0, 2.85, 0.92)
		label.rotation.x = -0.1
		label.visibility_range_end = 40.0
		anchor.add_child(label)
	if st.bunting:
		_bunting(st, xs)


func _multimesh(mesh: Mesh, xs: Array[Transform3D], colors: Array, vertex_color_mat: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not colors.is_empty()
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	if vertex_color_mat:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.roughness = 0.5
		mmi.material_override = m
	mmi.visibility_range_end = 160.0
	add_child(mmi)
	multimesh_count += 1
	return mmi


## Stall frame (counter, posts, crates) baked into one mesh, wood material.
func _frame_mesh(st: MarketStyle) -> ArrayMesh:
	var stool := SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wood := st.wood_color
	var dark := wood.darkened(0.3)
	_add_box(stool, Vector3(STALL_W, 0.9, 1.0), Vector3(0, 0.45, 0), wood)
	_add_box(stool, Vector3(STALL_W + 0.15, 0.06, 1.15), Vector3(0, 0.92, 0), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_add_box(stool, Vector3(0.09, 2.3, 0.09), Vector3(sx * 1.3, 1.15, sz * 0.5), dark)
	for i in 3:
		_add_box(stool, Vector3(0.7, 0.22, 0.5), Vector3(-0.85 + i * 0.85, 1.06, 0.05), wood.lightened(0.1))
	_add_box(stool, Vector3(0.6, 0.45, 0.45), Vector3(1.7, 0.22, 0.4), wood)
	_add_box(stool, Vector3(1.6, 0.4, 0.05), Vector3(0, 2.85, 0.9), dark)
	stool.generate_normals()
	var mesh := stool.commit()
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.85
	mesh.surface_set_material(0, m)
	return mesh


func _canopy_mesh(st: MarketStyle) -> ArrayMesh:
	var q := QuadMesh.new()
	q.size = Vector2(2.95, 1.75)
	var stool := SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	stool.append_from(q, 0, Transform3D(Basis(Vector3.RIGHT, -PI * 0.5 + 0.25), Vector3(0, 2.4, 0.1)))
	var mesh := stool.commit()
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
uniform bool striped = true;
varying vec3 inst;
void vertex() { inst = COLOR.rgb; }
void fragment() {
	float s = step(0.5, fract(UV.x * 3.5));
	ALBEDO = striped ? mix(inst, vec3(0.95, 0.93, 0.86), s) : inst;
	ROUGHNESS = 0.9;
}
"""
	mat.shader = sh
	mat.set_shader_parameter(&"striped", st.striped)
	mesh.surface_set_material(0, mat)
	return mesh


func _add_box(stool: SurfaceTool, size: Vector3, pos: Vector3, color: Color) -> void:
	var b := BoxMesh.new()
	b.size = size
	var arr := b.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	for i in idx:
		stool.set_color(color)
		stool.add_vertex(verts[i] + pos)


func _paving(st: MarketStyle) -> void:
	var r := TownLayout.MARKET_RECT
	var y := Terrain.height_at(TownLayout.MARKET_CENTER.x, TownLayout.MARKET_CENTER.y)
	var mi := MeshInstance3D.new()
	mi.name = "MarketPaving"
	var box := BoxMesh.new()
	box.size = Vector3(r.size.x, 0.3, r.size.y)
	mi.mesh = box
	mi.position = Vector3(r.get_center().x, y - 0.1, r.get_center().y)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 color_a : source_color = vec3(0.68, 0.6, 0.5);
uniform vec3 color_b : source_color = vec3(0.58, 0.5, 0.42);
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 g = wpos.xz / 0.9;
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float checker = mod(cell.x + cell.y, 2.0);
	float edge = smoothstep(0.0, 0.06, f.x) * smoothstep(0.0, 0.06, f.y) * smoothstep(1.0, 0.94, f.x) * smoothstep(1.0, 0.94, f.y);
	vec3 c = mix(color_a, color_b, checker);
	ALBEDO = c * mix(0.7, 1.0, edge);
	ROUGHNESS = 0.92;
}
"""
	mat.shader = sh
	mat.set_shader_parameter(&"color_a", st.paving_color)
	mat.set_shader_parameter(&"color_b", st.paving_alt)
	mi.material_override = mat
	add_child(mi)


func _bunting(st: MarketStyle, xs: Array[Transform3D]) -> void:
	# Flags strung across the road between facing stalls.
	var flag_xf: Array[Transform3D] = []
	var flag_col: Array = []
	var tri := PrismMesh.new()
	tri.size = Vector3(0.28, 0.32, 0.01)
	for i in range(0, xs.size() - 1, 2):
		var a := xs[i].origin + Vector3(0, 2.6, 0)
		var b := xs[i + 1].origin + Vector3(0, 2.6, 0)
		var n := 14
		for k in n:
			var t := (k + 0.5) / n
			var p := a.lerp(b, t) + Vector3(0, -0.35 * sin(t * PI), 0)
			var yaw := atan2(b.x - a.x, b.z - a.z) + PI * 0.5
			flag_xf.append(Transform3D(Basis(Vector3.UP, yaw).rotated(Vector3.UP, 0.0) * Basis(Vector3.RIGHT, PI), p))
			flag_col.append(st.awning_colors[k % st.awning_colors.size()] if not st.awning_colors.is_empty() else Color.WHITE)
	if flag_xf.is_empty():
		return
	var flags := _multimesh(tri, flag_xf, flag_col, true)
	flags.name = "Bunting"
	(flags.material_override as StandardMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
