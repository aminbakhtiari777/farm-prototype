class_name V7b1AudioWorld
extends Node
## v7b.1 audio workstream. One node (added by main.gd) that owns:
##   SpatialListener  AudioListener3D on the active camera (follow / cockpit /
##                    possessed resident) -> stereo panning + distance by position
##   FootstepAudio    surface-aware steps for the player, quieter steps for
##                    residents near the listener (possessed one = full volume)
##   DoorAudio        latch on open + thud on close for every BuildingDoor
##   AmbientEmitters  placed 3D beds (birds in trees, crickets in fields, square
##                    murmur, river, distant traffic) + wind gusts + storm thunder
## and a small pool of one-shot AudioStreamPlayer3D with a voice cap (nearest
## win), on top of the perf AudioBudget. Modules: spatial_audio, sound_fx,
## ambient_sounds. Sounds: tools/synth_audio_v7b1.py (assets/audio/v7b1/, ~130 KB).

var listener: SpatialListener
var footsteps: FootstepAudio
var doors: DoorAudio
var ambient: AmbientEmitters
var pool: Array[AudioStreamPlayer3D] = []
var one_shots: int = 0
var stolen: int = 0
var indoors: bool = false
static var _streams: Dictionary = {}


static func instance(tree: SceneTree) -> V7b1AudioWorld:
	return tree.get_first_node_in_group(&"v7b1_audio") as V7b1AudioWorld


static func stream(path: String) -> AudioStream:
	if path == "":
		return null
	if not _streams.has(path):
		_streams[path] = load(path) if ResourceLoader.exists(path) else null
	return _streams[path] as AudioStream


func style() -> SpatialAudioStyle:
	return Modules.style("spatial_audio") as SpatialAudioStyle


func _ready() -> void:
	name = "V7b1AudioWorld"
	add_to_group(&"v7b1_audio")
	# Dedicated / net-test servers have no ears.
	if DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--server"):
		set_process(false)
		return
	listener = SpatialListener.new()
	add_child(listener)
	footsteps = FootstepAudio.new()
	add_child(footsteps)
	doors = DoorAudio.new()
	add_child(doors)
	ambient = AmbientEmitters.new()
	add_child(ambient)
	_build_pool()
	GameEvents.building_entered.connect(func(_b: Node3D) -> void: _set_indoors(true))
	GameEvents.building_exited.connect(func(_b: Node3D) -> void: _set_indoors(false))
	Modules.on_swap("spatial_audio", self, func(_m: Resource) -> void:
		_build_pool()
		ambient.apply_filters())
	if OS.has_feature("web"):
		var q: Variant = JavaScriptBridge.eval("window.location.search", true)
		_probe = q is String and "audioprobe=1" in (q as String)
		_report_ready.call_deferred()


## Web: one console line when ready; ?audioprobe=1 adds a stats line every 2 s.
var _probe: bool = false
var _probe_t: float = 0.0


func _report_ready() -> void:
	for i in 3:
		await get_tree().process_frame
	print("FARMAUDIO ready emitters=%d doors=%d listener=%s" % [ambient.all_emitters().size(), doors.hooked, str(listener.is_current())])


func _process(delta: float) -> void:
	if not _probe:
		return
	_probe_t -= delta
	if _probe_t <= 0.0:
		_probe_t = 2.0
		var pl := footsteps.player()
		print("AUDIO: steps=%d surface=%s active=%d voices=%d/%d one_shots=%d doors=%d gusts=%d follows=%s" % [
			pl.footsteps_played if pl else -1, footsteps.surface, ambient.active_count(), voices_playing(), voice_cap(),
			one_shots, doors.hooked, ambient.gusts, listener.follows])


func _build_pool() -> void:
	for p in pool:
		p.queue_free()
	pool.clear()
	var st := style()
	var n := st.pool_size if st else 6
	for i in n:
		var p := AudioStreamPlayer3D.new()
		p.name = "OneShot%d" % i
		p.top_level = true
		configure(p, 4.0, 30.0)
		add_child(p)
		pool.append(p)


## Shared 3D settings: inverse-distance, stereo panning, distance low-pass.
func configure(p: AudioStreamPlayer3D, unit: float, reach: float) -> void:
	var st := style()
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.unit_size = unit
	p.max_distance = reach
	p.panning_strength = st.panning_strength if st else 1.5
	p.attenuation_filter_cutoff_hz = st.distance_cutoff_hz if st else 6000.0
	p.attenuation_filter_db = st.distance_filter_db if st else -18.0
	p.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED


## Voices this workstream may play at once (module cap and quality preset cap).
func voice_cap() -> int:
	var st := style()
	var cap := st.max_voices if st else 10
	var q: QualityStyle = PerfQuality.style()
	if q:
		cap = mini(cap, q.max_voices)
	return maxi(cap, 3)


func one_shots_playing() -> int:
	var n := 0
	for p in pool:
		if p.playing:
			n += 1
	return n


func voices_playing() -> int:
	return one_shots_playing() + (ambient.active_count() if ambient else 0)


func ear() -> Vector3:
	if listener and listener.is_inside_tree():
		return listener.global_position
	var cam := get_viewport().get_camera_3d()
	return cam.global_position if cam else Vector3.ZERO


## Positional one-shot from the pool. Silent beyond `reach` of the listener;
## when the cap is hit the farthest playing one-shot is reused (nearest win).
func play_at(s: AudioStream, pos: Vector3, db: float = -6.0, pitch: float = 1.0, unit: float = 4.0, reach: float = 30.0) -> AudioStreamPlayer3D:
	if s == null or pool.is_empty():
		return null
	var e := ear()
	var d := pos.distance_to(e)
	if d > reach:
		return null
	var allowed := voice_cap() - (ambient.active_count() if ambient else 0)
	allowed = clampi(allowed, 1, pool.size())
	var free_p: AudioStreamPlayer3D = null
	var playing := 0
	var far_p: AudioStreamPlayer3D = null
	var far_d := -1.0
	for p in pool:
		if p.playing:
			playing += 1
			var pd := p.global_position.distance_to(e)
			if pd > far_d:
				far_d = pd
				far_p = p
		elif free_p == null:
			free_p = p
	var use: AudioStreamPlayer3D = free_p
	if use == null or playing >= allowed:
		if far_p == null or far_d < d:
			return null  # every voice is nearer than this sound
		use = far_p
		use.stop()
		stolen += 1
	configure(use, unit, reach)
	use.stream = s
	use.volume_db = db + (indoor_offset() if indoors and not _near_indoor_ear(pos) else 0.0)
	use.pitch_scale = pitch
	use.global_position = pos
	use.play()
	one_shots += 1
	return use


func indoor_offset() -> float:
	var st := style()
	return st.indoor_db if st else -8.0


func _near_indoor_ear(pos: Vector3) -> bool:
	return pos.distance_to(ear()) < 6.0


func _set_indoors(v: bool) -> void:
	indoors = v
	if ambient:
		ambient.apply_filters()
