class_name NpcCard
extends PanelContainer
## v5b name + job card ("npc_card" module): pops up when you walk up to a
## townsperson - name (Persian or English), age, job and workplace with its
## opening hours, family, friendship hearts, health - and shows the last
## conversation after you talk (E). Hidden while a menu is open.

var bot: TownspersonBot
var _name: Label
var _job: Label
var _hours: Label
var _family: Label
var _health: Label
var _friend: Label
var _hearts: Control
var _dialogue: Label
var _story: Label  ## v7a backstory block
var _hint: Label
var _timer: float = 0.0
var _talk_until: float = 0.0
var _talk_bot: TownspersonBot
var shown_for: String = ""


func style() -> NpcCardStyle:
	return Modules.style("npc_card") as NpcCardStyle


func _ready() -> void:
	name = "NpcCard"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -286
	offset_right = -20
	offset_top = 292
	offset_bottom = 292
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.name = "Body"
	v.add_theme_constant_override(&"separation", 3)
	add_child(v)
	_name = UIKit.label(v, "", 24)
	_job = UIKit.label(v, "", 16)
	_hours = UIKit.label(v, "", 14)
	_family = UIKit.label(v, "", 14)
	_family.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_family.custom_minimum_size.x = 240
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override(&"separation", 8)
	v.add_child(fr)
	_hearts = Control.new()
	_hearts.custom_minimum_size = Vector2(200, 22)
	_hearts.draw.connect(_draw_hearts)
	fr.add_child(_hearts)
	_friend = UIKit.label(fr, "", 14)
	_health = UIKit.label(v, "", 14)
	_story = UIKit.label(v, "", 13)
	_story.name = "Story"
	_story.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_story.custom_minimum_size.x = 240
	_dialogue = UIKit.label(v, "", 17)
	_dialogue.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialogue.custom_minimum_size.x = 240
	_hint = UIKit.label(v, "", 13)
	for b in get_tree().get_nodes_in_group(&"townspeople"):
		_hook(b)
	get_tree().node_added.connect(func(n: Node) -> void:
		if n is TownspersonBot:
			_hook.call_deferred(n))
	Friendship.changed.connect(func(_k: String, _p: int, _g: int) -> void: refresh())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			refresh())
	Modules.on_swap("npc_card", self, func(_m: AssetModule) -> void: _apply_style())
	_apply_style()


func _hook(b: Node) -> void:
	if b is TownspersonBot and not (b as TownspersonBot).talked.is_connected(_on_talked):
		(b as TownspersonBot).talked.connect(_on_talked)


func _apply_style() -> void:
	var st := style()
	var bg := st.bg_color if st else Color(0.98, 0.94, 0.84, 0.95)
	var ink := st.ink_color if st else UIKit.INK
	add_theme_stylebox_override(&"panel", UIKit.style(bg, 12, 14, true))
	for l: Label in [_name, _job, _hours, _family, _health, _friend, _story, _dialogue, _hint]:
		l.add_theme_color_override(&"font_color", ink)
	_name.add_theme_color_override(&"font_color", st.accent_color if st else Color(0.7, 0.3, 0.2))
	_name.add_theme_font_override(&"font", Lang.bold_font())
	_dialogue.add_theme_font_override(&"font", Lang.bubble_font())
	_hint.add_theme_color_override(&"font_color", ink.lerp(bg, 0.4))
	_hearts.queue_redraw()


func _on_talked(b: TownspersonBot) -> void:
	_talk_bot = b
	_talk_until = Time.get_ticks_msec() / 1000.0 + 14.0
	show_for(b)


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.2
	var st := style()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player == null or GameEvents.ui_open:
		_hide()
		return
	var best: TownspersonBot = null
	var best_d := st.show_distance if st else 4.0
	for b in get_tree().get_nodes_in_group(&"townspeople"):
		var tb := b as TownspersonBot
		if tb == null or tb.hidden_inside or tb.has_meta(&"possessed"):  # v7a: you are them
			continue
		var d := tb.global_position.distance_to(player.global_position)
		if d < best_d:
			best = tb
			best_d = d
	if best == null:
		_hide()
		return
	if best != bot:
		show_for(best)
	elif _talk_bot == bot and Time.get_ticks_msec() / 1000.0 > _talk_until and _dialogue.visible:
		refresh()


func _hide() -> void:
	if visible:
		visible = false
	bot = null
	shown_for = ""


func show_for(b: TownspersonBot) -> void:
	bot = b
	visible = true
	refresh()


func refresh() -> void:
	if bot == null or not is_instance_valid(bot):
		return
	var fa := Lang.is_fa()
	Lang.apply_dir(get_child(0) as Control)
	var r := bot.resident
	var st := style()
	shown_for = Friendship.key_of(bot)
	_name.text = Dialogue.name_of(r) if not r.is_empty() else bot.display_name
	var age := int(r.get("age", 0))
	var work := str(r.get("work", ""))
	# Four compact lines: identity, age, location and feeling toward the player.
	_job.text = Lang.tt("سن: %s" % Lang.digits(str(age)), "Age: %d" % age)
	_hours.visible = true
	_hours.text = Dialogue.place_of(work if work != "" else str(r.get("home", "")))
	_friend.text = Friendship.level_name(Friendship.key_of(bot))
	_hearts.get_parent().visible = true
	_hearts.visible = false
	for extra: Label in [_family, _health, _story, _dialogue, _hint]:
		extra.visible = false
	reset_size()


func _draw_hearts() -> void:
	var st := style()
	var n := 10
	var fs := Friendship.style()
	if fs:
		n = fs.hearts
	var filled := Friendship.hearts(Friendship.key_of(bot)) if bot else 0.0
	var col := st.heart_color if st else Color(0.9, 0.2, 0.3)
	var empty := Color(col.r, col.g, col.b, 0.22)
	var rtl := Lang.is_fa()
	for i in n:
		var x := 9.0 + i * 19.0
		if rtl:
			x = _hearts.size.x - x
		var f := clampf(filled - float(i), 0.0, 1.0)
		_heart(Vector2(x, 11), 8.0, empty)
		if f > 0.0:
			_heart(Vector2(x, 11), 8.0 * (0.55 + 0.45 * f), col)


func _heart(c: Vector2, s: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 24:
		var t := TAU * k / 24.0
		var x := 16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
		pts.append(c + Vector2(x, y) * s / 16.0)
	_hearts.draw_colored_polygon(pts, col)
