class_name Conflicts
extends Node3D
## v7a "conflicts" module: now and then two townspeople argue in the street.
## The reason comes from what is going on in town - an unpaid debt, a theft
## report (WorldMemory reports), or noise - and hot-tempered people argue more.
## Heated red bubbles and sharp arm gestures; the player can calm it down (E on
## either of them: talk it out, friendship with both), otherwise the police
## patrol drives over and settles it. Each settled argument is remembered.

var active: Dictionary = {}   ## {} or {"a", "b", "reason", "t", "pos", "police"}
var auto: bool = true   ## false = no random arguments (tests)
var count: int = 0
var calmed_by_player: int = 0
var settled_by_police: int = 0
var _timer: float = 0.0
var _line_t: float = 0.0
var _turn: int = 0
var _rng := RandomNumberGenerator.new()
var _mark: Label3D


func style() -> ConflictStyle:
	return Modules.style("conflicts") as ConflictStyle


func _ready() -> void:
	_rng.randomize()
	TimeManager.hour_changed.connect(_on_hour)
	_mark = Label3D.new()
	_mark.name = "AngerMark"
	Lang.setup_label3d(_mark, 72)
	_mark.text = "!!"
	_mark.modulate = Color(1.0, 0.25, 0.15)
	_mark.outline_size = 14
	_mark.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_mark.pixel_size = 0.008
	_mark.visible = false
	add_child(_mark)
	Modules.on_swap("conflicts", self, func(_m: Resource) -> void: end(""))


func temper(b: TownspersonBot) -> float:
	# v7b: the personalities module decides tempers when it is active.
	if Personalities.style() != null:
		return Personalities.temper(b.resident)
	var st := style()
	if st == null:
		return 0.0
	return float(st.tempers.get(Population.full_name(b.resident), 0.3))


## v7b: hot tempers call for the police sooner.
func police_after_for(a: TownspersonBot, b: TownspersonBot) -> float:
	var st := style()
	var base := st.police_after if st else 18.0
	if is_instance_valid(a) and is_instance_valid(b) and maxf(temper(a), temper(b)) > 0.7:
		return base * 0.7
	return base


## What's going on in town decides the reason.
func pick_reason() -> String:
	var st := style()
	if st == null or st.reasons.is_empty():
		return ""
	var w := {"debt": 1.0, "noise": 0.8, "theft": 0.3}
	for r: Dictionary in WorldMemory.reports:
		if TimeManager.day - int(r.get("day", 0)) <= 3:
			w["theft"] = float(w["theft"]) + 1.5
	if TimeManager.hours_float() < 9.0 or TimeManager.hours_float() > 20.0:
		w["noise"] = float(w["noise"]) + 1.0
	var total := 0.0
	for k in w:
		if st.reasons.has(k):
			total += float(w[k])
	var x := _rng.randf() * total
	for k in w:
		if not st.reasons.has(k):
			continue
		x -= float(w[k])
		if x <= 0.0:
			return str(k)
	return str(st.reasons.keys()[0])


func _on_hour(h: int, _d: int) -> void:
	var st := style()
	if st == null or not auto or not active.is_empty() or h < int(st.hours.x) or h >= int(st.hours.y):
		return
	if _rng.randf() < st.chance_per_hour:
		start_random()


func _adults() -> Array[TownspersonBot]:
	var out: Array[TownspersonBot] = []
	for b in V7aKit.bots(get_tree()):
		if b.hidden_inside or b.resident.is_empty() or int(b.resident.get("age", 0)) < 18:
			continue
		if not (b.controller is ScheduleController):
			continue
		out.append(b)
	return out


## Picks the most hot-tempered visible adult and someone near them.
func start_random() -> bool:
	var people := _adults()
	if people.size() < 2:
		return false
	# Hot tempers first (with a little luck); scores fixed before sorting.
	var a: TownspersonBot = people[0]
	var best_s := -INF
	for x in people:
		var sc := temper(x) + _rng.randf() * 0.4
		if sc > best_s:
			best_s = sc
			a = x
	var b: TownspersonBot = null
	var bd := INF
	for o in people:
		if o == a or str(o.resident.get("home", "")) == str(a.resident.get("home", "")):
			continue
		var d := o.global_position.distance_to(a.global_position)
		if d < bd:
			bd = d
			b = o
	if b == null:
		return false
	return start(a, b, pick_reason())


func start(a: TownspersonBot, b: TownspersonBot, reason: String) -> bool:
	var st := style()
	if st == null or a == null or b == null or not active.is_empty() or not st.reasons.has(reason):
		return false
	# b walks up to a; both face each other.
	var mid := a.global_position
	if b.global_position.distance_to(a.global_position) > 1.6:
		var off := (b.global_position - a.global_position)
		off.y = 0.0
		off = off.normalized() * 1.3 if off.length() > 0.01 else Vector3(1.3, 0, 0)
		b.global_position = a.global_position + off
	for pair in [[a, b], [b, a]]:
		var sc := V7aKit.ScriptController.new()
		sc.original = (pair[0] as TownspersonBot).controller
		sc.pose = &"talk"
		sc.face_to = (pair[1] as Node3D).global_position
		sc.tag = "argue"
		sc.greeted = func(_bot: Node3D, _p: Node3D) -> void: calm.call_deferred(true)
		(pair[0] as TownspersonBot).set_controller(sc)
		V7aKit.bubble_color(pair[0], Color(1.0, 0.42, 0.35))
	active = {"a": a, "b": b, "reason": reason, "t": 0.0, "pos": mid, "police": false}
	count += 1
	CityState.arguments += 1
	_turn = 0
	_line_t = 0.0
	_mark.visible = true
	_mark.global_position = mid + Vector3(0, 2.9, 0)
	GameEvents.notification_requested.emit(Lang.tt("دعوا در خیابان! %s و %s با هم بحث می‌کنند (E: آرامشان کن)." % [Dialogue.first_name(a.resident), Dialogue.first_name(b.resident)],
			"An argument! %s and %s are shouting (E: calm them down)." % [str(a.resident.get("name", "")), str(b.resident.get("name", ""))]))
	return true


func _process(delta: float) -> void:
	if active.is_empty():
		return
	var st := style()
	var a := active["a"] as TownspersonBot
	var b := active["b"] as TownspersonBot
	if st == null or not is_instance_valid(a) or not is_instance_valid(b):
		end("")
		return
	active["t"] = float(active["t"]) + delta
	_line_t -= delta
	if _line_t <= 0.0:
		_line_t = 2.6
		var r: Dictionary = st.reasons[str(active["reason"])]
		var speaker := a if _turn % 2 == 0 else b
		var table: Array = r.get("lines", []) if _turn % 2 == 0 else r.get("replies", [])
		# v7b: personality lines (hot tempers escalate, calm people soothe).
		var own: Array = Personalities.lines(speaker.resident, "argue" if _turn % 2 == 0 else "reply")
		if not own.is_empty() and _rng.randf() < 0.4:
			table = own
		if not table.is_empty():
			var l: Dictionary = table[_rng.randi() % table.size()]
			speaker.say(str(l.get("fa" if Lang.is_fa() else "en", "")), 2.5)
			TownLife.log_line(Dialogue.first_name(speaker.resident), str(l.get("en", "")), str(l.get("fa", "")))
		speaker.start_wave(1.4, 1.0, 6.0)
		_turn += 1
	var t := float(active["t"])
	if t > police_after_for(a, b) and not bool(active["police"]):
		active["police"] = true
		_call_police()
	if t > st.duration:
		settle_by_police()
	_mark.global_position = (a.global_position + b.global_position) * 0.5 + Vector3(0, 2.9 + sin(t * 6.0) * 0.06, 0)


func _police() -> PolicePatrol:
	return get_tree().current_scene.find_child("PolicePatrol", true, false) as PolicePatrol


func _call_police() -> void:
	var pp := _police()
	if pp == null or pp.car == null:
		return
	pp.responding = true
	pp.car.set_flashing(true)
	pp.car.drive_to(active["pos"], false)


## The player talked it out (E on either of them).
func calm(by_player: bool = true) -> bool:
	if active.is_empty():
		return false
	var st := style()
	var a := active["a"] as TownspersonBot
	var b := active["b"] as TownspersonBot
	var r: Dictionary = st.reasons.get(str(active["reason"]), {}) if st else {}
	var c: Dictionary = r.get("calm", {})
	var msg := str(c.get("fa" if Lang.is_fa() else "en", ""))
	if by_player:
		calmed_by_player += 1
		CityState.calmed += 1
		for x in [a, b]:
			if is_instance_valid(x):
				var key := Friendship.key_of(x)
				# v7b: calm / generous people appreciate it more.
				var bonus := 5 if Personalities.trait_id(x.resident) in ["calm", "generous"] else 0
				Friendship.add_points(key, (st.calm_friendship if st else 10) + bonus)
				WorldMemory.npc_remember(key, "calmed", "You calmed down our argument.", "دعوایمان را آرام کردی.")
		GameEvents.notification_requested.emit(Lang.tt("آرامشان کردی. %s" % msg, "You calmed them down. %s" % msg))
	end(msg)
	return true


func settle_by_police() -> void:
	if active.is_empty():
		return
	settled_by_police += 1
	var a := active["a"] as TownspersonBot
	for x in [active["a"], active["b"]]:
		if is_instance_valid(x):
			WorldMemory.npc_remember(Friendship.key_of(x), "police_settled", "The police had to settle our argument.", "پلیس مجبور شد دعوایمان را فیصله بدهد.")
	WorldMemory.file_report("argument", Friendship.key_of(a) if is_instance_valid(a) else "", str(a.resident.get("home", "")) if is_instance_valid(a) else "", 0)
	GameEvents.notification_requested.emit(Lang.tt("پلیس دعوا را فیصله داد.", "The police settled the argument."))
	end(Lang.tt("باشد، جناب سروان.", "All right, officer."))


func end(msg: String) -> void:
	if active.is_empty():
		_mark.visible = false
		return
	for x in [active.get("a"), active.get("b")]:
		var bot := x as TownspersonBot
		if bot and is_instance_valid(bot):
			V7aKit.bubble_color(bot, Color(1, 1, 1))
			var sc := bot.controller as V7aKit.ScriptController
			if sc and sc.tag == "argue":
				bot.set_controller(sc.original)
			if msg != "":
				bot.say(msg, 4.0)
	active = {}
	_mark.visible = false


func is_arguing() -> bool:
	return not active.is_empty()
