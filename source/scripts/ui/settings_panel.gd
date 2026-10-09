class_name SettingsPanel
extends Control
## Settings / pause menu (gear button, Esc or O). Game: clock speed, pause,
## day/night, season jump. Audio & video: volume, mute, shadows, contextual
## prompts. Save / Load / auto-load, Controls, Quit.

signal controls_requested

var _panel: PanelContainer
var _speed_label: Label
var _pause_btn: Button
var _daynight_btn: Button
var _mute_btn: Button
var _quality_btn: Button
var _shadow_btn: Button
var _prompts_btn: Button
var _volume: HSlider
var _adhan_volume: HSlider
var _house_btn: Button
var _yard_btn: Button
var _bell_volume: HSlider
var _season_btns: Array[Button] = []
var _realclock_btn: Button
var _save_info: Label
var _lang_btn: Button
var _voices_btn: Button
## v7b.1 controls row
var _mouse_sens: HSlider
var _invert_btn: Button
var _touch_btn: Button


func toggle_language() -> void:
	Settings.set_value("dialogue_language", "en" if Lang.is_fa() else "fa")
	refresh()


func toggle_voices() -> void:
	Settings.set_value("npc_voices", not bool(Settings.get_value("npc_voices")))
	refresh()

const SHADOW_LEVELS := ["High", "Low", "Off"]
var shadow_level: int = 0


func _ready() -> void:
	name = "SettingsPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var m := UIKit.modal_panel("Settings", Vector2(640, 560))
	_panel = m["panel"]
	add_child(_panel)
	(m["close"] as Button).pressed.connect(close)
	var body: VBoxContainer = m["body"]

	_section(body, "Game")
	var r1 := _row(body)
	_pause_btn = UIKit.button(r1, "Pause clock (P)", TimeManager.toggle_pause)
	UIKit.button(r1, "Slower ([)", TimeManager.slower)
	_speed_label = UIKit.label(r1, "1x", 16, UIKit.INK)
	UIKit.button(r1, "Faster (])", TimeManager.faster)
	_daynight_btn = UIKit.button(r1, "Day/Night: On (N)", TimeManager.toggle_day_night)
	# v6a: follow the real clock (night_sky / real_clock modules; moon phase too).
	_realclock_btn = UIKit.button(r1, "Real clock: Off", toggle_real_clock, "Game time follows your computer's clock; the moon shows its real phase")
	_realclock_btn.name = "RealClockButton"
	var r2 := _row(body)
	UIKit.label(r2, "Season:", 16, UIKit.INK)
	for i in 4:
		var b := UIKit.button(r2, str(GameData.season(i).get("name", "Season")), func() -> void: TimeManager.set_season(i))
		b.toggle_mode = true
		_season_btns.append(b)
	UIKit.label(r2, "(K = next)", 13, UIKit.INK)
	# v5b: dialogue language (Persian / English) and NPC voice blips.
	var rl := _row(body)
	UIKit.label(rl, "Dialogue:", 16, UIKit.INK)
	_lang_btn = UIKit.button(rl, "", toggle_language, "Townspeople speak Persian (فارسی) or English")
	_lang_btn.name = "LanguageButton"
	_voices_btn = UIKit.button(rl, "", toggle_voices, "Pitch-varied voice blips when townspeople talk")

	_section(body, "Audio & video")
	var r3 := _row(body)
	UIKit.label(r3, "Volume", 16, UIKit.INK)
	_volume = HSlider.new()
	_volume.min_value = 0.0
	_volume.max_value = 1.0
	_volume.step = 0.05
	_volume.custom_minimum_size.x = 180
	_volume.focus_mode = Control.FOCUS_NONE
	_volume.value = float(Settings.get_value("volume"))
	_volume.value_changed.connect(func(v: float) -> void: Settings.set_value("volume", v))
	r3.add_child(_volume)
	_mute_btn = UIKit.button(r3, "Sound: On (M)", toggle_sound)
	# v5a: volume of the hourly adhan (mosque module) and church bells.
	var r3b := _row(body)
	UIKit.label(r3b, "Adhan", 16, UIKit.INK)
	_adhan_volume = _small_slider(r3b, "adhan_volume")
	UIKit.label(r3b, "Bells", 16, UIKit.INK)
	_bell_volume = _small_slider(r3b, "bell_volume")
	var r4 := _row(body)
	_shadow_btn = UIKit.button(r4, "Shadows: High (G)", cycle_shadows)
	_prompts_btn = UIKit.button(r4, "Prompts: On (H)", toggle_prompts, "Contextual 'Press E to ...' prompts")
	# v7b.1 perf: graphics preset (quality module). Cycles Auto / Low / Medium / High.
	_quality_btn = UIKit.button(r4, PerfQuality.label(), cycle_quality,
		Lang.loc_ui("Graphics quality (Auto picks Medium on the web and steps down if the game is slow)"))
	_quality_btn.name = "QualityButton"

	# v5a live style swaps (house_styles / yards modules), no reload needed.
	# v7b.1: mouse look sensitivity, invert Y, touch controls (GTA-style controls).
	var rc := _row(body)
	UIKit.label(rc, "Mouse look", 16, UIKit.INK)
	_mouse_sens = HSlider.new()
	_mouse_sens.name = "MouseSensitivitySlider"
	_mouse_sens.min_value = 0.2
	_mouse_sens.max_value = 3.0
	_mouse_sens.step = 0.1
	_mouse_sens.custom_minimum_size.x = 140
	_mouse_sens.focus_mode = Control.FOCUS_NONE
	_mouse_sens.value = float(Settings.get_value("camera_sensitivity"))
	_mouse_sens.value_changed.connect(func(v: float) -> void: Settings.set_value("camera_sensitivity", v))
	rc.add_child(_mouse_sens)
	_invert_btn = UIKit.button(rc, "Invert Y: Off", func() -> void:
		Settings.set_value("camera_invert_y", not bool(Settings.get_value("camera_invert_y"))))
	_invert_btn.name = "InvertYButton"
	_touch_btn = UIKit.button(rc, "Touch controls: Auto", cycle_touch_controls, "Show the touch joysticks and buttons (Auto = on touch screens)")
	_touch_btn.name = "TouchControlsButton"

	_section(body, "Town styles")
	var rs := _row(body)
	_house_btn = UIKit.button(rs, "Houses: Mixed", cycle_house_style, "Rebuild every home in another house style")
	_yard_btn = UIKit.button(rs, "Yards", cycle_yard_style, "Swap the front-yard fences")

	_section(body, "Game data")
	var r5 := _row(body)
	UIKit.button(r5, "Save (F5)", func() -> void:
		var ok := SaveGame.save_game()
		GameEvents.notification_requested.emit(Lang.loc_ui("Game saved") if ok else Lang.loc_ui("Save failed: ") + SaveGame.last_error)
		refresh())
	UIKit.button(r5, "Load (F9)", func() -> void:
		var ok := SaveGame.load_game()
		GameEvents.notification_requested.emit(Lang.loc_ui("Game loaded") if ok else SaveGame.last_error)
		refresh())
	_save_info = UIKit.label(r5, "", 13, UIKit.INK)
	var r6 := _row(body)
	UIKit.button(r6, "Controls (F1)", func() -> void: controls_requested.emit())
	UIKit.button(r6, "Voice / mute list (L)", func() -> void: GameEvents.ui_panel_requested.emit("voice"))
	if not OS.has_feature("web"):
		UIKit.button(r6, "Quit game", func() -> void: get_tree().quit())
	TimeManager.settings_changed.connect(refresh)
	TimeManager.season_changed.connect(func(_s: int) -> void: refresh())
	Settings.changed.connect(func(_k: String, _v: Variant) -> void: refresh())
	refresh.call_deferred()
	if not bool(Settings.get_value("shadows")):
		shadow_level = 2
		_apply_shadows.call_deferred()


## Mixed -> each house style -> Mixed (live rebuild of the homes).
func cycle_house_style() -> void:
	var ids: Array[String] = [""]
	for m in Modules.all("house_styles"):
		ids.append(m.id)
	var i := (ids.find(HouseStyle.town_style) + 1) % ids.size()
	HouseStyle.set_town_style(ids[i])
	GameEvents.notification_requested.emit("Houses: " + (ids[i].capitalize() if ids[i] != "" else "Mixed styles"))
	refresh()


func cycle_yard_style() -> void:
	var reg := get_node_or_null(^"/root/AssetRegistry")
	if reg == null:
		return
	var ids := Array(reg.call("variants", "yards") as PackedStringArray)
	if ids.is_empty():
		return
	var i := (ids.find(reg.call("active_id", "yards")) + 1) % ids.size()
	reg.call("set_active", "yards", ids[i])
	var m := Modules.style("yards")
	GameEvents.notification_requested.emit("Yards: " + (m.display_name if m else str(ids[i])))
	refresh()


func _small_slider(parent: Control, key: String) -> HSlider:
	var sl := HSlider.new()
	sl.name = key.capitalize().replace(" ", "") + "Slider"
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.custom_minimum_size.x = 110
	sl.focus_mode = Control.FOCUS_NONE
	sl.value = float(Settings.get_value(key))
	sl.tooltip_text = "0 = off"
	sl.value_changed.connect(func(v: float) -> void: Settings.set_value(key, v))
	parent.add_child(sl)
	return sl


func _section(parent: Control, text: String) -> void:
	var l := UIKit.label(parent, text, 18, Color(0.45, 0.28, 0.12))
	l.add_theme_constant_override(&"outline_size", 0)


func _row(parent: Control) -> HFlowContainer:
	var r := HFlowContainer.new()
	r.add_theme_constant_override(&"h_separation", 8)
	r.add_theme_constant_override(&"v_separation", 6)
	parent.add_child(r)
	return r


func open() -> void:
	visible = true
	GameEvents.open_modal("settings")
	GameEvents.interaction_prompt_changed.emit("")
	refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.close_modal("settings")


func toggle_sound() -> void:
	Settings.set_value("muted", not bool(Settings.get_value("muted")))
	GameEvents.notification_requested.emit("Sound off" if Settings.get_value("muted") else "Sound on")


func cycle_quality() -> void:
	PerfQuality.cycle()
	GameEvents.notification_requested.emit(PerfQuality.label())
	refresh()


func cycle_shadows() -> void:
	shadow_level = (shadow_level + 1) % SHADOW_LEVELS.size()
	_apply_shadows()
	Settings.set_value("shadows", shadow_level < 2)
	GameEvents.notification_requested.emit("Shadows: " + SHADOW_LEVELS[shadow_level])


func _apply_shadows() -> void:
	var sun := get_tree().current_scene.get_node_or_null(^"Sun") as DirectionalLight3D
	if sun:
		sun.shadow_enabled = shadow_level < 2
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS if shadow_level == 0 else DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = 60.0 if shadow_level == 0 else 35.0
		# v6b shadows module: soft cascades on desktop, cheap on the web.
		ShadowRig.apply(sun, shadow_level)
	refresh()


## v7b.1: Auto -> On -> Off.
func cycle_touch_controls() -> void:
	var order := ["auto", "on", "off"]
	var i := order.find(str(Settings.get_value("touch_controls")))
	Settings.set_value("touch_controls", order[(i + 1) % order.size()])


func toggle_real_clock() -> void:
	Settings.set_value("real_clock", not bool(Settings.get_value("real_clock")))


func toggle_prompts() -> void:
	Settings.set_value("prompts", not bool(Settings.get_value("prompts")))
	GameEvents.notification_requested.emit(Lang.loc_ui("Prompts on" if Settings.get_value("prompts") else "Prompts off"))


func refresh() -> void:
	if _pause_btn == null:
		return
	_pause_btn.text = "Resume clock (P)" if TimeManager.paused else "Pause clock (P)"
	_speed_label.text = ("%sx" % str(TimeManager.speed())).replace(".0x", "x")
	_daynight_btn.text = "Day/Night: %s (N)" % ("On" if TimeManager.day_night_enabled else "Off")
	for i in _season_btns.size():
		_season_btns[i].set_pressed_no_signal(i == TimeManager.season_index())
	_mute_btn.text = "Sound: %s (M)" % ("Off" if Settings.get_value("muted") else "On")
	_shadow_btn.text = "Shadows: %s (G)" % SHADOW_LEVELS[shadow_level]
	if _quality_btn:
		_quality_btn.text = PerfQuality.label()
	_prompts_btn.text = "Prompts: %s (H)" % ("On" if Settings.get_value("prompts") else "Off")
	_volume.set_value_no_signal(float(Settings.get_value("volume")))
	_adhan_volume.set_value_no_signal(float(Settings.get_value("adhan_volume")))
	_bell_volume.set_value_no_signal(float(Settings.get_value("bell_volume")))
	_house_btn.text = "Houses: " + (HouseStyle.town_style.capitalize() if HouseStyle.town_style != "" else "Mixed")
	if _lang_btn:
		_lang_btn.text = "فارسی (Persian)" if Lang.is_fa() else "English"
		_voices_btn.text = "Voices: " + ("On" if bool(Settings.get_value("npc_voices")) else "Off")
	var ym := Modules.style("yards")
	_yard_btn.text = "Yards: " + (ym.display_name if ym else "-")
	_save_info.text = "Save slot: %s%s" % ["browser storage" if OS.has_feature("web") else "user://save.json", " (exists)" if SaveGame.has_save() else " (empty)"]
	_realclock_btn.text = "Real clock: %s" % ("On" if bool(Settings.get_value("real_clock")) else "Off")
	if _invert_btn:
		_invert_btn.text = "Invert Y: %s" % ("On" if bool(Settings.get_value("camera_invert_y")) else "Off")
		_touch_btn.text = "Touch controls: %s" % str(Settings.get_value("touch_controls")).capitalize()
		_mouse_sens.set_value_no_signal(float(Settings.get_value("camera_sensitivity")))
	_translate()


## v6a: every label / button through Lang.loc_ui (Persian by default). Static
## texts remember their English in meta "en"; the ones refresh() rewrites
## (DYNAMIC) are translated from their fresh English text.
func _translate() -> void:
	if _panel == null:
		return
	var dynamic := [_pause_btn, _speed_label, _daynight_btn, _mute_btn, _shadow_btn, _prompts_btn, _house_btn, _lang_btn, _voices_btn, _yard_btn, _save_info, _realclock_btn, _invert_btn, _touch_btn, _quality_btn]
	for n in _panel.find_children("*", "", true, false):
		if not (n is Button or n is Label):
			continue
		var en := ""
		if n in dynamic:
			en = str(n.get("text"))
			if n == _lang_btn:
				continue
		else:
			if not n.has_meta(&"en"):
				n.set_meta(&"en", str(n.get("text")))
				n.set_meta(&"en_tip", str((n as Control).tooltip_text))
			en = str(n.get_meta(&"en"))
			(n as Control).tooltip_text = Lang.loc_ui(str(n.get_meta(&"en_tip")))
		n.set("text", Lang.loc_ui(en))
