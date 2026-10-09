extends Node
## v5d multiplayer endpoint (autoload "Net"). The SAME node runs on the
## headless server (`-- --server`, see NetServer) and on every client, so the
## RPCs below live at /root/Net on both sides.
##
## Single player is the default: a client never opens a socket unless the
## player opts in (Online panel, U) or the game is started with
## `-- --server-url=ws://...` (desktop / tests). The web build stays fully
## offline otherwise.
##
## Client states: "offline" (single player), "connecting", "online",
## "unreachable" (opted in but the server can't be reached: the game keeps
## running locally, saves are stamped and synced when the server returns).
##
## Modules: netcode, chat, live_updates, save_sync, away_avatar, accounts, npc_roles.

signal state_changed(state: String)
signal roster_changed
signal chat_received(pid: int, sender: String, text: String)
signal module_updated(type: String, version: int, ok: bool, error: String)
signal welcome_back(info: Dictionary)
signal avatar_event(pid: int, kind: String, npc: String, line: String)
signal npc_roles_changed(roles: Dictionary)
signal save_synced(from: Dictionary)
signal room_changed(info: Dictionary)
signal room_list_received(rooms: Array)
signal ping_received(rtt_ms: float)
signal version_mismatch(server_ver: String, client_ver: String)
signal room_error(reason: String)  ## v7b.1: "room full" / "unknown room" while already online (stay connected)

const SYNC_PATH := "user://sync_state.json"
const SYNC_WEB_KEY := "farm_prototype_sync"
const STATE_CODES := {"active": 0, "away_walk": 1, "away_sit": 2, "away_home": 3}

var is_server: bool = false
var server: Node = null  ## NetServer on the server
var state: String = "offline"
var url: String = ""
var my_pid: int = 0
## pid -> {"name", "color", "state", "guest"}
var roster: Dictionary = {}
## pid -> Array of [t, Vector3 pos, yaw, speed, state_code] (interpolation buffer)
var snapshots: Dictionary = {}
var npc_roles: Dictionary = {}  ## npc id -> pid
var chat_log: Array = []  ## [{pid, name, text, t}]
var server_manifest: Dictionary = {}
var last_welcome: Dictionary = {}
var corrections: int = 0  ## reconciliation corrections applied (tests)
var last_correction: Vector3 = Vector3.ZERO
var stats: Dictionary = {"snapshots": 0, "chat": 0, "modules_ok": 0, "modules_failed": 0, "uploads": 0, "save_applied": 0, "avatar_events": 0, "pings": 0}
## v7b.1 lobby / heartbeat
var room: Dictionary = {}  ## {code, players, max, host}
var room_list: Array = []
var last_rtt_ms: float = -1.0
var _ping_acc: float = 0.0
var _ping_sent_at: float = 0.0
var pending_room_action: String = ""  ## "" | "create" | "join:CODE"
var last_room_error: String = ""
var _cfg_cache: ServerConfig = null

var _peer: WebSocketMultiplayerPeer
var _seq: int = 0
var _history: Array = []  ## [[seq, Vector3]]
var _send_acc: float = 0.0
var _save_acc: float = 0.0
var _retry_in: float = -1.0
var _backoff: float = 2.0
var _last_pos: Vector3 = Vector3.INF
var _correction_left: Vector3 = Vector3.ZERO
var _force_teleport: bool = false
var _pending_modules: Dictionary = {}  ## type -> remote info
## Synced save record: {"data": snapshot, "stamps": {group: unix}, "hashes": {group: sha}}
var synced: Dictionary = {"data": {}, "stamps": {}, "hashes": {}}
## True until this device has merged with the server once. While true, changes are
## stamped 0 so a brand-new game (new phone, cleared browser) never beats the server save.
var never_synced: bool = true
var _clock_base: float = 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg == "--server":
			is_server = true
	if is_server:
		return  # server_main.gd starts NetServer
	_load_sync_state()
	# Downloaded module updates from earlier sessions (works offline too).
	ModuleManifest.apply_persisted.call_deferred()
	var cli_url := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--server-url="):
			cli_url = arg.trim_prefix("--server-url=")
	if cli_url != "":
		connect_to.call_deferred(cli_url)
	elif bool(Settings.get_value("online_enabled")) and str(Settings.get_value("server_url")) != "":
		connect_to.call_deferred(str(Settings.get_value("server_url")))


# ------------------------------------------------------------------ styles
func netcode() -> NetcodeStyle:
	return Modules.style("netcode") as NetcodeStyle


func chat_style() -> ChatStyle:
	return Modules.style("chat") as ChatStyle


func sync_style() -> SaveSyncStyle:
	return Modules.style("save_sync") as SaveSyncStyle


func now() -> float:
	return Time.get_unix_time_from_system()


func is_online() -> bool:
	return state == "online"


## True when the player opted in (online mode) - offline single player is false.
func opted_in() -> bool:
	return state != "offline"


# ------------------------------------------------------------------ identity
func guest_id() -> String:
	var g := str(Settings.get_value("guest_id"))
	if g == "":
		var st := Modules.style("accounts") as AccountsStyle
		var crypto := Crypto.new()
		g = (st.guest_prefix if st else "guest-") + crypto.generate_random_bytes(6).hex_encode()
		Settings.set_value("guest_id", g)
		Settings.set_value("guest_token", crypto.generate_random_bytes(16).hex_encode())
	return g


func guest_token() -> String:
	guest_id()
	return str(Settings.get_value("guest_token"))


func player_name() -> String:
	var n := str(Settings.get_value("player_name")).strip_edges()
	if n == "":
		var st := Modules.style("accounts") as AccountsStyle
		n = (st.default_names[0] if st and st.default_names.size() > 0 else "Farmer") + " " + guest_id().right(3)
	return n


# ------------------------------------------------------------------ connection (client)
## Opt in and connect. Returns false if the URL is unusable.
func connect_to(server_url: String) -> bool:
	server_url = server_url.strip_edges()
	if "YOUR_SERVER_HOST" in server_url or server_url.ends_with("://") or server_url.ends_with("://:"):
		push_warning("Net: placeholder server URL refused (%s)" % server_url)
		return false
	if not (server_url.begins_with("ws://") or server_url.begins_with("wss://")):
		push_warning("Net: server URL must start with ws:// or wss:// (%s)" % server_url)
		return false
	url = server_url
	_open()
	return true


## Back to single player: close the socket and stop retrying.
func go_offline() -> void:
	_retry_in = -1.0
	_close_peer()
	roster.clear()
	snapshots.clear()
	my_pid = 0
	_set_state("offline")
	roster_changed.emit()


func _open() -> void:
	_close_peer()
	var st := netcode()
	_peer = WebSocketMultiplayerPeer.new()
	_peer.inbound_buffer_size = st.buffer_bytes if st else 8388608
	_peer.outbound_buffer_size = st.buffer_bytes if st else 8388608
	_peer.max_queued_packets = 8192
	var err := _peer.create_client(url)
	if err != OK:
		_on_failed()
		return
	multiplayer.multiplayer_peer = _peer
	if not multiplayer.connected_to_server.is_connected(_on_connected):
		multiplayer.connected_to_server.connect(_on_connected)
		multiplayer.connection_failed.connect(_on_failed)
		multiplayer.server_disconnected.connect(_on_lost)
	_set_state("connecting")


func _close_peer() -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null


func _set_state(s: String) -> void:
	if s == state:
		return
	state = s
	print("Net: %s%s" % [s, (" " + url) if url != "" and s != "offline" else ""])
	state_changed.emit(s)


func _on_connected() -> void:
	my_pid = multiplayer.get_unique_id()
	var cfg := _server_cfg()
	var hello := {"guest": guest_id(), "token": guest_token(), "name": player_name(),
		"build": GameBrand.build_id(), "version": GameBrand.version(),
		"manifest": _versions(ModuleManifest.effective())}
	if pending_room_action == "create":
		hello["create_room"] = true
	elif pending_room_action.begins_with("join:"):
		hello["room"] = pending_room_action.trim_prefix("join:")
	var p := _local_player()
	if p:
		hello["pos"] = p.global_position
	c_hello.rpc_id(1, hello)


func _on_failed() -> void:
	_close_peer()
	_set_state("unreachable")
	_schedule_retry()


func _on_lost() -> void:
	_close_peer()
	roster.clear()
	snapshots.clear()
	roster_changed.emit()
	_set_state("unreachable")
	_schedule_retry()


func _schedule_retry() -> void:
	var st := netcode()
	_retry_in = _backoff
	_backoff = minf(_backoff * 2.0, st.reconnect_max if st else 20.0)


func _versions(man: Dictionary) -> Dictionary:
	var out := {}
	for t in man.get("modules", {}):
		out[t] = int(man["modules"][t].get("version", 0))
	return out


func _local_player() -> Node3D:
	if not is_inside_tree():
		return null
	return get_tree().get_first_node_in_group(&"player") as Node3D


# ------------------------------------------------------------------ per frame (client)
func _process(delta: float) -> void:
	if is_server:
		return
	# v7b.1 PERF: early return when offline (default web play) - no timer
	# accumulators, no empty work every frame. Online / connecting still tick.
	if state == "offline":
		return
	if state == "unreachable" or state == "connecting":
		if _retry_in >= 0.0:
			_retry_in -= delta
			if _retry_in < 0.0:
				_open()
	# Local autosave stamps keep running offline so sync knows what changed when.
	var sst := sync_style()
	_save_acc += delta
	if sst and _save_acc >= sst.upload_seconds and state != "offline":
		_save_acc = 0.0
		autosave_tick()
	if state != "online":
		return
	var st := netcode()
	_send_acc += delta
	var step := 1.0 / maxf(st.tick_hz if st else 15.0, 1.0)
	if _send_acc >= step:
		var dt := _send_acc
		_send_acc = 0.0
		_send_input(dt)
	# Heartbeat (keepalive for free-tier hosts).
	var hb := float(_server_cfg().heartbeat_sec)
	_ping_acc += delta
	if _ping_acc >= maxf(hb, 5.0):
		_ping_acc = 0.0
		send_ping()
	# Smoothly apply small reconciliation corrections.
	if _correction_left.length() > 0.001:
		var p := _local_player()
		if p:
			var part := _correction_left * minf(1.0, delta * 10.0)
			p.global_position += part
			_correction_left -= part


func _send_input(dt: float) -> void:
	var p := _local_player()
	if p == null:
		return
	_seq += 1
	var pos := p.global_position
	var vis := p.get_node_or_null(^"Visual") as Node3D
	var yaw := vis.rotation.y if vis else 0.0
	var speed := Vector2(p.get("velocity").x, p.get("velocity").z).length() if p is CharacterBody3D else 0.0
	_history.append([_seq, pos])
	if _history.size() > 90:
		_history.pop_front()
	# Teleports (loading a save, sleeping, doors) are announced separately: the
	# server accepts them rate-limited and logs them; normal steps are speed-checked.
	if _force_teleport or (_last_pos != Vector3.INF and _last_pos.distance_to(pos) > 6.0):
		_force_teleport = false
		c_teleport.rpc_id(1, _seq, pos)
	else:
		c_input.rpc_id(1, _seq, pos, yaw, speed, dt)
	_last_pos = pos


## The next position update is a deliberate placement (scripted move, door, bed),
## announced as a teleport (the server accepts one per 2 s) instead of a walk step.
func mark_teleport() -> void:
	_force_teleport = true


## Autosave: snapshot -> stamp changed groups -> keep locally -> upload if online.
func autosave_tick() -> void:
	if not is_inside_tree() or get_tree().get_first_node_in_group(&"player") == null:
		return
	var snap := SaveGame.snapshot()
	SaveSync.restamp(snap, synced["stamps"], synced["hashes"], 0.0 if never_synced else now())
	synced["data"] = snap
	_save_sync_state()
	if state == "online":
		c_save.rpc_id(1, SaveSync.pack({"data": snap, "stamps": synced["stamps"]}))
		stats["uploads"] += 1
	else:
		# Offline: the normal local save keeps the game safe until the server is back.
		SaveGame.save_game()


func _load_sync_state() -> void:
	var text := ""
	if OS.has_feature("web"):
		text = WebStorage.get_item(SYNC_WEB_KEY)
	elif FileAccess.file_exists(SYNC_PATH):
		text = FileAccess.get_file_as_string(SYNC_PATH)
	var v: Variant = JSON.parse_string(text) if text != "" else null
	if v is Dictionary:
		synced["stamps"] = (v as Dictionary).get("stamps", {})
		synced["hashes"] = (v as Dictionary).get("hashes", {})
		never_synced = bool((v as Dictionary).get("never_synced", false))


func _save_sync_state() -> void:
	var text := JSON.stringify({"stamps": synced["stamps"], "hashes": synced["hashes"], "never_synced": never_synced})
	if OS.has_feature("web"):
		WebStorage.set_item(SYNC_WEB_KEY, text)
		return
	var f := FileAccess.open(SYNC_PATH, FileAccess.WRITE)
	if f:
		f.store_string(text)


## Chat (client).
func send_chat(text: String) -> bool:
	text = text.strip_edges()
	if text == "" or state != "online":
		return false
	var st := chat_style()
	if st and text.length() > st.max_length:
		text = text.left(st.max_length)
	c_chat.rpc_id(1, text)
	return true


## NPC takeover groundwork (client): ask the server to control a townsperson.
func claim_npc(npc_id: String, claim: bool = true) -> void:
	if state == "online":
		c_claim_npc.rpc_id(1, npc_id, claim)


func _apply_clock(day: int, minutes: float, weather: String, speed_index: int) -> void:
	if TimeManager.day != day:
		TimeManager.reset_calendar(day, minutes / 60.0, weather)
	elif absf(TimeManager.minutes - minutes) > 3.0:
		TimeManager.set_time_of_day(minutes / 60.0)
	if TimeManager.weather_id != weather:
		TimeManager.set_weather(weather)
	if speed_index >= 0 and speed_index < TimeManager.speed_presets.size():
		TimeManager.speed_index = speed_index
	TimeManager.paused = false


func _start_module_sync(remote: Dictionary) -> void:
	server_manifest = remote
	var local := ModuleManifest.effective()
	for t in ModuleManifest.diff(local, remote):
		if not ModuleManifest.allowed(t):
			continue
		var files := ModuleManifest.changed_files(t, local, remote)
		_pending_modules[t] = remote["modules"][t]
		c_request_module.rpc_id(1, t, files)



# ------------------------------------------------------------------ v7b.1 config / rooms / heartbeat
func _server_cfg() -> ServerConfig:
	if _cfg_cache == null:
		_cfg_cache = ServerConfig.load_config()
	return _cfg_cache


func create_room() -> void:
	pending_room_action = "create"
	if state == "online":
		c_create_room.rpc_id(1)
	else:
		var u := _server_cfg().resolve_client_url()
		if u != "":
			Settings.set_value("online_enabled", true)
			connect_to(u)


func join_room(code: String) -> void:
	code = code.strip_edges().to_upper()
	pending_room_action = "join:" + code
	if state == "online":
		c_join_room.rpc_id(1, code)
	else:
		var u := _server_cfg().resolve_client_url()
		if u != "":
			Settings.set_value("online_enabled", true)
			connect_to(u)


func request_room_list() -> void:
	if state == "online":
		c_list_rooms.rpc_id(1)


func send_ping() -> void:
	if state != "online":
		return
	_ping_sent_at = Time.get_ticks_msec() / 1000.0
	c_ping.rpc_id(1, Time.get_ticks_msec())


# ================================================================== RPCs
# ---- client -> server
@rpc("any_peer", "call_remote", "reliable")
func c_hello(info: Dictionary) -> void:
	if server:
		server.call("on_hello", multiplayer.get_remote_sender_id(), info)


@rpc("any_peer", "call_remote", "unreliable_ordered")
func c_input(seq: int, pos: Vector3, yaw: float, speed: float, dt: float) -> void:
	if server:
		server.call("on_input", multiplayer.get_remote_sender_id(), seq, pos, yaw, speed, dt)


@rpc("any_peer", "call_remote", "reliable")
func c_teleport(seq: int, pos: Vector3) -> void:
	if server:
		server.call("on_teleport", multiplayer.get_remote_sender_id(), seq, pos)


@rpc("any_peer", "call_remote", "reliable")
func c_chat(text: String) -> void:
	if server:
		server.call("on_chat", multiplayer.get_remote_sender_id(), text)


@rpc("any_peer", "call_remote", "reliable")
func c_save(bytes: PackedByteArray) -> void:
	if server:
		server.call("on_save", multiplayer.get_remote_sender_id(), bytes)


@rpc("any_peer", "call_remote", "reliable")
func c_request_module(type: String, vids: PackedStringArray) -> void:
	if server:
		server.call("on_request_module", multiplayer.get_remote_sender_id(), type, vids)


@rpc("any_peer", "call_remote", "reliable")
func c_claim_npc(npc_id: String, claim: bool) -> void:
	if server:
		server.call("on_claim_npc", multiplayer.get_remote_sender_id(), npc_id, claim)


@rpc("any_peer", "call_remote", "reliable")
func c_create_room() -> void:
	if server:
		server.call("on_create_room", multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c_join_room(code: String) -> void:
	if server:
		server.call("on_join_room", multiplayer.get_remote_sender_id(), code)


@rpc("any_peer", "call_remote", "reliable")
func c_list_rooms() -> void:
	if server:
		server.call("on_list_rooms", multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func c_ping(client_ms: int) -> void:
	if server:
		server.call("on_ping", multiplayer.get_remote_sender_id(), client_ms)


# ---- server -> client
@rpc("authority", "call_remote", "reliable")
func s_reject(reason: String) -> void:
	# v7b.1: a refused room join while already in a room keeps the connection.
	if state == "online" and my_pid > 0 and (reason == "room full" or reason == "unknown room"):
		last_room_error = reason
		pending_room_action = ""
		GameEvents.notification_requested.emit(Lang.pick({"fa": "ورود به اتاق ممکن نشد: ", "en": "Could not join the room: "}) + Lang.pick({"fa": "اتاق پر است" if reason == "room full" else "کد اتاق پیدا نشد", "en": reason}))
		room_error.emit(reason)
		return
	push_warning("Net: server refused: " + reason)
	GameEvents.notification_requested.emit(Lang.pick({"fa": "سرور اتصال را نپذیرفت: ", "en": "Server refused: "}) + reason)
	go_offline()


@rpc("authority", "call_remote", "reliable")
func s_welcome(info: Dictionary) -> void:
	last_welcome = info
	my_pid = int(info.get("pid", my_pid))
	_backoff = netcode().reconnect_min if netcode() else 2.0
	_retry_in = -1.0
	roster = info.get("roster", {})
	npc_roles = info.get("npc_roles", {})
	if info.has("room"):
		room = info.get("room", {})
		room_changed.emit(room)
	var c: Dictionary = info.get("clock", {})
	if not c.is_empty():
		_apply_clock(int(c.get("day", 1)), float(c.get("minutes", 480.0)), str(c.get("weather", "sunny")), int(c.get("speed_index", -1)))
	_set_state("online")
	_last_pos = Vector3.INF
	_history.clear()
	roster_changed.emit()
	npc_roles_changed.emit(npc_roles)
	# Save: merge our local copy with the server's (latest per group, server wins for world state).
	var server_save := SaveSync.unpack(info.get("save", PackedByteArray()))
	_merge_and_apply(server_save)
	# Modules: download only what changed.
	_start_module_sync(info.get("manifest", {}))
	var away: Dictionary = info.get("away", {})
	if not away.is_empty():
		_on_welcome_back(away)


func _merge_and_apply(server_save: Dictionary) -> void:
	var have_local := not (synced["data"] as Dictionary).is_empty()
	if not have_local and get_tree().get_first_node_in_group(&"player") != null:
		# Fresh start (e.g. phone died, new device): nothing local yet.
		synced["data"] = {}
	var local := {"data": synced["data"], "stamps": synced["stamps"]}
	if server_save.is_empty():
		# Server has nothing for us yet: our copy becomes the reference.
		never_synced = false
		synced["hashes"] = {}
		autosave_tick()
		return
	var merged := SaveSync.merge(local, server_save)
	var from: Dictionary = merged["from"]
	var any_server := false
	for g in from:
		if from[g] == "server":
			any_server = true
	if any_server and get_tree().get_first_node_in_group(&"player") != null:
		var data: Dictionary = merged["data"]
		data["version"] = SaveGame.VERSION
		SaveGame.apply(data)
		stats["save_applied"] += 1
	synced["data"] = merged["data"]
	synced["stamps"] = merged["stamps"]
	synced["hashes"] = {}
	SaveSync.restamp(synced["data"], {}, synced["hashes"], 0.0)
	never_synced = false
	_save_sync_state()
	save_synced.emit(from)
	# Push the merged copy back so the server has our offline progress.
	c_save.rpc_id(1, SaveSync.pack({"data": synced["data"], "stamps": synced["stamps"]}))
	stats["uploads"] += 1


func _on_welcome_back(away: Dictionary) -> void:
	var st := Modules.style("away_avatar") as AwayAvatarStyle
	var minutes := maxi(1, int(round(float(away.get("seconds", 60.0)) / 60.0)))
	var line := Lang.fill(Lang.pick(st.welcome_lines) if st else "Welcome back!", {"minutes": Lang.digits(str(minutes))})
	var visits: Array = away.get("visits", [])
	if not visits.is_empty():
		var tea := 0
		for v in visits:
			if str(v.get("kind", "")) == "tea":
				tea += 1
		var vals := {"n": Lang.digits(str(visits.size())), "t": Lang.digits(str(tea))}
		if tea > 0:
			line += "  " + Lang.fill(Lang.pick({"fa": "{n} بار همسایه‌ها بهت سر زدند و {t} بار برات چای آوردند.", "en": "Neighbours visited {n} times and brought tea {t} times."}), vals)
		else:
			line += "  " + Lang.fill(Lang.pick({"fa": "{n} بار همسایه‌ها بهت سر زدند.", "en": "Neighbours visited {n} times."}), vals)
	away["message"] = line
	# Townspeople remember you were gone (Dialogue reads this).
	AwayMemory.remember(float(away.get("seconds", 60.0)), visits)
	# Shown once, as the NetHud welcome-back banner (no duplicate toast).
	welcome_back.emit(away)


@rpc("authority", "call_remote", "unreliable_ordered")
func s_snapshot(t: float, states: Dictionary) -> void:
	stats["snapshots"] += 1
	var st := netcode()
	for pid in states:
		var s: Array = states[pid]
		var pos := Vector3(s[0], s[1], s[2])
		if int(pid) == my_pid:
			var corr := NetMove.correction(pos, int(s[6]), _history, st)
			while not _history.is_empty() and int(_history[0][0]) <= int(s[6]):
				_history.pop_front()
			if corr != Vector3.ZERO:
				corrections += 1
				last_correction = corr
				var p := _local_player()
				if p:
					if corr.length() > (st.snap_threshold if st else 3.0):
						p.global_position += corr
						_correction_left = Vector3.ZERO
					else:
						_correction_left += corr
				# Later inputs were predicted from the wrong spot: shift them too.
				for h in _history:
					h[1] = h[1] + corr
			continue
		if not snapshots.has(pid):
			snapshots[pid] = []
		var buf: Array = snapshots[pid]
		buf.append([Time.get_ticks_msec() / 1000.0, pos, float(s[3]), float(s[4]), int(s[5])])
		if buf.size() > 30:
			buf.pop_front()


@rpc("authority", "call_remote", "reliable")
func s_roster(r: Dictionary) -> void:
	roster = r
	for pid in snapshots.keys():
		if not roster.has(pid):
			snapshots.erase(pid)
	roster_changed.emit()


@rpc("authority", "call_remote", "reliable")
func s_chat(pid: int, sender: String, text: String) -> void:
	stats["chat"] += 1
	chat_log.append({"pid": pid, "name": sender, "text": text, "t": now()})
	var st := chat_style()
	while chat_log.size() > (st.log_lines * 4 if st else 32):
		chat_log.pop_front()
	chat_received.emit(pid, sender, text)


@rpc("authority", "call_remote", "reliable")
func s_clock(day: int, minutes: float, weather: String, speed_index: int) -> void:
	_apply_clock(day, minutes, weather, speed_index)


@rpc("authority", "call_remote", "reliable")
func s_manifest(man: Dictionary) -> void:
	_start_module_sync(man)


@rpc("authority", "call_remote", "reliable")
func s_module(type: String, info: Dictionary, bodies: Dictionary) -> void:
	_pending_modules.erase(type)
	var res := ModuleManifest.install(type, info, bodies)
	var ok := bool(res["ok"])
	stats["modules_ok" if ok else "modules_failed"] += 1
	module_updated.emit(type, int(info.get("version", 0)), ok, str(res["error"]))


@rpc("authority", "call_remote", "reliable")
func s_avatar_event(pid: int, kind: String, npc: String, line_fa: String, line_en: String) -> void:
	stats["avatar_events"] += 1
	avatar_event.emit(pid, kind, npc, line_fa if Lang.is_fa() else line_en)


@rpc("authority", "call_remote", "reliable")
func s_npc_roles(roles: Dictionary) -> void:
	npc_roles = roles
	npc_roles_changed.emit(roles)


@rpc("authority", "call_remote", "reliable")
func s_room(info: Dictionary) -> void:
	room = info
	pending_room_action = ""
	room_changed.emit(info)


@rpc("authority", "call_remote", "reliable")
func s_room_list(rooms: Array) -> void:
	room_list = rooms
	room_list_received.emit(rooms)


@rpc("authority", "call_remote", "reliable")
func s_pong(client_ms: int) -> void:
	stats["pings"] = int(stats.get("pings", 0)) + 1
	var now := Time.get_ticks_msec()
	last_rtt_ms = float(now - int(client_ms))
	ping_received.emit(last_rtt_ms)


@rpc("authority", "call_remote", "reliable")
func s_version_mismatch(server_ver: String) -> void:
	print("Net: version mismatch (server %s, client %s) - playing offline" % [server_ver, GameBrand.version()])
	version_mismatch.emit(server_ver, GameBrand.version())
	GameEvents.notification_requested.emit(Lang.pick({
		"fa": "نسخهٔ بازی با سرور یکی نیست (سرور %s، شما %s). لطفاً به‌روز کن." % [server_ver, GameBrand.version()],
		"en": "Version mismatch (server %s, you %s). Please update." % [server_ver, GameBrand.version()],
	}))
