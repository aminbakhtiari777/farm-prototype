extends Node
## Native boot scene (exported builds only: feature tag "farm_boot" overrides
## run/main_scene). Shows splash + menu immediately while Main.tscn loads on a
## background thread; Play -> loading bar = real threaded-load progress -> Main.

const MAIN := "res://scenes/world/Main.tscn"


func _ready() -> void:
	if Net.is_server:
		# LOCALNET: exported FarmTown.exe ... -- --server (start_server_windows.bat) -> dedicated server, no menu.
		get_tree().change_scene_to_file.call_deferred("res://scenes/server/Server.tscn")
		return
	var err := ResourceLoader.load_threaded_request(MAIN, "", true)
	if err != OK:
		get_tree().change_scene_to_file.call_deferred(MAIN)
		return
	var plat := V7b1Platform.new()
	plat.boot_main_path = MAIN
	add_child(plat)
