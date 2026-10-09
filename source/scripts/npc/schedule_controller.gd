class_name ScheduleController
extends BotController
## Daily routine AI: a list of {from, to, spot, activity} entries (hours).
## The bot walks there along TownNav routes, then does the activity:
## "work"/"shop" (stand inside), "sit" (nearest free bench/chair), "wander"
## (stroll around the spot), "fish" (stand at the pier end), "sleep" (go home,
## hidden). When the bot is far from the player (off screen) it moves faster
## so routines stay on time even at 10x game speed.

var schedule: Array = []
var home_id: String = ""
var greetings: Array = []
var current: Dictionary = {}
var path: PackedVector3Array = PackedVector3Array()
var path_index: int = 0
var arrived: bool = false
var _wander_target: Vector3 = Vector3.INF
var _wander_timer: float = 0.0
var _seat: Seat = null
var _talk_timer: float = 0.0
var _talk_yaw: float = 0.0
var _rng := RandomNumberGenerator.new()
var walk_speed: float = 1.35
var _sleep_entry: Dictionary = {}
# v4 social life (driven by NpcSocial / the "npc_social" module).
var chat_timer: float = 0.0
var chat_yaw: float = 0.0
var chat_partner: Node3D = null
var social_cooldown: float = 0.0
var stroll_radius: float = 0.0  ## >0: wider random strolls in free time
var detour_chance: float = 0.0  ## chance to walk via a random public spot
var detour_spot: String = ""
## v5b: temporary routine entry that overrides the schedule (an ill
## townsperson walking to the doctor). {} = none.
var override_entry: Dictionary = {}


func _init(entries: Array, home: String, lines: Array, seed_value: int) -> void:
	schedule = entries
	home_id = home
	greetings = lines
	_rng.seed = seed_value


func entry_for_hour(h: float) -> Dictionary:
	if not override_entry.is_empty():
		return override_entry
	for e in schedule:
		var from := float(e["from"])
		var to := float(e["to"])
		if (from <= to and h >= from and h < to) or (from > to and (h >= from or h < to)):
			return e
	if _sleep_entry.is_empty():
		_sleep_entry = {"spot": "in:" + home_id, "activity": "sleep", "from": 0.0, "to": 24.0}
	return _sleep_entry


func describe() -> String:
	if current.is_empty():
		return "idle"
	return "%s at %s%s" % [current.get("activity", "?"), current.get("spot", "?"), "" if arrived else " (walking)"]


func tick(bot: Node3D, delta: float) -> Dictionary:
	var h := TimeManager.hours_float()
	var e := entry_for_hour(h)
	if e != current:
		_begin(bot, e)
	# Talking to the player overrides everything briefly.
	if _talk_timer > 0.0:
		_talk_timer -= delta
		return {"move": Vector3.ZERO, "face": _talk_yaw, "pose": &"talk"}
	social_cooldown = maxf(social_cooldown - delta, 0.0)
	if chat_timer > 0.0:
		chat_timer -= delta
		if chat_timer <= 0.0:
			chat_partner = null
			social_cooldown = 25.0
		return {"move": Vector3.ZERO, "face": chat_yaw, "pose": &"talk"}
	if not arrived:
		return _walk(bot, delta)
	match str(current.get("activity", "")):
		"sleep":
			return {"move": Vector3.ZERO, "hidden": true}
		"sit":
			if _seat != null and not is_instance_valid(_seat):
				_seat = null  # rebuilt building (live style swap)
			if _seat == null or (_seat.occupant != null and _seat.occupant != bot):
				_seat = _find_seat(bot)
			if _seat:
				return {"move": Vector3.ZERO, "pose": &"sit", "seat": _seat}
			return _wander(bot, delta, 3.0)
		"wander":
			return _wander(bot, delta, maxf(float(current.get("radius", 6.0)), stroll_radius))
		"fish":
			return {"move": Vector3.ZERO, "face": atan2(BeachBuilder.PIER_DIR.x, BeachBuilder.PIER_DIR.y), "pose": &""}
		"chat":
			return {"move": Vector3.ZERO, "pose": &"talk", "face": float(current.get("yaw", 0.0))}
		# v6a: gym workouts (gym module) and sunbathing (sunbathing module).
		"workout", "sunbathe":
			var grp := &"gym_stations" if str(current.get("activity")) == "workout" else &"sun_towels"
			if grp == &"sun_towels" and not SunbathingBeach.is_sunbathing_time():
				_seat = null
				return _wander(bot, delta, 5.0)
			if _seat != null and not is_instance_valid(_seat):
				_seat = null
			if _seat == null or (_seat.occupant != null and _seat.occupant != bot):
				_seat = _find_seat(bot, grp, 20.0)
			if _seat:
				return {"move": Vector3.ZERO, "pose": StringName(_seat.get_meta(&"pose", &"sit")), "seat": _seat}
			return _wander(bot, delta, 2.0)
		_:
			return _wander(bot, delta, 1.2)


func _begin(bot: Node3D, e: Dictionary) -> void:
	current = e
	arrived = false
	_seat = null
	_wander_target = Vector3.INF
	path = TownNav.route(bot.global_position, str(e["spot"]))
	detour_spot = ""
	# Randomised routes: sometimes stroll past another public spot on the way.
	if detour_chance > 0.0 and _rng.randf() < detour_chance and path.size() > 2:
		var target := TownNav.spot_position(str(e["spot"]))
		var direct := bot.global_position.distance_to(target)
		var options: Array[String] = []
		for sp in TownNav.public_spots():
			var q := TownNav.spot_position(sp)
			if sp != str(e["spot"]) and bot.global_position.distance_to(q) + q.distance_to(target) < direct * 1.6 + 12.0:
				options.append(sp)
		if not options.is_empty():
			detour_spot = options[_rng.randi() % options.size()]
			var via := TownNav.route(bot.global_position, detour_spot)
			var rest := TownNav.route(TownNav.spot_position(detour_spot), str(e["spot"]))
			if not via.is_empty() and not rest.is_empty():
				via.append_array(rest)
				path = via
			else:
				detour_spot = ""
	path_index = 0
	if path.is_empty():
		arrived = true


func _walk(bot: Node3D, delta: float) -> Dictionary:
	if path_index >= path.size():
		arrived = true
		return {"move": Vector3.ZERO}
	var target := path[path_index]
	var to := target - bot.global_position
	to.y = 0.0
	if to.length() < 0.7:
		path_index += 1
		return _walk(bot, delta) if path_index < path.size() else {"move": Vector3.ZERO}
	var speed := walk_speed
	if bot.has_method("is_far_from_player") and bot.call("is_far_from_player"):
		speed = walk_speed * 5.0  # off-screen fast travel keeps routines on time
	speed *= clampf(TimeManager.speed(), 1.0, 4.0)
	return {"move": to.normalized() * speed}


func _wander(bot: Node3D, delta: float, radius: float) -> Dictionary:
	_wander_timer -= delta
	var center := TownNav.spot_position(str(current["spot"]))
	if _wander_target == Vector3.INF or _wander_timer <= 0.0:
		if _rng.randf() < 0.45:
			_wander_target = bot.global_position  # stand still for a while
		else:
			var a := _rng.randf() * TAU
			_wander_target = center + Vector3(cos(a), 0, sin(a)) * _rng.randf_range(0.0, radius)
		_wander_timer = _rng.randf_range(3.0, 8.0)
	var to := _wander_target - bot.global_position
	to.y = 0.0
	if to.length() < 0.4:
		return {"move": Vector3.ZERO}
	return {"move": to.normalized() * walk_speed * 0.7}


func _find_seat(bot: Node3D, group: StringName = &"seats", max_d: float = 14.0) -> Seat:
	var best: Seat = null
	var best_d := max_d
	for s in bot.get_tree().get_nodes_in_group(group):
		var seat := s as Seat
		if seat == null or not seat.is_free():
			continue
		# v6a: gym stations, towels and boat benches only for their activity.
		if group == &"seats" and seat.has_meta(&"special"):
			continue
		var d := seat.global_position.distance_to(bot.global_position)
		if d < best_d:
			best = seat
			best_d = d
	return best


func on_greeted(bot: Node3D, player: Node3D) -> String:
	var to := player.global_position - bot.global_position
	_talk_yaw = atan2(to.x, to.z)
	_talk_timer = 3.5
	var h := TimeManager.hour()
	var hello := "Good morning" if h < 12 else ("Good afternoon" if h < 18 else "Good evening")
	var name_s := str(Settings.get_value("player_name"))
	var line: String = greetings[_rng.randi() % greetings.size()] if not greetings.is_empty() else "Nice day, isn't it?"
	return "%s%s! %s" % [hello, (", " + name_s) if name_s != "" else "", line]


## True when the bot is outdoors, awake and free to stop for a chat.
func can_chat() -> bool:
	if chat_timer > 0.0 or _talk_timer > 0.0 or social_cooldown > 0.0:
		return false
	var act := str(current.get("activity", ""))
	if act in ["sleep", "sit", "work", "shop", "workout", "sunbathe"]:
		return false
	return not str(current.get("spot", "")).begins_with("in:")


func start_chat(partner: Node3D, bot: Node3D, seconds: float) -> void:
	var to := partner.global_position - bot.global_position
	chat_yaw = atan2(to.x, to.z)
	chat_partner = partner
	chat_timer = seconds


## Face someone briefly (reaction to the player walking by).
func glance(bot: Node3D, target: Node3D, seconds: float) -> void:
	var to := target.global_position - bot.global_position
	_talk_yaw = atan2(to.x, to.z)
	_talk_timer = seconds
