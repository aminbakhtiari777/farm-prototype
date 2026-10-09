class_name InventoryPanel
extends PanelContainer
## Bag (I or the Bag button). Lists items with counts and today's sell price,
## the watering-can level and the selected seed.

var _list: GridContainer
var _water: Label
var _seed: Label


func _ready() -> void:
	name = "InventoryPanel"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_theme_stylebox_override(&"panel", UIKit.style(Color(0.08, 0.07, 0.06, 0.84), 10, 14))
	anchor_left = 1.0
	anchor_right = 1.0
	offset_left = -360.0
	offset_right = -16.0
	offset_top = 64.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 6)
	add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := UIKit.label(head, "Bag", 20, UIKit.GOLD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIKit.button(head, "x", close, "Close (I)")
	_water = UIKit.label(v, "", 15, Color(0.6, 0.85, 1.0))
	_seed = UIKit.label(v, "", 15, Color(0.75, 1.0, 0.7))
	UIKit.button(v, "Choose seed (Q)", Economy.cycle_seed)
	v.add_child(HSeparator.new())
	_list = GridContainer.new()
	_list.columns = 3
	_list.add_theme_constant_override(&"h_separation", 14)
	v.add_child(_list)
	Economy.inventory_changed.connect(refresh)
	Economy.water_changed.connect(func(_w: int, _c: int) -> void: refresh())
	Economy.selected_seed_changed.connect(func(_s: String) -> void: refresh())


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func close() -> void:
	visible = false


func refresh() -> void:
	if not visible:
		return
	_water.text = "Watering can: %d / %d" % [Economy.water, Economy.can_capacity()]
	var sid := Economy.selected_seed
	_seed.text = "Seed: %s" % ("none" if sid == "" else "%s x%d" % [GameData.item_name(sid), Economy.count(sid)])
	for c in _list.get_children():
		c.queue_free()
	var ids: Array = Economy.inventory.keys()
	ids.sort()
	if ids.is_empty():
		UIKit.label(_list, "(empty)", 15, Color(0.8, 0.8, 0.8))
		return
	for id: String in ids:
		UIKit.label(_list, GameData.item_name(id), 15, Color(1, 0.95, 0.88))
		UIKit.label(_list, "x%d" % Economy.count(id), 15, Color(1, 1, 1))
		var price := Economy.sell_price(id)
		UIKit.label(_list, ("%d G" % price) if price > 0 else "", 14, UIKit.GOLD)
