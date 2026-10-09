class_name RoadMarkings
extends Node3D
## v7b.1 road_markings module: stop lines at the signals and STOP signs, solid
## (yellow) centre lines before junctions, lane edge lines, Main St parking
## bays, straight-ahead arrows before the signals, give-way triangles at the
## roundabout entries and "مدرسه / SCHOOL" painted by the school. Dashed
## centre lines and zebra crossings come from TownBuilder. Two merged meshes.

const LIFT := 0.068

var white_mesh: MeshInstance3D
var yellow_mesh: MeshInstance3D
var stop_lines: int = 0
var signals: TrafficSignals


func style() -> RoadMarkingStyle:
	return Modules.style("road_markings") as RoadMarkingStyle


func _ready() -> void:
	rebuild.call_deferred()
	Modules.on_swap("road_markings", self, func(_m: Resource) -> void: rebuild())
	Modules.on_swap("traffic_rules", self, func(_m: Resource) -> void: rebuild.call_deferred())


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.75
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	stop_lines = 0
	var st := style()
	var rules := TrafficKit.rules()
	if st == null:
		return
	var w := SurfaceTool.new()
	w.begin(Mesh.PRIMITIVE_TRIANGLES)
	var y := SurfaceTool.new()
	y.begin(Mesh.PRIMITIVE_TRIANGLES)
	var juncs: Array = []   # [pos, arms]
	if rules:
		for s: Dictionary in rules.signals:
			juncs.append([s["pos"], TrafficKit.arms(s["pos"]), true])
		for s: Dictionary in rules.stops:
			var want: Array = s.get("approaches", [])
			var arms: Array = []
			for a: Dictionary in TrafficKit.arms(s["pos"]):
				if str(a["dir_code"]) in want:
					arms.append(a)
			juncs.append([s["pos"], arms, false])
	# Stop lines (right half of the approach) + solid centre + arrows.
	for j: Array in juncs:
		var c: Vector2 = j[0]
		for a: Dictionary in j[1]:
			var h: Vector2 = a["heading"]
			var right := Vector2(-h.y, h.x)
			var half := float(a["half"])
			var line_pt := c - h * float(a["stop"])
			TrafficKit.paint_quad(w, line_pt + right * 0.1, line_pt + right * (half - 0.25), st.stop_line_w * 0.5, LIFT)
			stop_lines += 1
			# Solid centre line before the stop line (both sides of the double line).
			for off: float in [-0.12, 0.12]:
				TrafficKit.paint_quad(y, line_pt - h * st.solid_near_junction + right * off, line_pt + right * off, 0.06, LIFT + 0.002)
			if st.arrows and bool(j[2]):
				_arrow(w, line_pt - h * 6.5 + right * half * 0.5, h)
	# Edge lines + parking bays along every paved street.
	for r: Dictionary in TrafficKit.paved():
		var half := float(r["half"])
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			var d := (b - a) / length
			var n := Vector2(-d.y, d.x)
			var t := 0.0
			while t < length - 0.5:
				var t1 := minf(t + 2.0, length)
				var mid := a + d * ((t + t1) * 0.5)
				var main_st := str(r["name"]) == "Main St"
				for side: float in [-1.0, 1.0]:
					var off := side * (half - st.edge_offset)
					if main_st and st.parking_bays:
						off = side * (half - 1.9)   # lane edge = inner edge of the parking strip
					var pe := mid + n * off
					if st.edge_lines and not _near_junction(pe, r, juncs) and not TrafficKit.in_square(pe):
						TrafficKit.paint_quad(w, a + d * t + n * off, a + d * t1 + n * off, st.line_w * 0.5, LIFT)
				t = t1
			# Parking bay ticks on Main St.
			if str(r["name"]) == "Main St" and st.parking_bays:
				var k := 3.0
				while k < length - 3.0:
					for side: float in [-1.0, 1.0]:
						var p0 := a + d * k + n * side * (half - 1.9)
						var p1 := a + d * k + n * side * (half - 0.15)
						if not _near_junction(p0, r, juncs) and not TrafficKit.in_square(p0) and not _bus_or_noparking(p0):
							TrafficKit.paint_quad(w, p0, p1, st.line_w * 0.5, LIFT)
					k += st.bay_length
	# Give-way triangles where streets enter the roundabout.
	for r: Dictionary in TrafficKit.paved():
		var pts: Array = r["points"]
		for e: Vector2 in [pts[0], pts[pts.size() - 1]]:
			if e.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 2.5:
				var into := (TownLayout.TOWN_CENTER - e).normalized()
				var right := Vector2(-into.y, into.x)
				var line_pt := e - into * 0.8
				var half := float(r["half"])
				var s := 0.6
				while s < half - 0.3:
					_triangle(w, line_pt + right * s, into, 0.32, 0.55)
					s += 0.85
	# School text.
	if not st.school_text.is_empty():
		var p: Vector2 = st.school_text.get("pos", Vector2.ZERO)
		var l := TrafficKit.label(self, str(st.school_text.get("fa", "مدرسه")), "", Vector3(p.x, Terrain.height_at(p.x, p.y) + LIFT + 0.01, p.y),
			deg_to_rad(float(st.school_text.get("yaw", 0.0))), 0.012, 64, st.paint, 0, true)
		l.name = "SchoolText"
		l.remove_from_group(&"v7b_signs")
		var l2 := TrafficKit.label(self, str(st.school_text.get("en", "SCHOOL")), "", Vector3(p.x, Terrain.height_at(p.x, p.y) + LIFT + 0.01, p.y) + Vector3(-1.4, 0, 0).rotated(Vector3.UP, deg_to_rad(float(st.school_text.get("yaw", 0.0)) )),
			deg_to_rad(float(st.school_text.get("yaw", 0.0))), 0.01, 64, st.paint, 0, true)
		l2.remove_from_group(&"v7b_signs")
	white_mesh = _commit(w, "MarkingsWhite", _mat(st.paint))
	yellow_mesh = _commit(y, "MarkingsYellow", _mat(st.center_paint))


func _commit(s: SurfaceTool, nm: String, m: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = nm
	mi.mesh = s.commit()
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


func _near_junction(p: Vector2, road: Dictionary, juncs: Array) -> bool:
	for r: Dictionary in TrafficKit.paved():
		if r["name"] == road["name"]:
			continue
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
			if q.distance_to(p) < float(r["half"]) + TownBuilder.SIDEWALK_W + 3.2:
				return true
	return false


func _bus_or_noparking(p: Vector2) -> bool:
	var ts := Modules.style("traffic_signs") as TrafficSignStyle
	if ts:
		for np: Dictionary in ts.no_parking:
			if (np["pos"] as Vector2).distance_to(p) < 9.0:
				return true
	var tr := Modules.style("transit") as TransitStyle
	if tr:
		for s: Dictionary in tr.line.get("stops", []):
			if (s["pos"] as Vector2).distance_to(p) < 9.0:
				return true
	return false


func _arrow(s: SurfaceTool, p: Vector2, h: Vector2) -> void:
	# Straight-ahead arrow: shaft + head.
	TrafficKit.paint_quad(s, p - h * 1.6, p + h * 0.6, 0.12, LIFT)
	_triangle(s, p + h * 0.6, h, 0.45, 0.9)


func _triangle(s: SurfaceTool, base: Vector2, h: Vector2, hw: float, length: float) -> void:
	var r := Vector2(-h.y, h.x)
	var pts := [base - r * hw, base + r * hw, base + h * length]
	var v: Array[Vector3] = []
	for q: Vector2 in pts:
		v.append(Vector3(q.x, Terrain.height_at(q.x, q.y) + LIFT, q.y))
	s.set_normal(Vector3.UP)
	s.add_vertex(v[0]); s.add_vertex(v[2]); s.add_vertex(v[1])
