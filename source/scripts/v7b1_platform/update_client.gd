class_name UpdateClient
extends Node
## Checks a remote update manifest (optional). Offline / declined / placeholder
## URL → keep playing the installed version. Coordinates with the v5d module
## manifest and the perf worker's split resource packs (same .pck mechanism).

signal check_finished(status: String, info: Dictionary)
## status: "offline" | "up_to_date" | "update_available" | "declined" | "error" | "disabled"

var last_status: String = "disabled"
var last_info: Dictionary = {}
var declined: bool = false
var _http: HTTPRequest


func _ready() -> void:
	name = "UpdateClient"
	_http = HTTPRequest.new()
	_http.timeout = 8.0
	add_child(_http)
	_http.request_completed.connect(_on_http)


func installed_version() -> String:
	return GameBrand.version()


## Kick off a check. Never blocks play. Safe on web (no foreign request unless
## Amin set a real manifest_url — placeholder / empty stays silent).
func check_now(force: bool = false) -> void:
	if declined and not force:
		last_status = "declined"
		check_finished.emit(last_status, last_info)
		return
	var cfg := ServerConfig.load_config()
	var url := cfg.manifest_url.strip_edges()
	if url == "" or "YOUR_" in url:
		last_status = "disabled"
		last_info = {"reason": "no_manifest_url"}
		check_finished.emit(last_status, last_info)
		return
	# Web gate forbids foreign requests: only fetch when online_enabled OR native.
	if OS.has_feature("web") and not bool(Settings.get_value("online_enabled")):
		last_status = "disabled"
		last_info = {"reason": "web_offline_default"}
		check_finished.emit(last_status, last_info)
		return
	var err := _http.request(url)
	if err != OK:
		last_status = "offline"
		last_info = {"error": error_string(err)}
		check_finished.emit(last_status, last_info)


func decline() -> void:
	declined = true
	last_status = "declined"
	check_finished.emit(last_status, last_info)


func accept_and_note(info: Dictionary = {}) -> void:
	## Real pack download is handled by tools / a later session; we record the offer.
	last_info = info if not info.is_empty() else last_info
	last_status = "update_available"
	Settings.set_value("pending_update", last_info)
	## Native: the pack is downloaded to user://updates, sha256-verified, then
	## PackLoader.register_installed() mounts it at the next start.


func _on_http(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		last_status = "offline"
		last_info = {"http": code, "result": result}
		check_finished.emit(last_status, last_info)
		return
	var parsed: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (parsed is Dictionary):
		last_status = "error"
		last_info = {"error": "bad_json"}
		check_finished.emit(last_status, last_info)
		return
	var remote: Dictionary = parsed
	var remote_ver := str(remote.get("latest", remote.get("version", "")))
	var local := installed_version()
	last_info = remote
	last_info["local_version"] = local
	last_status = evaluate(remote_ver, local)
	check_finished.emit(last_status, last_info)


## Pure decision used by the HTTP path and smoke tests.
static func evaluate(remote_ver: String, local_ver: String) -> String:
	if remote_ver == "" or remote_ver == local_ver:
		return "up_to_date"
	return "update_available" if compare_versions(remote_ver, local_ver) > 0 else "up_to_date"


static func compare_versions(a: String, b: String) -> int:
	var pa := a.split(".")
	var pb := b.split(".")
	for i in maxi(pa.size(), pb.size()):
		var x := int(pa[i]) if i < pa.size() else 0
		var y := int(pb[i]) if i < pb.size() else 0
		if x != y:
			return 1 if x > y else -1
	return 0


## Smoke / tests: simulate states without a network.
func simulate(status: String, info: Dictionary = {}) -> void:
	last_status = status
	last_info = info
	if status == "declined":
		declined = true
	check_finished.emit(last_status, last_info)
