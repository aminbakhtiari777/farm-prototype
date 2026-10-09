class_name FireSiren
extends Node3D
## v7b.1 "fire_truck" module: the fire truck's siren + flashing lights. A
## self-made procedural wail (two-tone sweep, generated once, looped) on an
## AudioStreamPlayer3D, so it sounds around town with distance falloff; it
## plays while the truck answers a call (FireService.Truck.TO_FIRE) and the
## cab light bar + side flashers blink. Swappable via the fire_truck module.

var fire: FireService
var truck: RoadCar
var player: AudioStreamPlayer3D
var lamps: Array[StandardMaterial3D] = []
var plays: int = 0  ## times the siren started (tests)
var _t: float = 0.0
static var _cache: Dictionary = {}


static func style() -> FireTruckStyle:
	return Modules.style("fire_truck") as FireTruckStyle


static func attach(fs: FireService, t: RoadCar) -> FireSiren:
	var s := FireSiren.new()
	s.name = "FireSiren"
	s.fire = fs
	s.truck = t
	t.add_child(s)
	return s


func _ready() -> void:
	var st := style()
	player = AudioStreamPlayer3D.new()
	player.name = "Siren"
	player.stream = siren_stream(st.siren_kind if st else "wail", st.siren_period if st else 2.4)
	player.unit_size = st.unit_size if st else 14.0
	player.max_distance = st.max_distance if st else 170.0
	player.volume_db = st.volume_db if st else -2.0
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.position = Vector3(0, 2.6, 2.0)
	add_child(player)
	# Cab light bar (red / white) + small side flashers.
	var sz := truck.size
	var cols: Array = st.light_colors if st else [Color(1, 0.08, 0.05), Color(1, 0.95, 0.9)]
	for i in 4:
		var m := StandardMaterial3D.new()
		var c: Color = cols[i % cols.size()]
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.2
		lamps.append(m)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.36, 0.14, 0.2)
		mi.mesh = bm
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3((i - 1.5) * 0.4, 2.85, sz.z * 0.5 - 1.2)
		add_child(mi)
	for sx in [1.0, -1.0]:
		for k in 2:
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.03, 0.12, 0.2)
			mi.mesh = bm
			mi.material_override = lamps[k * 2 + (0 if sx > 0 else 1)]
			mi.position = Vector3(sx * (sz.x * 0.5 + 0.02), 1.0, sz.z * 0.5 - 0.4 - k * (sz.z - 1.2))
			add_child(mi)


## Self-made siren: a sine sweeping between lo..hi Hz (wail) or alternating
## (hi_lo), with a little 2nd harmonic. One loop period, 16-bit mono.
static func siren_stream(kind: String = "wail", period: float = 2.4) -> AudioStreamWAV:
	var key := "%s|%.2f" % [kind, period]
	if _cache.has(key):
		return _cache[key]
	var rate := 22050
	var n := int(rate * period)
	var data := PackedByteArray()
	data.resize(n * 2)
	var ph := 0.0
	for i in n:
		var t := float(i) / rate
		var u := t / period
		var f: float
		if kind == "hi_lo":
			f = 960.0 if fmod(u * 2.0, 1.0) < 0.5 else 720.0
		else:
			f = 650.0 + 600.0 * (0.5 - 0.5 * cos(TAU * u))
		ph += TAU * f / rate
		var v := sin(ph) * 0.7 + sin(ph * 2.0) * 0.18 + sin(ph * 3.0) * 0.06
		data.encode_s16(i * 2, int(clampf(v * 0.8, -1.0, 1.0) * 28000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = n
	_cache[key] = w
	return w


func responding() -> bool:
	return fire != null and fire.truck_state == FireService.Truck.TO_FIRE


func _process(delta: float) -> void:
	var st := style()
	var on := responding() and (st == null or st.siren_enabled)
	if on and not player.playing:
		player.play()
		plays += 1
	elif not on and player.playing:
		player.stop()
	var flash := truck != null and truck.flashing
	_t += delta
	var phase := int(_t * 6.0) % 2
	for i in lamps.size():
		lamps[i].emission_energy_multiplier = (3.5 if (i % 2) == phase else 0.15) if flash else 0.2
