class_name Families
extends RefCounted
## v7b.1 "families" module: what kind of household lives in each home (large
## family with four children, family, newlyweds, young couple, couple whose
## children have grown up, older / elderly couple, single) and what every
## member does all day (job + workplace, school / kindergarten, university,
## retired). Shown on the name card and in the J town directory, in Persian
## (default) or English. The members themselves come from the population module.

const ROLE_FA := {"father": "پدر", "mother": "مادر", "son": "پسر", "daughter": "دختر", "husband": "شوهر",
	"wife": "همسر", "single": "مجرد", "grandmother": "مادربزرگ", "grandfather": "پدربزرگ"}
const ROLE_EN := {"father": "father", "mother": "mother", "son": "son", "daughter": "daughter", "husband": "husband",
	"wife": "wife", "single": "single", "grandmother": "grandmother", "grandfather": "grandfather"}


static func style() -> FamiliesStyle:
	return Modules.style("families") as FamiliesStyle


static func household(home: String) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	for h: Dictionary in st.households:
		if str(h.get("home", "")) == home:
			return h
	return {}


## Kind of a household, computed from its members when the module has no entry.
static func kind_of(home: String) -> String:
	var h := household(home)
	if not h.is_empty():
		return str(h.get("kind", "family"))
	var members: Array = Population.households().get(home, [])
	var kids := 0
	var oldest := 0
	for r: Dictionary in members:
		if str(r.get("role", "")) in ["son", "daughter"]:
			kids += 1
		oldest = maxi(oldest, int(r.get("age", 0)))
	if members.size() == 1:
		return "single"
	if kids >= 4:
		return "large_family"
	if kids > 0:
		return "family"
	return "elderly_couple" if oldest >= 65 else "couple_no_kids"


static func kind_text(home: String) -> String:
	var h := household(home)
	if not h.is_empty():
		return str(h.get("kind_fa" if Lang.is_fa() else "kind_en", h.get("kind", "")))
	var k := kind_of(home)
	return Lang.tt({"single": "مجرد", "large_family": "خانواده‌ی پرجمعیت", "family": "خانواده", "elderly_couple": "زوج سالمند",
		"couple_no_kids": "زوج بدون فرزند"}.get(k, k), k.replace("_", " "))


static func role_text(r: Dictionary) -> String:
	var role := str(r.get("role", ""))
	return str((ROLE_FA if Lang.is_fa() else ROLE_EN).get(role, role))


## What the resident does all day: "Barista at the Cafe", "pupil at School", "retired".
static func status_of(r: Dictionary) -> String:
	var job := str(r.get("job", ""))
	var work := str(r.get("work", ""))
	if work == "":
		return Dialogue.job_of(r) if job != "" else Lang.tt("بازنشسته", "retired")
	if Lang.is_fa():
		return "%s در %s" % [Dialogue.job_of(r), Dialogue.place_of(work)]
	return Population.job_text(r)


## "who is out of work" check used by the smoke test: adults (18..64) with no workplace.
static func adults_without_work() -> Array:
	var out: Array = []
	for r: Dictionary in Population.residents():
		var age := int(r.get("age", 0))
		if age >= 18 and age < 65 and str(r.get("work", "")) == "":
			out.append(Population.full_name(r))
	return out


## One line for the name card.
static func card_line(r: Dictionary) -> String:
	var st := style()
	if st == null or not st.enabled or r.is_empty():
		return ""
	var home := str(r.get("home", ""))
	var b := TownLayout.building(home)
	var addr := SignText.address(str(b.get("address", ""))) if not b.is_empty() else ""
	var line := Lang.tt("خانواده: %s · %s" % [kind_text(home), role_text(r)], "Household: %s · %s" % [kind_text(home), role_text(r)])
	if addr != "":
		line += " · " + addr
	return line


static func surname_text(r: Dictionary) -> String:
	var d := Dialogue.style()
	var s := str(r.get("surname", ""))
	return str(d.names_fa.get(s, s)) if Lang.is_fa() and d else s


## J directory content (returns false when the module is off -> classic list).
static func fill_directory(list: VBoxContainer) -> bool:
	var st := style()
	if st == null or not st.enabled:
		return false
	var fa := Lang.is_fa()
	var homes := Population.households()
	var kids := 0
	var workers := 0
	for r: Dictionary in Population.residents():
		if int(r.get("age", 0)) < 18:
			kids += 1
		elif str(r.get("work", "")) != "":
			workers += 1
	var sum := UIKit.label(list, Lang.tt("%s ساکن در %s خانه · %s شاغل · %s کودک و نوجوان" % [Lang.digits(str(Population.residents().size())), Lang.digits(str(homes.size())), Lang.digits(str(workers)), Lang.digits(str(kids))],
			"%d residents in %d homes · %d working · %d children" % [Population.residents().size(), homes.size(), workers, kids]), 14, Color(0.4, 0.3, 0.2))
	sum.name = "Summary"
	if fa:
		sum.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	for h: String in homes:
		var members: Array = homes[h]
		var b := TownLayout.building(h)
		var addr := SignText.address(str(b.get("address", h)))
		var head := UIKit.label(list, Lang.tt("خانواده‌ی %s — %s — %s" % [surname_text(members[0]), addr, kind_text(h)],
				"%s family — %s — %s" % [surname_text(members[0]), addr, kind_text(h)]), 18, UIKit.INK)
		head.name = "Home_" + h
		if fa:
			head.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		for r: Dictionary in members:
			var age := int(r.get("age", 0))
			var line := UIKit.label(list, Lang.tt("    %s (%s ساله)، %s — %s" % [Dialogue.first_name(r), Lang.digits(str(age)), role_text(r), status_of(r)],
					"    %s (%d), %s — %s" % [Dialogue.first_name(r), age, role_text(r), status_of(r)]), 14, Color(0.3, 0.22, 0.14))
			if fa:
				line.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return true


## Counts of household kinds (smoke test).
static func kind_counts() -> Dictionary:
	var out := {}
	for h: String in Population.households():
		var k := kind_of(h)
		out[k] = int(out.get(k, 0)) + 1
	return out
