class_name CarBody
extends RefCounted
## v7b.1 "car_bodies" module: self-made procedural car bodies that replace the
## Kenney car models (all of which shared one colormap texture whose coral body
## texels read pink, and the fire truck was a white van under a 78 % alpha red
## overlay = pink). Every car gets an opaque paint from the module palette
## (white, silver, black, dark blue, red, beige...) or a fixed livery (police,
## ambulance, taxi, fire truck), see-through glass, a real interior (seats,
## dashboard with gauges, rear-view mirror, steering wheel that turns with
## DrivableCar.steer_amount), tyres with rims, side mirrors, a grille,
## headlights, bumpers, hood lines and Persian-style number plates.
## Local space: +Z forward, +X = the driver's (left) side, wheels on y = 0.
## Static parts are merged into one mesh per material (few draw calls); the
## wheels, steering wheel, roof (group "car_roof") and plates stay separate.

const KINDS := ["sedan", "hatch", "suv", "van", "delivery", "police", "taxi", "ambulance", "firetruck", "pickup"]
static var _count: Dictionary = {}  ## kind -> cars built (deterministic colour order)
static var _mats: Dictionary = {}


## Tests: restart the deterministic colour / shape sequence.
static func reset_counts() -> void:
	_count.clear()


static func style() -> CarBodyStyle:
	return Modules.style("car_bodies") as CarBodyStyle


static func handles(model_name: String) -> bool:
	var st := style()
	return st != null and st.enabled and st.shapes.has(model_name)


## Same contract as VehicleKit.model(): [holder "Model", size (W, H, L)] or [].
static func build(model_name: String, length: float = -1.0, paint_index: int = -1) -> Array:
	var st := style()
	if st == null or not st.enabled or not st.shapes.has(model_name):
		return []
	var shp: Dictionary = st.shapes[model_name]
	var n := int(_count.get(model_name, 0))
	_count[model_name] = n + 1
	var shape_name := model_name
	# "sedan" parked cars alternate body shapes (sedan / hatchback / SUV / taxi...).
	if shp.has("variants") and not (shp["variants"] as Array).is_empty():
		var vlist: Array = shp["variants"]
		var pick := str(vlist[n % vlist.size()])
		if st.shapes.has(pick):
			shape_name = pick
			shp = st.shapes[pick]
	var L: float = length if length > 0.0 else float(shp.get("length", 4.5))
	var W: float = float(shp.get("width", 1.8))
	var H: float = float(shp.get("height", 1.45))
	var livery := str(shp.get("livery", ""))
	var paint_c: Color
	var paint_name := ""
	if livery != "" and st.liveries.has(livery):
		paint_c = (st.liveries[livery] as Dictionary).get("body", Color.WHITE)
		paint_name = livery
	else:
		var pal: Array = st.palette
		var idx := paint_index if paint_index >= 0 else (n * 3 + absi(hash(model_name))) % maxi(pal.size(), 1)
		var pe: Dictionary = pal[idx % pal.size()] if not pal.is_empty() else {"color": Color(0.8, 0.8, 0.82), "en": "silver"}
		paint_c = pe.get("color", Color.WHITE)
		paint_name = str(pe.get("en", ""))
	var holder := Node3D.new()
	holder.name = "Model"
	holder.set_meta(&"procedural", true)
	holder.set_meta(&"paint", paint_c)
	holder.set_meta(&"paint_name", paint_name)
	holder.set_meta(&"kind", shape_name)
	var stat := Node3D.new()
	stat.name = "Static"
	holder.add_child(stat)
	var ctx := {"L": L, "W": W, "H": H, "shp": shp, "st": st, "paint": paint_c, "holder": holder, "stat": stat,
		"livery": livery, "n": n}
	match str(shp.get("form", "car")):
		"truck":
			_truck(ctx)
		"box":
			_box_van(ctx)
		_:
			_car(ctx)
	holder.set_meta(&"parts", ctx.get("parts", {}))
	if st.merge_static:
		var merged := MeshMerger.merge_children(stat, holder, "BodyMesh")
		merged.set_meta(&"no_merge", true)
		holder.add_child(merged)
		stat.queue_free()
		holder.remove_child(stat)
	return [holder, Vector3(W, H, L)]


## Part inventory (holder meta "parts", used by the smoke test).
static func _tag(ctx: Dictionary, key: String, n: int) -> void:
	if not ctx.has("parts"):
		ctx["parts"] = {}
	var parts: Dictionary = ctx["parts"]
	parts[key] = int(parts.get(key, 0)) + n


# ------------------------------------------------------------------ materials
static func _m(key: String, c: Color, rough: float = 0.6, metal: float = 0.0, emit: float = 0.0, alpha: float = 1.0) -> StandardMaterial3D:
	var k := "%s|%s|%.2f|%.2f|%.2f|%.2f" % [key, c.to_html(), rough, metal, emit, alpha]
	if _mats.has(k):
		return _mats[k]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.roughness = rough
	m.metallic = metal
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	_mats[k] = m
	return m


static func paint(c: Color) -> StandardMaterial3D:
	var m := _m("paint", c, 0.28, 0.35)
	m.clearcoat_enabled = true
	m.clearcoat = 0.6
	return m


static func glass() -> StandardMaterial3D:
	var st := style()
	return _m("glass", Color(0.55, 0.66, 0.72), 0.05, 0.3, 0.0, st.glass_alpha if st else 0.3)


static func _box(p: Node3D, s: Vector3, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


static func _cyl(p: Node3D, r: float, h: float, pos: Vector3, m: Material, rot: Vector3 = Vector3.ZERO, seg: int = 14, top: float = -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r if top < 0.0 else top
	cm.bottom_radius = r
	cm.height = h
	cm.radial_segments = seg
	cm.rings = 1
	mi.mesh = cm
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	p.add_child(mi)
	return mi


## A thin slab between two points (glass panes, pillars) - local x width.
static func _slab(p: Node3D, a: Vector3, b: Vector3, width: float, thick: float, m: Material) -> MeshInstance3D:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := d.length()
	var mi := _box(p, Vector3(width, len, thick), mid, m)
	# Align local +Y with a->b (in the y/z plane).
	mi.rotation.x = atan2(d.z, d.y)
	return mi


# ------------------------------------------------------------------ shared parts
static func _wheels(ctx: Dictionary, wheelbase: float, r: float, track_in: float, rear_offset: float = 0.0, dual_rear: bool = false) -> void:
	_tag(ctx, "wheels", 6 if dual_rear else 4)
	var holder: Node3D = ctx["holder"]
	var W: float = ctx["W"]
	var tyre := _m("tyre", Color(0.06, 0.06, 0.065), 0.9)
	var rim := _m("rim", Color(0.78, 0.8, 0.83), 0.25, 0.8)
	var hub := _m("hub", Color(0.25, 0.26, 0.28), 0.4, 0.6)
	var arch := _m("arch", Color(0.03, 0.03, 0.035), 0.95)
	var stat: Node3D = ctx["stat"]
	for zi in [1.0, -1.0]:
		var z: float = zi * wheelbase * 0.5 + (rear_offset if zi < 0.0 else 0.0)
		for sx in [1.0, -1.0]:
			var w := Node3D.new()
			w.name = "Wheel_%s%s" % ["F" if zi > 0.0 else "R", "L" if sx > 0.0 else "R"]
			w.position = Vector3(sx * (W * 0.5 - track_in), r, z)
			w.add_to_group(&"car_wheels")
			if zi > 0.0:
				w.add_to_group(&"car_front_wheels")
			w.set_meta(&"no_merge", true)
			holder.add_child(w)
			var wide := 0.24
			_cyl(w, r, wide, Vector3.ZERO, tyre, Vector3(0, 0, PI * 0.5), 18)
			_cyl(w, r * 0.62, wide + 0.02, Vector3(sx * 0.005, 0, 0), rim, Vector3(0, 0, PI * 0.5), 14)
			_cyl(w, r * 0.2, wide + 0.05, Vector3(sx * 0.01, 0, 0), hub, Vector3(0, 0, PI * 0.5), 8)
			for k in 5:  # spokes
				var a := TAU * k / 5.0
				_box(w, Vector3(0.03, r * 0.5, 0.05), Vector3(sx * (wide * 0.5 + 0.012), sin(a) * r * 0.33, cos(a) * r * 0.33), rim, Vector3(a, 0, 0))
			if dual_rear and zi < 0.0:
				_cyl(w, r, wide, Vector3(-sx * 0.26, 0, 0), tyre, Vector3(0, 0, PI * 0.5), 18)
			# Dark wheel arch behind the tyre (reads as the cut-out in the body).
			_box(stat, Vector3(0.012, r * 0.55, r * 2.3), Vector3(sx * (W * 0.5 + 0.004), r + r * 0.72, z), arch)


static func _plate(ctx: Dictionary, pos: Vector3, rear: bool) -> void:
	_tag(ctx, "plates", 1)
	var holder: Node3D = ctx["holder"]
	var stat: Node3D = ctx["stat"]
	var st: CarBodyStyle = ctx["st"]
	var face := -1.0 if rear else 1.0
	var plate_w := 0.52
	_box(stat, Vector3(plate_w, 0.12, 0.02), pos, _m("plate", Color(0.97, 0.97, 0.95), 0.5))
	# Blue band on the left (Iranian plate) - the left as seen from outside.
	var band_x := plate_w * 0.5 - 0.035
	_box(stat, Vector3(0.06, 0.115, 0.022), pos + Vector3(band_x * face, 0, 0.002 * face), _m("plate_band", Color(0.1, 0.25, 0.65), 0.5))
	var l := Label3D.new()
	Lang.setup_label3d(l, 40)
	l.name = "PlateRear" if rear else "PlateFront"
	l.text = plate_text(int(ctx["n"]) + absi(hash(str(ctx["holder"].get_meta(&"kind")))) % 97, str(ctx["livery"]))
	l.font_size = 40
	l.pixel_size = 0.0022
	l.modulate = Color(0.05, 0.05, 0.06)
	l.outline_size = 0
	l.position = pos + Vector3(-0.025 * face, 0, 0.013 * face)
	l.rotation.y = PI if rear else 0.0
	l.visibility_range_end = 30.0
	l.add_to_group(&"car_plates")
	holder.add_child(l)
	if st and st.plate_frame:
		_box(stat, Vector3(plate_w + 0.03, 0.15, 0.012), pos - Vector3(0, 0, 0.008 * face), _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9))


## Persian-style plate: "۱۲ ب ۳۴۵ - ۶۷" (police / government plates use الف / پ / ث).
static func plate_text(n: int, livery: String = "") -> String:
	var letters := ["ب", "ج", "د", "س", "ص", "ط", "ق", "ل", "م", "ن", "و", "هـ", "ی"]
	var letter: String = letters[n % letters.size()]
	match livery:
		"police":
			letter = "پ"
		"ambulance", "firetruck":
			letter = "الف"
		"taxi":
			letter = "ت"
	var a := 11 + (n * 37) % 88
	var b := 111 + (n * 211) % 888
	var c := 10 + (n * 53) % 89
	return Lang.digits("%d %s %d | %d" % [a, letter, b, c]) if Lang.is_fa() else "%d %s %d | %d" % [a, letter, b, c]


static func _lights(ctx: Dictionary, zf: float, zr: float, y: float, W: float) -> void:
	_tag(ctx, "headlights", 2)
	var stat: Node3D = ctx["stat"]
	var chrome := _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9)
	for sx in [1.0, -1.0]:
		var x: float = sx * (W * 0.5 - 0.22)
		_box(stat, Vector3(0.34, 0.13, 0.06), Vector3(x, y, zf), chrome)
		_box(stat, Vector3(0.3, 0.1, 0.05), Vector3(x, y, zf + 0.012), _m("headlight", Color(1.0, 0.98, 0.9), 0.1, 0.0, 0.6))
		_box(stat, Vector3(0.1, 0.035, 0.05), Vector3(x - sx * 0.1, y - 0.075, zf + 0.004), _m("indicator", Color(1.0, 0.6, 0.1), 0.3, 0.0, 0.3))
		_box(stat, Vector3(0.3, 0.12, 0.05), Vector3(sx * (W * 0.5 - 0.2), y + 0.02, zr), _m("taillight", Color(0.85, 0.05, 0.05), 0.3, 0.0, 0.5))
		_box(stat, Vector3(0.08, 0.12, 0.052), Vector3(sx * (W * 0.5 - 0.06), y + 0.02, zr), _m("reverse", Color(0.95, 0.95, 0.95), 0.3))


static func _grille(ctx: Dictionary, z: float, y: float, w: float, h: float) -> void:
	_tag(ctx, "grille", 1)
	var stat: Node3D = ctx["stat"]
	var chrome := _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9)
	_box(stat, Vector3(w, h, 0.04), Vector3(0, y, z), _m("grille", Color(0.05, 0.05, 0.06), 0.7))
	for k in 4:
		_box(stat, Vector3(w * 0.96, 0.014, 0.05), Vector3(0, y - h * 0.38 + k * h * 0.25, z + 0.006), chrome)
	_box(stat, Vector3(w + 0.04, 0.025, 0.05), Vector3(0, y + h * 0.5, z + 0.004), chrome)


static func _mirrors(ctx: Dictionary, z: float, y: float, W: float, paint_m: Material) -> void:
	_tag(ctx, "side_mirrors", 2)
	var stat: Node3D = ctx["stat"]
	for sx in [1.0, -1.0]:
		_box(stat, Vector3(0.12, 0.04, 0.05), Vector3(sx * (W * 0.5 + 0.04), y, z), paint_m)
		_box(stat, Vector3(0.1, 0.11, 0.07), Vector3(sx * (W * 0.5 + 0.13), y + 0.02, z), paint_m)
		_box(stat, Vector3(0.085, 0.09, 0.01), Vector3(sx * (W * 0.5 + 0.13), y + 0.02, z - 0.04), _m("mirror", Color(0.75, 0.82, 0.88), 0.05, 0.9))


static func _seat(p: Node3D, pos: Vector3, w: float, fabric: Material, depth: float = 0.5, back_h: float = 0.62) -> void:
	_box(p, Vector3(w, 0.14, depth), pos, fabric)
	_box(p, Vector3(w, back_h, 0.12), pos + Vector3(0, back_h * 0.5 + 0.02, -depth * 0.5 + 0.02), fabric, Vector3(-0.2, 0, 0))
	_box(p, Vector3(w * 0.55, 0.16, 0.1), pos + Vector3(0, back_h + 0.14, -depth * 0.5 - 0.08), fabric, Vector3(-0.2, 0, 0))


## Dashboard (gauges, centre screen, vents), steering wheel (turns), rear-view mirror.
static func _interior(ctx: Dictionary, dash_z: float, belt: float, roof_y: float, front_seat_z: float, rear_seat_z: float, rear_seats: bool = true) -> void:
	_tag(ctx, "dashboard", 1)
	_tag(ctx, "gauges", 2)
	_tag(ctx, "seats", 3 if rear_seats else 2)
	_tag(ctx, "rear_view_mirror", 1)
	var holder: Node3D = ctx["holder"]
	var stat: Node3D = ctx["stat"]
	var W: float = ctx["W"]
	var H: float = ctx["H"]
	var st: CarBodyStyle = ctx["st"]
	var trim := _m("trim_dark", Color(0.12, 0.12, 0.13), 0.8)
	var fabric := _m("seat", st.seat_color if st else Color(0.22, 0.2, 0.19), 0.95)
	var floor_m := _m("carpet", Color(0.09, 0.09, 0.1), 1.0)
	var inner_w := W - 0.16
	_box(stat, Vector3(inner_w, 0.04, (dash_z - rear_seat_z) + 0.8), Vector3(0, belt - 0.55, (dash_z + rear_seat_z) * 0.5 - 0.1), floor_m)
	# Dashboard: a deep block under the windscreen + a hood over the gauges.
	_box(stat, Vector3(inner_w, 0.3, 0.42), Vector3(0, belt - 0.05, dash_z), trim)
	_box(stat, Vector3(inner_w, 0.04, 0.5), Vector3(0, belt + 0.11, dash_z + 0.04), _m("dash_top", Color(0.18, 0.17, 0.17), 0.7))
	var eye := CockpitEye.eye(Vector3(W, H, float(ctx["L"])))
	var dx := eye.x
	_box(stat, Vector3(0.42, 0.13, 0.08), Vector3(dx, belt + 0.12, dash_z - 0.2), trim)  # gauge hood
	for k in 2:
		var gx := dx + (0.09 if k == 0 else -0.09)
		_cyl(stat, 0.065, 0.02, Vector3(gx, belt + 0.1, dash_z - 0.235), _m("gauge", Color(0.92, 0.95, 1.0), 0.4, 0.0, 0.35), Vector3(PI * 0.5, 0, 0), 16)
		_box(stat, Vector3(0.008, 0.055, 0.005), Vector3(gx, belt + 0.11, dash_z - 0.248), _m("needle", Color(0.9, 0.1, 0.05), 0.4, 0.0, 0.5), Vector3(0, 0, 0.6 - k * 1.1))
	_box(stat, Vector3(0.2, 0.13, 0.02), Vector3(0, belt + 0.04, dash_z - 0.215), _m("screen", Color(0.25, 0.45, 0.75), 0.2, 0.0, 0.5))  # centre screen
	for sx in [-0.3, 0.0, 0.3]:
		_box(stat, Vector3(0.12, 0.04, 0.02), Vector3(sx * inner_w * 0.9, belt - 0.07, dash_z - 0.215), _m("vent", Color(0.03, 0.03, 0.03), 0.9))
	_box(stat, Vector3(0.22, 0.3, 0.55), Vector3(0, belt - 0.33, dash_z - 0.45), trim)  # centre console
	_box(stat, Vector3(0.04, 0.12, 0.04), Vector3(0, belt - 0.12, dash_z - 0.6), _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9))  # gear lever
	# Steering wheel on a column - a separate node that turns (SteeringWheel).
	var sw := SteeringWheel.new()
	sw.name = "SteeringWheel"
	sw.turn_deg = st.wheel_turn_deg if st else 140.0
	sw.set_meta(&"no_merge", true)
	sw.position = Vector3(dx, belt + 0.02, dash_z - 0.42)
	sw.rotation.x = deg_to_rad(-24.0)  # tilted towards the driver
	holder.add_child(sw)
	sw.build(trim, _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9))
	_cyl(stat, 0.035, 0.42, Vector3(dx, belt - 0.02, dash_z - 0.22), trim, Vector3(PI * 0.5 - 0.42, 0, 0))
	# Seats: two fronts + a rear bench.
	var seat_y := belt - 0.42
	for sx in [1.0, -1.0]:
		_seat(stat, Vector3(sx * inner_w * 0.24, seat_y, front_seat_z), inner_w * 0.36, fabric)
	if rear_seats:
		_seat(stat, Vector3(0, seat_y + 0.02, rear_seat_z), inner_w * 0.86, fabric)
	# Door cards (inner panels) + rear-view mirror.
	for sx in [1.0, -1.0]:
		_box(stat, Vector3(0.04, 0.42, (dash_z - rear_seat_z) + 0.4), Vector3(sx * (W * 0.5 - 0.1), belt - 0.2, (dash_z + rear_seat_z) * 0.5), _m("door_card", Color(0.2, 0.19, 0.18), 0.85))
	_box(stat, Vector3(0.24, 0.07, 0.03), Vector3(0, roof_y - 0.12, dash_z - 0.12), trim)
	_box(stat, Vector3(0.22, 0.055, 0.01), Vector3(0, roof_y - 0.12, dash_z - 0.138), _m("mirror", Color(0.75, 0.82, 0.88), 0.05, 0.9))


## Roof panel (group "car_roof" so the cockpit camera can hide it when looking up):
## paint frame + a glass sunroof in the middle.
static func _roof(ctx: Dictionary, z0: float, z1: float, y: float, w: float, paint_m: Material) -> void:
	_tag(ctx, "roof_glass", 1)
	var holder: Node3D = ctx["holder"]
	var st: CarBodyStyle = ctx["st"]
	var roof := Node3D.new()
	roof.name = "Roof"
	roof.add_to_group(&"car_roof")
	roof.set_meta(&"no_merge", true)
	holder.add_child(roof)
	var len := z1 - z0
	var zc := (z0 + z1) * 0.5
	var sun := st == null or st.sunroof
	if sun:
		var frame := w * 0.18
		for sx in [1.0, -1.0]:
			_box(roof, Vector3(frame, 0.05, len), Vector3(sx * (w * 0.5 - frame * 0.5), y, zc), paint_m)
		_box(roof, Vector3(w, 0.05, len * 0.16), Vector3(0, y, z1 - len * 0.08), paint_m)
		_box(roof, Vector3(w, 0.05, len * 0.16), Vector3(0, y, z0 + len * 0.08), paint_m)
		_box(roof, Vector3(w - frame * 2.0, 0.02, len * 0.68), Vector3(0, y + 0.01, zc), _m("sunroof", Color(0.12, 0.16, 0.2), 0.05, 0.4, 0.0, 0.45))
	else:
		_box(roof, Vector3(w, 0.05, len), Vector3(0, y, zc), paint_m)
	if not sun:
		_box(roof, Vector3(w - 0.08, 0.02, len - 0.06), Vector3(0, y - 0.035, zc), _m("headliner", Color(0.72, 0.7, 0.66), 0.95))


# ------------------------------------------------------------------ car (sedan / hatch / suv / police / taxi / van / pickup)
static func _car(ctx: Dictionary) -> void:
	var L: float = ctx["L"]
	var W: float = ctx["W"]
	var H: float = ctx["H"]
	var shp: Dictionary = ctx["shp"]
	var stat: Node3D = ctx["stat"]
	var pm := paint(ctx["paint"])
	var r: float = float(shp.get("wheel_r", 0.34))
	var clr: float = r * 0.75
	var belt: float = float(shp.get("belt", 0.95))
	var hood_len: float = float(shp.get("hood", 1.15))
	var trunk_len: float = float(shp.get("trunk", 0.85))
	var zf := L * 0.5
	var zr := -L * 0.5
	var ws_base := zf - hood_len          # windscreen base (front of the cabin)
	var rw_base := zr + trunk_len          # rear window base
	var rake: float = float(shp.get("rake", 0.62))   # windscreen run (m)
	var rear_rake: float = float(shp.get("rear_rake", 0.45))
	var roof_y := H - 0.03
	var roof_z1 := ws_base - rake
	var roof_z0 := rw_base + rear_rake
	var dark := _m("plastic", Color(0.1, 0.1, 0.11), 0.85)
	var chrome := _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9)
	var seam := _m("seam", Color(0.05, 0.05, 0.05), 0.9)
	# Lower body + bumpers.
	_box(stat, Vector3(W, belt - clr, L - 0.3), Vector3(0, (belt + clr) * 0.5, 0), pm)
	_box(stat, Vector3(W - 0.04, belt - clr - 0.12, 0.16), Vector3(0, (belt + clr) * 0.5 + 0.02, zf - 0.08), pm)  # nose
	_box(stat, Vector3(W - 0.04, belt - clr - 0.08, 0.16), Vector3(0, (belt + clr) * 0.5 + 0.03, zr + 0.08), pm)  # tail
	_box(stat, Vector3(W + 0.02, 0.2, 0.14), Vector3(0, clr + 0.1, zf - 0.03), dark)  # front bumper
	_box(stat, Vector3(W + 0.02, 0.22, 0.14), Vector3(0, clr + 0.11, zr + 0.03), dark)  # rear bumper
	_box(stat, Vector3(W * 0.6, 0.06, 0.03), Vector3(0, clr + 0.15, zf + 0.045), chrome)
	for sx in [1.0, -1.0]:
		_box(stat, Vector3(0.03, 0.08, L - 1.4), Vector3(sx * (W * 0.5 + 0.01), clr + 0.08, 0), dark)  # side skirts
	# Hood (slight slope) + hood lines, trunk lid.
	var hood := _box(stat, Vector3(W - 0.06, 0.05, hood_len), Vector3(0, belt + 0.02, zf - hood_len * 0.5), pm)
	hood.rotation.x = 0.05
	for sx in [1.0, -1.0]:
		_box(stat, Vector3(0.012, 0.012, hood_len * 0.85), Vector3(sx * W * 0.24, belt + 0.05, zf - hood_len * 0.5), seam, Vector3(0.05, 0, 0))
	_box(stat, Vector3(W - 0.06, 0.05, trunk_len), Vector3(0, belt + 0.04, zr + trunk_len * 0.5), pm)
	_box(stat, Vector3(W - 0.1, 0.01, 0.012), Vector3(0, belt + 0.07, zr + trunk_len - 0.02), seam)
	# Grille, headlights, tail lights, plates.
	_grille(ctx, zf + 0.005, (belt + clr) * 0.5 + 0.05, W * 0.42, 0.2)
	_lights(ctx, zf - 0.005, zr - 0.005, belt - 0.12, W)
	_plate(ctx, Vector3(0, clr + 0.12, zf + 0.05), false)
	_plate(ctx, Vector3(0, belt - 0.32, zr - 0.012), true)
	# Doors: seams + handles on both sides.
	var door_split := (ws_base + roof_z0) * 0.5 - 0.1
	for sx in [1.0, -1.0]:
		var x: float = sx * (W * 0.5 + 0.003)
		for z in [ws_base + 0.05, door_split, roof_z0 - 0.15 if bool(shp.get("rear_doors", true)) else door_split]:
			_box(stat, Vector3(0.008, belt - clr - 0.1, 0.012), Vector3(x, (belt + clr) * 0.5 + 0.03, z), seam)
		_box(stat, Vector3(0.02, 0.03, 0.14), Vector3(x + sx * 0.008, belt - 0.12, door_split + 0.45), chrome)
		if bool(shp.get("rear_doors", true)):
			_box(stat, Vector3(0.02, 0.03, 0.14), Vector3(x + sx * 0.008, belt - 0.12, door_split - 0.45), chrome)
	# Greenhouse: windscreen, rear window, side glass, pillars, roof.
	var gl := glass()
	var wsa := Vector3(0, belt + 0.06, ws_base)
	var wsb := Vector3(0, roof_y, roof_z1)
	_slab(stat, wsa, wsb, W - 0.2, 0.02, gl)
	_slab(stat, Vector3(0, belt + 0.06, rw_base), Vector3(0, roof_y, roof_z0), W - 0.22, 0.02, gl)
	var gw := 0.02
	for sx in [1.0, -1.0]:
		var x: float = sx * (W * 0.5 - 0.09)
		# Side glass (front + rear) as quads leaning in slightly.
		var side := _box(stat, Vector3(gw, roof_y - belt - 0.08, roof_z1 - roof_z0 + 0.2), Vector3(x, (roof_y + belt) * 0.5, (roof_z1 + roof_z0) * 0.5), gl)
		side.rotation.z = -sx * 0.06
		# A pillar, B pillar, C pillar.
		_slab(stat, Vector3(x, belt + 0.04, ws_base), Vector3(x, roof_y, roof_z1), 0.07, 0.07, pm)
		_box(stat, Vector3(0.07, roof_y - belt, 0.1), Vector3(x, (roof_y + belt) * 0.5, door_split), pm)
		_slab(stat, Vector3(x, belt + 0.04, rw_base), Vector3(x, roof_y, roof_z0), 0.07, 0.16, pm)
		# Window belt trim.
		_box(stat, Vector3(0.025, 0.025, roof_z1 - roof_z0 + 0.6), Vector3(sx * (W * 0.5 - 0.02), belt + 0.04, (roof_z1 + roof_z0) * 0.5), chrome)
	_roof(ctx, roof_z0 - 0.02, roof_z1 + 0.02, roof_y, W - 0.14, pm)
	_mirrors(ctx, ws_base - 0.08, belt + 0.12, W, pm)
	_interior(ctx, ws_base - 0.05, belt, roof_y, CockpitEye.eye(Vector3(W, H, L)).z - 0.15, roof_z0 + 0.25, bool(shp.get("rear_doors", true)))
	_wheels(ctx, L * 0.6, r, 0.1)
	_livery(ctx, belt, clr, roof_y, roof_z0, roof_z1)
	if str(shp.get("bed", "")) == "pickup":
		_box(stat, Vector3(W - 0.1, 0.4, trunk_len - 0.2), Vector3(0, belt + 0.2, zr + trunk_len * 0.5), _m("bed", Color(0.15, 0.15, 0.16), 0.9))


## Police / taxi / ambulance markings on a regular body.
static func _livery(ctx: Dictionary, belt: float, clr: float, roof_y: float, z0: float, z1: float) -> void:
	var livery := str(ctx["livery"])
	if livery == "":
		return
	var st: CarBodyStyle = ctx["st"]
	var lv: Dictionary = st.liveries.get(livery, {})
	var stat: Node3D = ctx["stat"]
	var holder: Node3D = ctx["holder"]
	var W: float = ctx["W"]
	var L: float = ctx["L"]
	var stripe: Color = lv.get("stripe", Color.TRANSPARENT)
	if stripe.a > 0.0:
		for sx in [1.0, -1.0]:
			_box(stat, Vector3(0.012, 0.16, L - 0.5), Vector3(sx * (W * 0.5 + 0.006), (belt + clr) * 0.5 + 0.02, 0), _m("stripe", stripe, 0.5))
	var text_fa := str(lv.get("text_fa", ""))
	if text_fa != "":
		for sx in [1.0, -1.0]:
			var l := Label3D.new()
			Lang.setup_label3d(l, 64)
			l.text = text_fa if Lang.is_fa() else str(lv.get("text_en", text_fa))
			l.pixel_size = 0.0045
			l.outline_size = 0
			l.modulate = lv.get("text_color", Color(1, 1, 1))
			l.position = Vector3(sx * (W * 0.5 + 0.02), (belt + clr) * 0.5 + 0.02, -0.1)
			l.rotation.y = sx * PI * 0.5
			l.visibility_range_end = 45.0
			holder.add_child(l)
	if bool(lv.get("roof_sign", false)):  # taxi sign
		_box(stat, Vector3(0.5, 0.16, 0.2), Vector3(0, roof_y + 0.11, (z0 + z1) * 0.5), _m("taxi_sign", Color(1.0, 0.85, 0.1), 0.4, 0.0, 0.2))


# ------------------------------------------------------------------ ambulance / delivery (box body behind a cab)
static func _box_van(ctx: Dictionary) -> void:
	var L: float = ctx["L"]
	var W: float = ctx["W"]
	var H: float = ctx["H"]
	var shp: Dictionary = ctx["shp"]
	var stat: Node3D = ctx["stat"]
	var pm := paint(ctx["paint"])
	var r: float = float(shp.get("wheel_r", 0.37))
	var clr := r * 0.75
	var belt: float = float(shp.get("belt", 1.05))
	var zf := L * 0.5
	var zr := -L * 0.5
	var cab_len: float = float(shp.get("cab", 1.9))
	var hood_len := 0.75
	var ws_base := zf - hood_len
	var cab_roof := minf(H - 0.35, belt + 0.85)
	var box_front := zf - cab_len
	var dark := _m("plastic", Color(0.1, 0.1, 0.11), 0.85)
	var gl := glass()
	# Cab lower body + hood + bumpers.
	_box(stat, Vector3(W, belt - clr, cab_len - 0.1), Vector3(0, (belt + clr) * 0.5, zf - cab_len * 0.5 - 0.05), pm)
	var hood := _box(stat, Vector3(W - 0.06, 0.05, hood_len), Vector3(0, belt + 0.02, zf - hood_len * 0.5), pm)
	hood.rotation.x = 0.08
	_box(stat, Vector3(W + 0.02, 0.22, 0.14), Vector3(0, clr + 0.11, zf - 0.03), dark)
	_box(stat, Vector3(W + 0.02, 0.22, 0.14), Vector3(0, clr + 0.11, zr + 0.03), dark)
	_grille(ctx, zf + 0.005, (belt + clr) * 0.5 + 0.05, W * 0.5, 0.26)
	_lights(ctx, zf - 0.005, zr - 0.005, belt - 0.12, W)
	_plate(ctx, Vector3(0, clr + 0.12, zf + 0.05), false)
	_plate(ctx, Vector3(0, clr + 0.4, zr - 0.012), true)
	# Cab greenhouse.
	var roof_z1 := ws_base - 0.5
	_slab(stat, Vector3(0, belt + 0.06, ws_base), Vector3(0, cab_roof, roof_z1), W - 0.2, 0.02, gl)
	for sx in [1.0, -1.0]:
		var x: float = sx * (W * 0.5 - 0.09)
		_box(stat, Vector3(0.02, cab_roof - belt - 0.08, roof_z1 - box_front), Vector3(x, (cab_roof + belt) * 0.5, (roof_z1 + box_front) * 0.5), gl)
		_slab(stat, Vector3(x, belt + 0.04, ws_base), Vector3(x, cab_roof, roof_z1), 0.07, 0.07, pm)
		_box(stat, Vector3(0.008, belt - clr - 0.1, 0.012), Vector3(sx * (W * 0.5 + 0.003), (belt + clr) * 0.5, box_front + 0.15), _m("seam", Color(0.05, 0.05, 0.05), 0.9))
	_roof(ctx, box_front, roof_z1 + 0.02, cab_roof, W - 0.14, pm)
	_mirrors(ctx, ws_base - 0.1, belt + 0.15, W, pm)
	# Box body (rear compartment) + rear doors.
	var box_len := box_front - zr
	_box(stat, Vector3(W + 0.04, H - clr - 0.1, box_len), Vector3(0, (H + clr + 0.1) * 0.5, zr + box_len * 0.5), pm)
	_box(stat, Vector3(0.012, H - clr - 0.4, 0.01), Vector3(0, (H + clr) * 0.5, zr - 0.006), _m("seam", Color(0.05, 0.05, 0.05), 0.9))
	for sx in [1.0, -1.0]:
		_box(stat, Vector3(0.5, 0.35, 0.012), Vector3(sx * 0.4, H - 0.6, zr - 0.006), gl)
	_interior(ctx, ws_base - 0.05, belt, cab_roof, CockpitEye.eye(Vector3(W, H, L)).z - 0.15, box_front + 0.4, false)
	_wheels(ctx, L * 0.58, r, 0.1)
	var livery := str(ctx["livery"])
	_livery(ctx, belt, clr, cab_roof, box_front, roof_z1)
	if livery == "ambulance":
		var red := _m("cross", Color(0.85, 0.08, 0.08), 0.5)
		for sx in [1.0, -1.0]:
			var x: float = sx * (W * 0.5 + 0.03)
			var zc := zr + box_len * 0.5
			_box(stat, Vector3(0.012, 0.5, 0.16), Vector3(x, H - 0.55, zc), red)
			_box(stat, Vector3(0.012, 0.16, 0.5), Vector3(x, H - 0.55, zc), red)
		_box(stat, Vector3(0.012 + 0.5, 0.16, 0.012), Vector3(0, H - 0.3, zr - 0.012), red)


# ------------------------------------------------------------------ fire truck
static func _truck(ctx: Dictionary) -> void:
	var L: float = ctx["L"]
	var W: float = ctx["W"]
	var H: float = ctx["H"]
	var shp: Dictionary = ctx["shp"]
	var stat: Node3D = ctx["stat"]
	var holder: Node3D = ctx["holder"]
	var pm := paint(ctx["paint"])
	var r: float = float(shp.get("wheel_r", 0.5))
	var clr := r * 0.8
	var belt := 1.45
	var zf := L * 0.5
	var zr := -L * 0.5
	var cab_len := 2.2
	var cab_roof := 2.75
	var box_front := zf - cab_len
	var dark := _m("plastic", Color(0.1, 0.1, 0.11), 0.85)
	var chrome := _m("chrome", Color(0.85, 0.86, 0.88), 0.2, 0.9)
	var white := _m("fire_white", Color(0.96, 0.96, 0.94), 0.5)
	var gl := glass()
	# Chassis + cab (flat-nosed, high windscreen).
	_box(stat, Vector3(W - 0.3, 0.3, L - 0.4), Vector3(0, clr + 0.05, 0), dark)
	_box(stat, Vector3(W, belt - clr, cab_len), Vector3(0, (belt + clr) * 0.5 + 0.1, zf - cab_len * 0.5), pm)
	_box(stat, Vector3(W + 0.04, 0.3, 0.18), Vector3(0, clr + 0.1, zf + 0.02), chrome)  # big chrome bumper
	_grille(ctx, zf + 0.005, belt - 0.35, W * 0.55, 0.42)
	_lights(ctx, zf - 0.005, zr - 0.005, belt - 0.5, W)
	_plate(ctx, Vector3(0, clr + 0.3, zf + 0.12), false)
	_plate(ctx, Vector3(0, clr + 0.3, zr - 0.012), true)
	_slab(stat, Vector3(0, belt + 0.05, zf - 0.05), Vector3(0, cab_roof - 0.05, zf - 0.3), W - 0.2, 0.03, gl)
	for sx in [1.0, -1.0]:
		var x: float = sx * (W * 0.5 - 0.06)
		_box(stat, Vector3(0.03, cab_roof - belt - 0.15, cab_len - 0.5), Vector3(x, (cab_roof + belt) * 0.5, zf - cab_len * 0.5 - 0.1), gl)
		_slab(stat, Vector3(x, belt, zf - 0.04), Vector3(x, cab_roof, zf - 0.3), 0.09, 0.09, pm)
		_box(stat, Vector3(0.09, cab_roof - belt, 0.12), Vector3(x, (cab_roof + belt) * 0.5, box_front + 0.08), pm)
		_box(stat, Vector3(0.012, belt - clr - 0.1, 0.012), Vector3(sx * (W * 0.5 + 0.003), (belt + clr) * 0.5, zf - cab_len * 0.55), _m("seam", Color(0.05, 0.05, 0.05), 0.9))
		for k in 3:  # cab steps
			_box(stat, Vector3(0.2, 0.04, 0.4), Vector3(sx * (W * 0.5 + 0.06), clr + 0.1 + k * 0.32, zf - cab_len * 0.55), chrome)
	_roof(ctx, box_front, zf - 0.28, cab_roof, W - 0.14, pm)
	_mirrors(ctx, zf - 0.35, belt + 0.25, W + 0.12, chrome)
	_interior(ctx, zf - 0.45, belt, cab_roof, CockpitEye.eye(Vector3(W, H, L)).z - 0.15, box_front + 0.4, true)
	# Body with roller-shutter lockers, white stripe, hose reels, ladder, light bar.
	var box_len := box_front - zr - 0.05
	var box_h := 2.45
	_box(stat, Vector3(W, box_h - clr - 0.15, box_len), Vector3(0, (box_h + clr + 0.15) * 0.5, zr + box_len * 0.5), pm)
	for sx in [1.0, -1.0]:
		var x: float = sx * (W * 0.5 + 0.006)
		_box(stat, Vector3(0.012, 0.14, L - 0.3), Vector3(x, belt - 0.15, -0.1), white)  # stripe
		for k in 3:
			var zc := zr + 0.5 + k * (box_len - 0.6) / 3.0 + (box_len - 0.6) / 6.0
			_box(stat, Vector3(0.012, 0.8, (box_len - 0.8) / 3.0), Vector3(x, belt + 0.55, zc), _m("shutter", Color(0.78, 0.8, 0.82), 0.35, 0.6))
			for s in 6:
				_box(stat, Vector3(0.016, 0.01, (box_len - 0.8) / 3.0), Vector3(x, belt + 0.2 + s * 0.13, zc), _m("seam", Color(0.05, 0.05, 0.05), 0.9))
		# Hose reels (red drum + white hose coils) on the rear sides.
		_cyl(stat, 0.32, 0.22, Vector3(sx * (W * 0.5 + 0.11), clr + 0.6, zr + 0.55), _m("reel", Color(0.6, 0.6, 0.62), 0.4, 0.6), Vector3(0, 0, PI * 0.5), 16)
		_cyl(stat, 0.26, 0.24, Vector3(sx * (W * 0.5 + 0.11), clr + 0.6, zr + 0.55), white, Vector3(0, 0, PI * 0.5), 16)
		# "آتش‌نشانی ۱۲۵" on both sides.
		var l := Label3D.new()
		Lang.setup_label3d(l, 72)
		l.text = Lang.tt("آتش‌نشانی ۱۲۵", "FIRE 125")
		l.pixel_size = 0.0055
		l.outline_size = 0
		l.modulate = Color(1, 1, 1)
		l.position = Vector3(sx * (W * 0.5 + 0.02), belt - 0.55, zf - cab_len * 0.5)
		l.rotation.y = sx * PI * 0.5
		l.visibility_range_end = 60.0
		l.add_to_group(&"fire_truck_text")
		holder.add_child(l)
	_tag(ctx, "hose_reels", 2)
	_tag(ctx, "ladder", 1)
	# Ladder on the roof (rails + rungs) on a turntable.
	_cyl(stat, 0.45, 0.2, Vector3(0, box_h + 0.1, zr + 0.9), dark, Vector3.ZERO, 16)
	for sx in [-0.32, 0.32]:
		_box(stat, Vector3(0.07, 0.1, L - 1.3), Vector3(sx, box_h + 0.32, -0.25), chrome, Vector3(-0.04, 0, 0))
	for k in 16:
		_box(stat, Vector3(0.64, 0.035, 0.04), Vector3(0, box_h + 0.32 + (k - 8) * 0.0145, -0.25 - (L - 1.4) * 0.5 + k * (L - 1.4) / 15.0), chrome, Vector3(-0.04, 0, 0))
	# Rear: ladder steps + a back panel stripe.
	_box(stat, Vector3(W - 0.2, 0.12, 0.012), Vector3(0, belt - 0.15, zr - 0.012), white)
	_wheels(ctx, L * 0.55, r, 0.14, 0.0, true)


## Small static helper so CockpitCamera and the interior agree on where the
## driver's eye is (CockpitCamera.eye_local_for(size) when it exists).
class CockpitEye:
	static func eye(size: Vector3) -> Vector3:
		return Vector3(size.x * 0.2, clampf(size.y * 0.74, 0.95, 1.7), size.z * 0.02)
