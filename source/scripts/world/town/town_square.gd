class_name TownSquare
extends Node3D
## v5a ornate town square ("town_square" module, SquareStyle): mosaic paving
## (star rosette / rings shader), a tiered fountain with animated water (or the
## classic well), flower beds, ornamental cast-iron lamps, a statue and low
## hedges. Repeated pieces (lamps, globes, flowers, hedges) are MultiMeshes;
## the fountain + statue are merged into one mesh per material.

var lamp_positions: PackedVector3Array = PackedVector3Array()
var fountain_seats: Array[Seat] = []


func _ready() -> void:
	var st := Modules.style("town_square") as SquareStyle
	var c := TownLayout.TOWN_CENTER
	var y := Terrain.height_at(c.x, c.y)
	position = Vector3(c.x, 0, c.y)
	_paving(st, y)
	if st == null or st.centerpiece == "well":
		var well := TownWell.new()
		well.name = "Well"
		add_child(well)
	else:
		_fountain(st, y)
	if st:
		_flower_beds(st, y)
		_lamps(st, y)
		if st.statue:
			_statue(st, y)
		if st.hedges:
			_hedges(st, y)


func _paving(st: SquareStyle, y: float) -> void:
	var disc := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = TownLayout.SQUARE_RADIUS + 0.4
	cyl.bottom_radius = TownLayout.SQUARE_RADIUS + 0.6
	cyl.height = 0.3
	cyl.radial_segments = 48
	cyl.rings = 1
	disc.mesh = cyl
	disc.name = "SquarePaving"
	disc.position = Vector3(0, y - 0.1, 0)
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;
uniform vec3 color_c : source_color;
uniform int pattern = 1;
uniform vec2 center;
varying vec3 wpos;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 q = wpos.xz - center;
	float r = length(q);
	float a = atan(q.y, q.x);
	// Cobbles everywhere.
	vec2 p = wpos.xz * 2.2;
	p.x += step(1.0, mod(floor(p.y), 2.0)) * 0.5;
	vec2 f = fract(p) - 0.5;
	float edge = smoothstep(0.38, 0.48, max(abs(f.x), abs(f.y)));
	vec3 col = mix(color_a, color_a * 0.86, hash(floor(p)));
	if (pattern == 1) {
		// Eight-point star rosette + two rings.
		float star = 3.2 + 1.3 * pow(abs(cos(a * 4.0)), 3.0);
		if (r < star && r > 2.7) col = mix(color_b, color_b * 0.85, hash(floor(p)));
		if (abs(r - 6.9) < 0.22 || abs(r - 9.6) < 0.18) col = color_c;
		if (r > 7.3 && r < 9.2 && abs(sin(a * 12.0)) < 0.12) col = color_b;
	} else if (pattern == 2) {
		if (abs(fract(r / 2.4) - 0.5) < 0.08) col = color_c;
	}
	ALBEDO = mix(col, col * 0.45, edge);
	ROUGHNESS = 0.88;
	NORMAL_MAP = vec3(0.5 + f.x * edge * 0.6, 0.5 + f.y * edge * 0.6, 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter(&"color_a", st.mosaic_a if st else Color(0.58, 0.54, 0.48))
	m.set_shader_parameter(&"color_b", st.mosaic_b if st else Color(0.47, 0.44, 0.4))
	m.set_shader_parameter(&"color_c", st.mosaic_c if st else Color(0.4, 0.35, 0.3))
	m.set_shader_parameter(&"pattern", st.pattern if st else 0)
	m.set_shader_parameter(&"center", TownLayout.TOWN_CENTER)
	disc.material_override = m
	add_child(disc)


static func _water_material() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """
shader_type spatial;
render_mode cull_disabled;
void fragment() {
	float t = TIME;
	vec2 uv = UV * 6.0;
	float w = sin(uv.x * 3.0 + t * 2.0) * 0.5 + sin(uv.y * 4.0 - t * 1.6) * 0.5;
	ALBEDO = mix(vec3(0.12, 0.35, 0.45), vec3(0.45, 0.7, 0.8), 0.5 + 0.25 * w);
	ROUGHNESS = 0.08;
	METALLIC = 0.1;
	NORMAL_MAP = vec3(0.5 + 0.12 * cos(uv.x * 3.0 + t * 2.0), 0.5 + 0.12 * cos(uv.y * 4.0 - t * 1.6), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


func _fountain(st: SquareStyle, y: float) -> void:
	var holder := Node3D.new()
	holder.name = "FountainParts"
	add_child(holder)
	var stone := ProceduralProp.color_material(st.stone_color, 0.8)
	var trim := ProceduralProp.color_material(st.stone_color.darkened(0.15), 0.85)
	var water := _water_material()
	# Octagonal basin: low wall + rim + water.
	_cyl(holder, 2.7, 2.8, 0.55, Vector3(0, y + 0.27, 0), stone, 8)
	_cyl(holder, 2.85, 2.85, 0.1, Vector3(0, y + 0.58, 0), trim, 8)
	_cyl(holder, 2.45, 2.45, 0.04, Vector3(0, y + 0.45, 0), water, 24)
	# Tiers.
	var h := y + 0.5
	for t in st.fountain_tiers:
		var r := 1.5 - t * 0.45
		_cyl(holder, 0.22 - t * 0.04, 0.3 - t * 0.04, 0.9, Vector3(0, h + 0.45, 0), stone, 12)
		h += 0.9
		_cyl(holder, r, r * 0.55, 0.28, Vector3(0, h + 0.1, 0), stone, 16)
		_cyl(holder, r - 0.08, r - 0.08, 0.03, Vector3(0, h + 0.22, 0), water, 20)
		# Falling water sheet around the bowl edge.
		var sheet := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = r + 0.02
		cm.bottom_radius = r + 0.12 + t * 0.1
		cm.height = 0.9 if t == 0 else 0.85
		cm.radial_segments = 20
		cm.cap_top = false
		cm.cap_bottom = false
		sheet.mesh = cm
		var wm := _water_material()
		wm.render_priority = 1
		sheet.material_override = wm
		sheet.transparency = 0.45
		sheet.position = Vector3(0, h + 0.2 - cm.height * 0.5, 0)
		sheet.set_meta(&"no_merge", true)
		sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(sheet)
	# Finial.
	var fin := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	fin.mesh = sm
	fin.material_override = ProceduralProp.color_material(Color(0.85, 0.72, 0.35), 0.35, false)
	fin.position = Vector3(0, h + 0.45, 0)
	holder.add_child(fin)
	var merged := MeshMerger.merge_children(holder, self, "FountainMesh")
	add_child(merged)
	# Collision + refill interaction + seats on the rim.
	var body := StaticBody3D.new()
	body.name = "FountainCollision"
	var shape := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 2.85
	cs.height = 1.2
	shape.shape = cs
	shape.position = Vector3(0, y + 0.6, 0)
	body.add_child(shape)
	add_child(body)
	var zone := Interactable.new()
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.action_text = "refill the watering can"
	zone.position = Vector3(0, y + 0.8, 0)
	var zs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 3.9
	zs.shape = sp
	zone.add_child(zs)
	add_child(zone)
	zone.interacted.connect(func(_who: Node3D) -> void:
		if not Economy.has("watering_can"):
			GameEvents.notification_requested.emit("You have no watering can")
			return
		Economy.refill_can()
		Sfx.play_at(&"splash", global_position + Vector3(0, 1, 0), -10.0)
		GameEvents.notification_requested.emit("Watering can refilled at the fountain (%d/%d)" % [Economy.water, Economy.can_capacity()]))
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var s := Seat.new()
		s.display_name = "fountain edge"
		s.position = Vector3(sin(a) * 3.05, y + 0.12, cos(a) * 3.05)
		s.rotation.y = a
		add_child(s)
		fountain_seats.append(s)


func _cyl(parent: Node3D, top: float, bottom: float, h: float, pos: Vector3, mat: Material, seg: int) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top
	cm.bottom_radius = bottom
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _mm(mesh: Mesh, xs: Array[Transform3D], cols: Array, mat: Material, node_name: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = not cols.is_empty()
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
		if mm.use_colors:
			mm.set_instance_color(i, cols[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.visibility_range_end = 150.0
	add_child(mmi)
	return mmi


func _flower_beds(st: SquareStyle, y: float) -> void:
	var soil := StandardMaterial3D.new()
	soil.vertex_color_use_as_albedo = true
	soil.roughness = 0.9
	var bed_xf: Array[Transform3D] = []
	var bed_col: Array = []
	var fl_xf: Array[Transform3D] = []
	var fl_col: Array = []
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var p := Vector3(sin(a), 0, cos(a)) * 4.6
		bed_xf.append(Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(2.2, 0.25, 1.0)), p + Vector3(0, y + 0.12, 0)))
		bed_col.append(Color(0.3, 0.45, 0.22))
		for i in 18:
			var off := Vector3(rng.randf_range(-1.0, 1.0), 0, rng.randf_range(-0.4, 0.4)).rotated(Vector3.UP, a)
			fl_xf.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * rng.randf_range(0.08, 0.12)), p + off + Vector3(0, y + 0.33, 0)))
			fl_col.append(st.flower_colors[rng.randi() % st.flower_colors.size()] if not st.flower_colors.is_empty() else Color.WHITE)
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_mm(box, bed_xf, bed_col, soil, "FlowerBeds")
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 6
	sph.rings = 3
	var petal := StandardMaterial3D.new()
	petal.vertex_color_use_as_albedo = true
	petal.roughness = 0.6
	_mm(sph, fl_xf, fl_col, petal, "Flowers")


func _lamps(st: SquareStyle, y: float) -> void:
	var post_xf: Array[Transform3D] = []
	var globe_xf: Array[Transform3D] = []
	var n := st.ornate_lamps
	for k in n:
		# Quadrant angles that keep the four road entries free: 45 deg (4 lamps)
		# or 30 / 60 deg (8 lamps) inside each quadrant.
		var a := deg_to_rad(int(k / 2) * 90.0 + (30.0 if k % 2 == 0 else 60.0)) if n > 4 else deg_to_rad(k * 90.0 + 30.0)
		var p := Vector3(sin(a), 0, cos(a)) * 8.4
		post_xf.append(Transform3D(Basis.IDENTITY, p + Vector3(0, y, 0)))
		for g in 3:
			var ga := TAU * g / 3.0
			globe_xf.append(Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.17), p + Vector3(cos(ga) * 0.38, y + 3.05, sin(ga) * 0.38)))
		lamp_positions.append(Vector3(position.x + p.x, y + 3.0, position.z + p.z))
	# Post mesh: base, column, arms, cap (one ArrayMesh).
	var stool := SurfaceTool.new()
	stool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var parts := [[Vector3(0.36, 0.4, 0.36), Vector3(0, 0.2, 0)], [Vector3(0.12, 2.8, 0.12), Vector3(0, 1.6, 0)],
			[Vector3(0.9, 0.06, 0.06), Vector3(0, 2.92, 0)], [Vector3(0.06, 0.06, 0.9), Vector3(0, 2.92, 0)], [Vector3(0.2, 0.3, 0.2), Vector3(0, 3.35, 0)]]
	for part in parts:
		var b := BoxMesh.new()
		b.size = part[0]
		stool.append_from(b, 0, Transform3D(Basis.IDENTITY, part[1]))
	stool.generate_normals()
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.1, 0.11, 0.12)
	iron.roughness = 0.4
	iron.metallic = 0.5
	_mm(stool.commit(), post_xf, [], iron, "OrnateLampPosts")
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 10
	sph.rings = 5
	_mm(sph, globe_xf, [], PowerFx.bulb_material(), "OrnateLampGlobes")
	var body := StaticBody3D.new()
	body.name = "LampCollision"
	add_child(body)
	for xf in post_xf:
		var shape := CollisionShape3D.new()
		var cs := CylinderShape3D.new()
		cs.radius = 0.2
		cs.height = 3.0
		shape.shape = cs
		shape.position = xf.origin + Vector3(0, 1.5, 0)
		body.add_child(shape)


func _statue(st: SquareStyle, y: float) -> void:
	var a := TAU * 0.125 + PI
	var p := Vector3(sin(a), 0, cos(a)) * 7.6
	var holder := Node3D.new()
	holder.name = "StatueParts"
	holder.position = p + Vector3(0, y, 0)
	holder.rotation.y = a + PI
	add_child(holder)
	var stone := ProceduralProp.color_material(st.stone_color.darkened(0.05), 0.85)
	var bronze := ProceduralProp.color_material(Color(0.42, 0.36, 0.24), 0.35, false)
	_box(holder, Vector3(1.2, 1.2, 1.2), Vector3(0, 0.6, 0), stone)
	_box(holder, Vector3(1.4, 0.15, 1.4), Vector3(0, 1.25, 0), stone)
	# A farmer with a raised sheaf (abstract).
	_cyl(holder, 0.22, 0.28, 1.0, Vector3(0, 1.85, 0), bronze, 10)
	var head := MeshInstance3D.new()
	var hs := SphereMesh.new()
	hs.radius = 0.17
	hs.height = 0.34
	head.mesh = hs
	head.material_override = bronze
	head.position = Vector3(0, 2.55, 0)
	holder.add_child(head)
	_box(holder, Vector3(0.1, 0.8, 0.1), Vector3(0.3, 2.55, 0), bronze)
	_cyl(holder, 0.16, 0.05, 0.4, Vector3(0.3, 3.05, 0), ProceduralProp.color_material(Color(0.8, 0.65, 0.3), 0.4, false), 8)
	var merged := MeshMerger.merge_children(holder, holder, "StatueMesh")
	holder.add_child(merged)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.4, 2.0, 1.4)
	shape.shape = bs
	shape.position = Vector3(0, 1.0, 0)
	body.add_child(shape)
	holder.add_child(body)


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)


func _hedges(st: SquareStyle, y: float) -> void:
	var xs: Array[Transform3D] = []
	for k in 32:
		var a := TAU * (k + 0.5) / 32.0
		var p := Vector3(sin(a), 0, cos(a)) * 9.9
		if absf(p.x) < 4.2 or absf(p.z) < 4.2:
			continue
		xs.append(Transform3D(Basis(Vector3.UP, a) * Basis.from_scale(Vector3(1.85, 0.55, 0.5)), p + Vector3(0, y + 0.27, 0)))
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.2, 0.42, 0.18)
	leaf.roughness = 0.95
	_mm(box, xs, [], leaf, "Hedges")
