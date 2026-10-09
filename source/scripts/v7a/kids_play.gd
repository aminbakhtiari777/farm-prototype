class_name KidsPlay
extends Node3D
## v7a "kids" module: after school (and on weekend mornings) the town's
## children come out to play. They ride bikes round the square and along the
## streets, play tag, stop to chat, and now and then ring a doorbell and run
## off - the grumpy owner steps out. Each kid keeps their own schedule
## outside play time (their ScheduleController is put back).

var kids: Array[TownspersonBot] = []
var bikes: Dictionary = {}       ## kid -> Node3D bike
var controllers: Dictionary = {} ## kid -> KidController
var playing: bool = false
var forced: bool = false
var auto: bool = true   ## false = only forced play (tests)
var laps: int = 0
var chats: int = 0
var mischief: int = 0
var _timer: float = 0.0
var _rng := RandomNumberGenerator.new()
var loop: PackedVector3Array = PackedVector3Array()


class KidController extends BotController:
	var original: BotController
	var mode: String = "bike"    # bike | tag | chat | ring | run
	var loop_i: int = 0
	var speed: float = 4.2
	var owner: KidsPlay
	var target: Vector3 = Vector3.INF
	var partner: Node3D
	var timer: float = 0.0
	var direction: int = 1
	func tick(bot: Node3D, delta: float) -> Dictionary:
		timer -= delta
		match mode:
			"bike":
				var p: Vector3 = owner.loop[loop_i]
				var to := p - bot.global_position
				to.y = 0.0
				if to.length() < 1.4:
					loop_i = (loop_i + direction + owner.loop.size()) % owner.loop.size()
					if loop_i == 0:
						owner.laps += 1
				return {"move": to.normalized() * speed, "pose": &"sit"}
			"chat":
				if partner and is_instance_valid(partner):
					var f := partner.global_position - bot.global_position
					return {"move": Vector3.ZERO, "face": atan2(f.x, f.z), "pose": &"talk"}
				return {"move": Vector3.ZERO, "pose": &"talk"}
			"tag":
				if target == Vector3.INF or V7aKit.flat(bot.global_position).distance_to(V7aKit.flat(target)) < 0.8 or timer <= 0.0:
					var c: Vector3 = owner.loop[0].lerp(owner.loop[4], 0.5)
					target = c + Vector3(owner._rng.randf_range(-6, 6), 0, owner._rng.randf_range(-4, 4))
					timer = 3.0
				var t2 := target - bot.global_position
				t2.y = 0.0
				return {"move": t2.normalized() * 2.6}
			"ring", "run":
				if target == Vector3.INF:
					return {"move": Vector3.ZERO}
				var t3 := target - bot.global_position
				t3.y = 0.0
				if t3.length() < 0.7:
					if mode == "ring" and timer <= 0.0:
						owner._rang(bot as TownspersonBot)
					return {"move": Vector3.ZERO, "face": atan2(t3.x, t3.z) if mode == "ring" else 0.0}
				return {"move": t3.normalized() * (1.6 if mode == "ring" else 3.6)}
		return {"move": Vector3.ZERO}
	func on_greeted(_bot: Node3D, _player: Node3D) -> String:
		return ""
	func describe() -> String:
		return "kid:" + mode


func style() -> KidsStyle:
	return Modules.style("kids") as KidsStyle


func _ready() -> void:
	_rng.randomize()
	_build_loop()
	_find_kids.call_deferred()
	Modules.on_swap("kids", self, func(_m: Resource) -> void:
		stop_play()
		_build_loop())


func _build_loop() -> void:
	loop = PackedVector3Array()
	var st := style()
	if st == null:
		return
	for p: Vector2 in st.bike_loop:
		loop.append(V7aKit.ground(p.x, p.y))


func _find_kids() -> void:
	kids.clear()
	var st := style()
	var max_age := st.max_age if st else 13
	for b in V7aKit.bots(get_tree()):
		if not b.resident.is_empty() and int(b.resident.get("age", 99)) <= max_age:
			kids.append(b)


func play_time() -> bool:
	var st := style()
	if st == null:
		return false
	var h := TimeManager.hours_float()
	var weekend := TimeManager.day % 7 in [5, 6]
	var from := 10.0 if weekend else st.play_hours.x
	return h >= from and h < st.play_hours.y and TimeManager.weather_id not in ["rain", "storm", "snow"]


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 1.0
	if kids.is_empty():
		_find_kids()
	var want := forced or (auto and play_time())
	if want and not playing:
		start_play()
	elif not want and playing:
		stop_play()
	if playing:
		_think()


## Kids come out: two bike round the square, the others play tag / chat.
func start_play(force: bool = false) -> void:
	forced = forced or force
	var st := style()
	if st == null or loop.is_empty():
		return
	if kids.is_empty():
		_find_kids()
	playing = true
	for i in kids.size():
		var k := kids[i]
		if k.controller is KidController:
			continue
		var kc := KidController.new()
		kc.original = k.controller
		kc.owner = self
		kc.speed = st.bike_speed
		kc.loop_i = (i * 3) % loop.size()
		kc.direction = 1 if i % 2 == 0 else -1
		kc.mode = "bike" if i < 2 else "tag"
		controllers[k] = kc
		k.set_controller(kc)
		if k.hidden_inside or k.global_position.distance_to(loop[0]) > 40.0:
			var p := loop[kc.loop_i]
			k.global_position = p + Vector3(0, 0.1, 0)
		_set_bike(k, kc.mode == "bike")


func stop_play() -> void:
	playing = false
	forced = false
	for k: TownspersonBot in controllers.keys():
		if is_instance_valid(k):
			var kc: KidController = controllers[k]
			k.set_controller(kc.original)
			_set_bike(k, false)
	controllers.clear()


func _set_bike(k: TownspersonBot, on: bool) -> void:
	var bike: Node3D = bikes.get(k, null)
	if on and bike == null:
		bike = _make_bike(bikes.size())
		k.add_child(bike)
		bikes[k] = bike
	if bike:
		bike.visible = on
	if k.visual:
		k.visual.position.y = 0.28 if on else 0.0


func _make_bike(i: int) -> Node3D:
	var st := style()
	var col: Color = st.bike_colors[i % st.bike_colors.size()] if st and not st.bike_colors.is_empty() else Color(0.8, 0.2, 0.15)
	var b := Node3D.new()
	b.name = "Bike"
	var dark := V7aKit.mat(Color(0.08, 0.08, 0.09), 0.6)
	var frame := V7aKit.mat(col, 0.4)
	for z in [-0.42, 0.42]:
		var w := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.24
		t.outer_radius = 0.3
		t.rings = 14
		t.ring_segments = 6
		w.mesh = t
		w.material_override = dark
		w.position = Vector3(0, 0.3, z)
		w.rotation = Vector3(0, 0, PI * 0.5)
		b.add_child(w)
	V7aKit.box(b, Vector3(0.05, 0.05, 0.86), Vector3(0, 0.52, 0), frame)
	V7aKit.box(b, Vector3(0.05, 0.36, 0.05), Vector3(0, 0.45, -0.14), frame)
	V7aKit.box(b, Vector3(0.05, 0.4, 0.05), Vector3(0, 0.5, 0.36), frame)
	V7aKit.box(b, Vector3(0.14, 0.05, 0.24), Vector3(0, 0.66, -0.16), dark)
	V7aKit.box(b, Vector3(0.5, 0.04, 0.04), Vector3(0, 0.72, 0.38), dark)
	# Faces the kid's walking direction (the visual turns, the bike follows it).
	return b


func _think() -> void:
	var st := style()
	if st == null:
		return
	# Bikes face where their rider faces.
	for k: TownspersonBot in bikes.keys():
		if is_instance_valid(k) and k.visual:
			(bikes[k] as Node3D).rotation.y = k.visual.rotation.y
	# Occasionally two kids stop to chat; occasionally one goes ring-and-run.
	if _rng.randf() < 0.06:
		start_chat()
	if _rng.randf() < st.mischief_chance / 60.0:
		ring_and_run()


func _kc(k: TownspersonBot) -> KidController:
	return controllers.get(k, null)


## Two kids stop and chat (bubbles), then go back to playing.
func start_chat() -> bool:
	var st := style()
	if kids.size() < 2 or st == null:
		return false
	var a := kids[_rng.randi() % kids.size()]
	var b := kids[(kids.find(a) + 1) % kids.size()]
	var ka := _kc(a)
	var kb := _kc(b)
	if ka == null or kb == null or ka.mode in ["ring", "run"] or kb.mode in ["ring", "run"]:
		return false
	b.global_position = a.global_position + Vector3(1.1, 0, 0.3)
	for pair in [[a, ka, b], [b, kb, a]]:
		var kc: KidController = pair[1]
		kc.mode = "chat"
		kc.partner = pair[2]
		_set_bike(pair[0], false)
	var line: Dictionary = st.chat_lines[_rng.randi() % st.chat_lines.size()] if not st.chat_lines.is_empty() else {"en": "Hi!", "fa": "سلام!"}
	a.say(str(line.get("fa" if Lang.is_fa() else "en", "")), 3.0)
	var line2: Dictionary = st.chat_lines[_rng.randi() % st.chat_lines.size()] if not st.chat_lines.is_empty() else line
	b.say(str(line2.get("fa" if Lang.is_fa() else "en", "")), 3.0)
	chats += 1
	get_tree().create_timer(6.0).timeout.connect(func() -> void:
		for pair2 in [[a, ka, 0], [b, kb, 1]]:
			var kc2: KidController = pair2[1]
			if is_instance_valid(pair2[0]) and kc2.mode == "chat":
				kc2.mode = "bike" if int(pair2[2]) == 0 else "tag"
				_set_bike(pair2[0], kc2.mode == "bike"))
	return true


## A kid walks to a house door, rings, and runs off giggling.
func ring_and_run(kid: TownspersonBot = null, home: String = "") -> bool:
	var st := style()
	if st == null or st.mischief_chance <= 0.0 or kids.is_empty():
		return false
	if kid == null:
		kid = kids[_rng.randi() % kids.size()]
	var kc := _kc(kid)
	if kc == null:
		return false
	if home == "":
		var homes: Array = []
		for b: Dictionary in TownLayout.homes():
			if str(b.get("id", "")) != "farmhouse" and str(b.get("id", "")) != str(kid.resident.get("home", "")):
				homes.append(str(b["id"]))
		if homes.is_empty():
			return false
		# The closest neighbour's door.
		homes.sort_custom(func(x: String, y: String) -> bool:
			return TownNav.spot_position("door:" + x).distance_to(kid.global_position) < TownNav.spot_position("door:" + y).distance_to(kid.global_position))
		home = str(homes[0])
	var door := TownNav.spot_position("door:" + home)
	if door == Vector3.INF:
		return false
	_set_bike(kid, false)
	kc.mode = "ring"
	kc.timer = 0.0
	kc.target = door
	kid.set_meta(&"ring_home", home)
	return true


## Called when the kid reached the door: ding-dong, run, the owner grumbles.
func _rang(kid: TownspersonBot) -> void:
	var st := style()
	var kc := _kc(kid)
	if kc == null or kc.mode != "ring":
		return
	mischief += 1
	var home := str(kid.get_meta(&"ring_home", ""))
	Sfx.play_at(&"door", kid.global_position, -8.0, 1.4)
	var g: Dictionary = st.kid_lines[_rng.randi() % st.kid_lines.size()] if st and not st.kid_lines.is_empty() else {"en": "Run!", "fa": "فرار کن!"}
	kid.say(str(g.get("fa" if Lang.is_fa() else "en", "")), 2.5)
	kc.mode = "run"
	kc.target = kid.global_position + (kid.global_position - TownNav.spot_position("door:" + home)).normalized() * 12.0
	# The owner comes out and grumbles; they'll remember.
	var owner_bot: TownspersonBot = null
	for b in V7aKit.bots(get_tree()):
		if str(b.resident.get("home", "")) == home and int(b.resident.get("age", 0)) > 15:
			owner_bot = b
			break
	if owner_bot:
		if owner_bot.hidden_inside or owner_bot.global_position.distance_to(kid.global_position) > 30.0:
			owner_bot.global_position = TownNav.spot_position("door:" + home)
		var m: Dictionary = st.mischief_lines[_rng.randi() % st.mischief_lines.size()] if st and not st.mischief_lines.is_empty() else {"en": "Kids!", "fa": "بچه‌ها!"}
		owner_bot.say(str(m.get("fa" if Lang.is_fa() else "en", "")), 4.0)
		WorldMemory.npc_remember(Population.full_name(owner_bot.resident), "ring_and_run",
				"%s rang our bell and ran off." % str(kid.resident.get("name", "A kid")),
				"%s زنگ خانه‌مان را زد و فرار کرد." % Dialogue.first_name(kid.resident))
	get_tree().create_timer(5.0).timeout.connect(func() -> void:
		if is_instance_valid(kid) and kc.mode == "run":
			kc.mode = "tag"
			kc.target = Vector3.INF)


func bikers() -> int:
	var n := 0
	for k: TownspersonBot in controllers.keys():
		if (controllers[k] as KidController).mode == "bike":
			n += 1
	return n
