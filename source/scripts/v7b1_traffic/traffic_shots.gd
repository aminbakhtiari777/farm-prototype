extends RefCounted
## v7b.1 traffic screenshots, run by DevShots (names "traffic-*"):
##   godot --path . -- --shots=/workspace/farm-v7b1 --only=traffic-intersection,...

const NAMES: PackedStringArray = ["traffic-wide-street", "traffic-intersection", "traffic-officer-flash",
	"traffic-license-quiz", "traffic-dealership", "traffic-new-city-road", "traffic-bus-stop",
	"traffic-classy-terrace", "traffic-disco-night", "traffic-night-street"]

var s  # DevShots (untyped: helpers are called dynamically)


func _init(shots: Node) -> void:
	s = shots


func w() -> V7b1TrafficWorld:
	return s.get_tree().current_scene.find_child("V7b1TrafficWorld", true, false) as V7b1TrafficWorld


func run(shot: String) -> void:
	Settings.set_value("dialogue_language", "fa")
	var tw := w()
	if tw == null:
		return
	tw.set_auto(true)
	tw.lounge.force_disco = -1
	await call("_" + shot.replace("-", "_"))
	s._player.visible = true
	GameEvents.close_all_modals()


## Camera looking from `eye` (xz offset from the focus) at world point `focus`.
func _look(focus: Vector3, from_dir: Vector2, pitch: float, dist: float) -> void:
	s._place(Vector2(focus.x, focus.z) + from_dir.normalized() * 2.0, 0.0)
	s._player.visible = false
	s._view(from_dir, pitch, dist, focus - s._player.global_position)


func _traffic_on(hour: float) -> void:
	s._time(5, hour)
	var tw := w()
	tw.npc_traffic.set_active(true)
	tw.transit.set_service(true)


func _traffic_wide_street() -> void:
	_traffic_on(10.3)
	await s._frames(240)
	var f := TrafficKit.ground(Vector2(-20, -50))
	_look(f + Vector3(0, 0.5, 0), Vector2(0.55, 1.0), -24.0, 22.0)
	await s._frames(40)
	await s._capture("traffic-wide-street")


func _traffic_intersection() -> void:
	_traffic_on(10.6)
	var tw := w()
	await s._frames(300)
	var f := TrafficKit.ground(Vector2(0, -90))
	_look(f, Vector2(0.8, 1.0), -34.0, 30.0)
	await s._frames(40)
	await s._capture("traffic-intersection")


func _traffic_officer_flash() -> void:
	s._time(5, 18.6)
	var tw := w()
	tw.npc_traffic.set_active(false)
	var car := _town_car()
	var f := TrafficKit.ground(Vector2(0, -90))
	if car:
		car.speed = 0.0
		car.yaw = -PI * 0.5
		car.rotation = Vector3(0, car.yaw, 0)
		var p := Vector2(-2.0, -88.3)
		car.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.1, p.y)
	await s._frames(20)
	var cam: Dictionary = tw.signals.nearest_camera(f, 40.0)
	if not cam.is_empty():
		tw.signals.flash(cam)
	var lines: Array = TrafficKit.rules().officer_lines.get("caught", [])
	if not lines.is_empty():
		tw.signals.officer_say(lines[0])
	var op: Vector3 = tw.signals.officer_pos if tw.signals.officer_pos != Vector3.INF else f
	_look(op.lerp(f, 0.45) + Vector3(0, 1.0, 0), Vector2(-0.4, 1.0), -16.0, 13.0)
	await s._frames(3)
	await s._capture("traffic-officer-flash")


func _traffic_license_quiz() -> void:
	s._time(5, 11.0)
	var tw := w()
	var desk := tw.license_office.desk_world()
	s._place(Vector2(desk.x, desk.z + 1.4), 180.0)
	s._player.global_position.y = desk.y + 0.05
	await s._frames(20)
	TrafficState.reset()
	Economy.add_money(100)
	tw.license_panel.open(true)
	tw.license_panel.start_quiz()
	tw.license_panel.answer(tw.license_panel.correct_answer())
	await s._frames(10)
	await s._capture("traffic-license-quiz")
	tw.license_panel.close()
	TrafficState.reset()


func _traffic_dealership() -> void:
	s._time(5, 10.0)
	var tw := w()
	var ds := tw.dealership.style()
	var c := TrafficKit.ground(ds.pos)
	_look(c + Vector3(0, 0.8, 0), Vector2(-1.0, 0.55), -22.0, 17.0)
	await s._frames(40)
	await s._capture("traffic-dealership")


func _traffic_new_city_road() -> void:
	s._time(5, 16.5)
	var f := TrafficKit.ground(Vector2(77.0, -51.5))
	_look(f + Vector3(0, 1.4, 0), Vector2(-1.0, 0.35), -12.0, 15.0)
	await s._frames(40)
	await s._capture("traffic-new-city-road")


func _traffic_bus_stop() -> void:
	_traffic_on(9.5)
	var tw := w()
	var tr := tw.transit
	var k := 0
	var lane: Vector3 = tr.stops[k]["lane"]
	var side: Vector2 = tr.stops[k]["side"]
	tr.bus.place(lane, tr.bus.yaw)
	tr.bus.path_i = int(tr.bus.stop_idx[k])
	if tr.bus.path_i + 1 < tr.bus.path.size():
		var nx := tr.bus.path[tr.bus.path_i + 1]
		tr.bus.place(lane, atan2(nx.x - lane.x, nx.z - lane.z))
	# A couple of residents waiting at the shelter.
	var n := 0
	for b in V7aKit.bots(s.get_tree()):
		if n >= 2:
			break
		if not b.hidden_inside and b.controller is ScheduleController and int(b.resident.get("age", 30)) >= 14:
			b.global_position = TrafficKit.ground(side) + Vector3(0.9 * n - 0.5, 0.05, 0.3)
			n += 1
	tr.arrive(k)
	tr.bus.dwell = 60.0
	await s._frames(30)
	var mid := TrafficKit.ground(side).lerp(lane, 0.5)
	var away := Vector2(side.x - lane.x, side.y - lane.z).normalized()
	_look(mid + Vector3(0, 1.2, 0), away.rotated(0.9), -14.0, 14.0)
	await s._frames(10)
	await s._capture("traffic-bus-stop")
	tr.bus.dwell = 0.0


func _traffic_classy_terrace() -> void:
	var cafe: TerraceCafe = s._cafe_evening(19.2)
	await s._frames(40)
	s._cafe_view(13.0, -20.0, -0.45)
	await s._frames(30)
	s._hide_card()
	await s._capture("traffic-classy-terrace")


func _traffic_disco_night() -> void:
	s._time(5, 22.0)
	var tw := w()
	var lg := tw.lounge
	lg.force_disco = 1
	lg.set_staff(true)
	var v7b := s._v7b() as V7bWorld
	if v7b:
		v7b.staffing.tick()
	lg.fill_crowd(10)
	var c := lg.at(Vector3(0, 0, 0))
	var door := lg.at(Vector3(0, 0, lg.style().hall_size.z * 0.5 - 1.5))
	s._place(Vector2(door.x, door.z), 0.0)
	await s._frames(90)
	s._player.visible = false
	var back := Vector2(door.x - c.x, door.z - c.z).normalized()
	s._view(back, -24.0, 6.5, c - s._player.global_position + Vector3(0, 0.6, 0))
	await s._frames(4)
	await s._capture("traffic-disco-night")
	lg.force_disco = -1
	lg.send_home()


func _traffic_night_street() -> void:
	_traffic_on(22.4)
	await s._frames(120)
	var f := TrafficKit.ground(Vector2(-30, -50))
	_look(f + Vector3(0, 0.8, 0), Vector2(0.35, 1.0), -18.0, 24.0)
	await s._frames(60)
	await s._capture("traffic-night-street")


func _town_car() -> DrivableCar:
	for n in s.get_tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		if c and not (c is DrivableBus) and not c.key.begins_with("owned_"):
			return c
	return null
