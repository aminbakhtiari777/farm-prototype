class_name PeoplePanel
extends PanelContainer
## v5a town directory (J, or ask the City Hall clerk): every household with
## its residents - name, age, job / workplace and family ties - from the
## "population" module.

var _list: VBoxContainer


func _ready() -> void:
	name = "PeoplePanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(UIKit.PAPER, 12, 18, true))
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -420
	offset_right = 420
	offset_top = -260
	offset_bottom = 260
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIKit.label(head, Lang.tt("فهرست ساکنان شهر", "Town Directory"), 24, UIKit.INK)
	t.name = "Title"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button(head, Lang.tt("بستن (J)", "Close (J)"), close, "Close")
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 440
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(_list)
	GameEvents.ui_panel_requested.connect(func(p: String) -> void:
		if p == "people":
			open())


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	GameEvents.open_modal("people")
	GameEvents.interaction_prompt_changed.emit("")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("people")


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed(&"menu") or event.is_action_pressed(&"interact")):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	for c in _list.get_children():
		c.queue_free()
	var title := find_child("Title", true, false) as Label
	if title:
		title.text = Lang.tt("فهرست ساکنان شهر", "Town Directory")
	# v7b.1 families module: household kinds, jobs / school / retired, Persian or English.
	if Families.fill_directory(_list):
		return
	var homes := Population.households()
	UIKit.label(_list, "%d residents in %d homes" % [Population.residents().size(), homes.size()], 14, Color(0.4, 0.3, 0.2))
	for h: String in homes:
		var members: Array = homes[h]
		var b := TownLayout.building(h)
		UIKit.label(_list, "%s family  -  %s" % [str(members[0].get("surname", "")), str(b.get("address", h))], 18, UIKit.INK)
		for r in members:
			var d: Dictionary = r
			UIKit.label(_list, "    %s (%d), %s  -  %s" % [d.get("name", "?"), int(d.get("age", 0)), d.get("role", ""), Population.job_text(d)], 14, Color(0.3, 0.22, 0.14))
