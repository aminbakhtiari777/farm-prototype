class_name EntryFlow
extends CanvasLayer
## v7b.1 pre-game entry (approved by Amin):
##   1. Splash: the farm logo rises from the bottom with a spring (TRANS_BACK),
##      pulses twice, fades out (~3 s). Click / tap / any key skips.
##   2. Main menu slides in from the right; buttons appear one by one (100 ms).
##   3. Big Play button with the live player count + blinking green dot (grey /
##      offline for placeholder or unreachable servers), Settings, About, Exit
##      (hidden on web / iOS), small QR codes (GitHub; LinkedIn hidden until set).
##   4. Play -> Single-player | Online (lobby) -> loading screen -> game.
## Persian default, English toggle, V6bWorld.ui_theme(). Enter = default button
## (keyboard / gate). Tests (--smoke-test, --net-test, --shots...) auto-enter.

signal entered_game(mode: String)
signal online_requested

const SPLASH_SECS := 3.0
const STAGGER := 0.1
const REQUIRED_WEB_PACKS := ["world", "hair", "animations"]

static var completed: bool = false  ## survives the Boot -> Main scene change

var root: Control
var state: String = "init"  ## splash | menu | play | settings | about | loading | game
var entered: bool = false
var auto_web: bool = true  ## kept for compatibility (shots turn auto-skip off)
var mode: String = "single"
## Boot scene: path loading on a thread (loading bar shows its real progress).
var loading_path: String = ""

var _splash: Control
var _logo: TextureRect
var _splash_tween: Tween
var _menu: Control
var _menu_box: VBoxContainer
var _title: Label
var _subtitle: Label
var _version: Label
var _lang_btn: Button
var _play_btn: Button
var _play_label: Label
var _count_label: Label
var _dot: Panel
var _dot_tween: Tween
var _counter: PlayerCounter
var _settings_btn: Button
var _about_btn: Button
var _exit_btn: Button
var _play_box: VBoxContainer
var _single_btn: Button
var _online_btn: Button
var _back_btn: Button
var _qr_row: HBoxContainer
var qr_items: Dictionary = {}  ## id -> {"rect": TextureRect, "url": String, "visible": bool}
var settings: EntrySettings
var about: Control
var loading: LoadingScreen
var _menu_buttons: Array = []


func T(fa: String, en: String) -> String:
	return Lang.tt(fa, en)


func _ready() -> void:
	layer = 100
	name = "EntryFlow"
	process_mode = Node.PROCESS_MODE_ALWAYS
	root = Control.new()
	root.name = "EntryRoot"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = V6bWorld.ui_theme()
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Color(0.07, 0.12, 0.09, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	var hill := ColorRect.new()
	hill.color = Color(0.2, 0.36, 0.17, 0.6)
	hill.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hill.offset_top = -160
	hill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hill)
	_build_splash()
	_build_menu()
	settings = EntrySettings.new()
	settings.visible = false
	settings.closed.connect(_show_menu_from_sub)
	root.add_child(settings)
	_build_about()
	loading = LoadingScreen.new()
	loading.visible = false
	loading.finished.connect(_on_loading_finished)
	loading.retry_requested.connect(func() -> void: start_loading(mode))
	root.add_child(loading)
	get_viewport().size_changed.connect(_layout)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			_rebuild_texts())
	_rebuild_texts()
	_layout()
	if completed or _should_autoskip():
		call_deferred("_autoskip")
	else:
		GameEvents.open_modal("entry")
		start_splash()


# ------------------------------------------------------------------ auto-skip
func _should_autoskip() -> bool:
	if not auto_web:
		return false
	for a in OS.get_cmdline_user_args():
		if a == "--smoke-test" or a.begins_with("--smoke-only=") or a.begins_with("--net-test=") \
				or a.begins_with("--screenshot") or a.begins_with("--shots") or a == "--perf" \
				or a.begins_with("--perf-profile") or a.begins_with("--perf-walk") or a == "--skip-title" or a.begins_with("--server-url=") \
				or a.begins_with("--ctl-shots") or a.begins_with("--vis-shots") or a.begins_with("--inspect="):
			return true
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		if q is String and ("skipmenu=1" in (q as String) or "demo=" in (q as String)):
			return true
	return false


func _autoskip() -> void:
	if entered:
		return
	_enter_game("single")


# ------------------------------------------------------------------ splash
func _build_splash() -> void:
	_splash = Control.new()
	_splash.name = "Splash"
	_splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_splash)
	_logo = TextureRect.new()
	_logo.name = "Logo"
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if ResourceLoader.exists(GameBrand.ICON_PNG):
		_logo.texture = load(GameBrand.ICON_PNG) as Texture2D
	elif ResourceLoader.exists(GameBrand.ICON_SVG):
		_logo.texture = load(GameBrand.ICON_SVG) as Texture2D
	_splash.add_child(_logo)
	var name_l := Label.new()
	name_l.name = "SplashName"
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.add_theme_color_override(&"font_color", Color(1, 0.92, 0.6))
	name_l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_splash.add_child(name_l)


func _logo_side() -> float:
	var s := get_viewport().get_visible_rect().size
	return clampf(minf(s.x, s.y) * 0.38, 120.0, 360.0)


func start_splash() -> void:
	state = "splash"
	_splash.visible = true
	_menu.visible = false
	var s := get_viewport().get_visible_rect().size
	var side := _logo_side()
	_logo.size = Vector2(side, side)
	_logo.pivot_offset = _logo.size * 0.5
	var center := Vector2((s.x - side) * 0.5, (s.y - side) * 0.5 - side * 0.12)
	_logo.position = Vector2(center.x, s.y + 20.0)
	_logo.modulate.a = 0.0
	_logo.scale = Vector2.ONE
	var nl := _splash.get_node("SplashName") as Label
	nl.text = GameBrand.title()
	nl.add_theme_font_size_override(&"font_size", int(clampf(side * 0.16, 22, 48)))
	nl.position = Vector2(0, center.y + side + 12.0)
	nl.size = Vector2(s.x, 60)
	nl.modulate.a = 0.0
	_splash_tween = create_tween()
	_splash_tween.set_parallel(true)
	_splash_tween.tween_property(_logo, "position", center, 0.9).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_splash_tween.tween_property(_logo, "modulate:a", 1.0, 0.5)
	_splash_tween.tween_property(nl, "modulate:a", 1.0, 0.6).set_delay(0.5)
	_splash_tween.set_parallel(false)
	for _i in 2:
		_splash_tween.tween_property(_logo, "scale", Vector2(1.08, 1.08), 0.22).set_trans(Tween.TRANS_SINE)
		_splash_tween.tween_property(_logo, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_SINE)
	_splash_tween.tween_interval(0.35)
	_splash_tween.set_parallel(true)
	_splash_tween.tween_property(_logo, "modulate:a", 0.0, 0.45)
	_splash_tween.tween_property(nl, "modulate:a", 0.0, 0.45)
	_splash_tween.set_parallel(false)
	_splash_tween.tween_callback(_end_splash)


func skip_splash() -> void:
	if state != "splash":
		return
	if _splash_tween and _splash_tween.is_valid():
		_splash_tween.kill()
	_end_splash()


func _end_splash() -> void:
	if state != "splash":
		return
	_splash.visible = false
	show_menu(true)


# ------------------------------------------------------------------ menu
func _build_menu() -> void:
	_menu = Control.new()
	_menu.name = "Menu"
	_menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_menu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu.visible = false
	root.add_child(_menu)
	_lang_btn = Button.new()
	_lang_btn.name = "Lang"
	_lang_btn.pressed.connect(_toggle_lang)
	_menu.add_child(_lang_btn)
	_menu_box = VBoxContainer.new()
	_menu_box.name = "MenuBox"
	_menu_box.add_theme_constant_override(&"separation", 12)
	_menu.add_child(_menu_box)
	_title = Label.new()
	_title.name = "Title"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override(&"font_color", Color(1.0, 0.92, 0.55))
	_menu_box.add_child(_title)
	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_subtitle.add_theme_color_override(&"font_color", Color(0.85, 0.92, 0.8))
	_menu_box.add_child(_subtitle)
	# Big Play button with the live player count + blinking dot.
	_play_btn = Button.new()
	_play_btn.name = "Play"
	_play_btn.pressed.connect(_on_play)
	_play_btn.add_theme_stylebox_override(&"normal", UIKit.style(Color(0.2, 0.55, 0.25, 0.95), 18, 12))
	_play_btn.add_theme_stylebox_override(&"hover", UIKit.style(Color(0.25, 0.65, 0.3, 1.0), 18, 12))
	_play_btn.add_theme_stylebox_override(&"pressed", UIKit.style(Color(0.15, 0.45, 0.2, 1.0), 18, 12))
	_play_btn.add_theme_stylebox_override(&"focus", UIKit.style(Color(0.25, 0.65, 0.3, 1.0), 18, 12))
	_menu_box.add_child(_play_btn)
	var pv := VBoxContainer.new()
	pv.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pv.alignment = BoxContainer.ALIGNMENT_CENTER
	pv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_play_btn.add_child(pv)
	_play_label = Label.new()
	_play_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_play_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pv.add_child(_play_label)
	var ch := HBoxContainer.new()
	ch.alignment = BoxContainer.ALIGNMENT_CENTER
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_theme_constant_override(&"separation", 8)
	pv.add_child(ch)
	_dot = Panel.new()
	_dot.name = "Dot"
	_dot.custom_minimum_size = Vector2(12, 12)
	_dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.6, 0.6, 0.6)
	sb.set_corner_radius_all(6)
	_dot.add_theme_stylebox_override(&"panel", sb)
	var dot_wrap := CenterContainer.new()
	dot_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot_wrap.add_child(_dot)
	ch.add_child(dot_wrap)
	_count_label = Label.new()
	_count_label.name = "Count"
	_count_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_count_label.add_theme_color_override(&"font_color", Color(0.92, 1.0, 0.9))
	ch.add_child(_count_label)
	_counter = PlayerCounter.new()
	_counter.visible = false  # logic only; shown through the Play button
	_counter.refreshed.connect(_on_counter)
	_menu.add_child(_counter)
	_settings_btn = _menu_button("Settings", _on_settings)
	_about_btn = _menu_button("About", _on_about)
	_exit_btn = _menu_button("Exit", _on_exit)
	# Play sub-menu (Single / Online / Back)
	_play_box = VBoxContainer.new()
	_play_box.name = "PlayBox"
	_play_box.add_theme_constant_override(&"separation", 12)
	_play_box.visible = false
	_menu.add_child(_play_box)
	_single_btn = _sub_button("Single", _on_single)
	_online_btn = _sub_button("Online", _on_online)
	_back_btn = _sub_button("Back", _on_back)
	# QR codes (bottom).
	_qr_row = HBoxContainer.new()
	_qr_row.name = "QrRow"
	_qr_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_qr_row.add_theme_constant_override(&"separation", 28)
	_menu.add_child(_qr_row)
	var cfg := ServerConfig.load_config()
	_add_qr("github", cfg.github_url, "گیت‌هاب امین", "Amin on GitHub", cfg.is_social_ready(cfg.github_url))
	_add_qr("linkedin", cfg.linkedin_url, "لینکدین امین", "Amin on LinkedIn", cfg.is_social_ready(cfg.linkedin_url))
	_version = Label.new()
	_version.name = "Version"
	_version.add_theme_font_size_override(&"font_size", 13)
	_version.add_theme_color_override(&"font_color", Color(0.7, 0.78, 0.65))
	_menu.add_child(_version)


func _menu_button(id: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.custom_minimum_size = Vector2(0, 50)
	b.pressed.connect(cb)
	_menu_box.add_child(b)
	return b


func _sub_button(id: String, cb: Callable) -> Button:
	var b := Button.new()
	b.name = id
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(cb)
	_play_box.add_child(b)
	return b


func _add_qr(id: String, url: String, fa: String, en: String, show: bool) -> void:
	var col := VBoxContainer.new()
	col.name = "Qr_" + id
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.visible = show
	_qr_row.add_child(col)
	var rect := TextureRect.new()
	rect.name = "Code"
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(86, 86)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	rect.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	rect.tooltip_text = url
	if show:
		var res := QrEncoder.encode(url)
		rect.texture = QrEncoder.to_texture(res, 4)
	rect.gui_input.connect(func(e: InputEvent) -> void:
		if (e is InputEventMouseButton and (e as InputEventMouseButton).pressed and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
				or (e is InputEventScreenTouch and (e as InputEventScreenTouch).pressed):
			open_link(id))
	col.add_child(rect)
	var link := LinkButton.new()
	link.name = "Link"
	link.text = T(fa, en)
	link.underline = LinkButton.UNDERLINE_MODE_ON_HOVER
	link.add_theme_font_size_override(&"font_size", 13)
	link.pressed.connect(open_link.bind(id))
	col.add_child(link)
	qr_items[id] = {"rect": rect, "url": url, "visible": show, "fa": fa, "en": en, "link": link}


var last_opened_url: String = ""


func open_link(id: String) -> void:
	var it: Dictionary = qr_items.get(id, {})
	if it.is_empty() or not bool(it.get("visible", false)):
		return
	last_opened_url = str(it["url"])
	if not _should_autoskip():  # never launch a browser from tests
		OS.shell_open(last_opened_url)


func _on_counter(info: Dictionary) -> void:
	var sb := _dot.get_theme_stylebox(&"panel") as StyleBoxFlat
	if _dot_tween and _dot_tween.is_valid():
		_dot_tween.kill()
	_dot.modulate.a = 1.0
	if bool(info.get("ok", false)):
		sb.bg_color = Color(0.3, 0.95, 0.4)
		_count_label.text = T("%d بازیکن در بازی" % int(info.get("players", 0)), "%d players in game" % int(info.get("players", 0)))
		_dot_tween = create_tween().set_loops()
		_dot_tween.tween_property(_dot, "modulate:a", 0.25, 0.6)
		_dot_tween.tween_property(_dot, "modulate:a", 1.0, 0.6)
	else:
		sb.bg_color = Color(0.6, 0.6, 0.6)
		_count_label.text = T("آفلاین — بازیکنان: —", "offline — players: —")


func players_text() -> String:
	return _count_label.text


func dot_online() -> bool:
	return (_dot.get_theme_stylebox(&"panel") as StyleBoxFlat).bg_color.g > 0.9


func show_menu(animate: bool) -> void:
	state = "menu"
	_menu.visible = true
	_menu_box.visible = true
	_play_box.visible = false
	settings.visible = false
	about.visible = false
	loading.visible = false
	_layout()
	_menu_buttons = [_play_btn, _settings_btn, _about_btn]
	if _exit_btn.visible:
		_menu_buttons.append(_exit_btn)
	_animate_in(_menu_box, _menu_buttons, animate)
	_play_btn.grab_focus.call_deferred()


func _animate_in(box: Control, buttons: Array, animate: bool) -> void:
	var s := get_viewport().get_visible_rect().size
	var target_x := box.position.x
	if not animate:
		for b in buttons:
			(b as Control).modulate.a = 1.0
		return
	box.position.x = target_x + s.x * 0.6
	var tw := create_tween()
	tw.tween_property(box, "position:x", target_x, 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	var i := 0
	for b in buttons:
		var c := b as Control
		c.modulate.a = 0.0
		var bt := create_tween()
		bt.tween_interval(0.25 + STAGGER * i)
		bt.tween_property(c, "modulate:a", 1.0, 0.18)
		i += 1


func _show_menu_from_sub() -> void:
	show_menu(false)


func _show_play_box() -> void:
	state = "play"
	_menu_box.visible = false
	_play_box.visible = true
	_layout()
	_animate_in(_play_box, [_single_btn, _online_btn, _back_btn], true)
	_single_btn.grab_focus.call_deferred()


# ------------------------------------------------------------------ about
func _build_about() -> void:
	about = PanelContainer.new()
	about.name = "About"
	about.visible = false
	(about as PanelContainer).add_theme_stylebox_override(&"panel", UIKit.style(Color(0.1, 0.13, 0.1, 0.96), 16, 18))
	root.add_child(about)
	var v := VBoxContainer.new()
	v.add_theme_constant_override(&"separation", 10)
	about.add_child(v)
	var t := Label.new()
	t.name = "AboutText"
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var b := Button.new()
	b.name = "AboutBack"
	b.custom_minimum_size = Vector2(0, 46)
	b.pressed.connect(_show_menu_from_sub)
	v.add_child(b)


func about_text() -> String:
	return T(
		"%s\nنسخه %s (%s)\n\nساخته‌ی امین بختیاری — Zamith / Zamis\nموتور: Godot 4.7 (MIT)\nمدل‌ها: Quaternius و Kenney (CC0) — قلم وزیرمتن (OFL)\nصداها و بقیه‌ی محتوا: ساخته‌شده برای همین بازی" % [GameBrand.title_fa(), GameBrand.version(), GameBrand.build_id()],
		"%s\nVersion %s (%s)\n\nMade by Amin Bakhtiari — Zamith / Zamis\nEngine: Godot 4.7 (MIT)\nArt: Quaternius & Kenney (CC0) — Vazirmatn font (OFL)\nAudio and everything else: made for this game" % [GameBrand.title_en(), GameBrand.version(), GameBrand.build_id()])


# ------------------------------------------------------------------ layout (phone portrait / landscape / desktop)
func _layout() -> void:
	if _menu == null:
		return
	var s := get_viewport().get_visible_rect().size
	var portrait := s.y > s.x
	var short_side := minf(s.x, s.y)
	var w := clampf(s.x * (0.86 if portrait else 0.42), 280.0, 560.0)
	var title_size := int(clampf(short_side * 0.075, 28, 60))
	_title.add_theme_font_size_override(&"font_size", title_size)
	_subtitle.add_theme_font_size_override(&"font_size", int(clampf(short_side * 0.026, 13, 19)))
	_play_label.add_theme_font_size_override(&"font_size", int(clampf(short_side * 0.05, 24, 38)))
	_count_label.add_theme_font_size_override(&"font_size", int(clampf(short_side * 0.024, 13, 18)))
	_play_btn.custom_minimum_size = Vector2(0, clampf(short_side * 0.15, 84, 120))
	for b in [_settings_btn, _about_btn, _exit_btn, _single_btn, _online_btn, _back_btn]:
		(b as Button).add_theme_font_size_override(&"font_size", int(clampf(short_side * 0.03, 16, 22)))
	var qr_side := clampf(short_side * 0.12, 64.0, 104.0)
	for id in qr_items:
		var r := qr_items[id]["rect"] as TextureRect
		r.custom_minimum_size = Vector2(qr_side, qr_side)
	var qr_h := qr_side + 30.0
	for box in [_menu_box, _play_box]:
		var c := box as Control
		c.size = Vector2(w, 0)
		c.reset_size()
		c.size.x = w
		var h := c.get_combined_minimum_size().y
		var avail := s.y - qr_h - 30.0
		c.position = Vector2((s.x - w) * 0.5, maxf(16.0, (avail - h) * 0.5))
	_qr_row.size = Vector2(s.x, qr_h)
	_qr_row.position = Vector2(0, s.y - qr_h - 10.0)
	_version.position = Vector2(12, s.y - 24)
	_lang_btn.position = Vector2(s.x - 130, 12)
	_lang_btn.size = Vector2(118, 40)
	settings.position = Vector2((s.x - minf(s.x * 0.94, 620.0)) * 0.5, 12)
	settings.size = Vector2(minf(s.x * 0.94, 620.0), s.y - 24)
	var aw := minf(s.x * 0.9, 560.0)
	about.position = Vector2((s.x - aw) * 0.5, s.y * 0.14)
	about.size = Vector2(aw, 0)
	loading.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _rebuild_texts() -> void:
	_title.text = GameBrand.title()
	_subtitle.text = GameBrand.subtitle()
	_play_label.text = T("بازی", "Play")
	_settings_btn.text = T("تنظیمات", "Settings")
	_about_btn.text = T("درباره", "About")
	_exit_btn.text = T("خروج", "Exit")
	_exit_btn.visible = not (OS.has_feature("web") or OS.has_feature("ios"))
	_single_btn.text = T("تک‌نفره", "Single-player")
	_online_btn.text = T("آنلاین — با دوستان (کد اتاق / فهرست / IP)", "Online — with friends (room code / list / IP)")
	_back_btn.text = T("بازگشت", "Back")
	_lang_btn.text = T("English", "فارسی")
	_version.text = "v%s (%s)" % [GameBrand.version(), GameBrand.build_id()]
	for id in qr_items:
		var it: Dictionary = qr_items[id]
		(it["link"] as LinkButton).text = T(str(it["fa"]), str(it["en"]))
	(about.find_child("AboutText", true, false) as Label).text = about_text()
	(about.find_child("AboutBack", true, false) as Button).text = T("بازگشت", "Back")
	if _counter:
		_on_counter(_counter.last)
	_layout()


func _toggle_lang() -> void:
	var cur := str(Settings.get_value("dialogue_language"))
	Settings.set_value("dialogue_language", "en" if cur == "fa" else "fa")


# ------------------------------------------------------------------ actions
func _on_play() -> void:
	_show_play_box()


func _on_single() -> void:
	start_loading("single")


func _on_online() -> void:
	mode = "online"
	visible = false
	online_requested.emit()


func _on_back() -> void:
	show_menu(false)


func _on_settings() -> void:
	state = "settings"
	_menu_box.visible = false
	_play_box.visible = false
	settings.open()


func _on_about() -> void:
	state = "about"
	_menu_box.visible = false
	about.visible = true
	_layout()


func _on_exit() -> void:
	get_tree().quit()


## Called by the lobby when a room was joined (or direct connect is online).
func online_ready() -> void:
	visible = true
	start_loading("online")


func start_loading(m: String) -> void:
	mode = m
	state = "loading"
	_menu.visible = false
	settings.visible = false
	about.visible = false
	loading.waiting_for_assets = loading_path != "" and AssetPacks.enabled
	loading.asset_keys = REQUIRED_WEB_PACKS
	loading.start(loading_path)
	if loading.waiting_for_assets:
		var assets_ready := false
		for attempt in 3:
			AssetPacks.reset_retry(REQUIRED_WEB_PACKS)
			assets_ready = await AssetPacks.ensure_all(REQUIRED_WEB_PACKS)
			if assets_ready:
				break
			if attempt < 2:
				await get_tree().create_timer(2.0 * float(attempt + 1)).timeout
		if not assets_ready:
			loading.fail(T("دانلود فایل‌های شهر کامل نشد. دکمهٔ تلاش دوباره را بزن.",
				"The town files could not be downloaded. Press Retry."))
			return
		loading.waiting_for_assets = false


func _on_loading_finished() -> void:
	_enter_game(mode)


func _enter_game(m: String) -> void:
	if entered:
		return
	entered = true
	completed = true
	state = "game"
	visible = false
	if _counter:
		_counter.set_process(false)
	GameEvents.close_modal("entry")
	if loading_path == "":
		print("ENTRY: in game (%s)" % m)
	entered_game.emit(m)


## Re-open the menu (e.g. from a pause menu). Skips the splash.
func open() -> void:
	entered = false
	visible = true
	GameEvents.open_modal("entry")
	show_menu(true)


# ------------------------------------------------------------------ input: skip splash, Enter = default
func _input(event: InputEvent) -> void:
	if not visible or state == "game":
		return
	var press := (event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo) \
		or (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if state == "splash" and press:
		skip_splash()
		get_viewport().set_input_as_handled()
		return
	if state == "loading":
		if event is InputEventKey:
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and (event as InputEventKey).pressed and not (event as InputEventKey).echo:
		var k := (event as InputEventKey).keycode
		if k == KEY_ENTER or k == KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			match state:
				"menu":
					_on_play()
				"play":
					_on_single()
		elif k == KEY_ESCAPE and state in ["play", "about"]:
			get_viewport().set_input_as_handled()
			show_menu(false)
