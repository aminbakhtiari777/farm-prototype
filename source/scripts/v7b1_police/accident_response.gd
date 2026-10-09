class_name AccidentResponse
extends Node
## v7b.1 "road_safety" module, part 2 (police workstream): when any car (the
## farmer's, a possessed resident's or an AI car) touches a person:
##  - light hit: knock-back, one knee (or a short fall), a Persian exclamation
##    bubble, they get back up;
##  - hard hit (>= hard_hit_kmh): they stay down; the ambulance (AmbulanceService
##    car + paramedics) and the police (PolicePatrol car + an officer) drive to
##    the spot with lights on, nearby townspeople gather in a ring and talk (chat
##    log), the police fine the driver (TrafficRules offence -> impound on the
##    2nd offence), the paramedics treat the person on the spot and they get up.
## Non-graphic (no blood), nobody dies. Contact test: car footprint vs. people
## from RoadSafety's per-frame grid, only for moving cars (far ones every 6th frame).

signal hit_registered(info: Dictionary)
signal accident_started(acc: Dictionary)
signal accident_finished(acc: Dictionary)

var auto: bool = true          ## false = no automatic contact detection (tests drive it)
var hits: int = 0
var hard_hits: int = 0
var last_hit: Dictionary = {}
var accidents: Array = []      ## active hard-hit scenes
var finished_accidents: int = 0
var reactions: Array = []      ## [{bot, hc}]
var lines_said: int = 0
var _cool: Dictionary = {}     ## person id -> msec
var _last_speed: Dictionary = {}
var _frame_i: int = 0
var _rng := RandomNumberGenerator.new()


func style() -> RoadSafetyStyle:
	return RoadSafety.style()


func _ready() -> void:
	_rng.randomize()


func _v6b() -> V6bWorld:
	var sc := get_tree().current_scene
	return sc.find_child("V6bWorld", true, false) as V6bWorld if sc else null


func _traffic() -> V7b1TrafficWorld:
	var sc := get_tree().current_scene
	return sc.find_child("V7b1TrafficWorld", true, false) as V7b1TrafficWorld if sc else null


func _line(kind: String) -> Array:
	var st := style()
	var list: Array = st.lines.get(kind, []) if st else []
	if list.is_empty():
		return ["...", "..."]
	var e: Dictionary = list[_rng.randi() % list.size()]
	return [str(e.get("en", "")), str(e.get("fa", ""))]


static func _txt(pair: Array) -> String:
	return str(pair[1]) if Lang.is_fa() else str(pair[0])


func _name_of(b: Node3D) -> String:
	var tb := b as TownspersonBot
	if tb == null or tb.resident.is_empty():
		return str(b.name)
	return Dialogue.first_name(tb.resident) if Lang.is_fa() else str(tb.resident.get("name", tb.display_name))


func _say(b: Node3D, pair: Array, seconds: float = 3.4) -> void:
	if b == null or not is_instance_valid(b):
		return
	if b is TownspersonBot:
		(b as TownspersonBot).say(_txt(pair), seconds)
	else:
		V7bKit.say_small(b, _txt(pair), seconds, 34)
	TownLife.log_line(_name_of(b), str(pair[0]), str(pair[1]))
	lines_said += 1


# ------------------------------------------------------------------ detection
func _physics_process(delta: float) -> void:
	if auto:
		_detect()
	for r in reactions.duplicate():
		var b := r["bot"] as TownspersonBot if is_instance_valid(r["bot"]) else null
		var hc: HitReactController = r["hc"]
		if b == null:
			reactions.erase(r)
			continue
		if hc.finished or b.controller != hc:
			if b.controller == hc:
				b.set_controller(hc.original)
			b.remove_meta(&"rs_down")
			reactions.erase(r)
	for acc in accidents.duplicate():
		_update(acc, delta)


func _detect() -> void:
	var st := style()
	if st == null or not st.enabled:
		return
	var tree := get_tree()
	_frame_i += 1
	var cam := RoadSafety.camera_pos(tree)
	var seen := {}
	for e: Dictionary in RoadSafety.moving_cars(tree):
		var car: Node3D = e["car"]
		if not is_instance_valid(car):
			continue
		var id := car.get_instance_id()
		var spd: float = e["speed"]
		var impact := maxf(spd, float(_last_speed.get(id, 0.0)))
		seen[id] = spd
		if cam != Vector3.INF and cam.distance_to(car.global_position) > st.near_radius and _frame_i % 6 != 0:
			continue
		if impact * 3.6 < st.hit_min_kmh:
			continue
		var p0: Vector2 = e["pos"]
		var fwd: Vector2 = e["fwd"]
		var perp := Vector2(-fwd.y, fwd.x)
		var hw: float = e["hw"]
		var hl: float = e["hl"]
		for n in RoadSafety.people_near(tree, p0, hl + 2.0):
			var b := n as Node3D
			if b == null or b == car or not is_instance_valid(b):
				continue
			var rel := RoadSafety.flat(b.global_position) - p0
			if absf(rel.dot(perp)) > hw + 0.36:
				continue
			var lon := rel.dot(fwd)
			if lon < -hl or lon > hl + 0.38:
				continue
			register_hit(b, car, impact * 3.6)
	_last_speed = seen


func _busy_victim(b: Node3D) -> bool:
	if b.has_meta(&"rs_down"):
		return true
	var tb := b as TownspersonBot
	return tb != null and (tb.controller is HitReactController or tb.hidden_inside)


## A car touched a person at `kmh`. Public for tests. Returns the hit info ({} = ignored).
func register_hit(person: Node3D, car: Node3D, kmh: float) -> Dictionary:
	var st := style()
	if st == null or person == null or not is_instance_valid(person):
		return {}
	var pid := person.get_instance_id()
	var now := Time.get_ticks_msec()
	if int(_cool.get(pid, 0)) > now or _busy_victim(person):
		return {}
	_cool[pid] = now + 4000
	hits += 1
	var hard := kmh >= st.hard_hit_kmh
	var info := {"person": person, "car": car, "kmh": kmh, "hard": hard, "pos": person.global_position,
		"who": _driver_id(car), "msec": now}
	last_hit = info
	# The car stops (an AI car never drives on through a person).
	if car is RoadCar:
		(car as RoadCar).cur_speed = 0.0
		if (car as RoadCar).moving:
			_say(car, _line("driver_sorry"), 3.0)
	elif car is DrivableCar:
		(car as DrivableCar).speed *= 0.2
	if person is Player:
		_player_hit(person as Player, car, kmh)
	elif person is TownspersonBot:
		var b := person as TownspersonBot
		if b.controller is Possession.PossessController:
			GameEvents.notification_requested.emit(_txt(_line("player_hit")))
		else:
			_bot_hit(b, car, kmh, hard)
			if hard:
				_start_accident(info)
			elif st.light_hit_fine > 0 and car is DrivableCar:
				_fine(car, str(info["who"]), st.light_hit_fine, kmh, person.global_position)
	hit_registered.emit(info)
	return info


func _driver_id(car: Node3D) -> String:
	if car is DrivableCar:
		var tw := _traffic()
		if tw and tw.rules and (car as DrivableCar).driver != null:
			return tw.rules._driver_id(car as DrivableCar)
		return "player" if (car as DrivableCar).driver != null else ""
	return str(car.name) if car else ""


func _player_hit(p: Player, car: Node3D, _kmh: float) -> void:
	var away := RoadSafety.flat(p.global_position - car.global_position).normalized()
	if away == Vector2.ZERO:
		away = Vector2(1, 0)
	p.global_position += Vector3(away.x, 0.0, away.y) * 0.8
	GameEvents.notification_requested.emit(_txt(_line("player_hit")))


func _bot_hit(b: TownspersonBot, car: Node3D, kmh: float, hard: bool) -> void:
	var st := style()
	var hc := HitReactController.new()
	hc.original = b.controller
	var away := b.global_position - car.global_position
	away.y = 0.0
	hc.push_dir = away.normalized() if away.length() > 0.05 else Vector3.RIGHT
	hc.push_t = clampf(kmh / 60.0, 0.15, 0.5)
	hc.face_yaw = atan2(-away.x, -away.z)
	if hard:
		hc.mode = "down"
	elif kmh >= st.fall_kmh:
		hc.mode = "fall"
		hc.hold = st.fall_s
	else:
		hc.mode = "stumble"
		hc.hold = st.stumble_s
	var pair := _line("hurt" if hard else "exclaim")
	hc.line = _txt(pair)
	b.set_controller(hc)
	b.set_meta(&"rs_down", true)
	_say(b, pair, 3.2)
	reactions.append({"bot": b, "hc": hc})


# ------------------------------------------------------------------ hard hit
func _start_accident(info: Dictionary) -> Dictionary:
	var b := info["person"] as TownspersonBot
	var acc := {"victim": b, "car": info["car"], "kmh": info["kmh"], "who": info["who"],
		"pos": b.global_position, "t": 0.0, "crowd": [], "amb_state": "", "amb_t": 0.0, "treat_t": 0.0,
		"police_state": "", "police_t": 0.0, "fined": false, "fine": 0, "treated": false, "end_t": 0.0,
		"chat_t": 1.2, "chat_i": 0, "last_line": "", "officer": null}
	hard_hits += 1
	accidents.append(acc)
	_dispatch_ambulance(acc)
	_dispatch_police(acc)
	_gather(acc)
	TrafficState.add_news("A pedestrian was hit by a car; the ambulance came. Drive slowly!",
		"یک عابر پیاده با ماشین تصادف کرد؛ آمبولانس آمد. آرام برانید!")
	TrafficState.stat("pedestrian_hits")
	if not b.resident.is_empty():
		WorldMemory.npc_remember(Friendship.key_of(b), "accident", "A car hit me; the paramedics helped me.",
			"ماشین به من زد؛ امدادگرها کمکم کردند.")
	GameEvents.notification_requested.emit(Lang.tt("تصادف با عابر پیاده! آمبولانس و پلیس در راه‌اند.",
		"A pedestrian was hit! The ambulance and the police are on the way."))
	accident_started.emit(acc)
	return acc


## Route to `target` that stops `keep` m before it (never over the person).
static func drive_near(car: RoadCar, target: Vector3, keep: float) -> void:
	var raw := VehicleKit.lane(VehicleKit.route(car.global_position, target))
	var dense := PackedVector3Array()
	for i in raw.size():
		if i > 0:
			var a := raw[i - 1]
			var d := raw[i] - a
			var n := int(d.length() / 2.0)
			for k in range(1, n):
				dense.append(a + d * (float(k) / n))
		dense.append(raw[i])
	var t2 := RoadSafety.flat(target)
	while dense.size() > 0 and RoadSafety.flat(dense[dense.size() - 1]).distance_to(t2) < keep:
		dense.remove_at(dense.size() - 1)
	if dense.size() == 0:
		car.stop()
		car.call_deferred("emit_signal", "arrived")
		return
	car.follow(dense)


func _dispatch_ambulance(acc: Dictionary) -> void:
	var w := _v6b()
	var amb := w.ambulance if w else null
	if amb == null or amb.car == null:
		acc["amb_state"] = "none"
		return
	if amb.state != AmbulanceService.State.IDLE and amb.state != AmbulanceService.State.RETURNING:
		acc["amb_state"] = "waiting"
		return
	amb.state = AmbulanceService.State.IDLE
	acc["amb_auto"] = amb.auto_dispatch
	amb.auto_dispatch = false   # keep the car for this scene (illness calls resume after)
	acc["amb"] = amb
	acc["amb_state"] = "coming"
	acc["amb_t"] = 0.0
	amb.car.set_flashing(true)
	var cb := _on_amb_arrived.bind(acc)
	acc["amb_cb"] = cb
	amb.car.arrived.connect(cb, CONNECT_ONE_SHOT)
	drive_near(amb.car, acc["pos"], 8.0)


func _on_amb_arrived(acc: Dictionary) -> void:
	if str(acc["amb_state"]) != "coming":
		return
	var amb: AmbulanceService = acc["amb"]
	acc["amb_state"] = "treating"
	acc["treat_t"] = 0.0
	amb.car.stop()
	amb._show_crew(true)
	var v: TownspersonBot = acc["victim"]
	if not is_instance_valid(v):
		return
	# Paramedics kneel by the person (the 'doctor visit').
	for i in amb.crew.size():
		var c := amb.crew[i]
		var side := Vector3(0.9 if i == 0 else -0.9, 0.0, 0.5)
		var p := v.global_position + side
		c.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
		var f := v.global_position - c.global_position
		c.rotation.y = atan2(f.x, f.z)
		if i == 0:
			c.set_pose(&"kneel")
	if amb.crew.size() > 0:
		_say(amb.crew[0], _line("paramedic"), 3.4)


func _dispatch_police(acc: Dictionary) -> void:
	var w := _v6b()
	var pol := w.police if w else null
	if pol == null or pol.car == null:
		acc["police_state"] = "none"
		_fine_acc(acc)
		return
	acc["pol"] = pol
	acc["police_t"] = 0.0
	if acc["car"] == pol.car:
		# The police car itself was involved: it is already there.
		pol.car.stop()
		_on_police_arrived(acc)
		get_tree().create_timer(12.0).timeout.connect(func() -> void:
			if is_instance_valid(pol) and pol.car and not pol.car.moving:
				pol._on_arrived())
		return
	acc["police_state"] = "coming"
	pol.responding = true
	pol.car.set_flashing(true)
	var pcb := _on_police_arrived.bind(acc)
	acc["pol_cb"] = pcb
	pol.car.arrived.connect(pcb, CONNECT_ONE_SHOT)
	drive_near(pol.car, acc["pos"], 10.0)


func _on_police_arrived(acc: Dictionary) -> void:
	if str(acc["police_state"]) == "on_scene" or not accidents.has(acc):
		return
	acc["police_state"] = "on_scene"
	var pol: PolicePatrol = acc.get("pol")
	if pol and pol.car:
		pol.car.stop()
		# An officer steps out next to the car for a while.
		var off := HumanoidModelVisual.new()
		off.name = "AccidentOfficer"
		off.body_type = "male"
		off.shirt_color = Color(0.16, 0.24, 0.42)
		off.pants_color = Color(0.12, 0.14, 0.2)
		off.top_style = "jacket"
		off.hair_style = "Hair_Buzzed"
		add_child(off)
		var right := Vector3(-pol.car.forward().z, 0, pol.car.forward().x)
		var p: Vector3 = pol.car.global_position + right * (pol.car.size.x * 0.5 + 0.8)
		off.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
		var f: Vector3 = acc["pos"] - off.global_position
		off.rotation.y = atan2(f.x, f.z)
		acc["officer"] = off
		_say(off, _line("police"), 3.6)
		get_tree().create_timer(14.0).timeout.connect(func() -> void:
			if is_instance_valid(off):
				off.queue_free())
	_fine_acc(acc)


func _fine_acc(acc: Dictionary) -> void:
	if bool(acc["fined"]):
		return
	acc["fined"] = true
	var st := style()
	var car: Node3D = acc["car"]
	var w := _v6b()
	if w and w.police and car == w.police.car:
		TrafficState.add_news("A police car was involved in an accident; an inquiry was opened.",
			"یک ماشین پلیس در تصادف دخیل بود؛ پرونده بررسی شد.")
		return
	acc["fine"] = _fine(car, str(acc["who"]), st.hit_fine if st else 250, float(acc["kmh"]), acc["pos"])


## Fine / offence for the driver. The farmer (or a possessed resident) goes
## through TrafficRules (offence points -> licence + impound); AI drivers pay the city fund.
func _fine(car: Node3D, who: String, fine: int, kmh: float, at: Vector3) -> int:
	var en := "Hitting a pedestrian (%d km/h)" % int(kmh)
	var fa := "زدن عابر پیاده (%s کیلومتر)" % Lang.digits(str(int(kmh)))
	var tw := _traffic()
	if car is DrivableCar and who != "" and tw and tw.rules:
		tw.rules._catch(car as DrivableCar, who, "hit_pedestrian", fine, en, fa, RoadSafety.flat(at))
		return fine
	CityState.add_fine("hit_pedestrian", fine, en, fa, false)
	WorldMemory.file_report("hit_pedestrian", who, "", fine)
	TrafficState.stat("hit_pedestrian")
	TrafficState.add_news(en, fa)
	return fine


func _free_bot(b: TownspersonBot) -> bool:
	if b.hidden_inside or b.has_meta(&"rs_down") or b.controller == null:
		return false
	if b.controller is Possession.PossessController or b.controller is AmbulanceService.RideController \
			or b.controller is HitReactController or b.controller is V7aKit.ScriptController:
		return false
	return b.resident.is_empty() or int(b.resident.get("age", 18)) >= 6


func _gather(acc: Dictionary) -> void:
	var st := style()
	var v: TownspersonBot = acc["victim"]
	var at: Vector3 = acc["pos"]
	var radius := st.crowd_radius if st else 35.0
	var cands: Array = []
	for b in V7aKit.bots(get_tree()):
		if b == v or not _free_bot(b):
			continue
		var d := RoadSafety.flat(b.global_position).distance_to(RoadSafety.flat(at))
		if d <= radius * 1.8:
			cands.append([d, b])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return float(x[0]) < float(y[0]))
	var want := st.crowd_max if st else 6
	var picked: Array = []
	for c in cands:
		if picked.size() >= want:
			break
		# Inside the radius always; beyond it only to reach the minimum crowd.
		if float(c[0]) <= radius or picked.size() < (st.crowd_min if st else 3):
			picked.append(c[1])
	var ring := st.crowd_ring if st else 2.6
	var base := _rng.randf() * TAU
	for i in picked.size():
		var b: TownspersonBot = picked[i]
		var ang := base + TAU * float(i) / float(picked.size())
		var p := at + Vector3(cos(ang), 0.0, sin(ang)) * ring
		var sc := V7aKit.ScriptController.new()
		sc.original = b.controller
		sc.target = Vector3(p.x, Terrain.height_at(p.x, p.z), p.z)
		sc.speed = 2.0
		sc.face_to = at
		sc.pose = &"talk"
		sc.tag = "accident_crowd"
		b.set_controller(sc)
		(acc["crowd"] as Array).append({"bot": b, "sc": sc})


func _update(acc: Dictionary, delta: float) -> void:
	var st := style()
	acc["t"] = float(acc["t"]) + delta
	var v := acc["victim"] as TownspersonBot if is_instance_valid(acc["victim"]) else null
	# Ambulance: retry when busy, unstick when blocked close by, treat on the spot.
	match str(acc["amb_state"]):
		"waiting":
			acc["amb_t"] = float(acc["amb_t"]) + delta
			if float(acc["amb_t"]) > 2.0:
				acc["amb_t"] = 0.0
				_dispatch_ambulance(acc)
		"coming":
			var amb: AmbulanceService = acc["amb"]
			acc["amb_t"] = float(acc["amb_t"]) + delta
			var near := amb.car.global_position.distance_to(acc["pos"]) < 16.0
			if near and amb.car.cur_speed < 0.3:
				acc["amb_stop_t"] = float(acc.get("amb_stop_t", 0.0)) + delta
				if float(acc["amb_stop_t"]) > 2.5:
					_disconnect(amb.car, acc.get("amb_cb"))
					_on_amb_arrived(acc)
			else:
				acc["amb_stop_t"] = 0.0
		"treating":
			acc["treat_t"] = float(acc["treat_t"]) + delta
			if float(acc["treat_t"]) >= (st.treat_s if st else 6.0) and not bool(acc["treated"]):
				_treated(acc)
	# Police that never get there (blocked / far): the fine still comes by post.
	if str(acc["police_state"]) == "coming":
		acc["police_t"] = float(acc["police_t"]) + delta
		if float(acc["police_t"]) > 60.0:
			acc["police_state"] = "late"
			_fine_acc(acc)
	if not bool(acc["treated"]) and float(acc["t"]) > (st.down_max_s if st else 90.0):
		_treated(acc)
	# The crowd talks about it.
	acc["chat_t"] = float(acc["chat_t"]) - delta
	if float(acc["chat_t"]) <= 0.0 and not (acc["crowd"] as Array).is_empty():
		acc["chat_t"] = st.chat_every_s if st else 2.8
		var crowd: Array = acc["crowd"]
		var c: Dictionary = crowd[int(acc["chat_i"]) % crowd.size()]
		acc["chat_i"] = int(acc["chat_i"]) + 1
		var b := c["bot"] as TownspersonBot if is_instance_valid(c["bot"]) else null
		if b and b.controller == c["sc"]:
			var pair := _line("crowd")
			if str(pair[1]) == str(acc["last_line"]):
				pair = _line("crowd")
			acc["last_line"] = str(pair[1])
			_say(b, pair, st.chat_every_s + 0.6 if st else 3.4)
	if bool(acc["treated"]):
		acc["end_t"] = float(acc["end_t"]) + delta
		if float(acc["end_t"]) > (st.crowd_stay_s if st else 8.0):
			_end(acc)
	elif v == null:
		_end(acc)


func _treated(acc: Dictionary) -> void:
	acc["treated"] = true
	var v := acc["victim"] as TownspersonBot if is_instance_valid(acc["victim"]) else null
	if v:
		var hc := v.controller as HitReactController
		if hc:
			hc.release()
		_say(v, _line("recovered"), 3.6)
	var amb: AmbulanceService = acc.get("amb")
	if amb and str(acc["amb_state"]) in ["coming", "treating"]:
		_disconnect(amb.car, acc.get("amb_cb"))
		for c in amb.crew:
			c.set_pose(&"")
		amb._show_crew(false)
		amb._go_back()
		amb.auto_dispatch = bool(acc.get("amb_auto", true))
	acc["amb_state"] = "done"


static func _disconnect(car: RoadCar, cb: Variant) -> void:
	if car and cb is Callable and car.arrived.is_connected(cb):
		car.arrived.disconnect(cb)


func _end(acc: Dictionary) -> void:
	for c: Dictionary in acc["crowd"]:
		var b := c["bot"] as TownspersonBot if is_instance_valid(c["bot"]) else null
		var sc: V7aKit.ScriptController = c["sc"]
		if b and b.controller == sc:
			b.set_controller(sc.original)
	(acc["crowd"] as Array).clear()
	if not bool(acc["fined"]):
		_fine_acc(acc)
	var pol: PolicePatrol = acc.get("pol")
	if pol and str(acc["police_state"]) == "coming":
		_disconnect(pol.car, acc.get("pol_cb"))
		pol.responding = false
		pol.car.set_flashing(false)
		pol._on_arrived()
	accidents.erase(acc)
	finished_accidents += 1
	accident_finished.emit(acc)


## Tests: end every scene now, hand everyone back to their routine.
func reset() -> void:
	for acc in accidents.duplicate():
		if not bool(acc["treated"]):
			_treated(acc)
		_end(acc)
	for r in reactions:
		var b := r["bot"] as TownspersonBot if is_instance_valid(r["bot"]) else null
		if b:
			if b.controller == r["hc"]:
				b.set_controller((r["hc"] as HitReactController).original)
			b.remove_meta(&"rs_down")
	reactions.clear()
	_cool.clear()
