extends Node
## v5b healthy-life needs (autoload "Needs"; modules "needs" / NeedsStyle and
## the "illnesses" collection / IllnessDef) for the farmer AND every
## townsperson:
##   hunger  100 = full .. 0 = starving (eat at least one meal a day),
##   fatigue 0 = rested .. 100 = worn out (sleep in your bed),
##   illness "" or an IllnessDef id (cold, flu): slower walking, weaker
##           stamina regeneration, sneezing; cured by the hospital doctor for
##           a fee in gold, or passes after a few days of food + sleep.
## Townspeople eat at meal hours, sleep at night, sometimes catch a cold, walk
## slower while ill and visit the doctor (hospital) to get treated.

signal changed
signal fell_ill(who: String, illness_id: String)
signal cured(who: String, by_doctor: bool)
signal sneezed(who: Node3D)
signal meal_eaten(who: String, hunger: float)

## Disabled by the smoke test outside its own section (time jumps in tests are
## not "lived" time); always on in normal play.
var sim_enabled: bool = true
var hunger: float = 85.0
var fatigue: float = 10.0
var illness: String = ""
var ill_day: int = 0
var meals_today: int = 0
var meals_yesterday: int = 1
var sleeping: bool = false
var hospital_income: int = 0
var npc_cured: int = 0
## "Name Surname" -> {hunger, fatigue, illness, ill_day, meals, visit}
var npc: Dictionary = {}

var rng := RandomNumberGenerator.new()
var _last_abs: float = -1.0
var _was_exhausted: bool = false
var _sneeze_timer: float = 12.0
var _npc_sneeze: Dictionary = {}
var _warned_hungry: bool = false


func _ready() -> void:
	rng.seed = 5150
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void: _on_clock())
	TimeManager.hour_changed.connect(_on_hour)
	TimeManager.day_started.connect(_on_day)
	GameEvents.stamina_changed.connect(_on_stamina)
	GameEvents.crafted.connect(_on_crafted)


func style() -> NeedsStyle:
	return Modules.style("needs") as NeedsStyle


func illness_def(id: String) -> IllnessDef:
	if id == "" or not AssetRegistry.variants("illnesses").has(id):
		return null
	return AssetRegistry.load_variant("illnesses", id) as IllnessDef


func illnesses() -> Array[IllnessDef]:
	var out: Array[IllnessDef] = []
	for id: String in AssetRegistry.variants("illnesses"):
		var d := AssetRegistry.load_variant("illnesses", id) as IllnessDef
		if d:
			out.append(d)
	out.sort_custom(func(a: IllnessDef, b: IllnessDef) -> bool: return a.severity < b.severity)
	return out


func _abs_minutes() -> float:
	return float(TimeManager.day) * 1440.0 + TimeManager.minutes


# ------------------------------------------------------------------ player
func is_hungry() -> bool:
	var st := style()
	return hunger < (st.hungry_below if st else 30.0)


func is_tired() -> bool:
	var st := style()
	return fatigue > (st.tired_above if st else 70.0)


func is_ill() -> bool:
	return illness != ""


## Walking speed factor for the farmer (illness, starving).
func player_speed_factor() -> float:
	var f := 1.0
	var d := illness_def(illness)
	if d:
		f *= d.speed_mult
	var st := style()
	if hunger <= 0.5 and st:
		f *= st.starving_speed
	return f


func player_regen_factor() -> float:
	var d := illness_def(illness)
	return d.stamina_regen_mult if d else 1.0


func _on_clock() -> void:
	var now := _abs_minutes()
	if _last_abs < 0.0 or not sim_enabled:
		_last_abs = now
		return
	var dm := now - _last_abs
	_last_abs = now
	if dm <= 0.0:
		return
	# Big jumps that are not sleep (calendar resets, loading) are not lived.
	if dm > 180.0 and not sleeping:
		return
	pass_minutes(dm)


## Lets `minutes` of game time pass for the farmer.
func pass_minutes(minutes: float) -> void:
	var st := style()
	if st == null:
		return
	var h := minutes / 60.0
	if sleeping:
		hunger = maxf(hunger - st.hunger_per_hour * 0.5 * h, 0.0)
		fatigue = maxf(fatigue - 12.0 * h, 0.0)
	else:
		hunger = maxf(hunger - st.hunger_per_hour * h, 0.0)
		fatigue = minf(fatigue + st.fatigue_per_hour * h, 100.0)
	if is_hungry() and not _warned_hungry and not sleeping:
		_warned_hungry = true
		GameEvents.notification_requested.emit("گرسنه‌ای! یک وعده غذا بخور." if Lang.is_fa() else "You're hungry! Cook or buy a meal (at least one a day).")
	changed.emit()


func _on_hour(_hour: int, _day: int) -> void:
	if not sim_enabled:
		return
	if not sleeping:
		roll_illness()
	_npc_hour()


## Hourly illness roll for the farmer. Returns the new illness id or "".
func roll_illness(force_chance: float = -1.0) -> String:
	var st := style()
	if st == null or is_ill():
		return ""
	var chance := st.ill_chance_base
	if is_tired():
		chance += st.ill_chance_tired
	if is_hungry():
		chance += st.ill_chance_hungry
	# v6a: fitness from the gym makes colds less likely (Lifestyle / gym module).
	var life := get_node_or_null(^"/root/Lifestyle")
	if life:
		chance *= float(life.call("illness_mult"))
	if force_chance >= 0.0:
		chance = force_chance
	if chance <= 0.0 or rng.randf() >= chance:
		return ""
	return fall_ill(pick_illness(fatigue, hunger))


## Worst illness whose thresholds match.
func pick_illness(fat: float, hun: float) -> String:
	var best := ""
	for d in illnesses():
		if fat >= d.min_fatigue and hun <= d.max_hunger:
			best = d.id
	return best


func fall_ill(id: String) -> String:
	var d := illness_def(id)
	if d == null:
		return ""
	illness = id
	ill_day = TimeManager.day
	_sneeze_timer = rng.randf_range(2.0, 5.0)
	if Lang.is_fa():
		GameEvents.notification_requested.emit("%s گرفتی: %s. برو بیمارستان پیش دکتر (%s سکه)." % [d.name_fa, d.symptoms_fa, Lang.digits(str(fee_of(id)))])
	else:
		GameEvents.notification_requested.emit("You caught a %s: %s. See the doctor at the hospital (%d G)." % [d.display_name.to_lower(), d.symptoms_en, fee_of(id)])
	fell_ill.emit("player", id)
	changed.emit()
	return id


func fee_of(id: String) -> int:
	var d := illness_def(id)
	var st := style()
	return int(round(float(d.fee) * (st.fee_mult if st else 1.0))) if d else 0


func cure(by_doctor: bool) -> void:
	if illness == "":
		return
	illness = ""
	cured.emit("player", by_doctor)
	changed.emit()


var last_subsidy: int = 0


## The hospital doctor: pays the fee and cures. Returns the message.
func treat_player() -> String:
	if not is_ill():
		var msg := "\"You're healthy!\" Hunger %d%%, fatigue %d%%." % [int(hunger), int(fatigue)]
		if Lang.is_fa():
			msg = "«سالمی!» سیری %s٪، خستگی %s٪." % [Lang.digits(str(int(hunger))), Lang.digits(str(int(fatigue)))]
		if is_tired():
			msg += " اما خسته‌ای؛ خوب بخواب." if Lang.is_fa() else " But you're tired - get some sleep."
		elif is_hungry():
			msg += " اما گرسنه‌ای؛ غذا بخور." if Lang.is_fa() else " But you're hungry - eat a meal."
		return msg
	var d := illness_def(illness)
	var fee := fee_of(illness)
	if Economy.money < fee:
		return ("برای درمان %s سکه لازم است." % Lang.digits(str(fee))) if Lang.is_fa() else "The treatment costs %d G - not enough money." % fee
	# v7a: the city fund pays part of the fee (city_fund module).
	var subsidy := CityState.doctor_subsidy(fee)
	Economy.add_money(-(fee - subsidy))
	hospital_income += fee
	last_subsidy = subsidy
	var name_s := d.name_fa if Lang.is_fa() else d.display_name.to_lower()
	cure(true)
	fatigue = minf(fatigue, 40.0)
	if Lang.is_fa():
		return "دکتر %s را درمان کرد. -%s سکه%s. خوب بخور و استراحت کن!" % [name_s, Lang.digits(str(fee - subsidy)),
				(" (%s سکه یارانه‌ی شهرداری)" % Lang.digits(str(subsidy))) if subsidy > 0 else ""]
	return "The doctor treated your %s. -%d G%s. Eat well and rest!" % [name_s, fee - subsidy,
			(" (city subsidy %d G)" % subsidy) if subsidy > 0 else ""]


## Eating: raises hunger; `meal` counts toward the daily meal.
func eat(amount: float, meal: bool = true, who: String = "player") -> void:
	if who != "player":
		var s := npc_state_by_key(who)
		s["hunger"] = minf(float(s["hunger"]) + amount, 100.0)
		s["meals"] = int(s["meals"]) + 1
		meal_eaten.emit(who, float(s["hunger"]))
		return
	hunger = minf(hunger + amount, 100.0)
	if meal:
		meals_today += 1
	if not is_hungry():
		_warned_hungry = false
	meal_eaten.emit("player", hunger)
	changed.emit()


## Sleeping in your own bed (InteriorItem "bed"): call around the time skip.
func begin_sleep() -> void:
	sleeping = true


func end_sleep() -> void:
	sleeping = false
	fatigue = 0.0
	_last_abs = _abs_minutes()
	changed.emit()


func _on_day(day: int) -> void:
	meals_yesterday = meals_today
	meals_today = 0
	for k in npc:
		(npc[k] as Dictionary)["meals"] = 0
	if not sim_enabled:
		return
	var st := style()
	if st == null:
		return
	if meals_yesterday < st.meals_per_day:
		fatigue = minf(fatigue + st.skipped_meal_fatigue, 100.0)
		GameEvents.notification_requested.emit("دیروز غذا نخوردی - بدنت ضعیف شده." if Lang.is_fa() else "You skipped meals yesterday - you feel weak.")
		roll_illness(st.ill_chance_hungry * 2.0)
	# A cold passes on its own after its days if you ate yesterday.
	var d := illness_def(illness)
	if d and day - ill_day >= d.days and meals_yesterday >= st.meals_per_day:
		cure(false)
		GameEvents.notification_requested.emit("حالت بهتر شد!" if Lang.is_fa() else "You feel better - the %s has passed." % d.display_name.to_lower())
	changed.emit()


func _on_stamina(_v: float, _m: float, exhausted: bool) -> void:
	if exhausted and not _was_exhausted and sim_enabled:
		var st := style()
		fatigue = minf(fatigue + (st.exhausted_fatigue if st else 5.0), 100.0)
		changed.emit()
	_was_exhausted = exhausted


func _on_crafted(recipe_id: String) -> void:
	# v5a stove recipes (quick meals) also count as a meal.
	var r := GameData.recipes.get(recipe_id) as RecipeDef
	if r and r.is_meal():
		eat(clampf(r.stamina * 0.6, 15.0, 60.0), r.stamina >= 40.0)


# ------------------------------------------------------------------ townspeople
func npc_state_by_key(key: String) -> Dictionary:
	if not npc.has(key):
		var h := absi(key.hash())
		npc[key] = {"hunger": 60.0 + float(h % 35), "fatigue": 10.0 + float((h / 7) % 30), "illness": "", "ill_day": 0, "meals": 0,
				"visit": -1.0, "cured": 0}
	return npc[key]


func npc_state(bot: Node) -> Dictionary:
	return npc_state_by_key(Friendship.key_of(bot))


func npc_is_ill(bot: Node) -> bool:
	return str(npc_state(bot).get("illness", "")) != ""


func npc_speed_factor(bot: Node) -> float:
	var d := illness_def(str(npc_state(bot).get("illness", "")))
	return d.speed_mult if d else 1.0


func _bots() -> Array:
	return get_tree().get_nodes_in_group(&"townspeople")


func _npc_hour() -> void:
	var st := style()
	if st == null:
		return
	var h := TimeManager.hour()
	for b in _bots():
		var bot := b as TownspersonBot
		if bot == null:
			continue
		var s := npc_state(bot)
		var sc := bot.controller as ScheduleController
		var asleep := sc != null and str(sc.current.get("activity", "")) == "sleep"
		if asleep:
			s["fatigue"] = maxf(float(s["fatigue"]) - 12.0, 0.0)
			s["hunger"] = maxf(float(s["hunger"]) - st.hunger_per_hour * 0.5, 0.0)
		else:
			s["fatigue"] = minf(float(s["fatigue"]) + st.fatigue_per_hour, 100.0)
			s["hunger"] = maxf(float(s["hunger"]) - st.hunger_per_hour, 0.0)
			if h in st.npc_meal_hours:
				eat(45.0, true, Friendship.key_of(bot))
		if str(s["illness"]) == "":
			var chance := st.npc_ill_chance
			if float(s["fatigue"]) > st.tired_above:
				chance += st.ill_chance_tired * 0.4
			if float(s["hunger"]) < st.hungry_below:
				chance += st.ill_chance_hungry * 0.4
			if not asleep and rng.randf() < chance:
				npc_fall_ill(bot, pick_illness(float(s["fatigue"]), float(s["hunger"])))
		_npc_doctor_tick(bot, s, asleep)


func npc_fall_ill(bot: TownspersonBot, id: String) -> void:
	if illness_def(id) == null:
		return
	var s := npc_state(bot)
	s["illness"] = id
	s["ill_day"] = TimeManager.day
	s["visit"] = -1.0
	_npc_sneeze[bot] = rng.randf_range(1.0, 4.0)
	fell_ill.emit(Friendship.key_of(bot), id)
	_send_to_doctor(bot)


## Ill townspeople walk (slowly) to the hospital and wait for the doctor.
func _send_to_doctor(bot: TownspersonBot) -> void:
	var sc := bot.controller as ScheduleController
	if sc == null:
		return
	var spot := Townspeople._spot_for("hospital")
	if spot == "":
		return
	sc.override_entry = {"from": 0.0, "to": 24.0, "spot": spot, "activity": "wander", "radius": 2.0, "doctor": true}


func _npc_doctor_tick(bot: TownspersonBot, s: Dictionary, asleep: bool) -> void:
	if str(s["illness"]) == "":
		return
	var sc := bot.controller as ScheduleController
	if sc == null:
		return
	if sc.override_entry.is_empty() and not asleep:
		_send_to_doctor(bot)
		return
	if sc.override_entry.is_empty():
		return
	if sc.arrived and sc.current == sc.override_entry:
		if float(s["visit"]) < 0.0:
			s["visit"] = _abs_minutes()
		var st := style()
		if _abs_minutes() - float(s["visit"]) >= (st.npc_doctor_hours if st else 1.5) * 60.0 - 1.0:
			npc_cure(bot, true)


func npc_cure(bot: TownspersonBot, by_doctor: bool) -> void:
	var s := npc_state(bot)
	if str(s["illness"]) == "":
		return
	if by_doctor:
		hospital_income += fee_of(str(s["illness"]))
		npc_cured += 1
	s["illness"] = ""
	s["visit"] = -1.0
	s["cured"] = int(s["cured"]) + 1
	var sc := bot.controller as ScheduleController
	if sc:
		sc.override_entry = {}
	if not bot.hidden_inside:
		bot.say("ممنون دکتر!" if Lang.is_fa() else "Thank you, doctor!", 2.5)
	cured.emit(Friendship.key_of(bot), by_doctor)


# ------------------------------------------------------------------ sneezing
func _process(delta: float) -> void:
	if illness != "":
		_sneeze_timer -= delta
		if _sneeze_timer <= 0.0:
			var d := illness_def(illness)
			_sneeze_timer = rng.randf_range(d.sneeze_min, d.sneeze_max) if d else 15.0
			var p := get_tree().get_first_node_in_group(&"player") as Node3D
			if p:
				sneeze(p)
	for bot: Variant in _npc_sneeze.keys():
		if not is_instance_valid(bot):
			_npc_sneeze.erase(bot)
			continue
		var b := bot as TownspersonBot
		var s := npc_state(b)
		if str(s["illness"]) == "":
			_npc_sneeze.erase(bot)
			continue
		_npc_sneeze[bot] = float(_npc_sneeze[bot]) - delta
		if float(_npc_sneeze[bot]) <= 0.0:
			var d2 := illness_def(str(s["illness"]))
			_npc_sneeze[bot] = rng.randf_range(d2.sneeze_min, d2.sneeze_max) if d2 else 15.0
			if not b.hidden_inside and not b.is_far_from_player():
				sneeze(b)


## A sneeze: sound + "Achoo!" (bubble for townspeople, floating text for the farmer).
func sneeze(who: Node3D) -> void:
	var dlg := Modules.style("dialogue") as DialogueStyle
	var word := Lang.pick(dlg.sneeze, rng) if dlg else "Achoo!"
	var pitch := 1.0
	if who is TownspersonBot:
		pitch = VoiceBlips.pitch_for((who as TownspersonBot).resident)
		(who as TownspersonBot).say(word, 1.6)
	else:
		var ft := Label3D.new()
		ft.set_script(load("res://scripts/ui/floating_text.gd"))
		Lang.setup_label3d(ft, 56)
		ft.text = word
		ft.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		ft.pixel_size = 0.005
		ft.modulate = Color(0.85, 0.95, 1.0)
		ft.outline_size = 12
		ft.position = who.global_position + Vector3(0, 2.1, 0)
		get_tree().current_scene.add_child(ft)
	Sfx.play_at(&"sneeze", who.global_position + Vector3(0, 1.5, 0), -6.0, pitch)
	sneezed.emit(who)


# ------------------------------------------------------------------ save
func reset() -> void:
	hunger = 85.0
	fatigue = 10.0
	illness = ""
	meals_today = 0
	meals_yesterday = 1
	npc.clear()
	_last_abs = -1.0
	changed.emit()


func to_save() -> Dictionary:
	return {"hunger": hunger, "fatigue": fatigue, "illness": illness, "ill_day": ill_day, "meals_today": meals_today,
		"meals_yesterday": meals_yesterday, "npc": npc.duplicate(true), "hospital_income": hospital_income}


func from_save(d: Dictionary) -> void:
	hunger = float(d.get("hunger", 85.0))
	fatigue = float(d.get("fatigue", 10.0))
	illness = str(d.get("illness", ""))
	ill_day = int(d.get("ill_day", 0))
	meals_today = int(d.get("meals_today", 0))
	meals_yesterday = int(d.get("meals_yesterday", 1))
	hospital_income = int(d.get("hospital_income", 0))
	npc = (d.get("npc", {}) as Dictionary).duplicate(true)
	_last_abs = _abs_minutes()
	changed.emit()
