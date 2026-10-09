class_name CarAudio
extends Node3D
## v7b.1 car_sounds module consumer: procedural vehicle audio, synthesised once
## per voice and cached (no files, no downloads).
##  - engine loop per model (petrol 4/6-cyl, diesel knock for the bus / van /
##    trucks / tractor) on the car you drive + the nearest few AI vehicles;
##    pitch follows RPM from speed and gear (CarSystems gears, or simulated
##    gears for AI cars), volume follows the throttle;
##  - horn per model (replaces DrivableCar's generic horn stream);
##  - indicator ticks: 8 / 9 toggle left / right, and they come on by themselves
##    while you steer hard at low speed; small amber lamps blink on the car;
##  - tyre squeal on hard braking / sharp fast turns; door clunk per model.

const RATE := 22050
static var _cache: Dictionary = {}    ## key -> AudioStreamWAV

var engine: AudioStreamPlayer3D        ## the farmer's car
var tick: AudioStreamPlayer
var squeal: AudioStreamPlayer3D
var door: AudioStreamPlayer3D
var npc: Array[AudioStreamPlayer3D] = []
var car: DrivableCar = null            ## car being driven
var indicator: int = 0                 ## -1 left, 0 off, 1 right
var auto_indicator: int = 0
var ticks: int = 0
var squeals: int = 0
var doors: int = 0
var rpm: float = 0.0
var _blink_t: float = 0.0
var _prev_speed: float = 0.0
var _squeal_cd: float = 0.0
var _npc_t: float = 0.0
var _lamps: Dictionary = {}            ## car instance id -> [StandardMaterial3D, ...]
var _was_driver: Dictionary = {}       ## car instance id -> bool


func style() -> CarSoundStyle:
	return Modules.style("car_sounds") as CarSoundStyle


func _ready() -> void:
	engine = _player3d("Engine", 10.0)
	squeal = _player3d("Squeal", 9.0)
	door = _player3d("Door", 6.0)
	tick = AudioStreamPlayer.new()
	tick.name = "IndicatorTick"
	tick.volume_db = -14.0
	add_child(tick)
	Modules.on_swap("car_sounds", self, func(_m: Resource) -> void:
		_cache.clear()
		car = null
		engine.stop()
		for p in npc:
			p.stop()
			p.set_meta(&"car", null))


func _player3d(nm: String, unit: float) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.name = nm
	p.unit_size = unit
	p.max_distance = 60.0
	add_child(p)
	return p


## Sound voice used for a vehicle model name.
static func voice_of(model: String) -> String:
	match model:
		"hatch", "sedan", "city_sedan":
			return "sedan"
		"pickup", "work_truck", "delivery":
			return "delivery"
		"family_van", "van":
			return "van"
		"city_bus", "minibus", "bus":
			return "bus"
	return model


func engine_spec(model: String) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	var v := voice_of(model)
	return st.engines.get(v, st.engines.get("sedan", {}))


# ------------------------------------------------------------------ synthesis
## Looping engine voice at its idle firing frequency (pitch_scale = rpm / idle).
func engine_stream(model: String) -> AudioStreamWAV:
	var spec := engine_spec(model)
	var key := "eng|" + voice_of(model) + "|" + str(spec.hash())
	if _cache.has(key):
		return _cache[key]
	var hz := float(spec.get("hz", 36.0))
	var cyl := int(spec.get("cyl", 4))
	var harm: Array = spec.get("harm", [1.0, 0.5, 0.25])
	var rough := float(spec.get("rough", 0.1))
	var diesel := bool(spec.get("diesel", false))
	var cycles := 24
	var n := int(round(RATE * cycles / hz))
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(voice_of(model))
	var jitter: Array = []
	for c in cycles:
		jitter.append(1.0 + rng.randf_range(-rough, rough))
	var noise_lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var ph := t * hz            # cycles since start
		var cyc := int(ph) % cycles
		var frac: float = ph - floor(ph)
		var v := 0.0
		for k in harm.size():
			v += float(harm[k]) * sin(TAU * (k + 1) * ph * (cyl * 0.5) / 2.0)
		# Firing pulses: each cylinder kick inside the cycle.
		var pulse := pow(maxf(sin(TAU * ph * cyl * 0.5), 0.0), 6.0 if diesel else 3.0)
		v = v * 0.55 + pulse * (0.75 if diesel else 0.4)
		noise_lp = lerpf(noise_lp, rng.randf_range(-1.0, 1.0), 0.25 if diesel else 0.12)
		if diesel:
			v += noise_lp * pulse * 0.9     # clatter on every combustion
		v += noise_lp * 0.08
		v *= float(jitter[cyc]) * (1.0 - 0.15 * frac * rough)
		data.encode_s16(i * 2, int(clampf(v * 0.45, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_cache[key] = w
	return w


func horn_stream(model: String) -> AudioStreamWAV:
	var st := style()
	var f: Array = st.horns.get(voice_of(model), [392, 494]) if st else [392, 494]
	var key := "horn|%s" % str(f)
	if _cache.has(key):
		return _cache[key]
	var dur := 0.5 if voice_of(model) != "bus" else 0.8
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.02, 1.0) * minf((dur - t) / 0.06, 1.0)
		var v := 0.0
		for fq in f:
			# Square-ish (reed horn) = fundamental + odd harmonics.
			var p := TAU * float(fq) * t
			v += sin(p) + 0.33 * sin(3.0 * p) + 0.18 * sin(5.0 * p)
		v *= 0.28 * env
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_cache[key] = w
	return w


func _tick_stream() -> AudioStreamWAV:
	var st := style()
	var hz := st.indicator_hz if st else 1800.0
	var key := "tick|%d" % int(hz)
	if _cache.has(key):
		return _cache[key]
	var n := int(RATE * 0.03)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v := sin(TAU * hz * t) * exp(-t * 160.0) + sin(TAU * hz * 0.5 * t) * exp(-t * 90.0) * 0.5
		data.encode_s16(i * 2, int(clampf(v * 0.8, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_cache[key] = w
	return w


func _squeal_stream() -> AudioStreamWAV:
	if _cache.has("squeal"):
		return _cache["squeal"]
	var n := int(RATE * 0.7)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		var env := minf(t / 0.05, 1.0) * minf((0.7 - t) / 0.2, 1.0)
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.5)
		var v := (sin(TAU * (1150.0 + sin(t * 31.0) * 60.0) * t) * 0.6 + lp * 0.4) * env * 0.5
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_cache["squeal"] = w
	return w


func _door_stream() -> AudioStreamWAV:
	if _cache.has("door"):
		return _cache["door"]
	var n := int(RATE * 0.25)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, rng.randf_range(-1, 1), 0.08)
		var v := (sin(TAU * 85.0 * t) * 0.8 + lp * 1.6) * exp(-t * 22.0)
		if t > 0.06:
			v += sin(TAU * 140.0 * t) * exp(-(t - 0.06) * 40.0) * 0.4   # latch
		data.encode_s16(i * 2, int(clampf(v * 0.7, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.data = data
	_cache["door"] = w
	return w


# ------------------------------------------------------------------ RPM
## Engine RPM for a vehicle at `speed` (m/s) of top speed `top`; uses the
## v7b CarSystems gear when there is one, else simulated gears.
func rpm_for(model: String, speed: float, top: float, gear: int = 0) -> float:
	var spec := engine_spec(model)
	var idle := float(spec.get("idle_rpm", 800))
	var mx := float(spec.get("max_rpm", 6000))
	var gears := int(spec.get("gears", 5))
	var v := absf(speed)
	if v < 0.3:
		return idle
	var frac := clampf(v / maxf(top, 1.0), 0.0, 1.0)
	var g := gear if gear > 0 else clampi(int(frac * gears) + 1, 1, gears)
	# Each gear covers an equal slice of the top speed.
	var lo := float(g - 1) / gears
	var hi := float(g) / gears
	var in_gear := clampf((frac - lo) / maxf(hi - lo, 0.01), 0.0, 1.2)
	return lerpf(idle * 1.25, mx * 0.92, in_gear)


func pitch_for(model: String, r: float) -> float:
	var spec := engine_spec(model)
	return clampf(r / float(spec.get("idle_rpm", 800)), 0.5, 6.0)


# ------------------------------------------------------------------ frame
func _process(delta: float) -> void:
	var st := style()
	if st == null:
		return
	_track_doors()
	var p := _player_node()
	var c: DrivableCar = p.vehicle as DrivableCar if p and p.vehicle is DrivableCar else null
	if c != car:
		_set_car(c)
	if car and is_instance_valid(car):
		var sys := car.get_node_or_null(^"CarSystems") as CarSystems
		var vs := car.style()
		var top := (vs.max_speed if vs else 11.0) * float(car.get_meta(&"top_mult", 1.0))
		rpm = rpm_for(car.model_name, car.speed, top, sys.gear if sys and not sys.is_auto() else 0)
		engine.global_position = car.global_position + Vector3(0, 0.8, 0)
		engine.pitch_scale = pitch_for(car.model_name, rpm)
		var th := absf(float(car._input_state().get("throttle", 0.0))) if car.driver else 0.0
		engine.volume_db = float(engine_spec(car.model_name).get("db", -10.0)) + th * 4.0
		if not engine.playing:
			engine.play()
		_tyres(delta)
		_indicators(delta)
	_npc_engines(delta)


func _player_node() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func _set_car(c: DrivableCar) -> void:
	car = c
	indicator = 0
	auto_indicator = 0
	if car == null:
		engine.stop()
		return
	engine.stream = engine_stream(car.model_name)
	var h: Variant = car.get(&"_horn")
	if h is AudioStreamPlayer3D:
		(h as AudioStreamPlayer3D).stream = horn_stream(car.model_name)
	_prev_speed = car.speed
	_ensure_lamps(car)


func _track_doors() -> void:
	var st := style()
	for n in get_tree().get_nodes_in_group(&"drivable_cars"):
		var c := n as DrivableCar
		var id := c.get_instance_id()
		var now := c.driver != null
		if _was_driver.has(id) and bool(_was_driver[id]) != now:
			play_door(c)
		_was_driver[id] = now


func play_door(c: Node3D) -> void:
	var st := style()
	var model := str(c.get(&"model_name"))
	door.stream = _door_stream()
	door.global_position = c.global_position + Vector3(0, 1.0, 0)
	door.pitch_scale = float(st.door_pitch.get(voice_of(model), 1.0)) if st else 1.0
	door.volume_db = -6.0
	door.play()
	doors += 1


func _tyres(delta: float) -> void:
	var st := style()
	_squeal_cd = maxf(_squeal_cd - delta, 0.0)
	var decel := (absf(_prev_speed) - absf(car.speed)) / maxf(delta, 0.001)
	var lateral := car.speed * car.speed * absf(tan(car.steer)) / maxf(car.size.z * 0.62, 0.5)
	_prev_speed = car.speed
	if _squeal_cd <= 0.0 and absf(car.speed) > 3.0 and (decel > st.squeal_decel or lateral > 9.0):
		do_squeal(car)


func do_squeal(c: Node3D) -> void:
	squeal.stream = _squeal_stream()
	squeal.global_position = c.global_position
	squeal.volume_db = -8.0
	squeal.play()
	squeals += 1
	_squeal_cd = 1.2


func _unhandled_key_input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo or car == null or GameEvents.ui_open:
		return
	if k.keycode == KEY_8:
		indicator = 0 if indicator == -1 else -1
		get_viewport().set_input_as_handled()
	elif k.keycode == KEY_9:
		indicator = 0 if indicator == 1 else 1
		get_viewport().set_input_as_handled()


func set_indicator(side: int) -> void:
	indicator = side


func _indicators(delta: float) -> void:
	var st := style()
	# Auto: on while steering hard at low speed, cancels when straight again.
	if absf(car.steer_amount) > 0.45 and absf(car.speed) < 7.0:
		auto_indicator = 1 if car.steer_amount < 0.0 else -1   # + steer_amount = turning left
	elif absf(car.steer_amount) < 0.1:
		auto_indicator = 0
	var side := indicator if indicator != 0 else auto_indicator
	var lamps: Array = _lamps.get(car.get_instance_id(), [])
	if side == 0:
		_blink_t = 0.0
		for m: StandardMaterial3D in lamps:
			m.emission_energy_multiplier = 0.0
		return
	var period := st.indicator_period if st else 0.42
	var before := fmod(_blink_t, period * 2.0) < period
	_blink_t += delta
	var on := fmod(_blink_t, period * 2.0) < period
	if on != before or _blink_t <= delta:
		tick.stream = _tick_stream()
		tick.pitch_scale = 1.0 if on else 0.82
		tick.play()
		ticks += 1
	for i in lamps.size():
		var left_lamp := i % 2 == 0
		(lamps[i] as StandardMaterial3D).emission_energy_multiplier = 4.0 if on and ((side < 0) == left_lamp) else 0.0


func _ensure_lamps(c: DrivableCar) -> void:
	var id := c.get_instance_id()
	if _lamps.has(id):
		return
	var arr: Array = []
	for z: float in [1.0, -1.0]:
		for sx: float in [1.0, -1.0]:   # +X = driver's (left) side
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.55, 0.05)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.55, 0.05)
			m.emission_energy_multiplier = 0.0
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.12, 0.08, 0.06)
			b.mesh = bm
			b.material_override = m
			b.position = Vector3(sx * (c.size.x * 0.5 - 0.06), 0.72, z * (c.size.z * 0.5 + 0.01))
			b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			b.name = "Indicator"
			c.add_child(b)
			arr.append(m)
	# Order: [front-left, front-right, rear-left, rear-right] -> even = left.
	_lamps[id] = arr


func _npc_engines(delta: float) -> void:
	var st := style()
	_npc_t -= delta
	if not st.npc_engines:
		for p in npc:
			p.stop()
		return
	while npc.size() < st.max_npc_engines:
		var p := _player3d("NpcEngine%d" % npc.size(), 7.0)
		p.max_distance = 35.0
		npc.append(p)
	var cam := get_viewport().get_camera_3d()
	if _npc_t <= 0.0 and cam:
		_npc_t = 0.5
		var order: Array = []
		for n in get_tree().get_nodes_in_group(&"road_cars"):
			var rc := n as RoadCar
			if rc and rc.is_visible_in_tree():
				order.append([rc.global_position.distance_squared_to(cam.global_position), rc])
		order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		for i in npc.size():
			var want: RoadCar = order[i][1] if i < order.size() and float(order[i][0]) < 1600.0 else null
			var have: Variant = npc[i].get_meta(&"car") if npc[i].has_meta(&"car") else null
			if want != have:
				npc[i].set_meta(&"car", want)
				if want:
					npc[i].stream = engine_stream(str(want.get_meta(&"voice", want.model_name)))
					npc[i].play()
				else:
					npc[i].stop()
	for p in npc:
		var rc: Variant = p.get_meta(&"car") if p.has_meta(&"car") else null
		if rc == null or not is_instance_valid(rc):
			continue
		var r := rc as RoadCar
		var voice := str(r.get_meta(&"voice", r.model_name))
		p.global_position = r.global_position + Vector3(0, 0.8, 0)
		p.pitch_scale = pitch_for(voice, rpm_for(voice, r.cur_speed, maxf(r.speed, 8.0)))
		p.volume_db = float(engine_spec(voice).get("db", -10.0)) - 4.0
