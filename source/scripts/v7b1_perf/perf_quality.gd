class_name PerfQuality
extends RefCounted
## Resolves the active QualityStyle from Settings["quality"] ("auto" / "low" /
## "medium" / "high"). Auto = medium on the web, high on desktop; steps down
## when AutoLod reports sustained low fps. Pure helpers - no Node.


static func key() -> String:
	return str(Settings.get_value("quality"))


static func is_auto() -> bool:
	return key() == "auto" or key() == ""


static func style_id() -> String:
	var k := key()
	if k in ["low", "medium", "high"]:
		return k
	return "medium" if OS.has_feature("web") else "high"


static var _cache_id: String = ""
static var _cache_style: QualityStyle = null


## Cached: called per townsperson per physics tick.
static func style() -> QualityStyle:
	var id := style_id()
	if _cache_style != null and id == _cache_id:
		return _cache_style
	var m := AssetRegistry.load_variant("quality", id) as QualityStyle
	if m == null:
		m = Modules.style("quality") as QualityStyle
	_cache_id = id
	_cache_style = m
	return m


## Module hot-swap (Modules.on_swap) drops the cache.
static func invalidate() -> void:
	_cache_style = null


## Cycle Auto -> Low -> Medium -> High -> Auto. Returns the new key.
static func cycle() -> String:
	var order := ["auto", "low", "medium", "high"]
	var i := order.find(key())
	var nxt: String = order[(maxi(i, 0) + 1) % order.size()]
	Settings.set_value("quality", nxt)
	return nxt


static func label() -> String:
	var k := key()
	match k:
		"low":
			return Lang.loc_ui("Graphics: Low")
		"medium":
			return Lang.loc_ui("Graphics: Medium")
		"high":
			return Lang.loc_ui("Graphics: High")
		_:
			return Lang.loc_ui("Graphics: Auto")
