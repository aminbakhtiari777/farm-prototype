extends Node
## v7b town-life state (autoload "TownLife"): everything the v7b modules need
## to remember across saves (SaveGame "town_life").
##   cars       - car key -> {"fuel": 0..100, "condition": 0..100, "upgrades": [ids], "auto": bool}
##   papers     - newspaper issues [{"day", "items": [{"en", "fa"}], "weather"}], newest last
##   paper_day  - the day of the last paper you bought (-1 = none)
##   cafe       - {"drinks", "strong_today", "strong_day", "fights", "breakups", "dui"}
##   tipsy      - seconds of tipsiness left
##   rides      - {"delivered", "earned", "tips"}
##   camps      - {"trips", "spot": "" or id (camp currently set up), "nights"}
##   chat_log   - [{"day", "h", "who", "en", "fa"}] what people said (newest last)
##   trades     - {"player": n, "npc": n, "earned": n}
##   events     - day -> {kind: count} small counters the newspaper reads (fights, rides, camps, trades)

signal changed(kind: String)

var cars: Dictionary = {}
var papers: Array = []
var paper_day: int = -1
var cafe: Dictionary = {}
var tipsy: float = 0.0
var rides: Dictionary = {}
var camps: Dictionary = {}
var chat_log: Array = []
var trades: Dictionary = {}
var events: Dictionary = {}
var show_log: bool = false


func _ready() -> void:
	_register_inputs()
	reset()


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


## v7b input actions (registered at runtime like v6b / v7a).
func _register_inputs() -> void:
	for pair in [[&"headlights", KEY_H], [&"gear_mode", KEY_3], [&"gear_up", KEY_SHIFT], [&"gear_down", KEY_CTRL],
			[&"newspaper", KEY_4], [&"chat_log", KEY_5], [&"camp", KEY_6], [&"haggle", KEY_7]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			InputMap.action_add_event(pair[0], _key(pair[1]))


func reset() -> void:
	cars.clear()
	papers.clear()
	paper_day = -1
	cafe = {"drinks": 0, "strong_today": 0, "strong_day": -1, "fights": 0, "breakups": 0, "dui": 0}
	tipsy = 0.0
	rides = {"delivered": 0, "earned": 0, "tips": 0}
	camps = {"trips": 0, "spot": "", "nights": 0}
	chat_log.clear()
	trades = {"player": 0, "npc": 0, "earned": 0}
	events.clear()
	changed.emit("all")


# ------------------------------------------------------------------ cars
func car(key: String) -> Dictionary:
	if not cars.has(key):
		var ds := Modules.style("driving") as DrivingStyle
		cars[key] = {"fuel": 100.0, "condition": 100.0, "upgrades": [], "auto": ds.auto_default if ds else true}
	return cars[key]


func car_mult(key: String, field: String) -> float:
	var ms := Modules.style("mechanic") as MechanicStyle
	var m := 1.0
	if ms == null:
		return m
	var ups: Array = car(key).get("upgrades", [])
	for u: Dictionary in ms.upgrades:
		if str(u.get("id", "")) in ups:
			m *= float(u.get(field, 1.0))
	return m


# ------------------------------------------------------------------ events
func count_event(kind: String, n: int = 1) -> void:
	var d := str(TimeManager.day)
	if not events.has(d):
		events[d] = {}
	var e: Dictionary = events[d]
	e[kind] = int(e.get(kind, 0)) + n
	# Keep ~10 days.
	for k in events.keys():
		if int(k) < TimeManager.day - 10:
			events.erase(k)
	changed.emit("events")


func events_on(day: int) -> Dictionary:
	return events.get(str(day), {})


func log_line(who: String, en: String, fa: String) -> void:
	var cs := Modules.style("chatter") as ChatterStyle
	chat_log.append({"day": TimeManager.day, "h": snappedf(TimeManager.hours_float(), 0.01), "who": who, "en": en, "fa": fa})
	var cap := cs.log_size if cs else 40
	while chat_log.size() > cap:
		chat_log.pop_front()
	changed.emit("chat")


func strong_today() -> int:
	if int(cafe.get("strong_day", -1)) != TimeManager.day:
		return 0
	return int(cafe.get("strong_today", 0))


func to_save() -> Dictionary:
	return {"cars": cars.duplicate(true), "papers": papers.duplicate(true), "paper_day": paper_day, "cafe": cafe.duplicate(true),
		"tipsy": tipsy, "rides": rides.duplicate(true), "camps": camps.duplicate(true), "chat_log": chat_log.duplicate(true),
		"trades": trades.duplicate(true), "events": events.duplicate(true), "show_log": show_log}


func from_save(d: Dictionary) -> void:
	cars = (d.get("cars", {}) as Dictionary).duplicate(true)
	papers = (d.get("papers", []) as Array).duplicate(true)
	paper_day = int(d.get("paper_day", -1))
	cafe.merge((d.get("cafe", {}) as Dictionary).duplicate(true), true)
	tipsy = float(d.get("tipsy", 0.0))
	rides.merge((d.get("rides", {}) as Dictionary).duplicate(true), true)
	camps.merge((d.get("camps", {}) as Dictionary).duplicate(true), true)
	chat_log = (d.get("chat_log", []) as Array).duplicate(true)
	trades.merge((d.get("trades", {}) as Dictionary).duplicate(true), true)
	events = (d.get("events", {}) as Dictionary).duplicate(true)
	show_log = bool(d.get("show_log", show_log))
	changed.emit("all")
