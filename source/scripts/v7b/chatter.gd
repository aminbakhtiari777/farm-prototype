class_name Chatter
extends Node
## v7b "chatter" module: a chattier town. Townspeople near you
##  - make small spontaneous remarks (time of day, weather, their own tone of
##    voice - voice_profiles small talk),
##  - react to events: fires, outages and the power coming back, quakes,
##    fines, new / finished public works, arguments, cafe fights, your fast
##    driving, your horn, driving at night without lights, playing as a
##    resident (v7a), passengers, newspapers, camping,
##  - and have short back-and-forth chats you can overhear (and sometimes a
##    little trade between them, shaped by their personalities).
## Lines show in small bubbles above heads (V7bKit.say_small) with each
## resident's voice, and go to the optional chat log (key 5).

var auto: bool = true          ## false = no timers / polling (tests drive it)
var remarks_made: int = 0
var reactions: int = 0
var chats_overheard: int = 0
var npc_trades: int = 0
var last_kind: String = ""
var last_line: String = ""
var last_speaker: TownspersonBot
var chat: Dictionary = {}      ## {} or {"a", "b", "lines", "i", "t"}
var _rng := RandomNumberGenerator.new()
var _remark_t: float = 12.0
var _chat_t: float = 20.0
var _poll_t: float = 1.0
var _cool: Dictionary = {}     ## kind -> seconds
var _snap: Dictionary = {}
var _horns: int = 0
var _possessing: bool = false


func style() -> ChatterStyle:
	return Modules.style("chatter") as ChatterStyle


func _ready() -> void:
	_rng.randomize()
	TimeManager.weather_changed.connect(func(w: String) -> void:
		if auto and w in ["rain", "storm", "snow", "heatwave", "sunny"]:
			react(w))
	_take_snapshot()
	Modules.on_swap("chatter", self, func(_m: Resource) -> void: end_chat())


func _player() -> Player:
	return V7bKit.player(get_tree())


func _take_snapshot() -> void:
	_snap = {"fires": CityState.fires, "outages": CityState.outages, "quakes": CityState.quakes, "arguments": CityState.arguments,
		"fines": CityState.fines_total, "power": PowerGrid.power_on, "projects": CityState.projects.duplicate(true),
		"fights": int(TownLife.cafe.get("fights", 0)), "rides": int(TownLife.rides.get("delivered", 0)), "camps": int(TownLife.camps.get("trips", 0))}


## Residents who can talk right now near `at` (visible, not busy, not hidden).
func speakers(at: Vector3, radius: float) -> Array[TownspersonBot]:
	var out: Array[TownspersonBot] = []
	for b in V7aKit.bots(get_tree()):
		if b.hidden_inside or b.resident.is_empty() or int(b.resident.get("age", 0)) < 6:
			continue
		if b.controller is Possession.PossessController:
			continue
		var sc := b.controller as V7aKit.ScriptController
		if sc and (sc.tag == "argue" or sc.tag == "fight" or sc.hidden):
			continue
		if V7aKit.flat(b.global_position).distance_to(V7aKit.flat(at)) <= radius:
			out.append(b)
	out.sort_custom(func(x: TownspersonBot, y: TownspersonBot) -> bool:
		return x.global_position.distance_squared_to(at) < y.global_position.distance_squared_to(at))
	return out


func _say(b: TownspersonBot, entry: Dictionary, values: Dictionary = {}) -> String:
	var st := style()
	var pair := V7bKit.both(entry, values)
	var text: String = pair[1] if Lang.is_fa() else pair[0]
	V7bKit.say_small(b, text, st.bubble_seconds if st else 3.6, st.bubble_font if st else 34)
	TownLife.log_line(Dialogue.first_name(b.resident) if Lang.is_fa() else str(b.resident.get("name", "")), pair[0], pair[1])
	last_line = text
	last_speaker = b
	return text


## Someone near `at` (default: the player) reacts to an event `kind`.
## Returns the line said ("" if nobody / module off / cooling down).
func react(kind: String, at: Vector3 = Vector3.INF, force: bool = false) -> String:
	var st := style()
	if st == null or not st.remarks.has(kind):
		return ""
	if not force and (float(_cool.get(kind, 0.0)) > 0.0 or _rng.randf() > st.react_chance):
		return ""
	var p := _player()
	if at == Vector3.INF:
		at = p.global_position if p else Vector3.ZERO
	var who := speakers(at, st.hear_radius * 1.6)
	if who.is_empty() and p and at.distance_to(p.global_position) > 1.0:
		who = speakers(p.global_position, st.hear_radius)
	if who.is_empty():
		return ""
	var b := who[0] if who.size() < 2 or _rng.randf() < 0.6 else who[1]
	var list: Array = st.remarks[kind]
	if list.is_empty():
		return ""
	_cool[kind] = 12.0
	reactions += 1
	last_kind = kind
	return _say(b, list[_rng.randi() % list.size()])


## A spontaneous remark by someone near you.
func remark() -> String:
	var st := style()
	var p := _player()
	if st == null or p == null:
		return ""
	var who := speakers(p.global_position, st.hear_radius)
	if who.is_empty():
		return ""
	var b := who[_rng.randi() % mini(who.size(), 3)]
	var entry: Dictionary = {}
	var roll := _rng.randf()
	if roll < 0.4:
		entry = VoiceProfiles.small_talk(b.resident, _rng)
	if entry.is_empty() and roll < 0.7:
		var w := TimeManager.weather_id
		var list: Array = st.remarks.get(w, [])
		if not list.is_empty():
			entry = list[_rng.randi() % list.size()]
	if entry.is_empty():
		var h := TimeManager.hours_float()
		var list2: Array = st.remarks.get("idle_morning" if h < 14.0 else "idle_evening", [])
		if list2.is_empty():
			return ""
		entry = list2[_rng.randi() % list2.size()]
	remarks_made += 1
	last_kind = "remark"
	return _say(b, entry)


func _topic_weights() -> Dictionary:
	var w := {"weather": 1.0, "fund": 0.8, "prices": 0.8, "family": 1.0, "work": 0.8, "health": 0.8, "cafe": 0.4, "news": 0.2}
	if CityState.fires > 0 or TownLife.paper_day == TimeManager.day:
		w["news"] = 1.5
	if TimeManager.hours_float() >= 15.0:
		w["cafe"] = 1.4
	return w


## Two people near you start a short chat (or a little trade).
func start_chat(a: TownspersonBot = null, b: TownspersonBot = null, topic: String = "") -> bool:
	var st := style()
	var p := _player()
	if st == null or not chat.is_empty():
		return false
	if a == null or b == null:
		if p == null:
			return false
		var who := speakers(p.global_position, st.hear_radius)
		var adults: Array[TownspersonBot] = []
		for x in who:
			if int(x.resident.get("age", 0)) >= 16:
				adults.append(x)
		if adults.size() < 2:
			return false
		a = adults[0]
		b = adults[1]
	if topic == "trade" or (topic == "" and _rng.randf() < 0.25):
		return _start_trade(a, b)
	var pool: Array = []
	var w := _topic_weights()
	for d: Dictionary in st.dialogues:
		if topic == "" or str(d.get("topic", "")) == topic:
			pool.append(d)
	if pool.is_empty():
		return false
	var pick: Dictionary = pool[0]
	if topic == "":
		var total := 0.0
		for d: Dictionary in pool:
			total += float(w.get(str(d.get("topic", "")), 0.5))
		var x := _rng.randf() * total
		for d: Dictionary in pool:
			x -= float(w.get(str(d.get("topic", "")), 0.5))
			if x <= 0.0:
				pick = d
				break
	var seq: Array = []
	for l: Dictionary in pick.get("lines", []):
		seq.append({"entry": l, "values": {}})
	chat = {"a": a, "b": b, "lines": seq, "i": 0, "t": 0.0, "topic": str(pick.get("topic", ""))}
	chats_overheard += 1
	_face_each_other(a, b)
	return true


func _face_each_other(a: TownspersonBot, b: TownspersonBot) -> void:
	for pair in [[a, b], [b, a]]:
		var x := pair[0] as TownspersonBot
		var y := pair[1] as TownspersonBot
		if x.controller is ScheduleController:
			(x.controller as ScheduleController).glance(x, y, 6.0)


## A small trade between two residents - their personalities decide the deal.
func _start_trade(seller: TownspersonBot, buyer: TownspersonBot) -> bool:
	var goods := [["tomatoes", "گوجه"], ["eggs", "تخم‌مرغ"], ["a jar of jam", "یک شیشه مربا"], ["fish", "ماهی"], ["bread", "نان"], ["honey", "عسل"]]
	var g: Array = goods[_rng.randi() % goods.size()]
	var price := 10 + _rng.randi() % 20
	var offer := maxi(1, int(round(price * (1.0 - 0.3 * Personalities.value(buyer.resident, "haggle", 0.4)))))
	var deal := Personalities.npc_deal(seller.resident, buyer.resident, _rng)
	var seq: Array = [
		{"entry": {"en": "How much for the %s?" % g[0], "fa": "%s چند؟" % g[1]}, "values": {}},
		{"entry": {"en": "%d gold." % price, "fa": "%s سکه." % Lang.digits(str(price))}, "values": {}},
	]
	if offer < price:
		var c: Array = Personalities.lines(buyer.resident, "counter")
		seq.append({"entry": c[0] if not c.is_empty() else {"en": "How about {price}?", "fa": "{price} چطور؟"}, "values": {"price": offer}})
	var ans: Array = Personalities.lines(seller.resident, "accept" if deal else "refuse")
	seq.append({"entry": ans[0] if not ans.is_empty() else ({"en": "Deal.", "fa": "قبول."} if deal else {"en": "No.", "fa": "نه."}), "values": {}})
	chat = {"a": buyer, "b": seller, "lines": seq, "i": 0, "t": 0.0, "topic": "trade", "deal": deal}
	chats_overheard += 1
	if deal:
		npc_trades += 1
		TownLife.trades["npc"] = int(TownLife.trades.get("npc", 0)) + 1
		TownLife.count_event("trade")
	_face_each_other(buyer, seller)
	return true


## Says the next line of the current chat (the timer calls it; tests too).
func step_chat() -> bool:
	if chat.is_empty():
		return false
	var a := chat["a"] as TownspersonBot
	var b := chat["b"] as TownspersonBot
	var seq: Array = chat["lines"]
	var i := int(chat["i"])
	if not is_instance_valid(a) or not is_instance_valid(b) or i >= seq.size():
		end_chat()
		return false
	var speaker := a if i % 2 == 0 else b
	var item: Dictionary = seq[i]
	_say(speaker, item["entry"], item.get("values", {}))
	chat["i"] = i + 1
	chat["t"] = 2.8
	if int(chat["i"]) >= seq.size():
		chat["t"] = 3.0
	return true


func end_chat() -> void:
	chat = {}


func _poll() -> void:
	var p := _player()
	# City events.
	if CityState.fires > int(_snap.get("fires", 0)):
		react("fire")
	if CityState.quakes > int(_snap.get("quakes", 0)):
		react("quake")
	elif CityState.outages > int(_snap.get("outages", 0)) or (bool(_snap.get("power", true)) and not PowerGrid.power_on):
		react("outage")
	elif not bool(_snap.get("power", true)) and PowerGrid.power_on:
		react("power_back")
	if CityState.arguments > int(_snap.get("arguments", 0)):
		react("argument")
	if CityState.fines_total > int(_snap.get("fines", 0)):
		react("fine")
	var old: Dictionary = _snap.get("projects", {})
	for id in CityState.projects:
		var now := str((CityState.projects[id] as Dictionary).get("state", ""))
		var was := str((old.get(id, {}) as Dictionary).get("state", "planned"))
		if now != was:
			react("project_done" if now == "done" else "project")
	if int(TownLife.cafe.get("fights", 0)) > int(_snap.get("fights", 0)):
		react("cafe_fight")
	if int(TownLife.rides.get("delivered", 0)) > int(_snap.get("rides", 0)):
		react("passenger")
	if int(TownLife.camps.get("trips", 0)) > int(_snap.get("camps", 0)):
		react("camping")
	_take_snapshot()
	# The player's actions.
	if p == null:
		return
	var car: DrivableCar = p.vehicle as DrivableCar
	if car:
		if absf(car.speed) > 10.0 and not speakers(p.global_position, 9.0).is_empty():
			react("player_fast")
		if car.horn_count != _horns:
			_horns = car.horn_count
			react("player_horn")
		var sys := car.get_node_or_null(^"CarSystems") as CarSystems
		if sys and sys.needs_lights() and not sys.lights_on and absf(car.speed) > 3.0 and not speakers(p.global_position, 10.0).is_empty():
			react("night_no_lights")
	var w7 := get_tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld
	var poss := w7 != null and w7.possession != null and w7.possession.is_active()
	if poss and not _possessing:
		react("player_possess")
	_possessing = poss


func _process(delta: float) -> void:
	for k in _cool.keys():
		_cool[k] = float(_cool[k]) - delta
	if not chat.is_empty():
		chat["t"] = float(chat["t"]) - delta
		if float(chat["t"]) <= 0.0:
			if int(chat["i"]) >= (chat["lines"] as Array).size():
				end_chat()
			else:
				step_chat()
	if not auto:
		return
	var st := style()
	if st == null:
		return
	_poll_t -= delta
	if _poll_t <= 0.0:
		_poll_t = 1.0
		_poll()
	_remark_t -= delta
	if _remark_t <= 0.0:
		_remark_t = _rng.randf_range(st.remark_interval.x, st.remark_interval.y)
		remark()
	_chat_t -= delta
	if _chat_t <= 0.0:
		_chat_t = _rng.randf_range(st.overhear_interval.x, st.overhear_interval.y)
		if start_chat():
			step_chat()
