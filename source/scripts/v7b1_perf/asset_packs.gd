extends Node
## Web-only, demand-loaded model packs. Native builds keep regular resources.
## Content hashes version disk caches and verify downloads before mounting.
signal pack_finished(key: String, ok: bool)
var packs: Dictionary = {}
var mounted: Dictionary = {}
var pending: Dictionary = {}
var retry_after: Dictionary = {}
var enabled: bool = false
var _build_frame: int = -1
var _active_key: String = ""
var _active_request: HTTPRequest = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.has_feature("web") and FileAccess.file_exists("res://data/web_asset_packs.json"):
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/web_asset_packs.json"))
		if data is Dictionary:
			packs = data
			enabled = true

func can_build_now() -> bool:
	if _build_frame == Engine.get_process_frames():
		return false
	_build_frame = Engine.get_process_frames()
	return true

func ensure_all(keys: Array) -> bool:
	for key in keys:
		var available: bool = await ensure_pack(str(key))
		if not available:
			return false
	return true


## Aggregate byte progress for the loading screen. Cached/mounted packs count as
## complete and the active HTTPRequest contributes its downloaded bytes.
func load_progress(keys: Array) -> float:
	var total := 0
	var done := 0
	for raw_key in keys:
		var key := str(raw_key)
		if not packs.has(key):
			continue
		var size := int((packs[key] as Dictionary).get("bytes", 0))
		total += size
		if mounted.has(key):
			done += size
		elif key == _active_key and _active_request != null:
			done += mini(size, _active_request.get_downloaded_bytes())
	return clampf(float(done) / float(total), 0.0, 1.0) if total > 0 else 0.0


func reset_retry(keys: Array) -> void:
	for raw_key in keys:
		retry_after.erase(str(raw_key))

func ensure_pack(key: String) -> bool:
	if not enabled or mounted.has(key):
		return true
	if not packs.has(key) or Time.get_ticks_msec() < int(retry_after.get(key, 0)):
		return false
	if pending.has(key):
		while pending.has(key):
			await pack_finished
		return mounted.has(key)
	print("ASSET PACK: requesting ", key)
	pending[key] = true
	_active_key = key
	var info: Dictionary = packs[key]
	var digest := str(info["sha256"])
	var cached := "user://asset-pack-%s.pck" % digest
	var ok := false
	if FileAccess.file_exists(cached) and FileAccess.get_sha256(cached) == digest:
		ok = ProjectSettings.load_resource_pack(cached, false)
	if not ok:
		var request := HTTPRequest.new()
		# GitHub Pages serves .pck files with Content-Encoding: gzip. Godot 4.6's
		# HTTP gzip stream can fail on this binary response (stream_peer_gzip),
		# leaving the entry screen at 1% forever. Request the original PCK bytes;
		# the content-addressed filename and SHA-256 already provide validation.
		request.accept_gzip = false
		request.timeout = 60.0
		request.download_chunk_size = 1048576
		add_child(request)
		_active_request = request
		var url := str(JavaScriptBridge.eval("new URL(%s, window.location.href).href" % JSON.stringify(str(info["file"])), true))
		var error := request.request(url)
		if error == OK:
			var response: Array = await request.request_completed
			if int(response[0]) == HTTPRequest.RESULT_SUCCESS and int(response[1]) == 200:
				var bytes: PackedByteArray = response[3]
				var hash := HashingContext.new()
				hash.start(HashingContext.HASH_SHA256)
				hash.update(bytes)
				if hash.finish().hex_encode() == digest:
					var f := FileAccess.open(cached, FileAccess.WRITE)
					if f:
						f.store_buffer(bytes)
						f.close()
						ok = ProjectSettings.load_resource_pack(cached, false)
		request.queue_free()
		_active_request = null
	if ok:
		mounted[key] = true
		print("ASSET PACK: mounted ", key)
	else:
		retry_after[key] = Time.get_ticks_msec() + 10000
		GameEvents.notification_requested.emit(Lang.tt("بارگیری ظاهر شخصیت‌ها ناموفق بود؛ دوباره تلاش می‌شود.", "Character download failed; retrying."))
	pending.erase(key)
	_active_key = ""
	pack_finished.emit(key, ok)
	return ok
