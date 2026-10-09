class_name Backstories
extends RefCounted
## v7a "backstories" module: each resident's spouse / family, job, talents, a
## current problem, a past hardship (gentle) and a hope, plus what they
## remember about the player (WorldMemory npc memories). Used by the NPC card
## (story block) and by Dialogue.talk_lines (one story / memory line a talk).

static var _rng := RandomNumberGenerator.new()


static func style() -> BackstoryStyle:
	return Modules.style("backstories") as BackstoryStyle


static func of(r: Dictionary) -> Dictionary:
	var st := style()
	if st == null or r.is_empty():
		return {}
	return st.people.get(Population.full_name(r), {})


static func _f(d: Dictionary, k: String) -> String:
	return str(d.get(k + ("_fa" if Lang.is_fa() else "_en"), ""))


## "Husband: Reza (postman)" / "همسر: رضا (پستچی)" - or the parents for a child.
static func spouse_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for m: Dictionary in Population.family_of(r):
		var k := Dialogue.relation_key(r, m)
		if k in ["husband", "wife"]:
			parts.append("%s (%s)" % [Dialogue.first_name(m), Dialogue.job_of(m)])
	if parts.is_empty():
		return ""
	return Lang.tt("همسر: ", "Spouse: ") + ", ".join(parts)


## Card block: talents, problem, past, latest memory of you.
static func card_lines(r: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	var d := of(r)
	if d.is_empty():
		return out
	var sp := spouse_text(r)
	if sp != "":
		out.append(sp)
	out.append(Lang.tt("استعداد: ", "Talents: ") + _f(d, "talents"))
	out.append(Lang.tt("گرفتاری: ", "Problem: ") + _f(d, "problem"))
	out.append(Lang.tt("گذشته: ", "Past: ") + _f(d, "past"))
	var mem := memory_line(Population.full_name(r))
	if mem != "":
		out.append(Lang.tt("به یاد دارد: ", "Remembers: ") + mem)
	return out


## The most recent thing this person remembers about the player.
static func memory_line(who: String) -> String:
	var list := WorldMemory.npc_memories(who)
	if list.is_empty():
		return ""
	var m: Dictionary = list[list.size() - 1]
	var ago := TimeManager.day - int(m.get("day", 0))
	if Lang.is_fa():
		var when := "امروز" if ago <= 0 else ("دیروز" if ago == 1 else "%s روز پیش" % Lang.digits(str(ago)))
		return "%s: %s" % [when, str(m.get("fa", ""))]
	var when_en := "today" if ago <= 0 else ("yesterday" if ago == 1 else "%d days ago" % ago)
	return "%s: %s" % [when_en, str(m.get("en", ""))]


## One line for a talk: a memory of you first, else (sometimes) their story.
static func talk_line(bot: Node) -> String:
	var st := style()
	var r: Dictionary = bot.get("resident") if bot.get("resident") is Dictionary else {}
	if st == null or r.is_empty():
		return ""
	var who := Population.full_name(r)
	_rng.seed = hash([who, TimeManager.day, TimeManager.hour(), Friendship.talks])
	var list := WorldMemory.npc_memories(who)
	if not list.is_empty() and st.memory_lines > 0:
		var m: Dictionary = list[list.size() - 1]
		if TimeManager.day - int(m.get("day", 0)) <= 7:
			return Lang.tt("یادم هست: ", "I remember: ") + str(m.get("fa" if Lang.is_fa() else "en", ""))
	var d := of(r)
	if d.is_empty() or _rng.randf() > st.story_chance:
		return ""
	var lv := Friendship.level(Friendship.key_of(bot))
	match _rng.randi() % (3 if lv >= 1 else 2):
		0:
			return Lang.tt("راستش این روزها نگرانم: %s." % _f(d, "problem"), "Honestly, I'm worried lately: %s." % _f(d, "problem"))
		1:
			return Lang.tt("آرزویم این است که %s." % _f(d, "hope"), "My dream is %s." % _f(d, "hope"))
		_:
			return Lang.tt("می‌دانی، %s." % _f(d, "past"), "You know, %s." % _f(d, "past"))


## Records that a resident remembers something the player did.
static func remember(bot_or_name: Variant, kind: String, en: String, fa: String) -> void:
	var who := ""
	if bot_or_name is String:
		who = bot_or_name
	elif bot_or_name is Node:
		who = Friendship.key_of(bot_or_name)
	WorldMemory.npc_remember(who, kind, en, fa)
