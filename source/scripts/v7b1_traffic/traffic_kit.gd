class_name TrafficKit
extends RefCounted
## v7b.1 traffic helpers shared by the signals, rules, signs, markings, NPC
## traffic and the bus: street lookup, speed limits, junction arms (approaches
## with their stop lines), cached materials and small mesh / label builders.

const STOP_GAP := 0.6        ## stop line behind the zebra crossing
const ARM_MIN := 8.0         ## a junction arm must run at least this far
static var _mats: Dictionary = {}


static func rules() -> TrafficRulesStyle:
	return Modules.style("traffic_rules") as TrafficRulesStyle


static func paved() -> Array:
	var out: Array = []
	for r: Dictionary in TownLayout.ROADS:
		if str(r["kind"]) == "paved":
			out.append(r)
	return out


static func road_named(nm: String) -> Dictionary:
	for r: Dictionary in paved():
		if str(r["name"]) == nm:
			return r
	return {}


## Nearest paved street at p: {road, dist, dir (Vector2 along the segment), point}.
static func street_at(p: Vector2, margin: float = 0.6) -> Dictionary:
	var best := {}
	var bd := INF
	for r: Dictionary in paved():
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var q := Geometry2D.get_closest_point_to_segment(p, a, b)
			var d := q.distance_to(p)
			if d <= float(r["half"]) + margin and d < bd:
				bd = d
				best = {"road": r, "dist": d, "dir": (b - a).normalized(), "point": q}
	return best


static func in_square(p: Vector2) -> bool:
	return p.distance_to(TownLayout.TOWN_CENTER) < VehicleKit.SQUARE_RING + 3.2


static func in_school_zone(p: Vector2) -> bool:
	var st := rules()
	if st == null:
		return false
	return p.distance_to(Vector2(st.school_zone.x, st.school_zone.y)) < st.school_zone.z


## Speed limit (km/h) at p.
static func limit_kmh(p: Vector2) -> float:
	var st := rules()
	if st == null:
		return 40.0
	if in_school_zone(p) and street_at(p, 1.0).size() > 0:
		return st.school_limit_kmh
	if in_square(p):
		return st.square_limit_kmh
	var s := street_at(p, 1.0)
	if s.is_empty():
		return st.default_limit_kmh
	return float(st.speed_limits.get(str((s["road"] as Dictionary)["name"]), st.default_limit_kmh))


static func limit_for_road(nm: String) -> float:
	var st := rules()
	return float(st.speed_limits.get(nm, st.default_limit_kmh)) if st else 40.0


## Arms of a junction at c: [{heading (Vector2, towards c), from (Vector2 point on the arm), road,
## half, stop (distance of the stop line from c), dir_code ('n','s','e','w' = the side it comes from), axis}].
static func arms(c: Vector2) -> Array:
	var out: Array = []
	var through: Array = []
	for r: Dictionary in paved():
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var q := Geometry2D.get_closest_point_to_segment(c, a, b)
			if q.distance_to(c) < float(r["half"]) + 0.6:
				through.append([r, a, b])
	for k in through.size():
		var r: Dictionary = through[k][0]
		var a: Vector2 = through[k][1]
		var b: Vector2 = through[k][2]
		var d := (b - a).normalized()
		# Widest crossing street decides where the stop line goes.
		var other_half := 0.0
		for t in through:
			if (t[0] as Dictionary)["name"] != r["name"]:
				other_half = maxf(other_half, float((t[0] as Dictionary)["half"]))
		if other_half <= 0.0:
			continue
		var stop := other_half + TownBuilder.SIDEWALK_W + 1.3 + 1.2 + STOP_GAP
		for sgn: float in [-1.0, 1.0]:
			# Arm on side sgn: does the road run that far from c?
			var far := c + d * sgn * (stop + ARM_MIN)
			var on := Geometry2D.get_closest_point_to_segment(far, a, b).distance_to(far) < 0.5
			if not on:
				# The road may continue in the next segment / road entry with the same name.
				var s := street_at(far, 0.2)
				on = not s.is_empty() and (s["road"] as Dictionary)["name"] == r["name"]
			if not on:
				continue
			var heading := -d * sgn
			var dup := false
			for o: Dictionary in out:
				if (o["heading"] as Vector2).dot(heading) > 0.95:
					dup = true
			if dup:
				continue
			out.append({"heading": heading, "from": c - heading * (stop + 6.0), "road": str(r["name"]), "half": float(r["half"]),
				"stop": stop, "dir_code": dir_code(-heading), "axis": absf(d.x) > absf(d.y)})
	return out


## Compass letter for a direction in the map (x east, z south).
static func dir_code(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "e" if v.x > 0.0 else "w"
	return "s" if v.y > 0.0 else "n"


## Where a vehicle at p (heading fwd) stands relative to an arm: {s (m past the
## stop line, <0 before), lat (lateral from the arm axis, + = right lane side), align}.
static func arm_pos(arm: Dictionary, c: Vector2, p: Vector2, fwd: Vector2) -> Dictionary:
	var h: Vector2 = arm["heading"]
	var line_pt := c - h * float(arm["stop"])
	var rel := p - line_pt
	var right := Vector2(-h.y, h.x)
	return {"s": rel.dot(h), "lat": rel.dot(right), "align": fwd.normalized().dot(h) if fwd.length() > 0.01 else 0.0}


# ------------------------------------------------------------------ builders
static func mat(c: Color, rough: float = 0.8, emit: float = 0.0, unshaded: bool = false) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f|%s" % [c.to_html(), rough, emit, unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := V7aKit.mat(c, rough, emit)
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func label(parent: Node3D, text_fa: String, text_en: String, pos: Vector3, yaw: float, px: float = 0.004, font: int = 48,
		col: Color = Color.WHITE, outline: int = 0, flat: bool = false) -> Label3D:
	var l := Label3D.new()
	Lang.setup_label3d(l, font)
	l.pixel_size = px
	l.outline_size = outline
	l.modulate = col
	l.position = pos
	l.rotation.y = yaw
	if flat:
		l.rotation = Vector3(-PI * 0.5, yaw, 0)
	l.double_sided = false
	l.text = Lang.tt(text_fa, text_en) if text_en != "" else text_fa
	l.set_meta(&"fa", text_fa)
	l.set_meta(&"en", text_en if text_en != "" else text_fa)
	l.add_to_group(&"v7b_signs")
	parent.add_child(l)
	return l


## Flat quad (y up) from a to b with half width hw, lifted `lift` above the terrain.
static func paint_quad(st: SurfaceTool, a: Vector2, b: Vector2, hw: float, lift: float = 0.075) -> void:
	var d := (b - a)
	var length := d.length()
	if length < 0.01:
		return
	d /= length
	var n := Vector2(-d.y, d.x) * hw
	var steps := maxi(int(ceil(length / 2.0)), 1)
	for i in steps:
		var p0 := a + d * (length * i / steps)
		var p1 := a + d * (length * (i + 1) / steps)
		var c := [p0 - n, p0 + n, p1 + n, p1 - n]
		var v: Array[Vector3] = []
		for q: Vector2 in c:
			v.append(Vector3(q.x, Terrain.height_at(q.x, q.y) + lift, q.y))
		st.set_normal(Vector3.UP)
		st.add_vertex(v[0]); st.add_vertex(v[2]); st.add_vertex(v[1])
		st.add_vertex(v[0]); st.add_vertex(v[3]); st.add_vertex(v[2])


static func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)


## Dashboard part: "Limit 40" for the street the car is on ("" when off-road).
static func dash_limit_text(car: Node3D) -> String:
	if car == null or rules() == null:
		return ""
	var p := Vector2(car.global_position.x, car.global_position.z)
	if street_at(p, 1.5).is_empty() and not in_square(p):
		return ""
	var lim := int(limit_kmh(p))
	return Lang.tt("حداکثر سرعت %s" % Lang.digits(str(lim)), "Limit %d" % lim)
