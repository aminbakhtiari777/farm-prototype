class_name BuildingDecor
extends RefCounted
## v5a exterior extras per building kind, read from the owning module:
## workplaces (striped awnings + shop-front goods), civic (columned portico,
## flag, electricity substation, water tower), workshop (log pile, sawhorse),
## mosque / church (MosqueBuilder / ChurchBuilder). Everything is added to the
## building's exterior/roof nodes so it is merged into the same few meshes.


static func decorate(b: Building, ext: Node3D, roof: Node3D) -> void:
	match b.kind:
		"workplace":
			_workplace(b, ext)
		"civic":
			_civic(b, ext, roof)
		"workshop":
			_workshop(b, ext)
		"mosque":
			MosqueBuilder.decorate(b, roof, ext)
		"church":
			ChurchBuilder.decorate(b, roof, ext)


static func _front(b: Building) -> float:
	return b.size.z * 0.5


static func _workplace(b: Building, ext: Node3D) -> void:
	var ws := Modules.style("workplaces") as WorkplaceStyle
	var hd := _front(b)
	var y := Building.FOUNDATION_HEIGHT
	if ws and ws.awnings and not ws.awning_colors.is_empty():
		var c: Color = ws.awning_colors[absi(hash(b.layout_id)) % ws.awning_colors.size()]
		var stripes := int(b.size.x / 0.5)
		for i in stripes:
			var col := c if i % 2 == 0 else Color(0.95, 0.93, 0.86)
			b.add_box(Vector3(b.size.x / stripes, 0.04, 1.1), Vector3(-b.size.x * 0.5 + (i + 0.5) * b.size.x / stripes, y + 2.75, hd + 0.5),
					ProceduralProp.color_material(col, 0.9, false), Vector3(0.32, 0, 0), ext)
	var wood := ProceduralProp.color_material(Color(0.5, 0.35, 0.22), 0.85)
	var side := b.size.x * 0.5 - 0.9
	match b.layout_id:
		"carpenter":
			for k in 4:
				b.add_box(Vector3(2.2, 0.12, 0.25), Vector3(side - 0.4, y + 0.06 + k * 0.13, hd + 1.0 + (k % 2) * 0.05), ProceduralProp.color_material(Color(0.72, 0.56, 0.36), 0.85), Vector3.ZERO, ext)
			b.add_box(Vector3(0.8, 0.06, 0.3), Vector3(-side, y + 0.6, hd + 1.0), wood, Vector3.ZERO, ext)
			for sx in [-0.3, 0.3]:
				b.add_box(Vector3(0.05, 0.6, 0.3), Vector3(-side + sx, y + 0.3, hd + 1.0), wood, Vector3(0, 0, sx * 0.4), ext)
		"blacksmith":
			var iron := ProceduralProp.color_material(Color(0.15, 0.15, 0.16), 0.45, false)
			b.add_box(Vector3(0.5, 0.45, 0.4), Vector3(side, y + 0.22, hd + 1.0), wood, Vector3.ZERO, ext)
			b.add_box(Vector3(0.7, 0.18, 0.28), Vector3(side, y + 0.54, hd + 1.0), iron, Vector3.ZERO, ext)
			b.add_box(Vector3(0.7, 1.6, 0.7), Vector3(-b.size.x * 0.5 + 0.5, Building.FOUNDATION_HEIGHT + b.size.y + 0.6, -b.size.z * 0.25),
					ProceduralProp.color_material(Color(0.45, 0.25, 0.2), 0.9), Vector3.ZERO, ext)
		"mason":
			var stone := ProceduralProp.color_material(Color(0.72, 0.7, 0.66), 0.95)
			for k in 5:
				b.add_box(Vector3(0.6, 0.4, 0.4), Vector3(side - (k % 3) * 0.65, y + 0.2 + int(k / 3) * 0.4, hd + 1.1), stone, Vector3(0, k * 0.2, 0), ext)
		"fruit_shop":
			var fruit := [Color(0.85, 0.12, 0.1), Color(0.95, 0.85, 0.25), Color(0.95, 0.55, 0.12), Color(0.5, 0.75, 0.2)]
			for k in 4:
				var fx := -side + 0.3 + k * 0.62 if k < 2 else side - 0.3 - (k - 2) * 0.62
				b.add_box(Vector3(0.55, 0.3, 0.4), Vector3(fx, y + 0.45, hd + 0.75), wood, Vector3.ZERO, ext)
				b.add_box(Vector3(0.5, 0.1, 0.35), Vector3(fx, y + 0.62, hd + 0.75), ProceduralProp.color_material(fruit[k], 0.5, false), Vector3.ZERO, ext)
				for sx in [-0.22, 0.22]:
					b.add_box(Vector3(0.05, 0.3, 0.05), Vector3(fx + sx, y + 0.15, hd + 0.75), wood, Vector3.ZERO, ext)
		"clothing":
			b.add_box(Vector3(0.05, 1.8, 0.05), Vector3(side, y + 0.9, hd + 0.8), wood, Vector3.ZERO, ext)
			b.add_sphere(0.2, Vector3(side, y + 1.55, hd + 0.8), ProceduralProp.color_material(Color(0.85, 0.75, 0.65), 0.6), Vector3(1, 1.3, 0.7), ext)
			b.add_box(Vector3(0.5, 0.6, 0.25), Vector3(side, y + 1.1, hd + 0.8), ProceduralProp.color_material(Color(0.75, 0.3, 0.45), 0.8), Vector3.ZERO, ext)
		"tool_shop", "electrical":
			b.add_box(Vector3(0.9, 0.6, 0.5), Vector3(side, y + 0.3, hd + 0.9), wood, Vector3.ZERO, ext)
			b.add_box(Vector3(0.6, 0.3, 0.35), Vector3(side, y + 0.75, hd + 0.9), ProceduralProp.color_material(Color(0.85, 0.6, 0.15) if b.layout_id == "electrical" else Color(0.3, 0.45, 0.65), 0.6), Vector3.ZERO, ext)


static func _civic(b: Building, ext: Node3D, roof: Node3D) -> void:
	var cs := Modules.style("civic") as CivicStyle
	if cs == null:
		return
	var hd := _front(b)
	var y := Building.FOUNDATION_HEIGHT
	if cs.columns:
		var col := ProceduralProp.color_material(cs.column_color, 0.7)
		var n := 4 if b.size.x < 11.0 else 6
		var span := minf(b.size.x - 1.0, 7.5 if n == 4 else 11.0)
		for i in n:
			var x := -span * 0.5 + span * i / (n - 1)
			if absf(x - b.door_offset) < 0.9:
				continue
			b.add_cylinder(0.17, 0.2, b.size.y, Vector3(x, y + b.size.y * 0.5, hd + 1.3), col, Vector3.ZERO, 10, ext)
			b.add_cylinder_collider(0.2, b.size.y, Vector3(x, y + b.size.y * 0.5, hd + 1.3))
		b.add_box(Vector3(span + 0.8, 0.3, 1.8), Vector3(0, y + b.size.y + 0.15, hd + 0.9), col, Vector3.ZERO, roof)
		b.add_gable_to(span + 0.8, 0.9, 0.3, Vector3(0, y + b.size.y + 0.75, hd + 1.65), col, Vector3.ZERO, roof)
		b.add_box(Vector3(span + 1.0, 0.12, 2.0), Vector3(0, 0.06, hd + 0.9), col, Vector3.ZERO, ext)
	# Flag pole on the front corner.
	var px := b.size.x * 0.5 + 0.6
	b.add_box(Vector3(0.07, 5.0, 0.07), Vector3(px, 2.5, hd - 0.3), ProceduralProp.color_material(Color(0.8, 0.8, 0.82), 0.4, false), Vector3.ZERO, ext)
	b.add_box(Vector3(0.03, 0.6, 1.0), Vector3(px, 4.6, hd - 0.8), ProceduralProp.color_material(cs.flag_color, 0.8, false), Vector3.ZERO, ext)
	if b.layout_id == "power_office" and cs.substation:
		_substation(b, ext)
	if b.layout_id == "water_office" and cs.water_tower:
		_water_tower(b, ext)
	if b.layout_id == "school":
		# Bell + playground bits.
		b.add_cylinder(0.08, 0.25, 0.35, Vector3(0, y + b.size.y + 2.2, -0.0), ProceduralProp.color_material(Color(0.75, 0.6, 0.25), 0.35, false), Vector3.ZERO, 10, roof)


## Electricity office: transformer yard with insulators and a fence; the
## electricity module's power post and lines tie into it.
static func _substation(b: Building, ext: Node3D) -> void:
	var x0 := -(b.size.x * 0.5 + 2.6)
	var z0 := -0.3
	var grey := ProceduralProp.color_material(Color(0.55, 0.57, 0.6), 0.5, false)
	var dark := ProceduralProp.color_material(Color(0.25, 0.26, 0.28), 0.6, false)
	var ins := ProceduralProp.color_material(Color(0.6, 0.35, 0.25), 0.4, false)
	b.add_box(Vector3(3.4, 0.15, 4.4), Vector3(x0, 0.07, z0), ProceduralProp.color_material(Color(0.5, 0.5, 0.48), 0.95), Vector3.ZERO, ext)
	for k in 2:
		var p := Vector3(x0, 0, z0 - 1.0 + k * 2.0)
		b.add_box(Vector3(1.3, 1.3, 1.0), p + Vector3(0, 0.8, 0), grey, Vector3.ZERO, ext)
		for f in 4:
			b.add_box(Vector3(0.18, 1.0, 0.04), p + Vector3(-0.74, 0.8, -0.36 + f * 0.24), dark, Vector3.ZERO, ext)
		for i in 3:
			b.add_cylinder(0.06, 0.09, 0.45, p + Vector3(-0.4 + i * 0.4, 1.68, 0), ins, Vector3.ZERO, 8, ext)
		b.add_box_collider(Vector3(1.3, 1.5, 1.0), p + Vector3(0, 0.75, 0))
	# Chain-link fence.
	for sz in [-1.0, 1.0]:
		b.add_box(Vector3(3.4, 1.6, 0.03), Vector3(x0, 0.8, z0 + sz * 2.2), ProceduralProp.color_material(Color(0.7, 0.72, 0.74, 1.0), 0.4, false), Vector3.ZERO, ext)
		b.add_box_collider(Vector3(3.4, 1.6, 0.1), Vector3(x0, 0.8, z0 + sz * 2.2))
	b.add_box(Vector3(0.03, 1.6, 4.4), Vector3(x0 - 1.7, 0.8, z0), ProceduralProp.color_material(Color(0.7, 0.72, 0.74), 0.4, false), Vector3.ZERO, ext)
	b.add_box_collider(Vector3(0.1, 1.6, 4.4), Vector3(x0 - 1.7, 0.8, z0))
	# Warning sign.
	b.add_box(Vector3(0.5, 0.4, 0.02), Vector3(x0, 1.1, z0 + 2.23), ProceduralProp.color_material(Color(0.95, 0.8, 0.1), 0.5, false), Vector3.ZERO, ext)


static func _water_tower(b: Building, ext: Node3D) -> void:
	var p := Vector3(b.size.x * 0.5 + 2.6, 0, -0.5)
	var steel := ProceduralProp.color_material(Color(0.5, 0.6, 0.68), 0.5, false)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			b.add_box(Vector3(0.14, 6.0, 0.14), p + Vector3(sx * 0.9, 3.0, sz * 0.9), steel, Vector3.ZERO, ext)
	b.add_cylinder(1.5, 1.5, 2.2, p + Vector3(0, 7.1, 0), ProceduralProp.color_material(Color(0.6, 0.75, 0.85), 0.5, false), Vector3.ZERO, 16, ext)
	b.add_cylinder(0.2, 1.6, 0.8, p + Vector3(0, 8.6, 0), steel, Vector3.ZERO, 16, ext)
	b.add_box_collider(Vector3(2.0, 6.0, 2.0), p + Vector3(0, 3.0, 0))


static func _workshop(b: Building, ext: Node3D) -> void:
	var cs := Modules.style("crafting") as CraftingStyle
	var wood := ProceduralProp.color_material(Color(0.45, 0.3, 0.18), 0.85)
	var hd := _front(b)
	# Log pile against the side wall.
	var lx := b.size.x * 0.5 + 0.45
	for k in 6:
		b.add_cylinder(0.14, 0.14, 1.4, Vector3(lx, 0.15 + int(k / 3) * 0.26, -0.8 + (k % 3) * 0.3 + (0.15 if k >= 3 else 0.0)),
				wood, Vector3(PI * 0.5, 0, 0), 8, ext)
	b.add_box_collider(Vector3(0.4, 0.6, 1.4), Vector3(lx, 0.3, -0.5))
	# Sawhorse + plank by the door.
	if cs == null or cs.sawdust:
		var sx0 := b.size.x * 0.5 - 0.9
		for dx in [-0.35, 0.35]:
			b.add_box(Vector3(0.06, 0.6, 0.5), Vector3(sx0 + dx, 0.3, hd + 1.1), wood, Vector3(0.3, 0, 0), ext)
		b.add_box(Vector3(1.1, 0.06, 0.12), Vector3(sx0, 0.62, hd + 1.1), wood, Vector3.ZERO, ext)
		b.add_box(Vector3(1.4, 0.04, 0.22), Vector3(sx0, 0.68, hd + 1.1), ProceduralProp.color_material(Color(0.78, 0.62, 0.4), 0.8), Vector3(0, 0.3, 0), ext)
