class_name AudioBudget
extends Node
## Audio budget (audio_budget module x quality preset): positional players
## beyond audio_distance are paused (stream_paused - no mixing cost), at most
## max_voices positional players run at once (nearest win), and Sfx's cached
## streams that have not played for release_after seconds are dropped so the
## engine can free them. 2D players (UI, music, adhan/bells) are left alone.

var paused_far: int = 0
var paused_cap: int = 0
var playing_now: int = 0
var released: int = 0
var _timer: float = 0.0
var _release_timer: float = 0.0
var _paused: Dictionary = {}  ## instance_id -> AudioStreamPlayer3D (paused by us)
var _last_used: Dictionary = {}  ## Sfx cache id -> msec


func _ready() -> void:
	name = "AudioBudget"
	add_to_group(&"audio_budget")


func _style() -> AudioBudgetStyle:
	return Modules.style("audio_budget") as AudioBudgetStyle


func _process(delta: float) -> void:
	var st := _style()
	if st == null or not st.enabled:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = st.check_interval
	var lod := get_tree().get_first_node_in_group(&"auto_lod")
	var q: QualityStyle = lod.current_style() if lod else PerfQuality.style()
	if q == null:
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin := cam.global_position
	var live: Array = []
	paused_far = 0
	paused_cap = 0
	for n in get_tree().get_nodes_in_group(&"_ab_players"):
		pass
	for p in _players():
		var a := p as AudioStreamPlayer3D
		if not a.playing and not _paused.has(a.get_instance_id()):
			continue
		var reach := a.max_distance if a.max_distance > 0.0 else q.audio_distance
		var d := a.global_position.distance_to(origin)
		if d > minf(reach, q.audio_distance):
			_pause(a)
			paused_far += 1
		else:
			live.append([d, a])
	live.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	playing_now = 0
	for i in live.size():
		var a2: AudioStreamPlayer3D = live[i][1]
		if i < q.max_voices:
			_resume(a2)
			playing_now += 1
		else:
			_pause(a2)
			paused_cap += 1
	_release_timer -= st.check_interval
	if _release_timer <= 0.0:
		_release_timer = 10.0
		_release_cache(st.release_after)


var _cache_players: Array = []
var _cache_age: float = 99.0


## All positional players in the scene (cached list, refreshed every 3 s).
func _players() -> Array:
	_cache_age += _style().check_interval if _style() else 0.35
	if _cache_age > 3.0:
		_cache_age = 0.0
		_cache_players = get_tree().current_scene.find_children("*", "AudioStreamPlayer3D", true, false)
	return _cache_players.filter(func(x: Node) -> bool: return is_instance_valid(x) and x.is_inside_tree())


func _pause(a: AudioStreamPlayer3D) -> void:
	if not a.stream_paused:
		a.stream_paused = true
		_paused[a.get_instance_id()] = a


func _resume(a: AudioStreamPlayer3D) -> void:
	if _paused.has(a.get_instance_id()):
		_paused.erase(a.get_instance_id())
		a.stream_paused = false


## Sfx keeps every stream it ever loaded; drop the ones idle for a while.
func _release_cache(after_s: float) -> void:
	var sfx := get_node_or_null(^"/root/Sfx")
	if sfx == null or not ("_cache" in sfx):
		return
	var cache: Dictionary = sfx.get("_cache")
	var now := Time.get_ticks_msec()
	for id in cache.keys():
		if not _last_used.has(id):
			_last_used[id] = now
	for id in _last_used.keys():
		if cache.has(id) and now - int(_last_used[id]) > int(after_s * 1000.0):
			cache.erase(id)
			_last_used.erase(id)
			released += 1


## Sfx can call this when it plays a cached id (keeps it warm).
func touch(id: StringName) -> void:
	_last_used[id] = Time.get_ticks_msec()


func paused_count() -> int:
	return _paused.size()
