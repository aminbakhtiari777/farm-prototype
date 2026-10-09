class_name InteriorV6b
extends RefCounted
## v6b richer home interiors (modules living_room, wardrobe, fridge):
##   * a movable sofa (E "push the sofa" -> next spot along the room; the spot
##     is remembered per home in WorldMemory) with its seat,
##   * a folded blanket + floor cushion by the front window to sit on,
##   * framed paintings on the walls (procedural canvases),
##   * in the farmhouse: a wardrobe (clothes) with a mirror (character creator).
## The LCD TV is sized in InteriorBuilder._home (living_room.lcd_width).

static var _canvas_cache: Dictionary = {}


static func living() -> LivingRoomStyle:
	return Modules.style("living_room") as LivingRoomStyle


static func _bid(ctx: Dictionary) -> String:
	var b := ctx["b"] as Building
	return b.layout_id if b and b.layout_id != "" else str(b.name if b else "home")


static func _rng_for(ctx: Dictionary, salt: String) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = hash(_bid(ctx) + salt)
	return r


static func _mesh_box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


## Called at the end of InteriorBuilder._home.
static func home_extras(ctx: Dictionary, info: Dictionary) -> void:
	var st := living()
	if st == null:
		return
	var hw: float = float(ctx["w"]) * 0.5
	var hd: float = float(ctx["d"]) * 0.5
	var ks: float = info["kitchen_side"]
	var fl := float(ctx["floor"])
	var rng := _rng_for(ctx, "living")
	# Paintings: above the bed (back wall) and on the living-side wall, kept
	# clear of the windows (Building puts one on the back wall at -w*0.22 and
	# one mid-way along each side wall) and of the farmhouse wardrobe. Not on
	# the kitchen wall: the fridge door and the hood need that space.
	var b := ctx["b"] as Building
	var bw := b.size.x
	var is_farm := b.layout_id == "farmhouse"
	var bx := float(info["bed_x"])
	# Farmhouse wardrobe: on the back wall just past the end of the kitchen run
	# (KitchenBuilder: cabinets reach ks*(hw-3.43)), clear of the bed.
	var wx := ks * (hw - 3.45) - ks * 0.63
	var back_obst: Array = [Vector2(-bw * 0.22, 0.68)]
	if is_farm:
		back_obst.append(Vector2(wx, 0.62))
	var side_obst: Array = [Vector2(0.0, 0.68)]
	var pz := _clear_x(-(hd * 0.5 + 0.15), 0.42, side_obst, hd - 0.6)
	var spots: Array = [[Vector3(_clear_x(bx, 0.47, back_obst, hw - 0.6), fl + 1.72, -hd + 0.03), 0.0],
		[Vector3(-ks * (hw - 0.03), fl + 1.8, pz), ks * PI * 0.5]]
	for i in mini(st.paintings_per_home, spots.size()):
		if st.paintings.is_empty():
			break
		var pdef: Dictionary = st.paintings[(rng.randi() + i) % st.paintings.size()]
		painting(ctx, spots[i][0], spots[i][1], pdef, Vector2(0.9 - i * 0.12, 0.62 - i * 0.06))
	# Blanket + cushion under the front window on the living side.
	var bc: Color = st.blanket_colors[rng.randi() % st.blanket_colors.size()] if not st.blanket_colors.is_empty() else Color(0.7, 0.25, 0.2)
	blanket(ctx, Vector3(-ks * (hw - 1.65), fl, hd - 0.65), bc)
	if is_farm:
		wardrobe(ctx, Vector3(wx, fl, -hd + 0.33))


## Moves a centre coordinate along a wall until an item of half-width `half`
## clears every obstacle (Vector2(centre, half-width)), staying within +-lim.
static func _clear_x(x: float, half: float, obstacles: Array, lim: float) -> float:
	for _k in 4:
		var moved := false
		for o: Vector2 in obstacles:
			var gap := o.y + half + 0.08
			if absf(x - o.x) < gap:
				var dir := signf(x - o.x) if x != o.x else 1.0
				var nx := o.x + dir * (gap + 0.05)
				if absf(nx) > lim:
					nx = o.x - dir * (gap + 0.05)
				x = nx
				moved = true
		if not moved:
			break
	return clampf(x, -lim, lim)


static func _canvas_texture(pdef: Dictionary) -> Texture2D:
	var key := str(pdef.get("kind", "")) + str(pdef.get("colors", []))
	if _canvas_cache.has(key):
		return _canvas_cache[key]
	var cols: Array = pdef.get("colors", [Color.WHITE, Color.GRAY, Color.BLACK])
	var c0: Color = cols[0]
	var c1: Color = cols[1 % cols.size()]
	var c2: Color = cols[2 % cols.size()]
	var w := 64
	var h := 44
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	var kind := str(pdef.get("kind", "landscape"))
	for y in h:
		for x in w:
			var fx := float(x) / w
			var fy := float(y) / h
			var c := c0
			match kind:
				"landscape":
					var hill := 0.55 + 0.12 * sin(fx * 7.0) + 0.06 * sin(fx * 17.0 + 1.0)
					c = c0.lerp(c0.lightened(0.4), fy) if fy < hill else c1.darkened(0.2 * (fy - hill) * 3.0)
					if fy > hill and fx > 0.62 and fx < 0.7 and fy < hill + 0.2:
						c = c2
				"sunset":
					c = c0.lerp(c1, fy * 1.4)
					if Vector2(fx - 0.5, (fy - 0.62) * 1.4).length() < 0.12:
						c = c0.lightened(0.45)
					if fy > 0.75:
						c = c2.lerp(c0.darkened(0.6), sin(fx * 40.0) * 0.1 + 0.2)
				"sea":
					c = c1.lerp(c0, fy * 1.6) if fy < 0.55 else c0.darkened(0.15 + 0.05 * sin(fx * 30.0 + fy * 20.0))
					if fy > 0.82:
						c = c2
				"geometric":
					var cell := (int(fx * 6.0) + int(fy * 4.0)) % 3
					c = [c0, c1, c2][cell]
					if absf(fx - 0.5) + absf(fy - 0.5) < 0.22:
						c = c1.lightened(0.3)
				"flowers":
					c = c0
					for k in 7:
						var cx := 0.12 + k * 0.13
						var cy := 0.35 + 0.12 * sin(k * 2.1)
						if Vector2(fx - cx, (fy - cy) * 0.7).length() < 0.05:
							c = c1
						elif absf(fx - cx) < 0.008 and fy > cy:
							c = c2
			img.set_pixel(x, y, c)
	var tex := ImageTexture.create_from_image(img)
	_canvas_cache[key] = tex
	return tex


static func painting(ctx: Dictionary, pos: Vector3, yaw: float, pdef: Dictionary, size: Vector2) -> Node3D:
	var root: Node3D = ctx["root"]
	var holder := Node3D.new()
	holder.name = "Painting"
	holder.add_to_group(&"paintings")
	holder.position = pos
	holder.rotation.y = yaw
	root.add_child(holder)
	var frame := ProceduralProp.color_material(Color(0.42, 0.28, 0.14), 0.6, false)
	var fh := Node3D.new()
	fh.position = pos
	fh.rotation.y = yaw
	(ctx["static"] as Node3D).add_child(fh)
	_mesh_box(fh, Vector3(size.x + 0.08, size.y + 0.08, 0.035), Vector3(0, 0, 0.018), frame)
	var canvas := StandardMaterial3D.new()
	canvas.albedo_texture = _canvas_texture(pdef)
	canvas.roughness = 0.8
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	q.mesh = qm
	q.material_override = canvas
	q.position = Vector3(0, 0, 0.037)
	holder.add_child(q)
	return holder


static func blanket(ctx: Dictionary, pos: Vector3, color: Color) -> void:
	var root: Node3D = ctx["root"]
	var holder := Node3D.new()
	holder.name = "WindowBlanket"
	holder.position = pos
	(ctx["static"] as Node3D).add_child(holder)
	var cloth := ProceduralProp.color_material(color, 0.95)
	var stripe := ProceduralProp.color_material(color.lightened(0.35), 0.95)
	# Spread blanket (slightly rumpled: two layers) + a folded throw + a cushion.
	_mesh_box(holder, Vector3(1.1, 0.025, 0.8), Vector3(0, 0.013, 0), cloth)
	_mesh_box(holder, Vector3(1.1, 0.027, 0.07), Vector3(0, 0.014, 0.26), stripe)
	_mesh_box(holder, Vector3(1.1, 0.027, 0.07), Vector3(0, 0.014, -0.26), stripe)
	_mesh_box(holder, Vector3(0.45, 0.09, 0.3), Vector3(0.3, 0.07, 0.16), stripe)
	var cushion := _mesh_box(holder, Vector3(0.42, 0.16, 0.38), Vector3(-0.18, 0.09, 0.18), ProceduralProp.color_material(color.darkened(0.25), 0.9))
	cushion.rotation.y = 0.2
	var s := Seat.new()
	s.name = "BlanketSeat"
	s.display_name = "blanket"
	s.interact_radius = 0.8
	s.position = pos + Vector3(-0.1, 0.0, -0.05)
	s.rotation.y = PI  # face the room (window behind)
	s.set_meta(&"pose", &"ground_sit")
	s.add_to_group(&"window_blankets")
	root.add_child(s)


## Movable sofa: a separate (non-merged) node with its own collider + seat.
static func sofa(ctx: Dictionary, model: String, x: float, z: float, yaw_deg: float, seat_label: String) -> Node3D:
	var st := living()
	var root: Node3D = ctx["root"]
	var b := ctx["b"] as Building
	var holder := MovableSofa.new()
	holder.name = "MovableSofa"
	holder.key = "sofa:" + _bid(ctx)
	holder.base = Vector3(x, float(ctx["floor"]), z)
	holder.yaw = deg_to_rad(yaw_deg)
	holder.slots = st.sofa_slots if st and not st.sofa_slots.is_empty() else [0.0]
	holder.building = b
	root.add_child(holder)
	# Visual: the Kenney sofa scaled like InteriorBuilder.furn (height 0.85).
	var path := InteriorBuilder._furniture_dir() + model + ".glb"
	if ResourceLoader.exists(path):
		var inst := InteriorBuilder._scene(path).instantiate() as Node3D
		var bounds := InteriorBuilder._aabb(inst)
		var sc := 0.85 / maxf(bounds.size.y, 0.001)
		inst.scale = Vector3.ONE * sc
		var c := bounds.get_center()
		inst.position = Vector3(-c.x * sc, -bounds.position.y * sc, -c.z * sc)
		inst.rotation.y = 0.0
		var pivot := Node3D.new()
		pivot.name = "SofaModel"
		pivot.rotation.y = holder.yaw
		pivot.add_child(inst)
		holder.add_child(pivot)
		holder.size = bounds.size * sc
	var seat := Seat.new()
	seat.display_name = seat_label
	seat.interact_radius = 0.9
	seat.position = Vector3((0.1 if x < 0.0 else -0.1), 0.0, 0.0)
	seat.rotation.y = holder.yaw
	holder.add_child(seat)
	holder.seat = seat
	return holder


## Farmhouse wardrobe (clothes) with a mirror on its side (character creator).
static func wardrobe(ctx: Dictionary, pos: Vector3) -> void:
	var root: Node3D = ctx["root"]
	var ws := Modules.style("wardrobe") as WardrobeStyle
	var wood := ProceduralProp.color_material(ws.cabinet_color if ws else Color(0.5, 0.34, 0.2), 0.7)
	var dark := ProceduralProp.color_material((ws.cabinet_color if ws else Color(0.5, 0.34, 0.2)).darkened(0.35), 0.7)
	var holder := Node3D.new()
	holder.name = "Wardrobe"
	holder.position = pos
	(ctx["static"] as Node3D).add_child(holder)
	var marker := Node3D.new()
	marker.name = "WardrobeMarker"
	marker.position = pos
	marker.add_to_group(&"wardrobes")
	root.add_child(marker)
	# Body on little feet, crown moulding, two panelled doors with brass
	# handles; the right door carries a full-length mirror.
	var light := ProceduralProp.color_material((ws.cabinet_color if ws else Color(0.5, 0.34, 0.2)).lightened(0.18), 0.6)
	_mesh_box(holder, Vector3(1.1, 1.92, 0.55), Vector3(0, 1.04, 0), wood)
	for fx: float in [-0.48, 0.48]:
		_mesh_box(holder, Vector3(0.08, 0.08, 0.5), Vector3(fx, 0.04, 0), dark)
	_mesh_box(holder, Vector3(1.2, 0.08, 0.62), Vector3(0, 2.03, 0.02), dark)
	_mesh_box(holder, Vector3(1.14, 0.05, 0.58), Vector3(0, 0.1, 0.01), dark)
	for dx: float in [-0.275, 0.275]:
		_mesh_box(holder, Vector3(0.5, 1.74, 0.02), Vector3(dx, 1.04, 0.285), light)
		_mesh_box(holder, Vector3(0.38, 0.6, 0.012), Vector3(dx, 1.45, 0.297), wood)
		_mesh_box(holder, Vector3(0.38, 0.6, 0.012), Vector3(dx, 0.62, 0.297), wood)
	_mesh_box(holder, Vector3(0.015, 1.74, 0.03), Vector3(0, 1.04, 0.29), dark)
	for sx: float in [-0.06, 0.06]:
		_mesh_box(holder, Vector3(0.025, 0.22, 0.035), Vector3(sx, 1.08, 0.31), ProceduralProp.color_material(Color(0.85, 0.7, 0.35), 0.3, false))
	# Mirror (unmerged so it keeps its sheen).
	var mirror := StandardMaterial3D.new()
	mirror.albedo_color = Color(0.75, 0.82, 0.88)
	mirror.metallic = 0.9
	mirror.roughness = 0.05
	var side := 1.0 if pos.x < 0.0 else -1.0
	var mm := _mesh_box(holder, Vector3(0.34, 1.3, 0.01), Vector3(0.275, 1.1, 0.307), mirror)
	mm.set_meta(&"no_merge", true)
	var b := ctx["b"] as Building
	b.add_box_collider(Vector3(1.15, 2.05, 0.6), holder.position + Vector3(0, 1.02, 0))
	var clothes := ActionSpot.make(root, pos + Vector3(-side * 0.15, 0, 0.75), 0.7,
		func() -> String: return Lang.tt("عوض کردن لباس (کمد)", "change clothes at the wardrobe"),
		func(_who: Node3D) -> void:
			var p := root.get_tree().get_first_node_in_group(&"wardrobe_panel") as WardrobePanel
			if p:
				p.open())
	clothes.name = "WardrobeSpot"
	var look := ActionSpot.make(root, pos + Vector3(side * 0.8, 0, 0.35), 0.6,
		func() -> String: return Lang.tt("نگاه در آینه (ظاهر شخصیت)", "look in the mirror (change your look)"),
		func(_who: Node3D) -> void:
			var p2 := root.get_tree().get_first_node_in_group(&"character_creator") as CharacterCreator
			if p2:
				p2.open())
	look.name = "MirrorSpot"


# ------------------------------------------------------------------ gym (v6b)
## Fuller gym ("gym" module, GymStyle.extras): a full-width mirror wall, a
## kettlebell shelf, a squat rack, a rowing machine, exercise balls and a
## water cooler. Positions avoid the v6a equipment and the door.
static func gym_extras(ctx: Dictionary) -> void:
	var gs := Modules.style("gym") as GymStyle
	if gs == null or not ("extras" in gs):
		return
	var ex: PackedStringArray = gs.extras
	var w: float = ctx["w"]
	var d: float = ctx["d"]
	var fl := InteriorV6a._fl(ctx)
	var hw := w * 0.5
	var hd := d * 0.5
	var dark := Color(0.12, 0.12, 0.14)
	var steel := Color(0.7, 0.72, 0.75)
	var accent := gs.accent
	var root: Node3D = ctx["root"]
	if "mirror_wall" in ex:
		# Silvered panels with thin seams, almost wall to wall, unmerged so the
		# slightly metallic material keeps its sheen.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.78, 0.85, 0.9)
		mat.metallic = 0.85
		mat.roughness = 0.08
		var mw := w - 0.6
		var m := _mesh_box(root, Vector3(mw, 1.9, 0.02), Vector3(0, fl + 1.2, -hd + 0.11), mat)
		m.name = "MirrorWall"
		m.add_to_group(&"gym_mirror")
		var panels := int(mw / 1.2)
		for i in range(1, panels):
			InteriorBuilder.box(ctx, Vector3(0.02, 1.9, 0.025), Vector3(-mw * 0.5 + i * mw / panels, fl + 1.2, -hd + 0.125), Color(0.3, 0.32, 0.35))
		InteriorBuilder.box(ctx, Vector3(mw + 0.08, 0.06, 0.06), Vector3(0, fl + 2.18, -hd + 0.12), accent)
		InteriorBuilder.box(ctx, Vector3(mw + 0.08, 0.06, 0.06), Vector3(0, fl + 0.22, -hd + 0.12), dark)
	if "kettlebells" in ex:
		var x := -hw + 0.3
		var z := -hd + 1.0
		InteriorBuilder.box(ctx, Vector3(0.45, 0.05, 1.3), Vector3(x, fl + 0.35, z), dark, 0.0, true)
		InteriorBuilder.box(ctx, Vector3(0.45, 0.05, 1.3), Vector3(x, fl + 0.8, z), dark)
		for sz: float in [-0.62, 0.62]:
			InteriorBuilder.box(ctx, Vector3(0.45, 0.85, 0.05), Vector3(x, fl + 0.42, z + sz), steel)
		for row in 2:
			for k in 4:
				var r := 0.08 + k * 0.012 + row * 0.01
				var p := Vector3(x, fl + 0.38 + row * 0.45 + r, z - 0.45 + k * 0.3)
				var ball := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = r
				sm.height = r * 2.0
				sm.radial_segments = 10
				sm.rings = 6
				ball.mesh = sm
				ball.position = p
				var km := StandardMaterial3D.new()
				km.albedo_color = Color(0.1, 0.1, 0.11) if (k + row) % 2 == 0 else accent.darkened(0.2)
				km.roughness = 0.5
				ball.material_override = km
				ctx["static"].add_child(ball)
				InteriorBuilder.box(ctx, Vector3(0.03, r * 0.9, r * 1.4), p + Vector3(0, r * 1.05, 0), dark)
	if "squat_rack" in ex:
		var c := Vector3(1.3, fl, -hd + 0.85)
		for sx: float in [-0.6, 0.6]:
			for sz: float in [-0.4, 0.4]:
				InteriorBuilder.box(ctx, Vector3(0.07, 2.1, 0.07), c + Vector3(sx, 1.05, sz), steel)
			InteriorBuilder.box(ctx, Vector3(0.07, 0.07, 0.87), c + Vector3(sx, 2.1, 0), steel)
		InteriorBuilder.box(ctx, Vector3(1.27, 0.07, 0.07), c + Vector3(0, 2.1, -0.4), steel)
		InteriorBuilder.box(ctx, Vector3(1.3, 0.05, 0.9), c + Vector3(0, 0.025, 0), Color(0.2, 0.2, 0.22), 0.0, true)
		InteriorBuilder._cyl_static(ctx, 0.022, 1.9, c + Vector3(0, 1.4, 0.4), steel, Vector3(0, 0, PI * 0.5))
		for sx: float in [-0.82, 0.82]:
			InteriorBuilder._cyl_static(ctx, 0.22, 0.07, c + Vector3(sx, 1.4, 0.4), dark, Vector3(0, 0, PI * 0.5))
	if "rower" in ex:
		var c := Vector3(-2.0, fl, hd - 0.85)
		InteriorBuilder.box(ctx, Vector3(1.9, 0.08, 0.16), c + Vector3(0, 0.3, 0), steel, 0.0, true)
		InteriorBuilder.box(ctx, Vector3(0.08, 0.3, 0.3), c + Vector3(-0.9, 0.15, 0), dark)
		InteriorBuilder.box(ctx, Vector3(0.08, 0.3, 0.3), c + Vector3(0.85, 0.15, 0), dark)
		InteriorBuilder._cyl_static(ctx, 0.24, 0.2, c + Vector3(0.82, 0.42, 0), accent, Vector3(PI * 0.5, 0, 0))
		InteriorBuilder.box(ctx, Vector3(0.32, 0.07, 0.32), c + Vector3(-0.2, 0.37, 0), Color(0.08, 0.08, 0.09))
		InteriorBuilder.box(ctx, Vector3(0.14, 0.04, 0.5), c + Vector3(0.45, 0.42, 0), dark)
	if "balls" in ex:
		var cols := [accent, Color(0.25, 0.5, 0.85), Color(0.4, 0.75, 0.45)]
		for i in 3:
			var r := 0.3 - i * 0.03
			var p := Vector3(-hw + 0.45, fl + r, 0.95 + i * 0.62)
			var ball := MeshInstance3D.new()
			var sm := SphereMesh.new()
			sm.radius = r
			sm.height = r * 2.0
			ball.mesh = sm
			ball.position = p
			var bm := StandardMaterial3D.new()
			bm.albedo_color = cols[i]
			bm.roughness = 0.35
			ball.material_override = bm
			ctx["static"].add_child(ball)
	if "water" in ex:
		var c := Vector3(hw - 0.35, fl, -0.25)
		InteriorBuilder.box(ctx, Vector3(0.36, 1.0, 0.36), c + Vector3(0, 0.5, 0), Color(0.92, 0.93, 0.95), 0.0, true)
		InteriorBuilder._cyl_static(ctx, 0.15, 0.45, c + Vector3(0, 1.23, 0), Color(0.45, 0.7, 0.95))
		InteriorBuilder.box(ctx, Vector3(0.06, 0.05, 0.05), c + Vector3(-0.2, 0.72, 0), Color(0.2, 0.4, 0.85))
		InteriorBuilder.box(ctx, Vector3(0.12, 0.02, 0.12), c + Vector3(-0.22, 0.5, 0), Color(0.6, 0.62, 0.65))
