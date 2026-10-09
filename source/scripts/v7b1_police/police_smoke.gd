extends RefCounted
## v7b.1 police / road-safety smoke (DevTools section _smoke_v7b1_police):
##  1. a police car (RoadCar) at 36 km/h with a pedestrian ahead stops before
##     contact, waits, the pedestrian steps aside, it drives on - no hit;
##     same for the farmer standing in the lane (waits, no time-out);
##  2. a low-speed hit (farmer's car) -> the person stumbles, Persian bubble, gets up;
##  3. a high-speed hit -> person stays down, ambulance + police dispatched with
##     lights, crowd of >= 3 gathers and talks (chat log), police fine, the
##     paramedics treat, the person gets up and everyone goes back to routine.

var t  # DevTools


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func _find(nm: String) -> Node:
	return _tree().current_scene.find_child(nm, true, false)


static func _fa(s: String) -> bool:
	for i in s.length():
		var c := s.unicode_at(i)
		if c >= 0x0600 and c <= 0x06FF:
			return true
	return false


func _free_bots(n: int, exclude: Array = []) -> Array[TownspersonBot]:
	var out: Array[TownspersonBot] = []
	for b in V7aKit.bots(_tree()):
		if out.size() >= n:
			break
		if b in exclude or b.hidden_inside or b.resident.is_empty() or int(b.resident.get("age", 18)) < 8:
			continue
		if not (b.controller is ScheduleController):
			continue
		out.append(b)
	return out


func _put_bot(b: TownspersonBot, p: Vector3) -> void:
	b.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z) + 0.05, p.z)
	b.velocity = Vector3.ZERO


func _stand(b: TownspersonBot) -> V7aKit.ScriptController:
	var sc := V7aKit.ScriptController.new()
	sc.original = b.controller
	sc.tag = "smoke_stand"
	b.set_controller(sc)
	return sc


func _lane() -> PackedVector3Array:
	var raw := VehicleKit.lane(VehicleKit.route(Vector3(14, 0, -50), Vector3(60, 0, -50)))
	return raw


## Point `d` m along the polyline.
static func _at(path: PackedVector3Array, d: float) -> Vector3:
	var acc := 0.0
	for i in range(1, path.size()):
		var l := path[i - 1].distance_to(path[i])
		if acc + l >= d:
			return path[i - 1].lerp(path[i], (d - acc) / maxf(l, 0.001))
		acc += l
	return path[path.size() - 1]


func _gap(car: Node3D, size_z: float, fwd: Vector3, who: Node3D) -> float:
	var rel := who.global_position - car.global_position
	rel.y = 0.0
	return rel.dot(fwd) - size_z * 0.5


func run() -> bool:
	var pw := _find("V7b1PoliceWorld") as V7b1PoliceWorld
	var w6 := _find("V6bWorld") as V6bWorld
	t._check(pw != null and pw.accidents != null, "V7b1PoliceWorld + AccidentResponse")
	t._check(Modules.style("road_safety") is RoadSafetyStyle, "road_safety module (%s)" % (Modules.style("road_safety").id if Modules.style("road_safety") else "-"))
	t._check(RoadCar.people_gate.is_valid() and TownspersonBot.move_filter.is_valid(), "RoadCar.people_gate + TownspersonBot.move_filter hooks set")
	if pw == null or w6 == null or w6.police == null or w6.ambulance == null:
		return false
	var ar := pw.accidents
	var auto0 := ar.auto
	ar.reset()
	ar.auto = true
	TimeManager.reset_calendar(TimeManager.day, 11.0, "sunny")
	var ok1 := await _yield_police(w6, ar)
	var ok2 := await _light_hit(ar)
	var ok3 := await _hard_hit(w6, ar)
	ar.reset()
	ar.auto = auto0
	return ok1 and ok2 and ok3


# ------------------------------------------------------------------ 1. yield
func _yield_police(w6: V6bWorld, ar: AccidentResponse) -> bool:
	var pol := w6.police
	var car := pol.car
	var path := _lane()
	t._check(path.size() >= 2, "Main St east lane path (%d pts)" % path.size())
	if path.size() < 2:
		return false
	await t._place(Vector2(26.0, -43.6), 180.0)
	var bots := _free_bots(1)
	if bots.is_empty():
		t._check(false, "a free townsperson for the yield test")
		return false
	var ped := bots[0]
	var sc := _stand(ped)
	var p0 := path[0]
	car.place(p0, atan2(path[1].x - p0.x, path[1].z - p0.z))
	_put_bot(ped, _at(path, 24.0))
	var hits0 := ar.hits
	var speed0 := car.speed
	var yield_style := RoadSafety.style()
	var aside_delay := yield_style.step_aside_s
	# First verify braking against a stationary blocker, then verify the
	# configured waiting/step-aside behaviour as a separate phase.
	yield_style.step_aside_s = 30.0
	for key in [&"rs_wait", &"rs_next", &"rs_cap", &"rs_blocker", &"rs_yielding"]:
		car.remove_meta(key)
	car.speed = 10.0   # 36 km/h: needs ~12 m to stop (old check looked 3.2 m past the nose)
	car.follow(path)
	await t._frames(2)
	var min_gap := INF
	var stopped_f := -1
	var top := 0.0
	for i in 480:
		await t._frames(1)
		top = maxf(top, car.cur_speed)
		min_gap = minf(min_gap, _gap(car, car.size.z, car.forward(), ped))
		if car.cur_speed < 0.05 and stopped_f < 0 and i > 20:
			stopped_f = i
			break
	yield_style.step_aside_s = aside_delay
	car.set_meta(&"rs_wait", 0.0)
	t._check(top > 7.0, "police car got up to speed (%.1f km/h)" % (top * 3.6))
	t._check(stopped_f >= 0 and min_gap > 0.4, "police car stops before the pedestrian (gap %.2f m, stopped at frame %d)" % [min_gap, stopped_f])
	t._check(ar.hits == hits0, "no contact (hits %d)" % (ar.hits - hits0))
	# Waiting, not driving through: the pedestrian steps aside after step_aside_s, then the car goes on.
	var st := RoadSafety.style()
	var steps0 := RoadSafety.step_asides
	var passed := false
	for i in 420:
		await t._frames(1)
		min_gap = minf(min_gap, _gap(car, car.size.z, car.forward(), ped) if _gap(car, car.size.z, car.forward(), ped) > -car.size.z else INF)
		if RoadSafety.step_asides > steps0 and _gap(car, car.size.z, car.forward(), ped) < -1.0:
			passed = true
			break
	t._check(RoadSafety.step_asides > steps0, "pedestrian stepped aside after ~%.1f s of waiting" % (st.step_aside_s if st else 0.0))
	t._check(passed and ar.hits == hits0, "police car drove on past without touching anyone (hits %d)" % (ar.hits - hits0))
	ped.remove_meta(&"rs_step")
	ped.set_controller(sc.original)
	# The farmer standing in the lane: the car waits (no time-out any more).
	car.place(p0, atan2(path[1].x - p0.x, path[1].z - p0.z))
	var pp := _at(path, 20.0)
	await t._place(Vector2(pp.x, pp.z), 0.0, 2)
	car.follow(path)
	var pgap := INF
	for i in 330:
		await t._frames(1)
		pgap = minf(pgap, _gap(car, car.size.z, car.forward(), t._player))
	t._check(pgap > 0.4 and car.cur_speed < 0.05 and ar.hits == hits0, "police car waits for the farmer in the lane (gap %.2f m after 5.5 s)" % pgap)
	car.speed = speed0
	await t._place(Vector2(26.0, -43.6), 180.0, 2)
	pol._on_arrived()
	car.stop()
	car.place(pol.base_pos(), PI * 0.5)
	return true


# ------------------------------------------------------------------ 2. light hit
func _town_car() -> DrivableCar:
	for n in _tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		if c and not (c is DrivableBus) and not c.key.begins_with("owned_") and not c.has_meta(&"impounded") and c.is_inside_tree():
			return c
	return null


func _put_car(c: DrivableCar, p: Vector3, yaw: float) -> void:
	c.speed = 0.0
	c.velocity = Vector3.ZERO
	c.yaw = yaw
	c.rotation = Vector3(0, yaw, 0)
	c.global_position = Vector3(p.x, Terrain.height_at(p.x, p.z) + 0.1, p.z)


func _light_hit(ar: AccidentResponse) -> bool:
	var car := _town_car()
	var bots := _free_bots(1)
	if car == null or bots.is_empty():
		t._check(false, "town car + townsperson for the hit tests")
		return false
	TrafficState.reset()
	TrafficState.grant(false)
	var path := _lane()
	var keep := car.global_transform
	var yaw := atan2(path[1].x - path[0].x, path[1].z - path[0].z)
	var c0 := _at(path, 6.0)
	_put_car(car, c0, yaw)
	await t._frames(3)
	car.get_in(t._player)
	var b := bots[0]
	var sc := _stand(b)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	_put_bot(b, c0 + fwd * (car.size.z * 0.5 + 1.6))
	await t._frames(2)
	var hits0 := ar.hits
	car.speed = 2.2
	car.auto_input = {"throttle": 0.15, "steer": 0.0, "brake": false}
	for i in 120:
		await t._frames(1)
		if ar.hits > hits0:
			break
	car.auto_input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	var h := ar.last_hit
	var kmh := float(h.get("kmh", 0.0))
	t._check(ar.hits > hits0 and h.get("person") == b, "low-speed hit detected (%.1f km/h)" % kmh)
	t._check(not bool(h.get("hard", true)), "counted as a light hit (< %.0f km/h)" % RoadSafety.style().hard_hit_kmh)
	var hc := b.controller as HitReactController
	t._check(hc != null and hc.mode in ["stumble", "fall"], "person reacts (%s)" % (hc.describe() if hc else str(b.controller)))
	t._check(b._bubble.visible and _fa(b._bubble.text), "Persian exclamation bubble: %s" % b._bubble.text)
	var low_pose := false
	for i in 60:
		await t._frames(1)
		var ps := b.visual.get_pose()
		if ps == &"kneel" or ps == &"lie":
			low_pose = true
	t._check(low_pose, "stumble pose (one knee / ground)")
	var up := false
	for i in 360:
		await t._frames(1)
		if b.controller == sc:
			up = true
			break
	t._check(up and b.visual.get_pose() == &"" and not b.has_meta(&"rs_down"), "got back up and resumed (pose '%s')" % b.visual.get_pose())
	t._check(ar.accidents.is_empty(), "no ambulance / police for a light hit")
	b.set_controller(sc.original)
	car.auto_input = {}
	car.get_out()
	car.global_transform = keep
	car.yaw = keep.basis.get_euler().y
	await t._frames(2)
	return true


# ------------------------------------------------------------------ 3. hard hit
func _hard_hit(w6: V6bWorld, ar: AccidentResponse) -> bool:
	var car := _town_car()
	if car == null:
		return false
	# Earlier gearbox tests may leave this shared car in first gear.
	var systems := car.get_node_or_null(^"CarSystems") as CarSystems
	if systems:
		systems.set_auto(true)
		systems.state()["fuel"] = 100.0
		systems.state()["condition"] = 100.0
	var amb := w6.ambulance
	var pol := w6.police
	amb.reset()
	amb.auto_dispatch = false
	pol.responding = false
	pol.car.stop()
	pol.car.place(pol.base_pos(), PI * 0.5)
	TrafficState.reset()
	TrafficState.grant(false)
	var path := _lane()
	var keep := car.global_transform
	var yaw := atan2(path[1].x - path[0].x, path[1].z - path[0].z)
	var c0 := _at(path, 4.0)
	_put_car(car, c0, yaw)
	await t._frames(3)
	car.get_in(t._player)
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var right := Vector3(-fwd.z, 0, fwd.x)
	var spot := c0 + fwd * (car.size.z * 0.5 + 3.0)
	# Hit reactions use a real-time cooldown. Headless physics can execute the
	# light-hit scenario in less than that cooldown, so use a different victim.
	var bots := _free_bots(6, [ar.last_hit.get("person")])
	if bots.size() < 5:
		t._check(false, "enough townspeople for the crowd test (%d)" % bots.size())
		return false
	var v := bots[0]
	var vsc := _stand(v)
	_put_bot(v, spot)
	# Four onlookers on the pavements within ~15 m.
	var crowd_src: Array[TownspersonBot] = []
	for i in range(1, 5):
		var side := 1.0 if i % 2 == 0 else -1.0
		_put_bot(bots[i], spot + fwd * (4.0 + i * 2.5) + right * side * 6.2)
		crowd_src.append(bots[i])
	await t._frames(2)
	var fines0 := CityState.fines_total
	var hits0 := ar.hard_hits
	car.speed = 9.5   # ~34 km/h
	car.auto_input = {"throttle": 0.8, "steer": 0.0, "brake": false}
	for i in 90:
		await t._frames(1)
		if ar.hard_hits > hits0:
			break
	car.auto_input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	var h := ar.last_hit
	t._check(ar.hard_hits > hits0 and h.get("person") == v, "high-speed hit detected (%.1f km/h)" % float(h.get("kmh", 0.0)))
	if ar.accidents.is_empty():
		t._check(false, "accident scene started")
		car.auto_input = {}
		car.get_out()
		car.global_transform = keep
		return false
	var acc: Dictionary = ar.accidents[0]
	var hc := v.controller as HitReactController
	t._check(hc != null and hc.mode == "down", "person stays down (%s)" % (hc.describe() if hc else "-"))
	t._check(_fa(v._bubble.text), "hurt line in Persian: %s" % v._bubble.text)
	t._check(str(acc["amb_state"]) == "coming" and amb.car.flashing and amb.car.moving, "ambulance dispatched with lights (%s)" % str(acc["amb_state"]))
	t._check(str(acc["police_state"]) in ["coming", "on_scene"] and pol.car.flashing and pol.responding, "police dispatched with lights (%s)" % str(acc["police_state"]))
	var crowd: Array = acc["crowd"]
	t._check(crowd.size() >= 3, "crowd gathers (%d townspeople)" % crowd.size())
	car.auto_input = {}
	car.get_out()
	await t._frames(2)
	# Let it play: crowd walks in and talks, ambulance + police arrive.
	var lines0 := ar.lines_said
	var log0 := TownLife.chat_log.size()
	var amb_f := -1
	var pol_f := -1
	var stayed_down := true
	for i in 1500:
		await t._frames(1)
		if not bool(acc["treated"]):
			stayed_down = stayed_down and hc != null and v.controller == hc and hc.mode == "down"
		if amb_f < 0 and str(acc["amb_state"]) in ["treating", "done"]:
			amb_f = i
		if pol_f < 0 and str(acc["police_state"]) == "on_scene":
			pol_f = i
		if amb_f >= 0 and pol_f >= 0 and i > amb_f + 30:
			break
	var near := 0
	for c: Dictionary in crowd:
		var cb := c["bot"] as TownspersonBot
		if is_instance_valid(cb) and RoadSafety.flat(cb.global_position).distance_to(RoadSafety.flat(acc["pos"])) < 5.0:
			near += 1
	t._check(near >= 3, "crowd of %d around the person (<5 m)" % near)
	t._check(ar.lines_said - lines0 >= 3 and TownLife.chat_log.size() > log0, "crowd chatter (%d lines, chat log +%d)" % [ar.lines_said - lines0, TownLife.chat_log.size() - log0])
	t._check(amb_f >= 0, "ambulance arrived, paramedics treating (frame %d)" % amb_f)
	t._check(pol_f >= 0, "police arrived (frame %d)" % pol_f)
	t._check(stayed_down, "person stayed down until treated")
	if pol_f < 0:
		ar._on_police_arrived(acc)
	if amb_f < 0:
		ar._on_amb_arrived(acc)
	t._check(bool(acc["fined"]) and CityState.fines_total > fines0 and TrafficState.offence_count("player") >= 1,
		"driver fined + offence (fine %d, offences %d)" % [int(acc["fine"]), TrafficState.offence_count("player")])
	# Treatment -> gets up.
	var up := false
	for i in 600:
		await t._frames(1)
		if v.controller == vsc:
			up = true
			break
	t._check(up and bool(acc["treated"]) and v.visual.get_pose() == &"", "treated on the spot, back on their feet (no death)")
	t._check(amb.status() in ["returning", "idle"] and amb.auto_dispatch == false, "ambulance heads back (%s)" % amb.status())
	ar.reset()
	await t._frames(2)
	var restored := 0
	for cb in crowd_src:
		if not (cb.controller is V7aKit.ScriptController and (cb.controller as V7aKit.ScriptController).tag == "accident_crowd"):
			restored += 1
	t._check(restored == crowd_src.size() and ar.accidents.is_empty(), "crowd back to their routine (%d / %d)" % [restored, crowd_src.size()])
	v.set_controller(vsc.original)
	car.global_transform = keep
	car.yaw = keep.basis.get_euler().y
	TrafficState.reset()
	amb.reset()
	return true
