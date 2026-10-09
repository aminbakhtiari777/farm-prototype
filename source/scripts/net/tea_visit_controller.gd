class_name TeaVisitController
extends BotController
## v5d: a townsperson walks over to a disconnected player's avatar, greets it
## or brings it tea, then goes back to its routine (the previous controller).
## Also the pattern for network-driven NPCs (see NetNpcController).

var previous: BotController
var target: Node3D
var kind: String = "greet"
var line: String = ""
var phase: String = "walk"
var _t: float = 0.0
var _said: bool = false
var done: bool = false


func _init(prev: BotController, tgt: Node3D, visit_kind: String, text: String) -> void:
	previous = prev
	target = tgt
	kind = visit_kind
	line = text


func tick(bot: Node3D, delta: float) -> Dictionary:
	_t += delta
	if target == null or not is_instance_valid(target) or done:
		_finish(bot)
		return {"move": Vector3.ZERO}
	var to := target.global_position - bot.global_position
	to.y = 0.0
	if phase == "walk":
		if to.length() > 25.0 and _t < 0.1:
			# Far away: arrive from just around the corner instead of crossing town.
			bot.global_position = target.global_position - to.normalized() * 7.0
			bot.global_position.y = Terrain.height_at(bot.global_position.x, bot.global_position.z)
			to = target.global_position - bot.global_position
			to.y = 0.0
		if to.length() > 1.3 and _t < 20.0:
			return {"move": to.normalized() * 1.7}
		phase = "talk"
		_t = 0.0
	if not _said:
		_said = true
		if bot.has_method("say"):
			bot.call("say", line, 4.5)
		if bot.has_method("start_wave"):
			bot.call("start_wave", 1.6)
		if kind == "tea" and target.has_method("serve_tea"):
			target.call("serve_tea")
	if _t > 5.0:
		_finish(bot)
	return {"move": Vector3.ZERO, "face": atan2(to.x, to.z), "pose": &"talk"}


func _finish(bot: Node3D) -> void:
	if done and bot.get("controller") != self:
		return
	done = true
	if bot.has_method("set_controller") and previous:
		bot.call("set_controller", previous)


func on_greeted(bot: Node3D, player: Node3D) -> String:
	return previous.on_greeted(bot, player) if previous else "..."


func describe() -> String:
	return "visiting an away player (%s)" % kind


## NPC takeover groundwork: a bot claimed by a player (server npc_roles) is
## driven by the network instead of its schedule. Stub: it stands still and
## shows who controls it; the claiming player's inputs are a later version.
class NetNpcController extends BotController:
	var owner_name: String = ""
	func _init(who: String) -> void:
		owner_name = who
	func tick(_bot: Node3D, _delta: float) -> Dictionary:
		return {"move": Vector3.ZERO, "pose": &""}
	func on_greeted(_bot: Node3D, _player: Node3D) -> String:
		return Lang.pick({"fa": "الان %s نقش من رو بازی می‌کنه!" % owner_name, "en": "%s is playing my role right now!" % owner_name})
	func describe() -> String:
		return "controlled by player %s" % owner_name
