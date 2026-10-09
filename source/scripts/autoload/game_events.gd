extends Node
## Global signal bus (autoload "GameEvents").
##
## Gameplay systems emit here and UI listens, so the HUD never needs direct
## references to the player or animals. Add new game-wide events here
## (crop harvested, day ended, item picked up, ...).

## Emitted when the closest usable interactable changes. Empty text = hide prompt.
@warning_ignore("unused_signal")
signal interaction_prompt_changed(text: String)

## Emitted when an animal's affection changes.
@warning_ignore("unused_signal")
signal affection_changed(animal_name: String, value: int, max_value: int)

## Emitted for short, transient messages ("Baa!", "Affection maxed!", ...).
@warning_ignore("unused_signal")
signal notification_requested(text: String)

## Emitted when something asks the HUD to open the shop.
@warning_ignore("unused_signal")
signal shop_requested

## v5a: open the shop panel for a specific shop / stall (Shops.shop(id)).
@warning_ignore("unused_signal")
signal shop_requested_for(shop_id: String)

## v5a: open the crafting panel for a station ("workbench" / "stove").
@warning_ignore("unused_signal")
signal crafting_requested(station: String)

## v5a: something was crafted / cooked (recipe id).
@warning_ignore("unused_signal")
signal crafted(recipe_id: String)

## v5b: a home stove opens the hands-on cooking panel (CookingPanel).
@warning_ignore("unused_signal")
signal cooking_requested(stove: Node3D)

## Emitted when a modal UI (shop) closes; the player ignores input briefly.
@warning_ignore("unused_signal")
signal ui_closed

## The player walked into / out of a building (Building node).
@warning_ignore("unused_signal")
signal building_entered(building: Node3D)
@warning_ignore("unused_signal")
signal building_exited(building: Node3D)

## A fish was caught / a shell picked up (item id).
@warning_ignore("unused_signal")
signal item_collected(item_id: String)

## Player stamina changed (value, max, exhausted).
@warning_ignore("unused_signal")
signal stamina_changed(value: float, max_value: float, exhausted: bool)

## Fishing minigame state for the HUD: "", "casting", "waiting", "bite", "caught", "missed".
@warning_ignore("unused_signal")
signal fishing_state_changed(state: String)

## Settings changed (shadows, sound, hints...). Key + new value.
@warning_ignore("unused_signal")
signal setting_changed(key: String, value: Variant)

## Request to open a UI panel by name ("settings", "controls", "inventory").
@warning_ignore("unused_signal")
signal ui_panel_requested(panel: String)

## Names of modal panels currently open (shop, settings, controls, ...).
var _open_panels: Dictionary = {}

## True while a modal UI (shop) is open: the player does not move or interact.
var ui_open: bool = false



## Modal panels call these; `ui_open` stays true while any panel is open.
func open_modal(panel: String) -> void:
	_open_panels[panel] = true
	ui_open = true


func close_modal(panel: String) -> void:
	_open_panels.erase(panel)
	ui_open = not _open_panels.is_empty()
	if not ui_open:
		ui_closed.emit()


func close_all_modals() -> void:
	_open_panels.clear()
	ui_open = false
	ui_closed.emit()


func is_modal_open(panel: String = "") -> bool:
	return ui_open if panel == "" else _open_panels.has(panel)
