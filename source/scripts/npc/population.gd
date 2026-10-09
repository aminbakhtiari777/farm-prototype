class_name Population
extends RefCounted
## v5a townsfolk identities from the "population" module (PopulationDef):
## names, ages, jobs, workplaces, homes and family ties. Townspeople spawns
## the bots from this; the People panel (J / City Hall clerk) lists it.


static func def() -> PopulationDef:
	return Modules.style("population") as PopulationDef


static func residents() -> Array:
	var d := def()
	return d.residents if d else []


static func full_name(r: Dictionary) -> String:
	return "%s %s" % [r.get("name", "?"), r.get("surname", "")]


static func place_name(id: String) -> String:
	match id:
		"":
			return "home"
		"pier":
			return "the pier"
	var b := TownLayout.building(id)
	if b.is_empty():
		return id.capitalize()
	var s := str(b.get("sign", ""))
	return s if s != "" else str(b.get("address", id))


static func home_address(r: Dictionary) -> String:
	return str(TownLayout.building(str(r.get("home", ""))).get("address", "?"))


static func family_of(r: Dictionary) -> Array:
	var out: Array = []
	for o in residents():
		if o != r and str(o.get("family", "")) == str(r.get("family", "")) and str(o.get("home", "")) == str(r.get("home", "")):
			out.append(o)
	return out


## "Reza (father), Ali (son)"
static func family_text(r: Dictionary) -> String:
	var parts: PackedStringArray = []
	for o in family_of(r):
		parts.append("%s (%s)" % [o.get("name", "?"), o.get("role", "family")])
	return ", ".join(parts)


static func job_text(r: Dictionary) -> String:
	var job := str(r.get("job", ""))
	var work := str(r.get("work", ""))
	if work == "":
		return job
	return "%s at %s" % [job, place_name(work)]


## One-line identity used by greetings and the People panel.
static func describe(r: Dictionary) -> String:
	var fam := family_text(r)
	return "%s, %d - %s. Lives at %s%s." % [full_name(r), int(r.get("age", 0)), job_text(r), home_address(r),
			(" with " + fam) if fam != "" else ""]


static func households() -> Dictionary:
	var out := {}
	for r in residents():
		var h := str(r.get("home", ""))
		if not out.has(h):
			out[h] = []
		(out[h] as Array).append(r)
	return out


static func by_name(first: String) -> Dictionary:
	for r in residents():
		if str(r.get("name", "")) == first:
			return r
	return {}
