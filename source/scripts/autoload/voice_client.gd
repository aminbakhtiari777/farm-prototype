extends Node
## Voice chat CLIENT side only (autoload "VoiceClient"). There is no voice
## server yet, so this module:
##   - handles push-to-talk (V / D-pad down) and the "talking" state,
##   - asks for the microphone on the first PTT press (web: getUserMedia via
##     JavaScriptBridge; desktop: AudioStreamMicrophone + AudioEffectCapture
##     if audio input is enabled),
##   - measures the mic level for the HUD meter,
##   - keeps the per-player mute list (stored in Settings),
##   - provides proximity attenuation for when peers exist,
##   - and reports "Voice server not configured" instead of erroring.
## Config: data/voice_config.json (LiveKit URL, token endpoint, TURN on 443).
## Wiring a real SFU is described in docs/VOICE_SETUP.md.

signal state_changed(state: String)
signal level_changed(level: float)

const CONFIG_PATH := "res://data/voice_config.json"

## idle | requesting_mic | talking | mic_denied | mic_unavailable
var state: String = "idle"
var talking: bool = false
## unknown | requesting | granted | denied | unavailable
var mic_state: String = "unknown"
var level: float = 0.0
var config: Dictionary = {}
var ptt_presses: int = 0
var _mic_player: AudioStreamPlayer
var _capture: AudioEffectCapture
var _web_ready: bool = false


func _ready() -> void:
	var f := FileAccess.open(CONFIG_PATH, FileAccess.READ)
	if f:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			config = parsed


func is_configured() -> bool:
	return str(config.get("livekit_url", "")) != "" and str(config.get("token_endpoint", "")) != ""


func status_text() -> String:
	if mic_state == "denied":
		return "Microphone blocked - allow it in the browser to talk"
	if mic_state == "unavailable":
		return "No microphone access on this platform (voice is web-only for now)"
	if not is_configured():
		return "Voice server not configured"
	return "Connected" if talking else "Ready"


func set_talking(value: bool) -> void:
	if value == talking:
		return
	talking = value
	if value:
		ptt_presses += 1
		_ensure_mic()
	_set_state(_compute_state())


func _compute_state() -> String:
	if mic_state == "denied":
		return "mic_denied"
	if mic_state == "unavailable":
		return "mic_unavailable" if talking else "idle"
	if talking and mic_state == "requesting":
		return "requesting_mic"
	return "talking" if talking else "idle"


func _set_state(s: String) -> void:
	if s != state:
		state = s
		state_changed.emit(s)


# ------------------------------------------------------------------ microphone
func _ensure_mic() -> void:
	if mic_state in ["granted", "requesting", "denied", "unavailable"]:
		return
	if OS.has_feature("web"):
		_request_web_mic()
	else:
		_start_desktop_mic()


func _request_web_mic() -> void:
	mic_state = "requesting"
	JavaScriptBridge.eval("""
	(function () {
		if (window.farmVoice) return;
		var fv = window.farmVoice = { state: 'requesting', levelValue: 0, analyser: null };
		fv.level = function () {
			if (!fv.analyser) return 0;
			var data = new Uint8Array(fv.analyser.fftSize);
			fv.analyser.getByteTimeDomainData(data);
			var sum = 0;
			for (var i = 0; i < data.length; i++) { var v = (data[i] - 128) / 128; sum += v * v; }
			return Math.sqrt(sum / data.length);
		};
		if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) { fv.state = 'unavailable'; return; }
		navigator.mediaDevices.getUserMedia({ audio: { echoCancellation: true, noiseSuppression: true, autoGainControl: true } })
			.then(function (stream) {
				var Ctx = window.AudioContext || window.webkitAudioContext;
				var ctx = new Ctx();
				var src = ctx.createMediaStreamSource(stream);
				fv.analyser = ctx.createAnalyser();
				fv.analyser.fftSize = 512;
				src.connect(fv.analyser);
				fv.stream = stream;
				fv.state = 'granted';
			})
			.catch(function (e) { fv.state = (e && e.name === 'NotFoundError') ? 'unavailable' : 'denied'; });
	})();
	""", true)
	_web_ready = true


func _start_desktop_mic() -> void:
	if DisplayServer.get_name() == "headless" or not bool(ProjectSettings.get_setting("audio/driver/enable_input", false)):
		mic_state = "unavailable"
		return
	var bus := AudioServer.get_bus_index(&"Mic")
	if bus == -1:
		AudioServer.add_bus()
		bus = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus, &"Mic")
		AudioServer.set_bus_mute(bus, true)  # never play our own voice back
		AudioServer.add_bus_effect(bus, AudioEffectCapture.new())
	_capture = AudioServer.get_bus_effect(bus, 0) as AudioEffectCapture
	_mic_player = AudioStreamPlayer.new()
	_mic_player.stream = AudioStreamMicrophone.new()
	_mic_player.bus = &"Mic"
	add_child(_mic_player)
	_mic_player.play()
	mic_state = "granted"


func _process(_delta: float) -> void:
	if OS.has_feature("web") and _web_ready:
		if mic_state == "requesting":
			var st: Variant = JavaScriptBridge.eval("window.farmVoice ? window.farmVoice.state : 'requesting'", true)
			if st is String and st != "requesting":
				mic_state = st
				_set_state(_compute_state())
		if talking and mic_state == "granted":
			var v: Variant = JavaScriptBridge.eval("window.farmVoice.level()", true)
			_set_level(clampf(float(v) * 4.0, 0.0, 1.0) if v != null else 0.0)
		elif level > 0.0:
			_set_level(0.0)
	elif _capture:
		var frames := _capture.get_frames_available()
		if frames > 0:
			var buf := _capture.get_buffer(frames)
			var sum := 0.0
			for s in buf:
				sum += s.x * s.x
			var rms := sqrt(sum / maxf(buf.size(), 1))
			_set_level(clampf(rms * 6.0, 0.0, 1.0) if talking else 0.0)


func _set_level(v: float) -> void:
	level = lerpf(level, v, 0.5)
	level_changed.emit(level)


# ------------------------------------------------------------------ peers
## Proximity volume 0..1 for a remote speaker at `speaker` heard at `listener`.
func attenuation(distance: float) -> float:
	var prox: Dictionary = config.get("proximity", {})
	var near := float(prox.get("full_volume_distance", 3.0))
	var far := float(prox.get("silent_distance", 25.0))
	if distance <= near:
		return 1.0
	if distance >= far:
		return 0.0
	var t := (distance - near) / (far - near)
	return pow(1.0 - t, 2.0)


func peer_volume(peer_name: String, speaker: Vector3, listener: Vector3) -> float:
	if is_muted(peer_name):
		return 0.0
	return attenuation(speaker.distance_to(listener))


func muted_players() -> Array:
	return Settings.get_value("voice_muted")


func is_muted(peer_name: String) -> bool:
	return peer_name in muted_players()


func set_muted(peer_name: String, value: bool) -> void:
	var list: Array = muted_players().duplicate()
	if value and peer_name not in list:
		list.append(peer_name)
	elif not value:
		list.erase(peer_name)
	Settings.set_value("voice_muted", list)
