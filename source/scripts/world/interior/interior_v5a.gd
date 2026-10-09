class_name InteriorV5a
extends RefCounted
## v5a interiors: farm workshop, the eight workplaces, water / electricity
## offices, school, university, mosque and church. Built with the shared
## InteriorBuilder helpers (Kenney furniture + procedural boxes, merged into
## one mesh per interior). Front (door) = +z, origin = room centre.




static func _fl(ctx: Dictionary) -> float:
	return float(ctx["floor"])


## Shop counter across the back + the interactive "shop_desk" (opens the
## building's shop from the workplaces module).
static func _shop_counter(ctx: Dictionary, color: Color) -> void:
	var d: float = ctx["d"]
	InteriorBuilder._counter(ctx, -d * 0.5 + 1.3, 2.4, color)
	var it := InteriorBuilder.item(ctx, "shop_desk", Vector3(0, _fl(ctx), -d * 0.5 + 2.1), 0.0, 1.4)
	it.shop_id = (ctx["b"] as Building).shop_id


# ------------------------------------------------------------------ farm workshop
static func workshop(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	var cs := Modules.style("crafting") as CraftingStyle
	var wood := cs.bench_color if cs else Color(0.62, 0.46, 0.3)
	# Long workbench along the back wall.
	var bz := -d * 0.5 + 0.45
	InteriorBuilder.box(ctx, Vector3(w - 1.0, 0.08, 0.75), Vector3(0, fl + 0.9, bz), wood.lightened(0.1))
	for sx: float in [-(w * 0.5 - 0.7), 0.0, w * 0.5 - 0.7]:
		InteriorBuilder.box(ctx, Vector3(0.08, 0.88, 0.7), Vector3(sx, fl + 0.44, bz), wood.darkened(0.2))
	InteriorBuilder.box(ctx, Vector3(w - 1.1, 0.04, 0.6), Vector3(0, fl + 0.28, bz), wood.darkened(0.1))
	InteriorBuilder._collider(ctx, Vector3(w - 1.0, 0.95, 0.75), Vector3(0, fl + 0.47, bz), 0.0)
	# Vice, plane, a half-built birdhouse on the bench.
	InteriorBuilder.box(ctx, Vector3(0.18, 0.14, 0.16), Vector3(-w * 0.3, fl + 1.01, bz + 0.2), Color(0.3, 0.32, 0.35))
	InteriorBuilder.box(ctx, Vector3(0.3, 0.08, 0.08), Vector3(0.4, fl + 0.98, bz + 0.1), Color(0.55, 0.4, 0.25))
	InteriorBuilder.box(ctx, Vector3(0.3, 0.3, 0.3), Vector3(w * 0.25, fl + 1.09, bz), Color(0.7, 0.55, 0.35))
	InteriorBuilder.box(ctx, Vector3(0.36, 0.05, 0.36), Vector3(w * 0.25, fl + 1.27, bz), Color(0.45, 0.25, 0.15), PI * 0.25)
	var props: PackedStringArray = cs.props if cs else PackedStringArray(["tools"])
	if "tools" in props:
		# Pegboard with tools above the bench.
		InteriorBuilder.box(ctx, Vector3(w - 1.4, 0.9, 0.04), Vector3(0, fl + 1.75, -d * 0.5 + 0.04), Color(0.72, 0.6, 0.42))
		for i in 7:
			var x := -w * 0.5 + 1.2 + i * (w - 2.4) / 6.0
			InteriorBuilder.box(ctx, Vector3(0.04, 0.55, 0.04), Vector3(x, fl + 1.75, -d * 0.5 + 0.09), Color(0.42, 0.28, 0.16))
			InteriorBuilder.box(ctx, Vector3(0.16, 0.06, 0.04), Vector3(x, fl + 1.5, -d * 0.5 + 0.09), Color(0.6, 0.62, 0.66))
	if "lathe" in props:
		InteriorBuilder.box(ctx, Vector3(1.1, 0.3, 0.35), Vector3(w * 0.5 - 0.7, fl + 0.85, 0.4), Color(0.25, 0.4, 0.3), PI * 0.5, true)
		InteriorBuilder.box(ctx, Vector3(0.9, 0.7, 0.3), Vector3(w * 0.5 - 0.7, fl + 0.35, 0.4), Color(0.2, 0.2, 0.22), PI * 0.5)
	if "anvil" in props:
		InteriorBuilder.box(ctx, Vector3(0.4, 0.5, 0.4), Vector3(w * 0.5 - 0.7, fl + 0.25, 0.4), Color(0.45, 0.3, 0.2), 0.0, true)
		InteriorBuilder.box(ctx, Vector3(0.7, 0.2, 0.25), Vector3(w * 0.5 - 0.7, fl + 0.6, 0.4), Color(0.15, 0.15, 0.16))
	# Plank rack on the side wall.
	for k in 5:
		InteriorBuilder.box(ctx, Vector3(0.1, 0.04, d - 1.6), Vector3(-w * 0.5 + 0.3, fl + 0.3 + k * 0.28, 0.2), Color(0.75, 0.6, 0.4))
	InteriorBuilder.item(ctx, "craft_bench", Vector3(0, fl, bz + 0.9), 0.0, 1.4)


# ------------------------------------------------------------------ workplaces
static func workplace(ctx: Dictionary, theme: String) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	var rng: RandomNumberGenerator = ctx["rng"]
	match theme:
		"carpenter":
			_shop_counter(ctx, Color(0.55, 0.4, 0.25))
			# v5c: livestock desk (coop / barn orders, animals, feed) beside the counter.
			InteriorBuilder.box(ctx, Vector3(1.1, 0.9, 0.6), Vector3(-w * 0.5 + 1.0, fl + 0.45, -d * 0.5 + 2.6), Color(0.45, 0.32, 0.2), 0.0, true)
			InteriorBuilder.box(ctx, Vector3(0.5, 0.36, 0.04), Vector3(-w * 0.5 + 1.0, fl + 1.12, -d * 0.5 + 2.4), Color(0.92, 0.88, 0.75))
			InteriorBuilder.item(ctx, "livestock_desk", Vector3(-w * 0.5 + 1.0, fl, -d * 0.5 + 3.1), 0.0, 1.1)
			InteriorBuilder.tools_corner(ctx, w * 0.5 - 1.3, -d * 0.5 + 0.05, 0.0, true)
			for k in 6:
				InteriorBuilder.box(ctx, Vector3(2.4, 0.1, 0.3), Vector3(-w * 0.5 + 1.5, fl + 0.05 + k * 0.11, d * 0.5 - 1.2 + (k % 2) * 0.04), Color(0.75, 0.58, 0.38))
			InteriorBuilder.furn(ctx, "chair", w * 0.5 - 1.2, 0.8, 30.0, "y", 0.92)
			InteriorBuilder.furn(ctx, "tableCloth", -w * 0.5 + 1.4, 0.3, 90.0, "y", 0.76)
		"blacksmith":
			_shop_counter(ctx, Color(0.35, 0.32, 0.3))
			var fx := -w * 0.5 + 1.0
			InteriorBuilder.box(ctx, Vector3(1.4, 0.9, 1.2), Vector3(fx, fl + 0.45, -0.3), Color(0.45, 0.25, 0.2), 0.0, true)
			InteriorBuilder.box(ctx, Vector3(1.0, 0.06, 0.8), Vector3(fx, fl + 0.93, -0.3), Color(1.0, 0.45, 0.12))
			InteriorBuilder.box(ctx, Vector3(0.8, 1.6, 0.8), Vector3(fx, fl + 1.9, -0.3), Color(0.35, 0.2, 0.17))
			InteriorBuilder.box(ctx, Vector3(0.4, 0.5, 0.4), Vector3(0.3, fl + 0.25, 0.6), Color(0.45, 0.3, 0.2), 0.0, true)
			InteriorBuilder.box(ctx, Vector3(0.75, 0.2, 0.26), Vector3(0.3, fl + 0.6, 0.6), Color(0.14, 0.14, 0.15))
			InteriorBuilder._cyl_static(ctx, 0.3, 0.6, Vector3(w * 0.5 - 0.7, fl + 0.3, 0.8), Color(0.4, 0.28, 0.18))
			for i in 5:
				InteriorBuilder.box(ctx, Vector3(0.05, 0.6, 0.05), Vector3(w * 0.5 - 0.1, fl + 1.5, -0.8 + i * 0.3), Color(0.25, 0.25, 0.27))
		"mason":
			_shop_counter(ctx, Color(0.6, 0.58, 0.55))
			for k in 8:
				InteriorBuilder.box(ctx, Vector3(0.6, 0.4, 0.4), Vector3(-w * 0.5 + 0.6 + (k % 4) * 0.66, fl + 0.2 + int(k / 4) * 0.4, d * 0.5 - 1.0), Color(0.75, 0.73, 0.68), 0.0, k < 4)
			InteriorBuilder._cyl_static(ctx, 0.28, 1.8, Vector3(w * 0.5 - 0.9, fl + 0.9, 0.4), Color(0.86, 0.84, 0.8))
			InteriorBuilder.box(ctx, Vector3(1.2, 0.8, 0.7), Vector3(-w * 0.5 + 1.0, fl + 0.4, -0.2), Color(0.5, 0.4, 0.3), 0.0, true)
			InteriorBuilder.box(ctx, Vector3(0.4, 0.4, 0.4), Vector3(-w * 0.5 + 1.0, fl + 1.0, -0.2), Color(0.82, 0.8, 0.76), 0.4)
		"fruit_shop":
			_shop_counter(ctx, Color(0.6, 0.45, 0.28))
			var fruit := [Color(0.85, 0.12, 0.1), Color(0.95, 0.85, 0.25), Color(0.95, 0.55, 0.12), Color(0.5, 0.75, 0.2), Color(0.55, 0.15, 0.4)]
			for sx: float in [-1.0, 1.0]:
				for k in 3:
					var z := -0.6 + k * 0.9
					var x := sx * (w * 0.5 - 0.5)
					InteriorBuilder.box(ctx, Vector3(0.7, 0.6, 0.7), Vector3(x, fl + 0.3, z), Color(0.55, 0.4, 0.25), 0.0, true)
					InteriorBuilder.box(ctx, Vector3(0.62, 0.12, 0.62), Vector3(x, fl + 0.66, z), fruit[(k + (2 if sx > 0 else 0)) % fruit.size()])
			InteriorBuilder.furn(ctx, "watermelon", 0.5, -d * 0.5 + 1.3, 0.0, "x", 0.32, false, fl + 1.06, InteriorBuilder._food_dir())
			InteriorBuilder.furn(ctx, "coconut", -0.4, -d * 0.5 + 1.3, 0.0, "x", 0.16, false, fl + 1.06, InteriorBuilder._food_dir())
		"clothing":
			_shop_counter(ctx, Color(0.6, 0.45, 0.5))
			var cols := [Color(0.75, 0.2, 0.2), Color(0.25, 0.55, 0.3), Color(0.25, 0.4, 0.75), Color(0.95, 0.78, 0.25), Color(0.85, 0.85, 0.85)]
			for sx: float in [-1.0, 1.0]:
				var x := sx * (w * 0.5 - 0.6)
				InteriorBuilder.box(ctx, Vector3(0.04, 0.04, 2.4), Vector3(x, fl + 1.6, 0.3), Color(0.6, 0.6, 0.62))
				for i in 7:
					InteriorBuilder.box(ctx, Vector3(0.42, 0.62, 0.06), Vector3(x, fl + 1.25, -0.8 + i * 0.36), cols[(i + int(sx > 0)) % cols.size()])
				for k in 2:
					InteriorBuilder.box(ctx, Vector3(0.04, 1.6, 0.04), Vector3(x, fl + 0.8, -0.9 + k * 2.4), Color(0.6, 0.6, 0.62))
			InteriorBuilder.box(ctx, Vector3(0.7, 1.8, 0.04), Vector3(w * 0.5 - 0.05, fl + 1.0, d * 0.5 - 1.0), Color(0.75, 0.85, 0.9), PI * 0.5)
		"jewelry":
			_shop_counter(ctx, Color(0.25, 0.18, 0.28))
			for k in 3:
				var x := -w * 0.5 + 1.2 + k * (w - 2.4) * 0.5
				InteriorBuilder.box(ctx, Vector3(1.1, 0.9, 0.6), Vector3(x, fl + 0.45, 0.6), Color(0.3, 0.22, 0.3), 0.0, true)
				InteriorBuilder.box(ctx, Vector3(1.0, 0.04, 0.5), Vector3(x, fl + 0.92, 0.6), Color(0.45, 0.12, 0.2))
				for i in 4:
					InteriorBuilder.box(ctx, Vector3(0.06, 0.06, 0.06), Vector3(x - 0.35 + i * 0.23, fl + 0.97, 0.6), Color(0.95, 0.8, 0.3) if i % 2 == 0 else Color(0.85, 0.88, 0.92))
				InteriorBuilder.box(ctx, Vector3(1.04, 0.3, 0.54), Vector3(x, fl + 1.1, 0.6), Color(0.85, 0.95, 1.0))
			InteriorBuilder.furn(ctx, "pottedPlant", w * 0.5 - 0.5, d * 0.5 - 0.5, 0.0, "y", 1.1)
		"tool_shop":
			_shop_counter(ctx, Color(0.4, 0.45, 0.4))
			InteriorBuilder.tools_corner(ctx, -w * 0.5 + 1.3, -d * 0.5 + 0.05, 0.0, false)
			InteriorBuilder._shelf(ctx, w * 0.5 - 0.35, 0.2, -PI * 0.5, d - 2.0, rng)
			for i in 3:
				InteriorBuilder.box(ctx, Vector3(0.05, 1.2, 0.05), Vector3(-w * 0.5 + 0.15, fl + 0.9, -0.2 + i * 0.4), Color(0.45, 0.3, 0.17))
		"electrical":
			_shop_counter(ctx, Color(0.45, 0.45, 0.5))
			InteriorBuilder._shelf(ctx, -(w * 0.5 - 0.35), 0.2, PI * 0.5, d - 2.0, rng)
			for k in 6:
				InteriorBuilder._cyl_static(ctx, 0.18, 0.2, Vector3(w * 0.5 - 0.5, fl + 0.3 + k * 0.25, -0.8 + (k % 2) * 0.5), [Color(0.8, 0.45, 0.2), Color(0.2, 0.2, 0.22), Color(0.8, 0.15, 0.1)][k % 3], Vector3(PI * 0.5, 0, 0))
			for i in 5:
				var bulb := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.07
				sm.height = 0.14
				bulb.mesh = sm
				bulb.material_override = PowerFx.bulb_material()
				bulb.position = Vector3(-1.2 + i * 0.6, fl + 2.4, 0.4)
				(ctx["static"] as Node3D).add_child(bulb)


# ------------------------------------------------------------------ civic
static func service_office(ctx: Dictionary, theme: String) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	InteriorBuilder._counter(ctx, -d * 0.5 + 1.3, 2.6, Color(0.3, 0.4, 0.55) if theme == "water_office" else Color(0.5, 0.45, 0.25))
	InteriorBuilder.item(ctx, "water_desk" if theme == "water_office" else "power_desk", Vector3(0, fl, -d * 0.5 + 2.1), 0.0, 1.4)
	InteriorBuilder.furn(ctx, "chairDesk", 0.0, -d * 0.5 + 0.7, 180.0, "y", 1.0, false)
	InteriorBuilder.furn(ctx, "computerScreen", 0.6, -d * 0.5 + 1.2, 0.0, "x", 0.5, false, fl + 1.03)
	if theme == "water_office":
		# Pipes and a tank level gauge.
		InteriorBuilder._cyl_static(ctx, 0.07, w - 1.0, Vector3(0, fl + 2.6, -d * 0.5 + 0.2), Color(0.3, 0.45, 0.65), Vector3(0, 0, PI * 0.5))
		for i in 3:
			InteriorBuilder._cyl_static(ctx, 0.06, 2.4, Vector3(-w * 0.5 + 1.0 + i * 1.6, fl + 1.4, -d * 0.5 + 0.2), Color(0.3, 0.45, 0.65))
		InteriorBuilder.box(ctx, Vector3(0.6, 1.2, 0.05), Vector3(w * 0.5 - 0.05, fl + 1.4, 0.0), Color(0.85, 0.9, 0.95), PI * 0.5)
		InteriorBuilder.box(ctx, Vector3(0.45, 0.9, 0.05), Vector3(w * 0.5 - 0.08, fl + 1.3, 0.0), Color(0.25, 0.55, 0.9), PI * 0.5)
	else:
		# Grid control board with indicator lamps.
		InteriorBuilder.box(ctx, Vector3(2.4, 1.3, 0.06), Vector3(-w * 0.5 + 0.05, fl + 1.5, 0.0), Color(0.22, 0.26, 0.3), PI * 0.5)
		for r in 3:
			for c in 6:
				InteriorBuilder.box(ctx, Vector3(0.08, 0.08, 0.03), Vector3(-w * 0.5 + 0.1, fl + 1.1 + r * 0.35, -0.9 + c * 0.36), Color(0.3, 0.9, 0.3) if (r + c) % 4 != 0 else Color(0.95, 0.75, 0.2), PI * 0.5)
	for i in 3:
		InteriorBuilder.furn(ctx, "chair", -1.0 + i * 1.0, d * 0.5 - 0.8, 180.0, "y", 0.92, false)
		InteriorBuilder.seat(ctx, Vector3(-1.0 + i * 1.0, 0, d * 0.5 - 0.85), 180.0, "waiting chair").rotation.y = PI
	InteriorBuilder.furn(ctx, "pottedPlant", w * 0.5 - 0.5, d * 0.5 - 0.5, 0.0, "y", 1.1)


static func school(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	# Blackboard + teacher's desk at the back.
	InteriorBuilder.box(ctx, Vector3(4.0, 1.3, 0.05), Vector3(0, fl + 1.6, -d * 0.5 + 0.04), Color(0.12, 0.22, 0.16))
	InteriorBuilder.box(ctx, Vector3(4.2, 0.06, 0.1), Vector3(0, fl + 0.92, -d * 0.5 + 0.08), Color(0.55, 0.4, 0.25))
	InteriorBuilder.furn_sized(ctx, "desk", -2.6, -d * 0.5 + 1.2, 0.0, Vector3(1.4, 0.76, 0.7))
	InteriorBuilder.item(ctx, "teacher", Vector3(-2.6, fl, -d * 0.5 + 1.9), 0.0, 1.3)
	# Pupils' desks: 3 rows x 4, each with a seat (pupils sit here).
	for row in 3:
		for col in 4:
			var x := -3.3 + col * 2.2
			var z := -d * 0.5 + 2.6 + row * 1.5
			InteriorBuilder.furn_sized(ctx, "desk", x, z, 180.0, Vector3(0.9, 0.7, 0.55), false)
			InteriorBuilder.furn(ctx, "chairDesk", x, z + 0.55, 180.0, "y", 0.85, false)
			var s := InteriorBuilder.seat(ctx, Vector3(x, 0, z + 0.55), 180.0, "school chair")
			s.rotation.y = PI
	# Shelves + globe.
	InteriorBuilder.furn(ctx, "bookcaseOpen", w * 0.5 - 0.35, d * 0.5 - 1.2, -90.0, "y", 1.9)
	InteriorBuilder._cyl_static(ctx, 0.04, 0.3, Vector3(-2.6, fl + 0.9, -d * 0.5 + 1.0), Color(0.3, 0.3, 0.3))
	var globe := MeshInstance3D.new()
	var gs := SphereMesh.new()
	gs.radius = 0.16
	gs.height = 0.32
	globe.mesh = gs
	globe.material_override = ProceduralProp.color_material(Color(0.25, 0.5, 0.8), 0.6)
	globe.position = Vector3(-2.6, fl + 1.15, -d * 0.5 + 1.0)
	(ctx["static"] as Node3D).add_child(globe)


static func university(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	# Lecture hall: lectern + screen at the back, benches facing it.
	InteriorBuilder.box(ctx, Vector3(5.0, 2.0, 0.05), Vector3(0, fl + 2.0, -d * 0.5 + 0.04), Color(0.92, 0.94, 0.96))
	InteriorBuilder.box(ctx, Vector3(0.7, 1.1, 0.5), Vector3(-2.0, fl + 0.55, -d * 0.5 + 1.2), Color(0.42, 0.3, 0.2), 0.0, true)
	InteriorBuilder.item(ctx, "lecture", Vector3(-2.0, fl, -d * 0.5 + 2.0), 0.0, 1.4)
	for row in 4:
		var z := -d * 0.5 + 3.0 + row * 1.3
		for half: float in [-1.0, 1.0]:
			var x := half * 3.6
			InteriorBuilder.box(ctx, Vector3(4.6, 0.06, 0.45), Vector3(x, fl + 0.75, z - 0.35), Color(0.5, 0.36, 0.24))
			InteriorBuilder.box(ctx, Vector3(4.6, 0.45, 0.35), Vector3(x, fl + 0.22, z + 0.2), Color(0.45, 0.32, 0.2), 0.0, true)
			for k in 3:
				InteriorBuilder.seat(ctx, Vector3(x - 1.5 + k * 1.5, 0, z + 0.2), 180.0, "lecture bench").rotation.y = PI
	for i in 3:
		InteriorBuilder.furn(ctx, "bookcaseClosedWide", -w * 0.5 + 0.35, -d * 0.5 + 1.6 + i * 2.2, 90.0, "y", 1.9)
		InteriorBuilder.furn(ctx, "bookcaseClosedWide", w * 0.5 - 0.35, -d * 0.5 + 1.6 + i * 2.2, -90.0, "y", 1.9)


# ------------------------------------------------------------------ worship
static func mosque(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	var st := Modules.style("mosque") as MosqueStyle
	var carpet := st.carpet_color if st else Color(0.55, 0.12, 0.14)
	var tile := st.tile_color if st else Color(0.15, 0.45, 0.6)
	# Prayer carpet with rows.
	InteriorBuilder.box(ctx, Vector3(w - 0.8, 0.012, d - 2.2), Vector3(0, fl + 0.006, -0.6), carpet)
	for r in 6:
		InteriorBuilder.box(ctx, Vector3(w - 0.9, 0.014, 0.06), Vector3(0, fl + 0.009, -d * 0.5 + 1.4 + r * 1.1), Color(0.85, 0.75, 0.45))
	# Mihrab niche on the back (qibla) wall + minbar steps.
	InteriorBuilder.box(ctx, Vector3(1.4, 2.4, 0.08), Vector3(0, fl + 1.2, -d * 0.5 + 0.05), tile)
	InteriorBuilder.box(ctx, Vector3(1.0, 2.0, 0.1), Vector3(0, fl + 1.0, -d * 0.5 + 0.08), Color(0.95, 0.9, 0.75))
	InteriorBuilder._cyl_static(ctx, 0.5, 0.1, Vector3(0, fl + 2.0, -d * 0.5 + 0.12), Color(0.95, 0.9, 0.75), Vector3(PI * 0.5, 0, 0))
	for k in 4:
		InteriorBuilder.box(ctx, Vector3(0.9, 0.25 + k * 0.25, 0.35), Vector3(1.6, fl + (0.25 + k * 0.25) * 0.5, -d * 0.5 + 0.4 + (3 - k) * 0.35), Color(0.45, 0.3, 0.18), 0.0, k == 0)
	# Tile band around the walls.
	for sx: float in [-1.0, 1.0]:
		InteriorBuilder.box(ctx, Vector3(0.03, 0.3, d - 0.4), Vector3(sx * (w * 0.5 - 0.02), fl + 1.0, 0), tile)
	# Chandelier ring.
	for k in 8:
		var a := TAU * k / 8.0
		InteriorBuilder.box(ctx, Vector3(0.12, 0.16, 0.12), Vector3(cos(a) * 1.2, fl + 3.0, sin(a) * 1.2 - 0.5), Color(0.95, 0.85, 0.5))
	# Shoe rack by the door.
	InteriorBuilder.box(ctx, Vector3(1.4, 0.5, 0.35), Vector3(-w * 0.5 + 1.0, fl + 0.25, d * 0.5 - 0.3), Color(0.45, 0.32, 0.2), 0.0, true)
	InteriorBuilder.item(ctx, "prayer", Vector3(0, fl, -0.5), 0.0, 1.6)


static func church(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	var st := Modules.style("church") as ChurchStyle
	var pew := st.pew_color if st else Color(0.42, 0.28, 0.16)
	# Altar, cross, candles at the back.
	InteriorBuilder.box(ctx, Vector3(2.0, 0.2, 1.4), Vector3(0, fl + 0.1, -d * 0.5 + 0.9), Color(0.6, 0.55, 0.5), 0.0, true)
	InteriorBuilder.box(ctx, Vector3(1.6, 0.9, 0.7), Vector3(0, fl + 0.65, -d * 0.5 + 0.8), Color(0.92, 0.9, 0.85), 0.0, true)
	InteriorBuilder.box(ctx, Vector3(0.1, 1.2, 0.06), Vector3(0, fl + 2.3, -d * 0.5 + 0.06), Color(0.85, 0.72, 0.3))
	InteriorBuilder.box(ctx, Vector3(0.6, 0.1, 0.06), Vector3(0, fl + 2.55, -d * 0.5 + 0.06), Color(0.85, 0.72, 0.3))
	for sx: float in [-0.6, 0.6]:
		InteriorBuilder._cyl_static(ctx, 0.04, 0.35, Vector3(sx, fl + 1.28, -d * 0.5 + 0.8), Color(0.96, 0.93, 0.85))
	InteriorBuilder.item(ctx, "prayer", Vector3(0, fl, -d * 0.5 + 2.2), 0.0, 1.4)
	# Pews: two columns with an aisle, each with seats.
	for row in 5:
		var z := -d * 0.5 + 3.0 + row * 1.35
		for half: float in [-1.0, 1.0]:
			var x := half * (w * 0.25 + 0.2)
			InteriorBuilder.box(ctx, Vector3(w * 0.38, 0.08, 0.45), Vector3(x, fl + 0.45, z), pew)
			InteriorBuilder.box(ctx, Vector3(w * 0.38, 0.55, 0.06), Vector3(x, fl + 0.75, z + 0.22), pew)
			InteriorBuilder.box(ctx, Vector3(0.06, 0.45, 0.45), Vector3(x - w * 0.19, fl + 0.22, z), pew.darkened(0.2))
			InteriorBuilder.box(ctx, Vector3(0.06, 0.45, 0.45), Vector3(x + w * 0.19, fl + 0.22, z), pew.darkened(0.2))
			InteriorBuilder._collider(ctx, Vector3(w * 0.38, 0.8, 0.5), Vector3(x, fl + 0.4, z), 0.0)
			for k in 2:
				InteriorBuilder.seat(ctx, Vector3(x - w * 0.09 + k * w * 0.18, 0, z - 0.02), 180.0, "pew").rotation.y = PI
	InteriorBuilder.furn(ctx, "pottedPlant", w * 0.5 - 0.5, -d * 0.5 + 0.5, 0.0, "y", 1.1)
	InteriorBuilder.furn(ctx, "pottedPlant", -w * 0.5 + 0.5, -d * 0.5 + 0.5, 0.0, "y", 1.1)
