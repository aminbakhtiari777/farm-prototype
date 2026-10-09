class_name TrafficRules
extends Node
## v7b.1 traffic enforcement: watches every driven car (the farmer and a
## possessed townsperson) for red-light running, rolling through a STOP and
## speeding past a camera / the officer. On a catch: camera flash, fine into
## the city fund (reuses CityFund.fine_speeding for speeding), police report,
## newspaper item, and an offence point. At offences_to_confiscate the licence
## is confiscated and the car is towed to the Impound. Driving without a
## licence is also an offence (once per day).

var signals: TrafficSignals
var impound: Impound
var auto: bool = true
## car_id -> {red_wait, stop_wait, stop_cleared, speed_t, last_flash_day, last_stop_day, last_red_day}
var _state: Dictionary = {}
var _timer: float = 0.0
var last_flash_cam: Dictionary = {}
var last_offense: Dictionary = {}   ## for tests / newspaper


func style() -> TrafficRulesStyle:
	return TrafficKit.rules()


func _ready() -> void:
	pass


func reset() -> void:
	_state.clear()
	# New dictionaries: last_flash_cam is the camera entry itself (shared with signals.cameras).
	last_offense = {}
	last_flash_cam = {}


func _process(delta: float) -> void:
	if not auto or signals == null:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.12
	for car in _cars():
		_watch(car, 0.12)


func _cars() -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		if c and c.driver != null and absf(c.speed) > 0.05:
			out.append(c)
	# Owned / dealership cars share the same group.
	return out


func _driver_id(car: DrivableCar) -> String:
	var v7a := _v7a()
	if v7a and v7a.possession and v7a.possession.is_active() and v7a.possession.bot:
		return Population.full_name(v7a.possession.bot.resident)
	return "player"


func _state_of(car: DrivableCar) -> Dictionary:
	var id := car.get_instance_id()
	if not _state.has(id):
		_state[id] = {"red_wait": 0.0, "stop_wait": 0.0, "stop_cleared": false, "speed_t": 0.0,
			"last_flash_day": -1, "last_stop_day": -1, "last_red_day": -1, "stop_id": "", "red_id": ""}
	return _state[id]


# ------------------------------------------------------------------ watch
func _watch(car: DrivableCar, dt: float) -> void:
	var st := style()
	if st == null:
		return
	var who := _driver_id(car)
	var s := _state_of(car)
	var p := Vector2(car.global_position.x, car.global_position.z)
	var fwd := Vector2(car.forward().x, car.forward().z)
	# Licence gate.
	if not TrafficState.licensed(who) and TrafficState.unlicensed_day != TimeManager.day and absf(car.speed) > 1.5:
		TrafficState.unlicensed_day = TimeManager.day
		_catch(car, who, "unlicensed", st.unlicensed_fine, "Driving without a licence", "رانندگی بدون گواهینامه", p)
	# Speed limit (cameras + officer).
	var lim := TrafficKit.limit_kmh(p)
	var kmh := absf(car.speed) * 3.6
	var near_enforcer := not signals.nearest_camera(car.global_position, st.enforcement_range).is_empty()
	if signals.officer_pos != Vector3.INF and car.global_position.distance_to(signals.officer_pos) < st.enforcement_range:
		near_enforcer = true
	if near_enforcer and kmh > lim + st.speed_tolerance_kmh:
		s["speed_t"] = float(s["speed_t"]) + dt
		if float(s["speed_t"]) >= st.speeding_seconds:
			s["speed_t"] = 0.0
			_catch_speeding(car, who, kmh, lim, p)
	else:
		s["speed_t"] = 0.0
	# Red light / STOP.
	_watch_signals(car, who, s, p, fwd, dt)
	_watch_stops(car, who, s, p, fwd, dt)


func _watch_signals(car: DrivableCar, who: String, s: Dictionary, p: Vector2, fwd: Vector2, dt: float) -> void:
	var st := style()
	for id in signals.junctions:
		var j: Dictionary = signals.junctions[id]
		var c: Vector2 = j["pos"]
		for a: Dictionary in j["arms"]:
			var ap := TrafficKit.arm_pos(a, c, p, fwd)
			var half := float(a["half"])
			if absf(float(ap["lat"])) > half + 1.5 or float(ap["align"]) < 0.55:
				continue
			var light := signals.light_for(j, a)
			# Waiting before the stop line at red: actuation + stop clock.
			if float(ap["s"]) > -8.0 and float(ap["s"]) < 0.4 and absf(car.speed) < 0.6 and light == "red":
				s["red_wait"] = float(s.get("red_wait", 0.0)) + dt
				s["red_id"] = id
				signals.report_wait(id, float(s["red_wait"]))
			# Crossing the stop line on red (or yellow that was already red for us) at speed.
			if float(ap["s"]) > 0.5 and float(ap["s"]) < 4.0 and light == "red" and absf(car.speed) > 1.5:
				if int(s["last_red_day"]) == TimeManager.day and str(s["red_id"]) == id:
					continue
				s["last_red_day"] = TimeManager.day
				s["red_id"] = id
				_catch(car, who, "red_light", st.red_light_fine, "Running a red light", "رد کردن چراغ قرمز", p, j)
				return
			# Cleared the junction: reset.
			if float(ap["s"]) > 6.0:
				s["red_wait"] = 0.0


func _watch_stops(car: DrivableCar, who: String, s: Dictionary, p: Vector2, fwd: Vector2, dt: float) -> void:
	var st := style()
	for id in signals.stops:
		var j: Dictionary = signals.stops[id]
		var c: Vector2 = j["pos"]
		for a: Dictionary in j["arms"]:
			var ap := TrafficKit.arm_pos(a, c, p, fwd)
			var half := float(a["half"])
			if absf(float(ap["lat"])) > half + 1.5 or float(ap["align"]) < 0.55:
				continue
			# Approaching: accumulate a full stop.
			if float(ap["s"]) > -6.0 and float(ap["s"]) < 0.5:
				if absf(car.speed) < 0.4:
					s["stop_wait"] = float(s.get("stop_wait", 0.0)) + dt
					if float(s["stop_wait"]) >= st.stop_hold_s:
						s["stop_cleared"] = true
						s["stop_id"] = id
				elif absf(car.speed) > 1.5 and float(ap["s"]) < -0.2:
					s["stop_wait"] = 0.0
			# Crossing without having stopped long enough.
			if float(ap["s"]) > 0.6 and float(ap["s"]) < 4.0 and absf(car.speed) > 1.0:
				if bool(s.get("stop_cleared", false)) and str(s.get("stop_id", "")) == id:
					s["stop_cleared"] = false
					s["stop_wait"] = 0.0
					continue
				if int(s["last_stop_day"]) == TimeManager.day and str(s.get("stop_id", "")) == id:
					continue
				s["last_stop_day"] = TimeManager.day
				s["stop_id"] = id
				_catch(car, who, "stop_sign", st.stop_sign_fine, "Rolling through a STOP sign", "رد کردن تابلوی ایست بدون توقف", p, j)
				s["stop_cleared"] = false
				s["stop_wait"] = 0.0
				return
			if float(ap["s"]) > 6.0:
				s["stop_cleared"] = false
				s["stop_wait"] = 0.0


# ------------------------------------------------------------------ catch
func _catch_speeding(car: DrivableCar, who: String, kmh: float, lim: float, p: Vector2) -> void:
	var st := style()
	var fine := st.speeding_fine if st else 50
	var en := "Speeding (%d km/h, limit %d)" % [int(kmh), int(lim)]
	var fa := "سرعت غیرمجاز (%s کیلومتر، مجاز %s)" % [Lang.digits(str(int(kmh))), Lang.digits(str(int(lim)))]
	# Reuse the v7a CityFund speeding fine for the farmer so its counter,
	# ledger line and report stay one system.
	var v7a := _v7a()
	if who == "player" and v7a and v7a.fund:
		v7a.fund.fine_speeding(kmh / 3.6)
		fine = v7a.fund.style().speeding_fine if v7a.fund.style() else fine
	else:
		CityState.add_fine("speeding", fine, en, fa, who == "player")
		WorldMemory.file_report("speeding", who, "", fine)
	TrafficState.stat("speeding")
	_after_catch(car, who, "speeding", fine, en, fa, p)


func _v7a() -> V7aWorld:
	var sc := get_tree().current_scene
	return sc.find_child("V7aWorld", true, false) as V7aWorld if sc else null


func _catch(car: DrivableCar, who: String, kind: String, fine: int, en: String, fa: String, p: Vector2, junc: Dictionary = {}) -> void:
	CityState.add_fine(kind, fine, en, fa, who == "player")
	WorldMemory.file_report(kind, who, "", fine)
	TrafficState.stat({"red_light": "red_runs", "stop_sign": "stop_runs", "unlicensed": "unlicensed"}.get(kind, kind))
	_after_catch(car, who, kind, fine, en, fa, p, junc)


func _after_catch(car: DrivableCar, who: String, kind: String, fine: int, en: String, fa: String, p: Vector2, junc: Dictionary = {}) -> void:
	var st := style()
	var cam := signals.nearest_camera(car.global_position, st.enforcement_range if st else 30.0)
	if not cam.is_empty():
		signals.flash(cam)
		last_flash_cam = cam
		TrafficState.stat("flashes")
	if signals.officer and signals.officer_pos.distance_to(car.global_position) < 25.0 and st:
		var lines: Array = st.officer_lines.get("caught", [])
		signals.officer_say(lines.pick_random() if not lines.is_empty() else {"en": en, "fa": fa})
	TrafficState.add_news(en, fa)
	last_offense = {"kind": kind, "who": who, "fine": fine, "en": en, "fa": fa, "day": TimeManager.day,
		"junc": str(junc.get("id", "")), "pos": p}
	var n := TrafficState.add_offence(who)
	GameEvents.notification_requested.emit(Lang.tt("تخلف: %s - جریمه %s سکه" % [fa, Lang.digits(str(fine))],
		"Offence: %s - fine %d G" % [en, fine]))
	if st and n >= st.offences_to_confiscate:
		_confiscate(car, who)


func _confiscate(car: DrivableCar, who: String) -> void:
	var ls := Modules.style("driving_license") as LicenseStyle
	var days := ls.confiscation_days if ls else 2
	TrafficState.confiscate(who, days)
	if who == "player" and car.driver:
		car.get_out()
	if impound:
		impound.take(car)
	TrafficState.stat("impounds")
	TrafficState.add_news("A car was impounded after a second offence.", "بعد از تخلف دوم یک ماشین توقیف شد.")
	GameEvents.notification_requested.emit(Lang.tt("گواهینامه‌ات توقیف شد و ماشین به پارکینگ توقیف رفت. بعد از %s روز دوباره امتحان بده." % Lang.digits(str(days)),
		"Your licence is confiscated and the car was towed. Retake the test after %d days." % days))


## Tests / shots: force an offence of `kind` on the currently driven car.
func force_offense(kind: String) -> Dictionary:
	var car: DrivableCar = null
	for c in _cars():
		car = c
		break
	if car == null:
		for n in get_tree().get_nodes_in_group(&"drivable_cars"):
			car = n as DrivableCar
			break
	if car == null:
		return {}
	var who := _driver_id(car)
	var st := style()
	var p := Vector2(car.global_position.x, car.global_position.z)
	match kind:
		"speeding":
			_catch_speeding(car, who, 80.0, 40.0, p)
		"red_light":
			_catch(car, who, "red_light", st.red_light_fine if st else 150, "Running a red light", "رد کردن چراغ قرمز", p)
		"stop_sign":
			_catch(car, who, "stop_sign", st.stop_sign_fine if st else 60, "Rolling through a STOP sign", "رد کردن تابلوی ایست بدون توقف", p)
		"unlicensed":
			_catch(car, who, "unlicensed", st.unlicensed_fine if st else 100, "Driving without a licence", "رانندگی بدون گواهینامه", p)
	return last_offense


# ------------------------------------------------------------------ AI cars
## RoadCar.traffic_gate target: caps an AI car's wanted speed (m/s) for the
## speed limit, red lights, STOP signs and the car in front. Emergency
## vehicles with sirens on skip lights and STOP signs.
static var ai_enabled: bool = true
static var _signals_ref: WeakRef


static func ai_gate(car: RoadCar, want: float) -> float:
	if not ai_enabled or not is_instance_valid(car) or not car.is_inside_tree():
		return want
	var p := Vector2(car.global_position.x, car.global_position.z)
	var f3 := car.forward()
	var fwd := Vector2(f3.x, f3.z)
	var out := want
	# Speed limit (km/h -> m/s); sirens may go 30 % over.
	var lim := TrafficKit.limit_kmh(p) / 3.6
	# Look ahead (nose + braking distance) so a car is already slow when it
	# enters a lower-limit zone (school zone, the square).
	var look := car.size.z * 0.5 + 2.0 + car.cur_speed * car.cur_speed / 18.0
	lim = minf(lim, TrafficKit.limit_kmh(p + fwd.normalized() * look) / 3.6)
	out = minf(out, lim * (1.3 if car.flashing else 1.0))
	var sig: TrafficSignals = _signals_ref.get_ref() as TrafficSignals if _signals_ref else null
	if sig and not car.flashing:
		for id in sig.junctions:
			var j: Dictionary = sig.junctions[id]
			if (j["pos"] as Vector2).distance_to(p) > 26.0:
				continue
			for a: Dictionary in j["arms"]:
				var ap := TrafficKit.arm_pos(a, j["pos"], p, fwd)
				if float(ap["align"]) < 0.6 or absf(float(ap["lat"])) > float(a["half"]) + 1.0:
					continue
				var front := float(ap["s"]) + car.size.z * 0.5   # nose relative to the stop line
				if front > 0.6 or front < -18.0:
					continue
				var light := sig.light_for(j, a)
				if light == "red" or (light == "yellow" and front < -4.0):
					out = minf(out, maxf((-front - 0.6) * 0.7, 0.0))
					if car.cur_speed < 0.4:
						var w := float(car.get_meta(&"red_wait", 0.0)) + 0.016
						car.set_meta(&"red_wait", w)
						sig.report_wait(str(id), w)
				else:
					car.set_meta(&"red_wait", 0.0)
		for id in sig.stops:
			var sj: Dictionary = sig.stops[id]
			if (sj["pos"] as Vector2).distance_to(p) > 22.0:
				continue
			for a: Dictionary in sj["arms"]:
				var ap := TrafficKit.arm_pos(a, sj["pos"], p, fwd)
				if float(ap["align"]) < 0.6 or absf(float(ap["lat"])) > float(a["half"]) + 1.0:
					continue
				var front := float(ap["s"]) + car.size.z * 0.5
				var key := StringName("stop_" + str(id))
				if front > 3.0 or front < -18.0:
					if front < -18.0:
						car.remove_meta(key)
					continue
				var held := float(car.get_meta(key, 0.0))
				var rs := TrafficKit.rules()
				var need := rs.stop_hold_s if rs else 5.0
				if held < need:
					out = minf(out, maxf((-front - 0.4) * 0.7, 0.0))
					if car.cur_speed < 0.3 and front > -3.5:
						car.set_meta(key, held + car.get_physics_process_delta_time())
	# Keep a gap to whatever drives in front (AI cars and the farmer's car).
	var gap := 7.0
	var nt := Modules.style("npc_traffic") as NpcTrafficStyle
	if nt:
		gap = nt.gap
	# A car left standing in the lane (nobody in it) blocks for a while; after
	# ~6 s the AI squeezes past it (no AI car is ever stuck for good).
	var now := Time.get_ticks_msec()
	var squeeze := int(car.get_meta(&"squeeze_until", 0)) > now
	var parked_block := false
	for g: StringName in [&"road_cars", &"drivable_cars"]:
		for n in car.get_tree().get_nodes_in_group(g):
			var o := n as Node3D
			if o == null or o == car or not o.is_visible_in_tree():
				continue
			var parked := o is DrivableCar and (o as DrivableCar).driver == null
			if parked and squeeze:
				continue
			var d := Vector2(o.global_position.x, o.global_position.z) - p
			var ahead := d.dot(fwd)
			if ahead <= 0.0 or ahead > gap + car.size.z + 6.0:
				continue
			if absf(d.dot(Vector2(-fwd.y, fwd.x))) > 1.5:
				continue
			var free := ahead - car.size.z * 0.5 - 2.5
			var cap := maxf(free - gap * 0.4, 0.0) * 0.8
			if cap < out:
				out = cap
				parked_block = parked
	if parked_block and car.cur_speed < 0.3:
		var bw := float(car.get_meta(&"parked_wait", 0.0)) + car.get_physics_process_delta_time()
		car.set_meta(&"parked_wait", bw)
		if bw > 6.0:
			car.set_meta(&"squeeze_until", now + 5000)
			car.set_meta(&"parked_wait", 0.0)
	elif not parked_block:
		car.set_meta(&"parked_wait", 0.0)
	return out
