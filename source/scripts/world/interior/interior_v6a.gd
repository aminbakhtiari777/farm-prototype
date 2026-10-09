class_name InteriorV6a
extends RefCounted
## v6a interiors: the town gym (gym module: equipment stations as Seats with
## workout poses + a reception desk) and the hypermarket (hypermarket module:
## kitchenware on display + the counter that opens its shop).


static func _fl(ctx: Dictionary) -> float:
	return float(ctx["floor"])


# ------------------------------------------------------------------ gym
static func gym(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	var gs := Modules.style("gym") as GymStyle
	var accent := gs.accent if gs else Color(0.95, 0.45, 0.1)
	# Rubber floor, wall mirror, posters, reception desk.
	InteriorBuilder.box(ctx, Vector3(w - 0.2, 0.02, d - 0.2), Vector3(0, fl + 0.01, 0), gs.floor_color if gs else Color(0.25, 0.27, 0.3))
	InteriorBuilder.box(ctx, Vector3(w * 0.6, 1.5, 0.04), Vector3(0, fl + 1.3, -d * 0.5 + 0.06), Color(0.72, 0.82, 0.88))
	InteriorBuilder.box(ctx, Vector3(w * 0.62, 0.06, 0.06), Vector3(0, fl + 2.08, -d * 0.5 + 0.07), accent)
	InteriorBuilder.box(ctx, Vector3(0.04, 0.9, 0.7), Vector3(-w * 0.5 + 0.06, fl + 1.6, -d * 0.25), accent.lightened(0.2))
	InteriorBuilder.box(ctx, Vector3(1.6, 1.0, 0.55), Vector3(w * 0.5 - 1.2, fl + 0.5, d * 0.5 - 1.1), Color(0.3, 0.32, 0.36), 0.0, true)
	InteriorBuilder.box(ctx, Vector3(1.7, 0.05, 0.62), Vector3(w * 0.5 - 1.2, fl + 1.02, d * 0.5 - 1.1), accent)
	InteriorBuilder.item(ctx, "v6_gym_desk", Vector3(w * 0.5 - 1.2, fl, d * 0.5 - 1.75), 180.0, 1.1)
	if gs == null:
		return
	var hx := w * 0.5 - 1.0
	var hz := d * 0.5 - 1.0
	for e in gs.equipment:
		var eq := e as Dictionary
		var p: Vector2 = eq.get("pos", Vector2.ZERO)
		var pos := Vector3(p.x * hx, fl, p.y * hz)
		var yaw := float(eq.get("yaw", 0.0))
		_equipment(ctx, str(eq.get("id", "")), pos, yaw, accent)
		var s := InteriorBuilder.seat(ctx, pos, yaw, "gym")
		var pose := str(eq.get("pose", "sit"))
		s.set_meta(&"pose", StringName(pose))
		s.set_meta(&"equipment", eq)
		s.set_meta(&"special", true)
		s.interact_radius = 0.95
		s.add_to_group(&"gym_stations")
		match pose:
			"jog":
				s.position.y = fl + 0.16
			"lie":
				s.position.y = fl + 0.32
			"ground_sit":
				s.position.y = fl + 0.02
		s.ready.connect(func() -> void:
			var fee := gs.fee
			var en := "%s (%d G)" % [str(eq.get("en", "work out")), fee] if fee > 0 else str(eq.get("en", "work out"))
			var fa := "%s (%s سکه)" % [str(eq.get("fa", "ورزش")), Lang.digits(str(fee))] if fee > 0 else str(eq.get("fa", "ورزش"))
			s.zone.action_text = en
			s.zone.set_meta(&"text_fa", fa), CONNECT_ONE_SHOT)
		s.used.connect(func(who: Node3D) -> void: Gym.workout(who, eq))
	InteriorV6b.gym_extras(ctx)  # v6b: mirror wall, kettlebells, squat rack, rower, balls, water


static func _equipment(ctx: Dictionary, id: String, pos: Vector3, yaw_deg: float, accent: Color) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var basis := Basis(Vector3.UP, yaw)
	var dark := Color(0.12, 0.12, 0.14)
	var steel := Color(0.7, 0.72, 0.75)
	var at := func(local: Vector3) -> Vector3: return pos + basis * local
	match id:
		"treadmill", "treadmill2":
			InteriorBuilder.box(ctx, Vector3(0.8, 0.14, 1.8), at.call(Vector3(0, 0.07, 0)), dark, yaw, true)
			InteriorBuilder.box(ctx, Vector3(0.6, 0.02, 1.6), at.call(Vector3(0, 0.15, 0)), Color(0.2, 0.2, 0.22), yaw)
			for sx: float in [-0.36, 0.36]:
				InteriorBuilder.box(ctx, Vector3(0.05, 1.1, 0.05), at.call(Vector3(sx, 0.6, 0.85)), steel, yaw)
			InteriorBuilder.box(ctx, Vector3(0.8, 0.3, 0.12), at.call(Vector3(0, 1.2, 0.85)), accent, yaw)
			InteriorBuilder.box(ctx, Vector3(0.5, 0.16, 0.02), at.call(Vector3(0, 1.22, 0.78)), Color(0.15, 0.35, 0.45), yaw)
		"dumbbells":
			InteriorBuilder.box(ctx, Vector3(1.4, 0.7, 0.45), at.call(Vector3(0, 0.35, 0.75)), dark, yaw, true)
			for k in 5:
				var x := -0.55 + k * 0.27
				InteriorBuilder._cyl_static(ctx, 0.06 + k * 0.008, 0.3, at.call(Vector3(x, 0.78, 0.75)), steel.darkened(0.1 * k), Vector3(0, yaw, PI * 0.5))
		"bench_press":
			InteriorBuilder.box(ctx, Vector3(0.38, 0.4, 1.3), at.call(Vector3(0, 0.2, -0.55)), Color(0.15, 0.15, 0.17), yaw, true)
			InteriorBuilder.box(ctx, Vector3(0.36, 0.06, 1.28), at.call(Vector3(0, 0.43, -0.55)), accent.darkened(0.3), yaw)
			for sx: float in [-0.45, 0.45]:
				InteriorBuilder.box(ctx, Vector3(0.06, 1.2, 0.06), at.call(Vector3(sx, 0.6, -1.05)), steel, yaw)
			InteriorBuilder._cyl_static(ctx, 0.02, 1.7, at.call(Vector3(0, 1.15, -1.05)), steel, Vector3(0, yaw, PI * 0.5))
			for sx: float in [-0.75, 0.75]:
				InteriorBuilder._cyl_static(ctx, 0.2, 0.08, at.call(Vector3(sx, 1.15, -1.05)), dark, Vector3(0, yaw, PI * 0.5))
		"bike":
			InteriorBuilder.box(ctx, Vector3(0.3, 0.1, 1.1), at.call(Vector3(0, 0.05, 0.05)), dark, yaw, true)
			InteriorBuilder.box(ctx, Vector3(0.08, 0.5, 0.08), at.call(Vector3(0, 0.25, -0.15)), steel, yaw)
			InteriorBuilder.box(ctx, Vector3(0.3, 0.06, 0.25), at.call(Vector3(0, 0.47, -0.15)), Color(0.1, 0.1, 0.1), yaw)
			InteriorBuilder.box(ctx, Vector3(0.08, 1.0, 0.08), at.call(Vector3(0, 0.55, 0.5)), steel, yaw)
			InteriorBuilder.box(ctx, Vector3(0.5, 0.05, 0.05), at.call(Vector3(0, 1.05, 0.5)), dark, yaw)
			InteriorBuilder._cyl_static(ctx, 0.22, 0.08, at.call(Vector3(0, 0.3, 0.38)), accent, Vector3(0, yaw, PI * 0.5))
		"mat":
			InteriorBuilder.box(ctx, Vector3(0.75, 0.02, 1.8), at.call(Vector3(0, 0.01, -0.2)), accent.lightened(0.15), yaw)


# ------------------------------------------------------------------ hypermarket
static func hypermarket(ctx: Dictionary) -> void:
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := _fl(ctx)
	var rng: RandomNumberGenerator = ctx["rng"]
	var hs := Modules.style("hypermarket") as HypermarketStyle
	var sign_col := hs.sign_color if hs else Color(0.1, 0.45, 0.75)
	var shelf_col := hs.shelf_color if hs else Color(0.85, 0.86, 0.88)
	# Counter + shop desk at the back.
	InteriorBuilder._counter(ctx, -d * 0.5 + 1.3, 2.6, sign_col.darkened(0.2))
	var it := InteriorBuilder.item(ctx, "shop_desk", Vector3(0, fl, -d * 0.5 + 2.1), 0.0, 1.4)
	it.shop_id = "hypermarket"
	InteriorBuilder.box(ctx, Vector3(w * 0.7, 0.4, 0.04), Vector3(0, fl + 2.5, -d * 0.5 + 0.06), sign_col)
	# Grocery shelves on the left wall.
	InteriorBuilder._shelf(ctx, -(w * 0.5 - 0.35), 0.3, PI * 0.5, d - 2.4, rng)
	# Kitchenware display: two white shelving units (right wall + middle island).
	var defs := Kitchenware.defs()
	var units := [[w * 0.5 - 0.35, 0.3, -PI * 0.5, d - 2.4], [0.2, 0.9, 0.0, 3.2]]
	var slots: Array = []
	for u in units:
		var x: float = u[0]
		var z: float = u[1]
		var yaw: float = u[2]
		var length: float = u[3]
		InteriorBuilder.box(ctx, Vector3(length, 1.6, 0.5), Vector3(x, fl + 0.8, z), shelf_col, yaw, true)
		for level in 3:
			for i in int(length / 0.75):
				var off := -length * 0.5 + 0.4 + i * 0.75
				var local := Vector3(off * cos(yaw), fl + 0.42 + level * 0.52, -off * sin(yaw))
				var front := Vector3(sin(yaw), 0, cos(yaw)) * 0.27
				slots.append([Vector3(x, 0, z) + local + front, yaw])
	for i in slots.size():
		var dfn: KitchenwareDef = defs[i % defs.size()] if not defs.is_empty() else null
		if dfn == null:
			break
		_ware(ctx, dfn, slots[i][0], slots[i][1])
	# Price tags for each product (first copy).
	for i in mini(defs.size(), slots.size()):
		var dfn: KitchenwareDef = defs[i]
		var lbl := Label3D.new()
		Lang.setup_label3d(lbl)
		lbl.text = "%s\n%s" % [dfn.name_fa if dfn.name_fa != "" else dfn.display_name, Lang.digits(str(dfn.price))]
		lbl.font_size = 26
		lbl.pixel_size = 0.0035
		var sp: Vector3 = slots[i][0]
		var yaw: float = slots[i][1]
		lbl.position = sp + Vector3(sin(yaw), 0, cos(yaw)) * 0.06 + Vector3(0, -0.1, 0)
		lbl.rotation.y = yaw
		lbl.modulate = Color(0.1, 0.1, 0.12)
		lbl.outline_size = 0
		lbl.visibility_range_end = 9.0
		(ctx["root"] as Node3D).add_child(lbl)


static func _ware(ctx: Dictionary, dfn: KitchenwareDef, p: Vector3, yaw: float) -> void:
	var c := dfn.color
	match dfn.shape:
		"plate":
			for k in 4:
				InteriorBuilder._cyl_static(ctx, 0.13, 0.015, p + Vector3(0, 0.01 + k * 0.018, 0), c)
		"pot":
			InteriorBuilder._cyl_static(ctx, 0.14, 0.18, p + Vector3(0, 0.09, 0), c)
			InteriorBuilder._cyl_static(ctx, 0.15, 0.02, p + Vector3(0, 0.19, 0), c.darkened(0.2))
		"pan":
			InteriorBuilder._cyl_static(ctx, 0.14, 0.04, p + Vector3(0, 0.02, 0), c)
			InteriorBuilder.box(ctx, Vector3(0.04, 0.025, 0.22), p + Basis(Vector3.UP, yaw) * Vector3(0.2, 0.03, 0.0) , c.darkened(0.3), yaw + PI * 0.5)
		"fork":
			for k in 5:
				InteriorBuilder.box(ctx, Vector3(0.02, 0.01, 0.2), p + Basis(Vector3.UP, yaw) * Vector3(-0.1 + k * 0.05, 0.01, 0), Color(0.82, 0.83, 0.85), yaw)
		"glass":
			for k in 3:
				InteriorBuilder._cyl_static(ctx, 0.04, 0.12, p + Basis(Vector3.UP, yaw) * Vector3(-0.1 + k * 0.1, 0.06, 0), c)
		"blender":
			InteriorBuilder.box(ctx, Vector3(0.16, 0.12, 0.16), p + Vector3(0, 0.06, 0), Color(0.2, 0.2, 0.22), yaw)
			InteriorBuilder._cyl_static(ctx, 0.07, 0.22, p + Vector3(0, 0.23, 0), c)
		"microwave":
			InteriorBuilder.box(ctx, Vector3(0.46, 0.28, 0.34), p + Vector3(0, 0.14, 0), c, yaw)
			InteriorBuilder.box(ctx, Vector3(0.28, 0.2, 0.01), p + Basis(Vector3.UP, yaw) * Vector3(-0.05, 0.14, 0.17), Color(0.1, 0.12, 0.14), yaw)
		_:
			InteriorBuilder.box(ctx, Vector3(0.2, 0.2, 0.2), p + Vector3(0, 0.1, 0), c, yaw)


# ------------------------------------------------------------------ v6_ interior items
static func item_text(it: InteriorItem) -> String:
	match it.kind:
		"v6_gym_desk":
			return Lang.tt("پذیرش باشگاه (آمادگی بدنی‌ات را ببین)", "gym reception (check your fitness)")
	return "use"


static func item_use(it: InteriorItem, _who: Node3D) -> void:
	match it.kind:
		"v6_gym_desk":
			var pct := int(round(Lifestyle.fitness_ratio() * 100.0))
			GameEvents.notification_requested.emit(Lang.tt(
				"آمادگی بدنی: %s٪ - انرژی بیشتر: +%s، احتمال بیماری کمتر. هر روز ورزش کن!" % [Lang.digits(str(pct)), Lang.digits(str(int(Lifestyle.stamina_bonus())))],
				"Fitness: %d%% - max stamina +%d, less illness. Train every day!" % [pct, int(Lifestyle.stamina_bonus())]))
