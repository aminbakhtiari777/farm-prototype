extends Node
## v7b.1 traffic state (autoload "TrafficState", saved under "traffic"):
## the farmer's driving licence (none -> passed -> confiscated -> back after
## the wait + a re-test), offences per driver, impounded cars, cars bought at
## the dealership, quiz / camera / bus statistics and traffic news for the
## daily paper. Residents are licensed unless theirs was taken.

signal changed(kind: String)

## Farmer's licence: "none", "valid", "confiscated".
var license: String = "none"
var license_day: int = -1
var confiscated_until: int = -1
var retest_passed: bool = false
## Offence points per driver ("player" or a resident's full name).
var offences: Dictionary = {}
## Residents whose licence was taken: full name -> day it comes back.
var resident_bans: Dictionary = {}
## car key -> {day, fee, pos: [x, y, z], yaw}
var impounded: Dictionary = {}
## Cars bought at the dealership: [{key, id, model, color: [r, g, b], price, day}]
var owned: Array = []
var stats: Dictionary = {}
## Traffic news since the last paper: [{day, en, fa}]
var news: Array = []
var unlicensed_day: int = -1


func _ready() -> void:
	reset()


func reset() -> void:
	license = "none"
	license_day = -1
	confiscated_until = -1
	retest_passed = false
	offences.clear()
	resident_bans.clear()
	impounded.clear()
	owned.clear()
	news.clear()
	unlicensed_day = -1
	stats = {"red_runs": 0, "stop_runs": 0, "speeding": 0, "unlicensed": 0, "flashes": 0, "quiz_taken": 0, "quiz_passed": 0,
		"bus_rides": 0, "bus_fares": 0, "cars_bought": 0, "impounds": 0, "releases": 0, "npc_stops": 0}
	changed.emit("all")


func stat(k: String, n: int = 1) -> void:
	stats[k] = int(stats.get(k, 0)) + n
	changed.emit("stats")


## Can this driver legally drive right now?
func licensed(who: String = "player") -> bool:
	if who == "player":
		_check_return()
		return license == "valid"
	var back := int(resident_bans.get(who, -1))
	if back >= 0 and TimeManager.day < back:
		return false
	var ls := Modules.style("driving_license") as LicenseStyle
	return ls == null or ls.residents_licensed


func _check_return() -> void:
	if license == "confiscated" and confiscated_until >= 0 and TimeManager.day >= confiscated_until and retest_passed:
		license = "valid"
		license_day = TimeManager.day
		changed.emit("license")


## Days until the confiscation ends (0 = may retake the test).
func days_left() -> int:
	return maxi(confiscated_until - TimeManager.day, 0) if license == "confiscated" else 0


func can_take_test() -> bool:
	return license == "none" or (license == "confiscated" and days_left() == 0 and not retest_passed)


func grant(by_test: bool = true) -> void:
	if license == "confiscated":
		retest_passed = true
		_check_return()
	else:
		license = "valid"
		license_day = TimeManager.day
	if by_test:
		stat("quiz_passed")
	changed.emit("license")


func confiscate(who: String, days: int) -> void:
	if who == "player":
		license = "confiscated"
		confiscated_until = TimeManager.day + days
		retest_passed = false
	else:
		resident_bans[who] = TimeManager.day + days
	offences[who] = 0
	changed.emit("license")


func add_offence(who: String) -> int:
	offences[who] = int(offences.get(who, 0)) + 1
	changed.emit("offences")
	return int(offences[who])


func offence_count(who: String = "player") -> int:
	return int(offences.get(who, 0))


func add_news(en: String, fa: String) -> void:
	news.append({"day": TimeManager.day, "en": en, "fa": fa})
	while news.size() > 12:
		news.pop_front()
	changed.emit("news")


## Traffic items for the newspaper (since `since` day), at most `cap`.
func news_items(since: int, cap: int = 2) -> Array:
	var out: Array = []
	for n: Dictionary in news:
		if int(n.get("day", 0)) >= since and out.size() < cap:
			out.append({"kind": "traffic", "en": str(n.get("en", "")), "fa": str(n.get("fa", ""))})
	return out


func is_impounded(key: String) -> bool:
	return impounded.has(key)


func owns(key: String) -> bool:
	for o: Dictionary in owned:
		if str(o.get("key", "")) == key:
			return true
	return false


func to_save() -> Dictionary:
	return {"license": license, "license_day": license_day, "confiscated_until": confiscated_until, "retest_passed": retest_passed,
		"offences": offences.duplicate(true), "resident_bans": resident_bans.duplicate(true), "impounded": impounded.duplicate(true),
		"owned": owned.duplicate(true), "stats": stats.duplicate(true), "news": news.duplicate(true), "unlicensed_day": unlicensed_day}


func from_save(d: Dictionary) -> void:
	license = str(d.get("license", "none"))
	license_day = int(d.get("license_day", -1))
	confiscated_until = int(d.get("confiscated_until", -1))
	retest_passed = bool(d.get("retest_passed", false))
	offences = (d.get("offences", {}) as Dictionary).duplicate(true)
	resident_bans = (d.get("resident_bans", {}) as Dictionary).duplicate(true)
	impounded = (d.get("impounded", {}) as Dictionary).duplicate(true)
	owned = (d.get("owned", []) as Array).duplicate(true)
	stats.merge((d.get("stats", {}) as Dictionary).duplicate(true), true)
	news = (d.get("news", []) as Array).duplicate(true)
	unlicensed_day = int(d.get("unlicensed_day", -1))
	changed.emit("all")
