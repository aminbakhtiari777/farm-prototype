class_name TrafficSigns
extends Node3D
## v7b.1 traffic_signs module: STOP (ایست) at the STOP junction, give way +
## roundabout + one-way arrows at the square, speed-limit discs that match the
## traffic_rules limits (repeated every `limit_every` m on both sides), school
## zone signs, NO PARKING discs and Persian / English direction boards.

var counts: Dictionary = {}     ## kind -> number built (tests)
var limit_signs: Array = []     ## [{pos: Vector2, kmh, road}]


func style() -> TrafficSignStyle:
	return Modules.style("traffic_signs") as TrafficSignStyle


func _ready() -> void:
	rebuild.call_deferred()
	Modules.on_swap("traffic_signs", self, func(_m: Resource) -> void: rebuild())
	Modules.on_swap("traffic_rules", self, func(_m: Resource) -> void: rebuild.call_deferred())


func _count(k: String) -> void:
	counts[k] = int(counts.get(k, 0)) + 1


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	counts.clear()
	limit_signs.clear()
	var st := style()
	var rules := TrafficKit.rules()
	if st == null or rules == null:
		return
	# STOP signs.
	for s: Dictionary in rules.stops:
		var want: Array = s.get("approaches", [])
		for a: Dictionary in TrafficKit.arms(s["pos"]):
			if not str(a["dir_code"]) in want:
				continue
			var h: Vector2 = a["heading"]
			var p := (s["pos"] as Vector2) - h * (float(a["stop"]) - 0.3) + Vector2(-h.y, h.x) * (float(a["half"]) + 0.7)
			var holder := _holder(p, h, "Stop")
			_pole(holder, st.pole_h)
			var oct := V7aKit.cyl(holder, st.disc * 0.55, 0.04, Vector3(0, st.pole_h, 0.05), TrafficKit.mat(Color(0.8, 0.06, 0.06), 0.5))
			(oct.mesh as CylinderMesh).radial_segments = 8
			oct.rotation = Vector3(PI * 0.5, 0, PI / 8.0)
			_text(holder, "ایست", "STOP", Vector3(0, st.pole_h, 0.08), 0.0042, Color.WHITE)
			_count("stop")
	# Roundabout: give way + roundabout disc + one-way arrows at every entry.
	for r: Dictionary in TrafficKit.paved():
		var pts: Array = r["points"]
		for e: Vector2 in [pts[0], pts[pts.size() - 1]]:
			if e.distance_to(TownLayout.TOWN_CENTER) > TownLayout.SQUARE_RADIUS + 2.5:
				continue
			var into := (TownLayout.TOWN_CENTER - e).normalized()
			var right := Vector2(-into.y, into.x)
			var p := e - into * 2.4 + right * (float(r["half"]) + 0.7)
			var holder := _holder(p, into, "GiveWay")
			_pole(holder, st.pole_h + 0.5)
			_tri(holder, Vector3(0, st.pole_h + 0.45, 0.05), st.disc * 0.6, Color(0.85, 0.08, 0.08), true)
			_tri(holder, Vector3(0, st.pole_h + 0.47, 0.08), st.disc * 0.42, Color(0.98, 0.98, 0.96), true)
			_disc(holder, Vector3(0, st.pole_h - 0.35, 0.05), st.disc * 0.45, Color(0.1, 0.32, 0.75))
			_arrow(holder, Vector3(0, st.pole_h - 0.35, 0.1), "right", Color.WHITE, 0.45)
			_text(holder, "میدان - حق تقدم با داخل", "Roundabout - give way", Vector3(0, st.pole_h - 0.85, 0.06), 0.0022, Color(0.1, 0.1, 0.1), 6)
			_count("give_way")
			# One-way board on the island opposite the entry (traffic turns right).
			var q := TownLayout.TOWN_CENTER - into * (VehicleKit.SQUARE_RING - 3.4)
			var oh := _holder(q, into, "OneWay")
			_pole(oh, 1.6)
			V7aKit.box(oh, Vector3(1.2, 0.36, 0.04), Vector3(0, 1.6, 0.04), TrafficKit.mat(Color(0.1, 0.32, 0.75), 0.5))
			_arrow(oh, Vector3(0.0, 1.6, 0.08), "right", Color.WHITE, 0.9)
			_text(oh, "یک‌طرفه", "One way", Vector3(0, 1.3, 0.07), 0.0022, Color(1, 1, 1), 6)
			_count("one_way")
	# Speed limits (and school zone entries).
	for r: Dictionary in TrafficKit.paved():
		var kmh := TrafficKit.limit_for_road(str(r["name"]))
		var half := float(r["half"])
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			if length < 6.0:
				continue
			var d := (b - a) / length
			var n := Vector2(-d.y, d.x)
			var t := 7.0
			while t < length - 4.0:
				for dirn: float in [1.0, -1.0]:
					var fwd := d * dirn
					var right := Vector2(-fwd.y, fwd.x)
					var c := a + d * (t if dirn > 0.0 else length - t)
					var p := c + right * (half + 0.6)
					if _blocked(p, r) or absf(TrafficKit.limit_kmh(c) - kmh) > 0.1:
						continue
					_limit_sign(p, fwd, kmh, str(r["name"]))
				t += st.limit_every
			# School zone entries.
			var was := TrafficKit.in_school_zone(a)
			var s := 1.0
			while s < length:
				var c2 := a + d * s
				var now := TrafficKit.in_school_zone(c2)
				if now != was:
					var fwd2 := d if now else -d
					var right2 := Vector2(-fwd2.y, fwd2.x)
					var p2 := c2 - fwd2 * 1.5 + right2 * (half + 0.6)
					if not _blocked(p2, r, false):
						_school_sign(p2, fwd2)
				was = now
				s += 1.0
	# NO PARKING.
	for np: Dictionary in st.no_parking:
		var p3: Vector2 = np["pos"]
		var yaw := deg_to_rad(float(np.get("yaw", 0.0)))
		var holder := Node3D.new()
		holder.name = "NoParking"
		holder.position = TrafficKit.ground(p3)
		holder.rotation.y = yaw
		add_child(holder)
		_pole(holder, st.pole_h)
		_disc(holder, Vector3(0, st.pole_h, 0.04), st.disc * 0.5, Color(0.85, 0.1, 0.1))
		_disc(holder, Vector3(0, st.pole_h, 0.06), st.disc * 0.42, Color(0.12, 0.3, 0.72))
		var slash := V7aKit.box(holder, Vector3(st.disc * 0.82, 0.07, 0.02), Vector3(0, st.pole_h, 0.08), TrafficKit.mat(Color(0.85, 0.1, 0.1), 0.5))
		slash.rotation.z = -PI * 0.25
		_text(holder, "توقف ممنوع", "No parking", Vector3(0, st.pole_h - 0.48, 0.05), 0.0024, Color(0.1, 0.1, 0.1), 6)
		_count("no_parking")
	# Direction boards.
	for db: Dictionary in st.directions:
		var p4: Vector2 = db["pos"]
		var holder := Node3D.new()
		holder.name = "DirectionBoard"
		holder.position = TrafficKit.ground(p4)
		holder.rotation.y = deg_to_rad(float(db.get("yaw", 0.0)))
		add_child(holder)
		var lines: Array = db.get("lines", [])
		var hgt := 0.32 * lines.size() + 0.16
		var top := 2.5 + hgt
		for sx in [-1.25, 1.25]:
			V7aKit.cyl(holder, 0.05, top, Vector3(sx, top * 0.5, 0), TrafficKit.mat(Color(0.5, 0.52, 0.55), 0.4))
		V7aKit.box(holder, Vector3(2.9, hgt, 0.05), Vector3(0, 2.5 + hgt * 0.5, 0.03), TrafficKit.mat(Color(0.08, 0.36, 0.2), 0.5))
		V7aKit.box(holder, Vector3(2.96, hgt + 0.06, 0.03), Vector3(0, 2.5 + hgt * 0.5, 0.0), TrafficKit.mat(Color(0.95, 0.95, 0.95), 0.5))
		var k := 0
		for ln: Dictionary in lines:
			var y := 2.5 + hgt - 0.24 - k * 0.32
			_arrow(holder, Vector3(-1.22, y, 0.07), str(ln.get("arrow", "up")), Color.WHITE, 0.26)
			var txt := str(ln.get("fa", "")) + ("  " + str(ln.get("en", "")) if st.bilingual else "")
			var l := TrafficKit.label(holder, txt, "", Vector3(0.14, y, 0.07), 0.0, 0.0019, 48, Color.WHITE)
			l.remove_from_group(&"v7b_signs")
			k += 1
		_count("direction")


# ------------------------------------------------------------------ pieces
func _holder(p: Vector2, heading: Vector2, nm: String) -> Node3D:
	var holder := Node3D.new()
	holder.name = nm
	holder.position = TrafficKit.ground(p)
	holder.rotation.y = atan2(-heading.x, -heading.y)   # +z faces the oncoming drivers
	add_child(holder)
	return holder


func _pole(holder: Node3D, h: float) -> void:
	V7aKit.cyl(holder, 0.045, h, Vector3(0, h * 0.5, 0), TrafficKit.mat(Color(0.62, 0.64, 0.66), 0.4))


func _disc(holder: Node3D, p: Vector3, r: float, c: Color) -> MeshInstance3D:
	var d := V7aKit.cyl(holder, r, 0.03, p, TrafficKit.mat(c, 0.5))
	d.rotation.x = PI * 0.5
	return d


func _tri(holder: Node3D, p: Vector3, r: float, c: Color, point_down: bool) -> void:
	var t := V7aKit.cyl(holder, r, 0.03, p, TrafficKit.mat(c, 0.5))
	(t.mesh as CylinderMesh).radial_segments = 3
	t.rotation.x = PI * 0.5 if point_down else -PI * 0.5


func _arrow(holder: Node3D, p: Vector3, dirn: String, c: Color, size: float) -> void:
	var pivot := Node3D.new()
	pivot.position = p
	pivot.rotation.z = {"up": 0.0, "right": -PI * 0.5, "left": PI * 0.5, "down": PI}.get(dirn, 0.0)
	holder.add_child(pivot)
	var m := TrafficKit.mat(c, 0.5)
	V7aKit.box(pivot, Vector3(size * 0.16, size * 0.55, 0.02), Vector3(0, -size * 0.18, 0), m, false)
	var head := V7aKit.cyl(pivot, size * 0.3, 0.02, Vector3(0, size * 0.2, 0), m)
	(head.mesh as CylinderMesh).radial_segments = 3
	head.rotation.x = -PI * 0.5


func _text(holder: Node3D, fa: String, en: String, p: Vector3, px: float, c: Color, outline: int = 0) -> Label3D:
	var st := style()
	var txt := fa + ("\n" + en if st and st.bilingual and en != "" else "")
	var l := TrafficKit.label(holder, txt, "", p, 0.0, px, 64, c, outline)
	l.remove_from_group(&"v7b_signs")
	return l


func _limit_sign(p: Vector2, fwd: Vector2, kmh: float, road: String) -> void:
	var st := style()
	var holder := _holder(p, fwd, "SpeedLimit")
	_pole(holder, st.pole_h)
	_disc(holder, Vector3(0, st.pole_h, 0.04), st.disc * 0.5, Color(0.85, 0.1, 0.1))
	_disc(holder, Vector3(0, st.pole_h, 0.06), st.disc * 0.4, Color(0.98, 0.98, 0.98))
	var l := TrafficKit.label(holder, Lang.digits(str(int(kmh))), str(int(kmh)), Vector3(0, st.pole_h, 0.085), 0.0, 0.006, 64, Color(0.05, 0.05, 0.05))
	l.set_meta(&"limit", int(kmh))
	limit_signs.append({"pos": p, "kmh": int(kmh), "road": road})
	_count("limit")


func _school_sign(p: Vector2, fwd: Vector2) -> void:
	var st := style()
	var rules := TrafficKit.rules()
	var holder := _holder(p, fwd, "SchoolZone")
	_pole(holder, st.pole_h + 0.6)
	var dm := V7aKit.box(holder, Vector3(0.62, 0.62, 0.03), Vector3(0, st.pole_h + 0.45, 0.04), TrafficKit.mat(Color(0.98, 0.8, 0.1), 0.5))
	dm.rotation.z = PI * 0.25
	_text(holder, "مدرسه", "SCHOOL", Vector3(0, st.pole_h + 0.45, 0.07), 0.0026, Color(0.05, 0.05, 0.05))
	var kmh := rules.school_limit_kmh if rules else 25.0
	_disc(holder, Vector3(0, st.pole_h - 0.35, 0.04), st.disc * 0.45, Color(0.85, 0.1, 0.1))
	_disc(holder, Vector3(0, st.pole_h - 0.35, 0.06), st.disc * 0.36, Color(0.98, 0.98, 0.98))
	TrafficKit.label(holder, Lang.digits(str(int(kmh))), str(int(kmh)), Vector3(0, st.pole_h - 0.35, 0.085), 0.0, 0.0055, 64, Color(0.05, 0.05, 0.05))
	limit_signs.append({"pos": p, "kmh": int(kmh), "road": "school"})
	_count("school")


## Too close to a junction, in a building, on another road or in the square.
func _blocked(p: Vector2, road: Dictionary, junction_check: bool = true) -> bool:
	if TrafficKit.in_square(p):
		return true
	for b in TownLayout.BUILDINGS:
		if (b["pos"] as Vector2).distance_to(p) < 12.0 and TownLayout.footprint_distance(b, p, 0.4) < 0.0:
			return true
	for r: Dictionary in TrafficKit.paved():
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			var dd := q.distance_to(p)
			if dd < float(r["half"]) + 0.2:
				return true
			if junction_check and r["name"] != road["name"] and dd < float(r["half"]) + 9.0:
				return true
	return false
