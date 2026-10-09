class_name V7b1TrafficWorld
extends Node3D
## v7b.1 traffic world wiring (traffic worker): traffic lights + cameras +
## officer, enforcement, road markings, signs, the road to the new city,
## brighter street lighting, the impound lot, the licence desk + panel, the car
## dealership, NPC traffic, the bus line (stops, NPC bus, drivable bus), car
## sounds and the classy cafe-lounge / disco. Keys: F3 licence panel,
## 8 / 9 indicators (in a car).

var ui: CanvasLayer
var signals: TrafficSignals
var rules: TrafficRules
var markings: RoadMarkings
var signs: TrafficSigns
var new_city: NewCityRoad
var lighting: StreetLighting
var impound: Impound
var license_office: LicenseOffice
var license_panel: LicensePanel
var dealership: Dealership
var dealership_panel: DealershipPanel
var npc_traffic: NpcTraffic
var transit: Transit
var audio: CarAudio
var lounge: CafeLounge


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.name = "TrafficUI"
	ui.layer = 6
	add_child(ui)
	signals = _add(TrafficSignals.new(), "TrafficSignals")
	impound = _add(Impound.new(), "Impound")
	rules = TrafficRules.new()
	rules.signals = signals
	rules.impound = impound
	_add(rules, "TrafficRules")
	TrafficRules._signals_ref = weakref(signals)
	RoadCar.traffic_gate = TrafficRules.ai_gate
	markings = _add(RoadMarkings.new(), "RoadMarkings")
	signs = _add(TrafficSigns.new(), "TrafficSigns")
	new_city = _add(NewCityRoad.new(), "NewCityRoad")
	lighting = _add(StreetLighting.new(), "StreetLighting")
	license_panel = LicensePanel.new()
	ui.add_child(license_panel)
	license_office = LicenseOffice.new()
	license_office.panel = license_panel
	_add(license_office, "LicenseOffice")
	dealership_panel = DealershipPanel.new()
	ui.add_child(dealership_panel)
	dealership = Dealership.new()
	dealership.panel = dealership_panel
	dealership_panel.dealer = dealership
	_add(dealership, "Dealership")
	npc_traffic = _add(NpcTraffic.new(), "NpcTraffic")
	transit = _add(Transit.new(), "Transit")
	audio = _add(CarAudio.new(), "CarAudio")
	lounge = CafeLounge.new()
	_add(lounge, "CafeLounge")
	_link.call_deferred()
	if not InputMap.has_action(&"license_panel"):
		InputMap.add_action(&"license_panel")
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F3
		InputMap.action_add_event(&"license_panel", ev)


func _add(n: Node, nm: String) -> Node:
	n.name = nm
	add_child(n)
	return n


## After V7aWorld / V7bWorld are ready: cafe + staffing for the lounge, the
## v7a CityFund speed rule is replaced by the per-street limits, existing AI
## vehicles join "road_cars" (gap keeping + engine sounds).
func _link() -> void:
	var sc := get_tree().current_scene
	var v7b := sc.find_child("V7bWorld", true, false) as V7bWorld if sc else null
	if v7b:
		lounge.cafe = v7b.cafe
		lounge.staffing = v7b.staffing
		lounge.rebuild()
	var v7a := sc.find_child("V7aWorld", true, false) as V7aWorld if sc else null
	if v7a and v7a.fund and "speed_check" in v7a.fund:
		v7a.fund.set(&"speed_check", false)
	_tag_road_cars.call_deferred()


func _tag_road_cars() -> void:
	var sc := get_tree().current_scene
	if sc == null:
		return
	for n in sc.find_children("*", "RoadCar", true, false):
		var rc := n as RoadCar
		if rc and not rc.is_in_group(&"road_cars"):
			rc.add_to_group(&"road_cars")
			if not rc.has_meta(&"voice"):
				rc.set_meta(&"voice", rc.model_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"license_panel") and not GameEvents.ui_open:
		license_panel.open(false)
		get_viewport().set_input_as_handled()


## Tests: everything automatic off (enforcement, signals cycling, NPC cars, bus, disco crowd).
func set_auto(on: bool) -> void:
	rules.auto = on
	signals.auto = on
	TrafficRules.ai_enabled = on
	npc_traffic.set_active(on)
	lounge.auto = on
	lounge.set_staff(on)
	if not on:
		lounge.send_home()
	transit.set_service(on)
