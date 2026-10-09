extends Node
## Loads res://data/game_data.json (seasons, weather, prices, tools, fish) and
## merges every crop module from AssetRegistry (type "crop_types"). Autoload
## "GameData". Edit the JSON for non-crop content; add a crop by adding
## res://modules/crop_types/<id>/<id>.tres and registering it in
## data/asset_modules.json.

const PATH := "res://data/game_data.json"

var data: Dictionary = {}
## crop_id -> CropDef (live view of the crop_types collection).
var crops: Dictionary = {}
## item_id -> ToolDef (live view of the tool_types collection).
var tools: Dictionary = {}
## recipe_id -> RecipeDef (v5a "recipes" collection: workbench + stove).
var recipes: Dictionary = {}


func _init() -> void:
	_load_json()
	_rebuild_crops()
	_rebuild_tools()
	_rebuild_module_items()


func _ready() -> void:
	# AssetRegistry is an autoload sibling; reconnect so live swaps refresh.
	if AssetRegistry:
		AssetRegistry.module_changed.connect(func(t: String, _m: AssetModule) -> void:
			if t == "crop_types":
				_rebuild_crops()
			elif t == "tool_types":
				_rebuild_tools()
			elif t in ["recipes", "workplaces", "ingredients", "producers", "livestock", "kitchenware", "dry_trees", "fishing_gear", "deep_sea", "fruit_gardens", "digging"]:
				_rebuild_module_items())


func _load_json() -> void:
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		data = parsed
	else:
		push_error("GameData: could not parse %s" % PATH)


func _rebuild_crops() -> void:
	crops.clear()
	var items: Dictionary = data.get("items", {})
	# Drop any previous crop seed / produce entries so a live swap can't leave
	# orphans; keep tools, fish, shells, fertilizer, ...
	for k in items.keys():
		var it: Dictionary = items[k]
		if it.get("type") == "seed" or it.has("crop_of") or it.has("crop"):
			items.erase(k)
	var loop := Engine.get_main_loop() as SceneTree
	var reg: Node = loop.root.get_node_or_null(^"AssetRegistry") if loop and loop.root else null
	if reg == null:
		# _init runs before the SceneTree exists: load from the JSON config.
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_modules.json"))
		for cid in (cfg.get("crop_types", {}).get("variants", {}) as Dictionary):
			var path: String = cfg["crop_types"]["variants"][cid]
			var crop := load(path) as CropDef
			if crop:
				_register_crop(crop, items)
	else:
		for cid: String in reg.call("variants", "crop_types"):
			var crop := reg.call("load_variant", "crop_types", cid) as CropDef
			if crop:
				_register_crop(crop, items)
	data["items"] = items
	var view := {}
	for cid in crops:
		view[cid] = (crops[cid] as CropDef).to_game_data()
	data["crops"] = view


func _collection(type: String) -> Array[Resource]:
	var out: Array[Resource] = []
	var loop := Engine.get_main_loop() as SceneTree
	var reg: Node = loop.root.get_node_or_null(^"AssetRegistry") if loop and loop.root else null
	if reg == null:
		var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_modules.json"))
		var vars: Dictionary = cfg.get(type, {}).get("variants", {})
		for vid in vars:
			var r := load(str(vars[vid]))
			if r:
				out.append(r)
	else:
		for vid: String in reg.call("variants", type):
			var r: Resource = reg.call("load_variant", type, vid)
			if r:
				out.append(r)
	return out


## Tools are a module collection too (modules/tool_types/*.tres).
func _rebuild_tools() -> void:
	tools.clear()
	var items: Dictionary = data.get("items", {})
	for k in items.keys():
		if (items[k] as Dictionary).has("tool_kind"):
			items.erase(k)
	for r in _collection("tool_types"):
		var t := r as ToolDef
		if t == null:
			continue
		tools[t.item_id] = t
		var extra := t.to_items()
		for k in extra:
			items[k] = extra[k]
	data["items"] = items


## v5a: items that come from modules - shop goods of the "workplaces" module
## (materials, outfits, jewellery) and crafted outputs of the "recipes"
## collection. Marked "module_item" so a live swap replaces them cleanly.
func _rebuild_module_items() -> void:
	var items: Dictionary = data.get("items", {})
	for k in items.keys():
		if (items[k] as Dictionary).get("module_item", false):
			items.erase(k)
	recipes.clear()
	for r in _collection("recipes"):
		var rec := r as RecipeDef
		if rec == null:
			continue
		recipes[rec.id] = rec
		var extra := rec.to_items()
		for k in extra:
			if not items.has(k):
				var it: Dictionary = extra[k]
				it["module_item"] = true
				items[k] = it
	# v5b: cooking ingredients (collection "ingredients") are shop items.
	for r in _collection("ingredients"):
		if r and r.has_method("to_items"):
			var extra2: Dictionary = r.call("to_items")
			for k in extra2:
				if not items.has(k):
					items[k] = extra2[k]
	# v5c: producer goods (furniture, shears, milk pail) and livestock items
	# (milk, chicken feed, hay) are module items too.
	for t in ["producers", "livestock", "kitchenware"]:
		for r3 in _collection(t):
			if r3 and r3.has_method("to_items"):
				var extra3: Dictionary = r3.call("to_items")
				for k in extra3:
					if not items.has(k):
						items[k] = extra3[k]
	# v6a: items from single (active) modules: firewood + dry wood (dry_trees),
	# the pro rod (fishing_gear), deep-sea fish (deep_sea).
	for t2 in ["dry_trees", "fishing_gear", "deep_sea", "fruit_gardens", "digging"]:  # v6b: orchard fruit, dug-up finds
		var r4: Resource = _single(t2)
		if r4 and r4.has_method("to_items"):
			var extra4: Dictionary = r4.call("to_items")
			for k in extra4:
				if not items.has(k):
					items[k] = extra4[k]
	var wp: Resource = _single("workplaces")
	if wp and wp.get("items") is Dictionary:
		var shop_items: Dictionary = wp.get("items")
		for k in shop_items:
			if not items.has(k):
				var it2: Dictionary = (shop_items[k] as Dictionary).duplicate()
				it2["module_item"] = true
				items[k] = it2
	data["items"] = items


func _single(type: String) -> Resource:
	var loop := Engine.get_main_loop() as SceneTree
	var reg: Node = loop.root.get_node_or_null(^"AssetRegistry") if loop and loop.root else null
	if reg != null:
		return reg.call("get_module", type)
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/asset_modules.json"))
	var entry: Dictionary = cfg.get(type, {})
	var path := str((entry.get("variants", {}) as Dictionary).get(str(entry.get("active", "")), ""))
	return load(path) if path != "" else null


func tool_def(item_id: String) -> ToolDef:
	return tools.get(item_id) as ToolDef


func _register_crop(crop: CropDef, items: Dictionary) -> void:
	crops[crop.id] = crop
	var extras := crop.to_items()
	for k in extras:
		items[k] = extras[k]


func seasons() -> Array:
	return data.get("seasons", [])


func season(index: int) -> Dictionary:
	var list := seasons()
	return list[posmod(index, list.size())] if not list.is_empty() else {}


func weather(id: String) -> Dictionary:
	return data.get("weather", {}).get(id, {})


func crop(id: String) -> Dictionary:
	return data.get("crops", {}).get(id, {})


func crop_def(id: String) -> CropDef:
	return crops.get(id) as CropDef


func crop_ids() -> PackedStringArray:
	return PackedStringArray(crops.keys())


func item(id: String) -> Dictionary:
	return data.get("items", {}).get(id, {})


func items() -> Dictionary:
	return data.get("items", {})


func calendar() -> Dictionary:
	return data.get("calendar", {})


func item_name(id: String) -> String:
	return str(item(id).get("name", id.capitalize()))
