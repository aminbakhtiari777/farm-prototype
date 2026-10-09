class_name NpcSocial
extends Node
## v4 NPC social life (module type "npc_social", SocialStyle):
##  - randomised walking routes (detours via public spots + wider free-time strolls),
##  - NPC <-> NPC chats when two idle townspeople meet (speech bubbles, they
##    face each other; the partner answers half-way through),
##  - reactions to the player: they turn, greet the farmer by name and wave
##    when the player walks up (cooldown per person).
## Swappable live: "chatty" (default) / "quiet".

signal chat_started(a: Node3D, b: Node3D)
signal reacted(bot: Node3D)

const TICK := 0.5
const GREET_COOLDOWN := 45.0

var chats_started := 0
var reactions := 0
var _timer := 0.0
var _rng := RandomNumberGenerator.new()
var _greeted_at: Dictionary = {}  ## bot -> time (s)
var _pending_replies: Array = []  ## [bot, text, time]


func _ready() -> void:
	add_to_group("npc_social")
	_rng.seed = 2026
	Modules.on_swap("npc_social", self, func(_m: AssetModule) -> void: apply_style())
	apply_style.call_deferred()


func style() -> SocialStyle:
	return Modules.style("npc_social") as SocialStyle


func bots() -> Array:
	return get_tree().get_nodes_in_group(&"townspeople")


func apply_style() -> void:
	var st := style()
	for b in bots():
		var sc := (b as TownspersonBot).controller as ScheduleController if b is TownspersonBot else null
		if sc == null:
			continue
		sc.stroll_radius = st.wander_radius if st else 0.0
		sc.detour_chance = 0.5 if st and st.chat_chance > 0.3 else 0.15


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0


func _physics_process(delta: float) -> void:
	var now := _now()
	for i in range(_pending_replies.size() - 1, -1, -1):
		var r: Array = _pending_replies[i]
		if now >= float(r[2]):
			var b := r[0] as TownspersonBot
			if is_instance_valid(b) and not b.hidden_inside:
				b.say(str(r[1]), 3.5)
			_pending_replies.remove_at(i)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = TICK
	var st := style()
	if st == null:
		return
	_try_chats(st)
	_react_to_player(st)


func _controller(b: Node) -> ScheduleController:
	var bot := b as TownspersonBot
	if bot == null or bot.hidden_inside or bot.is_far_from_player():
		return null
	return bot.controller as ScheduleController


func _try_chats(st: SocialStyle) -> void:
	var list := bots()
	for i in list.size():
		var sa := _controller(list[i])
		if sa == null or not sa.can_chat():
			continue
		for j in range(i + 1, list.size()):
			var sb := _controller(list[j])
			if sb == null or not sb.can_chat():
				continue
			var a := list[i] as TownspersonBot
			var b := list[j] as TownspersonBot
			if a.global_position.distance_to(b.global_position) > st.chat_distance:
				continue
			if _rng.randf() > st.chat_chance:
				# Not this time: don't re-roll every tick.
				sa.social_cooldown = 10.0
				sb.social_cooldown = 10.0
				continue
			start_chat(a, b)
			break


## Starts a chat between two bots (public for tests and the --shots tool).
func start_chat(a: TownspersonBot, b: TownspersonBot) -> bool:
	var st := style()
	var sa := a.controller as ScheduleController
	var sb := b.controller as ScheduleController
	if st == null or sa == null or sb == null:
		return false
	var secs := maxf(st.chat_seconds, 2.0)
	sa.start_chat(b, a, secs)
	sb.start_chat(a, b, secs)
	var line := st.lines[_rng.randi() % st.lines.size()] if st.lines.size() > 0 else "Hello!"
	var reply := st.replies[_rng.randi() % st.replies.size()] if st.replies.size() > 0 else "Hi!"
	# v5b: Persian / English lines from the dialogue module.
	if Dialogue.style() != null:
		line = Dialogue.chat_line()
		reply = Dialogue.chat_reply()
	a.say(line, secs * 0.5)
	_pending_replies.append([b, reply, _now() + secs * 0.45])
	chats_started += 1
	chat_started.emit(a, b)
	return true


func _react_to_player(st: SocialStyle) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or st.greet_distance <= 0.0:
		return
	var now := _now()
	for b in bots():
		var sc := _controller(b)
		var bot := b as TownspersonBot
		if sc == null or sc.chat_timer > 0.0:
			continue
		if bot.global_position.distance_to(player.global_position) > st.greet_distance:
			continue
		if now - float(_greeted_at.get(bot, -1000.0)) < GREET_COOLDOWN:
			continue
		react(bot, player)


## The bot turns to the player and greets them (speech bubble).
func react(bot: TownspersonBot, player: Node3D) -> void:
	var st := style()
	var sc := bot.controller as ScheduleController
	if sc == null:
		return
	_greeted_at[bot] = _now()
	sc.glance(bot, player, 2.5)
	var name_s := str(Settings.get_value("player_name"))
	var line := _pick_greeting(st.greetings if st else PackedStringArray())
	if name_s != "" and _rng.randf() < 0.5:
		line = "Hi %s!" % name_s
	# v5b: time-of-day greeting in Persian / English (dialogue module).
	if Dialogue.style() != null:
		line = Dialogue.player_greeting() if name_s != "" and _rng.randf() < 0.4 else Dialogue.greeting()
	bot.say(line, 2.5)
	reactions += 1
	reacted.emit(bot)


## Picks a greeting that fits the clock: "Morning!" only before noon,
## "Evening!" only from 17:00 (the lines themselves come from the module).
func _pick_greeting(lines: PackedStringArray) -> String:
	var h := TimeManager.hour()
	var ok: Array = []
	for l in lines:
		var low := String(l).to_lower()
		if low.contains("morning") and h >= 12:
			continue
		if low.contains("evening") and (h < 17 and h >= 4):
			continue
		ok.append(l)
	if ok.is_empty():
		return "Hi!"
	return str(ok[_rng.randi() % ok.size()])
