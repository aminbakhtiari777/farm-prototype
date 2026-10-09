class_name AmbientEmitters
extends Node3D
## v7b.1 ambient_sounds module consumer. Ambient beds are placed 3D emitters,
## so they come from where they are and pan / fade as you walk and turn:
##   birds    in tree crowns (NatureScatter.tree_positions), by day
##   crickets in fields / meadows, at night (spring - autumn)
##   murmur   around the town square, 8:00 - 21:00 (quieter in rain)
##   river    along the river bed (the pond keeps BeachBuilder's PondSound)
##   traffic  distant rumble along the main streets, day + evening
##   waves    BeachBuilder's WaveSound emitters along the shore (reused)
## Only the nearest `active` emitters of each kind play (and never more than
## the voice cap); the rest are stopped, so they cost nothing. Indoors all
## outdoor emitters get a low cutoff + lower volume (muffled through walls).
## Sky: wind gusts sweep past overhead from a random direction; distant thunder
## rolls from a random direction only while it rains / storms.

var emitters: Dictionary = {}          ## kind -> Array[AudioStreamPlayer3D]
var gust: AudioStreamPlayer3D
var thunder: AudioStreamPlayer3D
var gusts: int = 0
var thunders: int = 0
var levels: Dictionary = {}            ## kind -> 0..1 (time of day / weather)
var _active: Dictionary = {}           ## instance id -> AudioStreamPlayer3D
var _timer: float = 0.0
var _gust_t: float = 6.0
var _thunder_t: float = 10.0
var _gust_from: Vector3
var _gust_to: Vector3
var _gust_age: float = 0.0
var _gust_len: float = 3.6
var _orig_filter: Dictionary = {}      ## instance id -> [cutoff, db] of foreign emitters (waves, pond)


func style() -> AmbientSoundsStyle:
	return Modules.style("ambient_sounds") as AmbientSoundsStyle


func _world() -> V7b1AudioWorld:
	return get_parent() as V7b1AudioWorld


func _ready() -> void:
	name = "AmbientEmitters"
	gust = AudioStreamPlayer3D.new()
	gust.name = "Gust"
	add_child(gust)
	thunder = AudioStreamPlayer3D.new()
	thunder.name = "Thunder"
	add_child(thunder)
	Modules.on_swap("ambient_sounds", self, func(_m: Resource) -> void: rebuild())
	# Trees / beach are built by other nodes in their _ready: place after them.
	rebuild.call_deferred()


func rebuild() -> void:
	for kind in emitters:
		for p in emitters[kind]:
			(p as Node).queue_free()
	emitters.clear()
	_active.clear()
	var st := style()
	if st == null:
		return
	var w := _world()
	for kind in st.kinds:
		var spec: Dictionary = st.kinds[kind]
		var s := V7b1AudioWorld.stream(str(spec.get("stream", "")))
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		var list: Array = []
		var pts := _placements(str(kind), int(spec.get("count", 4)))
		for i in pts.size():
			var p := AudioStreamPlayer3D.new()
			p.name = "%s%d" % [str(kind).capitalize(), i]
			p.stream = s
			if w:
				w.configure(p, float(spec.get("unit", 5.0)), float(spec.get("range", 35.0)))
			p.volume_db = float(spec.get("db", -8.0))
			p.set_meta(&"base_db", float(spec.get("db", -8.0)))
			p.set_meta(&"kind", str(kind))
			p.add_to_group(&"ambient_emitters")
			add_child(p)
			p.global_position = pts[i]
			list.append(p)
		emitters[kind] = list
	# BeachBuilder's waves + pond join the indoor muffling (left playing as they were).
	gust.max_distance = 60.0
	thunder.max_distance = 260.0
	if w:
		w.configure(gust, 10.0, 60.0)
		w.configure(thunder, 40.0, 260.0)
		thunder.attenuation_filter_cutoff_hz = 1800.0
	apply_filters()
	_timer = 0.0


## World positions for each kind (deterministic).
func _placements(kind: String, count: int) -> Array:
	var out: Array = []
	match kind:
		"birds":
			var nature: Node = get_tree().current_scene.find_child("Nature", true, false) if get_tree().current_scene else null
			var trees: Array = []
			if nature and "tree_positions" in nature:
				for tp in nature.get("tree_positions") as PackedVector3Array:
					if TownLayout.PLAY_AREA.grow(25.0).has_point(Vector2(tp.x, tp.z)):
						trees.append(tp)
			for tp in _spread(trees, count):
				var tv: Vector3 = tp
				out.append(tv + Vector3.UP * 4.0)
		"crickets":
			var cands: Array = []
			var r := TownLayout.PLAY_AREA
			var x := r.position.x + 6.0
			while x < r.end.x - 4.0:
				var z := r.position.y + 6.0
				while z < r.end.y - 4.0:
					if _is_meadow(x, z):
						cands.append(Vector3(x, Terrain.height_at(x, z) + 0.25, z))
					z += 9.0
				x += 9.0
			out = _spread(cands, count)
		"murmur":
			var c := TownLayout.TOWN_CENTER
			for i in count:
				var a := TAU * float(i) / float(maxi(count, 1)) + 0.4
				var q := c + Vector2(cos(a), sin(a)) * TownLayout.SQUARE_RADIUS * 0.75
				out.append(Vector3(q.x, Terrain.height_at(q.x, q.y) + 1.6, q.y))
		"river":
			var pts: Array = []
			var riv := TownLayout.RIVER
			for i in riv.size() - 1:
				var a2: Vector2 = riv[i]
				var b2: Vector2 = riv[i + 1]
				var n := int(ceil(a2.distance_to(b2) / 6.0))
				for k in n:
					var q2 := a2.lerp(b2, float(k) / float(n))
					if TownLayout.PLAY_AREA.grow(10.0).has_point(q2) and q2.distance_to(TownLayout.POND_CENTER) > TownLayout.POND_RADIUS + 4.0:
						pts.append(Vector3(q2.x, Terrain.river_surface(q2.x, q2.y) + 0.3, q2.y))
			out = _spread(pts, count)
		"traffic":
			var pts2: Array = []
			for rd in TownLayout.ROADS:
				var road: Dictionary = rd
				if str(road.get("kind", "")) != "paved" or float(road.get("half", 0.0)) < 4.0:
					continue
				var rp: Array = road["points"]
				for i in rp.size() - 1:
					var a3: Vector2 = rp[i]
					var b3: Vector2 = rp[i + 1]
					var n2 := maxi(1, int(a3.distance_to(b3) / 20.0))
					for k in n2:
						var q3 := a3.lerp(b3, (float(k) + 0.5) / float(n2))
						pts2.append(Vector3(q3.x, Terrain.height_at(q3.x, q3.y) + 0.6, q3.y))
			out = _spread(pts2, count)
	return out


func _is_meadow(x: float, z: float) -> bool:
	var p := Vector2(x, z)
	if TownLayout.sea_distance(x, z) > -TownLayout.SAND_WIDTH - 2.0:
		return false
	if p.distance_to(TownLayout.TOWN_CENTER) < 30.0 or p.distance_to(TownLayout.POND_CENTER) < TownLayout.POND_RADIUS + 2.0:
		return false
	if FootstepAudio.surface_at(Vector3(x, Terrain.height_at(x, z), z)) != "grass":
		return false
	for b in TownLayout.BUILDINGS:
		var bd: Dictionary = b
		var c: Vector2 = bd["pos"]
		if absf(c.x - x) < 14.0 and absf(c.y - z) < 14.0 and TownLayout.footprint_distance(bd, p, 0.0) < 6.0:
			return false
	return true


## Farthest-point sampling: `count` points spread over the candidates.
func _spread(cands: Array, count: int) -> Array:
	var out: Array = []
	if cands.is_empty() or count <= 0:
		return out
	out.append(cands[int(cands.size() * 0.5)])
	while out.size() < mini(count, cands.size()):
		var best: Vector3 = cands[0]
		var best_d := -1.0
		for c in cands:
			var cv: Vector3 = c
			var md := INF
			for o in out:
				var ov: Vector3 = o
				md = minf(md, cv.distance_squared_to(ov))
			if md > best_d:
				best_d = md
				best = cv
		out.append(best)
	return out


func active_count() -> int:
	var n := 0
	for id in _active:
		var p := _active[id] as AudioStreamPlayer3D
		if is_instance_valid(p) and p.playing:
			n += 1
	return n + (1 if gust.playing else 0) + (1 if thunder.playing else 0)


func all_emitters() -> Array:
	var out: Array = []
	for kind in emitters:
		out.append_array(emitters[kind])
	return out


func wave_emitters() -> Array:
	return get_tree().get_nodes_in_group(&"wave_sounds")


## Time-of-day / weather level per kind.
func update_levels() -> void:
	var daylight := 1.0
	var dn := get_tree().get_first_node_in_group(&"day_night")
	if dn:
		daylight = float(dn.get("daylight"))
	var w := TimeManager.weather_id
	var season := TimeManager.season_id()
	var hour := fposmod(TimeManager.hours_float(), 24.0)
	var wet := w in ["rain", "storm"]
	levels["day"] = daylight * (0.0 if wet else 1.0) * (0.3 if season == "winter" else 1.0)
	levels["night"] = (1.0 - daylight) * (0.0 if season == "winter" or w in ["storm", "snow"] else 1.0) * (0.55 if w == "rain" else 1.0)
	levels["town"] = smoothstep(7.5, 8.5, hour) * (1.0 - smoothstep(20.5, 21.5, hour)) * (0.4 if wet else 1.0)
	levels["traffic"] = (0.25 + 0.75 * smoothstep(6.0, 7.5, hour) * (1.0 - smoothstep(22.0, 23.5, hour)))
	levels["always"] = 0.8 if season == "winter" else 1.0


func _level_for(p: AudioStreamPlayer3D) -> float:
	var st := style()
	var spec: Dictionary = st.kinds.get(str(p.get_meta(&"kind", "")), {}) if st else {}
	return float(levels.get(str(spec.get("when", "always")), 1.0))


func _process(delta: float) -> void:
	var st := style()
	if st == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = st.update_interval
		update_levels()
		refresh()
	# Smooth volume toward each active emitter's target (no pops at the edges).
	for id in _active:
		var p := _active[id] as AudioStreamPlayer3D
		if is_instance_valid(p):
			p.volume_db = move_toward(p.volume_db, float(p.get_meta(&"target_db", p.volume_db)), delta * 12.0)
	_sky(delta, st)


## Pick the nearest emitters per kind within range, up to the voice cap.
func refresh() -> void:
	var st := style()
	var w := _world()
	if st == null or w == null:
		return
	var e := w.ear()
	var cap := maxi(1, w.voice_cap() - 2)   # keep 2 voices for steps / doors
	var want: Array = []
	for kind in emitters:
		var spec: Dictionary = st.kinds.get(kind, {})
		var reach := float(spec.get("range", 35.0))
		var c: Array = []
		for p in emitters[kind]:
			var ap := p as AudioStreamPlayer3D
			var d := ap.global_position.distance_to(e)
			var lv := _level_for(ap)
			if d < reach and lv > 0.02:
				c.append([d, ap, lv, reach])
		c.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
		want.append_array(c.slice(0, int(spec.get("active", 2))))
	want.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	want = want.slice(0, cap)
	var keep: Dictionary = {}
	for rec in want:
		var ap: AudioStreamPlayer3D = rec[1]
		var edge := 1.0 - smoothstep(float(rec[3]) * 0.7, float(rec[3]), float(rec[0]))
		var tdb := float(ap.get_meta(&"base_db", -8.0)) + linear_to_db(maxf(float(rec[2]) * edge, 0.001))
		if w.indoors:
			tdb += w.indoor_offset()
		ap.set_meta(&"target_db", tdb)
		keep[ap.get_instance_id()] = ap
		if not ap.playing:
			ap.volume_db = -40.0
			var slen := ap.stream.get_length() if ap.stream else 0.0
			ap.play(randf() * slen * 0.9 if slen > 0.0 else 0.0)
	for id in _active:
		if not keep.has(id):
			var old := _active[id] as AudioStreamPlayer3D
			if is_instance_valid(old):
				old.stop()
	_active = keep


func is_active(p: AudioStreamPlayer3D) -> bool:
	return _active.has(p.get_instance_id()) and p.playing


## Indoors: outdoor emitters (ours + beach waves / pond) are muffled.
func apply_filters() -> void:
	var w := _world()
	if w == null:
		return
	var sp := w.style()
	var inside := w.indoors
	var cut := sp.indoor_cutoff_hz if sp else 900.0
	var far_cut := sp.distance_cutoff_hz if sp else 6000.0
	var list := all_emitters()
	list.append_array(wave_emitters())
	var scene := get_tree().current_scene
	var pond: Node = scene.find_child("PondSound", true, false) if scene else null
	if pond:
		list.append(pond)
	for n in list:
		var p := n as AudioStreamPlayer3D
		if p == null or not is_instance_valid(p):
			continue
		var id := p.get_instance_id()
		if not _orig_filter.has(id):
			_orig_filter[id] = [far_cut if p.get_parent() == self else p.attenuation_filter_cutoff_hz, p.attenuation_filter_db]
		var o: Array = _orig_filter[id]
		p.attenuation_filter_cutoff_hz = cut if inside else float(o[0])
		p.attenuation_filter_db = -30.0 if inside else float(o[1])
		if p.get_parent() != self:
			if not p.has_meta(&"v7b1_vol"):
				p.set_meta(&"v7b1_vol", p.volume_db)
			p.volume_db = float(p.get_meta(&"v7b1_vol")) + (w.indoor_offset() if inside else 0.0)
	# Old 2D beds -> faint base (the placed emitters carry the direction).
	var amb := get_tree().get_first_node_in_group(&"ambience")
	var st := style()
	if amb and "bed_scale" in amb and st:
		var bs: Dictionary = amb.get("bed_scale")
		bs["birds"] = st.bed_2d_scale
		bs["crickets"] = st.bed_2d_scale


# ------------------------------------------------------------------ sky
func _sky(delta: float, st: AmbientSoundsStyle) -> void:
	var w := _world()
	if w == null:
		return
	var weather := TimeManager.weather_id
	var wet := weather in ["rain", "storm"]
	# Gust: sweeps past overhead from a random side (pan moves across).
	if gust.playing:
		_gust_age += delta
		gust.global_position = _gust_from.lerp(_gust_to, clampf(_gust_age / _gust_len, 0.0, 1.0))
	_gust_t -= delta * (1.8 if weather == "storm" else 1.3 if wet or weather == "cloudy" else 1.0)
	if _gust_t <= 0.0:
		_gust_t = randf_range(st.gust_interval.x, st.gust_interval.y)
		play_gust()
	# Thunder: rain / storm only, far away in a random direction.
	if wet and not st.thunder.is_empty():
		_thunder_t -= delta * (1.0 if weather == "storm" else 0.33)
		if _thunder_t <= 0.0:
			_thunder_t = randf_range(st.thunder_interval.x, st.thunder_interval.y)
			play_thunder()


func play_gust() -> bool:
	var st := style()
	var w := _world()
	if st == null or w == null or st.gusts.is_empty() or w.voices_playing() >= w.voice_cap():
		return false
	var e := w.ear()
	var a := randf() * TAU
	var dir := Vector3(cos(a), 0.0, sin(a))
	var up := Vector3.UP * randf_range(7.0, 13.0)
	_gust_from = e + dir * 16.0 + up
	_gust_to = e - dir * 16.0 + up
	_gust_age = 0.0
	gust.stream = V7b1AudioWorld.stream(st.gusts[randi() % st.gusts.size()])
	_gust_len = gust.stream.get_length() if gust.stream else 3.6
	gust.volume_db = st.gust_db + (w.indoor_offset() * 1.5 if w.indoors else 0.0)
	gust.attenuation_filter_cutoff_hz = 1200.0 if w.indoors else 7000.0
	gust.pitch_scale = randf_range(0.85, 1.15)
	gust.global_position = _gust_from
	gust.play()
	gusts += 1
	return true


func play_thunder() -> bool:
	var st := style()
	var w := _world()
	if st == null or w == null or st.thunder.is_empty():
		return false
	var a := randf() * TAU
	thunder.stream = V7b1AudioWorld.stream(st.thunder[randi() % st.thunder.size()])
	thunder.volume_db = st.thunder_db + (w.indoor_offset() if w.indoors else 0.0)
	thunder.pitch_scale = randf_range(0.8, 1.1)
	thunder.global_position = w.ear() + Vector3(cos(a), 0.0, sin(a)) * randf_range(55.0, 110.0) + Vector3.UP * 25.0
	thunder.play()
	thunders += 1
	return true
