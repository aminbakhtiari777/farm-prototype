class_name KitchenBuilder
extends RefCounted
## v5a kitchen module: the counter run every home gets along its back wall -
## fridge, stove (electric / gas / wood from KitchenStyle), sink, base and
## upper cabinets, range hood and pots - plus the interactive "stove"
## InteriorItem that cooks the "stove" recipes. Procedural pieces are merged
## with the rest of the furniture (MeshMerger), so a kitchen adds ~0 draw calls.


## side: +1 = kitchen on the +x half of the back wall, -1 = on the -x half.
static func build(ctx: Dictionary, side: float, hw: float, hd: float) -> InteriorItem:
	var ks := Modules.style("kitchen") as KitchenStyle
	var cab := ks.cabinet_color if ks else Color(0.9, 0.9, 0.86)
	var top := ks.counter_color if ks else Color(0.3, 0.3, 0.32)
	var stove_kind := ks.stove if ks else "electric"
	# v6b gas_stove module: every kitchen gets a gas hob with a visible flame.
	var gs := Modules.style("gas_stove") as GasStoveStyle
	if gs and gs.force_gas:
		stove_kind = "gas"
	var fl := float(ctx["floor"])
	var z := -hd + 0.33
	var kx := side * (hw - 0.45)
	# Fridge in the corner (Kenney model) + snack item.
	# v6b fridge module: an openable fridge showing what is stored inside.
	var fridge_item := InteriorBuilder.item(ctx, "fridge", Vector3(kx, fl, -hd + 0.5), 0.0, 1.0)
	if Modules.style("fridge") != null:
		var fu := FridgeUnit.new()
		fu.name = "FridgeUnit"
		fu.building = ctx["b"]
		fu.hinge = side
		fu.position = Vector3(kx, fl, -hd + 0.38)
		(ctx["root"] as Node3D).add_child(fu)
		(ctx["b"] as Building).add_box_collider(Vector3(0.72, 1.82, 0.66), fu.position + Vector3(0, 0.91, 0))
		fridge_item.set_meta(&"fridge_unit", fu)
	else:
		InteriorBuilder.furn(ctx, "kitchenFridge", kx, -hd + 0.38, 0.0, "y", 1.85)
	# Base cabinets with worktop from the fridge toward the room centre.
	var sx := kx - side * 0.9   # stove
	var sink_x := kx - side * 1.75
	var end_x := kx - side * 2.55
	for cx: float in [sink_x, end_x]:
		_base_cabinet(ctx, cx, z, cab, top)
	# Stove.
	var stove_col := ks.stove_color if ks else Color(0.9, 0.9, 0.9)
	match stove_kind:
		"wood":
			InteriorBuilder.box(ctx, Vector3(0.8, 0.8, 0.62), Vector3(sx, fl + 0.4, z), stove_col, 0.0, true)
			InteriorBuilder.box(ctx, Vector3(0.84, 0.05, 0.66), Vector3(sx, fl + 0.82, z), stove_col.lightened(0.15))
			InteriorBuilder.box(ctx, Vector3(0.36, 0.22, 0.02), Vector3(sx, fl + 0.42, z + 0.32), Color(0.9, 0.4, 0.1))
			InteriorBuilder._cyl_static(ctx, 0.08, float(ctx["h"]) - 0.85, Vector3(sx, fl + 0.85 + (float(ctx["h"]) - 0.85) * 0.5, z - 0.15), stove_col)
		_:
			InteriorBuilder.box(ctx, Vector3(0.8, 0.88, 0.62), Vector3(sx, fl + 0.44, z), stove_col, 0.0, true)
			InteriorBuilder.box(ctx, Vector3(0.8, 0.03, 0.62), Vector3(sx, fl + 0.895, z), Color(0.08, 0.08, 0.09))
			InteriorBuilder.box(ctx, Vector3(0.6, 0.36, 0.02), Vector3(sx, fl + 0.42, z + 0.315), Color(0.12, 0.12, 0.14))
			for bx: float in [-0.18, 0.18]:
				for bz: float in [-0.13, 0.13]:
					InteriorBuilder._cyl_static(ctx, 0.09, 0.012, Vector3(sx + bx, fl + 0.915, z + bz), Color(0.25, 0.25, 0.27) if stove_kind == "gas" else Color(0.18, 0.12, 0.12))
			for k in 4:
				InteriorBuilder.box(ctx, Vector3(0.05, 0.05, 0.03), Vector3(sx - 0.27 + k * 0.18, fl + 0.8, z + 0.32), Color(0.2, 0.2, 0.2))
	# Range hood + upper cabinets.
	if ks == null or ks.hood:
		InteriorBuilder.box(ctx, Vector3(0.8, 0.3, 0.5), Vector3(sx, fl + 1.85, -hd + 0.27), stove_col.darkened(0.1))
		InteriorBuilder.box(ctx, Vector3(0.24, 0.6, 0.24), Vector3(sx, fl + 2.3, -hd + 0.14), stove_col.darkened(0.1))
	if ks == null or ks.upper_cabinets:
		for cx: float in [sink_x, end_x]:
			InteriorBuilder.box(ctx, Vector3(0.82, 0.62, 0.34), Vector3(cx, fl + 1.85, -hd + 0.19), cab)
			InteriorBuilder.box(ctx, Vector3(0.02, 0.5, 0.01), Vector3(cx, fl + 1.85, -hd + 0.365), cab.darkened(0.25))
	else:
		InteriorBuilder.box(ctx, Vector3(1.7, 0.04, 0.26), Vector3((sink_x + end_x) * 0.5, fl + 1.65, -hd + 0.15), cab.darkened(0.15))
	# Sink.
	if ks == null or ks.sink:
		InteriorBuilder.box(ctx, Vector3(0.5, 0.02, 0.36), Vector3(sink_x, fl + 0.935, z + 0.02), Color(0.7, 0.72, 0.75))
		InteriorBuilder.box(ctx, Vector3(0.04, 0.26, 0.04), Vector3(sink_x, fl + 1.05, z - 0.2), Color(0.75, 0.76, 0.8))
		InteriorBuilder.box(ctx, Vector3(0.03, 0.03, 0.18), Vector3(sink_x, fl + 1.17, z - 0.12), Color(0.75, 0.76, 0.8))
	# Pots on the stove.
	if ks == null or ks.pots:
		InteriorBuilder._cyl_static(ctx, 0.12, 0.16, Vector3(sx - 0.18, fl + 1.0, z - 0.1), Color(0.55, 0.56, 0.6))
		InteriorBuilder._cyl_static(ctx, 0.1, 0.05, Vector3(sx + 0.18, fl + 0.95, z + 0.12), Color(0.15, 0.15, 0.16))
	var it := InteriorBuilder.item(ctx, "stove", Vector3(sx, fl, -hd + 0.9), 0.0, 1.0)
	it.set_meta(&"glow_pos", Vector3(sx, fl + 1.0, z))
	# v5b hands-on cooking (CookingStation): pan on the front-left burner,
	# cutting board on the worktop next to the sink.
	it.set_meta(&"pan_pos", Vector3(sx - 0.18, fl + 0.93, z + 0.13))
	it.set_meta(&"board_pos", Vector3(end_x, fl + 0.95, z + 0.02))
	it.set_meta(&"gas", stove_kind == "gas")
	return it


static func _base_cabinet(ctx: Dictionary, x: float, z: float, cab: Color, top: Color) -> void:
	var fl := float(ctx["floor"])
	# Hollow cabinet with its own hinge; a solid baked box hid the shelves.
	var node := Node3D.new()
	node.name = "KitchenCabinet"
	node.position = Vector3(x, fl, z)
	(ctx["root"] as Node3D).add_child(node)
	for spec in [[Vector3(0.04, 0.86, 0.6), Vector3(-0.39, 0.43, 0)], [Vector3(0.04, 0.86, 0.6), Vector3(0.39, 0.43, 0)], [Vector3(0.82, 0.04, 0.6), Vector3(0, 0.06, 0)], [Vector3(0.82, 0.04, 0.6), Vector3(0, 0.45, 0)], [Vector3(0.82, 0.86, 0.04), Vector3(0, 0.43, -0.28)]]:
		V7aKit.box(node, spec[0], spec[1], ProceduralProp.color_material(cab, 0.8), false)
	var hinge := BuildingDoor.new()
	hinge.name = "CabinetDoor"
	hinge.width = 0.78
	hinge.height = 0.78
	hinge.panel_color = cab
	hinge.position = Vector3(-0.39, 0.08, 0.32)
	node.add_child(hinge)
	if hinge._zone:
		hinge._zone.set_action_text(Lang.tt("باز یا بسته کردن کابینت", "open or close the cabinet"))
		(hinge._zone.get_child(0) as CollisionShape3D).shape = _cabinet_zone()
	InteriorBuilder.box(ctx, Vector3(0.86, 0.05, 0.64), Vector3(x, fl + 0.885, z + 0.01), top)


static func _cabinet_zone() -> SphereShape3D:
	var sphere := SphereShape3D.new()
	sphere.radius = 0.9
	return sphere
