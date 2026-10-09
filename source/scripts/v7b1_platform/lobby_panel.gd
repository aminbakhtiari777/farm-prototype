class_name LobbyPanel
extends CanvasLayer
## Online lobby: Host (get a 6-char code), Join by code, Server list, Direct IP:port.
## Uses ServerConfig placeholders — never auto-connects to YOUR_SERVER_HOST.

signal closed
signal joined_room(code: String)

var root: Control
var panel: PanelContainer
var _code_label: Label
var _join_edit: LineEdit
var _direct_edit: LineEdit
var _list: VBoxContainer
var _status: Label
var _host_btn: Button
var _join_btn: Button
var _refresh_btn: Button
var _back_btn: Button
var last_code: String = ""
## v7b.1 LOCALNET: server picker (0 = main [server], 1 = home Wi-Fi [local_network]).
var server_opt: OptionButton
var _lan_hint: Label


func _ready() -> void:
	layer = 101
	name = "LobbyPanel"
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = V6bWorld.ui_theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(560, 560)
	panel.offset_left = -280
	panel.offset_right = 280
	panel.offset_top = -290
	panel.offset_bottom = 290
	panel.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.1, 0.12, 0.1, 0.95), 16, 14))
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	panel.add_child(box)
	var title := Label.new()
	title.add_theme_font_size_override(&"font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = Lang.pick({"fa": "لابی آنلاین", "en": "Online lobby"})
	box.add_child(title)
	var srow := HBoxContainer.new()
	srow.add_theme_constant_override(&"separation", 8)
	box.add_child(srow)
	var slabel := Label.new()
	slabel.name = "ServerLabel"
	srow.add_child(slabel)
	server_opt = OptionButton.new()
	server_opt.name = "ServerPicker"
	server_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	server_opt.add_item("main", 0)
	server_opt.add_item("local", 1)
	server_opt.item_selected.connect(func(i: int) -> void:
		select_profile(ServerConfig.PROFILE_LOCAL if i == 1 else ServerConfig.PROFILE_MAIN))
	srow.add_child(server_opt)
	_lan_hint = Label.new()
	_lan_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lan_hint.add_theme_font_size_override(&"font_size", 13)
	_lan_hint.add_theme_color_override(&"font_color", Color(1, 0.85, 0.5))
	box.add_child(_lan_hint)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override(&"font_size", 14)
	box.add_child(_status)
	_host_btn = Button.new()
	_host_btn.pressed.connect(_on_host)
	box.add_child(_host_btn)
	_code_label = Label.new()
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override(&"font_size", 22)
	_code_label.add_theme_color_override(&"font_color", Color(1, 0.9, 0.4))
	box.add_child(_code_label)
	var row := HBoxContainer.new()
	box.add_child(row)
	_join_edit = LineEdit.new()
	_join_edit.placeholder_text = "ABC123"
	_join_edit.max_length = 6
	_join_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_join_edit)
	_join_btn = Button.new()
	_join_btn.pressed.connect(_on_join)
	row.add_child(_join_btn)
	var drow := HBoxContainer.new()
	box.add_child(drow)
	_direct_edit = LineEdit.new()
	_direct_edit.placeholder_text = "ws://127.0.0.1:9080"
	_direct_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drow.add_child(_direct_edit)
	var connect_btn := Button.new()
	connect_btn.text = Lang.pick({"fa": "اتصال مستقیم", "en": "Connect direct"})
	connect_btn.pressed.connect(_on_direct)
	drow.add_child(connect_btn)
	_refresh_btn = Button.new()
	_refresh_btn.pressed.connect(_on_refresh)
	box.add_child(_refresh_btn)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size = Vector2(0, 120)
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	_back_btn = Button.new()
	_back_btn.pressed.connect(close)
	box.add_child(_back_btn)
	visible = false
	Net.state_changed.connect(func(_s: String) -> void: _refresh_status())
	Net.room_changed.connect(_on_room_changed)
	Net.room_list_received.connect(_on_room_list)
	Net.room_error.connect(func(reason: String) -> void:
		_refresh_status()
		_status.text += "\n" + Lang.pick({"fa": "اتاق پر است — اتاق دیگری را امتحان کن." if reason == "room full" else "این کد اتاق پیدا نشد.",
			"en": "That room is full — try another." if reason == "room full" else "Room code not found."}))
	_rebuild()


func _rebuild() -> void:
	_host_btn.text = Lang.pick({"fa": "میزبانی — ساخت اتاق و کد", "en": "Host — create room & code"})
	_join_btn.text = Lang.pick({"fa": "ورود با کد", "en": "Join by code"})
	_refresh_btn.text = Lang.pick({"fa": "فهرست اتاق‌ها", "en": "Refresh server list"})
	_back_btn.text = Lang.pick({"fa": "بازگشت", "en": "Back"})
	_sync_server_opt()
	_refresh_status()


## LOCALNET: fill the picker texts (fa/en) and select the saved profile.
func _sync_server_opt() -> void:
	if server_opt == null:
		return
	var lbl := server_opt.get_parent().get_node_or_null(^"ServerLabel") as Label
	if lbl:
		lbl.text = Lang.pick({"fa": "سرور:", "en": "Server:"})
	server_opt.set_item_text(0, ServerConfig.load_config().display_label())
	var lan := ServerConfig.local_network()
	server_opt.set_item_text(1, lan.display_label() if lan else Lang.pick({"fa": "شبکهٔ خانگی (تنظیم نشده)", "en": "Local network (not set)"}))
	server_opt.set_item_disabled(1, lan == null or lan.is_placeholder())
	var local := ServerConfig.selected_profile() == ServerConfig.PROFILE_LOCAL and lan != null
	server_opt.select(1 if local else 0)
	_lan_hint.visible = local
	if local:
		_lan_hint.text = Lang.pick({
			"fa": "فقط وقتی کار می‌کند که این دستگاه به همان وای‌فای کامپیوتر سرور (%s) وصل باشد. سرور را روی کامپیوتر با start_server_windows.bat روشن کن." % lan.host,
			"en": "Only works when this device is on the SAME Wi-Fi as the server PC (%s). Start the server there with start_server_windows.bat." % lan.host,
		})
		if _web_https():
			_lan_hint.text += "\n" + Lang.pick({
				"fa": "نسخه‌ی وب (https): اگر کروم پرسید «دسترسی به دستگاه‌های شبکه‌ی محلی؟» بزن «اجازه». فایرفاکس/سافاری اجازه نمی‌دهند — از برنامه‌ی ویندوز/اندروید استفاده کن.",
				"en": "Web (https): if Chrome asks to access devices on your local network, tap Allow. Firefox/Safari block it — use the Windows/Android app.",
			})


## LOCALNET: switch between the main server and the home Wi-Fi server. Drops a
## connection to the other server; reconnects when the lobby is open.
func select_profile(p: String, do_connect: bool = true) -> void:
	ServerConfig.set_profile(p)
	var u := ServerConfig.load_active().resolve_client_url()
	if Net.state != "offline" and Net.url != u:
		Net.go_offline()
	last_code = ""
	if _code_label:
		_code_label.text = ""
	_rebuild()
	if do_connect and visible and u != "" and Net.state == "offline":
		Settings.set_value("online_enabled", true)
		Net.connect_to(u)


func _web_https() -> bool:
	if not OS.has_feature("web"):
		return false
	return str(JavaScriptBridge.eval("window.location.protocol", true)) == "https:"


func _refresh_status() -> void:
	var cfg := ServerConfig.load_active()
	var url := cfg.resolve_client_url()
	if cfg.is_placeholder() and str(Settings.get_value("server_url")).strip_edges() == "":
		_status.text = Lang.pick({
			"fa": "آدرس سرور هنوز تنظیم نشده (YOUR_SERVER_HOST). در تنظیمات یا config/server.cfg وارد کن، یا اتصال مستقیم بزن.",
			"en": "Server address not set yet (YOUR_SERVER_HOST). Fill Settings / config/server.cfg, or use Direct connect.",
		})
	else:
		_status.text = Lang.pick({
			"fa": "وضعیت: %s — %s" % [Net.state, url if url != "" else str(Settings.get_value("server_url"))],
			"en": "Status: %s — %s" % [Net.state, url if url != "" else str(Settings.get_value("server_url"))],
		})
	if last_code != "":
		_code_label.text = Lang.pick({"fa": "کد اتاق: %s" % last_code, "en": "Room code: %s" % last_code})


func open() -> void:
	visible = true
	_rebuild()
	GameEvents.open_modal("lobby")
	var cfg := ServerConfig.load_active()
	var u := cfg.resolve_client_url()
	if u != "" and Net.state == "offline":
		Settings.set_value("online_enabled", true)
		Net.connect_to(u)


func close() -> void:
	visible = false
	GameEvents.close_modal("lobby")
	closed.emit()


func _ensure_connected() -> bool:
	if Net.state == "online":
		return true
	var cfg := ServerConfig.load_active()
	var u := _direct_edit.text.strip_edges()
	var typed := u != ""
	if u == "":
		u = cfg.resolve_client_url()
	if u == "":
		_status.text = Lang.pick({
			"fa": "اول آدرس سرور را وارد کن (مثل ws://IP:9080).",
			"en": "Enter a server address first (e.g. ws://IP:9080).",
		})
		return false
	if typed or cfg.profile != ServerConfig.PROFILE_LOCAL:
		Settings.set_value("server_url", u)  # home Wi-Fi pick is not saved as the typed URL
	Settings.set_value("online_enabled", true)
	Net.connect_to(u)
	_status.text = Lang.pick({"fa": "در حال اتصال…", "en": "Connecting…"})
	return false


func _on_host() -> void:
	if not _ensure_connected():
		# Retry create once online.
		if not Net.state_changed.is_connected(_host_when_online):
			Net.state_changed.connect(_host_when_online, CONNECT_ONE_SHOT)
		return
	Net.create_room()


func _host_when_online(s: String) -> void:
	if s == "online":
		Net.create_room()


func _on_join() -> void:
	var code := _join_edit.text.strip_edges().to_upper()
	if code.length() != 6:
		_status.text = Lang.pick({"fa": "کد باید ۶ کاراکتر باشد.", "en": "Code must be 6 characters."})
		return
	if not _ensure_connected():
		if not Net.state_changed.is_connected(_join_when_online.bind(code)):
			Net.state_changed.connect(func(s: String) -> void:
				if s == "online":
					Net.join_room(code), CONNECT_ONE_SHOT)
		return
	Net.join_room(code)


func _join_when_online(code: String, s: String) -> void:
	if s == "online":
		Net.join_room(code)


func _on_direct() -> void:
	var u := _direct_edit.text.strip_edges()
	if not (u.begins_with("ws://") or u.begins_with("wss://")):
		# Allow host:port shorthand.
		if u != "" and "://" not in u:
			u = "ws://" + u
		else:
			_status.text = Lang.pick({"fa": "آدرس باید با ws:// یا wss:// شروع شود.", "en": "URL must start with ws:// or wss://."})
			return
	Settings.set_value("server_url", u)
	Settings.set_value("online_enabled", true)
	Net.connect_to(u)


func _on_refresh() -> void:
	if Net.state != "online":
		_ensure_connected()
		return
	Net.request_room_list()


func _on_room_changed(info: Dictionary) -> void:
	last_code = str(info.get("code", ""))
	_refresh_status()
	if last_code != "":
		joined_room.emit(last_code)


func _on_room_list(rooms: Array) -> void:
	for c in _list.get_children():
		c.queue_free()
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = Lang.pick({"fa": "اتاق عمومی‌ای در فهرست نیست — یکی بساز.", "en": "No public rooms — host one."})
		_list.add_child(empty)
		return
	for r in rooms:
		var b := Button.new()
		var code := str(r.get("code", "?"))
		var n := int(r.get("players", 0))
		var mx := int(r.get("max", 6))
		b.text = "%s  (%d/%d)" % [code, n, mx]
		b.pressed.connect(func() -> void: Net.join_room(code))
		_list.add_child(b)
