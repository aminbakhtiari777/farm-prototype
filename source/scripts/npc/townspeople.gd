class_name Townspeople
extends Node3D
## v5a: spawns one TownspersonBot per resident of the "population" module
## (PopulationDef, up to max_spawned). Every bot has an identity (name, age,
## job, family, home) and a daily routine generated from its job: work at the
## workplace, school / university for pupils and students, prayers at the
## mosque or church, free time around town, evenings with the family at home,
## night asleep at home. Families share a home. Kids are scaled down.

## Free-time places (picked per resident so the town stays lively).
const LEISURE: Array = [["market", "wander"], ["fountain", "sit"], ["beach", "wander"], ["pond", "wander"],
		["lookout", "sit"], ["square", "wander"], ["in:cafe", "wander"], ["beach2", "wander"]]

## Working hours per job keyword: [from, to, activity].
const HOURS: Dictionary = {
	"barista": [7.0, 15.5, "work"], "police": [7.0, 15.0, "work"], "doctor": [8.0, 17.0, "work"],
	"nurse": [7.5, 16.0, "work"], "fisherman": [5.5, 12.0, "fish"], "pupil": [8.0, 14.0, "sit"],
	"student": [9.0, 16.0, "sit"], "imam": [5.5, 13.5, "work"], "priest": [8.0, 16.0, "work"],
	"teacher": [7.5, 15.0, "work"], "professor": [9.0, 16.0, "work"],
}

var bots: Array[TownspersonBot] = []


func _ready() -> void:
	_spawn()
	# Live swap of the population module: respawn everyone.
	Modules.on_swap("population", self, func(_r: Resource) -> void:
		for b in bots:
			b.queue_free()
		bots.clear()
		_spawn.call_deferred())


func _spawn() -> void:
	var d := Population.def()
	var list: Array = Population.residents()
	var cap := d.max_spawned if d else list.size()
	var i := 0
	for r: Dictionary in list:
		if i >= cap:
			break
		var bot := TownspersonBot.new()
		bot.name = "Bot_" + str(r.get("name", "Resident%d" % i))
		bot.display_name = str(r.get("name", "?"))
		bot.home_id = str(r.get("home", ""))
		bot.resident = r
		bot.outfit = outfit_for(r)
		var age := int(r.get("age", 30))
		if d and age < 13:
			bot.body_scale_mult = d.child_scale
		elif d and age < 18:
			bot.body_scale_mult = d.teen_scale
		bot.set_controller(ScheduleController.new(schedule_for(r, i), bot.home_id, r.get("lines", []), 100 + i))
		add_child(bot)
		bot.snap_to_schedule()
		bots.append(bot)
		i += 1


static func outfit_for(r: Dictionary) -> Dictionary:
	# v6b: npc_looks module (distinct faces, hair, build per resident).
	# v7b.1: resident_looks module (skin tones, height / build, hijab, glasses, family resemblance).
	return ResidentLooks.apply(r, NpcLooks.apply(r, outfit_for_base(r)))


static func outfit_for_base(r: Dictionary) -> Dictionary:
	return {"body_type": "female" if str(r.get("gender", "")) == "female" else "male",
		"hair_style": str(r.get("hair", "Hair_SimpleParted")), "hair_color": r.get("hair_color", Color(0.2, 0.15, 0.1)),
		"beard": bool(r.get("beard", false)), "top_style": str(r.get("top", "work_shirt")),
		"shirt_color": r.get("shirt", Color(0.4, 0.4, 0.5)), "pants_color": r.get("pants", Color(0.2, 0.2, 0.25)),
		"skin_tone": int(r.get("skin", 0))}


static func _hours(job: String) -> Array:
	var j := job.to_lower()
	for k: String in HOURS:
		if j.contains(k):
			return HOURS[k]
	return [8.0, 17.0, "work"]


static func _spot_for(id: String, prefix: String = "in:") -> String:
	if id == "":
		return ""
	if TownNav.has_spot(id):
		return id
	if TownNav.has_spot(prefix + id):
		return prefix + id
	if TownNav.has_spot("door:" + id):
		return "door:" + id
	return ""


## Daily routine from the resident's job, age and home (hours, 24 h clock).
static func schedule_for(r: Dictionary, index: int) -> Array:
	var home := str(r.get("home", ""))
	var home_spot := _spot_for(home, "door:")
	var work_spot := _spot_for(str(r.get("work", "")))
	var age := int(r.get("age", 30))
	var out: Array = []
	var leisure: Array = LEISURE[index % LEISURE.size()]
	var leisure2: Array = LEISURE[(index * 3 + 2) % LEISURE.size()]
	if not TownNav.has_spot(str(leisure[0])):
		leisure = ["square", "wander"]
	if not TownNav.has_spot(str(leisure2[0])):
		leisure2 = ["market", "wander"]
	var bedtime := 21.0 if age < 13 else 22.5
	if work_spot == "":
		# Retired: market in the morning, square at noon, a stroll in the afternoon.
		out.append([8.5, 11.5, "market", "wander"])
		out.append([11.5, 14.0, "fountain" if TownNav.has_spot("fountain") else "square", "sit"])
		out.append([14.0, 18.0, str(leisure2[0]), str(leisure2[1])])
	else:
		var h: Array = _hours(str(r.get("job", "")))
		var from := float(h[0])
		var to := float(h[1])
		out.append([from, to, work_spot, str(h[2])])
		# Imam: back to the mosque for the evening prayers after a break.
		if str(r.get("job", "")).to_lower().contains("imam"):
			out.append([to, 16.0, "market", "wander"])
			out.append([16.0, 19.5, work_spot, "work"])
		elif age < 13:
			out.append([to, 18.0, "square" if index % 2 == 0 else "pond", "wander"])
		else:
			out.append([to, minf(to + 2.5, 19.0), str(leisure[0]), str(leisure[1])])
			if to + 2.5 < 19.0:
				out.append([to + 2.5, 19.0, str(leisure2[0]), str(leisure2[1])])
	# Evening with the family in front of the house.
	var last := float(out[out.size() - 1][1])
	if home_spot != "" and last < bedtime:
		out.append([last, bedtime, home_spot, "wander"])
	var entries: Array = []
	for s in out:
		if float(s[1]) > float(s[0]) and TownNav.has_spot(str(s[2])):
			var e := {"from": s[0], "to": s[1], "spot": s[2], "activity": s[3]}
			if str(s[3]) == "wander" and str(s[2]).begins_with("door:"):
				e["radius"] = 2.5
			entries.append(e)
	return _v6a_leisure(entries, r, index)


## v6a: some townspeople train at the gym after work, others sunbathe on the
## sunbathing beach (replacing one afternoon leisure slot each).
static func _v6a_leisure(entries: Array, r: Dictionary, index: int) -> Array:
	var age := int(r.get("age", 30))
	var gs := Modules.style("gym") as GymStyle
	var ss := Modules.style("sunbathing") as SunbathingStyle
	var want := ""
	if gs and gs.npc_every > 0 and index % gs.npc_every == 1 and age >= 15 and age < 70 and TownNav.has_spot("in:gym"):
		want = "workout"
	elif ss and ss.npc_every > 0 and index % ss.npc_every == 3 and age >= 13 and TownNav.has_spot("sun_beach"):
		want = "sunbathe"
	if want == "":
		return entries
	for e in entries:
		var d := e as Dictionary
		if str(d["activity"]) in ["wander", "sit"] and not str(d["spot"]).begins_with("door:") and not str(d["spot"]).begins_with("in:") and float(d["from"]) >= 11.0:
			d["spot"] = "in:gym" if want == "workout" else "sun_beach"
			d["activity"] = want
			d.erase("radius")
			break
	return entries
