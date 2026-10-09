class_name NetServer
extends Node
## v5d headless dedicated server (child of the Net autoload when the game is
## started with `res://scenes/server/Server.tscn -- --server`). Authoritative:
##   * player positions (client steps checked by NetMove, clamped on cheats)
##   * the shared clock + weather (TimeManager runs here; clients follow)
##   * roster, chat relay (rate limit + length + filter), NPC role claims
##   * per-player saves (data dir), merged with SaveSync rules
##   * module content: built-in manifest + pushed modules (content dir),
##     re-read when tools/push_module.py publishes (clients get it live)
##   * disconnected players: their avatar walks to the cafe / home, sits, and
##     townspeople visit it (greet / tea) until they come back.
##
## Args: --port=8910 --content=DIR --data=DIR --bind=*

var port: int = 8910
var content_dir: String = "user://server_content"
var data_dir: String = "user://server_data"
var bind_address: String = "*"

## pid -> {"guest","name","pos","yaw","speed","state","ack","color","joined"}
var players: Dictionary = {}
## guest -> {"pid","name","pos","yaw","state","route","route_i","since","visits","next_visit","dest","color"}
var away: Dictionary = {}
var npc_roles: Dictionary = {}  ## npc id -> pid
var accounts: Dictionary = {}  ## guest -> {"token_sha", "name"}
var manifest: Dictionary = {}
var _manifest_stamp: String = ""
var _chat_times: Dictionary = {}  ## pid -> [unix...]
var _peer: WebSocketMultiplayerPeer
var _snap_acc: float = 0.0
var _clock_acc: float = 0.0
var _watch_acc: float = 0.0
var _rng := RandomNumberGenerator.new()
var log_lines: Array = []
var rejected_moves: int = 0
## v7b.1 rooms + health + heartbeat (lightweight free-host multiplayer)
var rooms: Dictionary = {}  ## code -> {code, host, members: Array[int], created, name, public}
var _health: HealthHttp
var _cfg: ServerConfig = null
var _hb_acc: float = 0.0
const DEFAULT_ROOM := "MAIN"
const CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"

const COLORS := [Color(0.25, 0.55, 0.9), Color(0.9, 0.45, 0.2), Color(0.35, 0.7, 0.35), Color(0.75, 0.35, 0.75),
	Color(0.9, 0.8, 0.25), Color(0.3, 0.75, 0.75), Color(0.85, 0.3, 0.35), Color(0.55, 0.45, 0.3)]


func _net() -> Node:
	return get_parent()


func log_line(t: String) -> void:
	var line := "[%s] %s" % [Time.get_time_string_from_system(), t]
	print("SERVER " + line)
	log_lines.append(line)
	if log_lines.size() > 200:
		log_lines.pop_front()


func start(args: PackedStringArray) -> int:
	var st := Modules.style("netcode") as NetcodeStyle
	port = st.port if st else 8910
	for a in args:
		if a.begins_with("--port="):
			port = int(a.trim_prefix("--port="))
		elif a.begins_with("--content="):
			content_dir = a.trim_prefix("--content=")
		elif a.begins_with("--data="):
			data_dir = a.trim_prefix("--data=")
		elif a.begins_with("--bind="):
			bind_address = a.trim_prefix("--bind=")
	DirAccess.make_dir_recursive_absolute(_abs(data_dir) + "/saves")
	DirAccess.make_dir_recursive_absolute(_abs(content_dir))
	_load_accounts()
	_reload_manifest(false)
	_peer = WebSocketMultiplayerPeer.new()
	_peer.inbound_buffer_size = st.buffer_bytes if st else 8388608
	_peer.outbound_buffer_size = st.buffer_bytes if st else 8388608
	_peer.max_queued_packets = 8192
	var err := _peer.create_server(port, bind_address)
	if err != OK:
		log_line("cannot listen on %d: %s" % [port, error_string(err)])
		return err
	multiplayer.multiplayer_peer = _peer
	multiplayer.peer_connected.connect(func(id: int) -> void: log_line("peer %d connected" % id))
	multiplayer.peer_disconnected.connect(_on_peer_left)
	TimeManager.paused = false
	_cfg = ServerConfig.load_config()
	# CLI may override port already; health port from config / env.
	for a in args:
		if a.begins_with("--health-port="):
			_cfg.health_port = int(a.trim_prefix("--health-port="))
		elif a.begins_with("--max-per-room="):
			_cfg.max_per_room = int(a.trim_prefix("--max-per-room="))
		elif a.begins_with("--heartbeat-timeout="):
			_cfg.heartbeat_timeout_sec = float(a.trim_prefix("--heartbeat-timeout="))
	rooms.clear()
	_ensure_room(DEFAULT_ROOM, 0, "Public", true)
	_health = HealthHttp.new()
	_health.name = "HealthHttp"
	add_child(_health)
	var herr := _health.start(int(_cfg.health_port))
	if herr == OK:
		_health.set_stats(0, rooms.size(), str(_cfg.game_version))
	log_line("listening on ws://%s:%d  content=%s  data=%s  health=%d  max_per_room=%d" % [
		bind_address, port, _abs(content_dir), _abs(data_dir), int(_cfg.health_port), int(_cfg.max_per_room)])
	print("SERVER READY port=%d" % port)
	return OK


func _abs(p: String) -> String:
	return ProjectSettings.globalize_path(p) if p.begins_with("user://") or p.begins_with("res://") else p


# ------------------------------------------------------------------ manifest + content
## Effective manifest: built-in (res://data/module_manifest.json) overlaid by
## the content dir's manifest.json (written by tools/push_module.py).
func _reload_manifest(broadcast: bool) -> void:
	var man := ModuleManifest.load_builtin()
	var cpath := _abs(content_dir) + "/manifest.json"
	var stamp := ""
	if FileAccess.file_exists(cpath):
		var text := FileAccess.get_file_as_string(cpath)
		stamp = text.sha256_text()
		var v: Variant = JSON.parse_string(text)
		if v is Dictionary:
			for t in (v as Dictionary).get("modules", {}):
				(man["modules"] as Dictionary)[t] = v["modules"][t]
	if stamp == _manifest_stamp and not manifest.is_empty():
		return
	_manifest_stamp = stamp
	manifest = man
	if broadcast:
		log_line("content manifest changed - notifying %d players" % players.size())
		for pid in players:
			_net().s_manifest.rpc_id(int(pid), _public_manifest())
	

func _public_manifest() -> Dictionary:
	# Clients only need versions, active ids and file hashes (no server paths).
	var out := {"format": 1, "modules": {}}
	for t in manifest.get("modules", {}):
		var info: Dictionary = manifest["modules"][t]
		var files := {}
		for vid in info.get("files", {}):
			var f: Dictionary = info["files"][vid]
			files[vid] = {"path": str(f.get("path", "")), "sha256": str(f.get("sha256", "")), "bytes": int(f.get("bytes", 0))}
		out["modules"][t] = {"version": int(info.get("version", 1)), "active": str(info.get("active", "")), "files": files}
	return out


func _module_body(type: String, vid: String) -> PackedByteArray:
	var info: Dictionary = (manifest.get("modules", {}) as Dictionary).get(type, {})
	var f: Dictionary = (info.get("files", {}) as Dictionary).get(vid, {})
	var file := str(f.get("file", ""))
	if file != "":
		var p := _abs(content_dir) + "/" + file
		if FileAccess.file_exists(p):
			return FileAccess.get_file_as_bytes(p)
	var res := str(f.get("path", ""))
	if res.begins_with("res://") and FileAccess.file_exists(res):
		return FileAccess.get_file_as_bytes(res)
	return PackedByteArray()


func on_request_module(pid: int, type: String, vids: PackedStringArray) -> void:
	if not players.has(pid):
		return
	var info: Dictionary = (_public_manifest()["modules"] as Dictionary).get(type, {})
	if info.is_empty():
		return
	var bodies := {}
	for vid in vids:
		if (info.get("files", {}) as Dictionary).has(vid):
			bodies[vid] = _module_body(type, vid)
	log_line("sending module %s v%d (%s) to %d" % [type, int(info.get("version", 0)), ", ".join(vids), pid])
	_net().s_module.rpc_id(pid, type, info, bodies)


# ------------------------------------------------------------------ accounts + saves
func _load_accounts() -> void:
	var p := _abs(data_dir) + "/accounts.json"
	if FileAccess.file_exists(p):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
		if v is Dictionary:
			accounts = v


func _save_accounts() -> void:
	var f := FileAccess.open(_abs(data_dir) + "/accounts.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(accounts, "\t"))


func _safe_guest(g: String) -> String:
	var out := ""
	for ch in g:
		if ch.is_valid_identifier() or ch in "-0123456789":
			out += ch
	return out.left(48)


func save_path(guest: String) -> String:
	return _abs(data_dir) + "/saves/%s.json" % _safe_guest(guest)


func load_save(guest: String) -> Dictionary:
	var p := save_path(guest)
	if not FileAccess.file_exists(p):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Dictionary else {}


func _write_save(guest: String, synced: Dictionary) -> void:
	var p := save_path(guest)
	var st := Modules.style("save_sync") as SaveSyncStyle
	var keep := st.server_backups if st else 3
	if keep > 0 and FileAccess.file_exists(p):
		for i in range(keep - 1, 0, -1):
			var a := "%s.bak%d" % [p, i]
			var b := "%s.bak%d" % [p, i + 1]
			if FileAccess.file_exists(a):
				DirAccess.rename_absolute(a, b)
		DirAccess.copy_absolute(p, p + ".bak1")
	var f := FileAccess.open(p + ".tmp", FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(synced))
	f.close()
	DirAccess.rename_absolute(p + ".tmp", p)


func _clock_group() -> Dictionary:
	return {"day": TimeManager.day, "minutes": TimeManager.minutes, "weather": TimeManager.weather_id}


func on_save(pid: int, bytes: PackedByteArray) -> void:
	if not players.has(pid):
		return
	var guest := str(players[pid]["guest"])
	var upload := SaveSync.unpack(bytes)
	if upload.is_empty():
		return
	var existing := load_save(guest)
	# The upload is the "local" side; the stored copy is the server side.
	var merged := SaveSync.merge(upload, existing) if not existing.is_empty() else {"data": upload.get("data", {}), "stamps": upload.get("stamps", {})}
	var data: Dictionary = merged["data"]
	var stamps: Dictionary = merged["stamps"]
	# The server owns the clock.
	data["time"] = _clock_group()
	stamps["time"] = Time.get_unix_time_from_system()
	_write_save(guest, {"data": data, "stamps": stamps, "guest": guest, "updated": Time.get_unix_time_from_system()})
	players[pid]["saves"] = int(players[pid].get("saves", 0)) + 1


# ------------------------------------------------------------------ join / leave
func on_hello(pid: int, info: Dictionary) -> void:
	var acc := Modules.style("accounts") as AccountsStyle
	var guest := _safe_guest(str(info.get("guest", "")))
	var token := str(info.get("token", ""))
	if guest == "" or token.length() < 8:
		_net().s_reject.rpc_id(pid, "missing guest id")
		_drop_later(pid)
		return
	if _cfg == null:
		_cfg = ServerConfig.load_config()
	var client_ver := str(info.get("version", info.get("build", "")))
	if client_ver != "" and not _cfg.versions_compatible(client_ver):
		log_line("version mismatch: pid %d client %s, server %s (compat %s) - refused" % [pid, client_ver, _cfg.game_version, _cfg.compat_prefix])
		_net().s_version_mismatch.rpc_id(pid, _cfg.game_version)
		_net().s_reject.rpc_id(pid, "version mismatch")
		_drop_later(pid)
		return
	var cap_total := int(_cfg.max_players_total) if _cfg else (acc.max_players if acc else 32)
	if players.size() >= cap_total:
		_net().s_reject.rpc_id(pid, "server full")
		_drop_later(pid)
		return
	var tsha := token.sha256_text()
	if accounts.has(guest) and str(accounts[guest].get("token_sha", "")) != tsha:
		_net().s_reject.rpc_id(pid, "wrong token for this guest id")
		_drop_later(pid)
		return
	for other in players:
		if str(players[other]["guest"]) == guest:
			# Same guest connected twice: drop the old connection.
			_peer.disconnect_peer(int(other))
	var name := str(info.get("name", "Farmer")).strip_edges().left(acc.name_max if acc else 16)
	if name.length() < (acc.name_min if acc else 2):
		name = "Farmer"
	accounts[guest] = {"token_sha": tsha, "name": name}
	_save_accounts()
	var pos: Vector3 = info.get("pos", Vector3(0, 0, 0)) if info.get("pos") is Vector3 else Vector3.ZERO
	var away_info := {}
	var color: Color = COLORS[players.size() % COLORS.size()]
	if away.has(guest):
		var a: Dictionary = away[guest]
		away_info = {"seconds": Time.get_unix_time_from_system() - float(a["since"]), "visits": a["visits"], "where": a["dest"]}
		color = a["color"]
		_broadcast_roster(str(a.get("room", DEFAULT_ROOM)))
		# drop the stale away pid from that room roster via rebuild
		away.erase(guest)
	players[pid] = {"guest": guest, "name": name, "pos": pos, "yaw": 0.0, "speed": 0.0, "state": "active", "ack": 0,
		"color": color, "joined": Time.get_unix_time_from_system(), "room": DEFAULT_ROOM,
		"last_ping": Time.get_unix_time_from_system()}
	# Room: create / join from hello, else public MAIN (keeps old net_test working).
	var room_code := DEFAULT_ROOM
	if bool(info.get("create_room", false)):
		room_code = _new_room_code()
		_ensure_room(room_code, pid, name + "'s room", false)
	elif str(info.get("room", "")) != "":
		room_code = str(info.get("room", "")).strip_edges().to_upper()
		if not rooms.has(room_code):
			_net().s_reject.rpc_id(pid, "unknown room")
			players.erase(pid)
			_drop_later(pid)
			return
	var put := _put_in_room(pid, room_code)
	if put != OK:
		_net().s_reject.rpc_id(pid, "room full" if put == ERR_BUSY else "bad room")
		players.erase(pid)
		_drop_later(pid)
		return
	var save := load_save(guest)
	var welcome := {"pid": pid, "roster": _roster_for_room(room_code), "clock": _clock_group().merged({"speed_index": TimeManager.speed_index}),
		"manifest": _public_manifest(), "save": SaveSync.pack(save) if not save.is_empty() else PackedByteArray(),
		"npc_roles": npc_roles, "away": away_info, "room": _room_info(room_code), "version": _cfg.game_version}
	log_line("hello %s (%s) pid %d room %s%s" % [name, guest, pid, room_code, (" - back after %ds" % int(away_info["seconds"])) if not away_info.is_empty() else ""])
	_net().s_welcome.rpc_id(pid, welcome)
	_net().s_room.rpc_id(pid, _room_info(room_code))
	_broadcast_roster(room_code)
	_refresh_health()


func _on_peer_left(pid: int) -> void:
	_chat_times.erase(pid)
	if not players.has(pid):
		return
	var p: Dictionary = players[pid]
	var room_code := str(p.get("room", DEFAULT_ROOM))
	_leave_room(pid)
	players.erase(pid)
	for npc in npc_roles.keys():
		if int(npc_roles[npc]) == pid:
			npc_roles.erase(npc)
	log_line("peer %d (%s) left room %s - avatar stays as away" % [pid, p["name"], room_code])
	_start_away(pid, p)
	_broadcast_roster(room_code)
	_rpc_room(room_code, "s_room", [_room_info(room_code)])
	_net().s_npc_roles.rpc(npc_roles)
	_refresh_health()


func _start_away(pid: int, p: Dictionary) -> void:
	var st := Modules.style("away_avatar") as AwayAvatarStyle
	var h := TimeManager.hours_float()
	var to_cafe := st != null and h >= st.cafe_from and h < st.cafe_to
	var spot := (st.cafe_spot if st else "door:cafe") if to_cafe else (st.home_spot if st else "door:farmhouse")
	var pos: Vector3 = p["pos"]
	var route := TownNav.route(pos, spot)
	var target := TownNav.spot_position(spot)
	if target != Vector3.INF:
		target += st.sit_offset if st else Vector3.ZERO
		target.y = Terrain.height_at(target.x, target.z)
		route.append(target)
	away[str(p["guest"])] = {"pid": pid, "name": p["name"], "pos": pos, "yaw": float(p["yaw"]), "state": "away_walk",
		"route": route, "route_i": 0, "since": Time.get_unix_time_from_system(), "visits": [],
		"next_visit": (st.visit_every if st else 12.0), "dest": "cafe" if to_cafe else "home", "color": p["color"],
		"ack": int(p["ack"]), "guest": p["guest"], "room": str(p.get("room", DEFAULT_ROOM))}


func roster() -> Dictionary:
	var r := {}
	for pid in players:
		var p: Dictionary = players[pid]
		r[pid] = {"name": p["name"], "color": p["color"], "state": "active"}
	for g in away:
		var a: Dictionary = away[g]
		r[int(a["pid"])] = {"name": a["name"], "color": a["color"], "state": a["state"], "dest": a["dest"]}
	return r


func _roster_without(pid: int) -> Dictionary:
	var r := roster()
	r.erase(pid)
	return r


# ------------------------------------------------------------------ input / chat / roles
func on_input(pid: int, seq: int, pos: Vector3, yaw: float, speed: float, dt: float) -> void:
	if not players.has(pid):
		return
	var p: Dictionary = players[pid]
	p["last_ping"] = Time.get_unix_time_from_system()  # any input counts as a heartbeat
	if seq <= int(p["ack"]):
		return
	var st := Modules.style("netcode") as NetcodeStyle
	var ok_pos := NetMove.validate(p["pos"], pos, dt, st) if int(p["ack"]) > 0 else pos
	if ok_pos.distance_to(pos) > 0.01:
		rejected_moves += 1
	p["pos"] = ok_pos
	p["yaw"] = yaw
	p["speed"] = minf(speed, st.max_speed * st.speed_tolerance if st else 8.0)
	p["ack"] = seq


var teleports: int = 0
func on_teleport(pid: int, seq: int, pos: Vector3) -> void:
	if not players.has(pid):
		return
	var p: Dictionary = players[pid]
	var now := Time.get_unix_time_from_system()
	if now - float(p.get("last_tp", 0.0)) < 2.0:
		rejected_moves += 1
		p["ack"] = seq
		return
	p["last_tp"] = now
	p["pos"] = pos
	p["ack"] = seq
	teleports += 1
	log_line("teleport %s -> (%.1f, %.1f, %.1f)" % [p["name"], pos.x, pos.y, pos.z])


func on_chat(pid: int, text: String) -> void:
	if not players.has(pid):
		return
	var st := Modules.style("chat") as ChatStyle
	var now := Time.get_unix_time_from_system()
	var times: Array = _chat_times.get(pid, [])
	while not times.is_empty() and now - float(times[0]) > (st.rate_window if st else 10.0):
		times.pop_front()
	if times.size() >= (st.rate_count if st else 5):
		_net().s_chat.rpc_id(pid, 0, "server", Lang.pick({"fa": "آهسته‌تر! چند ثانیه صبر کن.", "en": "Slow down - wait a few seconds."}))
		return
	times.append(now)
	_chat_times[pid] = times
	text = text.strip_edges().left(st.max_length if st else 200)
	if text == "":
		return
	if st:
		for w in st.blocked_words:
			var i := text.to_lower().find(w)
			while i >= 0:
				text = text.substr(0, i) + "***" + text.substr(i + w.length())
				i = text.to_lower().find(w)
	log_line("chat %s: %s" % [players[pid]["name"], text])
	_rpc_room(str(players[pid].get("room", DEFAULT_ROOM)), "s_chat", [pid, str(players[pid]["name"]), text])


func on_claim_npc(pid: int, npc_id: String, claim: bool) -> void:
	var st := Modules.style("npc_roles") as NpcRoleStyle
	if not players.has(pid) or st == null or not st.enabled:
		return
	if claim:
		if npc_roles.has(npc_id) and int(npc_roles[npc_id]) != pid:
			return
		var mine := 0
		for n in npc_roles:
			if int(npc_roles[n]) == pid:
				mine += 1
		if mine >= st.max_per_player:
			return
		npc_roles[npc_id] = pid
	elif npc_roles.has(npc_id) and int(npc_roles[npc_id]) == pid:
		npc_roles.erase(npc_id)
	log_line("npc roles: %s" % str(npc_roles))
	_net().s_npc_roles.rpc(npc_roles)


# ------------------------------------------------------------------ tick
func _process(delta: float) -> void:
	if _peer == null:
		return
	var st := Modules.style("netcode") as NetcodeStyle
	_tick_away(delta)
	_snap_acc += delta
	if _snap_acc >= 1.0 / maxf(st.tick_hz if st else 15.0, 1.0):
		_snap_acc = 0.0
		_broadcast_snapshot()
	_clock_acc += delta
	if _clock_acc >= (st.clock_every if st else 5.0):
		_clock_acc = 0.0
		if not players.is_empty():
			_net().s_clock.rpc(TimeManager.day, TimeManager.minutes, TimeManager.weather_id, TimeManager.speed_index)
	_watch_acc += delta
	if _watch_acc >= 1.0:
		_watch_acc = 0.0
		_reload_manifest(true)
		_check_heartbeats()
		_refresh_health()


func _broadcast_snapshot() -> void:
	if players.is_empty():
		return
	# Build per-room state maps (away avatars only visible in their last room).
	var by_room: Dictionary = {}
	for pid in players:
		var p: Dictionary = players[pid]
		var rc := str(p.get("room", DEFAULT_ROOM))
		if not by_room.has(rc):
			by_room[rc] = {}
		var pos: Vector3 = p["pos"]
		by_room[rc][pid] = [pos.x, pos.y, pos.z, p["yaw"], p["speed"], 0, p["ack"]]
	for g in away:
		var a: Dictionary = away[g]
		var rc2 := str(a.get("room", DEFAULT_ROOM))
		if not by_room.has(rc2):
			by_room[rc2] = {}
		var pos2: Vector3 = a["pos"]
		by_room[rc2][int(a["pid"])] = [pos2.x, pos2.y, pos2.z, a["yaw"], float(a.get("speed", 0.0)), Net.STATE_CODES.get(a["state"], 1), a["ack"]]
	var t := Time.get_ticks_msec() / 1000.0
	for rc3 in by_room:
		_rpc_room(rc3, "s_snapshot", [t, by_room[rc3]])


func _tick_away(delta: float) -> void:
	var st := Modules.style("away_avatar") as AwayAvatarStyle
	var now := Time.get_unix_time_from_system()
	var changed := false
	for g in away.keys():
		var a: Dictionary = away[g]
		if st and now - float(a["since"]) > st.keep_seconds:
			away.erase(g)
			changed = true
			continue
		if a["state"] == "away_walk":
			var route: PackedVector3Array = a["route"]
			var i := int(a["route_i"])
			if i >= route.size():
				a["state"] = "away_sit" if a["dest"] == "cafe" else "away_home"
				a["speed"] = 0.0
				changed = true
				log_line("%s's avatar arrived at the %s" % [a["name"], a["dest"]])
			else:
				var pos: Vector3 = a["pos"]
				var tgt := route[i]
				var d := Vector3(tgt.x - pos.x, 0, tgt.z - pos.z)
				var step := (st.walk_speed if st else 2.2) * delta
				if d.length() <= step:
					pos = Vector3(tgt.x, tgt.y, tgt.z)
					a["route_i"] = i + 1
				else:
					pos += d.normalized() * step
					pos.y = Terrain.height_at(pos.x, pos.z)
					a["yaw"] = atan2(d.x, d.z)
				a["pos"] = pos
				a["speed"] = st.walk_speed if st else 2.2
		# Townspeople visit the avatar (greet / bring tea).
		a["next_visit"] = float(a["next_visit"]) - delta
		if float(a["next_visit"]) <= 0.0:
			a["next_visit"] = st.visit_every if st else 12.0
			_visit(a, st)
	if changed:
		for code in rooms.keys():
			_broadcast_roster(code)


func _visit(a: Dictionary, st: AwayAvatarStyle) -> void:
	var people := Population.residents()
	if people.is_empty():
		return
	# Prefer townspeople whose work is the cafe when the avatar sits there.
	var pool: Array = []
	for r in people:
		if int(r.get("age", 30)) >= 12:
			pool.append(r)
	if pool.is_empty():
		return
	var r: Dictionary = pool[_rng.randi() % pool.size()]
	var visits: Array = a["visits"]
	var kind := "tea" if st and st.tea_every > 0 and (visits.size() + 1) % st.tea_every == 0 else "greet"
	var npc := str(r.get("name", "?"))
	visits.append({"npc": npc, "kind": kind, "t": Time.get_unix_time_from_system()})
	var lines: Dictionary = (st.tea_lines if kind == "tea" else st.greet_lines) if st else {}
	var fa := str((lines.get("fa", []) as Array).pick_random()) if lines.has("fa") else ""
	var en := str((lines.get("en", []) as Array).pick_random()) if lines.has("en") else ""
	log_line("%s visits %s's avatar (%s)" % [npc, a["name"], kind])
	_net().s_avatar_event.rpc(int(a["pid"]), kind, npc, fa, en)


# ------------------------------------------------------------------ v7b.1 rooms / heartbeat / health
func _server_cfg() -> ServerConfig:
	if _cfg == null:
		_cfg = ServerConfig.load_config()
	return _cfg


func _new_room_code() -> String:
	for _i in range(64):
		var code := ""
		for _j in range(6):
			code += CODE_ALPHABET[_rng.randi() % CODE_ALPHABET.length()]
		if not rooms.has(code) and code != DEFAULT_ROOM:
			return code
	return "R" + str(_rng.randi() % 100000).pad_zeros(5)


func _ensure_room(code: String, host_pid: int, room_name: String, is_public: bool) -> void:
	if rooms.has(code):
		return
	rooms[code] = {"code": code, "host": host_pid, "members": [], "created": Time.get_unix_time_from_system(),
		"name": room_name, "public": is_public}


func _room_max() -> int:
	return int(_server_cfg().max_per_room)


func _put_in_room(pid: int, code: String) -> int:
	if not rooms.has(code):
		return ERR_DOES_NOT_EXIST
	var r: Dictionary = rooms[code]
	var members: Array = r["members"]
	if members.size() >= _room_max() and pid not in members:
		return ERR_BUSY
	if pid not in members:
		members.append(pid)
	if players.has(pid):
		# Leave previous room first.
		var prev := str(players[pid].get("room", ""))
		if prev != "" and prev != code and rooms.has(prev):
			var pm: Array = rooms[prev]["members"]
			pm.erase(pid)
			if prev != DEFAULT_ROOM and pm.is_empty():
				rooms.erase(prev)
		players[pid]["room"] = code
	return OK


func _leave_room(pid: int) -> void:
	if not players.has(pid):
		return
	var code := str(players[pid].get("room", ""))
	if code == "" or not rooms.has(code):
		return
	var members: Array = rooms[code]["members"]
	members.erase(pid)
	if code != DEFAULT_ROOM and members.is_empty():
		rooms.erase(code)


func _room_info(code: String) -> Dictionary:
	if not rooms.has(code):
		return {}
	var r: Dictionary = rooms[code]
	return {"code": code, "players": (r["members"] as Array).size(), "max": _room_max(),
		"host": int(r.get("host", 0)), "name": str(r.get("name", code)), "public": bool(r.get("public", false))}


func _roster_for_room(code: String) -> Dictionary:
	var r := {}
	for pid in players:
		if str(players[pid].get("room", DEFAULT_ROOM)) != code:
			continue
		var p: Dictionary = players[pid]
		r[pid] = {"name": p["name"], "color": p["color"], "state": "active"}
	for g in away:
		var a: Dictionary = away[g]
		if str(a.get("room", DEFAULT_ROOM)) != code:
			continue
		r[int(a["pid"])] = {"name": a["name"], "color": a["color"], "state": a["state"], "dest": a["dest"]}
	return r


func _broadcast_roster(code: String) -> void:
	_rpc_room(code, "s_roster", [_roster_for_room(code)])


func _rpc_room(code: String, method: String, args: Array) -> void:
	if not rooms.has(code):
		return
	for pid in rooms[code]["members"]:
		if not players.has(int(pid)):
			continue
		# Net RPC methods take the arg list positionally.
		match method:
			"s_roster":
				_net().s_roster.rpc_id(int(pid), args[0])
			"s_snapshot":
				_net().s_snapshot.rpc_id(int(pid), args[0], args[1])
			"s_chat":
				_net().s_chat.rpc_id(int(pid), args[0], args[1], args[2])
			"s_room":
				_net().s_room.rpc_id(int(pid), args[0])
			_:
				pass


func _refresh_health() -> void:
	if _health:
		_health.set_stats(players.size(), rooms.size(), str(_server_cfg().game_version))


func _check_heartbeats() -> void:
	var timeout := float(_server_cfg().heartbeat_timeout_sec)
	var now := Time.get_unix_time_from_system()
	var drop: Array = []
	for pid in players:
		var last := float(players[pid].get("last_ping", players[pid].get("joined", now)))
		if now - last > timeout:
			drop.append(int(pid))
	for pid2 in drop:
		log_line("heartbeat timeout pid %d — disconnecting" % pid2)
		_peer.disconnect_peer(pid2)


func on_create_room(pid: int) -> void:
	if not players.has(pid):
		return
	var code := _new_room_code()
	var name := str(players[pid]["name"]) + "'s room"
	_ensure_room(code, pid, name, true)
	var err := _put_in_room(pid, code)
	if err != OK:
		_net().s_reject.rpc_id(pid, "cannot create room")
		return
	log_line("room %s created by %s" % [code, players[pid]["name"]])
	_net().s_room.rpc_id(pid, _room_info(code))
	_broadcast_roster(code)
	_refresh_health()


func on_join_room(pid: int, code: String) -> void:
	if not players.has(pid):
		return
	code = code.strip_edges().to_upper()
	if not rooms.has(code):
		_net().s_reject.rpc_id(pid, "unknown room")
		return
	var prev := str(players[pid].get("room", DEFAULT_ROOM))
	var err := _put_in_room(pid, code)
	if err != OK:
		_net().s_reject.rpc_id(pid, "room full")
		return
	log_line("%s joined room %s" % [players[pid]["name"], code])
	# Everyone in the room gets the new player count (not only the joiner).
	_rpc_room(code, "s_room", [_room_info(code)])
	if prev != code:
		_rpc_room(prev, "s_room", [_room_info(prev)])
		_broadcast_roster(prev)
	_broadcast_roster(code)
	_refresh_health()


func on_list_rooms(pid: int) -> void:
	var out: Array = []
	for code in rooms:
		var info := _room_info(code)
		if bool(rooms[code].get("public", false)) or code == DEFAULT_ROOM:
			out.append(info)
	_net().s_room_list.rpc_id(pid, out)


func on_ping(pid: int, client_ms: int) -> void:
	if players.has(pid):
		players[pid]["last_ping"] = Time.get_unix_time_from_system()
	_net().s_pong.rpc_id(pid, client_ms)


## Refuse a peer but let the reject RPC reach it first (an immediate disconnect drops it).
func _drop_later(pid: int) -> void:
	get_tree().create_timer(0.5).timeout.connect(func() -> void:
		if _peer and pid in multiplayer.get_peers():
			_peer.disconnect_peer(pid))
