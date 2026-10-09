class_name Outages
extends Node3D
## v7a "outages" module: power cuts from nature.
##  - Storm: on a storm day the wind may bring a line down at some hour
##    (blowing leaves + stronger rain); the power goes out.
##  - Earthquake: occasionally a mild quake - the camera shakes, small things
##    fall off shelves / walls, townspeople call out - and it may cut power.
##  - Homes switch to candles, lanterns and the fireplace (v4 electricity),
##    townspeople light candles and carry on; the electricity office sends its
##    crew in a van to the broken line and restores power after a few hours.

var auto: bool = true   ## false = no random storm cuts / quakes (tests)
var cut_active: bool = false
var cut_cause: String = ""
var repair_at: float = -1.0     ## absolute game minutes
var van: RoadCar
var crew: Array[HumanoidModelVisual] = []
var quake_t: float = 0.0
var quakes: int = 0
var cuts: int = 0
var repairs: int = 0
var fallen: Array[Node3D] = []
var _shook: bool = false
var _storm_cut_hour: int = -1
var _rng := RandomNumberGenerator.new()
var _leaves: CPUParticles3D
var _bubble: Label3D
var _line_spot: Vector3 = Vector3.INF


func style() -> OutageStyle:
	return Modules.style("outages") as OutageStyle


func _ready() -> void:
	_rng.randomize()
	TimeManager.weather_changed.connect(_on_weather)
	TimeManager.day_started.connect(_on_day)
	TimeManager.hour_changed.connect(_on_hour)
	PowerGrid.power_changed.connect(func(on: bool) -> void:
		if on and cut_active:
			_restored())
	_spawn_van()
	_leaves = V7aKit.particles("smoke", 70, Vector3(14, 3, 14))
	(_leaves.mesh.material as StandardMaterial3D).blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_leaves.mesh = QuadMesh.new()
	(_leaves.mesh as QuadMesh).size = Vector2(0.12, 0.08)
	var lm := V7aKit.mat(Color(0.45, 0.4, 0.15))
	lm.cull_mode = BaseMaterial3D.CULL_DISABLED
	lm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	(_leaves.mesh as QuadMesh).material = lm
	_leaves.color_ramp = null
	_leaves.direction = Vector3(1, 0.2, 0.3)
	_leaves.spread = 25.0
	_leaves.gravity = Vector3(6, -0.6, 2)
	_leaves.initial_velocity_min = 6.0
	_leaves.initial_velocity_max = 11.0
	_leaves.lifetime = 2.5
	_leaves.angular_velocity_min = -360.0
	_leaves.angular_velocity_max = 360.0
	_leaves.emitting = false
	add_child(_leaves)
	Modules.on_swap("outages", self, func(_m: Resource) -> void:
		if van:
			van.queue_free()
		_spawn_van())


func _spawn_van() -> void:
	van = RoadCar.new()
	van.name = "PowerCrewVan"
	van.model_name = "van"
	van.speed = 8.5
	add_child(van)
	van.build_model()
	if van.model_root:
		var o := StandardMaterial3D.new()
		o.albedo_color = Color(1.0, 0.62, 0.05, 0.7)
		o.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		for mi in van.model_root.find_children("*", "MeshInstance3D", true, false):
			if str(mi.name).to_lower().contains("body"):
				(mi as MeshInstance3D).material_overlay = o
	van.add_lightbar(Color(1.0, 0.65, 0.05), Color(1.0, 0.65, 0.05))
	van.place(base_pos(), PI)
	van.arrived.connect(_on_van_arrived)


func base_pos() -> Vector3:
	return V7aKit.ground(52.0, -86.4)


# ------------------------------------------------------------------ storm
func _on_weather(w: String) -> void:
	_leaves.emitting = w == "storm"
	var st := style()
	if w == "storm" and st and auto and _rng.randf() < st.storm_cut_chance:
		_storm_cut_hour = clampi(int(TimeManager.hours_float()) + 1 + _rng.randi() % 6, 0, 23)
	else:
		_storm_cut_hour = -1


func _on_hour(h: int, _d: int) -> void:
	if h == _storm_cut_hour and TimeManager.weather_id == "storm":
		_storm_cut_hour = -1
		cut("storm")
	if cut_active and repair_at > 0.0 and TimeManager.day * 1440.0 + TimeManager.minutes >= repair_at:
		repair_now()


func _on_day(_day: int) -> void:
	var st := style()
	if st and auto and _rng.randf() < st.quake_chance:
		get_tree().create_timer(_rng.randf_range(20.0, 120.0)).timeout.connect(func() -> void: quake())


func _abs_minutes() -> float:
	return TimeManager.day * 1440.0 + TimeManager.minutes


## Power goes out (storm / quake). Candles + lanterns take over (v4).
func cut(cause: String) -> void:
	if cut_active or not PowerGrid.power_on:
		return
	var st := style()
	cut_active = true
	cut_cause = cause
	cuts += 1
	CityState.outages += 1
	PowerGrid.set_power(false)
	repair_at = _abs_minutes() + (st.repair_hours if st else 3.0) * 60.0
	GameEvents.notification_requested.emit(Lang.tt(
		"برق رفت (%s)! خانه‌ها با شمع و فانوس روشن‌اند؛ اکیپ اداره‌ی برق در راه است." % ("طوفان" if cause == "storm" else "زلزله"),
		"Power cut (%s)! Homes light candles and lanterns; the electricity crew is on its way." % cause))
	# Townspeople light candles and carry on.
	var n := 0
	for b in V7aKit.bots(get_tree()):
		if not b.hidden_inside and n < 4:
			b.say(Lang.tt(["شمع‌ها را روشن کنیم!", "فانوس کجاست؟", "اشکالی ندارد، با شمع هم می‌شود!", "برق رفت... چای را روی گاز بگذار."][n],
				["Let's light the candles!", "Where's the lantern?", "No problem, candles will do!", "Power's out... put the tea on the gas."][n]), 4.0)
			n += 1
	# The crew drives to the broken line.
	_line_spot = VehicleKit.nearest(V7aKit.ground(3.4, -40.0) if cause != "storm" else V7aKit.ground(-10.0, -90.0))
	if van:
		van.set_flashing(true)
		van.drive_to(_line_spot, false)


func _on_van_arrived() -> void:
	if cut_active:
		_show_crew(true)
		var st := style()
		if st and not st.crew_lines.is_empty():
			_say(str((st.crew_lines[0] as Dictionary).get("fa" if Lang.is_fa() else "en", "")))
	else:
		_show_crew(false)
		van.set_flashing(false)
		van.place(base_pos(), PI)


func _say(t: String) -> void:
	if _bubble == null:
		_bubble = Label3D.new()
		Lang.setup_label3d(_bubble, 40)
		_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_bubble.outline_size = 10
		_bubble.pixel_size = 0.0045
		add_child(_bubble)
	_bubble.text = t
	_bubble.visible = true
	_bubble.global_position = van.global_position + Vector3(0, 2.8, 0)
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(_bubble):
			_bubble.visible = false)


func _show_crew(on: bool) -> void:
	while crew.size() < 2:
		var v := HumanoidModelVisual.new()
		v.name = "PowerCrew%d" % crew.size()
		v.shirt_color = Color(1.0, 0.55, 0.1)
		v.pants_color = Color(0.2, 0.25, 0.35)
		v.top_style = "jacket"
		v.hair_style = "Hair_Buzzed"
		add_child(v)
		V7aKit.ball(v, 0.16, Vector3(0, 1.82, 0), V7aKit.mat(Color(1.0, 0.95, 0.9), 0.3)).scale = Vector3(1.1, 0.7, 1.2)
		crew.append(v)
	for i in crew.size():
		crew[i].visible = on
		if on and van:
			var side := Vector3(-van.forward().z, 0, van.forward().x)
			var p := van.global_position + side * (2.0 + i * 0.9) - van.forward() * (1.0 - i * 2.0)
			crew[i].global_position = V7aKit.ground(p.x, p.z)
			crew[i].rotation.y = van.rotation.y + PI * 0.5 * (1 if i == 0 else -1)


## The crew fixes the line (also when the repair time passes).
func repair_now() -> void:
	if not cut_active:
		return
	repairs += 1
	PowerGrid.set_power(true)


func _restored() -> void:
	cut_active = false
	repair_at = -1.0
	var st := style()
	if st and st.crew_lines.size() > 1:
		_say(str((st.crew_lines[1] as Dictionary).get("fa" if Lang.is_fa() else "en", "")))
	GameEvents.notification_requested.emit(Lang.tt("اکیپ برق خط را تعمیر کرد - برق وصل شد.", "The electricity crew fixed the line - power is back."))
	if van:
		get_tree().create_timer(3.0).timeout.connect(func() -> void:
			if is_instance_valid(van) and not cut_active:
				_show_crew(false)
				van.drive_to(base_pos()))


# ------------------------------------------------------------------ earthquake
func quake() -> void:
	var st := style()
	if st == null:
		return
	quake_t = st.quake_seconds
	quakes += 1
	CityState.quakes += 1
	GameEvents.notification_requested.emit(Lang.tt("زلزله‌ی خفیف! آرام بمانید.", "A mild earthquake! Stay calm."))
	var n := 0
	for b in V7aKit.bots(get_tree()):
		if not b.hidden_inside and n < 5:
			b.say(Lang.tt(["زلزله!", "زیر میز برو!", "یا خدا!", "آرام باشید، تمام می‌شود.", "بچه‌ها کجایند؟"][n],
				["Earthquake!", "Get under a table!", "Oh my God!", "Stay calm, it'll pass.", "Where are the kids?"][n]), 3.5)
			n += 1
	_drop_items()
	if _rng.randf() < st.quake_cut_chance:
		get_tree().create_timer(minf(st.quake_seconds, 3.0)).timeout.connect(func() -> void: cut("quake"))


func force_quake(cut_power: bool) -> void:
	var st := style()
	var keep := st.quake_cut_chance if st else 0.0
	if st:
		st.quake_cut_chance = 1.0 if cut_power else 0.0
	quake()
	if st:
		st.quake_cut_chance = keep


## Stop shaking and zero the camera offsets (smoke / early end).
func end_quake() -> void:
	quake_t = 0.0
	_shook = false
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0


## Small things fall near the player (pots, books, a box) and tip over.
func _drop_items() -> void:
	for f in fallen:
		if is_instance_valid(f):
			f.queue_free()
	fallen.clear()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null:
		return
	var cols := [Color(0.72, 0.38, 0.22), Color(0.25, 0.35, 0.6), Color(0.62, 0.48, 0.3), Color(0.85, 0.85, 0.82), Color(0.3, 0.5, 0.3)]
	for i in 6:
		var rb := RigidBody3D.new()
		rb.name = "QuakeItem%d" % i
		rb.collision_layer = 0
		rb.collision_mask = 1
		rb.mass = 0.5
		var s := Vector3(_rng.randf_range(0.18, 0.35), _rng.randf_range(0.15, 0.4), _rng.randf_range(0.15, 0.3))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = s
		cs.shape = bs
		rb.add_child(cs)
		V7aKit.box(rb, s, Vector3.ZERO, cols[i % cols.size()])
		var a := TAU * i / 6.0 + _rng.randf() * 0.5
		rb.position = player.global_position + Vector3(cos(a) * 1.6, 1.4 + _rng.randf() * 0.6, sin(a) * 1.6)
		rb.angular_velocity = Vector3(_rng.randf_range(-4, 4), _rng.randf_range(-2, 2), _rng.randf_range(-4, 4))
		get_tree().current_scene.add_child(rb)
		fallen.append(rb)
	get_tree().create_timer(40.0).timeout.connect(func() -> void:
		for f2 in fallen:
			if is_instance_valid(f2):
				f2.queue_free()
		fallen.clear())


func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if quake_t <= 0.0 and _shook and cam:
		_shook = false
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if quake_t > 0.0:
		_shook = true
		quake_t -= delta
		var st := style()
		var amp := (st.quake_strength if st else 0.3) * clampf(quake_t / 1.5, 0.0, 1.0)
		if cam:
			cam.h_offset = _rng.randf_range(-amp, amp)
			cam.v_offset = _rng.randf_range(-amp, amp) * 0.6
		if quake_t <= 0.0 and cam:
			cam.h_offset = 0.0
			cam.v_offset = 0.0
	if _leaves.emitting and cam:
		_leaves.global_position = cam.global_position + Vector3(-8, -1, -2)


func shaking() -> bool:
	return quake_t > 0.0
