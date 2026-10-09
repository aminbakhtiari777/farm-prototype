class_name PlatformSmoke
extends RefCounted
## Smoke checks for the v7b.1 platform layer (entry flow, QR, loading, settings,
## updates, brand, config placeholders, rooms API).


static func run(dev: Node) -> bool:
	var check: Callable = dev._check
	var tree := dev.get_tree()
	var cfg := ServerConfig.load_config()
	check.call(cfg.port == 9080, "ServerConfig default port 9080")
	check.call(cfg.is_placeholder() and cfg.websocket_url() == "" and cfg.health_http_url() == "", "placeholder host YOUR_SERVER_HOST: no ws/health URL (no auto-connect)")
	check.call(cfg.max_per_room >= 4 and cfg.max_per_room <= 8, "max_per_room in 4..8 (free host): %d" % cfg.max_per_room)
	check.call(not Net.connect_to("ws://YOUR_SERVER_HOST:9080") and Net.state == "offline", "Net refuses the placeholder URL and stays offline")
	check.call(GameBrand.version() == "7.1.0" and GameBrand.app_name() == "FarmTown", "brand: FarmTown v%s" % GameBrand.version())
	check.call(GameBrand.title_fa() == "مزرعهٔ شهر" and GameBrand.title_en() == "Farm Town", "title fa/en from config/server.cfg")
	check.call(str(ProjectSettings.get_setting("application/config/name", "")) == "Farm Town", "project name Farm Town")
	var icon := str(ProjectSettings.get_setting("application/config/icon", ""))
	check.call(icon != "" and ResourceLoader.exists(icon) and ResourceLoader.exists(GameBrand.ICON_PNG), "app icon + logo exist (%s)" % icon)
	var plat := tree.current_scene.get_node_or_null(^"V7b1Platform") as V7b1Platform
	check.call(plat != null and plat.entry != null and plat.lobby != null, "V7b1Platform: entry flow + lobby present")
	if plat == null:
		return true
	var e := plat.entry
	check.call(e.entered and not e.visible and EntryFlow.completed and not GameEvents.is_modal_open("entry"), "tests auto-enter single-player (menu closed, no modal)")
	check.call(e.root.theme != null and e.root.theme.default_font == Lang.ui_font(), "entry uses V6bWorld.ui_theme (Vazirmatn)")
	# --- splash + menu animation (re-open for the check, then close again)
	e.entered = false
	e.visible = true
	e.start_splash()
	check.call(e.state == "splash" and e._logo.texture != null, "splash shows the farm logo")
	var y0 := e._logo.position.y
	await dev._frames(20)
	check.call(e._logo.position.y < y0 and e._logo.modulate.a > 0.0, "logo rises from the bottom and fades in")
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	e._input(key)
	check.call(e.state == "menu" and e._menu.visible and not e._splash.visible, "splash is skippable (key) -> menu")
	await dev._frames(2)
	var mx := e._menu_box.position.x
	await dev._frames(40)
	check.call(e._menu_box.position.x <= mx, "menu slides in from the right")
	check.call(e._play_btn.visible and e._settings_btn.visible and e._about_btn.visible, "menu: Play, Settings, About")
	check.call(e._exit_btn.visible == not (OS.has_feature("web") or OS.has_feature("ios")), "Exit hidden only on web / iOS")
	check.call(e._play_btn.custom_minimum_size.y >= 84, "Play is the big button (%d px)" % int(e._play_btn.custom_minimum_size.y))
	check.call(not e.dot_online() and ("—" in e.players_text()), "placeholder server: grey dot + '—' (%s)" % e.players_text())
	e._counter.simulate(true, 3, 1)
	check.call(e.dot_online() and "3" in e.players_text(), "live counter shows players + green dot (%s)" % e.players_text())
	e._counter.simulate(false)
	check.call(not e.dot_online(), "unreachable server -> grey / offline")
	# --- QR codes
	var gh: Dictionary = e.qr_items.get("github", {})
	var li: Dictionary = e.qr_items.get("linkedin", {})
	check.call(not gh.is_empty() and bool(gh["visible"]) and (gh["rect"] as TextureRect).texture != null, "GitHub QR rendered in-engine")
	check.call(not li.is_empty() and not bool(li["visible"]) and not (li["rect"] as TextureRect).get_parent().visible, "LinkedIn QR hidden while placeholder")
	e.open_link("github")
	check.call(e.last_opened_url == "https://github.com/aminbakhtiari777", "GitHub QR / label is a link (%s)" % e.last_opened_url)
	var ref: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/qr_reference.json"))
	if ref is Dictionary:
		var mine := QrEncoder.encode(str(ref["text"]))
		check.call(int(mine["version"]) == int(ref["version"]) and int(mine["mask"]) == int(ref["auto_mask"]), "QR encoder picks version %d mask %d like the reference" % [int(mine["version"]), int(mine["mask"])])
		check.call(QrEncoder.to_strings(mine) == PackedStringArray(ref["auto"]), "QR matrix identical to the Python reference")
		var m5 := QrEncoder.encode(str(ref["text"]), 5)
		check.call(QrEncoder.to_strings(m5) == PackedStringArray(ref["mask5_qrcode_lib"]), "QR (mask 5) identical to the Python qrcode library")
	else:
		check.call(false, "qr_reference.json readable")
	# --- Play -> sub menu, Enter key defaults
	var enter := InputEventKey.new()
	enter.keycode = KEY_ENTER
	enter.pressed = true
	e._input(enter)
	check.call(e.state == "play" and e._single_btn.visible and e._online_btn.visible, "Enter / Play -> Single-player + Online")
	# --- Settings screen
	e.show_menu(false)
	e._on_settings()
	await dev._frames(2)
	var s := e.settings
	check.call(s.visible and s.lang_opt != null and s.quality_opt != null and s.touch_opt != null, "settings: language, quality, touch")
	check.call(s.sliders.has("volume") and s.sliders.has("music_volume") and s.sliders.has("adhan_volume") and s.sliders.has("bell_volume") and s.sliders.has("camera_sensitivity"), "settings: volume / music / adhan / bells / mouse sliders")
	var q0 := str(Settings.get_value("quality"))
	check.call(s.quality_opt.item_count == 4, "quality: Auto / Low / Medium / High")
	s.quality_opt.item_selected.emit(1)
	check.call(str(Settings.get_value("quality")) == "low", "quality Low -> Settings 'quality' = low (perf preset)")
	Settings.set_value("quality", q0)
	var inv0 := bool(Settings.get_value("camera_invert_y"))
	s.invert_chk.toggled.emit(not inv0)
	check.call(bool(Settings.get_value("camera_invert_y")) == not inv0, "invert Y toggles ControlInput's camera_invert_y")
	Settings.set_value("camera_invert_y", inv0)
	var had_user := FileAccess.file_exists(ServerConfig.USER_PATH)
	var backup := FileAccess.get_file_as_string(ServerConfig.USER_PATH) if had_user else ""
	s.host_edit.text = "game.example.ir"
	s.port_edit.text = "9090"
	check.call(s.save_server() == OK and ServerConfig.load_config().host == "game.example.ir" and ServerConfig.load_config().port == 9090, "server address/port saved to user://server.cfg")
	check.call(ServerConfig.load_config().websocket_url() == "ws://game.example.ir:9090", "user://server.cfg overrides res:// config")
	if had_user:
		var f := FileAccess.open(ServerConfig.USER_PATH, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerConfig.USER_PATH))
	check.call(ServerConfig.load_config().is_placeholder(), "placeholder restored after the test")
	s.visible = false
	# --- About
	e.show_menu(false)
	e._on_about()
	check.call(e.about.visible and GameBrand.version() in e.about_text() and ("امین" in e.about_text() or "Amin" in e.about_text()) and "Zamith" in e.about_text() and "Quaternius" in e.about_text(), "About: name, version, credits, Amin / Zamith")
	# --- Loading screen
	e.entered = false
	e.start_loading("single")
	check.call(e.loading.visible and e.loading.running and e.loading.tip_text() != "", "loading screen with tip: %s" % e.loading.tip_text().left(40))
	var t0 := Time.get_ticks_msec()
	while e.loading.running and Time.get_ticks_msec() - t0 < 6000:
		await dev._frames(5)
	check.call(not e.loading.running and is_equal_approx(e.loading.progress, 1.0) and e.entered and not e.visible, "progress bar reaches 100%% (%s) and enters the game" % e.loading.source)
	check.call(not GameEvents.is_modal_open("entry"), "no entry modal left open")
	# --- Updates
	var u := plat.updates
	u.simulate("offline", {})
	check.call(u.last_status == "offline", "update: offline -> keep playing")
	check.call(UpdateClient.evaluate("7.1.1", "7.1.0") == "update_available", "update: newer version offered")
	u.decline()
	check.call(u.last_status == "declined" and GameBrand.version() == "7.1.0", "update: declining keeps the installed version")
	check.call(UpdateClient.evaluate("7.0.9", "7.1.0") == "up_to_date", "update: older remote ignored")
	u.check_now(true)
	check.call(u.last_status == "disabled", "update: empty manifest_url -> no request")
	var pl := tree.root.get_node_or_null(^"PackLoader")
	check.call(pl != null and pl.has_method("mount") and pl.has_method("register_installed"), "PackLoader autoload mounts user://updates packs")
	# --- Version compatibility
	check.call(cfg.versions_compatible("7.1.0") and cfg.versions_compatible("7.1.9"), "compatible: same / 7.1.x")
	check.call(not cfg.versions_compatible("1.0.0") and not cfg.versions_compatible("7.2.0"), "incompatible: 1.0.0 / 7.2.0 asked to update")
	check.call(Net.has_method("create_room") and Net.has_method("join_room") and Net.has_method("request_room_list") and Net.has_method("send_ping"), "Net room + heartbeat API")
	# --- LOCALNET: home Wi-Fi server option (config/server.cfg [local_network])
	var lan := ServerConfig.local_network()
	check.call(lan != null and lan.host == "192.168.1.57" and lan.port == 9080 and lan.health_port == 9081 and not lan.tls, "config [local_network] parses: 192.168.1.57 port 9080 health 9081 ws://")
	check.call(lan != null and lan.websocket_url() == "ws://192.168.1.57:9080" and lan.health_http_url() == "http://192.168.1.57:9081/health", "local network -> ws://192.168.1.57:9080 + http://192.168.1.57:9081/health")
	check.call(ServerConfig.load_config().host == ServerConfig.PLACEHOLDER_HOST and ServerConfig.selected_profile() == ServerConfig.PROFILE_MAIN and ServerConfig.load_active().is_placeholder(), "main [server] host stays YOUR_SERVER_HOST and is the default profile")
	var had_u2 := FileAccess.file_exists(ServerConfig.USER_PATH)
	var bak2 := FileAccess.get_file_as_string(ServerConfig.USER_PATH) if had_u2 else ""
	plat.lobby.select_profile(ServerConfig.PROFILE_LOCAL, false)  # no connect in tests
	var act := ServerConfig.load_active()
	var pick_ok := act.resolve_client_url() == "ws://192.168.1.57:9080" and act.health_http_url() == "http://192.168.1.57:9081/health" \
		and plat.lobby.server_opt.selected == 1 and "192.168.1.57:9080" in plat.lobby.server_opt.get_item_text(1) and Net.state == "offline"
	var pick_text := plat.lobby.server_opt.get_item_text(1)
	plat.lobby.select_profile(ServerConfig.PROFILE_MAIN, false)
	if had_u2:
		var f2 := FileAccess.open(ServerConfig.USER_PATH, FileAccess.WRITE)
		f2.store_string(bak2)
		f2.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(ServerConfig.USER_PATH))
	check.call(pick_ok and ServerConfig.selected_profile() == ServerConfig.PROFILE_MAIN and ServerConfig.load_active().is_placeholder(), "lobby picker '%s' -> Host/Join + player counter use it; back to main after" % pick_text)
	# --- Lobby panel (no connection with placeholder)
	plat.lobby.open()
	check.call(plat.lobby.visible and Net.state == "offline", "lobby opens without connecting to the placeholder")
	plat.lobby.close()
	return true
