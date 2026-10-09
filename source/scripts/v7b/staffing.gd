class_name Staffing
extends Node
## v7b posts that are never left empty (cafe bartender + DJ, mechanic).
## Each post has preferred residents; during opening hours the first one who
## is available takes the post (walks there and stays). If they are away -
## ill, being played by you (v7a possession), busy in an argument or an
## emergency, or missing - another adult resident fills in (a stand-in, who
## says so). This is the v7a role takeover idea applied to the town's jobs.

signal post_changed(role: String)

var posts: Dictionary = {}   ## role -> {preferred, spot, face, hours, holder, standin, for}
var auto: bool = true        ## false = only tick() moves people (tests)
var takeovers: int = 0
var _t: float = 3.0


func add_post(role: String, preferred: Array, spot: Vector3, face: Vector3, hours: Vector2) -> void:
	release(role)
	posts[role] = {"preferred": preferred, "spot": spot, "face": face, "hours": hours, "holder": null, "standin": false, "for": ""}


func remove_post(role: String) -> void:
	release(role)
	posts.erase(role)


static func open_at(hours: Vector2, h: float) -> bool:
	if hours.y > 24.0 or hours.y < hours.x:
		return h >= hours.x or h < fmod(hours.y, 24.0)
	return h >= hours.x and h < hours.y


func is_open(role: String) -> bool:
	var p: Dictionary = posts.get(role, {})
	return not p.is_empty() and open_at(p["hours"], TimeManager.hours_float())


func holder(role: String) -> TownspersonBot:
	var p: Dictionary = posts.get(role, {})
	var b: Variant = p.get("holder")
	return b as TownspersonBot if b != null and is_instance_valid(b) else null


func is_standin(role: String) -> bool:
	return bool((posts.get(role, {}) as Dictionary).get("standin", false))


## Why a resident cannot work right now ("" = available).
func unavailable(b: TownspersonBot, role: String) -> String:
	if b == null or not is_instance_valid(b) or b.resident.is_empty():
		return "missing"
	if int(b.resident.get("age", 0)) < 16:
		return "child"
	if b.controller is Possession.PossessController:
		return "possessed"
	if Needs.npc_is_ill(b):
		return "ill"
	var sc := b.controller as V7aKit.ScriptController
	if sc and sc.tag != "post:" + role:
		return "busy"
	if not (b.controller is ScheduleController) and sc == null:
		return "busy"
	for r in posts:
		if r != role and holder(r) == b:
			return "other_post"
	return ""


func _pick(role: String) -> Array:
	var p: Dictionary = posts[role]
	for nm in p["preferred"]:
		var b := V7aKit.bot_named(get_tree(), str(nm))
		if b and unavailable(b, role) == "":
			return [b, false, ""]
	var first := str((p["preferred"] as Array)[0]) if not (p["preferred"] as Array).is_empty() else ""
	# Stand-in: the nearest free adult.
	var best: TownspersonBot = null
	var bd := INF
	for b in V7aKit.bots(get_tree()):
		if Population.full_name(b.resident) in p["preferred"] or unavailable(b, role) != "" or int(b.resident.get("age", 0)) < 18:
			continue
		var d := b.global_position.distance_to(p["spot"])
		if d < bd:
			bd = d
			best = b
	return [best, true, first]


func assign(role: String) -> TownspersonBot:
	var p: Dictionary = posts.get(role, {})
	if p.is_empty():
		return null
	var pick := _pick(role)
	var b := pick[0] as TownspersonBot
	if b == null:
		return null
	if holder(role) == b:
		return b
	release(role)
	var sc := V7aKit.ScriptController.new()
	sc.original = b.controller
	sc.target = p["spot"]
	sc.face_to = p["face"]
	sc.tag = "post:" + role
	sc.speed = 1.6
	b.set_controller(sc)
	if b.global_position.distance_to(p["spot"]) > 20.0 or b.hidden_inside:
		b.global_position = p["spot"] + Vector3(0, 0.1, 0)
	p["holder"] = b
	p["standin"] = bool(pick[1])
	p["for"] = str(pick[2])
	if p["standin"]:
		takeovers += 1
	post_changed.emit(role)
	return b


func release_all() -> void:
	for role in posts.keys():
		release(role)


func release(role: String) -> void:
	var p: Dictionary = posts.get(role, {})
	if p.is_empty():
		return
	var b := holder(role)
	if b:
		var sc := b.controller as V7aKit.ScriptController
		if sc and sc.tag == "post:" + role:
			b.set_controller(V7bKit.original_of(sc))
			if b.controller is ScheduleController:
				b.snap_to_schedule()
	p["holder"] = null
	p["standin"] = false
	p["for"] = ""
	post_changed.emit(role)


## Checks every post: open -> someone available holds it; closed -> released.
func tick() -> void:
	# Someone handed back from possession while a stand-in holds their post: back to their day.
	for b in V7aKit.bots(get_tree()):
		var sc := b.controller as V7aKit.ScriptController
		if sc and sc.tag.begins_with("post:") and holder(sc.tag.trim_prefix("post:")) != b:
			b.set_controller(V7bKit.original_of(sc))
	for role in posts.keys():
		var p: Dictionary = posts[role]
		if not is_open(role):
			if holder(role):
				release(role)
			continue
		var h := holder(role)
		if h == null or unavailable(h, role) != "":
			assign(role)
		else:
			# A (more) preferred worker came back: hand the post back.
			var pref: Array = p["preferred"]
			var hi := pref.find(Population.full_name(h.resident))
			var upto := pref.size() if bool(p["standin"]) or hi < 0 else hi
			for i in upto:
				var b := V7aKit.bot_named(get_tree(), str(pref[i]))
				if b and b != h and unavailable(b, role) == "":
					release(role)
					assign(role)
					break


func _process(delta: float) -> void:
	if not auto:
		return
	_t -= delta
	if _t <= 0.0:
		_t = 2.0
		tick()
