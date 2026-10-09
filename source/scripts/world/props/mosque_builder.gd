class_name MosqueBuilder
extends RefCounted
## v5a mosque exterior (dome + minaret(s) + arched windows) from MosqueStyle.
## Called by Building after the hollow shell is up; replaces the flat roof.


static func decorate(b: Building, roof: Node3D, ext: Node3D) -> void:
	var st := Modules.style("mosque") as MosqueStyle
	if st == null:
		return
	var w := b.size.x
	var d := b.size.z
	var top := Building.FOUNDATION_HEIGHT + b.size.y
	var dome := ProceduralProp.color_material(st.dome_color, 0.55, false)
	var trim := ProceduralProp.color_material(st.trim_color, 0.6)
	var tile := ProceduralProp.color_material(st.tile_color, 0.5, false)
	# v5b: proper dome on a drum - 16-sided drum with arched windows and a
	# tile band, then an onion (bulbous, pointed) or ribbed Persian dome built
	# as a lathe mesh with raised ribs, and a finial (pole, orbs, ring).
	var wall := ProceduralProp.color_material(st.wall_color, 0.8)
	var rd := w * 0.27
	var dh := st.drum_height
	b.add_cylinder(rd + 0.12, rd + 0.18, 0.25, Vector3(0, top + 0.125, 0), trim, Vector3.ZERO, 16, roof)
	b.add_cylinder(rd, rd, dh, Vector3(0, top + 0.25 + dh * 0.5, 0), wall, Vector3.ZERO, 16, roof)
	b.add_cylinder(rd + 0.06, rd + 0.06, 0.22, Vector3(0, top + 0.25 + dh - 0.11, 0), tile, Vector3.ZERO, 16, roof)
	var dark := ProceduralProp.color_material(Color(0.12, 0.14, 0.18), 0.4, false)
	for i in 8:
		var ang := TAU * (i + 0.5) / 8.0
		var dir := Vector3(sin(ang), 0, cos(ang))
		var wy := top + 0.25 + dh * 0.45
		b.add_box(Vector3(0.34, dh * 0.5, 0.06), Vector3(0, wy, 0) + dir * (rd + 0.005), dark, Vector3(0, ang, 0), roof)
		b.add_cylinder(0.17, 0.17, 0.06, Vector3(0, wy + dh * 0.25, 0) + dir * (rd + 0.005), dark, Vector3(PI * 0.5, ang, 0), 10, roof)
		b.add_box(Vector3(0.44, 0.06, 0.1), Vector3(0, wy - dh * 0.26, 0) + dir * (rd + 0.03), trim, Vector3(0, ang, 0), roof)
	var base_y := top + 0.25 + dh
	var r0 := rd + 0.05
	var height := r0 * (1.9 if st.dome_shape == "onion" else 1.4)
	var mi := MeshInstance3D.new()
	mi.name = "Dome"
	mi.mesh = dome_mesh(st.dome_shape, r0, height, maxi(st.dome_ribs, 0), st.dome_color, st.rib_color, st.trim_color)
	var dm := StandardMaterial3D.new()
	dm.vertex_color_use_as_albedo = true
	dm.vertex_color_is_srgb = true
	dm.roughness = 0.4
	dm.metallic = 0.15
	mi.material_override = dm
	mi.position = Vector3(0, base_y, 0)
	mi.set_meta(&"no_merge", true)
	roof.add_child(mi)
	# Finial: pole, two orbs and a ring.
	var tip := base_y + height
	var gold := ProceduralProp.color_material(Color(0.92, 0.75, 0.3), 0.35, false)
	b.add_cylinder(0.035, 0.05, 0.9, Vector3(0, tip + 0.4, 0), gold, Vector3.ZERO, 8, roof)
	b.add_sphere(0.12, Vector3(0, tip + 0.25, 0), gold, Vector3.ONE, roof)
	b.add_sphere(0.08, Vector3(0, tip + 0.55, 0), gold, Vector3.ONE, roof)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.1
	ring.outer_radius = 0.14
	ring.rings = 16
	ring.ring_segments = 6
	b._add_mesh(ring, Vector3(0, tip + 0.92, 0), gold, Vector3(PI * 0.5, 0, 0), roof)
	# Tile band under the eaves.
	b.add_box(Vector3(w + 0.3, 0.22, 0.12), Vector3(0, top - 0.1, d * 0.5 + 0.05), tile, Vector3.ZERO, ext)
	b.add_box(Vector3(w + 0.3, 0.22, 0.12), Vector3(0, top - 0.1, -d * 0.5 - 0.05), tile, Vector3.ZERO, ext)
	for sx in [-1.0, 1.0]:
		b.add_box(Vector3(0.12, 0.22, d + 0.3), Vector3(sx * (w * 0.5 + 0.05), top - 0.1, 0), tile, Vector3.ZERO, ext)
	# Minaret(s) at the back corners.
	for i in st.minarets:
		var sx := -1.0 if i == 0 else 1.0
		var mx := sx * (w * 0.5 + 0.7)
		var mz := -d * 0.5 + 0.4
		_minaret(b, roof, Vector3(mx, 0, mz), st.minaret_height, trim, dome, tile)
	# Arched windows on the sides.
	for side in [-1.0, 1.0]:
		for j in 2:
			var z := -d * 0.25 + j * d * 0.5
			b.add_cylinder(0.55, 0.55, 0.1, Vector3(side * (w * 0.5 + 0.01), Building.FOUNDATION_HEIGHT + 1.7, z),
					Building.window_material(false), Vector3(0, 0, PI * 0.5), 12, ext)


static func _minaret(b: Building, roof: Node3D, base: Vector3, h: float, stone: Material, dome: Material, tile: Material) -> void:
	var y0 := Building.FOUNDATION_HEIGHT
	b.add_cylinder(0.55, 0.7, h * 0.7, base + Vector3(0, y0 + h * 0.35, 0), stone, Vector3.ZERO, 10, roof)
	b.add_box(Vector3(1.4, 0.18, 1.4), base + Vector3(0, y0 + h * 0.7, 0), tile, Vector3.ZERO, roof)
	b.add_cylinder(0.4, 0.45, h * 0.22, base + Vector3(0, y0 + h * 0.7 + h * 0.11, 0), stone, Vector3.ZERO, 10, roof)
	b.add_sphere(0.55, base + Vector3(0, y0 + h * 0.7 + h * 0.22 + 0.35, 0), dome, Vector3(1, 0.8, 1), roof)
	b.add_box(Vector3(0.08, 0.55, 0.08), base + Vector3(0, y0 + h * 0.7 + h * 0.22 + 0.75, 0), stone, Vector3.ZERO, roof)
	b.add_box_collider(Vector3(1.2, h * 0.7, 1.2), base + Vector3(0, y0 + h * 0.35, 0))


## Profile (radius, height) of the dome, both normalised to 0..1.
static func _profile(shape: String) -> PackedVector2Array:
	if shape == "onion":
		return PackedVector2Array([Vector2(1.0, 0.0), Vector2(1.07, 0.07), Vector2(1.13, 0.17), Vector2(1.13, 0.28),
			Vector2(1.04, 0.4), Vector2(0.86, 0.53), Vector2(0.6, 0.66), Vector2(0.36, 0.77), Vector2(0.18, 0.87),
			Vector2(0.07, 0.95), Vector2(0.0, 1.0)])
	return PackedVector2Array([Vector2(1.0, 0.0), Vector2(1.0, 0.1), Vector2(0.97, 0.24), Vector2(0.9, 0.4),
		Vector2(0.77, 0.57), Vector2(0.57, 0.74), Vector2(0.32, 0.88), Vector2(0.12, 0.96), Vector2(0.0, 1.0)])


static func _sample(p: PackedVector2Array, t: float) -> Vector2:
	var f := t * (p.size() - 1)
	var i := clampi(int(floor(f)), 0, p.size() - 2)
	var u := f - i
	var a := p[maxi(i - 1, 0)]
	var b := p[i]
	var c := p[i + 1]
	var d := p[mini(i + 2, p.size() - 1)]
	# Catmull-Rom.
	return 0.5 * ((2.0 * b) + (-a + c) * u + (2.0 * a - 5.0 * b + 4.0 * c - d) * u * u + (-a + 3.0 * b - 3.0 * c + d) * u * u * u)


## Lathe mesh of the dome with `ribs` raised ribs (vertex coloured).
static func dome_mesh(shape: String, radius: float, height: float, ribs: int, col: Color, rib_col: Color, band_col: Color) -> ArrayMesh:
	var prof := _profile(shape)
	var rings := 30
	var segs := 64
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var verts: Array[PackedVector3Array] = []
	var cols: Array[PackedColorArray] = []
	for j in rings + 1:
		var t := float(j) / rings
		var pr := _sample(prof, t)
		var row := PackedVector3Array()
		var crow := PackedColorArray()
		for k in segs + 1:
			var phi := TAU * k / segs
			var rib := 0.0
			if ribs > 0:
				rib = pow(absf(cos(phi * ribs * 0.5)), 18.0)
			var fade := clampf(1.0 - t * 1.05, 0.0, 1.0)
			var r := pr.x * radius * (1.0 + 0.045 * rib * fade)
			row.append(Vector3(sin(phi) * r, pr.y * height, cos(phi) * r))
			var c := col.lerp(col.lightened(0.25), t * 0.8)
			if ribs > 0 and rib > 0.35 and t < 0.97:
				c = rib_col
			if t < 0.05:
				c = band_col
			crow.append(c)
		verts.append(row)
		cols.append(crow)
	for j in rings:
		for k in segs:
			var a := verts[j][k]
			var b := verts[j][k + 1]
			var c := verts[j + 1][k + 1]
			var d := verts[j + 1][k]
			for q in [[a, cols[j][k]], [c, cols[j + 1][k + 1]], [b, cols[j][k + 1]], [a, cols[j][k]], [d, cols[j + 1][k]], [c, cols[j + 1][k + 1]]]:
				st.set_color(q[1])
				st.add_vertex(q[0])
	st.generate_normals()
	return st.commit()
