class_name InteriorBuilder
extends RefCounted


static func _furniture_dir() -> String:
	var f := Modules.style("furniture") as FurnitureStyle
	return f.furniture_dir if f else "res://assets/third_party/kenney/furniture/"


static func _food_dir() -> String:
	var f := Modules.style("furniture") as FurnitureStyle
	return f.food_dir if f else "res://assets/third_party/kenney/food/"

## Furnishes building interiors with CC0 Kenney "Furniture Kit" models plus a
## few procedural pieces (tool rack, workbench, counters, shelves). Every home
## gets: a bed, a fridge, a table with chairs (seats), a TV (toggle) on a
## cabinet, a tool rack + workbench; layouts are mirrored / swapped and the
## colours, beds, tables and TVs differ per theme. Civic buildings get themed
## rooms (shop counter, cafe tables, hospital beds, office desks...).
##
## Static furniture is merged into one mesh per interior (MeshMerger); only
## interactive bits (TV screen, Seats, InteriorItems) stay separate nodes.


const THEMES := {
	"farmhouse": {"wall": Color(0.66, 0.5, 0.34), "floor": Color(0.42, 0.29, 0.18)},
	"home_a": {"wall": Color(0.78, 0.86, 0.72), "floor": Color(0.62, 0.45, 0.28)},
	"home_b": {"wall": Color(0.72, 0.82, 0.9), "floor": Color(0.55, 0.55, 0.56)},
	"home_c": {"wall": Color(0.95, 0.9, 0.76), "floor": Color(0.66, 0.36, 0.25)},
	"home_d": {"wall": Color(0.9, 0.74, 0.74), "floor": Color(0.32, 0.24, 0.18)},
	"store": {"wall": Color(0.93, 0.88, 0.75), "floor": Color(0.55, 0.42, 0.3)},
	"supermarket": {"wall": Color(0.92, 0.94, 0.92), "floor": Color(0.75, 0.75, 0.72)},
	"cafe": {"wall": Color(0.85, 0.7, 0.55), "floor": Color(0.38, 0.26, 0.18)},
	"office": {"wall": Color(0.9, 0.9, 0.86), "floor": Color(0.45, 0.3, 0.2)},
	"post": {"wall": Color(0.82, 0.88, 0.95), "floor": Color(0.6, 0.6, 0.58)},
	"hospital": {"wall": Color(0.92, 0.97, 0.97), "floor": Color(0.8, 0.85, 0.85)},
	"police": {"wall": Color(0.78, 0.82, 0.9), "floor": Color(0.5, 0.52, 0.56)},
	# v5a
	"workshop": {"wall": Color(0.7, 0.56, 0.4), "floor": Color(0.5, 0.4, 0.3)},
	"carpenter": {"wall": Color(0.82, 0.7, 0.52), "floor": Color(0.52, 0.38, 0.24)},
	"blacksmith": {"wall": Color(0.55, 0.5, 0.46), "floor": Color(0.36, 0.34, 0.32)},
	"mason": {"wall": Color(0.82, 0.8, 0.74), "floor": Color(0.6, 0.58, 0.54)},
	"fruit_shop": {"wall": Color(0.96, 0.9, 0.72), "floor": Color(0.6, 0.45, 0.3)},
	"clothing": {"wall": Color(0.95, 0.86, 0.9), "floor": Color(0.55, 0.42, 0.36)},
	"jewelry": {"wall": Color(0.36, 0.28, 0.4), "floor": Color(0.25, 0.2, 0.22)},
	"tool_shop": {"wall": Color(0.82, 0.86, 0.8), "floor": Color(0.5, 0.48, 0.44)},
	"electrical": {"wall": Color(0.92, 0.9, 0.78), "floor": Color(0.5, 0.5, 0.52)},
	"water_office": {"wall": Color(0.82, 0.9, 0.96), "floor": Color(0.55, 0.6, 0.65)},
	"power_office": {"wall": Color(0.96, 0.93, 0.8), "floor": Color(0.5, 0.48, 0.45)},
	"school": {"wall": Color(0.96, 0.92, 0.8), "floor": Color(0.6, 0.45, 0.3)},
	"university": {"wall": Color(0.9, 0.86, 0.78), "floor": Color(0.42, 0.3, 0.22)},
	"mosque": {"wall": Color(0.96, 0.95, 0.9), "floor": Color(0.7, 0.66, 0.58)},
	"church": {"wall": Color(0.9, 0.87, 0.8), "floor": Color(0.55, 0.5, 0.45)},
	# v6a
	"gym": {"wall": Color(0.86, 0.88, 0.9), "floor": Color(0.25, 0.27, 0.3)},
	"hypermarket": {"wall": Color(0.95, 0.96, 0.97), "floor": Color(0.82, 0.82, 0.8)},
}

static var _scene_cache: Dictionary = {}


static func theme_colors(theme: String) -> Dictionary:
	return THEMES.get(theme, THEMES["home_a"])


static func build(building: Building, root: Node3D, theme: String, inner: Vector3, rng: RandomNumberGenerator) -> void:
	var static_root := Node3D.new()
	static_root.name = "StaticFurniture"
	root.add_child(static_root)
	var ctx := {"b": building, "root": root, "static": static_root, "w": inner.x, "h": inner.y, "d": inner.z,
			"floor": Building.FOUNDATION_HEIGHT + 0.04, "rng": rng}
	match theme:
		"farmhouse":
			_home(ctx, 1.0, {"bed": "bedDouble", "table": "table", "tv": "televisionVintage", "sofa": "loungeChair", "rug": "rugRectangle", "extra": "radio", "rustic": true})
		"home_a":
			_home(ctx, 1.0, {"bed": "bedDouble", "table": "table", "tv": "televisionModern", "sofa": "loungeSofa", "rug": "rugRectangle", "extra": "pottedPlant"})
		"home_b":
			_home(ctx, -1.0, {"bed": "bedSingle", "table": "tableRound", "tv": "televisionModern", "sofa": "loungeSofa", "rug": "rugRound", "extra": "lampRoundFloor"})
		"home_c":
			_home(ctx, 1.0, {"bed": "bedSingle", "table": "tableCloth", "tv": "televisionVintage", "sofa": "loungeChair", "rug": "rugRound", "extra": "bookcaseOpen", "swap": true})
		"home_d":
			_home(ctx, -1.0, {"bed": "bedDouble", "table": "tableCloth", "tv": "televisionVintage", "sofa": "loungeSofa", "rug": "rugRectangle", "extra": "bookcaseClosedWide", "swap": true})
		"store", "supermarket":
			_shop(ctx, theme == "supermarket")
		"cafe":
			_cafe(ctx)
		"office", "police":
			_office(ctx, theme == "police")
		"post":
			_post(ctx)
		"hospital":
			_hospital(ctx)
		"workshop":
			InteriorV5a.workshop(ctx)
		"carpenter", "blacksmith", "mason", "fruit_shop", "clothing", "jewelry", "tool_shop", "electrical":
			InteriorV5a.workplace(ctx, theme)
		"water_office", "power_office":
			InteriorV5a.service_office(ctx, theme)
		"school":
			InteriorV5a.school(ctx)
		"university":
			InteriorV5a.university(ctx)
		"mosque":
			InteriorV5a.mosque(ctx)
		"church":
			InteriorV5a.church(ctx)
		"gym":
			InteriorV6a.gym(ctx)
		"hypermarket":
			InteriorV6a.hypermarket(ctx)
		_:
			_home(ctx, 1.0, {"bed": "bedSingle", "table": "table", "tv": "televisionModern", "sofa": "loungeSofa", "rug": "rugRound", "extra": "pottedPlant"})
	var merged := MeshMerger.merge_children(static_root, root, "FurnitureMesh")
	merged.visibility_range_end = 60.0
	root.add_child(merged)


# ------------------------------------------------------------------ helpers
static func _scene(path: String) -> PackedScene:
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	return _scene_cache[path]


static func _aabb(node: Node) -> AABB:
	var bounds := AABB()
	var first := true
	for mi in node.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var xf := MeshMerger._relative_xform(m, node as Node3D)
		var a := xf * m.mesh.get_aabb()
		bounds = a if first else bounds.merge(a)
		first = false
	return bounds


## Places a Kenney model so that its size along `axis` ("x" width, "y" height,
## "z" depth) equals `target`, standing on the floor at (x, z), rotated by yaw.
static func furn(ctx: Dictionary, model: String, x: float, z: float, yaw_deg: float, axis: String, target: float,
		collide: bool = true, y: float = -1.0, dir: String = "_auto_") -> Node3D:
	if dir == "_auto_":
		dir = _furniture_dir()
	return _place(ctx, dir + model + ".glb", x, z, yaw_deg, axis, target, Vector3.ZERO, collide, y)


## Like furn() but stretches the model to an exact size (width, height, depth).
static func furn_sized(ctx: Dictionary, model: String, x: float, z: float, yaw_deg: float, size: Vector3,
		collide: bool = true, y: float = -1.0, dir: String = "_auto_") -> Node3D:
	if dir == "_auto_":
		dir = _furniture_dir()
	return _place(ctx, dir + model + ".glb", x, z, yaw_deg, "", 0.0, size, collide, y)


static func _place(ctx: Dictionary, path: String, x: float, z: float, yaw_deg: float, axis: String, target: float,
		size: Vector3, collide: bool, y: float) -> Node3D:
	if not ResourceLoader.exists(path):
		return null
	var inst := _scene(path).instantiate() as Node3D
	var bounds := _aabb(inst)
	var sc: Vector3
	if size != Vector3.ZERO:
		sc = size / bounds.size.max(Vector3.ONE * 0.001)
	else:
		var extent: float = {"x": bounds.size.x, "y": bounds.size.y, "z": bounds.size.z}[axis]
		sc = Vector3.ONE * (target / maxf(extent, 0.001))
	var holder := Node3D.new()
	holder.position = Vector3(x, ctx["floor"] if y < 0.0 else y, z)
	holder.rotation.y = deg_to_rad(yaw_deg)
	(ctx["static"] as Node3D).add_child(holder)
	inst.scale = sc
	var c := bounds.get_center()
	inst.position = Vector3(-c.x * sc.x, -bounds.position.y * sc.y, -c.z * sc.z)
	holder.add_child(inst)
	var bs := bounds.size * sc
	if collide:
		_collider(ctx, bs, holder.position + Vector3(0, bs.y * 0.5, 0), holder.rotation.y)
	holder.set_meta(&"size", bs)
	return holder


static func _collider(ctx: Dictionary, size: Vector3, pos: Vector3, yaw: float) -> void:
	var b := ctx["b"] as Building
	b.add_box_collider(size * Vector3(0.92, 1.0, 0.92), pos, Vector3(0, yaw, 0))


static func box(ctx: Dictionary, size: Vector3, pos: Vector3, color: Color, yaw: float = 0.0, collide: bool = false) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = ProceduralProp.color_material(color, 0.8)
	mi.position = pos
	mi.rotation.y = yaw
	(ctx["static"] as Node3D).add_child(mi)
	if collide:
		_collider(ctx, size, pos, yaw)


static func item(ctx: Dictionary, kind: String, pos: Vector3, yaw_deg: float, radius: float = 1.3) -> InteriorItem:
	var it := InteriorItem.new()
	it.kind = kind
	it.radius = radius
	it.building = ctx["b"]
	it.position = pos
	it.rotation.y = deg_to_rad(yaw_deg)
	(ctx["root"] as Node3D).add_child(it)
	return it


static func seat(ctx: Dictionary, pos: Vector3, yaw_deg: float, label: String) -> Seat:
	var s := Seat.new()
	s.display_name = label
	s.interact_radius = 0.9
	s.position = Vector3(pos.x, ctx["floor"], pos.z)
	s.rotation.y = deg_to_rad(yaw_deg)
	(ctx["root"] as Node3D).add_child(s)
	return s


## Wall-mounted pegboard with tools + a workbench in front of it.
static func tools_corner(ctx: Dictionary, x: float, z: float, yaw_deg: float, rustic: bool) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var base := Vector3(x, ctx["floor"], z)
	var board := Color(0.55, 0.42, 0.28) if rustic else Color(0.72, 0.6, 0.42)
	box(ctx, Vector3(1.5, 1.0, 0.04), base + Vector3(0, 1.55, 0) - fwd * 0.02, board, yaw)
	# Tools: hoe, rake, saw, hammer, a watering can.
	var metal := Color(0.55, 0.57, 0.6)
	var wood := Color(0.45, 0.3, 0.17)
	for i in 3:
		var p := base + right * (-0.5 + i * 0.25) + fwd * 0.05 + Vector3(0, 1.5, 0)
		box(ctx, Vector3(0.035, 0.85, 0.035), p, wood, yaw)
		box(ctx, Vector3(0.18 if i != 1 else 0.26, 0.05, 0.03), p + Vector3(0, -0.42, 0), metal, yaw)
	box(ctx, Vector3(0.36, 0.13, 0.02), base + right * 0.35 + fwd * 0.05 + Vector3(0, 1.75, 0), metal, yaw)
	box(ctx, Vector3(0.24, 0.2, 0.14), base + right * 0.4 + fwd * 0.1 + Vector3(0, 1.3, 0), Color(0.3, 0.55, 0.35), yaw)
	# Workbench.
	var bench := base + fwd * 0.45
	box(ctx, Vector3(1.4, 0.07, 0.6), bench + Vector3(0, 0.88, 0), wood.lightened(0.15), yaw, false)
	for sx: float in [-0.62, 0.62]:
		for sz: float in [-0.24, 0.24]:
			box(ctx, Vector3(0.07, 0.86, 0.07), bench + right * sx + fwd * sz + Vector3(0, 0.43, 0), wood, yaw)
	box(ctx, Vector3(1.3, 0.04, 0.5), bench + Vector3(0, 0.25, 0), wood, yaw)
	box(ctx, Vector3(0.14, 0.12, 0.12), bench + right * 0.5 + Vector3(0, 0.98, 0), metal.darkened(0.3), yaw)
	_collider(ctx, Vector3(1.4, 0.95, 0.62), bench + Vector3(0, 0.47, 0), yaw)
	item(ctx, "tool_rack", base + fwd * 0.3 + right * 0.35, yaw_deg, 1.0)
	item(ctx, "workbench", bench + fwd * 0.35 - right * 0.4, yaw_deg, 0.9)


static func tv_set(ctx: Dictionary, model: String, x: float, z: float, yaw_deg: float) -> InteriorItem:
	# v6b living_room module: a big flat LCD in every home.
	var lr := Modules.style("living_room") as LivingRoomStyle
	if lr and lr.lcd_width > 0.0:
		model = "televisionModern"
	var cab := furn(ctx, "cabinetTelevision", x, z, yaw_deg, "x", maxf(1.3, lr.lcd_width + 0.15) if lr else 1.3)
	var cab_h: float = (cab.get_meta(&"size") as Vector3).y if cab else 0.5
	var tv_w := 1.05 if model == "televisionModern" else 0.6
	if lr and lr.lcd_width > 0.0:
		tv_w = lr.lcd_width
	var tv := furn(ctx, model, x, z, yaw_deg, "x", tv_w, false, float(ctx["floor"]) + cab_h)
	var tv_size: Vector3 = tv.get_meta(&"size") if tv else Vector3(1, 0.6, 0.1)
	var it := item(ctx, "tv", Vector3(x, ctx["floor"], z), yaw_deg, 1.6)
	# Screen quad slightly in front of the TV face.
	var screen := Vector2(tv_size.x * 0.86, tv_size.y * 0.74) if model == "televisionModern" else Vector2(tv_size.x * 0.62, tv_size.y * 0.62)
	it.setup_screen(screen, Vector3(0.0 if model == "televisionModern" else -tv_size.x * 0.08, cab_h + tv_size.y * 0.52, tv_size.z * 0.5 + 0.012))
	return it


# ------------------------------------------------------------------ homes
static func _home(ctx: Dictionary, m: float, opt: Dictionary) -> void:
	# v4 house styles: the style's furniture choices win over the theme's.
	var bld := ctx["b"] as Building
	if bld and bld.house_style:
		opt = opt.duplicate()
		opt.merge(bld.house_style.furniture, true)
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var hw := w * 0.5
	var hd := d * 0.5
	var swap := bool(opt.get("swap", false))
	var bed_x := m * (-hw + 1.15) if not swap else m * (hw - 1.15)
	var kitchen_side := m * (1.0 if not swap else -1.0)
	# Bed against the back wall + nightstand.
	var double: bool = opt["bed"] == "bedDouble"
	furn_sized(ctx, opt["bed"], bed_x, -hd + 1.08, 0.0, Vector3(1.55 if double else 1.0, 0.62, 2.05))
	furn(ctx, "sideTable", bed_x + (1.0 if bed_x < 0 else -1.0) * (1.25 if double else 0.95), -hd + 0.3, 0.0, "y", 0.55)
	item(ctx, "bed", Vector3(bed_x, ctx["floor"], -hd + 1.1), 0.0, 1.5)
	# Kitchen along the back wall on the other side (v5a kitchen module:
	# fridge, stove, sink, cabinets, hood - KitchenBuilder).
	KitchenBuilder.build(ctx, kitchen_side, hw, hd)
	# Living area: TV on the side wall, sofa/armchair facing it, rug.
	var tv_x := -kitchen_side * (hw - 0.32)
	var tv_yaw := 90.0 if tv_x < 0.0 else -90.0
	tv_set(ctx, opt["tv"], tv_x, 0.55, tv_yaw)
	var sofa_x := tv_x + (2.05 if tv_x < 0.0 else -2.05)
	if Modules.style("living_room") != null:
		# v6b: the sofa is a movable piece (push it to another spot, remembered).
		InteriorV6b.sofa(ctx, opt["sofa"], sofa_x, 0.55, tv_yaw + 180.0, "sofa" if opt["sofa"] == "loungeSofa" else "armchair")
	else:
		furn(ctx, opt["sofa"], sofa_x, 0.55, tv_yaw + 180.0, "y", 0.85)
		seat(ctx, Vector3(sofa_x + (0.1 if tv_x < 0.0 else -0.1), 0, 0.55), tv_yaw + 180.0, "sofa" if opt["sofa"] == "loungeSofa" else "armchair")
	furn(ctx, opt["rug"], (tv_x + sofa_x) * 0.5, 0.55, 90.0, "x", 1.9, false, float(ctx["floor"]) + 0.004)
	# Dining table + two chairs.
	var tx := kitchen_side * (hw - 1.65)
	var tz := 0.45
	if opt["table"] == "tableRound":
		furn_sized(ctx, opt["table"], tx, tz, 0.0, Vector3(1.0, 0.76, 1.0))
	else:
		furn_sized(ctx, opt["table"], tx, tz, 0.0, Vector3(1.35, 0.76, 0.8))
	for side: float in [-1.0, 1.0]:
		var cz := tz + side * 0.7
		furn(ctx, "chairCushion", tx, cz, 0.0 if side < 0 else 180.0, "y", 0.92, false)
		seat(ctx, Vector3(tx, 0, cz - side * 0.05), 180.0 if side < 0 else 0.0, "chair").rotation.y = deg_to_rad(0.0 if side < 0 else 180.0)
	_power_fallback(ctx, tx, tz, kitchen_side, hw, hd)
	if opt["table"] == "tableCloth":
		furn(ctx, "cup-coffee", tx + 0.15, tz, 30.0, "x", 0.12, false, float(ctx["floor"]) + 0.77, _food_dir())
	# Tool rack + workbench on the front wall (inside), away from the door.
	tools_corner(ctx, kitchen_side * (hw - 1.2), hd - 0.05, 180.0, bool(opt.get("rustic", false)))
	# Extra piece in the front corner on the other side.
	var extra: String = opt.get("extra", "pottedPlant")
	furn(ctx, extra, -kitchen_side * (hw - 0.5), hd - 0.45, 180.0, "y", {"pottedPlant": 1.1, "lampRoundFloor": 1.6, "bookcaseOpen": 1.9, "bookcaseClosedWide": 1.8, "radio": 0.4}.get(extra, 1.0), extra != "radio")
	if extra == "radio":
		box(ctx, Vector3(0.6, 0.8, 0.45), Vector3(-kitchen_side * (hw - 0.5), float(ctx["floor"]) + 0.4, hd - 0.45), Color(0.42, 0.29, 0.18), 0.0, true)
	furn(ctx, "coatRackStanding", m * 0.95, hd - 0.35, 0.0, "y", 1.75, true)
	furn(ctx, "plantSmall1", bed_x + (1.0 if bed_x < 0 else -1.0) * (1.25 if double else 0.95), -hd + 0.3, 0.0, "y", 0.3, false, float(ctx["floor"]) + 0.56)
	# v6b: paintings, window blanket, farmhouse wardrobe + mirror.
	InteriorV6b.home_extras(ctx, {"kitchen_side": kitchen_side, "bed_x": bed_x, "tv_x": tv_x, "m": m})


## Electricity module: what a home uses when the power is cut - candles on
## the dining table, an oil lantern on the kitchen cabinet and a small
## fireplace on the kitchen-side wall. Flames + one warm light are hidden
## while the power is on (NightLights toggles the groups).
static func _power_fallback(ctx: Dictionary, tx: float, tz: float, kitchen_side: float, hw: float, hd: float) -> void:
	var st := Modules.style("power") as PowerStyle
	var root: Node3D = ctx["root"]
	var fl := float(ctx["floor"])
	var flames := Node3D.new()
	flames.name = "CandleFlames"
	flames.set_meta(&"no_merge", true)
	flames.add_to_group(&"candle_flames")
	flames.visible = false
	root.add_child(flames)
	var wax := Color(0.96, 0.93, 0.85)
	var n := st.candles_per_home if st else 3
	for i in n:
		var off := (i - (n - 1) * 0.5) * 0.16
		var p := Vector3(tx + off, fl + 0.77, tz + (0.08 if i % 2 == 0 else -0.08))
		box(ctx, Vector3(0.12, 0.02, 0.12), p + Vector3(0, 0.01, 0), Color(0.75, 0.65, 0.35))
		var h := 0.16 + 0.05 * (i % 2)
		_cyl_static(ctx, 0.022, h, p + Vector3(0, 0.02 + h * 0.5, 0), wax)
		_flame(flames, p + Vector3(0, 0.05 + h, 0), 0.022)
	if st == null or st.lantern:
		var lp := Vector3(kitchen_side * (hw - 0.45) - kitchen_side * 1.75, fl + 0.92, -hd + 0.42)
		box(ctx, Vector3(0.16, 0.03, 0.16), lp, Color(0.15, 0.15, 0.15))
		box(ctx, Vector3(0.03, 0.22, 0.03), lp + Vector3(0.065, 0.12, 0.065), Color(0.15, 0.15, 0.15))
		box(ctx, Vector3(0.03, 0.22, 0.03), lp + Vector3(-0.065, 0.12, -0.065), Color(0.15, 0.15, 0.15))
		box(ctx, Vector3(0.18, 0.04, 0.18), lp + Vector3(0, 0.25, 0), Color(0.15, 0.15, 0.15))
		_flame(flames, lp + Vector3(0, 0.1, 0), 0.03)
	if st == null or st.fireplace:
		var fx := kitchen_side * (hw - 0.22)
		var fz := tz
		var brick := Color(0.55, 0.3, 0.24)
		box(ctx, Vector3(0.44, 1.0, 1.1), Vector3(fx, fl + 0.5, fz), brick, 0.0, true)
		box(ctx, Vector3(0.5, 0.08, 1.24), Vector3(fx, fl + 1.02, fz), Color(0.42, 0.3, 0.2))
		box(ctx, Vector3(0.05, 0.5, 0.62), Vector3(fx - kitchen_side * 0.2, fl + 0.32, fz), Color(0.08, 0.06, 0.05))
		for k in 3:
			_cyl_static(ctx, 0.04, 0.5, Vector3(fx - kitchen_side * 0.27, fl + 0.1 + k * 0.04, fz - 0.15 + k * 0.15), Color(0.35, 0.22, 0.12), Vector3(PI * 0.5, 0, 0))
		for k in 3:
			_flame(flames, Vector3(fx - kitchen_side * 0.28, fl + 0.24, fz - 0.14 + k * 0.14), 0.07)
	var light := OmniLight3D.new()
	light.name = "CandleLight"
	light.position = Vector3(tx, fl + 1.3, tz)
	light.omni_range = maxf(hw, hd) * 2.0
	light.light_energy = 0.0
	light.shadow_enabled = false
	light.visible = false
	light.add_to_group(&"candle_lights")
	root.add_child(light)


static func _flame(parent: Node3D, pos: Vector3, r: float) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	mi.mesh = sm
	mi.scale = Vector3(1, 1.9, 1)
	mi.position = pos
	mi.material_override = PowerFx.flame_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


static func _cyl_static(ctx: Dictionary, r: float, h: float, pos: Vector3, color: Color, rot: Vector3 = Vector3.ZERO) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = 8
	cm.rings = 1
	mi.mesh = cm
	mi.position = pos
	mi.rotation = rot
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.7
	mi.material_override = m
	(ctx["static"] as Node3D).add_child(mi)


# ------------------------------------------------------------------ civic
static func _counter(ctx: Dictionary, z: float, width: float, color: Color) -> void:
	box(ctx, Vector3(width, 1.0, 0.6), Vector3(0, float(ctx["floor"]) + 0.5, z), color, 0.0, true)
	box(ctx, Vector3(width + 0.1, 0.06, 0.7), Vector3(0, float(ctx["floor"]) + 1.03, z), color.lightened(0.3))


static func _shelf(ctx: Dictionary, x: float, z: float, yaw: float, length: float, rng: RandomNumberGenerator) -> void:
	var base := float(ctx["floor"])
	box(ctx, Vector3(length, 1.7, 0.5), Vector3(x, base + 0.85, z), Color(0.6, 0.48, 0.34), yaw, true)
	var palette := [Color(0.9, 0.4, 0.3), Color(0.95, 0.8, 0.35), Color(0.4, 0.65, 0.9), Color(0.5, 0.8, 0.45), Color(0.95, 0.95, 0.9)]
	for level in 3:
		for i in int(length / 0.3):
			if rng.randf() < 0.25:
				continue
			var off := -length * 0.5 + 0.15 + i * 0.3
			var local := Vector3(off * cos(yaw), base + 0.35 + level * 0.55, -off * sin(yaw))
			var front := Vector3(sin(yaw), 0, cos(yaw)) * 0.27
			box(ctx, Vector3(0.22, 0.28, 0.16), Vector3(x, 0, z) + local + front, palette[rng.randi() % palette.size()], yaw)


static func _shop(ctx: Dictionary, big: bool) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var rng: RandomNumberGenerator = ctx["rng"]
	_counter(ctx, -d * 0.5 + 1.4, 2.6, Color(0.45, 0.3, 0.2))
	if big:
		# v5b: the supermarket counter sells cooking ingredients (grocery).
		var g := item(ctx, "shop_desk", Vector3(0, ctx["floor"], -d * 0.5 + 2.2), 0.0, 1.4)
		g.shop_id = "grocery"
	else:
		item(ctx, "shop_counter", Vector3(0, ctx["floor"], -d * 0.5 + 2.2), 0.0, 1.4)
	for sx: float in [-1.0, 1.0]:
		_shelf(ctx, sx * (w * 0.5 - 0.35), 0.0, sx * -PI * 0.5, d - 2.0, rng)
	if big:
		for sx: float in [-1.0, 1.0]:
			_shelf(ctx, sx * 1.8, 0.6, 0.0, 2.4, rng)
		furn(ctx, "kitchenFridgeLarge", -w * 0.5 + 1.4, -d * 0.5 + 0.35, 0.0, "y", 2.0)
		furn(ctx, "kitchenFridgeLarge", w * 0.5 - 1.4, -d * 0.5 + 0.35, 0.0, "y", 2.0)
	else:
		furn(ctx, "barrel", w * 0.5 - 1.2, d * 0.5 - 0.9, 0.0, "y", 0.85, true, -1.0, _food_dir())
		furn(ctx, "pumpkin", 1.5, d * 0.5 - 1.2, 20.0, "x", 0.45, false, -1.0, _food_dir())
	tv_set(ctx, "televisionModern", w * 0.5 - 0.32, -d * 0.5 + 2.2, -90.0)


static func _cafe(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	_counter(ctx, -d * 0.5 + 1.0, 2.8, Color(0.3, 0.2, 0.14))
	furn(ctx, "cup-coffee", -0.6, -d * 0.5 + 1.0, 0.0, "x", 0.14, false, float(ctx["floor"]) + 1.06, _food_dir())
	furn(ctx, "bread", 0.5, -d * 0.5 + 1.0, 0.0, "x", 0.3, false, float(ctx["floor"]) + 1.06, _food_dir())
	item(ctx, "coffee", Vector3(0, ctx["floor"], -d * 0.5 + 1.8), 0.0, 1.3)
	for p: Vector2 in [Vector2(-w * 0.5 + 1.3, 0.3), Vector2(w * 0.5 - 1.3, 0.3), Vector2(-w * 0.5 + 1.3, d * 0.5 - 1.3)]:
		var tp: Vector2 = p
		furn_sized(ctx, "tableRound", tp.x, tp.y, 0.0, Vector3(0.9, 0.76, 0.9))
		for side: float in [-1.0, 1.0]:
			furn(ctx, "chair", tp.x + side * 0.75, tp.y, side * -90.0, "y", 0.92, false)
			seat(ctx, Vector3(tp.x + side * 0.7, 0, tp.y), side * -90.0, "cafe chair").rotation.y = deg_to_rad(side * -90.0)
	tv_set(ctx, "televisionModern", w * 0.5 - 0.32, d * 0.5 - 1.5, -90.0)
	furn(ctx, "pottedPlant", w * 0.5 - 0.5, -d * 0.5 + 0.45, 0.0, "y", 1.1)


static func _office(ctx: Dictionary, police: bool) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	for i in 2:
		var x := -w * 0.25 + i * w * 0.5
		furn_sized(ctx, "desk", x, -d * 0.5 + 1.3, 180.0, Vector3(1.5, 0.76, 0.75))
		furn(ctx, "computerScreen", x, -d * 0.5 + 1.15, 180.0, "x", 0.55, false, float(ctx["floor"]) + 0.76)
		furn(ctx, "chairDesk", x, -d * 0.5 + 2.1, 0.0, "y", 1.0, false)
		item(ctx, "clerk", Vector3(x, ctx["floor"], -d * 0.5 + 2.3), 0.0, 1.0)
	for sx: float in [-1.0, 1.0]:
		furn(ctx, "bookcaseClosedWide", sx * (w * 0.5 - 0.35), 0.0, sx * -90.0, "y", 1.9)
	if police:
		# Holding cell bars in the back corner.
		for i in 7:
			box(ctx, Vector3(0.05, 2.2, 0.05), Vector3(w * 0.5 - 2.2 + i * 0.3, float(ctx["floor"]) + 1.1, d * 0.5 - 1.6), Color(0.35, 0.36, 0.4))
	else:
		# v5a: the town directory (population module) at the City Hall desk.
		item(ctx, "registry", Vector3(0.0, ctx["floor"], -d * 0.5 + 2.3), 0.0, 0.9)
		# Flag on a pole.
		box(ctx, Vector3(0.05, 2.2, 0.05), Vector3(-w * 0.5 + 0.6, float(ctx["floor"]) + 1.1, d * 0.5 - 0.6), Color(0.75, 0.65, 0.3))
		box(ctx, Vector3(0.8, 0.5, 0.02), Vector3(-w * 0.5 + 1.0, float(ctx["floor"]) + 1.9, d * 0.5 - 0.6), Color(0.2, 0.55, 0.3))
	for i in 3:
		furn(ctx, "chair", -1.0 + i * 1.0, d * 0.5 - 0.8, 180.0, "y", 0.92, false)
		seat(ctx, Vector3(-1.0 + i * 1.0, 0, d * 0.5 - 0.85), 180.0, "waiting chair").rotation.y = PI
	tv_set(ctx, "televisionModern", w * 0.5 - 0.32, -0.2, -90.0)


static func _post(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	_counter(ctx, -d * 0.5 + 1.3, 2.6, Color(0.3, 0.35, 0.55))
	item(ctx, "post_counter", Vector3(0, ctx["floor"], -d * 0.5 + 2.1), 0.0, 1.3)
	# Wall of PO boxes.
	for r in 4:
		for c in 6:
			box(ctx, Vector3(0.3, 0.26, 0.05), Vector3(-w * 0.5 + 0.05, float(ctx["floor"]) + 0.6 + r * 0.3, -1.0 + c * 0.34), Color(0.75, 0.62, 0.3), PI * 0.5)
	for i in 4:
		furn(ctx, "cardboardBoxClosed", w * 0.5 - 0.6, -d * 0.5 + 0.5 + i * 0.6, 0.0, "y", 0.45, i == 0)
	furn(ctx, "pottedPlant", w * 0.5 - 0.5, d * 0.5 - 0.5, 0.0, "y", 1.1)
	tv_set(ctx, "televisionVintage", w * 0.5 - 0.32, 0.4, -90.0)


static func _hospital(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	_counter(ctx, d * 0.5 - 1.8, 2.4, Color(0.85, 0.9, 0.92))
	item(ctx, "reception", Vector3(0, ctx["floor"], d * 0.5 - 1.0), 180.0, 1.4)
	# v5b: the doctor's desk (treats illnesses for a fee - Needs).
	furn_sized(ctx, "desk", w * 0.5 - 1.5, 0.4, -90.0, Vector3(1.3, 0.76, 0.7))
	_cyl_static(ctx, 0.04, 0.5, Vector3(w * 0.5 - 1.35, float(ctx["floor"]) + 1.05, 0.15), Color(0.9, 0.9, 0.95))
	var doc := item(ctx, "doctor", Vector3(w * 0.5 - 2.4, ctx["floor"], 0.4), -90.0, 1.5)
	doc.set_meta(&"desk", true)
	for i in 3:
		var x := -w * 0.5 + 1.4 + i * 2.6
		furn_sized(ctx, "bedSingle", x, -d * 0.5 + 1.1, 0.0, Vector3(1.0, 0.7, 2.0))
		box(ctx, Vector3(0.04, 1.8, 2.1), Vector3(x + 1.2, float(ctx["floor"]) + 0.9, -d * 0.5 + 1.1), Color(0.6, 0.8, 0.82))
	box(ctx, Vector3(0.6, 0.6, 0.06), Vector3(0, float(ctx["floor"]) + 2.2, d * 0.5 - 0.02), Color(0.85, 0.15, 0.15))
	for i in 3:
		furn(ctx, "chair", -w * 0.5 + 0.6, 0.6 + i * 0.6, 90.0, "y", 0.92, false)
		seat(ctx, Vector3(-w * 0.5 + 0.65, 0, 0.6 + i * 0.6), 90.0, "waiting chair").rotation.y = PI * 0.5
	tv_set(ctx, "televisionModern", w * 0.5 - 0.32, 0.8, -90.0)
	furn(ctx, "pottedPlant", w * 0.5 - 0.5, d * 0.5 - 0.5, 0.0, "y", 1.1)
