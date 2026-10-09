class_name Modules
extends RefCounted
## Static access to the active asset modules. Works at runtime (through the
## AssetRegistry autoload) and in the editor / @tool scripts (reads the
## config directly), so consumers never need to know where assets live.

static var _fallback: Dictionary = {}


static func style(type: String) -> AssetModule:
	var loop := Engine.get_main_loop() as SceneTree
	if loop and loop.root:
		var reg := loop.root.get_node_or_null(^"AssetRegistry")
		if reg:
			return reg.call("get_module", type) as AssetModule
	if _fallback.is_empty():
		var f := FileAccess.open("res://data/asset_modules.json", FileAccess.READ)
		if f:
			_fallback = JSON.parse_string(f.get_as_text())
	var entry: Dictionary = _fallback.get(type, {})
	var path := str((entry.get("variants", {}) as Dictionary).get(str(entry.get("active", "")), ""))
	return load(path) as AssetModule if path != "" else null


## All modules of a collection type (e.g. every crop in "crop_types").
static func all(type: String) -> Array[AssetModule]:
	var loop := Engine.get_main_loop() as SceneTree
	if loop and loop.root:
		var reg := loop.root.get_node_or_null(^"AssetRegistry")
		if reg:
			return reg.call("all_of", type)
	return []


## Connects `callable(module)` to live swaps of `type` (no-op in the editor).
static func on_swap(type: String, owner: Node, callable: Callable) -> void:
	var loop := Engine.get_main_loop() as SceneTree
	if loop == null or loop.root == null:
		return
	var reg := loop.root.get_node_or_null(^"AssetRegistry")
	if reg == null:
		return
	# v6b: hold the owner by id (not as a captured object) and drop the
	# connection once the owner is gone - v6b rebuilds nodes on swap (sheep,
	# cars), which used to leave "lambda capture was freed" errors behind.
	var oid := owner.get_instance_id()
	var holder: Array = []
	var cb := func(t: String, m: AssetModule) -> void:
		var o := instance_from_id(oid)
		if o == null or not is_instance_valid(o):
			if not holder.is_empty() and reg.is_connected(&"module_changed", holder[0]):
				reg.disconnect(&"module_changed", holder[0])
			return
		if t == type:
			callable.call(m)
	holder.append(cb)
	reg.connect(&"module_changed", cb)
