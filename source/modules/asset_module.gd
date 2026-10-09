class_name AssetModule
extends Resource
## Base class for every swappable asset module (trees, rocks, terrain, ...).
## A module is a small Resource (.tres) inside res://modules/<type>/ that
## describes one *style* of that asset type. Gameplay code never hard-codes
## asset paths: it asks AssetRegistry.get_module("<type>") and reads the
## fields of the returned style. Swapping a style = change the "active" entry
## in data/asset_modules.json (or call AssetRegistry.set_active at runtime).
##
## Interface every module provides:
##   id / type / display_name   - identification
##   get_variant(season) -> Dictionary   - per-season parameters ({} = none)
##   asset_paths() -> PackedStringArray  - files the module depends on
##   validate() -> PackedStringArray     - missing files (empty = OK)

@export var id: String = ""
@export var type: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""


func get_variant(_season: String) -> Dictionary:
	return {}


func asset_paths() -> PackedStringArray:
	return PackedStringArray()


func validate() -> PackedStringArray:
	var missing := PackedStringArray()
	for p in asset_paths():
		if not ResourceLoader.exists(p):
			missing.append(p)
	return missing
