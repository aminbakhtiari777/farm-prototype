extends Node
## v5d network test client driver (loaded by main.gd ONLY with `-- --net-test=<id>`).
## tools/net_test.py starts the server and two clients and steers them through
## command files; this node executes the commands and reports state:
##   <net-dir>/ctl_<id>.json     {"cmds": [{"n": 1, "op": "walk", ...}, ...]} (python writes)
##   <net-dir>/status_<id>.json  this client's view (written every 0.25 s)

var id: String = "A"
var dir: String = "/tmp/v5d-net"
var _done: Dictionary = {}
var _acc: float = 0.0
var _move: Vector3 = Vector3.ZERO
var _move_left: float = 0.0
var _events: Array = []
var _chat: Array = []
var _updates: Array = []
var _frames: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--net-test="):
			id = a.trim_prefix("--net-test=")
		elif a.begins_with("--net-dir="):
			dir = a.trim_prefix("--net-dir=")
		elif a.begins_with("--net-name="):
			Settings.set_value("player_name", a.trim_prefix("--net-name="))
	Net.chat_received.connect(func(pid: int, s: String, t: String) -> void: _chat.append([pid, s, t]))
	Net.avatar_event.connect(func(pid: int, k: String, npc: String, _l: String) -> void: _events.append([pid, k, npc]))
	Net.module_updated.connect(func(t: String, v: int, ok: bool, e: String) -> void: _updates.append([t, v, ok, e]))
	# The title screen would block input in a normal start: close it.
	var hud := get_tree().current_scene.get_node_or_null(^"HUD")
	if hud and hud.get("title_screen"):
		var ts: Node = hud.get("title_screen")
		if ts.has_method("close"):
			ts.call("close")
	print("NETTEST %s ready" % id)


func _player() -> Node3D:
	return get_tree().get_first_node_in_group(&"player") as Node3D


func _physics_process(delta: float) -> void:
	_frames += 1
	var p := _player()
	if p and _move_left > 0.0:
		_move_left -= delta
		var np := p.global_position + _move * delta
		np.y = Terrain.height_at(np.x, np.z) + 0.05
		p.global_position = np
		(p as CharacterBody3D).velocity = _move
	elif p and _move != Vector3.ZERO:
		_move = Vector3.ZERO
		(p as CharacterBody3D).velocity = Vector3.ZERO
	_acc += delta
	if _acc >= 0.25:
		_acc = 0.0
		_read_ctl()
		_write_status()


func _read_ctl() -> void:
	var path := dir + "/ctl_%s.json" % id
	if not FileAccess.file_exists(path):
		return
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (v is Dictionary):
		return
	for c: Dictionary in (v as Dictionary).get("cmds", []):
		var n := int(c.get("n", 0))
		if _done.has(n):
			continue
		_done[n] = true
		_run(c)


func _run(c: Dictionary) -> void:
	var op := str(c.get("op", ""))
	print("NETTEST %s cmd %s" % [id, JSON.stringify(c)])
	match op:
		"walk":
			var d: Array = c.get("dir", [1, 0])
			_move = Vector3(float(d[0]), 0, float(d[1])).normalized() * float(c.get("speed", 2.6))
			_move_left = float(c.get("secs", 1.0))
		"chat":
			Net.send_chat(str(c.get("text", "")))
		"money":
			Economy.money = int(c.get("value", 0))
		"save_now":
			Net.autosave_tick()
		"place":
			var p := _player()
			var xz: Array = c.get("xz", [0, 0])
			if p:
				p.global_position = Vector3(float(xz[0]), Terrain.height_at(float(xz[0]), float(xz[1])) + 0.05, float(xz[1]))
				Net.mark_teleport()
				var vis := p.get_node_or_null(^"Visual") as Node3D
				if vis and c.has("yaw"):
					vis.rotation.y = deg_to_rad(float(c["yaw"]))
		"create_room":
			Net.create_room()
		"join_room":
			Net.join_room(str(c.get("code", "")))
		"list_rooms":
			Net.request_room_list()
		"ping":
			Net.send_ping()
		"quit":
			get_tree().quit(0)


func _vec(v: Vector3) -> Array:
	return [snappedf(v.x, 0.01), snappedf(v.y, 0.01), snappedf(v.z, 0.01)]


func _write_status() -> void:
	var p := _player()
	var remotes := {}
	var ra := get_tree().current_scene.get_node_or_null(^"RemoteAvatars") as RemoteAvatars
	if ra:
		for pid in ra.avatars:
			var av: RemoteAvatar = ra.avatars[pid]
			remotes[str(pid)] = {"pos": _vec(av.global_position), "status": av.status, "dest": av.dest, "name": av.display_name, "teas": av.teas}
	var wages := Modules.style("wages") as WagesStyle
	var st := {
		"id": id, "frames": _frames, "state": Net.state, "pid": Net.my_pid, "roster": Net.roster.size(),
		"pos": _vec(p.global_position) if p else [], "money": Economy.money,
		"remotes": remotes, "chat": _chat, "events": _events, "updates": _updates, "stats": Net.stats,
		"corrections": Net.corrections, "wages_default": wages.default_wage if wages else -1,
		"wages_active": AssetRegistry.active_id("wages"), "installed": ModuleManifest.load_installed().get("modules", {}).keys(),
		"welcome": Net.last_welcome.get("away", {}), "away_memory": AwayMemory.active(),
		"visits_started": ra.visits_started if ra else 0, "clock": [TimeManager.day, snappedf(TimeManager.minutes, 0.1)],
		"has_local_save": SaveGame.has_save(),
		"room": Net.room, "rtt_ms": Net.last_rtt_ms, "pings": int(Net.stats.get("pings", 0)),
		"room_list": Net.room_list, "room_error": Net.last_room_error,
	}
	var f := FileAccess.open(dir + "/status_%s.json.tmp" % id, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(st))
		f.close()
		DirAccess.rename_absolute(dir + "/status_%s.json.tmp" % id, dir + "/status_%s.json" % id)
