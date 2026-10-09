class_name V7b1Platform
extends Node
## v7b.1 platform layer: splash -> menu -> (single | online lobby) -> loading -> game,
## update check, brand wiring. Web stays offline single-player unless the player
## opts in (no socket / foreign request with the placeholder host).

var entry: EntryFlow
var lobby: LobbyPanel
var updates: UpdateClient
var cfg: ServerConfig
## Set by the Boot scene: Main.tscn is loading on a thread.
var boot_main_path: String = ""


func _ready() -> void:
	name = "V7b1Platform"
	cfg = ServerConfig.load_config()
	if not OS.has_feature("web") and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_title("%s — %s  v%s" % [cfg.title_en, cfg.title_fa, GameBrand.version()])
	updates = UpdateClient.new()
	add_child(updates)
	var shots := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plat-shots="):
			shots = true
	entry = EntryFlow.new()
	if shots:
		entry.auto_web = false
	entry.loading_path = boot_main_path
	add_child(entry)
	if boot_main_path != "":
		entry.entered_game.connect(_boot_to_main)
	lobby = LobbyPanel.new()
	add_child(lobby)
	entry.online_requested.connect(_open_lobby)
	lobby.closed.connect(_lobby_closed)
	lobby.joined_room.connect(func(_code: String) -> void: _online_ready())
	Net.state_changed.connect(func(s: String) -> void:
		# Direct IP connect (no room) also counts as ready once online.
		if s == "online" and lobby.visible and Net.pending_room_action == "":
			_online_ready())
	if bool(Settings.get_value("online_enabled")):
		updates.check_now()
	if shots:
		add_child(load("res://scripts/v7b1_platform/platform_shots.gd").new())


func _open_lobby() -> void:
	lobby.open()


func _lobby_closed() -> void:
	if entry and not entry.entered:
		entry.visible = true
		entry.show_menu(false)


func _online_ready() -> void:
	if entry.entered:
		return
	lobby.visible = false
	GameEvents.close_modal("lobby")
	entry.online_ready()


func _boot_to_main(_mode: String) -> void:
	var packed := ResourceLoader.load_threaded_get(boot_main_path) as PackedScene
	if packed:
		get_tree().change_scene_to_packed.call_deferred(packed)
	else:
		get_tree().change_scene_to_file.call_deferred(boot_main_path)
