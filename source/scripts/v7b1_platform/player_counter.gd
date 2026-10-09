class_name PlayerCounter
extends HBoxContainer
## Live "players online" pill for the title / lobby. Fetches GET /health
## (players, rooms). Never contacts the network when the host is still a
## placeholder, or on the web unless the player opted into online (Pages gate:
## 0 websockets / 0 foreign requests). Shows "—" / offline gracefully.

signal refreshed(info: Dictionary)

var _dot: Panel
var _label: Label
var _http: HTTPRequest
var _timer: Timer
var last: Dictionary = {}
var poll_sec: float = 12.0


func _ready() -> void:
	name = "PlayerCounter"
	add_theme_constant_override(&"separation", 8)
	_dot = Panel.new()
	_dot.custom_minimum_size = Vector2(12, 12)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.55, 0.55)
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	_dot.add_theme_stylebox_override(&"panel", sb)
	add_child(_dot)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color(0.9, 0.95, 0.85))
	add_child(_label)
	_http = HTTPRequest.new()
	_http.timeout = 5.0
	add_child(_http)
	_http.request_completed.connect(_on_http)
	_timer = Timer.new()
	_timer.wait_time = poll_sec
	_timer.timeout.connect(refresh)
	add_child(_timer)
	_set_offline()
	call_deferred("refresh")
	_timer.start()


func _set_offline(reason: String = "") -> void:
	last = {"ok": false, "reason": reason}
	(_dot.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = Color(0.55, 0.55, 0.55)
	_label.text = Lang.pick({"fa": "بازیکنان آنلاین: —", "en": "Players online: —"})
	if reason == "placeholder":
		_label.text = Lang.pick({
			"fa": "بازیکنان آنلاین: — (سرور تنظیم نشده)",
			"en": "Players online: — (server not configured)",
		})
	elif reason == "offline":
		_label.text = Lang.pick({"fa": "بازیکنان آنلاین: آفلاین", "en": "Players online: offline"})
	refreshed.emit(last)


func _set_online(players: int, rooms: int) -> void:
	last = {"ok": true, "players": players, "rooms": rooms}
	(_dot.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color = Color(0.25, 0.75, 0.35)
	_label.text = Lang.pick({
		"fa": "بازیکنان آنلاین: %d  ·  اتاق‌ها: %d" % [players, rooms],
		"en": "Players online: %d  ·  rooms: %d" % [players, rooms],
	})
	refreshed.emit(last)


func _allowed() -> bool:
	var cfg := ServerConfig.load_active()  # LOCALNET: home Wi-Fi pick -> its health port
	if cfg.is_placeholder():
		return false
	if OS.has_feature("web") and not bool(Settings.get_value("online_enabled")):
		return false
	return true


func refresh() -> void:
	if not _allowed():
		_set_offline("placeholder" if ServerConfig.load_active().is_placeholder() else "web_offline")
		return
	var url := ServerConfig.load_active().health_http_url()
	if url == "":
		_set_offline("placeholder")
		return
	# Cancel in-flight and try again.
	_http.cancel_request()
	var err := _http.request(url)
	if err != OK:
		_set_offline("offline")


func _on_http(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or code < 200 or code >= 300:
		_set_offline("offline")
		return
	var v: Variant = JSON.parse_string(body.get_string_from_utf8())
	if not (v is Dictionary) or not bool(v.get("ok", false)):
		_set_offline("offline")
		return
	_set_online(int(v.get("players", 0)), int(v.get("rooms", 0)))


## Smoke / tests: force a state without network.
func simulate(ok: bool, players: int = 0, rooms: int = 0) -> void:
	if ok:
		_set_online(players, rooms)
	else:
		_set_offline("offline")
