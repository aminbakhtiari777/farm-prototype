class_name CookingPanel
extends PanelContainer
## v5b hands-on cooking UI (opens on GameEvents.cooking_requested from a home
## stove). Pick a dish (dishes module), then do every action of the cooking
## module in order - wash + chop, add salt, add spices, cook, eat - and watch
## it happen in the pan (CookingStation). Eating counts as the day's meal.
## E = do the next step, Esc = close. "Quick recipes" opens the v5a stove menu.

var stove: Node3D
var session: Cooking
var station: CookingStation
var _title: Label
var _info: Label
var _dishes: VBoxContainer
var _steps: VBoxContainer
var _do_btn: Button
var _log: Label
var _hint: Label


func _ready() -> void:
	name = "CookingPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.12, 0.09, 0.07, 0.9), 12, 16))
	# Left side, under the top bar: the minimap + NPC card own the right
	# side and the needs / stamina bars sit bottom-left (below y = 900-190).
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	offset_left = 16
	offset_right = 536
	offset_top = 62
	offset_bottom = 700
	grow_horizontal = Control.GROW_DIRECTION_END
	var v := VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override(&"separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UIKit.label(head, "", 24, UIKit.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button(head, "Close (Esc)", close, "Close")
	_info = UIKit.label(v, "", 14, Color(0.85, 0.8, 0.7))
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dishes = VBoxContainer.new()
	_dishes.add_theme_constant_override(&"separation", 4)
	v.add_child(_dishes)
	v.add_child(HSeparator.new())
	_steps = VBoxContainer.new()
	_steps.add_theme_constant_override(&"separation", 2)
	v.add_child(_steps)
	_do_btn = UIKit.button(v, "", do_next, "Do the next cooking step (E)", 18)
	_do_btn.custom_minimum_size.y = 40
	_log = UIKit.label(v, "", 15, Color(1, 0.95, 0.8))
	_log.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_log.custom_minimum_size.x = 480
	_hint = UIKit.label(v, "", 13, Color(0.7, 0.85, 0.7))
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size.x = 480
	var row := HBoxContainer.new()
	v.add_child(row)
	UIKit.button(row, "Quick recipes (tea, soups...)", _quick, "The v5a stove recipes", 13)
	GameEvents.cooking_requested.connect(open)
	Economy.inventory_changed.connect(refresh)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			refresh())


func _t(fa: String, en: String) -> String:
	return fa if Lang.is_fa() else en


func open(at_stove: Node3D) -> void:
	stove = at_stove
	station = CookingStation.for_stove(at_stove) if at_stove else null
	if session == null or session.done or session.stove != at_stove:
		session = null
		if station:
			station.set_stage("idle")
	visible = true
	GameEvents.open_modal("cooking")
	GameEvents.interaction_prompt_changed.emit("")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("cooking")


func _quick() -> void:
	close()
	GameEvents.crafting_requested.emit("stove")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed(&"interact"):
		do_next()
		get_viewport().set_input_as_handled()


## Chooses a dish and lays its ingredients on the board.
func choose(dish: DishDef) -> void:
	session = Cooking.new(dish, stove)
	if station:
		station.set_stage("ready", dish)
	_log.text = _t("مواد %s را روی تخته گذاشتی." % Cooking.dish_name(dish), "The ingredients for %s are on the board." % dish.display_name)
	refresh()


## Performs the current step of the session.
func do_next() -> String:
	if session == null:
		var first := _first_cookable()
		if first == null:
			_log.text = _t("مواد کافی نداری - از سوپرمارکت بخر.", "Not enough ingredients - buy some at the Supermarket.")
			return ""
		choose(first)
		return ""
	if session.done:
		session = null
		if station:
			station.set_stage("idle")
		refresh()
		return ""
	var sid := session.current_id()
	var before := session.step_index
	var msg := session.do_step(sid, get_tree())
	if session.step_index > before and station:
		station.set_stage(sid)
		TownGameplay.animate_hands("eat" if sid == "eat" else "place")
	_log.text = msg
	GameEvents.notification_requested.emit(msg)
	refresh()
	return msg


func _first_cookable() -> DishDef:
	for d in Cooking.dishes():
		if Cooking.can_cook(d):
			return d
	return null


func refresh() -> void:
	if not visible:
		return
	var ks := Modules.style("kitchen") as KitchenStyle
	_title.text = _t("آشپزی در خانه", "Home cooking")
	var meals := "%d/%d" % [Needs.meals_today, (Needs.style().meals_per_day if Needs.style() else 1)]
	_info.text = _t("سیری %s٪، وعده امروز %s، اجاق: %s%s" % [Lang.digits(str(int(Needs.hunger))), Lang.digits(meals), _stove_fa(ks), (" - برق نیست!" if ks and ks.needs_power() and not PowerGrid.power_on else "")],
			"Hunger %d%% full · meals today %s · stove: %s%s" % [int(Needs.hunger), meals, ks.stove if ks else "?", ("  -  no power!" if ks and ks.needs_power() and not PowerGrid.power_on else "")])
	for c in _dishes.get_children():
		c.queue_free()
	UIKit.label(_dishes, _t("غذا را انتخاب کن:", "Choose a dish:"), 15, Color(0.95, 0.85, 0.6))
	for d in Cooking.dishes():
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 8)
		_dishes.add_child(row)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		var sel := session != null and session.dish == d
		UIKit.label(left, "%s%s   (+%s)" % ["» " if sel else "", Cooking.dish_name(d), Lang.digits(str(int(d.hunger)))], 17, UIKit.GOLD if sel else Color(1, 0.95, 0.85))
		var have: PackedStringArray = []
		for k in d.inputs:
			have.append("%s %s/%s" % [Cooking.ingredient_name(str(k)), Lang.digits(str(Kitchenware.count_input(str(k)))), Lang.digits(str(int(d.inputs[k])))])
		have.append("%s %s" % [Cooking.ingredient_name("salt"), Lang.digits(str(Economy.count("salt")))])
		have.append("%s %s" % [Cooking.ingredient_name("spices"), Lang.digits(str(Economy.count("spices")))])
		var why := Cooking.missing(d)
		var need := UIKit.label(left, "، ".join(have) if Lang.is_fa() else ", ".join(have), 13, Color(0.6, 0.9, 0.6) if why == "" else Color(0.95, 0.6, 0.5))
		need.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		need.custom_minimum_size.x = 340
		var btn := UIKit.button(row, _t("انتخاب", "Choose"), func() -> void: choose(d), d.description)
		btn.disabled = why != "" or (session != null and not session.done and session.step_index > 0)
	for c in _steps.get_children():
		c.queue_free()
	var list := Cooking.steps()
	for i in list.size():
		var s: Dictionary = list[i]
		var state := 0
		if session != null:
			state = 2 if i < session.step_index else (1 if i == session.step_index and not session.done else 0)
		var mark := "[x] " if state == 2 else ("> " if state == 1 else "[ ] ")
		var col := Color(0.55, 0.9, 0.55) if state == 2 else (UIKit.GOLD if state == 1 else Color(0.7, 0.68, 0.62))
		UIKit.label(_steps, "%s%s. %s" % [mark, Lang.digits(str(i + 1)), Cooking.step_label(s)], 16, col)
	if session == null:
		_do_btn.text = _t("یک غذا انتخاب کن (E)", "Pick a dish (E)")
	elif session.done:
		_do_btn.text = _t("نوش جان! دوباره بپز (E)", "Enjoyed! Cook again (E)")
	else:
		_do_btn.text = _t("انجام بده: %s (E)" % Cooking.step_label(session.current_step()), "Do: %s (E)" % Cooking.step_label(session.current_step()))
	_hint.text = _t("مرغ، تخم‌مرغ، پیاز، گوجه، سبزی، برنج، نمک و ادویه را از پیشخوان سوپرمارکت (خیابان اصلی ۱۵) بخر.",
			"Buy chicken, eggs, onions, tomatoes, herbs, rice, salt and spices at the Supermarket counter (15 Main St).")
	Lang.apply_dir(get_child(0) as Control)


func _stove_fa(ks: KitchenStyle) -> String:
	if ks == null:
		return "?"
	match ks.stove:
		"electric":
			return "برقی"
		"gas":
			return "گازی"
		"wood":
			return "هیزمی"
	return ks.stove
