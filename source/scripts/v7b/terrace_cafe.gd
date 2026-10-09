class_name TerraceCafe
extends Node3D
## v7b "cafe" module: an open-air terrace next to the Cafe with a bar, a DJ
## booth, tables and string lights. Open in the afternoon / evening:
##  - the bartender (Staffing post) serves the drinks menu (E at the bar);
##    strong drinks make you tipsy for a short while (Tipsy) and the bartender
##    stops serving them after the daily limit - responsible, not glorified,
##  - the DJ (Staffing post) plays positional music at night,
##  - guests (residents) sit at the tables; now and then two of them get into
##    a small fight: the bartender breaks it up (or the police if nobody is
##    behind the bar); both pay a fine to the city fund, get a bruise (tired)
##    and remember it.
## Posts are never empty: Staffing finds a stand-in if a worker is away.

var staffing: Staffing
var menu_panel: CafeMenuPanel
var tipsy: Tipsy
var root: Node3D
var music: AudioStreamPlayer3D
var dj_lights: Array[OmniLight3D] = []
var string_lights: Array[MeshInstance3D] = []
var seats: Array[Seat] = []
var bar_spot: ActionSpot
var guests: Array[TownspersonBot] = []
var fight: Dictionary = {}       ## {} or {"a", "b", "t", "police", "line_t", "turn"}
var auto: bool = true            ## random guests / fights (off in tests)
var served: int = 0
var refused: int = 0
var fights: int = 0
var breakups_bartender: int = 0
var breakups_police: int = 0
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _dj_t: float = 8.0
var _sign: Label3D


func style() -> CafeStyle:
	return Modules.style("cafe") as CafeStyle


func _ready() -> void:
	_rng.randomize()
	TimeManager.hour_changed.connect(_on_hour)
	rebuild()
	Modules.on_swap("cafe", self, func(_m: Resource) -> void: rebuild())


## Local -> world on the terrace.
func at(local: Vector3) -> Vector3:
	return root.global_transform * local if root else local


func ground_at(lx: float, lz: float) -> Vector3:
	var w := at(Vector3(lx, 0, lz))
	return Vector3(w.x, Terrain.height_at(w.x, w.z), w.z)


func rebuild() -> void:
	end_fight(false)
	send_guests_home()
	if staffing:
		staffing.remove_post("bartender")
		staffing.remove_post("dj")
	if root:
		root.queue_free()
		root = null
	seats.clear()
	dj_lights.clear()
	string_lights.clear()
	music = null
	var st := style()
	if st == null:
		return
	root = Node3D.new()
	root.name = "Terrace"
	var y := Terrain.height_at(st.pos.x, st.pos.y)
	root.position = Vector3(st.pos.x, y, st.pos.y)
	root.rotation.y = deg_to_rad(st.yaw)
	add_child(root)
	V7bKit.clear_trees(get_tree(), Rect2(st.pos - Vector2(st.size.x, st.size.y) * 0.62, Vector2(st.size.x, st.size.y) * 1.24))
	_build(st)
	if staffing:
		var bar := at(Vector3(0, 0, -st.size.y * 0.5 + 0.75))
		var dj := at(Vector3(-st.size.x * 0.5 + 1.2, 0, -0.6))
		staffing.add_post("bartender", Array(st.staff.get("bartender", [])), bar, at(Vector3(0, 0, 0)), st.hours)
		staffing.add_post("dj", Array(st.staff.get("dj", [])), dj, at(Vector3(1.0, 0, -0.6)), st.dj_hours)


func _build(st: CafeStyle) -> void:
	var w := st.size.x
	var d := st.size.y
	var wood := V7aKit.mat(Color(0.55, 0.38, 0.24), 0.8)
	var dark_wood := V7aKit.mat(Color(0.32, 0.2, 0.12), 0.7)
	var metal := V7aKit.mat(Color(0.15, 0.15, 0.17), 0.4)
	# Deck on short legs (follows the ground roughly) + collision.
	V7aKit.box(root, Vector3(w, 0.22, d), Vector3(0, 0.11, 0), wood)
	var body := StaticBody3D.new()
	body.name = "TerraceBody"
	root.add_child(body)
	_col(body, Vector3(w, 0.22, d), Vector3(0, 0.11, 0))
	# Railing on the back and sides, open front (+z).
	for sx: float in [-w * 0.5, w * 0.5]:
		V7aKit.box(root, Vector3(0.08, 0.9, d), Vector3(sx, 0.67, 0), dark_wood)
		_col(body, Vector3(0.1, 0.9, d), Vector3(sx, 0.67, 0))
	V7aKit.box(root, Vector3(w, 2.6, 0.12), Vector3(0, 1.4, -d * 0.5), V7aKit.mat(Color(0.86, 0.72, 0.58)))
	_col(body, Vector3(w, 2.6, 0.12), Vector3(0, 1.4, -d * 0.5))
	# Bar counter with stools in front and shelves of bottles / jars behind.
	var bz := -d * 0.5 + 1.5
	V7aKit.box(root, Vector3(4.2, 1.05, 0.6), Vector3(0, 0.74, bz), dark_wood)
	V7aKit.box(root, Vector3(4.4, 0.06, 0.75), Vector3(0, 1.28, bz), V7aKit.mat(Color(0.2, 0.15, 0.1), 0.3))
	_col(body, Vector3(4.2, 1.1, 0.6), Vector3(0, 0.76, bz))
	for k in 3:
		V7aKit.box(root, Vector3(3.6, 0.05, 0.3), Vector3(0, 1.3 + k * 0.42, -d * 0.5 + 0.22), wood)
		for j in 9:
			var c: Color = [Color(0.85, 0.5, 0.1), Color(0.2, 0.55, 0.25), Color(0.75, 0.15, 0.2), Color(0.9, 0.8, 0.3)][(j + k) % 4]
			V7aKit.cyl(root, 0.06, 0.26, Vector3(-1.6 + j * 0.4, 1.46 + k * 0.42, -d * 0.5 + 0.22), V7aKit.mat(c, 0.2, 0.15))
	# Samovar + tea glasses on the counter.
	V7aKit.cyl(root, 0.18, 0.5, Vector3(1.4, 1.56, bz), V7aKit.mat(Color(0.8, 0.65, 0.3), 0.25), 0.12)
	for j in 4:
		V7aKit.cyl(root, 0.04, 0.09, Vector3(-1.2 + j * 0.22, 1.36, bz + 0.12), V7aKit.mat(Color(0.75, 0.25, 0.1), 0.1, 0.1))
	for j in 3:
		var sp := Vector3(-1.3 + j * 1.3, 0, bz + 0.75)
		V7aKit.cyl(root, 0.2, 0.06, sp + Vector3(0, 0.95, 0), dark_wood)
		V7aKit.cyl(root, 0.04, 0.72, sp + Vector3(0, 0.58, 0), metal)
		var s := Seat.new()
		s.display_name = "bar stool"
		s.position = sp + Vector3(0, 0.22, 0)
		s.rotation.y = PI
		s.set_meta(&"pose", &"sit")
		root.add_child(s)
		seats.append(s)
	# The bar: order a drink.
	bar_spot = ActionSpot.make(root, Vector3(0, 0.2, bz + 0.85), 1.4, _bar_text, func(_w: Node3D) -> void: open_menu())
	bar_spot.name = "BarSpot"
	# DJ booth with turntables, speakers and coloured lights.
	var dx := -w * 0.5 + 1.0
	V7aKit.box(root, Vector3(1.0, 1.0, 1.8), Vector3(dx + 0.6, 0.72, -0.6), V7aKit.mat(Color(0.1, 0.1, 0.12)))
	_col(body, Vector3(1.0, 1.0, 1.8), Vector3(dx + 0.6, 0.72, -0.6))
	for k in 2:
		V7aKit.cyl(root, 0.22, 0.04, Vector3(dx + 0.6, 1.25, -1.1 + k * 1.0), V7aKit.mat(Color(0.05, 0.05, 0.05), 0.2))
	for zz: float in [-2.2, 1.4]:
		V7aKit.box(root, Vector3(0.7, 1.5, 0.6), Vector3(dx, 0.97, zz), V7aKit.mat(Color(0.08, 0.08, 0.09)))
		V7aKit.cyl(root, 0.2, 0.05, Vector3(dx + 0.36, 1.2, zz), metal).rotation.z = PI * 0.5
		_col(body, Vector3(0.7, 1.5, 0.6), Vector3(dx, 0.97, zz))
	for k in 2:
		var ol := OmniLight3D.new()
		ol.light_color = [Color(0.7, 0.2, 1.0), Color(0.15, 0.6, 1.0)][k]
		ol.omni_range = 7.0
		ol.light_energy = 0.0
		ol.position = Vector3(dx + 1.2, 2.6, -1.5 + k * 2.0)
		ol.shadow_enabled = false
		root.add_child(ol)
		dj_lights.append(ol)
	music = AudioStreamPlayer3D.new()
	music.name = "DJMusic"
	music.position = Vector3(dx + 0.4, 1.3, -0.6)
	music.unit_size = 9.0
	music.max_distance = st.music_range
	music.volume_db = st.music_db
	music.attenuation_filter_cutoff_hz = 12000.0
	if not st.music.is_empty():
		var s0 := load(st.music[0]) as AudioStream
		if s0:
			var s1 := s0.duplicate() as AudioStream
			if s1 is AudioStreamOggVorbis:
				(s1 as AudioStreamOggVorbis).loop = true
			music.stream = s1
	root.add_child(music)
	# Tables with chairs.
	for i in 3:
		var tp := Vector3(-0.6 + i * 2.2, 0, 1.6 if i != 1 else 2.9)
		V7aKit.cyl(root, 0.5, 0.05, tp + Vector3(0, 0.95, 0), V7aKit.mat(Color(0.92, 0.9, 0.85), 0.5))
		V7aKit.cyl(root, 0.05, 0.75, tp + Vector3(0, 0.58, 0), metal)
		V7aKit.cyl(root, 0.06, 0.08, tp + Vector3(0.15, 1.02, 0.1), V7aKit.mat(Color(0.75, 0.25, 0.1), 0.1, 0.1))
		for sgn: float in [-1.0, 1.0]:
			var cp := tp + Vector3(sgn * 0.85, 0, 0)
			V7aKit.box(root, Vector3(0.45, 0.06, 0.45), cp + Vector3(0, 0.66, 0), dark_wood)
			V7aKit.box(root, Vector3(0.06, 0.5, 0.45), cp + Vector3(sgn * 0.21, 0.92, 0), dark_wood)
			var s := Seat.new()
			s.display_name = "cafe chair"
			s.position = cp + Vector3(0, 0.22, 0)
			s.rotation.y = -sgn * PI * 0.5
			s.set_meta(&"pose", &"sit")
			root.add_child(s)
			seats.append(s)
	# String lights on four poles.
	var bulb := V7aKit.mat(Color(1.0, 0.85, 0.5), 0.3, 2.5)
	var corners := [Vector3(-w * 0.5 + 0.2, 0, d * 0.5 - 0.2), Vector3(w * 0.5 - 0.2, 0, d * 0.5 - 0.2), Vector3(w * 0.5 - 0.2, 0, -d * 0.5 + 0.3), Vector3(-w * 0.5 + 0.2, 0, -d * 0.5 + 0.3)]
	for c: Vector3 in corners:
		V7aKit.cyl(root, 0.05, 3.0, c + Vector3(0, 1.6, 0), metal)
	for e in 4:
		var a: Vector3 = corners[e] + Vector3(0, 3.0, 0)
		var b: Vector3 = corners[(e + 1) % 4] + Vector3(0, 3.0, 0)
		for k in 7:
			var t := (k + 0.5) / 7.0
			var p := a.lerp(b, t) - Vector3(0, sin(t * PI) * 0.35, 0)
			string_lights.append(V7aKit.ball(root, 0.07, p, bulb))
	var lamp := OmniLight3D.new()
	lamp.name = "TerraceGlow"
	lamp.light_color = Color(1.0, 0.82, 0.55)
	lamp.omni_range = 9.0
	lamp.light_energy = 0.0
	lamp.position = Vector3(0, 2.8, 0.6)
	lamp.shadow_enabled = false
	root.add_child(lamp)
	dj_lights.append(lamp)
	_sign = V7bKit.sign(root, Vector3(w * 0.5 - 0.8, 0.1, d * 0.5 + 0.6), 0.0, "کافه‌ی تراس شب", "Terrace Cafe", Color(0.35, 0.16, 0.3), 3.0)


func _col(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


func _bar_text() -> String:
	return Lang.loc_ui("order a drink") if is_open() else Lang.tt("تراس بسته است", "the terrace is closed")


func is_open() -> bool:
	var st := style()
	return st != null and Staffing.open_at(st.hours, TimeManager.hours_float())


func dj_time() -> bool:
	var st := style()
	return st != null and Staffing.open_at(st.dj_hours, TimeManager.hours_float())


func bartender() -> TownspersonBot:
	return staffing.holder("bartender") if staffing else null


func dj() -> TownspersonBot:
	return staffing.holder("dj") if staffing else null


func open_menu() -> bool:
	var st := style()
	if st == null:
		return false
	if not is_open():
		GameEvents.notification_requested.emit(V7bKit.line(st.lines.get("closed", [])))
		return false
	if staffing:
		staffing.tick()
	var b := bartender()
	if b:
		V7bKit.say_small(b, V7bKit.line(st.lines.get("bartender_greet", []), {}, _rng))
		if staffing.is_standin("bartender"):
			var who := V7aKit.bot_named(get_tree(), str(staffing.posts["bartender"].get("for", "")))
			var nm := Dialogue.first_name(who.resident) if who else str(staffing.posts["bartender"].get("for", "")).get_slice(" ", 0)
			b.say(V7bKit.line(st.lines.get("standin", []), {"name": nm}, _rng), 3.5)
	menu_panel.open()
	return true


func menu_item(id: String) -> Dictionary:
	var st := style()
	if st:
		for m: Dictionary in st.menu:
			if str(m.get("id", "")) == id:
				return m
	return {}


## Buy a drink: "ok", "refused" (strong limit -> a free tea), "poor", "closed", "none".
func order(id: String) -> String:
	var st := style()
	var m := menu_item(id)
	if st == null or m.is_empty():
		return "none"
	if not is_open():
		return "closed"
	var p := V7bKit.player(get_tree())
	var b := bartender()
	if str(m.get("kind", "")) == "strong" and TownLife.strong_today() >= st.max_strong:
		refused += 1
		var line := V7bKit.line(st.lines.get("refuse", []), {}, _rng)
		if b:
			b.say(line, 4.0)
		GameEvents.notification_requested.emit(line)
		_apply(menu_item("tea"), p)
		return "refused"
	var price := int(m.get("price", 0))
	if Economy.money < price:
		GameEvents.notification_requested.emit(Lang.tt("پول کافی نداری.", "Not enough money."))
		return "poor"
	Economy.add_money(-price)
	CityState.add_income("tax", int(ceil(price * 0.1)), "Cafe sales tax", "مالیات فروش کافه")
	_apply(m, p)
	served += 1
	TownLife.cafe["drinks"] = int(TownLife.cafe.get("drinks", 0)) + 1
	if str(m.get("kind", "")) == "strong":
		if int(TownLife.cafe.get("strong_day", -1)) != TimeManager.day:
			TownLife.cafe["strong_day"] = TimeManager.day
			TownLife.cafe["strong_today"] = 0
		TownLife.cafe["strong_today"] = int(TownLife.cafe["strong_today"]) + 1
	GameEvents.notification_requested.emit(Lang.tt("%s نوشیدی (%s سکه)." % [str(m.get("fa", "")), Lang.digits(str(price))], "You drink a %s (%d G)." % [str(m.get("en", "")), price]))
	return "ok"


func _apply(m: Dictionary, p: Player) -> void:
	if m.is_empty():
		return
	var stam := float(m.get("stamina", 0))
	if p:
		if stam >= 0.0:
			p.restore_stamina(stam)
		else:
			p.spend_stamina(-stam)
	if float(m.get("hunger", 0)) > 0.0:
		Needs.eat(float(m.get("hunger", 0)), false)
	var t := float(m.get("tipsy", 0))
	if t > 0.0:
		TownLife.tipsy = minf(TownLife.tipsy + t, 150.0)
		# Health: strong drinks tire you (and the doctor notices).
		Needs.fatigue = minf(Needs.fatigue + 4.0, 100.0)
		Needs.changed.emit()
		GameEvents.notification_requested.emit(Lang.tt("کمی سرت گیج می‌رود... امشب رانندگی نکن.", "You feel a little tipsy... don't drive tonight."))


# ------------------------------------------------------------------ guests
class GuestController extends V7aKit.ScriptController:
	var seat: Seat
	func tick(bot: Node3D, delta: float) -> Dictionary:
		if seat and is_instance_valid(seat) and bot.global_position.distance_to(seat.global_position) < 1.4 and (seat.is_free() or seat.occupant == bot):
			return {"seat": seat}
		if seat and is_instance_valid(seat):
			target = seat.global_position
		return super.tick(bot, delta)


func free_seats() -> Array[Seat]:
	var out: Array[Seat] = []
	for s in seats:
		if is_instance_valid(s) and s.is_free() and s.display_name == "cafe chair":
			var taken := false
			for g in guests:
				if is_instance_valid(g) and g.controller is GuestController and (g.controller as GuestController).seat == s:
					taken = true
			if not taken:
				out.append(s)
	return out


## A resident comes to sit at a free table.
func invite_guest(b: TownspersonBot = null) -> TownspersonBot:
	var free := free_seats()
	if free.is_empty():
		return null
	if b == null:
		var best_d := INF
		for x in V7aKit.bots(get_tree()):
			if x in guests or int(x.resident.get("age", 0)) < 18 or not (x.controller is ScheduleController) or (staffing and staffing.unavailable(x, "guest") != ""):
				continue
			var d := x.global_position.distance_to(root.global_position)
			if d < best_d:
				best_d = d
				b = x
	if b == null:
		return null
	var gc := GuestController.new()
	gc.original = b.controller
	gc.seat = free[0]
	gc.tag = "cafe_guest"
	gc.speed = 1.5
	b.set_controller(gc)
	if b.global_position.distance_to(gc.seat.global_position) > 25.0 or b.hidden_inside:
		b.global_position = gc.seat.global_position + Vector3(0.8, 0.1, 0.8)
	guests.append(b)
	return b


func send_guests_home() -> void:
	for g in guests:
		if is_instance_valid(g) and g.controller is GuestController:
			g.set_controller((g.controller as GuestController).original)
			if g.controller is ScheduleController:
				g.snap_to_schedule()
	guests.clear()


func seated_guests() -> int:
	var n := 0
	for g in guests:
		if is_instance_valid(g) and g.controller is GuestController and (g.controller as GuestController).seat and (g.controller as GuestController).seat.occupant == g:
			n += 1
	return n


# ------------------------------------------------------------------ fights
func start_fight(a: TownspersonBot = null, b: TownspersonBot = null) -> bool:
	var st := style()
	if st == null or not fight.is_empty():
		return false
	if a == null or b == null:
		var gs: Array[TownspersonBot] = []
		for g in guests:
			if is_instance_valid(g) and g.controller is GuestController:
				gs.append(g)
		if gs.size() < 2:
			return false
		# Hot tempers start it.
		gs.sort_custom(func(x: TownspersonBot, y: TownspersonBot) -> bool: return Personalities.temper(x.resident) > Personalities.temper(y.resident))
		a = gs[0]
		b = gs[1]
	var mid := (a.global_position + b.global_position) * 0.5
	for pair in [[a, b, -1.0], [b, a, 1.0]]:
		var x := pair[0] as TownspersonBot
		var sc := V7aKit.ScriptController.new()
		sc.original = (x.controller as GuestController).original if x.controller is GuestController else x.controller
		sc.tag = "fight"
		sc.pose = &"talk"
		var off := at(Vector3(float(pair[2]) * 0.6, 0, 0.0)) - root.global_position
		sc.target = mid + off
		sc.face_to = mid - off
		sc.speed = 2.0
		x.set_controller(sc)
		V7aKit.bubble_color(x, Color(1.0, 0.42, 0.35))
	guests.erase(a)
	guests.erase(b)
	fight = {"a": a, "b": b, "t": 0.0, "police": false, "line_t": 0.0, "turn": 0, "pos": mid}
	fights += 1
	TownLife.cafe["fights"] = int(TownLife.cafe.get("fights", 0)) + 1
	TownLife.count_event("cafe_fight")
	GameEvents.notification_requested.emit(Lang.tt("دعوا در کافه‌ی تراس! %s و %s به هم پریدند." % [Dialogue.first_name(a.resident), Dialogue.first_name(b.resident)],
		"A scuffle at the terrace cafe! %s and %s are going at it." % [str(a.resident.get("name", "")), str(b.resident.get("name", ""))]))
	return true


## Ends the fight; consequences when `settled` (fines, bruises, memories).
func end_fight(settled: bool, by: String = "bartender") -> void:
	if fight.is_empty():
		return
	var st := style()
	for x in [fight.get("a"), fight.get("b")]:
		var bot := x as TownspersonBot
		if bot == null or not is_instance_valid(bot):
			continue
		V7aKit.bubble_color(bot, Color(1, 1, 1))
		var sc := bot.controller as V7aKit.ScriptController
		if sc and sc.tag == "fight":
			bot.set_controller(V7bKit.original_of(sc))
		if settled and st:
			var key := Friendship.key_of(bot)
			CityState.add_fine("cafe_fight", st.fight_fine, "Disturbing the peace at the cafe (%s)" % str(bot.resident.get("name", "")),
				"برهم زدن آرامش در کافه (%s)" % Dialogue.first_name(bot.resident), false)
			WorldMemory.npc_remember(key, "cafe_fight", "I got into a stupid fight at the cafe and paid a fine.", "در کافه دعوای بی‌خودی کردم و جریمه دادم.")
			var ns := Needs.npc_state(bot)
			if not ns.is_empty():
				ns["fatigue"] = minf(float(ns.get("fatigue", 0.0)) + 20.0, 100.0)  # a bruise: tired and sore
	if settled:
		WorldMemory.file_report("cafe_fight", Friendship.key_of(fight["a"]) if is_instance_valid(fight["a"]) else "", "", st.fight_fine * 2 if st else 0)
		if by == "police":
			breakups_police += 1
		else:
			breakups_bartender += 1
			TownLife.cafe["breakups"] = int(TownLife.cafe.get("breakups", 0)) + 1
	var pp := get_tree().current_scene.find_child("PolicePatrol", true, false) as PolicePatrol
	if bool(fight.get("police", false)) and pp and pp.car:
		pp.responding = false
		pp.car.set_flashing(false)
	fight = {}


func _step_fight(delta: float) -> void:
	var st := style()
	var a := fight["a"] as TownspersonBot
	var b := fight["b"] as TownspersonBot
	if st == null or not is_instance_valid(a) or not is_instance_valid(b):
		end_fight(false)
		return
	fight["t"] = float(fight["t"]) + delta
	fight["line_t"] = float(fight["line_t"]) - delta
	if float(fight["line_t"]) <= 0.0:
		fight["line_t"] = 2.2
		var sp := a if int(fight["turn"]) % 2 == 0 else b
		var own: Array = Personalities.lines(sp.resident, "argue")
		var table: Array = own if not own.is_empty() and _rng.randf() < 0.3 else st.lines.get("fight", [])
		var l := V7bKit.line(table, {}, _rng)
		sp.say(l, 2.0)
		sp.start_wave(1.2, 1.0, 9.0)
		fight["turn"] = int(fight["turn"]) + 1
	var t := float(fight["t"])
	var bt := bartender()
	if t > st.fight_seconds:
		if bt:
			bt.say(V7bKit.line(st.lines.get("breakup", []), {}, _rng), 4.0)
			end_fight(true, "bartender")
		elif not bool(fight["police"]):
			fight["police"] = true
			var pp := get_tree().current_scene.find_child("PolicePatrol", true, false) as PolicePatrol
			if pp and pp.car:
				pp.responding = true
				pp.car.set_flashing(true)
				pp.car.drive_to(fight["pos"], false)
		elif t > st.fight_seconds + 12.0:
			GameEvents.notification_requested.emit(V7bKit.line(st.lines.get("police", [])))
			end_fight(true, "police")


func _on_hour(h: int, _d: int) -> void:
	var st := style()
	if st == null or not auto:
		return
	if is_open():
		while guests.size() < 3 and invite_guest() != null:
			pass
		if _rng.randf() < st.fight_chance and h >= 20:
			start_fight()
	else:
		send_guests_home()


func _process(delta: float) -> void:
	var st := style()
	if st == null or root == null:
		return
	if not fight.is_empty():
		_step_fight(delta)
	_t -= delta
	if _t > 0.0:
		return
	_t = 0.5
	var dj_on := dj_time() and dj() != null
	var night := TimeManager.hours_float() >= 18.0 or TimeManager.hours_float() < 5.0
	if music:
		if dj_on and not music.playing and music.stream:
			music.play()
		elif not dj_on and music.playing:
			music.stop()
	var tt := Time.get_ticks_msec() / 1000.0
	for i in dj_lights.size():
		var l := dj_lights[i]
		if l.name == "TerraceGlow":
			l.light_energy = 1.4 if night and is_open() else 0.0
		else:
			l.light_energy = (1.2 + 0.8 * sin(tt * 3.0 + i * 2.0)) if dj_on and night else 0.0
	for s in string_lights:
		s.visible = night and is_open()
	if dj_on:
		_dj_t -= 0.5
		if _dj_t <= 0.0:
			_dj_t = 25.0
			V7bKit.say_small(dj(), V7bKit.line(st.lines.get("dj", []), {}, _rng))
			dj().start_wave(1.5, 0.8, 5.0)
