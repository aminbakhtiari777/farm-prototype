class_name Dialogue
extends RefCounted
## v5b talking to townspeople ("dialogue" module, DialogueStyle): a short
## conversation that depends on the person's job (at work / off work), the
## time of day, their family, how well you know them (friendship), their
## health and yours, and whether their shop is open. Persian or English
## (Settings "dialogue_language").

static var _rng := RandomNumberGenerator.new()


static func style() -> DialogueStyle:
	return Modules.style("dialogue") as DialogueStyle


static func part_of_day(h: float = -1.0) -> String:
	if h < 0.0:
		h = TimeManager.hours_float()
	if h >= 4.0 and h < 12.0:
		return "morning"
	if h >= 12.0 and h < 17.0:
		return "noon"
	if h >= 17.0 and h < 21.0:
		return "evening"
	return "night"


static func greeting(h: float = -1.0) -> String:
	var st := style()
	if st == null:
		return "Hi!"
	return Lang.pick(st.greetings.get(part_of_day(h), {}), _rng)


static func chat_line() -> String:
	var st := style()
	return Lang.pick(st.chat_lines, _rng) if st else "Hello!"


static func chat_reply() -> String:
	var st := style()
	return Lang.pick(st.chat_replies, _rng) if st else "Hi!"


static func player_greeting() -> String:
	var st := style()
	var name_s := str(Settings.get_value("player_name"))
	if st == null or name_s == "":
		return greeting()
	# Unicode isolate (FSI..PDI) keeps a Latin name from reordering the Persian sentence.
	if Lang.is_fa() and not Lang.is_rtl_text(name_s):
		name_s = "\u2068" + name_s + "\u2069"
	return Lang.fill(Lang.pick(st.player_greeting, _rng), {"player": name_s})


## Persian / English display name, job and place.
static func name_of(r: Dictionary) -> String:
	var st := style()
	if Lang.is_fa() and st:
		var n := str(r.get("name", ""))
		var s := str(r.get("surname", ""))
		return "%s %s" % [st.names_fa.get(n, n), st.names_fa.get(s, s)]
	return Population.full_name(r)


static func first_name(r: Dictionary) -> String:
	var st := style()
	var n := str(r.get("name", "?"))
	return str(st.names_fa.get(n, n)) if Lang.is_fa() and st else n


static func job_of(r: Dictionary) -> String:
	var st := style()
	var j := str(r.get("job", ""))
	return str(st.jobs_fa.get(j, j)) if Lang.is_fa() and st else j


static func place_of(id: String) -> String:
	var st := style()
	if Lang.is_fa() and st and st.places_fa.has(id):
		return str(st.places_fa[id])
	return Population.place_name(id)


static func job_key(job: String, st: DialogueStyle) -> String:
	var j := job.to_lower()
	# Longest keyword first ("retired teacher" before "teacher").
	var keys: Array = st.job_lines.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for k: String in keys:
		if j.contains(k):
			return k
	return ""


static func is_at_work(bot: Node) -> bool:
	var sc := bot.get("controller") as ScheduleController
	if sc == null:
		return false
	var r: Dictionary = bot.get("resident")
	var work := str(r.get("work", ""))
	var spot := str(sc.current.get("spot", ""))
	return work != "" and spot.ends_with(work)


static func doctor_name() -> String:
	for r: Dictionary in Population.residents():
		if str(r.get("job", "")).to_lower().contains("doctor"):
			return first_name(r)
	return "Leila"


## The conversation lines for a talk (first = greeting, shown in the bubble).
## How `other` relates to `viewer` (both resident dictionaries): the stored
## role is the household role ("father", "wife", "son"...), so parents see
## each other as spouses and children see each other as siblings.
static func relation_key(viewer: Dictionary, other: Dictionary) -> String:
	var adult := ["father", "mother", "husband", "wife"]
	var child := ["son", "daughter"]
	var vr := str(viewer.get("role", ""))
	var o_role := str(other.get("role", ""))
	var male := str(other.get("gender", "")) == "male" or o_role in ["father", "husband", "son"]
	if vr in adult and o_role in adult:
		return "husband" if male else "wife"
	if vr in child and o_role in child:
		return "brother" if male else "sister"
	return o_role


static func relation_text(viewer: Dictionary, other: Dictionary) -> String:
	var st := style()
	var k := relation_key(viewer, other)
	return Lang.pick(st.relations.get(k, {})) if st else k


static func talk_lines(bot: Node) -> PackedStringArray:
	var st := style()
	var out := PackedStringArray()
	if st == null:
		out.append("Hello!")
		return out
	_rng.seed = hash([str(bot.get("display_name")), TimeManager.day, TimeManager.hour(), Friendship.talks])
	var r: Dictionary = bot.get("resident") if bot.get("resident") is Dictionary else {}
	var key := Friendship.key_of(bot)
	var lv := Friendship.level(key)
	# 1. Greeting (by name once you know each other).
	if lv >= 1 and str(Settings.get_value("player_name")) != "":
		out.append(player_greeting())
	else:
		out.append(greeting())
	# v5d: townspeople remember that you were away (away_avatar module).
	var away_line := AwayMemory.line_for(key, str(bot.get("display_name")))
	if away_line != "":
		out.append(away_line)
	# 2. Health first (theirs, then yours), else job / time of day.
	var npc_s := Needs.npc_state(bot)
	var extra: Array[String] = []
	if str(npc_s.get("illness", "")) != "":
		extra.append(Lang.pick(st.ill_self, _rng))
	if Needs.is_ill():
		extra.append(Lang.fill(Lang.pick(st.ill_player, _rng), {"doctor": doctor_name()}))
	elif Needs.is_hungry():
		extra.append(Lang.pick(st.hungry_player, _rng))
	elif Needs.is_tired():
		extra.append(Lang.pick(st.tired_player, _rng))
	var work := str(r.get("work", ""))
	if work != "" and not ShopHours.is_open(work) and Shops.shop(work).size() > 0 and part_of_day() != "night":
		extra.append(Lang.fill(Lang.pick(st.closed_lines, _rng), {"hour": Lang.hour_text(ShopHours.opens_at(work))}))
	elif part_of_day() == "night":
		extra.append(Lang.pick(st.night_lines, _rng))
	else:
		var jk := job_key(str(r.get("job", "")), st)
		var table: Dictionary = st.job_lines.get(jk, st.generic_lines) if jk != "" else st.generic_lines
		extra.append(Lang.pick(table.get("work" if is_at_work(bot) else "off", {}), _rng))
	# 3. Family or friendship.
	var fam: Array = Population.family_of(r) if not r.is_empty() else []
	if not fam.is_empty() and _rng.randf() < 0.6:
		var m: Dictionary = fam[_rng.randi() % fam.size()]
		var rel := Lang.pick(st.relations.get(relation_key(r, m), {}), _rng)
		if rel != "":
			extra.append(Lang.fill(Lang.pick(st.family_lines, _rng), {"name": first_name(m), "rel": rel}))
	# v7a: memories of the player / their life story (backstories module).
	var story := Backstories.talk_line(bot)
	if story != "":
		extra.insert(mini(1, extra.size()), story)
	if st.friendship_lines.size() > 0:
		extra.append(Lang.pick(st.friendship_lines[clampi(lv, 0, st.friendship_lines.size() - 1)], _rng))
	for e in extra:
		if out.size() >= st.lines_per_talk:
			break
		if e != "":
			out.append(e)
	return out
