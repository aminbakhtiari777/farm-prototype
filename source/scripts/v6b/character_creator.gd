class_name CharacterCreator
extends PanelContainer
## v6b "character_creator" module UI (Y, or the farmhouse mirror): name, body
## (incl. slim), face, hair + colour, beard, skin and a job preset. Every change
## is shown live on the farmer (camera turns to the face). Done saves the look
## with the player; the job's starter items are given once.

signal finished(look: Dictionary)

var look: Dictionary = {}
var _rows: Dictionary = {}  ## key -> Label (value)
var _name: LineEdit
var _title: Label
var _perk: Label
var _rng := RandomNumberGenerator.new()
var opened_count: int = 0
var _keys_lbl: Dictionary = {}


func _ready() -> void:
	name = "CharacterCreator"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(UIKit.PAPER, 14, 16, true))
	set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	offset_left = -440
	offset_right = -24
	offset_top = -300
	offset_bottom = 300
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 7)
	add_child(v)
	_title = UIKit.label(v, "", 24, UIKit.INK)
	var nrow := HBoxContainer.new()
	v.add_child(nrow)
	_keys_lbl["name"] = UIKit.label(nrow, "", 16, UIKit.INK)
	(_keys_lbl["name"] as Label).custom_minimum_size.x = 110
	_name = LineEdit.new()
	_name.custom_minimum_size.x = 250
	_name.max_length = 24
	_name.text_changed.connect(func(t: String) -> void: look["name"] = t.strip_edges())
	nrow.add_child(_name)
	for key in ["body", "face", "hair", "hair_color", "beard", "skin", "job"]:
		var row := HBoxContainer.new()
		v.add_child(row)
		var k := UIKit.label(row, "", 16, UIKit.INK)
		k.custom_minimum_size.x = 110
		_keys_lbl[key] = k
		_ltr(UIKit.button(row, ">" if Lang.is_fa() else "<", func() -> void: change(key, -1), "", 16))
		var val := UIKit.label(row, "", 16, Color(0.35, 0.2, 0.1))
		val.custom_minimum_size.x = 200
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_rows[key] = val
		_ltr(UIKit.button(row, "<" if Lang.is_fa() else ">", func() -> void: change(key, 1), "", 16))
	_perk = UIKit.label(v, "", 14, Color(0.4, 0.3, 0.2))
	_perk.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_perk.custom_minimum_size.x = 380
	var b := HBoxContainer.new()
	v.add_child(b)
	_keys_lbl["random"] = UIKit.button(b, "", randomize_look, "", 16)
	_keys_lbl["done"] = UIKit.button(b, "", done, "", 16)
	_keys_lbl["cancel"] = UIKit.button(b, "", cancel, "", 16)
	_rng.seed = 6066


func _player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


var _before: Dictionary = {}


func open() -> void:
	var p := _player()
	if p == null or p.vehicle != null:
		return
	if p.carried:
		p._try_place()
	p.stand_up()
	look = p.appearance.duplicate() if not p.appearance.is_empty() else CharacterLook.default_look()
	if not look.has("name") or str(look["name"]) == "":
		look["name"] = str(Settings.get_value("player_name"))
	_before = look.duplicate()
	visible = true
	opened_count += 1
	GameEvents.open_modal("character")
	GameEvents.interaction_prompt_changed.emit("")
	_frame_face()
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("character")
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	if rig:
		rig.target_offset = Vector3.ZERO
		rig.reset_behind_target()


func _frame_face() -> void:
	var p := _player()
	var rig := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	if p == null or rig == null:
		return
	var r := (p.get_node(^"Visual") as Node3D).rotation.y
	rig.target_offset = Vector3(0, 0.05, 0)
	rig.snap_view(rad_to_deg(r), -6.0, 2.6)


func change(key: String, dir: int) -> void:
	if key == "hair_color":
		var st := CharacterLook.style()
		var n := st.hair_colors.size() if st else 1
		look["hair_color"] = wrapi(int(look.get("hair_color", 0)) + dir, 0, maxi(n, 1))
	else:
		look[key] = CharacterLook.step(look, key, dir)
	if key == "job":
		var jo := CharacterLook.job_outfit(look)
		look["top"] = jo["top"]
		var p := _player()
		if p:
			p.outfit["shirt"] = jo["shirt"]
			p.outfit["pants"] = jo["pants"]
	_preview()
	refresh()


func randomize_look() -> void:
	var nm := str(look.get("name", ""))
	look = CharacterLook.random_look(_rng)
	look["name"] = nm
	_preview()
	refresh()


func _preview() -> void:
	var p := _player()
	if p:
		p.apply_look(look)


func done() -> void:
	var p := _player()
	if p:
		look["name"] = _name.text.strip_edges() if _name.text.strip_edges() != "" else str(look.get("name", ""))
		var first := not bool(look.get("starter_given", false))
		look["starter_given"] = true
		p.apply_look(look)
		if first:
			var job := CharacterLook.job(look)
			var item := str(job.get("item", ""))
			if item != "" and not GameData.item(item).is_empty():
				Economy.add_item(item, int(job.get("count", 3)))
		GameEvents.notification_requested.emit(Lang.tt("شخصیتت ذخیره شد! (Y برای تغییر)", "Character saved! (Y to change)"))
	finished.emit(look)
	close()


func cancel() -> void:
	var p := _player()
	if p and _before != look:
		p.apply_look(_before)
	close()


func refresh() -> void:
	var fa := Lang.is_fa()
	_title.text = Lang.tt("ساخت شخصیت", "Create your character")
	var names := {"name": ["نام", "Name"], "body": ["بدن", "Body"], "face": ["چهره", "Face"], "hair": ["مو", "Hair"],
		"hair_color": ["رنگ مو", "Hair colour"], "beard": ["ریش", "Beard"], "skin": ["رنگ پوست", "Skin"], "job": ["شغل", "Job"]}
	for k in names:
		if _keys_lbl.has(k):
			(_keys_lbl[k] as Label).text = str(names[k][0 if fa else 1])
	(_keys_lbl["random"] as Button).text = Lang.tt("تصادفی", "Random")
	(_keys_lbl["done"] as Button).text = Lang.tt("تمام", "Done")
	(_keys_lbl["cancel"] as Button).text = Lang.tt("انصراف", "Cancel")
	if not _name.has_focus():
		_name.text = str(look.get("name", ""))
	for key in _rows:
		var lbl := _rows[key] as Label
		if key == "hair_color":
			lbl.text = Lang.tt("رنگ %s", "Shade %s") % Lang.digits(str(int(look.get("hair_color", 0)) + 1))
			lbl.add_theme_color_override(&"font_color", CharacterLook.hair_color(look).lightened(0.15))
		else:
			lbl.text = CharacterLook.label(key, str(look.get(key, "")))
	var j := CharacterLook.job(look)
	_perk.text = (Lang.tt("ویژگی شغل: ", "Job perk: ") + str(j.get("perk_fa" if fa else "perk_en", ""))) if not j.is_empty() else ""


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"menu"):
		cancel()
		get_viewport().set_input_as_handled()


## Arrow buttons keep their direction in the Persian (RTL) layout.
static func _ltr(b: Button) -> Button:
	b.text_direction = Control.TEXT_DIRECTION_LTR
	return b
