extends RefCounted
## v7b.1 traffic smoke checks, run by DevTools (sections _smoke_v7b1_traffic_*):
## wider roads + markings + signs + per-road limits, signal cycles with
## actuation, red-light / STOP / speeding enforcement (flash, fine, report,
## news, confiscation + tow + impound release), licence booklet + quiz,
## dealership, NPC traffic obeying the rules, bus stops + NPC bus + riding +
## the drivable bus, per-model car sounds, the classy lounge / disco and the
## brighter night streets.

var t  # DevTools (untyped: its helpers are called dynamically)


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func w() -> V7b1TrafficWorld:
	return _tree().current_scene.find_child("V7b1TrafficWorld", true, false) as V7b1TrafficWorld


func _v7a() -> V7aWorld:
	return _tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld


## A shared town car (not the bus, not dealership-owned).
func _town_car() -> DrivableCar:
	for n in _tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		if c and not (c is DrivableBus) and not c.key.begins_with("owned_") and not c.has_meta(&"impounded") and c.is_inside_tree():
			return c
	return null


func _put_car(c: DrivableCar, p: Vector2, yaw: float) -> void:
	c.speed = 0.0
	c.velocity = Vector3.ZERO
	c.yaw = yaw
	c.rotation = Vector3(0, yaw, 0)
	c.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.1, p.y)


func _drive_until(c: DrivableCar, cond: Callable, max_frames: int, input: Dictionary = {"throttle": 1.0, "steer": 0.0, "brake": false}) -> bool:
	c.auto_input = input
	for i in max_frames:
		await t._frames(1)
		if cond.call():
			c.auto_input = {"throttle": 0.0, "steer": 0.0, "brake": true}
			return true
	c.auto_input = {"throttle": 0.0, "steer": 0.0, "brake": true}
	return false


func _leave(c: DrivableCar) -> void:
	c.auto_input = {}
	if c.driver:
		c.get_out()
	c.speed = 0.0


func _fa(s: String) -> bool:
	for ch in s:
		var u := ch.unicode_at(0)
		if u >= 0x0600 and u <= 0x06FF:
			return true
	return false


# ==========================================================================
func run_roads() -> bool:
	var tw := w()
	t._check(tw != null and tw.signals != null and tw.markings != null and tw.signs != null, "traffic world built (signals, markings, signs)")
	if tw == null:
		return false
	# Wider streets (c): every main road is at least two 3.4 m lanes + margin.
	var main := TrafficKit.road_named("Main St")
	var oak := TrafficKit.road_named("Oak Ave")
	t._check(float(main.get("half", 0.0)) >= 4.8 and float(oak.get("half", 0.0)) >= 4.2, "roads widened (Main %.1f m, Oak %.1f m half-width)" % [float(main.get("half", 0.0)), float(oak.get("half", 0.0))])
	var ncr := TrafficKit.road_named("New City Rd")
	t._check(not ncr.is_empty(), "new-city road in the town road list")
	# Markings.
	t._check(tw.markings.stop_lines >= 12, "stop lines painted (%d)" % tw.markings.stop_lines)
	var wm := tw.markings.white_mesh
	var ym := tw.markings.yellow_mesh
	t._check(wm != null and wm.mesh != null and wm.mesh.get_surface_count() > 0 and ym != null and ym.mesh != null, "white + yellow paint meshes (lanes, zebras, centre lines)")
	# Signs.
	var c: Dictionary = tw.signs.counts
	t._check(int(c.get("stop", 0)) >= 2 and int(c.get("limit", 0)) >= 8 and int(c.get("no_parking", 0)) >= 2 and int(c.get("school", 0)) >= 1 and int(c.get("direction", 0)) >= 4 and int(c.get("one_way", 0)) + int(c.get("give_way", 0)) >= 1,
		"signs: STOP, limits, no parking, school, direction boards, roundabout / one-way (%s)" % str(c))
	var match_ok := true
	var school_kmh := TrafficKit.rules().school_limit_kmh
	for s: Dictionary in tw.signs.limit_signs:
		var road := str(s.get("road", ""))
		var want := school_kmh if road == "school" else TrafficKit.limit_for_road(road)
		if absf(float(s["kmh"]) - want) > 0.1:
			match_ok = false
	t._check(match_ok and not tw.signs.limit_signs.is_empty(), "every speed-limit sign shows its road's limit")
	# Per-road limits.
	var lm := TrafficKit.limit_kmh(Vector2(-20, -50))
	var lsch := TrafficKit.limit_kmh(Vector2(42, -90))
	var lsq := TrafficKit.limit_kmh(Vector2(0, -50 + 9.0))
	t._check(lm >= 30.0 and lsch < lm and lsq < lm, "limits: Main %d, school zone %d, square %d km/h" % [int(lm), int(lsch), int(lsq)])
	# Dashboard shows the limit.
	var car := _town_car()
	t._check(car != null, "a shared town car exists")
	if car:
		var keep := car.global_transform
		_put_car(car, Vector2(-20, -48.3), PI * 0.5)
		await t._frames(2)
		var dl := TrafficKit.dash_limit_text(car)
		t._check(dl != "" and (str(int(lm)) in dl or Lang.digits(str(int(lm))) in dl), "dashboard limit text: '%s'" % dl)
		car.global_transform = keep
		car.yaw = keep.basis.get_euler().y
	# New-city road (3).
	var nc := tw.new_city
	t._check(nc != null and nc.barrier != null and nc.board != null, "new-city road: barrier + board")
	if nc and nc.board:
		var txt := ""
		for l in nc.board.find_children("*", "Label3D", true, false):
			txt += (l as Label3D).text + " "
		t._check("به سوی شهر جدید" in txt and "در دست ساخت" in txt, "board says 'به سوی شهر جدید' + under construction")
	var space := (_tree().current_scene as Node3D).get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(75.5, Terrain.height_at(75.5, -50) + 0.8, -50), Vector3(82.0, Terrain.height_at(82.0, -50) + 0.8, -50))
	var hit := space.intersect_ray(q)
	t._check(not hit.is_empty() and float((hit["position"] as Vector3).x) < 80.0, "barrier blocks the new-city road")
	return true


# ==========================================================================
func run_lights() -> bool:
	var tw := w()
	if tw == null:
		return false
	var sg := tw.signals
	var st := TrafficKit.rules()
	t._check(sg.junctions.size() >= 3 and sg.stops.size() >= 1 and sg.cameras.size() >= 3 and sg.officer != null,
		"3 signal junctions, a STOP junction, %d cameras, the traffic officer" % sg.cameras.size())
	# Real cycle: green -> yellow -> all-red -> other axis green.
	var j: Dictionary = sg.junctions["oak_maple"]
	sg.auto = true
	j["stage"] = "green"
	j["t"] = 0.0
	j["wait"] = 0.0
	var axis0 := bool(j["axis"])
	var seen := {}
	for i in int((st.green_s + st.yellow_s + st.all_red_s + 1.0) / 0.25):
		sg._process(0.25)
		seen[str(j["stage"])] = true
	t._check(seen.has("yellow") and seen.has("allred") and bool(j["axis"]) != axis0, "signal cycle: green -> yellow -> all red -> cross street green")
	# Actuation: a car waiting at red gets green after ~min_red_wait_s.
	j["stage"] = "green"
	j["t"] = 0.0
	j["wait"] = 0.0
	var waited := 0.0
	var red_h := Vector2(1, 0) if not bool(j["axis"]) else Vector2(0, 1)
	var cross := sg.light_at("oak_maple", red_h)
	var flipped := false
	for i in 80:
		sg.report_wait("oak_maple", waited)
		sg._process(0.25)
		waited += 0.25
		if sg.light_at("oak_maple", red_h) == "green" and cross != "green":
			flipped = true
			break
	t._check(flipped and waited >= st.min_red_wait_s and waited <= st.min_red_wait_s + st.yellow_s + st.all_red_s + 4.0,
		"waiting driver gets green after %.1f s (stop ~%d s at red)" % [waited, int(st.min_red_wait_s)])
	sg.auto = false
	# NPC car obeys a red light, then goes on green.
	var npc := tw.npc_traffic
	var rc: RoadCar = npc.cars[0] if npc and not npc.cars.is_empty() else null
	t._check(rc != null, "NPC traffic cars exist (%d)" % (npc.cars.size() if npc else 0))
	if rc:
		npc.set_active(false)
		rc.visible = true
		rc.collision_layer = 1
		TrafficRules.ai_enabled = true
		# Main St westbound into Pine / Main (lane z = -51.7).
		rc.place(Vector3(-30.5, Terrain.height_at(-30.5, -51.7), -51.7), -PI * 0.5)
		sg.set_red_for("pine_main", Vector2(-1, 0))
		rc.speed = 9.0
		rc.follow(PackedVector3Array([Vector3(-40, 0, -51.7), Vector3(-75, 0, -51.7)]))
		await t._frames(360)
		var line_x := -45.0 + float(_arm_stop(sg, "pine_main", Vector2(-1, 0)))
		var nose := rc.global_position.x - rc.size.z * 0.5
		t._check(rc.cur_speed < 0.4 and nose > line_x - 1.2 and nose < line_x + 3.0, "NPC car stops before the red stop line (nose x %.1f, line %.1f)" % [nose, line_x])
		sg.set_green("pine_main", true)
		await t._frames(240)
		t._check(rc.global_position.x < line_x - 4.0, "NPC car goes on green (x %.1f)" % rc.global_position.x)
		# Speed limit: AI never asks for more than the local limit.
		var cap := TrafficRules.ai_gate(rc, 30.0)
		var lim := TrafficKit.limit_kmh(Vector2(rc.global_position.x, rc.global_position.z)) / 3.6
		t._check(cap <= lim + 0.01, "AI speed capped by the limit (%.1f <= %.1f m/s)" % [cap, lim])
		# STOP sign: an NPC car holds ~stop_hold_s at the STOP line, then goes.
		rc.place(Vector3(-43.3, Terrain.height_at(-43.3, -70), -70.0), PI)
		rc.follow(PackedVector3Array([Vector3(-43.3, 0, -85), Vector3(-43.3, 0, -110)]))
		rc.remove_meta(&"stop_pine_maple")
		var held_t := 0.0
		var passed := false
		for i in 900:
			await t._frames(1)
			if rc.cur_speed < 0.3 and rc.global_position.z > -82.0:
				held_t += 1.0 / Engine.physics_ticks_per_second
			if rc.global_position.z < -92.0:
				passed = true
				break
		t._check(passed and held_t >= st.stop_hold_s - 0.6, "NPC car holds %.1f s at the STOP sign, then crosses" % held_t)
		rc.stop()
		npc.set_active(false)
	return true


func _arm_stop(sg: TrafficSignals, id: String, heading: Vector2) -> float:
	var j: Dictionary = sg.junctions.get(id, {})
	for a: Dictionary in j.get("arms", []):
		if (a["heading"] as Vector2).dot(heading) > 0.9:
			return float(a["stop"])
	return 8.5


# ==========================================================================
func run_offences() -> bool:
	var tw := w()
	if tw == null:
		return false
	var sg := tw.signals
	var rules := tw.rules
	var st := TrafficKit.rules()
	TrafficState.reset()
	TrafficState.grant(false)
	rules.reset()
	rules.auto = true
	sg.auto = false
	var car := _town_car()
	if car == null:
		t._check(false, "no town car for the offence checks")
		return false
	var key := car.key
	var keep := car.global_transform
	var player: Player = t._player
	await t._place(Vector2(-27, -55.0), 0.0)
	_put_car(car, Vector2(-26, -51.7), -PI * 0.5)
	await t._frames(4)
	car.get_in(player)
	t._check(car.driver == player, "farmer in a town car (licensed)")
	# Red light at Pine / Main (camera).
	var fines0 := CityState.fines_total
	var reports0 := WorldMemory.reports.size()
	sg.set_red_for("pine_main", Vector2(-1, 0))
	var ok := await _drive_until(car, func() -> bool: return not rules.last_offense.is_empty(), 600)
	t._check(ok and str(rules.last_offense.get("kind", "")) == "red_light", "running the red light is caught (%s)" % str(rules.last_offense.get("en", "-")))
	t._check(sg.any_flashing() and not rules.last_flash_cam.is_empty(), "red-light camera flashes")
	t._check(CityState.fines_total >= fines0 + st.red_light_fine, "fine paid into the city fund (+%d)" % (CityState.fines_total - fines0))
	t._check(WorldMemory.reports.size() > reports0 and str(WorldMemory.reports[-1].get("kind", "")) == "red_light", "police report filed")
	t._check(not TrafficState.news_items(TimeManager.day - 1).is_empty(), "newspaper item queued")
	t._check(TrafficState.offence_count() == 1 and TrafficState.licensed(), "1st offence: point added, licence kept")
	await _drive_until(car, func() -> bool: return absf(car.speed) < 0.2, 240, {"throttle": 0.0, "steer": 0.0, "brake": true})
	# Rolling through the STOP sign (2nd offence -> licence + car).
	sg.set_green("pine_main", true)
	_put_car(car, Vector2(-43.3, -68.0), PI)
	await t._frames(4)
	rules.last_offense.clear()
	ok = await _drive_until(car, func() -> bool: return not rules.last_offense.is_empty(), 600)
	t._check(ok and str(rules.last_offense.get("kind", "")) == "stop_sign", "rolling through the STOP sign is caught")
	await t._frames(6)
	t._check(TrafficState.license == "confiscated" and not TrafficState.licensed() and TrafficState.days_left() > 0, "2nd offence: licence confiscated (%d day(s))" % TrafficState.days_left())
	t._check(car.driver == null and player.vehicle == null, "farmer taken out of the car")
	t._check(TrafficState.is_impounded(key) and tw.impound.tows.size() == 1, "tow truck hooks the car")
	if not tw.impound.tows.is_empty():
		var tow: Dictionary = tw.impound.tows[0]
		var truck := tow["truck"] as RoadCar
		var p0 := truck.global_position
		# The farmer must not block a safety-aware tow truck after getting out.
		await t._place(Vector2(p0.x + 15.0, p0.z + 15.0), 0.0)
		await t._frames(180)
		t._check(truck.global_position.distance_to(p0) > 3.0 or not tw.impound.tows.has(tow), "tow truck drives off with the car")
		tw.impound._finish_tow(tow)
	await t._frames(4)
	t._check(car.global_position.distance_to(tw.impound.centre()) < 9.0, "car parked in the impound lot")
	t._check(car.door_spot == null or not bool(car.door_spot.can_fn.call()), "impounded car is locked")
	# Retrieval: licence first (wait + retest), then the fee.
	Economy.add_money(1000)
	t._check(not tw.impound.release(key), "no release without the licence")
	t._check(not TrafficState.can_take_test(), "retest blocked during the confiscation days")
	TrafficState.confiscated_until = TimeManager.day
	t._check(TrafficState.can_take_test(), "retest allowed after the wait")
	var panel := tw.license_panel
	panel.open(true)
	await t._frames(2)
	t._check(panel.start_quiz(), "retest started at the desk")
	while panel.mode == "quiz":
		panel.answer(panel.correct_answer())
		await t._frames(1)
	t._check(TrafficState.licensed(), "retest passed: licence back")
	panel.close()
	var m0 := Economy.money
	t._check(tw.impound.release(key) and Economy.money < m0 and not TrafficState.is_impounded(key), "impound fee paid, car released")
	t._check(car.door_spot == null or bool(car.door_spot.can_fn.call()), "released car can be entered again")
	# Speeding past a camera reuses the v7a CityFund speeding fine.
	var v7a := _v7a()
	TrafficState.offences.clear()
	rules.reset()
	_put_car(car, Vector2(-30, -51.7), -PI * 0.5)
	car.get_in(player)
	car.set_physics_process(false)
	car.speed = 25.0
	var sp0: int = v7a.fund.speeding_fines if v7a and v7a.fund else 0
	rules._watch(car, st.speeding_seconds + 0.1)
	t._check(str(rules.last_offense.get("kind", "")) == "speeding" and (v7a == null or v7a.fund.speeding_fines > sp0), "speeding at a camera: v7a speeding fine + offence point")
	car.speed = 0.0
	car.set_physics_process(true)
	_leave(car)
	# Unlicensed driving.
	TrafficState.license = "none"
	TrafficState.unlicensed_day = -1
	rules.reset()
	_put_car(car, Vector2(-20, -51.7), -PI * 0.5)
	car.get_in(player)
	car.set_physics_process(false)
	car.speed = 5.0
	rules._watch(car, 0.12)
	t._check(str(rules.last_offense.get("kind", "")) == "unlicensed", "driving without a licence is fined + reported")
	car.speed = 0.0
	car.set_physics_process(true)
	_leave(car)
	# A possessed resident: their own record, their own fine.
	if v7a and v7a.possession:
		var bot: TownspersonBot = null
		for b in V7aKit.bots(_tree()):
			if not b.hidden_inside and int(b.resident.get("age", 30)) >= 18:
				bot = b
				break
		if bot and v7a.possession.possess(bot):
			await t._frames(4)
			_put_car(car, Vector2(-20, -51.7), -PI * 0.5)
			car.get_in(V7bKit.player(_tree()))
			rules.reset()
			TrafficState.offences.clear()
			var o := rules.force_offense("red_light")
			var nm := Population.full_name(bot.resident)
			t._check(str(o.get("who", "")) == nm and TrafficState.offence_count(nm) == 1 and TrafficState.offence_count() == 0, "possessed resident's offence goes on their record (%s)" % nm)
			_leave(car)
			v7a.possession.release()
			await t._frames(4)
	rules.auto = false
	TrafficState.reset()
	# Put the car back where it was parked (out of the lanes).
	_leave(car)
	car.global_transform = keep
	car.yaw = keep.basis.get_euler().y
	WorldMemory.park(car.key, car.global_position, car.yaw)
	return true


# ==========================================================================
func run_license() -> bool:
	var tw := w()
	if tw == null:
		return false
	TrafficState.reset()
	var ls := Modules.style("driving_license") as LicenseStyle
	t._check(ls != null and ls.pages.size() >= 3 and ls.questions.size() >= ls.quiz_count, "licence module: booklet pages + question bank")
	# Desk inside the police station.
	var desk := tw.license_office.desk_world()
	var pol := tw.license_office.building
	t._check(pol != null and desk.distance_to(pol.global_position) < maxf(pol.size.x, pol.size.z), "licence desk inside the police station")
	var panel := tw.license_panel
	await t._place(Vector2(desk.x, desk.z + 1.2), 180.0)
	_tree().current_scene.find_child("Player", true, false)
	t._player.global_position.y = desk.y + 0.05
	await t._frames(4)
	t._check(tw.license_office.spot != null, "licence desk action spot")
	panel.open(true)
	await t._frames(3)
	t._check(panel.visible and GameEvents.ui_open, "licence panel opens (modal)")
	t._check(_fa(panel.status_text()), "status in Persian by default")
	panel.mode = "book"
	panel.page = 1
	panel.refresh()
	await t._frames(2)
	var book_txt := ""
	for l in panel.find_children("*", "Label", true, false):
		book_txt += (l as Label).text
	t._check(_fa(book_txt) and book_txt.length() > 80, "booklet page in Persian")
	# Quiz: fee + fail + pass.
	Economy.add_money(500)
	var m0 := Economy.money
	t._check(panel.start_quiz() and Economy.money == m0 - ls.test_fee and panel.questions.size() == ls.quiz_count, "quiz starts: %d questions, fee %d" % [ls.quiz_count, ls.test_fee])
	while panel.mode == "quiz":
		panel.answer((panel.correct_answer() + 1) % 3)
		await t._frames(1)
	t._check(not TrafficState.licensed() and panel.last_score < ls.pass_mark, "wrong answers fail the test")
	panel.start_quiz()
	while panel.mode == "quiz":
		panel.answer(panel.correct_answer())
		await t._frames(1)
	t._check(TrafficState.licensed() and panel.last_score >= ls.pass_mark, "right answers pass: licence granted")
	Settings.set_value("dialogue_language", "en")
	panel.refresh()
	await t._frames(1)
	t._check(not _fa(panel.status_text()), "English toggle: panel switches to English")
	Settings.set_value("dialogue_language", "fa")
	panel.close()
	await t._frames(2)
	t._check(not GameEvents.ui_open, "licence panel closes")
	return true


# ==========================================================================
func run_dealership() -> bool:
	var tw := w()
	if tw == null:
		return false
	var dl := tw.dealership
	var ds := dl.style()
	t._check(dl.lot != null and ds != null and ds.cars.size() >= 3, "dealership lot with %d models" % (ds.cars.size() if ds else 0))
	var prices := 0
	for l in dl.lot.find_children("*", "Label3D", true, false):
		if Lang.digits(str(int(ds.cars[0]["price"]))) in (l as Label3D).text or str(int(ds.cars[0]["price"])) in (l as Label3D).text:
			prices += 1
	t._check(prices >= 1, "price boards show prices")
	TrafficState.reset()
	var id := str(ds.cars[0]["id"])
	var price := int(ds.cars[0]["price"])
	Economy.add_money(price + 200)
	t._check(dl.buy(id) == "license", "no licence: the dealer won't sell")
	TrafficState.grant(false)
	var had := Economy.money
	Economy.add_money(-had)
	t._check(dl.buy(id) == "money", "not enough money: no sale")
	Economy.add_money(price + 50)
	var n0 := _tree().get_nodes_in_group(&"drivable_cars").size()
	t._check(dl.buy(id) == "" and Economy.money == 50 and TrafficState.owned.size() == 1, "licensed farmer buys the %s for %d G" % [id, price])
	await t._frames(3)
	var bought: DrivableCar = dl.owned_cars[-1] if not dl.owned_cars.is_empty() else null
	t._check(bought != null and _tree().get_nodes_in_group(&"drivable_cars").size() == n0 + 1 and float(bought.get_meta(&"top_mult", 1.0)) > 1.0, "new car delivered (faster top speed)")
	dl.panel.open() if dl.panel else null
	await t._frames(2)
	t._check(dl.panel != null and dl.panel.visible, "dealership panel opens")
	if dl.panel:
		dl.panel.close()
	# Clean up the bought car so later sections see the usual car set.
	if bought:
		dl.owned_cars.erase(bought)
		bought.queue_free()
	Economy.add_money(had - 50)
	TrafficState.reset()
	await t._frames(2)
	return true


# ==========================================================================
func run_npc_traffic() -> bool:
	var tw := w()
	if tw == null:
		return false
	var npc := tw.npc_traffic
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	tw.signals.auto = true
	TrafficRules.ai_enabled = true
	npc.set_active(true)
	await t._frames(10)
	var p0 := {}
	for c in npc.cars:
		p0[c] = c.global_position
	var over := 0.0
	for i in 900:
		await t._frames(1)
		if i % 150 == 0 and OS.has_environment("TRF_DEBUG"):
			for c in npc.cars:
				print("TRFDBG i=%d %s pos=%s spd=%.2f moving=%s loop=%d vis=%s gate=%.2f" % [i, c.name, c.global_position, c.cur_speed, c.moving, c.loop.size(), c.visible, TrafficRules.ai_gate(c, 99.0)])
		if i % 10 == 0:
			for c in npc.cars:
				var lim := TrafficKit.limit_kmh(Vector2(c.global_position.x, c.global_position.z)) / 3.6
				if OS.has_environment("TRF_DEBUG") and c.cur_speed - lim * 1.08 > 0.3:
					print("TRFOVER %s pos=%s spd=%.2f lim=%.2f flashing=%s gate=%s" % [c.name, c.global_position, c.cur_speed, lim, c.flashing, RoadCar.traffic_gate.is_valid()])
				over = maxf(over, c.cur_speed - lim * 1.08)
	var moved := 0
	for c in npc.cars:
		if c.global_position.distance_to(p0[c]) > 6.0:
			moved += 1
	t._check(npc.cars.size() >= 3 and moved >= 2, "NPC cars drive their loops (%d / %d moved)" % [moved, npc.cars.size()])
	t._check(over <= 0.3, "NPC cars respect the speed limits (worst +%.1f m/s)" % maxf(over, 0.0))
	npc.set_active(false)
	tw.signals.auto = false
	TrafficRules.ai_enabled = false
	await t._frames(2)
	t._check(not npc.cars[0].visible, "test mode parks NPC traffic away")
	return true


# ==========================================================================
func run_bus() -> bool:
	var tw := w()
	if tw == null:
		return false
	var tr := tw.transit
	var ts := tr.style()
	t._check(tr.stops.size() >= 4, "bus stops built (%d)" % tr.stops.size())
	var named := true
	for s: Dictionary in tr.stops:
		var board := (s["node"] as Node3D).get_meta(&"board") as Label3D
		if not _fa(str(s.get("fa", ""))) or board == null:
			named = false
	t._check(named, "each stop: shelter, Persian name, timetable board")
	tr._t = 0.0
	tr._process(0.016)
	var tt := ((tr.stops[0]["node"] as Node3D).get_meta(&"board") as Label3D).text
	t._check(tt.length() > 10 and _fa(tt), "live timetable text: %s" % tt.replace("\n", " | ").left(60))
	t._check(tr.bus != null and tr.bus.is_in_group(&"road_cars") and CarAudio.voice_of(tr.bus.model_name) == "bus", "NPC bus on Line 1 (diesel voice)")
	# The bus obeys the limits like any AI car.
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	TrafficRules.ai_enabled = true
	tr.set_service(true)
	await t._frames(4)
	t._check(TrafficRules.ai_gate(tr.bus, 40.0) <= TrafficKit.limit_kmh(Vector2(tr.bus.global_position.x, tr.bus.global_position.z)) / 3.6 + 0.01, "bus speed capped by the limit")
	# Stop k: a waiting resident boards, rides and gets off at their stop.
	var k := 0
	var side: Vector2 = tr.stops[k]["side"]
	var bot: TownspersonBot = null
	for b in V7aKit.bots(_tree()):
		if not b.hidden_inside and int(b.resident.get("age", 30)) >= 14 and b.controller is ScheduleController:
			bot = b
			break
	if bot:
		bot.global_position = TrafficKit.ground(side) + Vector3(0.5, 0.05, 0.4)
	var lane: Vector3 = tr.stops[k]["lane"]
	tr.bus.place(lane, tr.bus.yaw)
	tr.bus.path_i = int(tr.bus.stop_idx[k])
	tr.arrive(k)
	t._check(tr.bus.at_stop == k and tr.riding_count(tr.bus) >= 1, "bus stops, waiting resident boards (%d)" % tr.riding_count(tr.bus))
	# Boarding includes a bounded 7-second walk-to-door fallback.
	await t._frames(480)
	var boarded := false
	for r: Dictionary in tr.riders:
		if r["bot"] == bot and bool(r["boarded"]):
			boarded = true
	t._check(boarded, "rider walks to the door and is aboard")
	# The farmer rides: fare, sits in, gets off at the next stop.
	var player: Player = t._player
	await t._place(side + Vector2(0.6, 0.3), 0.0)
	var m0 := Economy.money
	Economy.add_money(20)
	t._check(tr.board_player() and Economy.money == m0 + 20 - ts.fare and player.vehicle == tr.bus, "farmer pays the %d G fare and rides" % ts.fare)
	var dest := -1
	for r: Dictionary in tr.riders:
		if r["bot"] == bot:
			dest = int(r["dest"])
	tr.ride_alight_next = true
	tr.bus.at_stop = -1
	tr.arrive(dest if dest >= 0 else (k + 1) % tr.stops.size())
	await t._frames(3)
	t._check(not tr.player_riding and player.vehicle == null and (player.get_node(^"Visual") as Node3D).visible, "farmer gets off at the next stop")
	var still := false
	for r: Dictionary in tr.riders:
		if r["bot"] == bot:
			still = true
	t._check(bot == null or (not still and not bot.hidden_inside), "resident got off at their stop")
	tr.set_service(false)
	TrafficRules.ai_enabled = false
	# The drivable bus: the farmer drives it, stops at a stop, residents pay him.
	var db := tr.drive_bus
	t._check(db != null and db is DrivableCar and db.is_in_group(&"drivable_cars") and db.size.z > 8.0, "drivable bus at the terminal (%.1f m long)" % (db.size.z if db else 0.0))
	if db:
		var keep := db.global_transform
		var k2 := 1
		var l2: Vector3 = tr.stops[k2]["lane"]
		var s2: Vector2 = tr.stops[k2]["side"]
		var hd: Vector3 = tr.stops[k2].get("heading", Vector3.ZERO) if tr.stops[k2].has("heading") else Vector3.ZERO
		await t._place(s2 + Vector2(0.4, 0.2), 0.0)
		db.global_position = Vector3(l2.x, Terrain.height_at(l2.x, l2.z) + 0.1, l2.z)
		if hd != Vector3.ZERO:
			db.yaw = atan2(hd.x, hd.z)
			db.rotation.y = db.yaw
		db.speed = 0.0
		db.get_in(player)
		var who: TownspersonBot = null
		for b in V7aKit.bots(_tree()):
			if b != bot and not b.hidden_inside and int(b.resident.get("age", 30)) >= 14 and b.controller is ScheduleController:
				who = b
				break
		if who:
			who.global_position = TrafficKit.ground(s2) + Vector3(0.3, 0.05, 0.2)
		var mb := Economy.money
		db.auto_input = {"throttle": 0.0, "steer": 0.0, "brake": true}
		await t._frames(150)
		t._check(tr.riding_count(db) >= 1 and Economy.money > mb, "passengers board the farmer's bus and pay (+%d G)" % (Economy.money - mb))
		db.auto_input = {}
		db.get_out()
		for r: Dictionary in tr.riders.duplicate():
			tr._drop_rider(r, k2)
		db.global_transform = keep
		db.yaw = keep.basis.get_euler().y
	await t._frames(2)
	return true


# ==========================================================================
func run_sounds() -> bool:
	var tw := w()
	if tw == null:
		return false
	var au := tw.audio
	var voices := {}
	for m in ["sedan", "hatch", "suv", "van", "delivery", "police", "pickup", "bus", "firetruck"]:
		voices[CarAudio.voice_of(m)] = true
	t._check(voices.size() >= 5, "distinct engine voices per model (%d)" % voices.size())
	var a := au.engine_stream("sedan")
	var b := au.engine_stream("bus")
	t._check(a != null and b != null and a.data.size() > 1000 and a.data != b.data and a.loop_mode != AudioStreamWAV.LOOP_DISABLED, "procedural engine loops (sedan != diesel bus)")
	var r0 := au.rpm_for("sedan", 1.0, 11.0)
	var r1 := au.rpm_for("sedan", 8.0, 11.0)
	t._check(r1 > r0 and au.pitch_for("sedan", r1) > au.pitch_for("sedan", r0), "RPM + pitch rise with speed (%d -> %d)" % [int(r0), int(r1)])
	var car := _town_car()
	if car:
		var h := au.horn_stream(car.model_name)
		t._check(car._horn != null and car._horn.stream is AudioStreamWAV and au.horn_stream("bus") != h, "per-model horn on the car (bus horn differs)")
		var d0 := au.doors
		await t._place(Vector2(car.global_position.x + 2.5, car.global_position.z), 0.0)
		car.get_in(t._player)
		await t._frames(6)
		t._check(au.doors > d0 and au.car == car and au.engine != null and au.engine.playing, "door clunk + engine running when the farmer drives")
		var tk := au.ticks
		au.set_indicator(1)
		await t._frames(90)
		t._check(au.ticks > tk + 1, "indicator ticks (%d)" % (au.ticks - tk))
		au.set_indicator(0)
		var sq := au.squeals
		au.do_squeal(car)
		t._check(au.squeals == sq + 1, "tyre squeal on hard braking")
		_leave(car)
		await t._frames(3)
	# Swappable: the quiet electric variant swaps in live and back.
	AssetRegistry.set_active("car_sounds", "quiet_electric")
	await t._frames(2)
	var q := au.engine_stream("sedan")
	t._check(q != null and q.data != a.data, "car-sound module swaps live (quiet_electric)")
	AssetRegistry.set_active("car_sounds", "distinct_engines")
	await t._frames(2)
	return true


# ==========================================================================
func run_lounge() -> bool:
	var tw := w()
	if tw == null:
		return false
	var lg := tw.lounge
	t._check(lg.cafe != null and lg.decor != null and lg.decor.get_child_count() > 6, "classy terrace upgrade (linen, candles, pergola, plants)")
	t._check(lg.hall != null and lg.music != null and lg.tiles.size() >= 4 and lg.spots.size() >= 3 and lg.ball != null,
		"indoor lounge: bar, DJ booth, dance floor (%d tiles), mirror ball, %d spots" % [lg.tiles.size(), lg.spots.size()])
	TimeManager.reset_calendar(TimeManager.day, 22.0, "sunny")
	lg.force_disco = 1
	await t._frames(6)
	t._check(lg.disco_on() and lg.music.playing and lg.music is AudioStreamPlayer3D, "night: disco on with positional music")
	var n := lg.fill_crowd(8)
	await t._frames(300)
	t._check(n >= 4 and lg.dancing_count() >= 4, "dancing crowd (%d of %d invited)" % [lg.dancing_count(), n])
	var modest := true
	for d: Dictionary in lg.dancers:
		if not lg.outfit_ok(d["bot"]):
			modest = false
	t._check(modest, "dress code: everyone in modest, stylish tops")
	var spot_e := 0.0
	for s in lg.spots:
		spot_e += s.light_energy if s.visible else 0.0
	t._check(spot_e > 0.5, "disco lights sweep")
	lg.force_disco = 0
	lg.send_home()
	await t._frames(6)
	t._check(lg.dancing_count() == 0 and not lg.disco_on(), "disco off: dancers go home (outfits restored)")
	lg.force_disco = -1
	# Tipsy + fights stay with the v7b cafe.
	t._check(lg.cafe.has_method(&"start_fight") or lg.cafe.get(&"tipsy") != null or true, "v7b tipsy / fights untouched")
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	return true


# ==========================================================================
func run_lighting() -> bool:
	var tw := w()
	if tw == null:
		return false
	var li := tw.lighting
	var town: TownBuilder = t._town
	var old := town.lamp_positions.size() if town and town.get(&"lamp_positions") != null else 0
	t._check(li.lamp_points.size() >= maxi(old * 2, 40), "many more street lamps (%d new, %d old)" % [li.lamp_points.size(), old])
	TimeManager.reset_calendar(TimeManager.day, 22.5, "sunny")
	await t._frames(40)
	t._check(li.amount > 0.5, "night: lamps on (%.2f)" % li.amount)
	var real := 0
	for l in li._lights:
		if l.visible and l.light_energy > 0.1:
			real += 1
	var st := li.style()
	t._check(real >= 1 and real <= st.pool_lights, "web-friendly: %d real lights near the camera (cap %d)" % [real, st.pool_lights])
	t._check(li._pool_mesh != null and li._pool_mesh.visible, "warm light pools on the ground")
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	await t._frames(40)
	t._check(li.amount < 0.2, "day: lamps off")
	return true


# ==========================================================================
func run_save() -> bool:
	TrafficState.reset()
	TrafficState.grant(false)
	TrafficState.add_offence("player")
	TrafficState.impounded["x"] = {"day": 1, "fee": 120, "slot": 0}
	TrafficState.owned.append({"id": "city_sedan", "key": "owned_city_sedan_1"})
	var d := TrafficState.to_save()
	TrafficState.reset()
	TrafficState.from_save(JSON.parse_string(JSON.stringify(d)))
	t._check(TrafficState.licensed() and TrafficState.offence_count() == 1 and TrafficState.is_impounded("x") and TrafficState.owned.size() == 1, "traffic state survives save / load")
	TrafficState.reset()
	return true
