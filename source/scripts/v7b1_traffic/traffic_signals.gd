class_name TrafficSignals
extends Node3D
## v7b.1 traffic lights (traffic_rules module): signalised junctions with real
## cycles - green, yellow, all-red, then the cross street - and actuation (a
## vehicle waiting at red for ~min_red_wait_s gets the green soon after).
## Every arm has a pole with a 3-lamp head facing the drivers; red-light
## cameras flash when someone runs the red; a traffic officer in white gloves
## directs traffic at the main junction. STOP-sign junctions are listed too
## (TrafficRules enforces the full stop).

## id -> {pos: Vector2, arms: [...], axis: bool (green axis), stage, t, wait, heads: [...], camera, officer}
var junctions: Dictionary = {}
## STOP junctions: id -> {pos, arms (only the arms with a STOP sign)}
var stops: Dictionary = {}
var cameras: Array = []           ## {pos: Vector3, flash: OmniLight3D, lens: MeshInstance3D, t}
var officer: HumanoidModelVisual
var officer_pos: Vector3 = Vector3.INF
var auto: bool = true              ## cycles run (tests may freeze them)
var _t_officer: float = 0.0
var _rng := RandomNumberGenerator.new()


func style() -> TrafficRulesStyle:
	return TrafficKit.rules()


func _ready() -> void:
	_rng.randomize()
	rebuild()
	Modules.on_swap("traffic_rules", self, func(_m: Resource) -> void: rebuild())


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	junctions.clear()
	stops.clear()
	cameras.clear()
	officer = null
	var st := style()
	if st == null:
		return
	var k := 0
	for s: Dictionary in st.signals:
		var c: Vector2 = s["pos"]
		var arms := TrafficKit.arms(c)
		var j := {"id": str(s["id"]), "pos": c, "arms": arms, "axis": true, "stage": "green", "t": 0.0 + k * 4.0, "wait": 0.0,
			"heads": [], "camera": bool(s.get("camera", false)), "officer": bool(s.get("officer", false)), "en": str(s.get("en", "")), "fa": str(s.get("fa", ""))}
		# Start with the busier (horizontal) street green; stagger the junctions.
		junctions[j["id"]] = j
		_build_heads(j)
		if j["camera"]:
			_build_camera(c, arms, str(s["id"]))
		if j["officer"]:
			_build_officer(c, arms)
		k += 1
	for s: Dictionary in st.stops:
		var c2: Vector2 = s["pos"]
		var want: Array = s.get("approaches", [])
		var arms2: Array = []
		for a: Dictionary in TrafficKit.arms(c2):
			if str(a["dir_code"]) in want:
				arms2.append(a)
		stops[str(s["id"])] = {"id": str(s["id"]), "pos": c2, "arms": arms2, "en": str(s.get("en", "")), "fa": str(s.get("fa", ""))}
	for sc: Dictionary in st.speed_cameras:
		var p: Vector2 = sc["pos"]
		var holder := Node3D.new()
		holder.position = TrafficKit.ground(p)
		holder.rotation.y = deg_to_rad(float(sc.get("yaw", 0.0)))
		add_child(holder)
		_camera_pole(holder, "speed")


# ------------------------------------------------------------------ cycle
func light_for(j: Dictionary, arm: Dictionary) -> String:
	if bool(arm["axis"]) != bool(j["axis"]):
		return "red"
	match str(j["stage"]):
		"green":
			return "green"
		"yellow":
			return "yellow"
	return "red"


## Light an arbitrary vehicle sees at junction id, given where it is heading.
func light_at(id: String, heading: Vector2) -> String:
	var j: Dictionary = junctions.get(id, {})
	for a: Dictionary in j.get("arms", []):
		if (a["heading"] as Vector2).dot(heading.normalized()) > 0.7:
			return light_for(j, a)
	return "green"


func set_green(id: String, horizontal: bool) -> void:
	var j: Dictionary = junctions.get(id, {})
	if j.is_empty():
		return
	j["axis"] = horizontal
	j["stage"] = "green"
	j["t"] = 0.0
	j["wait"] = 0.0
	_paint(j)


## Force the arm a vehicle with `heading` uses to red (cross street green).
func set_red_for(id: String, heading: Vector2) -> void:
	set_green(id, absf(heading.y) > absf(heading.x))


## A vehicle reports it is waiting at red at junction id (actuation).
func report_wait(id: String, seconds: float) -> void:
	var j: Dictionary = junctions.get(id, {})
	if not j.is_empty():
		j["wait"] = maxf(float(j["wait"]), seconds)


func _process(delta: float) -> void:
	var st := style()
	if st == null:
		return
	for id in junctions:
		var j: Dictionary = junctions[id]
		if auto:
			j["t"] = float(j["t"]) + delta
			var t := float(j["t"])
			match str(j["stage"]):
				"green":
					# Actuation: a driver waiting at red gets green after about
					# min_red_wait_s in total (the cross street's yellow + all-red included).
					var trigger := maxf(st.min_red_wait_s - st.yellow_s - st.all_red_s, 0.3)
					var waited := float(j["wait"]) >= trigger and t > 4.0
					if t >= st.green_s or waited:
						j["stage"] = "yellow"
						j["t"] = 0.0
				"yellow":
					if t >= st.yellow_s:
						j["stage"] = "allred"
						j["t"] = 0.0
				"allred":
					if t >= st.all_red_s:
						j["stage"] = "green"
						j["axis"] = not bool(j["axis"])
						j["t"] = 0.0
						j["wait"] = 0.0
		# Waiting reports fade if nobody keeps reporting.
		j["wait"] = maxf(float(j["wait"]) - delta * 0.5, 0.0)
		_paint(j)
	_tick_cameras(delta)
	_tick_officer(delta)


# ------------------------------------------------------------------ heads
func _build_heads(j: Dictionary) -> void:
	var c: Vector2 = j["pos"]
	var pole := TrafficKit.mat(Color(0.16, 0.17, 0.18), 0.5)
	var housing := TrafficKit.mat(Color(0.08, 0.08, 0.09), 0.6)
	for a: Dictionary in j["arms"]:
		var h: Vector2 = a["heading"]
		var right := Vector2(-h.y, h.x)
		# Pole on the right kerb just before the stop line, head faces the drivers.
		var p := c - h * (float(a["stop"]) - 0.6) + right * (float(a["half"]) + 0.6)
		var holder := Node3D.new()
		holder.name = "Signal_%s_%s" % [j["id"], a["dir_code"]]
		holder.position = TrafficKit.ground(p)
		holder.rotation.y = atan2(-h.x, -h.y)   # +z of the holder points against the traffic
		add_child(holder)
		V7aKit.cyl(holder, 0.08, 3.4, Vector3(0, 1.7, 0), pole)
		# Mast arm reaching over the lane.
		var arm_len := float(a["half"]) * 0.55 + 0.6
		V7aKit.box(holder, Vector3(arm_len, 0.09, 0.09), Vector3(arm_len * 0.5, 3.3, 0), pole).rotation.y = PI
		var lamps: Array = []
		for hp: Vector3 in [Vector3(0, 2.3, 0.12), Vector3(arm_len * -1.0 + 0.2, 3.0, 0.0)]:
			V7aKit.box(holder, Vector3(0.36, 1.0, 0.26), hp + Vector3(0, 0, 0), housing)
			var lset := []
			for i in 3:
				var col: Color = [Color(1.0, 0.12, 0.08), Color(1.0, 0.72, 0.05), Color(0.1, 1.0, 0.35)][i]
				var m := V7aKit.mat(col.darkened(0.7), 0.4, 0.0)
				m.emission_enabled = true
				m.emission = col
				m.emission_energy_multiplier = 0.0
				var bulb := MeshInstance3D.new()
				var sm := SphereMesh.new()
				sm.radius = 0.11
				sm.height = 0.12
				bulb.mesh = sm
				bulb.material_override = m
				bulb.position = hp + Vector3(0, 0.3 - i * 0.3, 0.13)
				bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				holder.add_child(bulb)
				lset.append(m)
			lamps.append(lset)
		# Pedestrian-side back plate + small glow on the ground (cheap).
		(j["heads"] as Array).append({"arm": a, "lamps": lamps, "node": holder})
	_paint(j)


func _paint(j: Dictionary) -> void:
	for hd: Dictionary in j["heads"]:
		var state := light_for(j, hd["arm"])
		var idx := {"red": 0, "yellow": 1, "green": 2}.get(state, 0) as int
		for lset: Array in hd["lamps"]:
			for i in 3:
				(lset[i] as StandardMaterial3D).emission_energy_multiplier = 3.2 if i == idx else 0.05


# ------------------------------------------------------------------ cameras
func _build_camera(c: Vector2, arms: Array, _id: String) -> void:
	# One camera pole on a corner, watching every arm (radius check in TrafficRules).
	var corner := c + Vector2(1, 1).normalized() * 0.0
	if not arms.is_empty():
		var a: Dictionary = arms[0]
		var h: Vector2 = a["heading"]
		corner = c - h * (float(a["stop"]) + 1.5) - Vector2(-h.y, h.x) * (float(a["half"]) + 0.9)
	var holder := Node3D.new()
	holder.name = "RedLightCamera"
	holder.position = TrafficKit.ground(corner)
	var to := c - corner
	holder.rotation.y = atan2(to.x, to.y)
	add_child(holder)
	_camera_pole(holder, "red")


func _camera_pole(holder: Node3D, kind: String) -> void:
	var pole := TrafficKit.mat(Color(0.75, 0.76, 0.78), 0.4)
	V7aKit.cyl(holder, 0.07, 4.2, Vector3(0, 2.1, 0), pole)
	V7aKit.box(holder, Vector3(0.36, 0.3, 0.6), Vector3(0, 4.1, 0.25), TrafficKit.mat(Color(0.92, 0.92, 0.9), 0.5))
	var lens := V7aKit.cyl(holder, 0.09, 0.08, Vector3(0, 4.1, 0.58), TrafficKit.mat(Color(0.05, 0.05, 0.08), 0.1))
	lens.rotation.x = PI * 0.5
	V7aKit.box(holder, Vector3(0.5, 0.3, 0.05), Vector3(0, 3.5, 0.08), TrafficKit.mat(Color(0.95, 0.8, 0.1), 0.6))
	TrafficKit.label(holder, "دوربین کنترل سرعت" if kind == "speed" else "دوربین ثبت تخلف", "SPEED CAMERA" if kind == "speed" else "RED LIGHT CAMERA",
		Vector3(0, 3.5, 0.11), 0.0, 0.0018, 40, Color(0.05, 0.05, 0.05))
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.95, 0.97, 1.0)
	flash.omni_range = 16.0
	flash.light_energy = 0.0
	flash.visible = false
	flash.position = Vector3(0, 4.0, 0.7)
	flash.shadow_enabled = false
	holder.add_child(flash)
	var glow := V7aKit.ball(holder, 0.16, Vector3(0, 4.1, 0.62), TrafficKit.mat(Color(1, 1, 1), 0.2, 0.0))
	glow.visible = false
	cameras.append({"pos": holder.global_position if holder.is_inside_tree() else holder.position, "node": holder, "flash": flash, "glow": glow, "t": 0.0, "kind": kind})


func nearest_camera(p: Vector3, max_d: float) -> Dictionary:
	var best := {}
	var bd := max_d
	for cam: Dictionary in cameras:
		var d := ((cam["node"] as Node3D).global_position - p).length()
		if d < bd:
			bd = d
			best = cam
	return best


## White flash (the photo).
func flash(cam: Dictionary) -> void:
	if cam.is_empty():
		return
	cam["t"] = 0.6
	(cam["flash"] as OmniLight3D).visible = true
	(cam["glow"] as MeshInstance3D).visible = true
	Sfx.play_at(&"door", (cam["node"] as Node3D).global_position, -10.0, 2.6)


func _tick_cameras(delta: float) -> void:
	for cam: Dictionary in cameras:
		if float(cam["t"]) <= 0.0:
			continue
		cam["t"] = float(cam["t"]) - delta
		var on := float(cam["t"]) > 0.0 and fmod(float(cam["t"]), 0.3) > 0.12
		(cam["flash"] as OmniLight3D).light_energy = 9.0 if on else 0.0
		(cam["glow"] as MeshInstance3D).visible = on
		if float(cam["t"]) <= 0.0:
			(cam["flash"] as OmniLight3D).visible = false
			(cam["glow"] as MeshInstance3D).visible = false


func any_flashing() -> bool:
	for cam: Dictionary in cameras:
		if float(cam["t"]) > 0.0:
			return true
	return false


# ------------------------------------------------------------------ officer
func _build_officer(c: Vector2, arms: Array) -> void:
	# On a small round podium at the corner of the junction (out of the lanes).
	var spot := c + Vector2(-1, 1).normalized() * 0.0
	if arms.size() >= 2:
		var h: Vector2 = (arms[1] as Dictionary)["heading"]
		spot = c - h * (float((arms[1] as Dictionary)["stop"]) - 2.2) + Vector2(-h.y, h.x) * (float((arms[1] as Dictionary)["half"]) + 1.0)
	var holder := Node3D.new()
	holder.name = "TrafficOfficer"
	holder.position = TrafficKit.ground(spot)
	add_child(holder)
	V7aKit.cyl(holder, 0.55, 0.25, Vector3(0, 0.12, 0), TrafficKit.mat(Color(0.9, 0.9, 0.88), 0.6))
	V7aKit.cyl(holder, 0.58, 0.05, Vector3(0, 0.26, 0), TrafficKit.mat(Color(0.85, 0.15, 0.12), 0.6))
	# Parasol for the summer sun.
	V7aKit.cyl(holder, 0.03, 2.4, Vector3(0.5, 1.4, -0.3), TrafficKit.mat(Color(0.3, 0.3, 0.3), 0.5))
	V7aKit.cyl(holder, 1.1, 0.35, Vector3(0.5, 2.7, -0.3), TrafficKit.mat(Color(0.95, 0.95, 0.95), 0.7), 0.0)
	officer = HumanoidModelVisual.new()
	officer.name = "Officer"
	officer.body_type = "male"
	officer.top_style = "jacket"
	officer.shirt_color = Color(0.86, 0.84, 0.7)   # Iranian traffic police khaki / white
	officer.pants_color = Color(0.18, 0.22, 0.3)
	officer.hair_style = "Hair_Buzzed"
	officer.position = Vector3(0, 0.28, 0)
	holder.add_child(officer)
	# White cap + reflective vest band.
	V7aKit.cyl(officer, 0.14, 0.09, Vector3(0, 1.74, 0.0), TrafficKit.mat(Color(0.97, 0.97, 0.97), 0.5))
	V7aKit.box(officer, Vector3(0.44, 0.08, 0.28), Vector3(0, 1.25, 0), TrafficKit.mat(Color(0.75, 1.0, 0.2), 0.4, 0.4))
	officer_pos = holder.position
	TrafficKit.label(holder, "پلیس راهنمایی و رانندگی", "Traffic police", Vector3(0, 2.35, 0), 0.0, 0.0028, 40, Color(1, 1, 1), 8).billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _tick_officer(delta: float) -> void:
	if officer == null or not is_instance_valid(officer):
		return
	_t_officer -= delta
	if _t_officer > 0.0:
		return
	_t_officer = 0.5
	# Faces the arm that is green and waves it through (talk pose = arm gestures).
	for id in junctions:
		var j: Dictionary = junctions[id]
		if not bool(j["officer"]):
			continue
		for a: Dictionary in j["arms"]:
			if light_for(j, a) == "green":
				var h: Vector2 = a["heading"]
				officer.rotation.y = lerp_angle(officer.rotation.y, atan2(-h.x, -h.y), 0.5)
				break
		if officer.has_method("set_pose"):
			officer.call("set_pose", &"talk" if str(j["stage"]) != "allred" else &"")


func officer_say(line: Dictionary) -> void:
	if officer == null:
		return
	var holder := officer.get_parent() as Node3D
	var l := TrafficKit.label(holder, str(line.get("fa", "")), str(line.get("en", "")), Vector3(0, 2.75, 0), 0.0, 0.0032, 44, Color(1, 0.95, 0.6), 10)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.remove_from_group(&"v7b_signs")
	get_tree().create_timer(3.5).timeout.connect(func() -> void:
		if is_instance_valid(l):
			l.queue_free())
