extends Node
## Central registry of swappable asset modules (autoload "AssetRegistry").
## Config: data/asset_modules.json
##   { "<type>": { "active": "<variant id>", "variants": { "<id>": "res://modules/<type>/<id>.tres" } } }
## Consumers call get_module(type) and listen to module_changed(type) if they
## can restyle live. See docs/MODULES.md.

signal module_changed(type: String, module: AssetModule)

const CONFIG_PATH := "res://data/asset_modules.json"

var config: Dictionary = {}
var _active: Dictionary = {}  ## type -> variant id
var _cache: Dictionary = {}  ## path -> AssetModule


func _init() -> void:
	# Loaded in _init so other autoloads / @tool scripts can query it early.
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			config = parsed
	for t: String in config:
		_active[t] = str((config[t] as Dictionary).get("active", ""))


func types() -> PackedStringArray:
	return PackedStringArray(config.keys())


func variants(type: String) -> PackedStringArray:
	return PackedStringArray(((config.get(type, {}) as Dictionary).get("variants", {}) as Dictionary).keys())


func active_id(type: String) -> String:
	return str(_active.get(type, ""))


func load_variant(type: String, variant_id: String) -> AssetModule:
	var path := str((((config.get(type, {}) as Dictionary).get("variants", {})) as Dictionary).get(variant_id, ""))
	if path == "":
		return null
	if not _cache.has(path):
		var res := load(path) as AssetModule
		if res == null:
			push_warning("AssetRegistry: cannot load %s module '%s' (%s)" % [type, variant_id, path])
			return null
		_cache[path] = res
	return _cache[path]


## Collections (e.g. "crop_types": every crop is its own module and ALL of
## them are in use at once) are marked "collection": true in the config.
func is_collection(type: String) -> bool:
	return bool((config.get(type, {}) as Dictionary).get("collection", false))


## Every module of a type (collections), in config order.
func all_of(type: String) -> Array[AssetModule]:
	var out: Array[AssetModule] = []
	for v in variants(type):
		var m := load_variant(type, v)
		if m:
			out.append(m)
	return out


## Adds or replaces one member of a type at runtime (e.g. swap one crop
## module for another file). Emits module_changed.
func register_variant(type: String, variant_id: String, path: String) -> bool:
	if not config.has(type):
		config[type] = {"active": variant_id, "variants": {}}
	((config[type] as Dictionary)["variants"] as Dictionary)[variant_id] = path
	var m := load_variant(type, variant_id)
	if m == null:
		return false
	module_changed.emit(type, m)
	return true


## The active style for an asset type (null if the type is unknown).
func get_module(type: String) -> AssetModule:
	return load_variant(type, active_id(type))


## Runtime swap (also used by the smoke test). Returns false if unknown.
func set_active(type: String, variant_id: String) -> bool:
	var m := load_variant(type, variant_id)
	if m == null:
		return false
	_active[type] = variant_id
	module_changed.emit(type, m)
	return true


## Every variant of every type: { "type/id": [missing paths] } for broken ones.
func validate_all() -> Dictionary:
	var bad := {}
	for t in types():
		for v in variants(t):
			var m := load_variant(t, v)
			if m == null:
				bad[t + "/" + v] = ["(module failed to load)"]
				continue
			var missing := m.validate()
			if not missing.is_empty():
				bad[t + "/" + v] = missing
	return bad
