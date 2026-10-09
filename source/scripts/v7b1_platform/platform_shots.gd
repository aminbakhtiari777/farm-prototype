extends Node
## v7b.1 platform screenshots:
##   xvfb-run -a -s "-screen 0 1600x900x24" godot --path . -- --plat-shots=/workspace/farm-v7b1 [--portrait]
## Writes -splash, -menu (=-title), -lobby (play counter), -online-lobby, -settings,
## -loading and a short splash/menu frame sequence (-anim-NN.png).

var prefix: String = "/workspace/farm-v7b1"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--plat-shots="):
			prefix = a.trim_prefix("--plat-shots=")
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _cap(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s-%s.png" % [prefix, name]
	img.save_png(path)
	print("PLATSHOT ", path)


func _run() -> void:
	var plat := get_parent() as V7b1Platform
	var e := plat.entry
	Settings.set_value("dialogue_language", "fa")
	await _frames(30)
	e.start_splash()
	# Animation frame sequence (every ~0.25 s).
	for i in 12:
		await _frames(15)
		await _cap("anim-%02d" % i)
		if i == 4:
			await _cap("splash")
		if e.state == "menu":
			break
	if e.state == "splash":
		e.skip_splash()
	for i in range(12, 16):
		await _frames(8)
		await _cap("anim-%02d" % i)
	await _frames(30)
	e._counter.simulate(true, 4, 2)
	await _frames(10)
	await _cap("menu")
	await _cap("title")
	e._show_play_box()
	await _frames(40)
	await _cap("lobby")
	e._on_online()
	plat.lobby._direct_edit.text = "ws://YOUR_SERVER_HOST:9080"
	plat.lobby.last_code = "K7M2QX"
	plat.lobby._refresh_status()
	plat.lobby._on_room_list([{"code": "K7M2QX", "players": 2, "max": 6}, {"code": "MAIN", "players": 1, "max": 6}])
	await _frames(15)
	await _cap("online-lobby")
	plat.lobby.visible = false
	e.visible = true
	e.show_menu(false)
	e._on_settings()
	await _frames(15)
	await _cap("settings")
	e.settings.visible = false
	e.loading.min_secs = 30.0
	e.start_loading("single")
	await _frames(50)
	await _cap("loading")
	print("PLATFORM SHOTS DONE")
	get_tree().quit(0)
