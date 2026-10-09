class_name NetHud
extends CanvasLayer
## v5d online UI (Persian by default, English toggle):
##   * status pill: online / connecting / offline (opted in but the server
##     can't be reached - the game keeps running and syncs later). Hidden in
##     single player, which is the default.
##   * chat: T or Enter to type, Enter to send, Esc to cancel; recent lines
##     bottom-left; bubbles over heads (RemoteAvatars).
##   * Online panel (U): opt in / out, name, server URL, players, module updates
##     (list + roll back) and the save-sync status.
##   * banners: module updated live, welcome back.

const MODULE_NAMES_FA := {"wages": "دستمزدها", "market_economy": "اقتصاد بازار", "chat": "گفتگو", "netcode": "شبکه",
	"away_avatar": "آواتار غایب", "save_sync": "همگام‌سازی ذخیره", "dialogue": "گفتگوی مردم", "price_board": "تابلوی قیمت",
	"crop_types": "محصولات", "population": "مردم شهر", "fonts": "قلم‌ها", "needs": "نیازها", "livestock": "دام‌ها",
	"accounts": "حساب‌ها", "npc_roles": "نقش‌های مردم", "live_updates": "به‌روزرسانی زنده", "lighting": "نورپردازی", "sky": "آسمان"}

var root: Control
var pill: PanelContainer
var pill_label: Label
var _pill_dot: Panel
var _pill_dot_box: StyleBoxFlat
var chat_box: VBoxContainer
var chat_lines: VBoxContainer
var chat_input: LineEdit
var panel: PanelContainer
var banner: PanelContainer
var banner_label: Label
var _banner_tween: Tween
var _status_label: Label
var _name_edit: LineEdit
var _url_edit: LineEdit
var _players_label: Label
var _updates_label: Label
var _sync_label: Label
var _line_nodes: Array = []  ## [Label, seconds_left]
var banners_shown: int = 0
var _title: Label
var _close_btn: Button
var last_banner: String = ""


func _ready() -> void:
	layer = 6
	name = "NetHud"
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var th := Theme.new()
	th.default_font = Lang.ui_font()
	root.theme = th
	add_child(root)
	_build_pill()
	_build_chat()
	_build_banner()
	_build_panel()
	Net.state_changed.connect(func(_s: String) -> void: _refresh())
	Net.roster_changed.connect(_refresh)
	Net.chat_received.connect(_on_chat)
	Net.module_updated.connect(_on_module_updated)
	Net.welcome_back.connect(_on_welcome_back)
	Net.save_synced.connect(func(_f: Dictionary) -> void: _refresh())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			_rebuild_texts())
	_refresh()


func T(fa: String, en: String) -> String:
	return Lang.pick({"fa": fa, "en": en})


# ------------------------------------------------------------------ status pill
func _build_pill() -> void:
	pill = PanelContainer.new()
	pill.name = "NetStatus"
	pill.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.08, 0.07, 0.06, 0.78), 14, 8))
	pill.set_anchors_preset(Control.PRESET_TOP_LEFT)
	pill.position = Vector2(16, 62)
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pill.add_child(row)
	# Status dot drawn as a round panel (Vazirmatn has no "●" glyph).
	_pill_dot = Panel.new()
	_pill_dot.custom_minimum_size = Vector2(10, 10)
	_pill_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pill_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pill_dot_box = StyleBoxFlat.new()
	_pill_dot_box.set_corner_radius_all(5)
	_pill_dot.add_theme_stylebox_override(&"panel", _pill_dot_box)
	row.add_child(_pill_dot)
	pill_label = UIKit.label(row, "", 16, Color.WHITE)


func status_text() -> String:
	match Net.state:
		"online":
			var n := 0
			var away := 0
			for pid in Net.roster:
				if str(Net.roster[pid].get("state", "active")) == "active":
					n += 1
				else:
					away += 1
			var t := T("آنلاین — %s بازیکن" % Lang.digits(str(n)), "Online · %d players" % n)
			if away > 0:
				t += T("، %s غایب" % Lang.digits(str(away)), " · %d away" % away)
			return t
		"connecting":
			return T("در حال اتصال…", "Connecting…")
		"unreachable":
			return T("آفلاین — سرور در دسترس نیست؛ بازی ادامه دارد و بعداً همگام می‌شود", "Offline — server unreachable; playing locally, will sync later")
	return ""


func _refresh() -> void:
	var txt := status_text()
	pill.visible = txt != ""
	pill_label.text = txt
	var col := Color(0.55, 0.95, 0.55)
	if Net.state == "connecting":
		col = Color(1.0, 0.9, 0.4)
	elif Net.state == "unreachable":
		col = Color(1.0, 0.62, 0.35)
	pill_label.add_theme_color_override(&"font_color", col)
	_pill_dot_box.bg_color = col
	pill.reset_size()
	chat_box.visible = Net.state == "online" or not _line_nodes.is_empty()
	if panel.visible:
		_fill_panel()


# ------------------------------------------------------------------ chat
func _build_chat() -> void:
	chat_box = VBoxContainer.new()
	chat_box.name = "Chat"
	chat_box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	chat_box.anchor_top = 1.0
	chat_box.anchor_bottom = 1.0
	chat_box.offset_left = 16
	chat_box.offset_right = 560
	chat_box.offset_top = -400
	chat_box.offset_bottom = -205
	chat_box.alignment = BoxContainer.ALIGNMENT_END
	chat_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(chat_box)
	chat_lines = VBoxContainer.new()
	chat_lines.alignment = BoxContainer.ALIGNMENT_END
	chat_lines.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_box.add_child(chat_lines)
	chat_input = LineEdit.new()
	chat_input.name = "ChatInput"
	chat_input.visible = false
	chat_input.custom_minimum_size = Vector2(520, 38)
	chat_input.add_theme_font_size_override(&"font_size", 17)
	chat_input.add_theme_font_override(&"font", Lang.bubble_font())
	chat_input.text_submitted.connect(_on_submit)
	chat_input.structured_text_bidi_override = TextServer.STRUCTURED_TEXT_DEFAULT
	var st := Modules.style("chat") as ChatStyle
	chat_input.max_length = st.max_length if st else 200
	chat_box.add_child(chat_input)


func open_chat() -> void:
	if Net.state != "online":
		GameEvents.notification_requested.emit(T("گفتگو فقط در حالت آنلاین است (U)", "Chat works when you are online (U)"))
		return
	chat_box.visible = true
	chat_input.placeholder_text = T("پیام… (Enter بفرست، Esc لغو)", "Message… (Enter send, Esc cancel)")
	chat_input.visible = true
	chat_input.text = ""
	chat_input.grab_focus()
	GameEvents.open_modal("chat")


func close_chat() -> void:
	if not chat_input.visible:
		return
	chat_input.release_focus()
	chat_input.visible = false
	GameEvents.close_modal("chat")


func _on_submit(text: String) -> void:
	Net.send_chat(text)
	close_chat()


func _on_chat(pid: int, sender: String, text: String) -> void:
	var st := Modules.style("chat") as ChatStyle
	var l := UIKit.label(chat_lines, "", 17, Color(1, 1, 1))
	l.add_theme_font_override(&"font", Lang.bubble_font())
	l.add_theme_constant_override(&"outline_size", 6)
	l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.85))
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 520
	var who := sender if pid != 0 else T("سرور", "server")
	var col := Color(0.6, 1, 0.6) if pid == Net.my_pid else (Color(1, 0.85, 0.5) if pid == 0 else Color(0.7, 0.85, 1))
	l.text = "%s: %s" % [who, text]
	l.add_theme_color_override(&"font_color", col)
	l.text_direction = Control.TEXT_DIRECTION_AUTO
	_line_nodes.append([l, st.line_seconds if st else 12.0])
	while _line_nodes.size() > (st.log_lines if st else 8):
		(_line_nodes.pop_front()[0] as Node).queue_free()
	chat_box.visible = true


func _process(delta: float) -> void:
	for e in _line_nodes:
		e[1] = float(e[1]) - delta
		var l: Label = e[0]
		if is_instance_valid(l):
			l.modulate.a = clampf(float(e[1]) / 2.0, 0.0, 1.0) if not chat_input.visible else 1.0


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey or event is InputEventAction) or not event.is_pressed() or event.is_echo():
		return
	if chat_input.visible:
		if event.is_action(&"menu"):
			close_chat()
			get_viewport().set_input_as_handled()
		return
	if panel.visible and (event.is_action(&"menu") or event.is_action(&"online_panel")):
		close_panel()
		get_viewport().set_input_as_handled()
		return
	if GameEvents.ui_open:
		return
	if event.is_action(&"chat"):
		open_chat()
		get_viewport().set_input_as_handled()
	elif event.is_action(&"online_panel"):
		open_panel()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ banner
func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.name = "NetBanner"
	banner.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.12, 0.3, 0.22, 0.92), 14, 14, true))
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.offset_top = 150
	banner.offset_left = -330
	banner.offset_right = 330
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.modulate.a = 0.0
	root.add_child(banner)
	banner_label = UIKit.label(banner, "", 20, Color(1, 1, 0.92))
	banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	banner_label.custom_minimum_size.x = 620


func show_banner(text: String, color: Color = Color(0.12, 0.3, 0.22, 0.92), seconds: float = 5.0) -> void:
	banners_shown += 1
	last_banner = text
	banner.add_theme_stylebox_override(&"panel", UIKit.style(color, 14, 14, true))
	banner_label.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_tween.tween_property(banner, "modulate:a", 1.0, 0.25)
	_banner_tween.tween_interval(seconds)
	_banner_tween.tween_property(banner, "modulate:a", 0.0, 0.8)


## One module-update history entry in the current language.
static func history_line(h: Variant) -> String:
	if not (h is Dictionary):
		return str(h)
	var d := h as Dictionary
	if not Lang.is_fa():
		return str(d.get("en", ""))
	var n := module_name(str(d.get("type", "")))
	var v := Lang.digits(str(int(d.get("version", 0))))
	match str(d.get("kind", "")):
		"updated":
			return "«%s» به نسخهٔ %s به‌روز شد" % [n, v]
		"rejected":
			return "به‌روزرسانی «%s» نسخهٔ %s رد شد؛ نسخهٔ فعلی ماند" % [n, v]
		"rolled_back":
			return "«%s» به نسخهٔ %s برگردانده شد" % [n, v]
	return str(d.get("en", ""))


static func module_name(type: String) -> String:
	if Lang.is_fa():
		return MODULE_NAMES_FA.get(type, type)
	return type.replace("_", " ")


func _on_module_updated(type: String, version: int, ok: bool, error: String) -> void:
	var st := Modules.style("live_updates") as LiveUpdatesStyle
	if st and not st.notify:
		return
	if ok:
		show_banner(T("ماژول «%s» به نسخهٔ %s به‌روز شد — بدون نصب دوباره" % [module_name(type), Lang.digits(str(version))],
			"Module “%s” updated to v%d — live, no reinstall" % [module_name(type), version]))
	else:
		show_banner(T("به‌روزرسانی «%s» رد شد؛ نسخهٔ قبلی سر جایش ماند (%s)" % [module_name(type), error],
			"Update of “%s” rejected; kept the previous version (%s)" % [module_name(type), error]), Color(0.4, 0.16, 0.12, 0.92))
	if panel.visible:
		_fill_panel()


func _on_welcome_back(info: Dictionary) -> void:
	show_banner(str(info.get("message", T("خوش برگشتی!", "Welcome back!"))), Color(0.18, 0.24, 0.42, 0.94), 7.0)


# ------------------------------------------------------------------ online panel (U)
func _build_panel() -> void:
	var d := UIKit.modal_panel(T("بازی آنلاین (آزمایشی)", "Online play (beta)"), Vector2(700, 560))
	panel = d["panel"]
	panel.name = "OnlinePanel"
	panel.visible = false
	root.add_child(panel)
	var v: VBoxContainer = d["body"]
	_title = d["title"]
	_close_btn = d["close"]
	_close_btn.pressed.connect(close_panel)
	_status_label = UIKit.label(v, "", 17, UIKit.INK)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var note := UIKit.label(v, "", 14, UIKit.INK.lightened(0.25))
	note.name = "Note"
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	var l1 := UIKit.label(g, "", 16, UIKit.INK)
	l1.name = "NameLabel"
	_name_edit = LineEdit.new()
	_name_edit.custom_minimum_size.x = 440
	_name_edit.max_length = 16
	g.add_child(_name_edit)
	var l2 := UIKit.label(g, "", 16, UIKit.INK)
	l2.name = "UrlLabel"
	_url_edit = LineEdit.new()
	_url_edit.custom_minimum_size.x = 440
	_url_edit.placeholder_text = "wss://game.example.ir"
	g.add_child(_url_edit)
	var row := HBoxContainer.new()
	v.add_child(row)
	var b1 := UIKit.button(row, "", _on_connect_pressed)
	b1.name = "ConnectButton"
	var b2 := UIKit.button(row, "", _on_offline_pressed)
	b2.name = "OfflineButton"
	var b3 := UIKit.button(row, "", _on_rollback_pressed)
	b3.name = "RollbackButton"
	_players_label = UIKit.label(v, "", 15, UIKit.INK)
	_players_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sync_label = UIKit.label(v, "", 15, UIKit.INK)
	_sync_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_updates_label = UIKit.label(v, "", 14, UIKit.INK)
	_updates_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rebuild_texts()


func _rebuild_texts() -> void:
	if panel == null:
		return
	_title.text = T("بازی آنلاین (آزمایشی)", "Online play (beta)")
	_close_btn.text = T("بستن (Esc)", "Close (Esc)")
	(panel.find_child("Note", true, false) as Label).text = T(
		"بازی به‌طور پیش‌فرض تک‌نفره و آفلاین است و به هیچ سروری وصل نمی‌شود، مگر خودت اینجا «اتصال» را بزنی.",
		"The game is single-player and offline by default and never contacts a server unless you press Connect here.")
	(panel.find_child("NameLabel", true, false) as Label).text = T("نام:", "Name:")
	(panel.find_child("UrlLabel", true, false) as Label).text = T("آدرس سرور:", "Server URL:")
	(panel.find_child("ConnectButton", true, false) as Button).text = T("اتصال", "Connect")
	(panel.find_child("OfflineButton", true, false) as Button).text = T("قطع (تک‌نفره)", "Go offline")
	(panel.find_child("RollbackButton", true, false) as Button).text = T("برگرداندن آخرین به‌روزرسانی", "Roll back last update")
	_refresh()


func open_panel() -> void:
	panel.visible = true
	GameEvents.open_modal("online")
	_name_edit.text = str(Settings.get_value("player_name"))
	var u := str(Settings.get_value("server_url"))
	if u == "" and Net.url != "":
		u = Net.url
	_url_edit.text = u
	_fill_panel()


func close_panel() -> void:
	if not panel.visible:
		return
	panel.visible = false
	GameEvents.close_modal("online")


func _fill_panel() -> void:
	var st := status_text()
	_status_label.text = st if st != "" else T("تک‌نفره (آفلاین)", "Single player (offline)")
	var names := PackedStringArray()
	for pid in Net.roster:
		var r: Dictionary = Net.roster[pid]
		var s := str(r.get("name", "?"))
		if int(pid) == Net.my_pid:
			s += T(" (تو)", " (you)")
		elif str(r.get("state", "active")) != "active":
			s += T(" (غایب)", " (away)")
		names.append(s)
	_players_label.text = T("بازیکنان: ", "Players: ") + (", ".join(names) if not names.is_empty() else "—")
	var stamps: Dictionary = Net.synced.get("stamps", {})
	_sync_label.text = T("ذخیره: هر %s ثانیه با سرور همگام می‌شود (گروه‌ها: %s). قانون: جدیدترین نسخهٔ هر بخش؛ وضعیت مشترک دنیا با سرور." % [Lang.digits(str(int(_upload_s()))), Lang.digits(str(stamps.size()))],
		"Save: syncs with the server every %d s (%d groups). Rule: newest copy per group; shared world state from the server." % [int(_upload_s()), stamps.size()])
	var lines := PackedStringArray()
	for h in ModuleManifest.history.slice(-5):
		lines.append("• " + history_line(h))
	var inst: Dictionary = ModuleManifest.load_installed().get("modules", {})
	var head := T("به‌روزرسانی‌های ماژول نصب‌شده: %s" % Lang.digits(str(inst.size())), "Installed module updates: %d" % inst.size())
	for t in inst:
		head += "\n  " + module_name(str(t)) + " v" + str(int(inst[t].get("version", 0)))
	_updates_label.text = head + ("\n" + "\n".join(lines) if not lines.is_empty() else "")


func _on_connect_pressed() -> void:
	var n := _name_edit.text.strip_edges()
	if n != "":
		Settings.set_value("player_name", n)
	var u := _url_edit.text.strip_edges()
	if not (u.begins_with("ws://") or u.begins_with("wss://")):
		GameEvents.notification_requested.emit(T("آدرس باید با wss:// شروع شود", "The URL must start with wss://"))
		return
	Settings.set_value("server_url", u)
	Settings.set_value("online_enabled", true)
	Net.connect_to(u)
	_fill_panel()


func _on_offline_pressed() -> void:
	Settings.set_value("online_enabled", false)
	Net.go_offline()
	_fill_panel()


func _on_rollback_pressed() -> void:
	var inst: Dictionary = ModuleManifest.load_installed().get("modules", {})
	if inst.is_empty():
		GameEvents.notification_requested.emit(T("به‌روزرسانی‌ای برای برگرداندن نیست", "No update to roll back"))
		return
	var t: String = inst.keys()[-1]
	ModuleManifest.rollback(t, "player")
	show_banner(T("«%s» به نسخهٔ قبلی برگشت" % module_name(t), "“%s” rolled back" % module_name(t)), Color(0.35, 0.28, 0.12, 0.92))
	_fill_panel()


func _upload_s() -> float:
	var st := Modules.style("save_sync") as SaveSyncStyle
	return st.upload_seconds if st else 5.0
