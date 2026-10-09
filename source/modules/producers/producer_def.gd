class_name ProducerDef
extends AssetModule
## v5c roles (collection "producers"): a workplace that produces goods every
## morning and restocks a shop. Inputs are taken from the town stock first
## (the tailor spins the wool farmers sold, the carpenter turns planks into
## furniture); missing inputs scale the output down. If every worker with one
## of `worker_jobs` is ill that day, nothing is produced (shortage).
## Consumers: Market (daily production, targets), Shops (what a shop sells),
## GameData (new items), PricesPanel.

@export var name_fa: String = ""
## Shop that sells the output ("carpenter", "grocery", "stall:fish", "livestock", ...).
@export var shop: String = ""
@export var worker_jobs: PackedStringArray = PackedStringArray()
## item id -> units per day.
@export var outputs: Dictionary = {}
## item id -> units per day consumed from the town stock.
@export var inputs: Dictionary = {}
## New items this producer introduces: id -> GameData item dictionary.
@export var items: Dictionary = {}
@export var sort_order: int = 0


func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
