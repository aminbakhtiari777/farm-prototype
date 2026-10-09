extends Node
## v7a city state (autoload "CityState", module "city_fund"): the municipality
## fund and what the town remembers about damage.
##   fund      - balance; every fine (theft, fire, damages, speeding) goes in
##   ledger    - [{"day", "kind", "en", "fa", "amount"}] (+ income, - spending)
##   projects  - public works: id -> {"state": "planned|building|done", "start", "done_day"}
##   damage    - building id -> {"burn": 0..1, "state": "ok|burning|burned|demolished|rebuilding", "since": day, "cause": who}
## Saved with the game (SaveGame "city"). CityFund (V7aWorld) builds the works.

signal changed(kind: String)

var fund: int = 0
var ledger: Array = []
var projects: Dictionary = {}
var damage: Dictionary = {}
var fines_total: int = 0
var spent_total: int = 0
var fires: int = 0
var outages: int = 0
var quakes: int = 0
var arguments: int = 0
var calmed: int = 0
var _started: bool = false


func style() -> CityFundStyle:
	return Modules.style("city_fund") as CityFundStyle


func _ready() -> void:
	TimeManager.day_started.connect(_on_day)
	_register_inputs()
	reset()


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


## v7a input actions (registered at runtime like v6b's WorldMemory).
func _register_inputs() -> void:
	for pair in [[&"possess", KEY_F2], [&"city_panel", KEY_F4], [&"role_demolish", KEY_1], [&"role_fire", KEY_2]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			InputMap.action_add_event(pair[0], _key(pair[1]))


func reset() -> void:
	var st := style()
	fund = st.start_balance if st else 500
	ledger.clear()
	projects.clear()
	damage.clear()
	fines_total = 0
	spent_total = 0
	fires = 0
	outages = 0
	quakes = 0
	arguments = 0
	calmed = 0
	changed.emit("all")


# ------------------------------------------------------------------ money
func _entry(kind: String, en: String, fa: String, amount: int) -> void:
	ledger.append({"day": TimeManager.day, "kind": kind, "en": en, "fa": fa, "amount": amount})
	while ledger.size() > 60:
		ledger.pop_front()


## A fine or damages paid into the fund (by the player or a townsperson).
func add_fine(kind: String, amount: int, en: String, fa: String, payer_is_player: bool = true) -> int:
	if amount <= 0:
		return 0
	if payer_is_player:
		var paid := mini(amount, maxi(Economy.money, 0))
		Economy.add_money(-paid)
		if paid < amount:
			WorldMemory.file_report("unpaid_" + kind, "player", "", amount - paid)
	fund += amount
	fines_total += amount
	_entry(kind, en, fa, amount)
	changed.emit("fund")
	GameEvents.notification_requested.emit(Lang.tt("جریمه: %s سکه به صندوق شهرداری - %s" % [Lang.digits(str(amount)), fa],
			"Fine: %d G to the city fund - %s" % [amount, en]))
	return amount


func add_income(kind: String, amount: int, en: String, fa: String) -> void:
	if amount <= 0:
		return
	fund += amount
	_entry(kind, en, fa, amount)
	changed.emit("fund")


func spend(kind: String, amount: int, en: String, fa: String) -> bool:
	if amount <= 0 or fund < amount:
		return false
	fund -= amount
	spent_total += amount
	_entry(kind, en, fa, -amount)
	changed.emit("fund")
	return true


func income_total() -> int:
	var s := 0
	for e: Dictionary in ledger:
		if int(e.get("amount", 0)) > 0:
			s += int(e["amount"])
	return s


func spending_total() -> int:
	var s := 0
	for e: Dictionary in ledger:
		if int(e.get("amount", 0)) < 0:
			s -= int(e["amount"])
	return s


## v5b doctor: the fund pays part of the player's fee. Returns the subsidy.
func doctor_subsidy(fee: int) -> int:
	var st := style()
	if st == null or fee <= 0:
		return 0
	var sub := mini(int(round(fee * st.doctor_subsidy)), st.subsidy_cap)
	sub = mini(sub, fund)
	if sub > 0:
		spend("doctor", sub, "Doctor subsidy", "یارانه‌ی درمان")
	return sub


# ------------------------------------------------------------------ projects
func project_state(id: String) -> String:
	return str((projects.get(id, {}) as Dictionary).get("state", "planned"))


func start_project(id: String) -> bool:
	var st := style()
	if st == null or project_state(id) != "planned":
		return false
	for p: Dictionary in st.projects:
		if str(p.get("id", "")) == id:
			if not spend("project", int(p.get("cost", 0)), str(p.get("en", id)), str(p.get("fa", id))):
				return false
			projects[id] = {"state": "building", "start": TimeManager.day, "done_day": TimeManager.day + int(p.get("days", 1))}
			changed.emit("projects")
			GameEvents.notification_requested.emit(Lang.tt("شهرداری کار تازه‌ای شروع کرد: %s" % str(p.get("fa", id)),
					"City Hall started a public work: %s" % str(p.get("en", id))))
			return true
	return false


## Finish a project now (day tick or tests).
func finish_project(id: String) -> void:
	if not projects.has(id):
		projects[id] = {"start": TimeManager.day}
	projects[id]["state"] = "done"
	projects[id]["done_day"] = TimeManager.day
	changed.emit("projects")


## Picks the next affordable planned project (cheapest first).
func auto_start() -> String:
	var st := style()
	if st == null:
		return ""
	var list: Array = st.projects.duplicate()
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("cost", 0)) < int(b.get("cost", 0)))
	for p: Dictionary in list:
		var id := str(p.get("id", ""))
		if project_state(id) == "planned" and fund >= int(p.get("cost", 0)) + 100:
			if start_project(id):
				return id
	return ""


# ------------------------------------------------------------------ damage
func damage_of(id: String) -> Dictionary:
	return damage.get(id, {})


func set_damage(id: String, state: String, burn: float, cause: String = "") -> void:
	var d: Dictionary = damage.get(id, {})
	d["state"] = state
	d["burn"] = snappedf(clampf(burn, 0.0, 1.0), 0.01)
	if cause != "":
		d["cause"] = cause
	if not d.has("since") or state in ["burning", "demolished"]:
		d["since"] = TimeManager.day
	damage[id] = d
	changed.emit("damage")


func clear_damage(id: String) -> void:
	damage.erase(id)
	changed.emit("damage")


# ------------------------------------------------------------------ day
func _on_day(day: int) -> void:
	var st := style()
	if st and st.daily_tax > 0:
		add_income("tax", st.daily_tax, "Shop taxes", "عوارض مغازه‌ها")
	for id in projects.keys():
		var p: Dictionary = projects[id]
		if str(p.get("state", "")) == "building" and day >= int(p.get("done_day", day)):
			finish_project(str(id))
			GameEvents.notification_requested.emit(Lang.tt("کار عمومی تمام شد!", "A public work is finished!"))
	auto_start()


func to_save() -> Dictionary:
	return {"fund": fund, "ledger": ledger.duplicate(true), "projects": projects.duplicate(true), "damage": damage.duplicate(true),
		"fines_total": fines_total, "spent_total": spent_total, "fires": fires, "outages": outages, "quakes": quakes,
		"arguments": arguments, "calmed": calmed}


func from_save(d: Dictionary) -> void:
	fund = int(d.get("fund", fund))
	ledger = (d.get("ledger", []) as Array).duplicate(true)
	projects = (d.get("projects", {}) as Dictionary).duplicate(true)
	damage = (d.get("damage", {}) as Dictionary).duplicate(true)
	fines_total = int(d.get("fines_total", 0))
	spent_total = int(d.get("spent_total", 0))
	fires = int(d.get("fires", 0))
	outages = int(d.get("outages", 0))
	quakes = int(d.get("quakes", 0))
	arguments = int(d.get("arguments", 0))
	calmed = int(d.get("calmed", 0))
	changed.emit("all")
