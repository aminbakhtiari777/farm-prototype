class_name WebStorage
extends RefCounted
## Browser localStorage helper (web builds only). v3 found that writes to
## user:// on the web were not reliably flushed to IndexedDB (a save made
## during play was gone after reloading the page), so saves and settings are
## mirrored into localStorage, which the browser persists synchronously.


static func available() -> bool:
	return OS.has_feature("web")


static func set_item(key: String, text: String) -> bool:
	if not OS.has_feature("web"):
		return false
	JavaScriptBridge.eval("try { localStorage.setItem(%s, %s); } catch (e) { console.warn('localStorage: ' + e); }" % [JSON.stringify(key), JSON.stringify(text)], true)
	return get_item(key) == text


static func get_item(key: String) -> String:
	if not OS.has_feature("web"):
		return ""
	var v: Variant = JavaScriptBridge.eval("(function(){ try { var v = localStorage.getItem(%s); return v === null ? '' : v; } catch (e) { return ''; } })()" % JSON.stringify(key), true)
	return str(v) if v != null else ""


static func has_item(key: String) -> bool:
	return get_item(key) != ""


static func remove_item(key: String) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("try { localStorage.removeItem(%s); } catch (e) {}" % JSON.stringify(key), true)
