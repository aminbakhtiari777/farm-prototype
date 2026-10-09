class_name SignText
extends RefCounted
## v6b polish: building signs, address plaques and street-name signposts in
## the current language (Persian by default). Business names come from the
## dialogue module's places, family names from its names table; streets have
## their own table here. Re-applied live when the language changes.

const STREETS_FA := {
	"Main St": "خیابان اصلی", "Oak Ave": "بلوار بلوط", "Maple St": "خیابان افرا", "Pine Ln": "کوچه‌ی کاج",
	"Harbor Rd": "جاده‌ی بندر", "Farm Rd": "جاده‌ی مزرعه", "Town Sq": "میدان شهر", "Market Ln": "کوچه‌ی بازار",
	"University Walk": "راه دانشگاه", "Beach": "ساحل", "Lookout Trail": "راه دیدگاه", "Pond Path": "راه برکه",
	"Farm": "مزرعه", "University": "دانشگاه", "Market": "بازار", "Town ->": "شهر ←", "Beach Path": "راه ساحل",
}

const SIGNS_FA := {
	"Your Farmhouse": "خانه‌ی مزرعه‌ی تو", "General Store": "فروشگاه", "Cafe": "کافه",
	"Municipality - City Hall": "شهرداری", "Post Office": "اداره‌ی پست", "Hospital": "بیمارستان",
	"Supermarket": "سوپرمارکت", "Police Station": "کلانتری", "Blacksmith": "آهنگری", "Carpenter": "نجاری",
	"Church": "کلیسا", "Clothing": "پوشاک", "Electrical Supplies": "لوازم برقی", "Electricity Office": "اداره‌ی برق",
	"Fruit Shop": "میوه‌فروشی", "Gym": "باشگاه ورزشی", "Hypermarket": "هایپرمارکت", "Jeweller": "جواهرفروشی",
	"Mosque": "مسجد", "School": "مدرسه", "Stonemason": "سنگ‌تراشی", "Tool Shop": "ابزارفروشی",
	"University": "دانشگاه", "Water Office": "اداره‌ی آب", "Workshop": "کارگاه",
	"Fire Station": "ایستگاه آتش‌نشانی",
}


static func _names_fa() -> Dictionary:
	var st := Dialogue.style()
	return st.names_fa if st else {}


static func sign_of(en: String) -> String:
	if not Lang.is_fa() or en == "":
		return en
	if SIGNS_FA.has(en):
		return SIGNS_FA[en]
	if en.begins_with("The ") and en.ends_with(" Family"):
		var sur := en.substr(4, en.length() - 11)
		return "خانواده‌ی " + str(_names_fa().get(sur, sur))
	if en.ends_with("'s House"):
		var who := en.substr(0, en.length() - 8)
		return "خانه‌ی " + str(_names_fa().get(who, who))
	return Lang.t(en)


## "12 Maple St" -> "خیابان افرا، پلاک ۱۲".
static func address(en: String) -> String:
	if not Lang.is_fa() or en == "":
		return en
	var sp := en.find(" ")
	if sp <= 0:
		return street(en)
	var num := en.substr(0, sp)
	var rest := en.substr(sp + 1)
	if not num[0].is_valid_int():
		return street(en)
	return "%s، پلاک %s" % [street(rest), Lang.digits(num)]


static func street(en: String) -> String:
	if not Lang.is_fa():
		return en
	return str(STREETS_FA.get(en, en))


## Re-labels every sign in the scene (language switch).
static func refresh(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b == null:
			continue
		if is_instance_valid(b.sign_label):
			b.sign_label.text = sign_of(b.sign_text)
		if is_instance_valid(b.address_label):
			b.address_label.text = address(b.address)
			b.fit_address()
	for n in tree.get_nodes_in_group(&"street_signs"):
		var l := n as Label3D
		if l and l.has_meta(&"en"):
			l.text = street(str(l.get_meta(&"en")))
