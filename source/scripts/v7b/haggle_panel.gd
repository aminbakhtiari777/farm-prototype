class_name HagglePanel
extends PanelContainer
## v7b personality trading (personalities module): key 7 next to a
## townsperson - they offer to buy one of your goods. Their personality
## decides the opening offer, how far they go and how patient they are
## (generous people pay more, stingy ones haggle hard, hot-tempered ones
## walk away fast). Accept / ask for more (+15%) / walk away.

var bot: TownspersonBot
var item_id: String = ""
var fair: int = 0
var offer: int = 0
var round_n: int = 0
var done: bool = false
var deals: int = 0
var _rng := RandomNumberGenerator.new()
var _title: Label
var _who: Label
var _offer: Label
var _line: Label
var _accept: Button
var _more: Button
var _walk: Button


func _ready() -> void:
	name = "HagglePanel"
	_rng.randomize()
	theme = V6bWorld.ui_theme()
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.12, 0.13, 0.1, 0.96), 14, 18, true))
	set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	custom_minimum_size = Vector2(600, 260)
	offset_left = -300
	offset_right = 300
	offset_top = -330
	offset_bottom = -70
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	_title = UIKit.label(v, "", 22, UIKit.GOLD)
	_who = UIKit.label(v, "", 15, Color(0.85, 0.9, 0.85))
	_offer = UIKit.label(v, "", 19, Color(1, 1, 1))
	_line = UIKit.label(v, "", 17, Color(1.0, 0.9, 0.6))
	_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	v.add_child(row)
	_accept = UIKit.button(row, "", accept, "", 16)
	_more = UIKit.button(row, "", ask_more, "", 16)
	_walk = UIKit.button(row, "", walk_away, "", 16)


## The adult townsperson next to the player who is free to talk (or null).
static func partner(tree: SceneTree, pos: Vector3, radius: float = 3.2) -> TownspersonBot:
	var best: TownspersonBot = null
	var bd := radius
	for b in V7aKit.bots(tree):
		if int(b.resident.get("age", 0)) < 16 or b.controller is Possession.PossessController:
			continue
		var d := V7aKit.flat(b.global_position).distance_to(V7aKit.flat(pos))
		if d < bd and b.visible:
			bd = d
			best = b
	return best


## The good you offer: the sellable item you have most of.
static func pick_item() -> String:
	var best := ""
	var n := 0
	for id in Economy.sellable_items():
		if Economy.count(id) > n:
			n = Economy.count(id)
			best = id
	return best


func start(who: TownspersonBot, id: String = "") -> bool:
	if who == null:
		GameEvents.notification_requested.emit(Lang.tt("کسی کنارت نیست که با او معامله کنی.", "Nobody next to you to trade with."))
		return false
	item_id = id if id != "" else pick_item()
	if item_id == "" or Economy.count(item_id) <= 0:
		GameEvents.notification_requested.emit(Lang.tt("چیزی برای فروش نداری (محصول یا فرآورده).", "You have nothing to sell (produce or animal products)."))
		return false
	bot = who
	fair = maxi(Economy.sell_price(item_id), 1)
	offer = Personalities.opening_offer(who.resident, fair)
	round_n = 0
	done = false
	visible = true
	GameEvents.open_modal("haggle")
	var open := Lang.tt("این %s را %s سکه می‌خرم." % [Market.local_name(item_id), Lang.digits(str(offer))], "I'll buy your %s for %d G." % [Market.local_name(item_id), offer])
	_set_line(open)
	refresh()
	return true


func _set_line(t: String) -> void:
	_line.text = "«%s»" % t if Lang.is_fa() else "\"%s\"" % t
	if bot:
		V7bKit.say_small(bot, t, 3.5)


func accept() -> bool:
	if done or bot == null or not Economy.remove_item(item_id, 1):
		return false
	Economy.add_money(offer)
	done = true
	deals += 1
	TownLife.trades["player"] = int(TownLife.trades.get("player", 0)) + 1
	TownLife.trades["earned"] = int(TownLife.trades.get("earned", 0)) + offer
	TownLife.count_event("trade")
	Friendship.add_points(Friendship.key_of(bot), 2)
	TownLife.log_line(Dialogue.name_of(bot.resident), "Deal: %s for %d G." % [GameData.item_name(item_id), offer], "معامله: %s به %s سکه." % [Newspaper._fa_item_name(item_id), Lang.digits(str(offer))])
	Sfx.play_at(&"coin", bot.global_position)
	_set_line(V7bKit.line(Personalities.lines(bot.resident, "accept"), {}, _rng))
	refresh()
	return true


func ask_more() -> String:
	if done or bot == null:
		return ""
	var asking := maxi(int(ceil(offer * 1.15)), offer + 1)
	var r := Personalities.respond(bot.resident, fair, asking, round_n, _rng)
	round_n += 1
	match str(r["result"]):
		"accept":
			offer = int(r["price"])
			_set_line(str(r["line"]))
			accept()
		"counter":
			offer = int(r["price"])
			_set_line(str(r["line"]))
		"refuse":
			done = true
			if Personalities.temper(bot.resident) > 0.6:
				Friendship.add_points(Friendship.key_of(bot), -1)
			_set_line(str(r["line"]))
	refresh()
	return str(r["result"])


func walk_away() -> void:
	close()


func close() -> void:
	if not visible:
		return
	visible = false
	bot = null
	GameEvents.close_modal("haggle")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"menu") or event.is_action_pressed(&"haggle")):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	Lang.apply_dir(get_child(0) as Control)
	_title.text = Lang.tt("چانه‌زنی", "Haggling")
	if bot:
		_who.text = Lang.tt("%s · شخصیت: %s · قیمت منصفانه %s سکه" % [Dialogue.name_of(bot.resident), Personalities.trait_name(bot.resident), Lang.digits(str(fair))],
			"%s · personality: %s · fair price %d G" % [Dialogue.name_of(bot.resident), Personalities.trait_name(bot.resident), fair])
	_offer.text = Lang.tt("پیشنهاد: %s سکه برای یک %s (داری: %s)" % [Lang.digits(str(offer)), Market.local_name(item_id), Lang.digits(str(Economy.count(item_id)))],
		"Offer: %d G for one %s (you have %d)" % [offer, Market.local_name(item_id), Economy.count(item_id)])
	_accept.text = Lang.tt("قبول", "Accept")
	_more.text = Lang.tt("بیشتر بخواه (+۱۵٪)", "Ask for more (+15%)")
	_walk.text = Lang.tt("بستن", "Close") if done else Lang.tt("ولش کن", "Walk away")
	_accept.disabled = done
	_more.disabled = done
