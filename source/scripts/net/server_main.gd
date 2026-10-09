extends Node
## v5d dedicated server entry scene (scenes/server/Server.tscn).
##   godot --headless --path . res://scenes/server/Server.tscn -- --server [--port=8910] [--content=DIR] [--data=DIR]
## No 3D world is loaded: the server keeps the authoritative state (players,
## clock, chat, saves, module content, away avatars) and the town navigation
## graph (TownNav / TownLayout, pure data).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not Net.is_server:
		push_error("Server.tscn must be started with -- --server")
		get_tree().quit(2)
		return
	# Keep the server light: no audio, no window.
	AudioServer.set_bus_mute(0, true)
	var srv := NetServer.new()
	srv.name = "Server"
	Net.add_child(srv)
	Net.server = srv
	var err := srv.start(args)
	if err != OK:
		get_tree().quit(3)
