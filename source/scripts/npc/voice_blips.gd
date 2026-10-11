class_name VoiceBlips
extends Node
## v5b townspeople voices ("voices" module, VoiceStyle): when a speech bubble
## appears, the speaker "talks" in short synthesized vowel blips (no real
## speech). Pitch depends on the person: women and children higher, men lower,
## elders a bit lower, plus a stable per-person offset and per-syllable jitter.

var synthesized_speech_enabled := false
var spoken: int = 0
var last_pitch: float = 1.0
var last_rate: float = 1.0  ## v7b voice profile speaking rate
var _active: Array = []  ## [player, remaining syllables, timer, base pitch]
var _streams: Array[AudioStream] = []
var _streams_id: String = ""
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	add_to_group(&"voice_blips")
	_rng.seed = 77


static func style() -> VoiceStyle:
	return Modules.style("voices") as VoiceStyle


static func instance(tree: SceneTree) -> VoiceBlips:
	return tree.get_first_node_in_group(&"voice_blips") as VoiceBlips


## Base pitch for a resident (population module identity).
static func pitch_for(r: Dictionary) -> float:
	var st := style()
	if st == null:
		return 1.0
	var age := int(r.get("age", 30))
	var female := str(r.get("gender", "")) == "female"
	var p := st.man_pitch
	if age < 13:
		p = st.child_pitch
	elif age < 18:
		p = st.teen_pitch * (1.12 if female else 1.0)
	elif female:
		p = st.woman_pitch
	if age >= 60:
		p *= st.elder_mult
	var h := absi(str(r.get("name", "")).hash()) % 1000
	p *= 1.0 + (float(h) / 1000.0 - 0.5) * 2.0 * st.person_jitter
	return p


func _load_streams() -> void:
	var st := style()
	var sid := st.id if st else ""
	if sid == _streams_id and not _streams.is_empty():
		return
	_streams_id = sid
	_streams.clear()
	if st:
		for p in st.samples:
			var s := load(p) as AudioStream
			if s:
				_streams.append(s)


## Starts the blip "speech" for a bot saying `text`.
func speak(bot: Node3D, text: String) -> bool:
	if bot == null or not is_instance_valid(bot):
		return false
	# Synthesized vowel blips sound like unrelated effects, not conversation.
	# Keep the explicit diagnostics available, but ordinary dialogue uses text.
	if not synthesized_speech_enabled:
		return false
	var st := style()
	_load_streams()
	if st == null or _streams.is_empty() or not bool(Settings.get_value("npc_voices")):
		return false
	var cam := get_viewport().get_camera_3d()
	if cam and cam.global_position.distance_to(bot.global_position) > st.max_distance * 1.5:
		return false
	var player := bot.get_node_or_null(^"Voice") as AudioStreamPlayer3D
	if player == null:
		player = AudioStreamPlayer3D.new()
		player.name = "Voice"
		player.position = Vector3(0, 1.6, 0)
		player.max_distance = st.max_distance
		player.unit_size = 6.0
		player.bus = &"Master"
		bot.add_child(player)
	player.volume_db = st.volume_db
	var r: Dictionary = bot.get("resident") if bot.get("resident") is Dictionary else {}
	var base := pitch_for(r)
	# v7b: personal voice profile (voice_profiles module): pitch, rate, tone.
	var rate := 1.0
	var jit := st.syllable_jitter
	var prof := VoiceProfiles.of(r)
	if not prof.is_empty():
		base = float(prof.get("pitch", base))
		rate = float(prof.get("rate", 1.0))
		var ti := VoiceProfiles.tone_info(r)
		jit = float(ti.get("jitter", jit))
		player.volume_db = st.volume_db + float(ti.get("volume_db", 0.0))
	last_pitch = base
	last_rate = rate
	var syl := clampi(int(ceil(text.length() / 3.0)), 2, st.max_syllables)
	for a in _active:
		if a[0] == player:
			_active.erase(a)
			break
	_active.append([player, syl, 0.0, base, rate, jit])
	spoken += 1
	return true


func is_speaking(bot: Node3D) -> bool:
	var p := bot.get_node_or_null(^"Voice")
	for a in _active:
		if a[0] == p:
			return true
	return false


func _process(delta: float) -> void:
	if _active.is_empty():
		return
	var st := style()
	var step := st.syllable_seconds if st else 0.1
	for i in range(_active.size() - 1, -1, -1):
		var a: Array = _active[i]
		var obj: Variant = a[0]
		if not is_instance_valid(obj):
			_active.remove_at(i)
			continue
		var p := obj as AudioStreamPlayer3D
		a[2] = float(a[2]) - delta
		if float(a[2]) > 0.0:
			continue
		if int(a[1]) <= 0:
			_active.remove_at(i)
			continue
		a[1] = int(a[1]) - 1
		a[2] = step / maxf(float(a[4]) if a.size() > 4 else 1.0, 0.3) * _rng.randf_range(0.8, 1.25)
		p.stream = _streams[_rng.randi() % _streams.size()]
		var jit: float = float(a[5]) if a.size() > 5 else (st.syllable_jitter if st else 0.05)
		p.pitch_scale = clampf(float(a[3]) * _rng.randf_range(1.0 - jit, 1.0 + jit), 0.3, 3.0)
		p.play()
