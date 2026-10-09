class_name Passengers
extends Node3D
## v7b "passengers" module: now and then a townsperson waits at a stop and
## waves for a ride (yellow beam). Stop your car next to them and they get in;
## drive to their destination (green beam) and stop: they pay the fare,
## generous people tip, everyone remembers a safe ride. Speeding with a
## passenger gets a complaint (and no tip) - safety first.

var staffing: Staffing
var auto: bool = true
var state: String = ""          ## "" | waiting | riding | leaving
var bot: TownspersonBot
var from_stop: Dictionary = {}
var to_stop: Dictionary = {}
var wait_t: float = 0.0
var warned: bool = false
var last_fare: int = 0
var last_tip: int = 0
var beam: Node3D
var _beam_mat: StandardMaterial3D
var _beam_label: Label3D
var _hours_acc: float = 0.0
var _wave_t: float = 0.0
var _leave_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func style() -> PassengerStyle:
	return Modules.style("passengers") as PassengerStyle


func _ready() -> void:
	_rng.randomize()
	_build_beam()
	TimeManager.hour_changed.connect(_on_hour)
	Modules.on_swap("passengers", self, func(_m: Resource) -> void: cancel())


func _build_beam() -> void:
	beam = Node3D.new()
	beam.name = "RideBeam"
	beam.visible = false
	add_child(beam)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.albedo_color = Color(1.0, 0.85, 0.2, 0.35)
	var c := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.25
	cm.bottom_radius = 0.45
	cm.height = 26.0
	cm.radial_segments = 12
	c.mesh = cm
	c.material_override = _beam_mat
	c.position.y = 13.0
	c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(c)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.6
	tm.outer_radius = 3.0
	ring.mesh = tm
	ring.material_override = _beam_mat
	ring.position.y = 0.08
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	beam.add_child(ring)
	_beam_label = Label3D.new()
	Lang.setup_label3d(_beam_label)
	_beam_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_beam_label.no_depth_test = true
	_beam_label.font_size = 54
	_beam_label.outline_size = 12
	_beam_label.pixel_size = 0.01
	_beam_label.position.y = 4.2
	beam.add_child(_beam_label)


func stop(id: String) -> Dictionary:
	var st := style()
	if st:
		for s: Dictionary in st.stops:
			if str(s.get("id", "")) == id:
				return s
	return {}


func stop_pos(s: Dictionary) -> Vector3:
	var p: Vector2 = s.get("pos", Vector2.ZERO)
	return V7aKit.ground(p.x, p.y)


func _show_beam(s: Dictionary, dest: bool) -> void:
	beam.visible = true
	beam.global_position = stop_pos(s)
	_beam_mat.albedo_color = Color(0.3, 1.0, 0.45, 0.35) if dest else Color(1.0, 0.85, 0.2, 0.35)
	_beam_label.modulate = Color(0.6, 1.0, 0.65) if dest else Color(1.0, 0.9, 0.4)
	_beam_label.text = (Lang.tt("مقصد: ", "Drop-off: ") if dest else Lang.tt("مسافر: ", "Passenger: ")) + str(s.get("fa" if Lang.is_fa() else "en", ""))


func player_car() -> DrivableCar:
	var p := V7bKit.player(get_tree())
	return p.vehicle as DrivableCar if p else null


func _on_hour(_h: int, _d: int) -> void:
	var st := style()
	if not auto or st == null or state != "":
		return
	_hours_acc += 1.0
	if _hours_acc >= st.every_hours and Staffing.open_at(st.hours, TimeManager.hours_float()):
		_hours_acc = 0.0
		request_random()


func request_random() -> bool:
	var st := style()
	if st == null or st.stops.size() < 2:
		return false
	var cands: Array[TownspersonBot] = []
	for b in V7aKit.bots(get_tree()):
		if b.controller is ScheduleController and int(b.resident.get("age", 0)) >= 16 and not Needs.npc_is_ill(b):
			if staffing == null or staffing.unavailable(b, "passenger") == "":
				cands.append(b)
	if cands.is_empty():
		return false
	var a: Dictionary = st.stops[_rng.randi() % st.stops.size()]
	var far: Array = []
	for s: Dictionary in st.stops:
		if s != a and stop_pos(s).distance_to(stop_pos(a)) > 35.0:
			far.append(s)
	if far.is_empty():
		return false
	var b: Dictionary = far[_rng.randi() % far.size()]
	return request(cands[_rng.randi() % cands.size()], str(a["id"]), str(b["id"]))


func request(who: TownspersonBot, from_id: String, to_id: String) -> bool:
	if state != "":
		cancel()
	var st := style()
	from_stop = stop(from_id)
	to_stop = stop(to_id)
	if st == null or who == null or from_stop.is_empty() or to_stop.is_empty():
		return false
	bot = who
	var sc := V7aKit.ScriptController.new()
	sc.tag = "passenger"
	sc.original = who.controller
	var at := stop_pos(from_stop)
	who.global_position = at + Vector3(1.2, 0.0, 0.0)
	sc.face_to = at + Vector3(0, 0, 3)
	who.set_controller(sc)
	state = "waiting"
	wait_t = 0.0
	warned = false
	_wave_t = 0.0
	_show_beam(from_stop, false)
	GameEvents.notification_requested.emit(Lang.tt("%s در %s منتظر ماشین است (پرتو زرد)." % [Dialogue.name_of(who.resident), str(from_stop["fa"])],
		"%s is waiting for a ride at %s (yellow beam)." % [Dialogue.name_of(who.resident), str(from_stop["en"])]))
	return true


func _valid() -> bool:
	return bot != null and is_instance_valid(bot) and bot.controller is V7aKit.ScriptController and (bot.controller as V7aKit.ScriptController).tag == "passenger"


func _say(kind: String, vals: Dictionary = {}) -> String:
	var st := style()
	if st == null or bot == null:
		return ""
	var e: Array = st.lines.get(kind, [])
	if e.is_empty():
		return ""
	var pair := V7bKit.both(e[_rng.randi() % e.size()], vals)
	var txt := str(pair[1]) if Lang.is_fa() else str(pair[0])
	TownLife.log_line(Dialogue.name_of(bot.resident), str(pair[0]), str(pair[1]))
	if state == "riding":
		GameEvents.notification_requested.emit("%s: %s" % [Dialogue.name_of(bot.resident), txt])
	else:
		V7bKit.say_small(bot, txt, 4.0)
	return txt


func board() -> bool:
	if state != "waiting" or not _valid():
		return false
	(bot.controller as V7aKit.ScriptController).hidden = true
	state = "riding"
	_show_beam(to_stop, true)
	_say("board", {"dest": [str(to_stop["en"]), str(to_stop["fa"])]})
	return true


func fare() -> int:
	var st := style()
	if st == null:
		return 0
	var d := stop_pos(from_stop).distance_to(stop_pos(to_stop))
	return st.fare_base + int(round(st.fare_per_100m * d / 100.0))


func arrive() -> bool:
	if state != "riding" or not _valid():
		return false
	var f := fare()
	var gen := Personalities.value(bot.resident, "generosity", 0.5)
	var tip := 0
	if gen > 0.55 and not warned:
		tip = maxi(1, int(round(f * 0.3 * gen)))
	Economy.add_money(f + tip)
	last_fare = f
	last_tip = tip
	TownLife.rides["delivered"] = int(TownLife.rides.get("delivered", 0)) + 1
	TownLife.rides["earned"] = int(TownLife.rides.get("earned", 0)) + f + tip
	TownLife.rides["tips"] = int(TownLife.rides.get("tips", 0)) + tip
	TownLife.count_event("ride")
	Friendship.add_points(Friendship.key_of(bot), 4 if not warned else 1)
	WorldMemory.npc_remember(Friendship.key_of(bot), "ride", "The farmer drove me to %s." % str(to_stop["en"]), "کشاورز مرا تا %s رساند." % str(to_stop["fa"]))
	var sc := bot.controller as V7aKit.ScriptController
	sc.hidden = false
	var car := player_car()
	var base := car.global_position if car else stop_pos(to_stop)
	var side := car.global_transform.basis.x.normalized() if car else Vector3.RIGHT
	bot.global_position = V7aKit.ground(base.x + side.x * 2.4, base.z + side.z * 2.4)
	state = "leaving"
	_leave_t = 4.0
	beam.visible = false
	_say("arrive")
	if tip > 0:
		V7bKit.say_small(bot, V7bKit.line(style().lines.get("tip", [])), 3.0)
	GameEvents.notification_requested.emit(Lang.tt("کرایه: %s سکه%s" % [Lang.digits(str(f)), (" + انعام %s" % Lang.digits(str(tip))) if tip > 0 else ""],
		"Fare: %d G%s" % [f, (" + %d tip" % tip) if tip > 0 else ""]))
	Sfx.play_at(&"coin", bot.global_position)
	return true


func give_up() -> void:
	if _valid():
		_say("gave_up")
	cancel()


func cancel() -> void:
	if _valid():
		var sc := bot.controller as V7aKit.ScriptController
		sc.hidden = false
		bot.set_controller(V7bKit.original_of(sc))
	state = ""
	bot = null
	beam.visible = false


func _process(delta: float) -> void:
	if state == "":
		return
	var st := style()
	if st == null or not _valid():
		state = ""
		bot = null
		beam.visible = false
		return
	var car := player_car()
	match state:
		"waiting":
			wait_t += delta
			_wave_t -= delta
			if _wave_t <= 0.0:
				_wave_t = 7.0
				bot.start_wave(1.6)
				if _rng.randf() < 0.6:
					_say("hail")
			if car and absf(car.speed) < 1.5 and V7aKit.flat(car.global_position).distance_to(V7aKit.flat(bot.global_position)) < st.pickup_radius:
				board()
			elif wait_t > st.max_wait:
				give_up()
		"riding":
			if car == null:
				return
			bot.global_position = car.global_position
			if absf(car.speed) > 13.0 and not warned:
				warned = true
				_say("slow_down")
			if absf(car.speed) < 1.5 and V7aKit.flat(car.global_position).distance_to(V7aKit.flat(stop_pos(to_stop))) < st.pickup_radius * 1.3:
				arrive()
		"leaving":
			_leave_t -= delta
			if _leave_t <= 0.0:
				cancel()
