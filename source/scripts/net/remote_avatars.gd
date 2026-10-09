class_name RemoteAvatars
extends Node3D
## v5d: draws the other players (and the avatars of disconnected players)
## from the Net snapshots: humanoid body in the player's colour, name tag,
## chat bubble, interpolation ~120 ms in the past (netcode module). Away
## avatars sit at a little cafe table / on the porch; townspeople walk over to
## greet them or bring tea (away_avatar module, TeaVisitController).

var avatars: Dictionary = {}  ## pid -> RemoteAvatar
var visits_started: int = 0
var _npc_controllers: Dictionary = {}  ## npc name -> previous controller


func _ready() -> void:
	name = "RemoteAvatars"
	Net.roster_changed.connect(_sync_roster)
	Net.chat_received.connect(_on_chat)
	Net.avatar_event.connect(_on_avatar_event)
	Net.npc_roles_changed.connect(_on_npc_roles)
	Net.state_changed.connect(func(_s: String) -> void: _sync_roster())


func _sync_roster() -> void:
	for pid in avatars.keys():
		if not Net.roster.has(pid) or Net.state != "online":
			(avatars[pid] as Node).queue_free()
			avatars.erase(pid)
	if Net.state != "online":
		return
	for pid in Net.roster:
		if int(pid) == Net.my_pid:
			continue
		var info: Dictionary = Net.roster[pid]
		var av: RemoteAvatar = avatars.get(pid)
		if av == null:
			av = RemoteAvatar.new()
			av.pid = int(pid)
			av.color = info.get("color", Color(0.3, 0.5, 0.9))
			av.display_name = str(info.get("name", "?"))
			add_child(av)
			avatars[pid] = av
			var buf: Array = Net.snapshots.get(pid, [])
			if not buf.is_empty():
				av.global_position = buf[-1][1]
		av.set_status(str(info.get("state", "active")), str(info.get("dest", "")))


func _process(_delta: float) -> void:
	var st := Modules.style("netcode") as NetcodeStyle
	var render_t := Time.get_ticks_msec() / 1000.0 - (st.interp_delay if st else 0.12)
	for pid in avatars:
		var buf: Array = Net.snapshots.get(pid, [])
		if buf.is_empty():
			continue
		var av: RemoteAvatar = avatars[pid]
		var a: Array = buf[0]
		var b: Array = buf[-1]
		for i in range(buf.size() - 1):
			if float(buf[i][0]) <= render_t and float(buf[i + 1][0]) >= render_t:
				a = buf[i]
				b = buf[i + 1]
				break
		var span := maxf(float(b[0]) - float(a[0]), 0.0001)
		var k := clampf((render_t - float(a[0])) / span, 0.0, 1.0)
		if render_t > float(b[0]):
			k = 1.0
		var pos: Vector3 = (a[1] as Vector3).lerp(b[1], k)
		av.apply(pos, lerp_angle(float(a[2]), float(b[2]), k), lerpf(float(a[3]), float(b[3]), k), int(b[4]))


func _on_chat(pid: int, _sender: String, text: String) -> void:
	var av: RemoteAvatar = avatars.get(pid)
	if av:
		av.bubble(text)
	elif pid == Net.my_pid:
		var p := get_tree().get_first_node_in_group(&"player")
		if p:
			_own_bubble(p as Node3D, text)


var _own_label: Label3D
func _own_bubble(p: Node3D, text: String) -> void:
	if _own_label == null or not is_instance_valid(_own_label):
		_own_label = RemoteAvatar.make_bubble()
		p.add_child(_own_label)
	_own_label.text = text
	_own_label.visible = true
	var st := Modules.style("chat") as ChatStyle
	var tw := create_tween()
	tw.tween_interval(st.bubble_seconds if st else 6.0)
	tw.tween_callback(func() -> void:
		if is_instance_valid(_own_label):
			_own_label.visible = false)


func _bot_named(npc: String) -> TownspersonBot:
	for b in get_tree().get_nodes_in_group(&"townspeople"):
		if str(b.get("display_name")) == npc:
			return b as TownspersonBot
	return null


func _on_avatar_event(pid: int, kind: String, npc: String, line: String) -> void:
	var av: RemoteAvatar = avatars.get(pid)
	if av == null:
		return
	var bot := _bot_named(npc)
	if bot and bot.controller and not (bot.controller is TeaVisitController):
		bot.set_controller(TeaVisitController.new(bot.controller, av, kind, line))
		visits_started += 1
	else:
		av.bubble("%s: %s" % [npc, line])
		if kind == "tea":
			av.serve_tea()


func _on_npc_roles(roles: Dictionary) -> void:
	for b in get_tree().get_nodes_in_group(&"townspeople"):
		var bot := b as TownspersonBot
		var id := str(bot.display_name)
		var claimed := roles.has(id)
		if claimed and not (bot.controller is TeaVisitController.NetNpcController):
			_npc_controllers[id] = bot.controller
			var who := str((Net.roster.get(roles[id], {}) as Dictionary).get("name", "?"))
			bot.set_controller(TeaVisitController.NetNpcController.new(who))
		elif not claimed and bot.controller is TeaVisitController.NetNpcController and _npc_controllers.has(id):
			bot.set_controller(_npc_controllers[id])
			_npc_controllers.erase(id)
