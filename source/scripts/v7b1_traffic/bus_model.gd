class_name BusModel
extends RefCounted
## v7b.1 procedural bus body (transit vehicle module): box body with a dark
## window band, livery stripe, doors on the kerb (right) side, destination
## board "خط ۱", wheels, lights and bumpers. Local +Z = forward, wheels on y = 0.
## Returns [holder "Model", size] like VehicleKit.model().

static func build(spec: Dictionary, line_fa: String = "خط ۱", line_en: String = "Line 1") -> Array:
	var L := float(spec.get("length", 9.6))
	var W := float(spec.get("width", 2.5))
	var H := float(spec.get("height", 3.0))
	var body := _c(spec.get("color", Color(0.1, 0.45, 0.62)))
	var stripe := _c(spec.get("stripe", Color(0.96, 0.82, 0.25)))
	var holder := Node3D.new()
	holder.name = "Model"
	holder.set_meta(&"procedural", true)
	holder.set_meta(&"paint_name", "bus")
	holder.set_meta(&"kind", "bus")
	var paint := V7aKit.mat(body, 0.45)
	paint.metallic = 0.2
	var glass := V7aKit.mat(Color(0.12, 0.16, 0.2), 0.08)
	glass.metallic = 0.4
	var dark := V7aKit.mat(Color(0.08, 0.08, 0.09), 0.7)
	var floor_y := 0.42
	# Body + roof.
	V7aKit.box(holder, Vector3(W, H - floor_y - 0.12, L), Vector3(0, floor_y + (H - floor_y - 0.12) * 0.5, 0), paint)
	V7aKit.box(holder, Vector3(W - 0.16, 0.14, L - 0.5), Vector3(0, H - 0.05, -0.1), V7aKit.mat(body.lightened(0.25), 0.5))
	# Window band (both sides) + windscreen + rear window.
	for sx: float in [-1.0, 1.0]:
		V7aKit.box(holder, Vector3(0.04, 1.0, L - 1.6), Vector3(sx * (W * 0.5 + 0.005), H - 1.05, -0.3), glass, false)
		V7aKit.box(holder, Vector3(0.04, 0.22, L - 0.2), Vector3(sx * (W * 0.5 + 0.01), floor_y + 0.75, 0), V7aKit.mat(stripe, 0.5), false)
		# Window pillars.
		var n := int((L - 1.6) / 1.3)
		for k in n + 1:
			V7aKit.box(holder, Vector3(0.05, 1.0, 0.09), Vector3(sx * (W * 0.5 + 0.02), H - 1.05, -0.3 - (L - 1.6) * 0.5 + k * (L - 1.6) / n), paint, false)
	V7aKit.box(holder, Vector3(W - 0.2, 1.45, 0.05), Vector3(0, H - 1.25, L * 0.5 + 0.005), glass, false)
	V7aKit.box(holder, Vector3(W - 0.5, 0.7, 0.05), Vector3(0, H - 1.0, -L * 0.5 - 0.005), glass, false)
	# Doors on the right (kerb) side: local -X is the right side (+X = driver's left).
	for dz: float in [L * 0.5 - 1.1, -0.6]:
		V7aKit.box(holder, Vector3(0.05, H - floor_y - 0.45, 1.1), Vector3(-W * 0.5 - 0.01, floor_y + (H - floor_y - 0.45) * 0.5 + 0.05, dz), glass, false)
		V7aKit.box(holder, Vector3(0.06, H - floor_y - 0.4, 0.06), Vector3(-W * 0.5 - 0.02, floor_y + (H - floor_y - 0.4) * 0.5, dz), dark, false)
	# Destination board.
	V7aKit.box(holder, Vector3(W - 0.6, 0.3, 0.04), Vector3(0, H - 0.32, L * 0.5 + 0.03), V7aKit.mat(Color(0.05, 0.05, 0.05), 0.3), false)
	var l := Label3D.new()
	Lang.setup_label3d(l, 48)
	l.pixel_size = 0.004
	l.modulate = Color(1.0, 0.7, 0.15)
	l.text = "%s  %s" % [line_fa, line_en]
	l.position = Vector3(0, H - 0.32, L * 0.5 + 0.06)
	holder.add_child(l)
	# Bumpers, lights.
	V7aKit.box(holder, Vector3(W + 0.04, 0.3, 0.16), Vector3(0, floor_y + 0.05, L * 0.5 + 0.02), dark, false)
	V7aKit.box(holder, Vector3(W + 0.04, 0.3, 0.16), Vector3(0, floor_y + 0.05, -L * 0.5 - 0.02), dark, false)
	for sx: float in [-1.0, 1.0]:
		V7aKit.box(holder, Vector3(0.32, 0.16, 0.05), Vector3(sx * (W * 0.5 - 0.3), floor_y + 0.4, L * 0.5 + 0.02), V7aKit.mat(Color(1.0, 0.97, 0.85), 0.2, 1.5), false)
		V7aKit.box(holder, Vector3(0.24, 0.3, 0.05), Vector3(sx * (W * 0.5 - 0.25), floor_y + 0.55, -L * 0.5 - 0.02), V7aKit.mat(Color(0.8, 0.05, 0.05), 0.3, 0.8), false)
	# Wheels (2 axles).
	var tyre := V7aKit.mat(Color(0.06, 0.06, 0.06), 0.9)
	var rim := V7aKit.mat(Color(0.7, 0.72, 0.75), 0.3)
	for z: float in [L * 0.5 - 1.9, -L * 0.5 + 2.1]:
		for sx: float in [-1.0, 1.0]:
			var w := V7aKit.cyl(holder, 0.5, 0.32, Vector3(sx * (W * 0.5 - 0.18), 0.5, z), tyre)
			w.rotation.z = PI * 0.5
			var r := V7aKit.cyl(holder, 0.28, 0.34, Vector3(sx * (W * 0.5 - 0.18), 0.5, z), rim)
			r.rotation.z = PI * 0.5
	# Interior seats (seen through the glass).
	var seat := V7aKit.mat(Color(0.25, 0.3, 0.45), 0.8)
	var rows := int((L - 3.0) / 0.9)
	for k in rows:
		for sx: float in [-0.65, 0.65]:
			V7aKit.box(holder, Vector3(0.8, 0.45, 0.45), Vector3(sx, floor_y + 0.55, L * 0.5 - 2.4 - k * 0.9), seat, false)
	return [holder, Vector3(W, H, L)]


static func _c(v: Variant) -> Color:
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		return Color(float(v[0]), float(v[1]), float(v[2]))
	return Color.WHITE
