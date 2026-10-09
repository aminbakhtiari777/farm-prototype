class_name CraftingPanel
extends PanelContainer
## v5a crafting / cooking UI. Opens on GameEvents.crafting_requested(station)
## from the farm workshop bench ("workbench") or a home stove ("stove").
## Lists the "recipes" module collection for that station with inputs and
## what you have; Craft / Cook buttons. Close with E, Esc or the button.

var station: String = "workbench"
var _title: Label
var _info: Label
var _list: VBoxContainer


func _ready() -> void:
	name = "CraftingPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.12, 0.09, 0.07, 0.92), 12, 18))
	set_anchors_preset(Control.PRESET_CENTER)
	offset_left = -380
	offset_right = 380
	offset_top = -230
	offset_bottom = 230
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	_title = UIKit.label(head, "Workbench", 24, UIKit.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button(head, "Close (E)", close, "Close")
	_info = UIKit.label(v, "", 14, Color(0.85, 0.8, 0.7))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 340
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(sc)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"separation", 6)
	sc.add_child(_list)
	GameEvents.crafting_requested.connect(open)
	Economy.inventory_changed.connect(refresh)
	PowerGrid.power_changed.connect(func(_on: bool) -> void: refresh())


func open(which: String) -> void:
	station = which
	visible = true
	GameEvents.open_modal("crafting")
	GameEvents.interaction_prompt_changed.emit("")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("crafting")


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed(&"interact") or event.is_action_pressed(&"menu"):
		close()
		get_viewport().set_input_as_handled()


func refresh() -> void:
	if not visible:
		return
	if station == "stove":
		var ks := Modules.style("kitchen") as KitchenStyle
		_title.text = "Kitchen stove"
		_info.text = "Cook a meal and eat it right away (restores stamina). Stove: %s%s" % [
				ks.stove if ks else "?", ("  -  no power!" if ks and ks.needs_power() and not PowerGrid.power_on else "")]
	else:
		var cs := Modules.style("crafting") as CraftingStyle
		_title.text = "Workbench"
		_info.text = "Craft goods from materials (carpenter, blacksmith, mason, electrical shop). Each craft takes %d game minutes." % int(cs.craft_minutes if cs else 20.0)
	for c in _list.get_children():
		c.queue_free()
	for r in Crafting.recipes(station):
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 10)
		_list.add_child(row)
		var left := VBoxContainer.new()
		left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(left)
		var out := r.display_name
		if r.is_meal():
			out += "   (+%d stamina)" % int(r.stamina)
		elif r.output_sell > 0:
			out += "   x%d  ·  sells %d G" % [r.output_count, r.output_sell]
		else:
			out += "   x%d" % r.output_count
		UIKit.label(left, out, 17, Color(1, 0.95, 0.85))
		var have: PackedStringArray = []
		for k in r.inputs:
			have.append("%s %d/%d" % [GameData.item_name(str(k)), Economy.count(str(k)), int(r.inputs[k])])
		var why := Crafting.missing(r)
		UIKit.label(left, ("Needs: " + ", ".join(have)) if not have.is_empty() else "Needs: nothing", 13,
				Color(0.6, 0.9, 0.6) if why == "" else Color(0.95, 0.6, 0.5))
		var btn := UIKit.button(row, "Cook" if station == "stove" else "Craft", func() -> void: _do(r), r.description)
		btn.disabled = why != ""


func _do(r: RecipeDef) -> void:
	GameEvents.notification_requested.emit(Crafting.craft(r, get_tree()))
	refresh()
