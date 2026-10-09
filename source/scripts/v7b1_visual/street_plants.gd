class_name StreetPlants
extends Node3D
## v7b.1 "street_plants" module (swappable plant set): street trees (plane,
## cypress, olive, jacaranda), shrubs (boxwood, lavender), flower clumps
## (rose, marigold) and planters (stone, clay) along the sidewalks of every
## paved street, plus low planting on the square's flower beds instead of the
## old coloured balls (which read as ice-cream scoops on the ground).
## Everything is a handful of MultiMeshes with per-instance colour (one draw
## call per part). Placement keeps clear of the asphalt (half + road_margin),
## road markings, junctions, traffic lights / signs, the traffic worker's
## street lights, doors and buildings.

var plant_points: Array = []   ## [Vector3 world, species id]
var _built := false


static func style() -> StreetPlantsStyle:
	return Modules.style("street_plants") as StreetPlantsStyle


## Old flower balls / planters are replaced by this module.
static func replaces_old() -> bool:
	var st := style()
	return st != null and st.enabled and st.clear_old_flowers


## True when a prop at p (x, z) would stand on (or within 0.3 m of) asphalt.
static func on_asphalt(p: Vector2, margin: float = 0.3) -> bool:
	for r: Dictionary in TownLayout.ROADS:
		if str(r.get("kind", "")) != "paved":
			continue
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			if Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p) < float(r["half"]) + margin:
				return true
	return false


func _ready() -> void:
	name = "StreetPlants"
	Modules.on_swap("street_plants", self, func(_m: Resource) -> void: rebuild())


## Built after the town + the traffic layer exist (V7b1Visual calls this deferred).
func rebuild() -> void:
	for c in get_children():
		c.free()
	plant_points.clear()
	_built = true
	var st := style()
	if st == null or not st.enabled or st.species.is_empty():
		_square_beds(false)
		return
	var avoid := _avoid_points()
	var trees: Array = []
	var small: Array = []
	for s: Dictionary in st.species:
		if str(s.get("kind", "")) == "tree":
			trees.append(s)
		else:
			small.append(s)
	var placed: Array = []
	var idx := 0
	for r: Dictionary in TownLayout.ROADS:
		if str(r.get("kind", "")) != "paved":
			continue
		var half := float(r["half"])
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var length := a.distance_to(b)
			if length < 2.0:
				continue
			var d := (b - a) / length
			var n := Vector2(-d.y, d.x)
			for side: float in [-1.0, 1.0]:
				var t := 4.0 + (st.tree_spacing * 0.5 if side > 0.0 else 0.0)
				while t < length - 2.0:
					# Trees in the outer half of the sidewalk, shrubs / planters between them.
					var tree_p := a + d * t + n * side * (half + st.road_margin + st.sidewalk * 0.62)
					if not trees.is_empty() and _free(tree_p, r, avoid, placed, 3.2):
						var sp: Dictionary = trees[absi(hash("%d" % idx)) % trees.size()]
						placed.append([tree_p, sp])
						idx += 1
					var mid := t + st.tree_spacing * 0.5
					if not small.is_empty() and mid < length - 2.0:
						var sp2: Dictionary = small[absi(hash("s%d" % idx)) % small.size()]
						var off := half + st.road_margin + st.sidewalk * (0.8 if str(sp2.get("kind", "")) != "planter" else 0.62)
						var bush_p := a + d * mid + n * side * off
						if _free(bush_p, r, avoid, placed, 1.6):
							placed.append([bush_p, sp2])
							idx += 1
					t += st.tree_spacing
	_build_meshes(placed)
	_square_beds(true)


func _avoid_points() -> Array:
	var out: Array = []
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene == null:
		return out
	var town := scene.get_node_or_null(^"Town")
	if town and "lamp_positions" in town:
		for p: Vector3 in town.get("lamp_positions"):
			out.append([Vector2(p.x, p.z), 1.6])
	var lighting := scene.find_child("StreetLighting", true, false)
	if lighting and "lamp_points" in lighting:
		for p: Vector3 in lighting.get("lamp_points"):
			out.append([Vector2(p.x, p.z), 1.8])
	for nm in ["TrafficSigns", "TrafficSignals", "RoadMarkings"]:
		var holder := scene.find_child(nm, true, false) as Node3D
		if holder == null:
			continue
		for c in holder.get_children():
			if c is Node3D and not (c is MultiMeshInstance3D) and not (c is MeshInstance3D and nm == "RoadMarkings"):
				var g := (c as Node3D).global_position
				out.append([Vector2(g.x, g.z), 1.6])
	var rules := Modules.style("traffic_rules")
	if rules and "signals" in rules:
		for s: Dictionary in rules.get("signals"):
			out.append([s.get("pos", Vector2.ZERO), 9.5])
	for s: Array in TownLayout.STREET_SIGNS:
		out.append([s[0], 1.6])
	for g in get_tree().get_nodes_in_group(&"parked_cars"):
		if g is Node3D:
			out.append([Vector2((g as Node3D).global_position.x, (g as Node3D).global_position.z), 3.0])
	return out


func _free(p: Vector2, road: Dictionary, avoid: Array, placed: Array, min_d: float) -> bool:
	var st := style()
	if not TownLayout.PLAY_AREA.grow(-1.0).has_point(p):
		return false
	if p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 5.0:
		return false
	if TownLayout.MARKET_RECT.grow(1.0).has_point(p):
		return false
	for a: Array in avoid:
		if (a[0] as Vector2).distance_to(p) < float(a[1]):
			return false
	for q: Array in placed:
		if (q[0] as Vector2).distance_to(p) < min_d:
			return false
	for b in TownLayout.BUILDINGS:
		if (b["pos"] as Vector2).distance_to(p) < 16.0 and TownLayout.footprint_distance(b, p, 0.5) < 0.0:
			return false
		var dp := TownLayout.door_point(b, 2.0)
		if Vector2(dp.x, dp.z).distance_to(p) < 2.6:
			return false
	for r: Dictionary in TownLayout.ROADS:
		var pts: Array = r["points"]
		for i in pts.size() - 1:
			var dd := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1]).distance_to(p)
			if dd < float(r["half"]) + st.road_margin:
				return false
			# Keep junctions (crossings, stop lines, signals) clear.
			if str(r.get("kind", "")) == "paved" and r["name"] != road.get("name", "") and dd < float(r["half"]) + st.sidewalk + 4.0:
				return false
	if TownLayout.sea_distance(p.x, p.y) > -2.0 or TownLayout.river_distance(p) < TownLayout.RIVER_HALF + 1.5:
		return false
	return true


# ------------------------------------------------------------------ meshes
func _mat(vertex_col: bool = true, rough: float = 0.9) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = vertex_col
	m.roughness = rough
	return m


func _mm(mesh: Mesh, xf: Array, cols: Array, mat: Material, nm: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		mm.set_instance_color(i, cols[i] if i < cols.size() else Color.WHITE)
	var mi := MultiMeshInstance3D.new()
	mi.name = nm
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if nm.begins_with("Tree") else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 150.0
	mi.add_to_group(&"street_plants")
	add_child(mi)
	return mi


func _sphere(seg: int, rings: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = 0.5
	s.height = 1.0
	s.radial_segments = seg
	s.rings = rings
	return s


func _build_meshes(placed: Array) -> void:
	var trunk_xf: Array = []
	var trunk_c: Array = []
	var crown_xf: Array = []
	var crown_c: Array = []
	var cone_xf: Array = []
	var cone_c: Array = []
	var bush_xf: Array = []
	var bush_c: Array = []
	var bloom_xf: Array = []
	var bloom_c: Array = []
	var pot_xf: Array = []
	var pot_c: Array = []
	var pit_xf: Array = []
	var pit_c: Array = []
	for q: Array in placed:
		var p: Vector2 = q[0]
		var sp: Dictionary = q[1]
		var y := Terrain.height_at(p.x, p.y)
		var base := Vector3(p.x, y, p.y)
		var s := float(sp.get("size", 1.0))
		var col: Color = sp.get("color", Color(0.25, 0.45, 0.22))
		var h := absi(hash(str(p)))
		var jitter := 0.9 + float(h % 100) / 500.0
		var yaw := float(h % 628) / 100.0
		plant_points.append([base, str(sp.get("id", ""))])
		match str(sp.get("kind", "")):
			"tree":
				var th := 2.2 * s * jitter
				trunk_xf.append(Transform3D(Basis.from_scale(Vector3(0.22 * s, th, 0.22 * s)), base + Vector3(0, th * 0.5, 0)))
				trunk_c.append(sp.get("trunk", Color(0.4, 0.28, 0.16)))
				pit_xf.append(Transform3D(Basis.from_scale(Vector3(1.1, 0.06, 1.1)), base + Vector3(0, 0.02, 0)))
				pit_c.append(Color(0.24, 0.18, 0.12))
				if str(sp.get("shape", "")) == "cone":
					cone_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.3 * s, 4.2 * s * jitter, 1.3 * s)), base + Vector3(0, th * 0.55 + 2.1 * s * jitter, 0)))
					cone_c.append(col)
				else:
					for k in 3:
						var a := yaw + k * 2.1
						var off := Vector3(cos(a), 0, sin(a)) * 0.55 * s
						var r := (1.9 - k * 0.3) * s * jitter
						crown_xf.append(Transform3D(Basis(Vector3.UP, a).scaled(Vector3(r, r * 0.85, r)), base + Vector3(0, th + 0.6 * s + k * 0.35 * s, 0) + off))
						crown_c.append(col.lightened(0.04 * k) if k != 1 else col.darkened(0.06))
			"bush":
				for k in 2:
					var off2 := Vector3(cos(yaw + k * 3.0), 0, sin(yaw + k * 3.0)) * 0.22
					bush_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.6 * s, 1.2 * s, 1.4 * s)), base + Vector3(0, 0.45 * s, 0) + off2))
					bush_c.append(col if k == 0 else col.darkened(0.08))
			"flowers":
				# A low leafy clump with a blossom-coloured top (no loose balls).
				bush_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.9 * s, 0.9 * s, 1.5 * s)), base + Vector3(0, 0.25 * s, 0)))
				bush_c.append(Color(0.22, 0.42, 0.2))
				bloom_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(1.7 * s, 0.35 * s, 1.3 * s)), base + Vector3(0, 0.5 * s, 0)))
				bloom_c.append(col)
			"planter":
				pot_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s, s * 0.6, s)), base + Vector3(0, s * 0.3, 0)))
				pot_c.append(col)
				bush_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s * 0.95, s * 0.6, s * 0.95)), base + Vector3(0, s * 0.68, 0)))
				bush_c.append(Color(0.24, 0.46, 0.22))
				bloom_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(s * 0.8, s * 0.22, s * 0.8)), base + Vector3(0, s * 0.92, 0)))
				bloom_c.append(sp.get("plant", Color(0.9, 0.3, 0.4)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.35
	trunk.bottom_radius = 0.5
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	_mm(trunk, trunk_xf, trunk_c, _mat(), "TreeTrunks")
	_mm(_sphere(8, 5), crown_xf, crown_c, _mat(), "TreeCrowns")
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 8
	cone.rings = 2
	_mm(cone, cone_xf, cone_c, _mat(), "TreeCypress")
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	_mm(box, pit_xf, pit_c, _mat(true, 1.0), "TreePits")
	_mm(_sphere(8, 4), bush_xf, bush_c, _mat(), "Shrubs")
	_mm(_sphere(8, 3), bloom_xf, bloom_c, _mat(true, 0.7), "Blooms")
	var pot := CylinderMesh.new()
	pot.top_radius = 0.5
	pot.bottom_radius = 0.38
	pot.height = 1.0
	pot.radial_segments = 8
	_mm(pot, pot_xf, pot_c, _mat(true, 0.85), "Planters")


## The square's four flower beds: hide the old coloured balls and plant low
## shrubs with a band of blossom on each bed instead (children of TownSquare,
## placed from the FlowerBeds MultiMesh so they sit exactly on the beds).
func _square_beds(plant: bool) -> void:
	var scene := get_tree().current_scene if is_inside_tree() else null
	var sq: Node3D = scene.find_child("TownSquare", true, false) as Node3D if scene else null
	if sq == null:
		return
	for old_name in ["SquareBedShrubs", "SquareBedBlooms"]:
		var o := sq.get_node_or_null(NodePath(old_name))
		if o:
			o.free()
	var old := sq.find_child("Flowers", false, false) as Node3D
	if old:
		old.visible = not replaces_old()
	if not plant or not replaces_old():
		return
	var beds := sq.find_child("FlowerBeds", false, false) as MultiMeshInstance3D
	if beds == null or beds.multimesh == null:
		return
	var st := style()
	var flowers: Array = []
	for s: Dictionary in st.species:
		if str(s.get("kind", "")) in ["flowers", "bush"]:
			flowers.append(s)
	var bush_xf: Array = []
	var bush_c: Array = []
	var bloom_xf: Array = []
	var bloom_c: Array = []
	for k in beds.multimesh.instance_count:
		var bt := beds.multimesh.get_instance_transform(k)
		var along := bt.basis.x.normalized()
		var sx := bt.basis.x.length()
		var top := bt.origin + Vector3(0, bt.basis.y.length() * 0.5, 0)
		var sp: Dictionary = flowers[k % flowers.size()] if not flowers.is_empty() else {}
		var n := 4
		for i in n:
			var off := along * (float(i) - (n - 1) * 0.5) * (sx / float(n))
			var yaw := atan2(along.x, along.z)
			bush_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.52, 0.34, 0.62)), top + off + Vector3(0, 0.1, 0)))
			bush_c.append(Color(0.22, 0.42, 0.2) if i % 2 == 0 else Color(0.2, 0.38, 0.19))
			bloom_xf.append(Transform3D(Basis(Vector3.UP, yaw).scaled(Vector3(0.46, 0.12, 0.52)), top + off + Vector3(0, 0.25, 0)))
			bloom_c.append(sp.get("color", Color(0.85, 0.2, 0.3)) if i % 2 == 0 else (sp.get("color", Color(0.85, 0.2, 0.3)) as Color).lightened(0.25))
	var a1 := _mm(_sphere(8, 4), bush_xf, bush_c, _mat(), "SquareBedShrubs")
	var a2 := _mm(_sphere(8, 3), bloom_xf, bloom_c, _mat(true, 0.7), "SquareBedBlooms")
	for m: MultiMeshInstance3D in [a1, a2]:
		m.reparent(sq, false)
		m.add_to_group(&"square_plants")


## Species variety count (smoke test).
func species_count() -> int:
	var seen := {}
	for q: Array in plant_points:
		seen[q[1]] = true
	return seen.size()
