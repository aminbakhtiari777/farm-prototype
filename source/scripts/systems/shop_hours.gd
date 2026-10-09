class_name ShopHours
extends RefCounted
## v5b opening hours ("shop_hours" module, ShopHoursStyle). Ids are building
## ids (carpenter, cafe, supermarket...), "grocery", "market" (all stalls) or
## "stall:<id>". Counters refuse service while closed.


static func style() -> ShopHoursStyle:
	return Modules.style("shop_hours") as ShopHoursStyle


static func _key(id: String) -> String:
	if id.begins_with("stall:"):
		return "market"
	return id


static func hours_of(id: String) -> Array:
	var st := style()
	if st == null:
		return [0.0, 24.0]
	var k := _key(id)
	if k in st.always_open:
		return [0.0, 24.0]
	if st.hours.has(id):
		return st.hours[id]
	if st.hours.has(k):
		return st.hours[k]
	return st.default_hours


static func is_open(id: String, h: float = -1.0) -> bool:
	if h < 0.0:
		h = TimeManager.hours_float()
	var hr: Array = hours_of(id)
	var a := float(hr[0])
	var b := float(hr[1])
	if b - a >= 24.0 or (a == 0.0 and b >= 24.0):
		return true
	if a <= b:
		return h >= a and h < b
	return h >= a or h < b


static func opens_at(id: String) -> float:
	return float(hours_of(id)[0])


static func closes_at(id: String) -> float:
	return float(hours_of(id)[1])


## "Open until 17:00" / "Closed - opens 08:00" (current language).
static func status_text(id: String) -> String:
	var hr: Array = hours_of(id)
	if float(hr[1]) - float(hr[0]) >= 24.0:
		return "شبانه‌روزی باز است" if Lang.is_fa() else "Open 24 hours"
	if is_open(id):
		return ("باز است تا %s" if Lang.is_fa() else "Open until %s") % Lang.hour_text(float(hr[1]))
	return ("بسته است - ساعت %s باز می‌شود" if Lang.is_fa() else "Closed - opens at %s") % Lang.hour_text(float(hr[0]))


## Toast when a closed counter is used.
static func closed_message(id: String, title: String) -> String:
	if Lang.is_fa():
		return "%s بسته است. ساعت کاری: %s تا %s" % [title, Lang.hour_text(opens_at(id)), Lang.hour_text(closes_at(id))]
	return "%s is closed. Hours: %s - %s" % [title, Lang.hour_text(opens_at(id)), Lang.hour_text(closes_at(id))]
