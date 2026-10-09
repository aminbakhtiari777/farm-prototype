class_name Possession
extends Node3D
## v7a "possession" module: play as a townsperson (local single player).
## F2 next to a resident takes over their body: the farmer's body is hidden
## and the resident follows your controls, keeping their own name, job, home
## and memories (shown in the banner). Free choices:
##   R  dig (v6b digging, as usual)
##   1  demolish their own house with the axe - rubble, rebuilt over days by
##      the carpenter + mason; the household pays the rebuild cost
##   2  start a fire next to a building - FireService; fines + damages
## Destructive acts ask first (Persian confirmation dialog). Consequences:
## the family and neighbours remember, the police take a report, fines go to
## the city fund. F2 again hands the body back to its owner.
## v7b.1: the hidden farmer body carries the controls, so possession uses the
## same GTA-style input (mouse look, WASD camera-relative, touch sticks +
## play-as / dig / demolish / fire buttons) and can drive cars.

var bot: TownspersonBot
var acts: Array[String] = []
var banner: PanelContainer
var _label: Label
var dialog: V7aConfirmDialog
var possessions: int = 0
var _prev_pos: Vector3


class PossessController extends BotController:
	var original: BotController
	var player: Player
	func tick(bot: Node3D, _delta: float) -> Dictionary:
		if player == null:
			return {"move": Vector3.ZERO}
		var v := player.velocity
		v.y = 0.0
		bot.global_position = player.global_position
		# v7b.1: a possessed resident can drive too - hide the body while in the car.
		var tb := bot as TownspersonBot
		if tb and tb.visual:
			tb.visual.visible = player.vehicle == null
		var pv := player.get_node_or_null(^"Visual") as Node3D
		var out := {"move": v, "pose": &""}
		if v.length() < 0.05 and pv:
			out["face"] = pv.rotation.y
		return out
	func on_greeted(_bot: Node3D, _player: Node3D) -> String:
		return ""
	func describe() -> String:
		return "possessed"


func style() -> PossessionStyle:
	return Modules.style("possession") as PossessionStyle


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 7
	add_child(layer)
	banner = PanelContainer.new()
	banner.name = "PossessionBanner"
	banner.theme = V6bWorld.ui_theme()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.18, 0.08, 0.2, 0.82), 10, 12, true))
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 112
	banner.offset_left = -330
	banner.offset_right = 330
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.visible = false
	layer.add_child(banner)
	_label = UIKit.label(banner, "", 16, Color(1, 0.95, 0.85))
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.custom_minimum_size.x = 640
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog = V7aConfirmDialog.new()
	dialog.theme = V6bWorld.ui_theme()
	layer.add_child(dialog)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			_refresh())


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func allowed(act: String) -> bool:
	var st := style()
	return st != null and (st.allow.is_empty() or act in st.allow)


func is_active() -> bool:
	return bot != null and is_instance_valid(bot)


func nearest_resident(max_d: float = -1.0) -> TownspersonBot:
	var p := _player()
	var st := style()
	if p == null:
		return null
	var best: TownspersonBot = null
	var bd := max_d if max_d > 0.0 else (st.max_distance if st else 3.0)
	for b in V7aKit.bots(get_tree()):
		if b.hidden_inside or b.resident.is_empty() or not (b.controller is ScheduleController):
			continue
		var d := b.global_position.distance_to(p.global_position)
		if d < bd:
			bd = d
			best = b
	return best


func possess(b: TownspersonBot) -> bool:
	var p := _player()
	if b == null or p == null or is_active() or style() == null or p.vehicle != null:
		return false
	bot = b
	possessions += 1
	_prev_pos = p.global_position
	p.stand_up()
	p.global_position = b.global_position + Vector3(0, 0.05, 0)
	(p.get_node(^"Visual") as Node3D).rotation.y = b.visual.rotation.y
	(p.get_node(^"Visual") as Node3D).visible = false
	var pc := PossessController.new()
	pc.original = b.controller
	pc.player = p
	b.set_controller(pc)
	b.collision_layer = 0
	b.zone.enabled = false
	b.set_meta(&"possessed", true)
	Backstories.remember(b, "possessed", "Strange... I lost a few hours today.", "عجیب است... امروز چند ساعت از یادم رفته.")
	_refresh()
	banner.visible = true
	GameEvents.notification_requested.emit(Lang.tt("حالا در نقش %s هستی. F2 برای بازگشت." % Dialogue.name_of(b.resident),
			"You are now playing as %s. F2 to return." % Population.full_name(b.resident)))
	return true


func release() -> void:
	if not is_active():
		bot = null
		banner.visible = false
		return
	var p := _player()
	var pc := bot.controller as PossessController
	if pc:
		bot.set_controller(pc.original)
	if bot.visual:
		bot.visual.visible = true
	bot.collision_layer = 16
	bot.zone.enabled = true
	bot.remove_meta(&"possessed")
	if p:
		(p.get_node(^"Visual") as Node3D).visible = true
		var side := Vector3(1.2, 0, 0).rotated(Vector3.UP, (p.get_node(^"Visual") as Node3D).rotation.y)
		p.global_position = bot.global_position + side + Vector3(0, 0.05, 0)
	bot = null
	banner.visible = false
	GameEvents.notification_requested.emit(Lang.tt("به نقش خودت برگشتی.", "You're back in your own shoes."))


func _refresh() -> void:
	if not is_active():
		return
	var r := bot.resident
	var home := str(r.get("home", ""))
	var lines: PackedStringArray = []
	if Lang.is_fa():
		lines.append("در نقش: %s - %s ساله، %s (خانه: %s)" % [Dialogue.name_of(r), Lang.digits(str(int(r.get("age", 0)))), Dialogue.job_of(r), SignText.address(Population.home_address(r))])
	else:
		lines.append("Playing as: %s - %d, %s (home: %s)" % [Population.full_name(r), int(r.get("age", 0)), str(r.get("job", "")), Population.home_address(r)])
	var mem := Backstories.memory_line(Population.full_name(r))
	if mem != "":
		lines.append(Lang.tt("خاطره: ", "Memory: ") + mem)
	var keys: PackedStringArray = [Lang.tt("F2 بازگشت", "F2 return")]
	if allowed("dig"):
		keys.append(Lang.tt("R کندن زمین", "R dig"))
	if allowed("demolish") and home != "":
		keys.append(Lang.tt("1 خراب کردن خانه‌ی خودت با تبر", "1 demolish own house (axe)"))
	if allowed("fire"):
		keys.append(Lang.tt("2 آتش زدن", "2 start a fire"))
	lines.append("  ·  ".join(keys))
	_label.text = "\n".join(lines)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo() or dialog.visible:
		return
	if event.is_action(&"possess"):
		if is_active():
			release()
		elif not GameEvents.ui_open:
			var b := nearest_resident()
			if b:
				possess(b)
			else:
				GameEvents.notification_requested.emit(Lang.tt("برای بازی در نقش کسی، کنارش بایست و F2 را بزن.", "Stand next to a townsperson and press F2 to play as them."))
		get_viewport().set_input_as_handled()
	elif is_active() and event.is_action(&"role_demolish"):
		request_demolish()
		get_viewport().set_input_as_handled()
	elif is_active() and event.is_action(&"role_fire"):
		request_fire()
		get_viewport().set_input_as_handled()


func _fire() -> FireService:
	return get_tree().current_scene.find_child("FireService", true, false) as FireService


func home_building() -> Building:
	if not is_active():
		return null
	var fs := _fire()
	return fs.building_by_id(str(bot.resident.get("home", ""))) if fs else null


## 1: tear down your own house (confirmation first).
func request_demolish() -> bool:
	if not allowed("demolish"):
		return false
	var b := home_building()
	var p := _player()
	if b == null or p == null:
		return false
	if p.global_position.distance_to(b.door_world_position(1.0)) > 9.0:
		GameEvents.notification_requested.emit(Lang.tt("برای خراب کردن باید کنار خانه‌ی خودت باشی.", "Stand by your own house to demolish it."))
		return false
	var st := style()
	dialog.ask(Lang.tt("خراب کردن خانه؟", "Demolish the house?"),
		Lang.tt("می‌خواهی خانه‌ی خانواده‌ی %s را با تبر خراب کنی؟ هزینه‌ی بازسازی %s سکه است و %s روز طول می‌کشد. خانواده و همسایه‌ها این را به یاد می‌آورند." % [
			Dialogue.name_of(bot.resident), Lang.digits(str(st.rebuild_cost)), Lang.digits(str(st.demolish_days))],
			"Tear down the %s family home with the axe? Rebuilding costs %d G and takes %d days. The family and neighbours will remember." % [
			str(bot.resident.get("surname", "")), st.rebuild_cost, st.demolish_days]),
		func() -> void: do_demolish())
	return true


func do_demolish() -> bool:
	var b := home_building()
	var fs := _fire()
	if b == null or fs == null:
		return false
	var st := style()
	var who := Population.full_name(bot.resident)
	if not fs.demolish(b, who):
		return false
	var cost := st.rebuild_cost if st else 600
	var paid := mini(cost, maxi(Economy.money, 0))
	Economy.add_money(-paid)
	CityState._entry("rebuild", "Rebuild cost paid to the carpenter + mason (%s)" % who, "هزینه‌ی بازسازی به نجار و بنا (%s)" % Dialogue.name_of(bot.resident), 0)
	for m in Population.family_of(bot.resident):
		WorldMemory.npc_remember(Population.full_name(m), "demolished", "%s tore our house down with an axe!" % str(bot.resident.get("name", "")),
				"%s خانه‌مان را با تبر خراب کرد!" % Dialogue.first_name(bot.resident))
	Backstories.remember(who, "demolished", "I tore my own house down... what was I thinking?", "خانه‌ی خودم را خراب کردم... چه فکری می‌کردم؟")
	GameEvents.notification_requested.emit(Lang.tt("خانه خراب شد. -%s سکه هزینه‌ی بازسازی؛ نجار و بنا از فردا کار را شروع می‌کنند." % Lang.digits(str(paid)),
			"The house is down. -%d G rebuild cost; the carpenter and mason start tomorrow." % paid))
	_refresh()
	return true


## 2: start a fire at the nearest building (confirmation first).
func request_fire() -> bool:
	if not allowed("fire"):
		return false
	var fs := _fire()
	var p := _player()
	if fs == null or p == null:
		return false
	var target := fs.nearest_flammable(p.global_position, 6.0)
	if target == null:
		GameEvents.notification_requested.emit(Lang.tt("اینجا چیزی برای آتش زدن نیست.", "Nothing here that would burn."))
		return false
	var fst := fs.style()
	dialog.ask(Lang.tt("آتش زدن؟", "Start a fire?"),
		Lang.tt("واقعاً می‌خواهی کنار این ساختمان آتش روشن کنی؟ آتش ممکن است به خانه‌های کناری هم برسد. جریمه %s سکه به‌اضافه‌ی خسارت است و پلیس گزارش می‌گیرد." % Lang.digits(str(fst.fine if fst else 300)),
			"Really start a fire by this building? It can spread to the houses next to it. The fine is %d G plus damages, and the police will take a report." % (fst.fine if fst else 300)),
		func() -> void: do_fire(target))
	return true


func do_fire(target: Building) -> bool:
	var fs := _fire()
	if fs == null or target == null:
		return false
	var who := Population.full_name(bot.resident) if is_active() else "player"
	var ok := fs.ignite(target, who, true)
	if ok and is_active():
		Backstories.remember(who, "arson", "I started a fire... I'm so ashamed.", "آتش روشن کردم... خیلی شرمنده‌ام.")
	return ok
