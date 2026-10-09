extends CanvasLayer
## HUD root. Builds the whole UI in code:
##   TopBar (clock / weather / money / Bag / Save / Connect / Logout / gear),
##   contextual fading prompt, toasts, stamina bar, sheep affection, location
##   label, fishing cue, inventory, voice HUD, Settings, Controls, Shop and the
##   title screen. Also owns the global (non-movement) hotkeys.
## There is deliberately NO permanent key-hint bar: F1 opens Controls.

var top_bar: TopBar
var settings_panel: SettingsPanel
var controls_menu: ControlsMenu
var inventory_panel: InventoryPanel
var voice_hud: VoiceHud
var stamina_bar: StaminaBar
var title_screen: TitleScreen
var minimap: Minimap
var shop_panel: Control
var crafting_panel: CraftingPanel
var people_panel: PeoplePanel
## v5b
var npc_card: NpcCard
var needs_hud: NeedsHud
var cooking_panel: CookingPanel
## v5c
var prices_panel: PricesPanel
var livestock_panel: LivestockPanel
var root: Control

var _prompt_panel: PanelContainer
var _prompt_label: Label
var _prompt_text: String = ""
var _prompt_alpha: float = 0.0
var _toast_label: Label
var _toast_tween: Tween
var _affection_panel: PanelContainer
var _affection_label: Label
var _affection_bar: ProgressBar
var _affection_timer: float = 0.0
var _location: Label
var _fish_cue: Label


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# v5b: default font + Persian fallback (fonts module) for every panel.
	var th := Theme.new()
	th.default_font = Lang.ui_font()
	root.theme = th
	add_child(root)

	stamina_bar = StaminaBar.new()
	root.add_child(stamina_bar)
	needs_hud = NeedsHud.new()
	root.add_child(needs_hud)
	_build_affection()
	_build_prompt()
	_location = UIKit.label(root, "", 17, Color(1, 0.95, 0.85))
	_location.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_location.offset_left = -250
	_location.offset_right = 250
	_location.offset_top = 56
	_location.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_location, 6)
	_fish_cue = UIKit.label(root, "!", 80, Color(1, 0.85, 0.2))
	_fish_cue.set_anchors_preset(Control.PRESET_CENTER)
	_fish_cue.offset_left = -200
	_fish_cue.offset_right = 200
	_fish_cue.offset_top = -170
	_fish_cue.offset_bottom = -60
	_fish_cue.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_outline(_fish_cue, 14)
	_fish_cue.visible = false
	_toast_label = UIKit.label(root, "", 28, Color(1, 0.95, 0.85))
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -420
	_toast_label.offset_right = 420
	_toast_label.offset_top = 92
	_toast_label.offset_bottom = 140
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_outline(_toast_label, 10)
	_toast_label.modulate.a = 0.0

	minimap = Minimap.new()
	root.add_child(minimap)
	voice_hud = VoiceHud.new()
	root.add_child(voice_hud)
	inventory_panel = InventoryPanel.new()
	root.add_child(inventory_panel)
	top_bar = TopBar.new()
	root.add_child(top_bar)
	shop_panel = PanelContainer.new()
	shop_panel.name = "ShopPanel"
	shop_panel.set_script(load("res://scripts/ui/shop_panel.gd"))
	shop_panel.set_anchors_preset(Control.PRESET_CENTER)
	shop_panel.offset_left = -430
	shop_panel.offset_right = 430
	shop_panel.offset_top = -240
	shop_panel.offset_bottom = 240
	shop_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	shop_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(shop_panel)
	crafting_panel = CraftingPanel.new()
	root.add_child(crafting_panel)
	people_panel = PeoplePanel.new()
	root.add_child(people_panel)
	npc_card = NpcCard.new()
	root.add_child(npc_card)
	cooking_panel = CookingPanel.new()
	root.add_child(cooking_panel)
	prices_panel = PricesPanel.new()
	root.add_child(prices_panel)
	livestock_panel = LivestockPanel.new()
	root.add_child(livestock_panel)
	settings_panel = SettingsPanel.new()
	root.add_child(settings_panel)
	controls_menu = ControlsMenu.new()
	root.add_child(controls_menu)
	title_screen = TitleScreen.new()
	root.add_child(title_screen)

	top_bar.settings_pressed.connect(toggle_settings)
	top_bar.bag_pressed.connect(inventory_panel.toggle)
	top_bar.logout_pressed.connect(logout)
	settings_panel.controls_requested.connect(open_controls)
	GameEvents.interaction_prompt_changed.connect(func(t: String) -> void: _prompt_text = t)
	GameEvents.affection_changed.connect(_on_affection_changed)
	GameEvents.notification_requested.connect(toast)
	GameEvents.fishing_state_changed.connect(_on_fishing)
	GameEvents.building_entered.connect(_on_building_entered)
	GameEvents.building_exited.connect(func(_b: Node3D) -> void: _location.text = "")
	GameEvents.ui_panel_requested.connect(_on_panel_requested)
	if not bool(Settings.get_value("tip_shown")):
		_first_tip.call_deferred()


func _outline(l: Label, size: int) -> void:
	l.add_theme_constant_override(&"outline_size", size)
	l.add_theme_color_override(&"font_outline_color", Color(0.22, 0.12, 0.06, 0.9))


func _build_prompt() -> void:
	_prompt_panel = PanelContainer.new()
	_prompt_panel.name = "PromptPanel"
	var st := UIKit.style(Color(0.98, 0.95, 0.86, 0.9), 20, 10, true)
	st.content_margin_left = 22
	st.content_margin_right = 22
	_prompt_panel.add_theme_stylebox_override(&"panel", st)
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_top = -132
	_prompt_panel.offset_bottom = -90
	_prompt_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_panel.modulate.a = 0.0
	root.add_child(_prompt_panel)
	_prompt_label = UIKit.label(_prompt_panel, "", 20, UIKit.INK)
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_affection() -> void:
	_affection_panel = PanelContainer.new()
	_affection_panel.add_theme_stylebox_override(&"panel", UIKit.style(UIKit.DARK, 10, 10))
	_affection_panel.position = Vector2(20, 64)
	_affection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_affection_panel.modulate.a = 0.0
	root.add_child(_affection_panel)
	var v := VBoxContainer.new()
	_affection_panel.add_child(v)
	_affection_label = UIKit.label(v, "Sheep affection", 15, Color(1, 1, 1))
	_affection_bar = ProgressBar.new()
	_affection_bar.custom_minimum_size = Vector2(220, 10)
	_affection_bar.show_percentage = false
	_affection_bar.step = 0.01
	_affection_bar.add_theme_stylebox_override(&"fill", UIKit.style(Color(0.93, 0.45, 0.5), 5, 0))
	_affection_bar.add_theme_stylebox_override(&"background", UIKit.style(Color(1, 1, 1, 0.15), 5, 0))
	v.add_child(_affection_bar)


func _process(delta: float) -> void:
	# Contextual prompt fades in/out; hidden while a modal is open or when
	# prompts are turned off in Settings.
	var want := not _prompt_text.is_empty() and not GameEvents.ui_open and bool(Settings.get_value("prompts"))
	if want and _prompt_label.text != _prompt_text:
		_prompt_label.text = _prompt_text
		_prompt_panel.reset_size()
		_prompt_panel.offset_left = -_prompt_panel.size.x * 0.5
		_prompt_panel.offset_right = _prompt_panel.size.x * 0.5
	_prompt_alpha = move_toward(_prompt_alpha, 1.0 if want else 0.0, delta * 5.0)
	_prompt_panel.modulate.a = _prompt_alpha
	_prompt_panel.visible = _prompt_alpha > 0.01
	if _affection_timer > 0.0:
		_affection_timer -= delta
		_affection_panel.modulate.a = clampf(_affection_timer, 0.0, 1.0)


func toast(text: String) -> void:
	_toast_label.text = text
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_property(_toast_label, "modulate:a", 1.0, 0.2)
	_toast_tween.tween_interval(2.2)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.6)


func _first_tip() -> void:
	await get_tree().create_timer(1.5).timeout
	toast(Lang.loc_ui("Tip: press F1 (or ?) to see all controls"))
	Settings.set_value("tip_shown", true)


func _on_affection_changed(animal_name: String, value: int, max_value: int) -> void:
	_affection_label.text = "%s affection  %d / %d" % [animal_name, value, max_value]
	_affection_bar.max_value = max_value
	create_tween().tween_property(_affection_bar, "value", float(value), 0.35)
	if Engine.get_process_frames() > 30:
		_affection_timer = 6.0


func _on_fishing(state: String) -> void:
	_fish_cue.visible = state == "bite"
	if state == "bite":
		_fish_cue.text = "!  Press E"
		_fish_cue.pivot_offset = Vector2(200, 55)
		_fish_cue.scale = Vector2(0.6, 0.6)
		create_tween().tween_property(_fish_cue, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK)


func _on_building_entered(b: Node3D) -> void:
	var bld := b as Building
	if bld:
		var t := bld.sign_text if bld.sign_text != "" else ("%s's house" % bld.owner_name if bld.owner_name != "" else "House")
		if Lang.is_fa():
			# v6a: Persian place names; addresses keep the street name, digits localised.
			if bld.sign_text == "" and bld.owner_name != "":
				t = "خانه‌ی %s" % bld.owner_name
			_location.text = Lang.loc(t) + ("  ·  " + SignText.address(bld.address) if bld.address != "" else "")
		else:
			_location.text = t + ("  ·  " + bld.address if bld.address != "" else "")


func _on_panel_requested(panel: String) -> void:
	match panel:
		"voice":
			settings_panel.close()
			voice_hud.toggle_panel()
		"controls":
			open_controls()
		"settings":
			toggle_settings()
		"inventory":
			inventory_panel.toggle()


func toggle_settings() -> void:
	if settings_panel.visible:
		settings_panel.close()
	else:
		controls_menu.close()
		settings_panel.open()


func open_controls() -> void:
	settings_panel.close()
	controls_menu.open()


func logout() -> void:
	settings_panel.close()
	controls_menu.close()
	inventory_panel.close()
	title_screen.open()


## Esc: close the top-most panel, otherwise open the menu.
func back() -> void:
	if title_screen.visible:
		return
	if controls_menu.visible:
		controls_menu.close()
	elif settings_panel.visible:
		settings_panel.close()
	elif shop_panel.visible:
		shop_panel.call(&"close_shop")
	elif crafting_panel.visible:
		crafting_panel.close()
	elif cooking_panel.visible:
		cooking_panel.close()
	elif prices_panel.visible:
		prices_panel.close()
	elif livestock_panel.visible:
		livestock_panel.close()
	elif people_panel.visible:
		people_panel.close()
	elif inventory_panel.visible or voice_hud.panel.visible:
		inventory_panel.close()
		voice_hud.panel.visible = false
	else:
		settings_panel.open()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventJoypadMotion:
		return
	if not event.is_pressed() or event.is_echo():
		return
	if title_screen.visible:
		return
	var handled := true
	if event.is_action(&"menu"):
		back()
	elif event.is_action(&"open_controls"):
		if controls_menu.visible:
			controls_menu.close()
		else:
			open_controls()
	elif event.is_action(&"open_settings"):
		toggle_settings()
	elif event.is_action(&"quick_save"):
		var ok := SaveGame.save_game()
		toast("Game saved" if ok else "Save failed: " + SaveGame.last_error)
	elif event.is_action(&"quick_load"):
		var ok2 := SaveGame.load_game()
		toast("Game loaded" if ok2 else SaveGame.last_error)
	elif event.is_action(&"quit") and not OS.has_feature("web"):
		get_tree().quit()
	elif event.is_action(&"people_panel") and (people_panel.visible or not GameEvents.ui_open):
		people_panel.toggle()
	elif event.is_action(&"market_prices") and (prices_panel.visible or not GameEvents.ui_open):
		prices_panel.toggle()
	elif GameEvents.ui_open:
		handled = false
	elif event.is_action(&"time_pause"):
		TimeManager.toggle_pause()
		toast("Clock paused" if TimeManager.paused else "Clock running")
	elif event.is_action(&"time_slower"):
		TimeManager.slower()
		toast("Clock speed %sx" % str(TimeManager.speed()))
	elif event.is_action(&"time_faster"):
		TimeManager.faster()
		toast("Clock speed %sx" % str(TimeManager.speed()))
	elif event.is_action(&"toggle_day_night"):
		TimeManager.toggle_day_night()
		toast("Day/night cycle " + ("on" if TimeManager.day_night_enabled else "off"))
	elif event.is_action(&"next_season"):
		TimeManager.next_season()
		toast("Season: " + TimeManager.season_name())
	elif event.is_action(&"toggle_sound"):
		settings_panel.toggle_sound()
	elif event.is_action(&"toggle_shadows"):
		settings_panel.cycle_shadows()
	elif event.is_action(&"toggle_minimap"):
		minimap.toggle()
		toast("Minimap on" if minimap.visible else "Minimap off")
	elif event.is_action(&"toggle_hints"):
		# v7b: H is the headlight switch while driving.
		var drv := get_tree().get_first_node_in_group(&"player") as Player
		if drv == null or drv.vehicle == null:
			settings_panel.toggle_prompts()
	elif event.is_action(&"toggle_inventory"):
		inventory_panel.toggle()
	elif event.is_action(&"cycle_seed"):
		Economy.cycle_seed()
		var sid := Economy.selected_seed
		toast("Seed: " + ("none" if sid == "" else GameData.item_name(sid)))
	elif event.is_action(&"voice_panel"):
		voice_hud.toggle_panel()
	else:
		handled = false
	if handled:
		get_viewport().set_input_as_handled()
