class_name V6bWorld
extends Node3D
## v6b world features, each its own module node: character creator +
## wardrobe UI, drivable cars, ambulance, police patrol, wood pickup, town
## square landmark, fruit gardens, extra lots, pushable boxes, sheep herding,
## digging, the daily yard routine, shadows and cloud shadows, gym polish.

var ui: CanvasLayer
var creator: CharacterCreator
var wardrobe: WardrobePanel
var vehicles: Vehicles
var ambulance: AmbulanceService
var police: PolicePatrol
var pickup: WoodPickup
var landmark: TownLandmark
var gardens: FruitGardens
var lots: TownLots
var pushables: Pushables
var herding: Herding
var digging: Digging
var routine: YardRoutine
var clouds: CloudShadows


## Theme for v6b panels on their own CanvasLayers: they don't inherit the HUD
## theme, and the web build has no system fonts to fall back on, so they need
## the default font + Persian fallback (fonts module) explicitly.
static func ui_theme() -> Theme:
	var th := Theme.new()
	th.default_font = Lang.ui_font()
	return th


func _ready() -> void:
	ui = CanvasLayer.new()
	ui.name = "V6bUI"
	ui.layer = 6
	add_child(ui)
	creator = CharacterCreator.new()
	creator.add_to_group(&"character_creator")
	creator.theme = ui_theme()
	ui.add_child(creator)
	wardrobe = WardrobePanel.new()
	wardrobe.add_to_group(&"wardrobe_panel")
	wardrobe.theme = ui_theme()
	ui.add_child(wardrobe)
	vehicles = _add(Vehicles.new(), "Vehicles")
	ambulance = _add(AmbulanceService.new(), "AmbulanceService")
	police = _add(PolicePatrol.new(), "PolicePatrol")
	pickup = _add(WoodPickup.new(), "WoodPickup")
	landmark = _add(TownLandmark.new(), "TownLandmark")
	gardens = _add(FruitGardens.new(), "FruitGardens")
	lots = _add(TownLots.new(), "TownLots")
	pushables = _add(Pushables.new(), "Pushables")
	herding = _add(Herding.new(), "Herding")
	digging = _add(Digging.new(), "Digging")
	routine = _add(YardRoutine.new(), "YardRoutine")
	clouds = _add(CloudShadows.new(), "CloudShadows")
	# Realistic shadows at start (SettingsPanel re-applies on each toggle).
	_apply_shadow_rig.call_deferred()
	Modules.on_swap("shadows", self, func(_m: AssetModule) -> void: _apply_shadow_rig())
	# Signs + street names follow the language toggle.
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			SignText.refresh(get_tree()))


func _apply_shadow_rig() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var sun := scene.get_node_or_null(^"Sun") as DirectionalLight3D
	# High quality = 4 splits (SettingsPanel level 0); Low/Off are left alone.
	if sun and sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS:
		ShadowRig.apply(sun, 0)


func _add(n: Node, nm: String) -> Node:
	n.name = nm
	add_child(n)
	return n


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if event.is_action(&"character_panel"):
		if creator.visible:
			creator.cancel()
		elif not GameEvents.ui_open and Modules.style("character_creator") != null:
			var p := get_tree().get_first_node_in_group(&"player") as Player
			if p and p.vehicle == null:
				creator.open()
		get_viewport().set_input_as_handled()
