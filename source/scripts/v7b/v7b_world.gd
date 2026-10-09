class_name V7bWorld
extends Node3D
## v7b world wiring: a chattier town (Chatter + chat log), the terrace cafe
## with bartender + DJ (TerraceCafe, menu, tipsiness), the mechanic and
## deeper driving (gears, headlights, fuel, wear), passengers, camping, the
## daily newspaper and personality-driven haggling. Staffing keeps the cafe
## and garage posts filled (a stand-in covers when someone is away).
## Keys: 4 newspaper, 5 chat log, 6 camp, 7 haggle (H / 3 / Shift / Ctrl in the car).

var ui: CanvasLayer
var staffing: Staffing
var chatter: Chatter
var chat_log: ChatLogPanel
var driving: Driving
var cafe: TerraceCafe
var tipsy: Tipsy
var menu_panel: CafeMenuPanel
var mechanic: MechanicShop
var mechanic_panel: MechanicPanel
var passengers: Passengers
var camping: Camping
var newspaper: Newspaper
var newspaper_panel: NewspaperPanel
var haggle: HagglePanel


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.name = "V7bUI"
	ui.layer = 6
	add_child(ui)
	staffing = _add(Staffing.new(), "Staffing")
	chatter = _add(Chatter.new(), "Chatter")
	chat_log = ChatLogPanel.new()
	ui.add_child(chat_log)
	driving = _add(Driving.new(), "Driving")
	tipsy = _add(Tipsy.new(), "Tipsy")
	menu_panel = CafeMenuPanel.new()
	ui.add_child(menu_panel)
	cafe = TerraceCafe.new()
	cafe.staffing = staffing
	cafe.menu_panel = menu_panel
	cafe.tipsy = tipsy
	menu_panel.cafe = cafe
	_add(cafe, "TerraceCafe")
	mechanic_panel = MechanicPanel.new()
	ui.add_child(mechanic_panel)
	mechanic = MechanicShop.new()
	mechanic.staffing = staffing
	mechanic.driving = driving
	mechanic.panel = mechanic_panel
	mechanic_panel.shop = mechanic
	_add(mechanic, "MechanicShop")
	passengers = Passengers.new()
	passengers.staffing = staffing
	_add(passengers, "Passengers")
	camping = _add(Camping.new(), "Camping")
	newspaper_panel = NewspaperPanel.new()
	ui.add_child(newspaper_panel)
	newspaper = Newspaper.new()
	newspaper.panel = newspaper_panel
	newspaper_panel.news = newspaper
	_add(newspaper, "Newspaper")
	haggle = HagglePanel.new()
	ui.add_child(haggle)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			V7bKit.refresh_signs(get_tree()))
	V7bKit.refresh_signs.call_deferred(get_tree())


func _add(n: Node, nm: String) -> Node:
	n.name = nm
	add_child(n)
	return n


func _player() -> Player:
	return V7bKit.player(get_tree())


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var p := _player()
	if event.is_action(&"chat_log"):
		chat_log.toggle()
		get_viewport().set_input_as_handled()
		return
	if GameEvents.ui_open:
		return
	if event.is_action(&"newspaper"):
		newspaper.read()
		get_viewport().set_input_as_handled()
	elif event.is_action(&"camp") and p:
		if p.vehicle:
			GameEvents.notification_requested.emit(Lang.tt("اول از ماشین پیاده شو.", "Get out of the car first."))
		else:
			camping.toggle(p.global_position)
		get_viewport().set_input_as_handled()
	elif event.is_action(&"haggle") and p and p.vehicle == null:
		haggle.start(HagglePanel.partner(get_tree(), p.global_position))
		get_viewport().set_input_as_handled()
