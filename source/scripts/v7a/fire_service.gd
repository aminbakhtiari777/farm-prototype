class_name FireService
extends Node3D
## v7a "fire" module: fire + emergencies.
##  - A fire station on Main St with a red fire truck and a crew of three.
##  - ignite(building, cause): flames + smoke grow on the building; a full fire
##    slowly spreads to the nearest flammable building within spread_radius.
##  - The truck drives out fast (lights on); the crew gets out and hoses the
##    fire down; the ambulance stands by; the police take a report.
##  - Burned buildings (CityState.damage) are rebuilt over days: scaffolding,
##    the carpenter and the mason come to work, then a "rebuilt" plaque.
##  - Whoever caused the fire pays a fine + damages into the city fund.

enum Truck { IDLE, TO_FIRE, HOSING, RETURNING }

var station: Building
var truck: RoadCar
var crew: Array[HumanoidModelVisual] = []
var hoses: Array[CPUParticles3D] = []
var fires: Dictionary = {}   ## building id -> Fire
var truck_state: Truck = Truck.IDLE
var target_id: String = ""
var calls: int = 0
var extinguished: int = 0
var spreads: int = 0
var rebuilt: int = 0
var frozen: bool = false   ## shots: hold fire levels still
var _arrive_t: float = 0.0


class Fire extends Node3D:
	var building: Building
	var id: String = ""
	var intensity: float = 0.05
	var burn: float = 0.0
	var hosed: bool = false
	var cause: String = ""
	var by_player: bool = false
	var spread_t: float = 0.0
	var flames: Array[CPUParticles3D] = []
	var smoke: CPUParticles3D
	var light: OmniLight3D
	var audio: AudioStreamPlayer3D
	var _flick: float = 0.0
	func setup(b: Building) -> void:
		building = b
		var w := b.size.x
		var d := b.size.z
		var top := b.size.y + 0.3
		for k in 3:
			var f := V7aKit.particles("flame", 26, Vector3(w * 0.32, 0.3, d * 0.22))
			f.position = Vector3((k - 1) * w * 0.28, top * (0.55 if k != 1 else 0.95), (k - 1) * d * 0.12)
			add_child(f)
			flames.append(f)
		smoke = V7aKit.particles("smoke", 22, Vector3(w * 0.3, 0.4, d * 0.3))
		smoke.position = Vector3(0, top + 1.2, 0)
		add_child(smoke)
		light = OmniLight3D.new()
		light.light_color = Color(1.0, 0.5, 0.15)
		light.omni_range = 14.0
		light.position = Vector3(0, top, d * 0.6)
		light.shadow_enabled = false
		add_child(light)
		var s := load("res://assets/audio/ambience/campfire_loop.ogg") as AudioStream
		if s:
			audio = AudioStreamPlayer3D.new()
			audio.stream = s
			audio.volume_db = 6.0
			audio.unit_size = 8.0
			audio.max_distance = 60.0
			audio.position = Vector3(0, 2, 0)
			add_child(audio)
			audio.play()
	func set_level(v: float, delta: float) -> void:
		_flick += delta * 9.0
		for f in flames:
			f.emitting = v > 0.03
			f.scale_amount_min = 0.5 + v * 0.9
			f.scale_amount_max = 0.9 + v * 1.8
			f.initial_velocity_max = 1.6 + v * 1.8
		smoke.emitting = v > 0.01 or burn > 0.1
		light.light_energy = v * (2.6 + sin(_flick) * 0.5 + sin(_flick * 2.3) * 0.3)
		if audio:
			audio.volume_db = linear_to_db(maxf(v, 0.02)) + 6.0


func style() -> FireStyle:
	return Modules.style("fire") as FireStyle


func _ready() -> void:
	_build_station()
	_spawn_truck()
	TimeManager.day_started.connect(_on_day)
	CityState.changed.connect(func(kind: String) -> void:
		if kind == "all":
			_apply_all_damage.call_deferred())
	_apply_all_damage.call_deferred()
	Modules.on_swap("fire", self, func(_m: Resource) -> void:
		for id in fires.keys():
			_put_out(str(id), false)
		if truck:
			truck.queue_free()
		if station:
			station.queue_free()
		for c in crew:
			c.queue_free()
		crew.clear()
		hoses.clear()
		_build_station()
		_spawn_truck())


# ------------------------------------------------------------------ station + truck
func _build_station() -> void:
	var st := style()
	if st == null:
		return
	var b := Building.new()
	b.name = "FireStation"
	b.layout_id = "fire_station"
	b.size = Vector3(9.0, 4.0, 7.5)
	b.roof_height = 1.2
	b.roof_type = "flat"
	b.wall_color = Color(0.86, 0.22, 0.16)
	b.roof_color = Color(0.3, 0.3, 0.32)
	b.trim_color = Color(0.95, 0.93, 0.9)
	b.kind = "civic"
	b.interior_theme = "office"
	b.sign_text = "Fire Station"
	b.address = "17 Main St"
	b.has_chimney = false
	b.random_seed = 717
	var p := st.station_pos
	b.position = V7aKit.ground(p.x, p.y)
	b.rotation.y = deg_to_rad(st.station_yaw)
	add_child(b)
	station = b
	# Big garage door + the number on the front (local +z is the street side).
	var front := Node3D.new()
	front.name = "GarageFront"
	b.add_child(front)
	V7aKit.box(front, Vector3(3.2, 2.8, 0.06), Vector3(-2.4, 1.7, b.size.z * 0.5 + 0.03), Color(0.92, 0.92, 0.9))
	for k in 6:
		V7aKit.box(front, Vector3(3.2, 0.03, 0.08), Vector3(-2.4, 0.6 + k * 0.42, b.size.z * 0.5 + 0.06), Color(0.7, 0.7, 0.7))
	V7aKit.box(front, Vector3(9.1, 0.35, 0.1), Vector3(0, 3.55, b.size.z * 0.5 + 0.06), Color(0.95, 0.95, 0.95))
	var l := Label3D.new()
	Lang.setup_label3d(l, 64)
	l.text = "۱۲۵"
	l.modulate = Color(0.85, 0.1, 0.08)
	l.pixel_size = 0.006
	l.position = Vector3(2.6, 2.6, b.size.z * 0.5 + 0.08)
	front.add_child(l)


func truck_base() -> Vector3:
	var st := style()
	var b := st.truck_base if st else Vector2(46.5, -46.1)
	return V7aKit.ground(b.x, b.y)


func _spawn_truck() -> void:
	var st := style()
	if st == null:
		return
	truck = RoadCar.new()
	truck.name = "FireTruck"
	truck.model_name = "firetruck" if CarBody.handles("firetruck") else "delivery"  # v7b.1 real fire truck
	truck.speed = st.truck_speed
	add_child(truck)
	truck.build_model()
	_paint_truck(st.truck_color)
	truck.add_lightbar(Color(1.0, 0.1, 0.05), Color(1.0, 0.95, 0.9))
	truck.place(truck_base(), PI * 0.5)
	truck.arrived.connect(_on_truck_arrived)
	truck_state = Truck.IDLE


func _paint_truck(c: Color) -> void:
	if truck.model_root == null:
		return
	if truck.model_root.has_meta(&"procedural"):
		FireSiren.attach(self, truck)  # v7b.1: the procedural fire truck has its own paint, ladder, reels + siren
		return
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(c.r, c.g, c.b, 0.78)
	red.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	red.roughness = 0.4
	for mi in truck.model_root.find_children("*", "MeshInstance3D", true, false):
		var n := str(mi.name).to_lower()
		if n.contains("body") or n.contains("door"):
			(mi as MeshInstance3D).material_overlay = red
	# Ladder on the roof + a white stripe.
	var sz := truck.size
	var silver := V7aKit.mat(Color(0.8, 0.82, 0.85), 0.3)
	for sx in [-0.3, 0.3]:
		V7aKit.box(truck, Vector3(0.06, 0.06, sz.z * 0.8), Vector3(sx, sz.y + 0.12, -0.1), silver)
	for k in 9:
		V7aKit.box(truck, Vector3(0.6, 0.04, 0.04), Vector3(0, sz.y + 0.12, -sz.z * 0.38 + k * sz.z * 0.09), silver)
	for sx in [-1.0, 1.0]:
		V7aKit.box(truck, Vector3(0.02, 0.12, sz.z * 0.7), Vector3(sx * (sz.x * 0.5 + 0.01), sz.y * 0.42, 0), Color(0.97, 0.97, 0.95))


func _show_crew(on: bool) -> void:
	var st := style()
	var n := st.crew if st else 3
	while crew.size() < n:
		var v := HumanoidModelVisual.new()
		v.name = "Firefighter%d" % crew.size()
		v.body_type = "male" if crew.size() != 1 else "female"
		v.shirt_color = Color(0.2, 0.22, 0.28)
		v.pants_color = Color(0.2, 0.22, 0.28)
		v.top_style = "jacket"
		v.hair_style = "Hair_Buzzed"
		v.visible = false
		add_child(v)
		V7aKit.ball(v, 0.16, Vector3(0, 1.82, 0), V7aKit.mat(Color(0.95, 0.78, 0.1), 0.35)).scale = Vector3(1.1, 0.7, 1.2)
		V7aKit.box(v, Vector3(0.5, 0.05, 0.02), Vector3(0, 1.2, 0.16), V7aKit.mat(Color(0.95, 0.85, 0.2), 0.3, 0.6))
		var hose := V7aKit.particles("water", 40, Vector3(0.03, 0.03, 0.03))
		hose.position = Vector3(0, 1.15, 0.35)
		hose.direction = Vector3(0, 0.25, 1)
		hose.emitting = false
		v.add_child(hose)
		crew.append(v)
		hoses.append(hose)
	var f: Fire = fires.get(target_id, null)
	for i in crew.size():
		var c := crew[i]
		c.visible = on
		hoses[i].emitting = on and f != null
		if on and f:
			var b := f.building
			var to := V7aKit.flat(b.global_position - truck.global_position).normalized()
			var side := Vector3(-to.z, 0, to.x)
			var p := truck.global_position + to * 3.0 + side * (float(i) - 1.0) * 1.6
			c.global_position = V7aKit.ground(p.x, p.z)
			var face := b.global_position + Vector3(0, b.size.y, 0) - c.global_position
			c.rotation.y = atan2(face.x, face.z)
			# Aim the jet up at the fire.
			var dist := V7aKit.flat(face).length()
			hoses[i].initial_velocity_min = clampf(dist * 0.9, 6.0, 14.0)
			hoses[i].initial_velocity_max = hoses[i].initial_velocity_min + 1.5


# ------------------------------------------------------------------ fires
func flammables() -> Array[Building]:
	var out: Array[Building] = []
	for n in get_tree().get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b == null or b == station or not is_instance_valid(b):
			continue
		if b.kind in ["home", "store", "cafe", "workplace", "supermarket"] or b.layout_id.begins_with("maple") or str(b.name).begins_with("Lot_"):
			out.append(b)
	return out


static func id_of(b: Building) -> String:
	return b.layout_id if b.layout_id != "" else str(b.name)


func building_by_id(id: String) -> Building:
	for n in get_tree().get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b and id_of(b) == id:
			return b
	return null


func nearest_flammable(pos: Vector3, max_d: float = 8.0) -> Building:
	var best: Building = null
	var bd := max_d
	for b in flammables():
		var d := V7aKit.flat(b.global_position).distance_to(V7aKit.flat(pos)) - maxf(b.size.x, b.size.z) * 0.5
		if d < bd:
			bd = d
			best = b
	return best


## Sets a building on fire. cause = who did it ("player", a resident's full
## name, "storm", "spread"...). by_player: the player pays fines + damages.
func ignite(b: Building, cause: String = "accident", by_player: bool = false) -> bool:
	if b == null or style() == null:
		return false
	var id := id_of(b)
	if fires.has(id) or str(CityState.damage_of(id).get("state", "ok")) in ["demolished", "rebuilding"]:
		return false
	var f := Fire.new()
	f.name = "Fire_" + id
	f.id = id
	f.cause = cause
	f.by_player = by_player
	f.burn = float(CityState.damage_of(id).get("burn", 0.0))
	b.add_child(f)
	f.setup(b)
	fires[id] = f
	CityState.fires += 1
	CityState.set_damage(id, "burning", f.burn, cause)
	GameEvents.notification_requested.emit(Lang.tt("آتش‌سوزی! %s می‌سوزد - آتش‌نشانی در راه است (۱۲۵)." % _place_name(b),
			"Fire! %s is burning - the fire brigade is on its way." % _place_name(b, false)))
	_dispatch()
	_ambulance_standby(b)
	return true


func _place_name(b: Building, fa: bool = true) -> String:
	if fa and Lang.is_fa():
		if b.address != "":
			return SignText.address(b.address)
		return SignText.sign_of(b.sign_text)
	return b.address if b.address != "" else b.sign_text


func _process(delta: float) -> void:
	var st := style()
	if st == null:
		return
	for id in fires.keys():
		var f: Fire = fires[id]
		if not is_instance_valid(f) or not is_instance_valid(f.building):
			fires.erase(id)
			continue
		if frozen:
			f.set_level(clampf(f.intensity, 0.0, 1.0), delta)
			continue
		if f.hosed:
			f.intensity -= delta / maxf(st.extinguish_seconds, 0.5)
		else:
			f.intensity = minf(f.intensity + delta / maxf(st.grow_seconds, 0.5), 1.0)
		f.burn = minf(f.burn + st.damage_per_second * maxf(f.intensity, 0.0) * delta, 1.0)
		f.set_level(clampf(f.intensity, 0.0, 1.0), delta)
		if f.intensity >= 0.9 and not f.hosed:
			f.spread_t += delta
			if f.spread_t >= st.spread_seconds:
				f.spread_t = 0.0
				_spread_from(f)
		if f.intensity <= 0.0:
			_put_out(str(id), true)
	# Truck: crew hoses the target fire.
	if truck_state == Truck.HOSING:
		var tf: Fire = fires.get(target_id, null)
		if tf == null:
			_next_or_return()
		else:
			tf.hosed = true
	elif truck_state == Truck.TO_FIRE:
		_arrive_t += delta
		var tf2: Fire = fires.get(target_id, null)
		if tf2 and truck.global_position.distance_to(tf2.building.global_position) < maxf(tf2.building.size.x, tf2.building.size.z) * 0.5 + 9.0:
			truck.stop()
			_on_truck_arrived()


func _spread_from(f: Fire) -> void:
	var st := style()
	var best: Building = null
	var bd := st.spread_radius
	for b in flammables():
		var id := id_of(b)
		if b == f.building or fires.has(id) or str(CityState.damage_of(id).get("state", "ok")) != "ok":
			continue
		var d := V7aKit.flat(b.global_position).distance_to(V7aKit.flat(f.building.global_position)) - (maxf(b.size.x, b.size.z) + maxf(f.building.size.x, f.building.size.z)) * 0.35
		if d < bd:
			bd = d
			best = b
	if best:
		spreads += 1
		ignite(best, f.cause, f.by_player)


func _put_out(id: String, natural: bool) -> void:
	var f: Fire = fires.get(id, null)
	fires.erase(id)
	if f == null or not is_instance_valid(f):
		return
	var b := f.building
	var burn := f.burn
	f.queue_free()
	if not natural:
		CityState.set_damage(id, "ok", 0.0)
		BuildingDamage.apply(b, "ok", 0.0)
		return
	extinguished += 1
	var st := style()
	var state := "burned" if burn >= 0.12 else "ok"
	CityState.set_damage(id, state, burn, f.cause)
	if state == "ok":
		CityState.clear_damage(id)
	BuildingDamage.apply(b, state, burn)
	GameEvents.notification_requested.emit(Lang.tt("آتش خاموش شد. %s٪ آسیب دید." % Lang.digits(str(int(burn * 100))),
			"The fire is out. %d%% damaged." % int(burn * 100)))
	# Justice: whoever caused it pays (fine + damages); the police take a report.
	if f.cause != "" and f.cause not in ["accident", "storm", "quake", "spread"]:
		var dmg := int(round((st.damage_cost if st else 800) * burn))
		var base_fine := st.fine if st else 300
		var ps := Modules.style("possession") as PossessionStyle
		if f.by_player and ps:
			base_fine = ps.arson_fine  # deliberate arson while playing a resident
		var fine := base_fine + dmg
		CityState.add_fine("fire", fine, "Fire caused by %s (damages %d G)" % [f.cause, dmg],
				"آتش‌سوزی به دست %s (خسارت %s سکه)" % [_fa_name(f.cause), Lang.digits(str(dmg))], f.by_player)
		WorldMemory.file_report("fire", f.cause, id, fine)
		for bot in V7aKit.bots(get_tree()):
			if str(bot.resident.get("home", "")) == id:
				WorldMemory.npc_remember(Friendship.key_of(bot), "fire", "%s set our house on fire." % f.cause,
						"%s خانه‌مان را آتش زد." % _fa_name(f.cause))
				if f.by_player and f.cause == "player":
					Friendship.add_points(Friendship.key_of(bot), -20)
	if fires.is_empty():
		_ambulance_return()


func _fa_name(full: String) -> String:
	if full == "player":
		return "کشاورز"
	var r := Population.by_name(full.get_slice(" ", 0))
	return Dialogue.name_of(r) if not r.is_empty() else full


# ------------------------------------------------------------------ truck flow
func _dispatch() -> void:
	if truck == null or truck_state in [Truck.TO_FIRE, Truck.HOSING]:
		return
	_next_target()


func _next_target() -> bool:
	var best := ""
	var bd := INF
	for id in fires.keys():
		var f: Fire = fires[id]
		var d := truck.global_position.distance_to(f.building.global_position)
		if d < bd:
			bd = d
			best = str(id)
	if best == "":
		return false
	target_id = best
	calls += 1
	truck_state = Truck.TO_FIRE
	_arrive_t = 0.0
	truck.set_flashing(true)
	_show_crew(false)
	var b: Building = (fires[best] as Fire).building
	var road := VehicleKit.nearest(b.global_position)
	truck.drive_to(road, false)
	return true


func _on_truck_arrived() -> void:
	match truck_state:
		Truck.TO_FIRE:
			if not fires.has(target_id):
				_next_or_return()
				return
			truck_state = Truck.HOSING
			var b: Building = (fires[target_id] as Fire).building
			var to := V7aKit.flat(b.global_position - truck.global_position)
			truck.place(truck.global_position, atan2(to.x, to.z) + PI * 0.5)
			_show_crew(true)
		Truck.RETURNING:
			truck_state = Truck.IDLE
			truck.set_flashing(false)
			truck.place(truck_base(), PI * 0.5)


func _next_or_return() -> void:
	_show_crew(false)
	if _next_target():
		return
	truck_state = Truck.RETURNING
	truck.set_flashing(false)
	truck.drive_to(truck_base())


## Tests / shots: move the truck straight to the fire and start hosing.
func arrive_now() -> void:
	if not fires.has(target_id):
		if not _next_target():
			return
	var b: Building = (fires[target_id] as Fire).building
	var road := VehicleKit.nearest(b.global_position)
	truck.place(road, 0.0)
	truck.stop()
	truck_state = Truck.TO_FIRE
	_on_truck_arrived()


func _amb() -> AmbulanceService:
	return get_tree().current_scene.find_child("AmbulanceService", true, false) as AmbulanceService


func _ambulance_standby(b: Building) -> void:
	var a := _amb()
	if a == null or a.car == null or a.state != AmbulanceService.State.IDLE:
		return
	a.car.set_flashing(true)
	a.car.drive_to(VehicleKit.nearest(b.global_position + Vector3(6, 0, 0)), false)
	set_meta(&"amb_standby", true)


func _ambulance_return() -> void:
	var a := _amb()
	if a == null or not has_meta(&"amb_standby"):
		return
	remove_meta(&"amb_standby")
	if a.state == AmbulanceService.State.IDLE and a.car:
		a.state = AmbulanceService.State.RETURNING
		a.car.drive_to(a.base_pos())


# ------------------------------------------------------------------ rebuilding
func _apply_all_damage() -> void:
	for id in CityState.damage.keys():
		var d: Dictionary = CityState.damage[id]
		var b := building_by_id(str(id))
		if b == null:
			continue
		var state := str(d.get("state", "ok"))
		if state == "burning" and not fires.has(str(id)):
			state = "burned"
			CityState.damage[id]["state"] = state
		BuildingDamage.apply(b, state, float(d.get("burn", 0.0)), _days_left(d))
	_update_workers()


func _days_left(d: Dictionary) -> int:
	return int(d.get("until", 0)) - TimeManager.day


## Burned / demolished buildings start rebuilding the next day and are done
## after rebuild_days; the carpenter + mason work there in the daytime.
func start_rebuild(id: String) -> void:
	var st := style()
	var d: Dictionary = CityState.damage_of(id)
	if d.is_empty():
		return
	var days := st.rebuild_days if st else 2
	var ps := Modules.style("possession") as PossessionStyle
	if str(d.get("state", "")) == "demolished" and ps:
		days = ps.demolish_days
	d["state"] = "rebuilding"
	d["until"] = TimeManager.day + days
	CityState.damage[id] = d
	CityState.changed.emit("damage")
	BuildingDamage.apply(building_by_id(id), "rebuilding", float(d.get("burn", 1.0)), days)
	_update_workers()


func finish_rebuild(id: String) -> void:
	var b := building_by_id(id)
	CityState.clear_damage(id)
	rebuilt += 1
	if b:
		BuildingDamage.apply(b, "ok", 0.0)
		BuildingDamage.rebuilt_plaque(b)
		b.set_meta(&"rebuilt_day", TimeManager.day)
	_update_workers()
	GameEvents.notification_requested.emit(Lang.tt("نجار و بنا خانه را دوباره ساختند.", "The carpenter and the mason have rebuilt the house."))


func _on_day(day: int) -> void:
	for id in CityState.damage.keys():
		var d: Dictionary = CityState.damage[id]
		match str(d.get("state", "")):
			"burned", "demolished":
				start_rebuild(str(id))
			"rebuilding":
				if day >= int(d.get("until", day)):
					finish_rebuild(str(id))
	# Old plaques come down after two days.
	for n in get_tree().get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b and b.has_meta(&"rebuilt_day") and day - int(b.get_meta(&"rebuilt_day")) >= 2:
			var pl := b.get_node_or_null(^"V7aRebuilt")
			if pl:
				pl.queue_free()
			b.remove_meta(&"rebuilt_day")


func rebuilding_site() -> String:
	for id in CityState.damage.keys():
		if str((CityState.damage[id] as Dictionary).get("state", "")) == "rebuilding":
			return str(id)
	return ""


## The carpenter + the mason go to the site (v5b override_entry).
func _update_workers() -> void:
	var site := rebuilding_site()
	for job in ["carpenter", "stonemason"]:
		var w := V7aKit.bot_with_job(get_tree(), job)
		if w == null:
			continue
		var sc := w.controller as ScheduleController
		if sc == null:
			continue
		if site != "" and TownNav.spot_position("door:" + site) != Vector3.INF:
			sc.override_entry = {"spot": "door:" + site, "activity": "wander", "from": 8.0, "to": 17.0, "v7a": "rebuild"}
		elif str(sc.override_entry.get("v7a", "")) == "rebuild":
			sc.override_entry = {}


func workers_at_site() -> int:
	var n := 0
	for job in ["carpenter", "stonemason"]:
		var w := V7aKit.bot_with_job(get_tree(), job)
		if w and w.controller is ScheduleController and str((w.controller as ScheduleController).override_entry.get("v7a", "")) == "rebuild":
			n += 1
	return n


## Possession: tear down a house (axe). Rubble now, rebuilt over days.
func demolish(b: Building, cause: String) -> bool:
	if b == null:
		return false
	var id := id_of(b)
	if fires.has(id):
		return false
	CityState.set_damage(id, "demolished", 1.0, cause)
	BuildingDamage.apply(b, "demolished", 1.0)
	Sfx.play_at(&"hammer", b.global_position, 2.0, 0.7)
	return true
