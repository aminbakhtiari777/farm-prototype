class_name WorldStreamer
extends Node
## Grid of cells. Modules (and a one-time auto-scan) register units that belong
## to a world position; only cells within the quality preset's stream_radius are
## awake. Far cells go dormant (process_mode DISABLED, meshes hidden, physics
## shapes off) and wake back up inside a per-frame time budget so driving into
## a new street never hitches. Gameplay for unloaded areas keeps running on
## data (WorldMemory / CityState / TownLife / fires / traffic) - this only
## manages nodes.

signal cell_loaded(key: Vector2i)
signal cell_unloaded(key: Vector2i)

class Unit:
	var node: Node
	var pos: Vector3
	var key: Vector2i
	var important: bool = false  ## never fully free; just sleep
	var was_visible: bool = true
	var was_process: int = Node.PROCESS_MODE_INHERIT
	var awake: bool = true


var _units: Array = []  ## Unit
var _by_key: Dictionary = {}  ## Vector2i -> Array[Unit]
var _loaded: Dictionary = {}  ## Vector2i -> true
var _queue_in: Array = []  ## Vector2i to wake
var _queue_out: Array = []  ## Vector2i to sleep
var _timer: float = 0.0
var _centre: Vector3 = Vector3.ZERO
var _builders: Array = []  ## Callables (key, rect) -> void: progressive content builders
var _built: Dictionary = {}  ## Vector2i -> true for builder-owned cells
var enabled: bool = true
var auto_scan_on_ready: bool = true
var _scanned: bool = false


func _ready() -> void:
	name = "WorldStreamer"
	add_to_group(&"world_streamer")
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "quality":
			_timer = 0.0)
	# Late scan so other modules have spawned their props.
	_late_scan.call_deferred()


func _late_scan() -> void:
	for i in 3:
		await get_tree().process_frame
	if auto_scan_on_ready:
		_auto_scan()


func register_builder(cb: Callable) -> void:
	_builders.append(cb)
	# Cells that are already live get built right away (late-loading modules).
	var st := _style()
	var cs := st.cell_size if st else 32.0
	for k in _loaded.keys():
		var kk: Vector2i = k
		cb.call(kk, Rect2(kk.x * cs, kk.y * cs, cs, cs))


func register(node: Node, world_pos: Vector3, important: bool = false) -> void:
	if node == null or not is_instance_valid(node):
		return
	var u := Unit.new()
	u.node = node
	u.pos = world_pos
	u.key = _key_of(world_pos)
	u.important = important
	if node is Node3D:
		u.was_visible = (node as Node3D).visible
	u.was_process = node.process_mode
	_units.append(u)
	if not _by_key.has(u.key):
		_by_key[u.key] = []
	(_by_key[u.key] as Array).append(u)
	# Content added by late modules must inherit the cell's current state.
	if _scanned and not _loaded.has(u.key):
		_set_awake(u, false)


func _style() -> WorldStreamStyle:
	return Modules.style("world_stream") as WorldStreamStyle


func _quality() -> QualityStyle:
	var lod := get_tree().get_first_node_in_group(&"auto_lod")
	if lod and lod.has_method("current_style"):
		return lod.current_style()
	return PerfQuality.style()


func _key_of(p: Vector3) -> Vector2i:
	var st := _style()
	var cs := st.cell_size if st else 32.0
	return Vector2i(floori(p.x / cs), floori(p.z / cs))


func _auto_scan() -> void:
	if _scanned:
		return
	_scanned = true
	var st := _style()
	if st == null or not st.enabled:
		return
	var names: Array = st.auto_units
	var scene := get_tree().current_scene
	if scene == null:
		return
	_scan_named(scene, names)
	# Buildings: whole unit (exterior stays drawn - AutoLod ranges handle it;
	# far = process + physics off, lazily-built interiors freed).
	for n in get_tree().get_nodes_in_group(&"buildings"):
		if n is Node3D:
			register(n, (n as Node3D).global_position, true)
	# Town chunks (merged static street meshes, no scripts): hidden when far.
	var town := scene.get_node_or_null(^"Town")
	if town:
		for c in town.get_children():
			if c is Node3D and not c.is_queued_for_deletion() and (str(c.name).begins_with("Chunk_") or str(c.name).begins_with("StreetProps_")):
				# important = never hidden (AutoLod visibility ranges fade streets in step
				# with the buildings standing on them; hiding whole chunks popped roads).
				var aabb_c := _centre_of(c as Node3D)
				register(c, aabb_c, true)
	# Force an immediate pass so the starting area is awake and the rest sleeps.
	_timer = 0.0
	_centre = Vector3(INF, 0, INF)
	_update_queues(true)
	_drain(st.budget_ms)


func _centre_of(n: Node3D) -> Vector3:
	var acc := Vector3.ZERO
	var cnt := 0
	for c in n.find_children("*", "VisualInstance3D", true, false):
		var vi := c as VisualInstance3D
		acc += vi.global_transform * vi.get_aabb().get_center()
		cnt += 1
	return acc / cnt if cnt > 0 else n.global_position


func _scan_named(n: Node, names: Array) -> void:
	if n is Building or n.is_in_group(&"player") or n is CharacterBody3D:
		return  # buildings are units themselves; never stream actors
	var sc: Script = n.get_script()
	if sc and sc.resource_path.get_file() in names and n is Node3D:
		register(n, (n as Node3D).global_position, false)
	for c in n.get_children():
		_scan_named(c, names)


func _process(delta: float) -> void:
	if not enabled:
		return
	var st := _style()
	if st == null or not st.enabled:
		return
	_timer -= delta
	# Teleports (doors, save load, respawn) are caught on the very next frame.
	var jumped := _player_pos().distance_to(_centre) > st.cell_size * 1.5
	if _timer <= 0.0 or jumped:
		_timer = st.update_interval
		_update_queues(false)
	_drain(st.budget_ms)


func _player_pos() -> Vector3:
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	return p.global_position if p else _centre


func _update_queues(force: bool) -> void:
	var st := _style()
	var q := _quality()
	if st == null or q == null:
		return
	var p := _player_pos()
	# Look-ahead while moving / driving.
	var player := get_tree().get_first_node_in_group(&"player") as CharacterBody3D
	if player:
		p += player.velocity * st.lookahead
	var jumped := _centre.distance_to(p) > st.cell_size * 1.5
	_centre = p
	if jumped:
		force = true  # teleport / load: wake the new area right now (no budget)
	var r := q.stream_radius
	var r2 := r * r
	var u2 := (r + st.unload_margin) * (r + st.unload_margin)
	var want: Dictionary = {}
	# Every cell whose centre is within stream_radius of the player.
	var cs := st.cell_size
	var min_k := Vector2i(floori((p.x - r) / cs), floori((p.z - r) / cs))
	var max_k := Vector2i(floori((p.x + r) / cs), floori((p.z + r) / cs))
	for x in range(min_k.x, max_k.x + 1):
		for z in range(min_k.y, max_k.y + 1):
			var k := Vector2i(x, z)
			var cx: float = (x + 0.5) * cs
			var cz: float = (z + 0.5) * cs
			if Vector2(cx - p.x, cz - p.z).length_squared() <= r2:
				want[k] = true
	# Discard stale work after a turn/teleport and never queue a cell twice.
	_queue_in.clear()
	_queue_out.clear()
	for k in want.keys():
		if not _loaded.has(k):
			_queue_in.append(k)
	if force:
		for k in want.keys():
			_wake_cell(k)
		_queue_in.clear()
		# Everything registered but not wanted sleeps (first pass: all cells start awake).
		for k in _by_key.keys():
			if not want.has(k):
				_loaded[k] = true
				_queue_out.append(k)
	else:
		for k in _loaded.keys():
			if want.has(k):
				continue
			var cx: float = (k.x + 0.5) * cs
			var cz: float = (k.y + 0.5) * cs
			if Vector2(cx - p.x, cz - p.z).length_squared() > u2:
				_queue_out.append(k)


func _drain(budget_ms: float) -> void:
	var t0 := Time.get_ticks_usec()
	while not _queue_in.is_empty():
		var k: Vector2i = _queue_in.pop_front()
		_wake_cell(k)
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			return
	while not _queue_out.is_empty():
		var k2: Vector2i = _queue_out.pop_front()
		_sleep_cell(k2)
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			return


func _wake_cell(k: Vector2i) -> void:
	if _loaded.has(k):
		return
	_loaded[k] = true
	for u in (_by_key.get(k, []) as Array):
		_set_awake(u, true)
	if not _built.has(k):
		_built[k] = true
		var st := _style()
		var cs := st.cell_size if st else 32.0
		var rect := Rect2(k.x * cs, k.y * cs, cs, cs)
		for b in _builders:
			b.call(k, rect)
	cell_loaded.emit(k)


func _sleep_cell(k: Vector2i) -> void:
	if not _loaded.has(k):
		return
	_loaded.erase(k)
	for u in (_by_key.get(k, []) as Array):
		_set_awake(u, false)
	cell_unloaded.emit(k)


func _set_awake(u: Unit, on: bool) -> void:
	if not is_instance_valid(u.node):
		return
	if u.awake == on:
		return
	var n := u.node
	# Never sleep something that has wandered next to the player (pushed / carried / driven).
	if not on and n is Node3D and (n as Node3D).global_position.distance_to(_player_pos()) < 40.0:
		return
	u.awake = on
	if on:
		n.process_mode = u.was_process
		if not u.important and n is Node3D:
			(n as Node3D).visible = u.was_visible
		wakes += 1
	else:
		u.was_process = n.process_mode
		# PROCESS_MODE_DISABLED: scripts, AnimationPlayers, sounds pause and every
		# CollisionObject3D below leaves the physics space (DISABLE_MODE_REMOVE).
		n.process_mode = Node.PROCESS_MODE_DISABLED
		if not u.important and n is Node3D:
			u.was_visible = (n as Node3D).visible
			(n as Node3D).visible = false
		if n.has_method("release_interior"):
			n.call("release_interior")
		sleeps += 1


var wakes: int = 0
var sleeps: int = 0


func unit_count() -> int:
	return _units.size()


func awake_units() -> int:
	var c := 0
	for u in _units:
		if (u as Unit).awake:
			c += 1
	return c


func loaded_count() -> int:
	return _loaded.size()


func is_loaded(world_pos: Vector3) -> bool:
	return _loaded.has(_key_of(world_pos))


## Force-load the cell under `world_pos` (save/load, teleports, smoke tests).
func ensure(world_pos: Vector3) -> void:
	var k := _key_of(world_pos)
	if not _loaded.has(k):
		_wake_cell(k)


## LoadingScreen hook (platform entry flow polls group "world_streamer").
## 1.0 once the first scan ran and nothing is queued to wake.
func load_progress() -> float:
	if not enabled or not auto_scan_on_ready:
		return 1.0
	if not _scanned:
		return 0.5
	var pending := _queue_in.size()
	if pending == 0:
		return 1.0
	return clampf(1.0 - float(pending) / float(maxi(_loaded.size() + pending, 1)), 0.5, 0.99)
