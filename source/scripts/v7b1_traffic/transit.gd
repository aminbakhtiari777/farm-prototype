class_name Transit
extends Node3D
## v7b.1 transit (vehicle module "transit"): bus stops with a shelter, Persian
## sign and timetable; an NPC city bus on line 1 that stops at every stop for
## `dwell_s`, obeys lights / STOP signs / speed limits (RoadCar.traffic_gate)
## and lets residents get on and off; the farmer can ride it (E at the door,
## pay the fare, E again to get off at the next stop) or drive the second bus
## parked at the terminal (DrivableBus) - stop at a bus stop and waiting
## residents board and pay you the fare.

var bus: NpcBus
var drive_bus: DrivableBus
var stops: Array = []              ## [{id, pos, side, en, fa, node, board, lane: Vector3, idx}]
var riders: Array = []             ## [{bot, sc, dest (stop index), vehicle}]
var player_riding: bool = false
var ride_alight_next: bool = false
var ride_from: int = -1
var player_bus_stop: int = -1
var _player_dwell_t: float = 0.0
var _t: float = 0.0


class NpcBus extends RoadCar:
	var transit: Transit
	var spec: Dictionary = {}
	var stop_idx: Array = []        ## path index of each stop (same order as transit.stops)
	var next_stop: int = 0
	var dwell: float = 0.0
	var at_stop: int = -1
	var door_spot: ActionSpot
	var loops: int = 0

	func _ready() -> void:
		add_to_group(&"road_cars")
		add_to_group(&"buses")
		set_meta(&"voice", "bus")
		arrived.connect(func() -> void:
			loops += 1
			path_i = 0
			moving = true)

	func build_bus(line_fa: String, line_en: String) -> void:
		var m := BusModel.build(spec, line_fa, line_en)
		model_root = m[0]
		size = m[1]
		add_child(model_root)
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(size.x, size.y - 0.4, size.z)
		cs.shape = bs
		cs.position = Vector3(0, 0.4 + bs.size.y * 0.5, 0)
		add_child(cs)

	func door_world() -> Vector3:
		return global_transform * Vector3(-size.x * 0.5 - 0.9, 0, size.z * 0.5 - 1.1)


func style() -> TransitStyle:
	return Modules.style("transit") as TransitStyle


func _ready() -> void:
	rebuild.call_deferred()
	Modules.on_swap("transit", self, func(_m: Resource) -> void: rebuild())


func _line_names() -> Array:
	var st := style()
	return [str(st.line.get("fa", "خط ۱")), str(st.line.get("en", "Line 1"))] if st else ["خط ۱", "Line 1"]


func rebuild() -> void:
	if player_riding:
		alight_player()
	for r: Dictionary in riders.duplicate():
		_drop_rider(r, -1)
	for c in get_children():
		c.queue_free()
	stops.clear()
	riders.clear()
	bus = null
	drive_bus = null
	var st := style()
	if st == null:
		return
	var names := _line_names()
	var path := NpcTraffic.loop_path(st.line.get("route", []))
	var k := 0
	for s: Dictionary in st.line.get("stops", []):
		var stop := s.duplicate()
		stop["node"] = _build_shelter(s, k)
		# Path index nearest to the stop (lane side).
		var best := -1
		var bd := INF
		var sp: Vector2 = s["pos"]
		var side: Vector2 = s["side"]
		for i in path.size():
			var q := Vector2(path[i].x, path[i].z)
			var d := q.distance_to(sp) + q.distance_to(side) * 0.5
			if d < bd:
				bd = d
				best = i
		# Make sure there is a waypoint right at the stop.
		var lane_pt := Vector3(sp.x, 0, sp.y) + (Vector3(side.x, 0, side.y) - Vector3(sp.x, 0, sp.y)).normalized() * VehicleKit.LANE
		stop["lane"] = lane_pt
		stop["idx"] = best
		stops.append(stop)
		k += 1
	# Insert the stop points into the path (sorted by index, from the back).
	var order := stops.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["idx"]) > int(b["idx"]))
	for s: Dictionary in order:
		var i := int(s["idx"])
		var lp: Vector3 = s["lane"]
		# Put it between i-1 / i / i+1 where it projects best.
		var ins := i if i > 0 and _between(path[i - 1], path[i], lp) else i + 1
		path.insert(clampi(ins, 0, path.size()), lp)
	for s: Dictionary in stops:
		var lp2: Vector3 = s["lane"]
		for i in path.size():
			if path[i].is_equal_approx(lp2):
				s["idx"] = i
				break
	var vspec: Dictionary = st.vehicles.get(str(st.line.get("vehicle", "city_bus")), {})
	bus = NpcBus.new()
	bus.name = "Bus_Line1"
	bus.transit = self
	bus.spec = vspec
	bus.model_name = "bus"
	bus.speed = float(st.line.get("speed", 8.0))
	add_child(bus)
	bus.build_bus(names[0], names[1])
	for s: Dictionary in stops:
		bus.stop_idx.append(int(s["idx"]))
	bus.path = path
	if path.size() > 1:
		bus.place(path[0], atan2(path[1].x - path[0].x, path[1].z - path[0].z))
	bus.path_i = 1
	bus.moving = true
	bus.door_spot = ActionSpot.make(bus, Vector3(-bus.size.x * 0.5 - 0.9, 0, bus.size.z * 0.5 - 1.1), 1.4, _door_text, func(_w: Node3D) -> void: board_player(),
		func() -> bool: return not player_riding)
	bus.door_spot.name = "BusDoor"
	# The drivable bus at the terminal.
	var term: Dictionary = st.terminal
	if not term.is_empty():
		var tspec: Dictionary = st.vehicles.get(str(term.get("vehicle", "city_bus")), vspec)
		drive_bus = DrivableBus.new()
		drive_bus.name = "TerminalBus"
		drive_bus.key = "bus_terminal"
		drive_bus.spec = tspec
		drive_bus.line_names = names
		var tp: Vector2 = term.get("pos", Vector2(-62, -46.1))
		drive_bus.yaw = deg_to_rad(float(term.get("yaw", 90.0)))
		drive_bus.position = TrafficKit.ground(tp)
		drive_bus.set_meta(&"home_pos", drive_bus.position)
		drive_bus.set_meta(&"home_yaw", drive_bus.yaw)
		var vs := Modules.style("vehicles") as VehicleStyle
		drive_bus.set_meta(&"top_mult", float(tspec.get("top_kmh", 45)) / 3.6 / (vs.max_speed if vs else 11.0))
		add_child(drive_bus)
		var m := WorldMemory.cars.get(drive_bus.key, {}) as Dictionary
		if not m.is_empty():
			drive_bus.global_position = WorldMemory.vec(m.get("p"))
			drive_bus.yaw = float(m.get("yaw", drive_bus.yaw))
			drive_bus.rotation = Vector3(0, drive_bus.yaw, 0)
		var v7b := get_tree().current_scene.find_child("V7bWorld", true, false) as V7bWorld if get_tree().current_scene else null
		if v7b and v7b.driving:
			v7b.driving.attach_all.call_deferred()
		_terminal_sign(tp, float(term.get("yaw", 90.0)), term)


static func _between(a: Vector3, b: Vector3, p: Vector3) -> bool:
	var ab := b - a
	var t := (p - a).dot(ab) / maxf(ab.length_squared(), 0.001)
	return t > 0.0 and t < 1.0


func _door_text() -> String:
	var st := style()
	return Lang.tt("سوار اتوبوس شو - کرایه %s سکه" % Lang.digits(str(st.fare if st else 5)), "ride the bus - fare %d G" % (st.fare if st else 5))


# ------------------------------------------------------------------ shelters
func _build_shelter(s: Dictionary, k: int) -> Node3D:
	var st := style()
	var side: Vector2 = s["side"]
	var pos: Vector2 = s["pos"]
	var holder := Node3D.new()
	holder.name = "BusStop_%s" % str(s.get("id", k))
	holder.position = TrafficKit.ground(side)
	var to_road := (pos - side).normalized()
	holder.rotation.y = atan2(to_road.x, to_road.y)   # +z faces the road
	add_child(holder)
	var frame := TrafficKit.mat(Color(0.2, 0.32, 0.5), 0.4)
	var glass := TrafficKit.mat(Color(0.7, 0.85, 0.95, 0.3), 0.05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Posts, roof, back glass, side glass, bench.
	for sx: float in [-1.4, 1.4]:
		V7aKit.box(holder, Vector3(0.08, 2.4, 0.08), Vector3(sx, 1.2, -0.5), frame)
		V7aKit.box(holder, Vector3(0.08, 2.4, 0.08), Vector3(sx, 1.2, 0.4), frame)
		V7aKit.box(holder, Vector3(0.03, 1.6, 0.85), Vector3(sx, 1.25, -0.05), glass, false)
	V7aKit.box(holder, Vector3(3.2, 0.1, 1.3), Vector3(0, 2.45, -0.05), frame)
	V7aKit.box(holder, Vector3(2.8, 1.7, 0.03), Vector3(0, 1.3, -0.52), glass, false)
	V7aKit.box(holder, Vector3(2.2, 0.08, 0.42), Vector3(0, 0.48, -0.3), TrafficKit.mat(Color(0.45, 0.3, 0.18), 0.7))
	for sx2: float in [-0.9, 0.9]:
		V7aKit.box(holder, Vector3(0.06, 0.46, 0.36), Vector3(sx2, 0.23, -0.3), frame)
	# Stop name on the roof edge (faces the road and the pavement).
	var names := _line_names()
	var l := TrafficKit.label(holder, "ایستگاه %s - %s" % [str(s.get("fa", "")), names[0]], "Bus stop %s - %s" % [str(s.get("en", "")), names[1]],
		Vector3(0, 2.62, 0.62), 0.0, 0.0028, 48, Color(1, 1, 1), 8)
	l.name = "StopName"
	# Bus-stop pole sign at the kerb end.
	V7aKit.cyl(holder, 0.04, 2.8, Vector3(1.9, 1.4, 0.6), TrafficKit.mat(Color(0.62, 0.64, 0.66), 0.4))
	var disc := V7aKit.cyl(holder, 0.3, 0.03, Vector3(1.9, 2.6, 0.62), TrafficKit.mat(Color(0.1, 0.4, 0.75), 0.5))
	disc.rotation.x = PI * 0.5
	var bl := TrafficKit.label(holder, "اتوبوس", "BUS", Vector3(1.9, 2.6, 0.65), 0.0, 0.0028, 48, Color.WHITE)
	bl.name = "BusDisc"
	# Timetable board inside the shelter (back wall), updated live.
	V7aKit.box(holder, Vector3(1.1, 0.8, 0.03), Vector3(-0.75, 1.45, -0.49), TrafficKit.mat(Color(0.97, 0.97, 0.94), 0.6))
	var board := Label3D.new()
	Lang.setup_label3d(board, 32)
	board.pixel_size = 0.0018
	board.modulate = Color(0.08, 0.08, 0.1)
	board.width = 560.0
	board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.position = Vector3(-0.75, 1.45, -0.47)
	board.name = "Timetable"
	holder.add_child(board)
	holder.set_meta(&"board", board)
	return holder


func timetable_text(k: int) -> String:
	var st := style()
	if st == null:
		return ""
	var names := _line_names()
	var s: Dictionary = stops[k]
	var lines: PackedStringArray = []
	var h0 := "%02d:00" % int(st.hours.x)
	var h1 := "%02d:00" % int(st.hours.y)
	if Lang.is_fa():
		lines.append("%s - ایستگاه %s" % [names[0], str(s.get("fa", ""))])
		lines.append("هر %s دقیقه، %s تا %s" % [Lang.digits(str(st.interval_min)), Lang.digits(h0), Lang.digits(h1)])
		lines.append("کرایه: %s سکه" % Lang.digits(str(st.fare)))
		lines.append("اتوبوس بعدی: %s" % _eta_text(k))
		var route_fa: PackedStringArray = []
		for o: Dictionary in stops:
			route_fa.append(str(o.get("fa", "")))
		lines.append("مسیر: " + " - ".join(route_fa))
	else:
		lines.append("%s - stop %s" % [names[1], str(s.get("en", ""))])
		lines.append("Every %d min, %s-%s" % [st.interval_min, h0, h1])
		lines.append("Fare: %d G" % st.fare)
		lines.append("Next bus: %s" % _eta_text(k))
		var route_en: PackedStringArray = []
		for o: Dictionary in stops:
			route_en.append(str(o.get("en", "")))
		lines.append("Route: " + " - ".join(route_en))
	return "\n".join(lines)


## How many stops away the bus is from stop k (live).
func stops_away(k: int) -> int:
	if bus == null or stops.is_empty():
		return -1
	var n := stops.size()
	if bus.at_stop == k:
		return 0
	return posmod(k - bus.next_stop, n) + (0 if bus.at_stop < 0 else 0)


func _eta_text(k: int) -> String:
	if not in_service():
		return Lang.tt("فردا صبح", "tomorrow morning")
	var a := stops_away(k)
	if a == 0:
		return Lang.tt("در ایستگاه است", "at the stop now")
	if a == 1 and bus.at_stop < 0:
		return Lang.tt("در راه است", "on its way")
	return Lang.tt("%s ایستگاه دیگر" % Lang.digits(str(a)), "%d stop(s) away" % a)


func _terminal_sign(p: Vector2, yaw_deg: float, term: Dictionary) -> void:
	var yaw := deg_to_rad(yaw_deg)
	var right := Vector2(-cos(yaw), sin(yaw))   # kerb side of a bus facing yaw
	var sp := p + right * 2.4 + Vector2(sin(yaw), cos(yaw)) * 3.0
	var l := V7bKit.sign(self, TrafficKit.ground(sp), yaw + PI * 0.5 + PI, str(term.get("fa", "پایانه")), str(term.get("en", "Terminal")), Color(0.1, 0.35, 0.6), 2.4)
	l.name = "TerminalSign"


func in_service() -> bool:
	var st := style()
	if st == null:
		return false
	var h := TimeManager.hours_float()
	return h >= st.hours.x and h < st.hours.y


## Tests: the NPC bus parked away (hidden, no collision) / back in service.
var service: bool = true


func set_service(on: bool) -> void:
	service = on
	if bus and is_instance_valid(bus):
		bus.visible = on
		bus.collision_layer = 1 if on else 0
		bus.moving = on and bus.at_stop < 0
	if not on:
		if player_riding:
			alight_player()
		for r: Dictionary in riders.duplicate():
			_drop_rider(r, -1)


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	var st := style()
	if st == null or bus == null or not is_instance_valid(bus):
		return
	_t -= delta
	# Service hours: off-hours the NPC bus rests (hidden) after its loop.
	var on := in_service() and service
	if not on and bus.at_stop < 0 and not player_riding:
		bus.visible = false
		bus.collision_layer = 0
		bus.moving = false
	elif on and not bus.visible:
		bus.visible = true
		bus.collision_layer = 1
		bus.moving = true
	_tick_bus(delta)
	_tick_player_ride()
	_tick_player_bus(delta)
	_tick_riders()
	if _t <= 0.0:
		_t = 1.0
		for k in stops.size():
			var node := stops[k]["node"] as Node3D
			var board := node.get_meta(&"board") as Label3D
			if board:
				board.text = timetable_text(k)


func _tick_bus(delta: float) -> void:
	var st := style()
	if bus.at_stop >= 0:
		bus.dwell -= delta
		bus.cur_speed = 0.0
		if bus.dwell <= 0.0:
			bus.at_stop = -1
			bus.next_stop = (bus.next_stop + 1) % stops.size()
			bus.moving = bus.visible
		return
	if stops.is_empty() or not bus.moving:
		return
	var target_i := int(bus.stop_idx[bus.next_stop])
	var last := bus.path.size() - 1
	var tp := bus.path[target_i]
	var near := Vector2(bus.global_position.x, bus.global_position.z).distance_to(Vector2(tp.x, tp.z)) < 1.6
	if bus.path_i == target_i + 1 or (bus.path_i == target_i and near) or (target_i == last and bus.path_i == 0 and near):
		arrive(bus.next_stop)
	elif bus.path_i > target_i + 1:
		# Missed it (spawned past it / loop reset): aim for the next stop ahead.
		bus.next_stop = _next_stop_ahead()


func _next_stop_ahead() -> int:
	var best := 0
	var bd := 1 << 30
	for k in stops.size():
		var d := posmod(int(bus.stop_idx[k]) - bus.path_i, bus.path.size())
		if d < bd:
			bd = d
			best = k
	return best


## The NPC bus stops at stop k: riders get off, waiting residents get on.
func arrive(k: int) -> void:
	var st := style()
	bus.at_stop = k
	bus.next_stop = k
	bus.dwell = float(st.line.get("dwell_s", 7.0)) if st else 7.0
	bus.moving = false
	bus.cur_speed = 0.0
	if player_riding and (ride_alight_next or k == posmod(ride_from + 1, stops.size()) and ride_alight_next):
		alight_player()
	_unload(bus, k)
	_load(bus, k)


func _unload(vehicle: Node3D, k: int) -> void:
	for r: Dictionary in riders.duplicate():
		if r["vehicle"] == vehicle and int(r["dest"]) == k:
			_drop_rider(r, k)


func _drop_rider(r: Dictionary, k: int) -> void:
	riders.erase(r)
	var b := r["bot"] as TownspersonBot
	if not is_instance_valid(b):
		return
	var sc := r["sc"] as V7aKit.ScriptController
	if k >= 0 and k < stops.size():
		var side: Vector2 = stops[k]["side"]
		b.global_position = TrafficKit.ground(side) + Vector3(randf_range(-0.8, 0.8), 0.05, 0.6)
	if b.controller == sc:
		b.set_controller(V7bKit.original_of(sc))


func _load(vehicle: Node3D, k: int, pay_player: bool = false) -> int:
	var st := style()
	if st == null or not st.residents_ride:
		return 0
	var side: Vector2 = stops[k]["side"]
	var here := TrafficKit.ground(side)
	var n := 0
	for b in V7aKit.bots(get_tree()):
		if n >= 2 or riders.size() >= st.max_riders:
			break
		if b.hidden_inside or b.resident.is_empty() or int(b.resident.get("age", 0)) < 12:
			continue
		if not (b.controller is ScheduleController) or b.global_position.distance_to(here) > 14.0:
			continue
		var sc := V7aKit.ScriptController.new()
		sc.original = b.controller
		sc.tag = "bus"
		sc.speed = 1.8
		sc.target = (vehicle as Node3D).call(&"door_world") if vehicle.has_method(&"door_world") else vehicle.global_position
		b.set_controller(sc)
		var dest := posmod(k + 1 + (b.get_instance_id() % maxi(stops.size() - 1, 1)), stops.size())
		riders.append({"bot": b, "sc": sc, "dest": dest, "vehicle": vehicle, "t": 0.0, "boarded": false})
		n += 1
		if pay_player:
			Economy.add_money(st.fare)
			TrafficState.stat("bus_fares", st.fare)
		V7bKit.say_small(b, Lang.tt("سلام آقای راننده!", "Hello, driver!") if pay_player else Lang.tt("اتوبوس آمد!", "Here's the bus!"))
	return n


func _tick_riders() -> void:
	for r: Dictionary in riders:
		var b := r["bot"] as TownspersonBot
		var sc := r["sc"] as V7aKit.ScriptController
		var v := r["vehicle"] as Node3D
		if not is_instance_valid(b) or not is_instance_valid(v):
			continue
		if not bool(r["boarded"]):
			r["t"] = float(r["t"]) + get_process_delta_time()
			var door: Vector3 = v.call(&"door_world") if v.has_method(&"door_world") else v.global_position
			sc.target = door
			if b.global_position.distance_to(door) < 1.4 or float(r["t"]) > 7.0:
				r["boarded"] = true
				sc.hidden = true
				sc.target = Vector3.INF
		else:
			b.global_position = v.global_position + Vector3(0, 0.3, 0)


## Residents riding (tests / HUD).
func riding_count(vehicle: Node3D = null) -> int:
	var n := 0
	for r: Dictionary in riders:
		if vehicle == null or r["vehicle"] == vehicle:
			n += 1
	return n


# ------------------------------------------------------------------ player ride
func board_player() -> bool:
	var st := style()
	var p := V7bKit.player(get_tree())
	if p == null or player_riding or bus == null or p.vehicle != null:
		return false
	if Economy.money < (st.fare if st else 5):
		GameEvents.notification_requested.emit(Lang.tt("کرایه را نداری.", "You can't pay the fare."))
		return false
	Economy.add_money(-(st.fare if st else 5))
	CityState.add_income("bus_fare", st.fare if st else 5, "Bus fare", "کرایه‌ی اتوبوس")
	TrafficState.stat("bus_rides")
	player_riding = true
	ride_alight_next = false
	ride_from = bus.at_stop if bus.at_stop >= 0 else bus.next_stop
	p.vehicle = bus
	p.set_meta(&"v6b_layers", [p.collision_layer, p.collision_mask])
	p.collision_layer = 0
	p.collision_mask = 0
	var vis := p.get_node_or_null(^"Visual") as Node3D
	if vis:
		vis.visible = false
	GameEvents.interaction_prompt_changed.emit(Lang.tt("در اتوبوس هستی · E پیاده شدن در ایستگاه بعد", "On the bus · E to get off at the next stop"))
	GameEvents.notification_requested.emit(Lang.tt("کرایه پرداخت شد. سفر خوش!", "Fare paid. Enjoy the ride!"))
	return true


func _tick_player_ride() -> void:
	if not player_riding:
		return
	var p := V7bKit.player(get_tree())
	if p == null or bus == null:
		player_riding = false
		return
	p.global_position = bus.global_position + Vector3(0, 0.6, 0)
	if not GameEvents.ui_open and Input.is_action_just_pressed(&"interact"):
		if bus.at_stop >= 0:
			alight_player()
		else:
			ride_alight_next = true
			GameEvents.notification_requested.emit(Lang.tt("ایستگاه بعد پیاده می‌شوی.", "You'll get off at the next stop."))


func alight_player() -> void:
	var p := V7bKit.player(get_tree())
	player_riding = false
	ride_alight_next = false
	if p == null:
		return
	p.vehicle = null
	var layers: Array = p.get_meta(&"v6b_layers", [2, 5])
	p.collision_layer = int(layers[0])
	p.collision_mask = int(layers[1])
	var vis := p.get_node_or_null(^"Visual") as Node3D
	if vis:
		vis.visible = true
	var spot: Vector3 = bus.door_world() if bus else p.global_position
	if bus and bus.at_stop >= 0:
		var side: Vector2 = stops[bus.at_stop]["side"]
		spot = TrafficKit.ground(side) + Vector3(0, 0, 0.0)
	p.global_position = Vector3(spot.x, Terrain.height_at(spot.x, spot.z) + 0.1, spot.z)
	p.velocity = Vector3.ZERO
	GameEvents.interaction_prompt_changed.emit("")


# ------------------------------------------------------------------ player drives a bus
func _tick_player_bus(delta: float) -> void:
	if drive_bus == null or not is_instance_valid(drive_bus) or drive_bus.driver == null:
		player_bus_stop = -1
		_player_dwell_t = 0.0
		return
	var p := Vector2(drive_bus.global_position.x, drive_bus.global_position.z)
	var near := -1
	for k in stops.size():
		var lp: Vector3 = stops[k]["lane"]
		if Vector2(lp.x, lp.z).distance_to(p) < 5.0:
			near = k
	if near >= 0 and absf(drive_bus.speed) < 0.3:
		_player_dwell_t += delta
		if _player_dwell_t > 1.5 and player_bus_stop != near:
			player_bus_stop = near
			_unload(drive_bus, near)
			var n := _load(drive_bus, near, true)
			GameEvents.notification_requested.emit(Lang.tt("ایستگاه %s: %s مسافر سوار شد." % [str(stops[near].get("fa", "")), Lang.digits(str(n))],
				"Stop %s: %d passenger(s) boarded." % [str(stops[near].get("en", "")), n]))
	else:
		_player_dwell_t = 0.0
		if near < 0:
			player_bus_stop = -1 if player_bus_stop >= 0 and absf(drive_bus.speed) > 3.0 else player_bus_stop
