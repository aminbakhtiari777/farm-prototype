class_name TownLandmark
extends Node3D
## v6b "landmark" module: the town square's symbol - a brick clock tower with
## stone bands, four clock faces that show the game time (hands move, faces
## glow at night), an open belfry and a turquoise tiled cap (or, with the
## "monument" variant, a stone obelisk). It chimes softly on the hour when
## you are nearby. E at the base reads the plaque / tells the time.

var hands: Array = []   ## [[hour_pivot, minute_pivot], ...]
var _face_mats: Array[StandardMaterial3D] = []
var _body: StaticBody3D
var _chime: AudioStreamPlayer3D
var _last_hour: int = -1
var chimes: int = 0
var spot: ActionSpot


func style() -> LandmarkStyle:
	return Modules.style("landmark") as LandmarkStyle


func _ready() -> void:
	add_to_group(&"town_landmark")
	_build()
	Modules.on_swap("landmark", self, func(_m: Resource) -> void: _build())


static func _mat(c: Color, rough: float = 0.8, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _box(s: Vector3, p: Vector3, m: Material, parent: Node3D = self) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s
	mi.mesh = bm
	mi.material_override = m
	mi.position = p
	parent.add_child(mi)
	return mi


func _build() -> void:
	for c in get_children():
		c.queue_free()
	hands.clear()
	_face_mats.clear()
	var st := style()
	if st == null:
		return
	var p := st.pos
	position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
	rotation.y = deg_to_rad(-45.0)  # faces the square diagonally
	_body = StaticBody3D.new()
	_body.name = "LandmarkBody"
	add_child(_body)
	if st.kind == "monument":
		_monument(st)
	else:
		_clock_tower(st)
	_chime = AudioStreamPlayer3D.new()
	_chime.stream = _chime_stream()
	_chime.unit_size = 20.0
	_chime.max_distance = 90.0
	_chime.position = Vector3(0, st.height * 0.7, 0)
	add_child(_chime)
	spot = ActionSpot.make(self, Vector3(0, 0, 2.6), 1.4, _spot_text, _use)
	spot.name = "Plaque"
	_update_hands()


func _collider(s: Vector3, p: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = s
	cs.shape = bs
	cs.position = p
	_body.add_child(cs)


func _clock_tower(st: LandmarkStyle) -> void:
	var brick := _mat(st.brick, 0.9)
	var stone := _mat(st.stone, 0.75)
	var roof := _mat(st.roof, 0.35, 0.15)
	var gold := _mat(Color(0.85, 0.68, 0.3), 0.3, 0.8)
	var h := st.height
	var w := 3.0
	# Plinth + steps.
	_box(Vector3(w + 1.6, 0.3, w + 1.6), Vector3(0, 0.15, 0), stone)
	_box(Vector3(w + 0.8, 0.6, w + 0.8), Vector3(0, 0.6, 0), stone)
	# Shaft (slight taper by two blocks) with stone bands.
	var shaft_h := h * 0.62
	_box(Vector3(w, shaft_h, w), Vector3(0, 0.9 + shaft_h * 0.5, 0), brick)
	for k in 3:
		var y := 0.9 + shaft_h * (0.3 + 0.33 * k)
		_box(Vector3(w + 0.14, 0.22, w + 0.14), Vector3(0, y, 0), stone)
	# Arched door + slit windows (dark insets) on the front.
	var dark := _mat(Color(0.12, 0.09, 0.08), 0.9)
	_box(Vector3(1.0, 1.9, 0.06), Vector3(0, 0.9 + 0.95, w * 0.5 + 0.01), _mat(Color(0.35, 0.22, 0.12), 0.7))
	for k in 2:
		_box(Vector3(0.28, 1.0, 0.05), Vector3(0, 0.9 + shaft_h * (0.45 + 0.3 * k), w * 0.5 + 0.01), dark)
	# Clock stage: wider stone block with four faces.
	var cy := 0.9 + shaft_h + 1.3
	_box(Vector3(w + 0.5, 2.6, w + 0.5), Vector3(0, cy, 0), stone)
	for side in 4:
		var yaw := side * PI * 0.5
		var face := Node3D.new()
		face.rotation.y = yaw
		face.position = Vector3(0, cy, 0)
		add_child(face)
		var dial_mat := _mat(Color(0.97, 0.95, 0.88), 0.5)
		dial_mat.emission_enabled = true
		dial_mat.emission = Color(1.0, 0.9, 0.65)
		dial_mat.emission_energy_multiplier = 0.0
		_face_mats.append(dial_mat)
		var dial := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.0
		cm.bottom_radius = 1.0
		cm.height = 0.06
		cm.radial_segments = 28
		dial.mesh = cm
		dial.material_override = dial_mat
		dial.rotation.x = PI * 0.5
		dial.position = Vector3(0, 0, (w + 0.5) * 0.5 + 0.03)
		face.add_child(dial)
		var rim := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 0.98
		tm.outer_radius = 1.1
		tm.rings = 28
		rim.mesh = tm
		rim.material_override = gold
		rim.rotation.x = PI * 0.5
		rim.position = dial.position + Vector3(0, 0, 0.02)
		face.add_child(rim)
		for t in 12:
			var a := TAU * t / 12.0
			var tick := _box(Vector3(0.06, 0.18 if t % 3 == 0 else 0.1, 0.02), Vector3(sin(a) * 0.82, cos(a) * 0.82, (w + 0.5) * 0.5 + 0.07), _mat(Color(0.1, 0.1, 0.12)), face)
			tick.rotation.z = -a
		var hp := Node3D.new()
		hp.position = Vector3(0, 0, (w + 0.5) * 0.5 + 0.09)
		face.add_child(hp)
		var mp := Node3D.new()
		mp.position = Vector3(0, 0, (w + 0.5) * 0.5 + 0.11)
		face.add_child(mp)
		_box(Vector3(0.09, 0.55, 0.02), Vector3(0, 0.24, 0), _mat(Color(0.08, 0.08, 0.1)), hp)
		_box(Vector3(0.06, 0.82, 0.02), Vector3(0, 0.36, 0), _mat(Color(0.08, 0.08, 0.1)), mp)
		hands.append([hp, mp])
	# Belfry: four corner piers, open arches, bell.
	var by := cy + 1.3
	var bh := 2.0
	for sx: float in [-1, 1]:
		for sz: float in [-1, 1]:
			_box(Vector3(0.5, bh, 0.5), Vector3(sx * (w * 0.5 - 0.15), by + bh * 0.5, sz * (w * 0.5 - 0.15)), brick)
	_box(Vector3(w + 0.3, 0.25, w + 0.3), Vector3(0, by + bh + 0.12, 0), stone)
	var bell := MeshInstance3D.new()
	var bc := CylinderMesh.new()
	bc.top_radius = 0.28
	bc.bottom_radius = 0.55
	bc.height = 0.8
	bell.mesh = bc
	bell.material_override = gold
	bell.position = Vector3(0, by + bh - 0.6, 0)
	add_child(bell)
	# Turquoise tiled cap (pyramid) + gold finial.
	var cap := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.05
	pm.bottom_radius = (w + 0.3) * 0.72
	pm.height = h * 0.2
	pm.radial_segments = 4
	cap.mesh = pm
	cap.material_override = roof
	cap.rotation.y = PI * 0.25
	cap.position = Vector3(0, by + bh + 0.25 + pm.height * 0.5, 0)
	add_child(cap)
	var fin := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.18
	sm.height = 0.36
	fin.mesh = sm
	fin.material_override = gold
	fin.position = Vector3(0, cap.position.y + pm.height * 0.5 + 0.15, 0)
	add_child(fin)
	_collider(Vector3(w + 0.8, h, w + 0.8), Vector3(0, h * 0.5, 0))


func _monument(st: LandmarkStyle) -> void:
	var stone := _mat(st.stone, 0.7)
	var dark := _mat(st.brick.darkened(0.2), 0.85)
	var h := st.height
	_box(Vector3(4.4, 0.3, 4.4), Vector3(0, 0.15, 0), dark)
	_box(Vector3(3.2, 0.9, 3.2), Vector3(0, 0.75, 0), stone)
	var ob := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.35
	cm.bottom_radius = 0.95
	cm.height = h - 1.2
	cm.radial_segments = 4
	ob.mesh = cm
	ob.material_override = stone
	ob.rotation.y = PI * 0.25
	ob.position = Vector3(0, 1.2 + cm.height * 0.5, 0)
	add_child(ob)
	_collider(Vector3(3.2, h, 3.2), Vector3(0, h * 0.5, 0))


func _spot_text() -> String:
	var st := style()
	if st and st.kind == "monument":
		return Lang.tt("خواندن لوح بنای یادبود", "read the monument's plaque")
	return Lang.tt("نگاه به ساعت برج (%s)" % Lang.digits(_clock()), "check the clock tower (%s)" % _clock())


func _use(_who: Node3D) -> void:
	GameEvents.notification_requested.emit(Lang.tt(
		"برج ساعت میدان: نماد نظم، عدالت و همبستگی مردم شهر. ساعت %s است." % Lang.digits(_clock()),
		"The square's clock tower: a symbol of order, justice and the town standing together. It is %s." % _clock()))


static var _chime_cache: AudioStreamWAV


static func _chime_stream() -> AudioStreamWAV:
	if _chime_cache:
		return _chime_cache
	var rate := 22050
	var notes := [659.3, 523.3, 587.3, 392.0]
	var each := 0.55
	var n := int(rate * (each * notes.size() + 1.2))
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var v := 0.0
		for k in notes.size():
			var t0 := t - k * each
			if t0 < 0.0:
				continue
			var env := exp(-t0 * 2.2)
			v += (sin(TAU * notes[k] * t0) + 0.4 * sin(TAU * notes[k] * 2.01 * t0) + 0.2 * sin(TAU * notes[k] * 3.0 * t0)) * env * 0.22
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	_chime_cache = w
	return w


func _update_hands() -> void:
	var hf := TimeManager.hours_float()
	var m := fmod(hf, 1.0) * 60.0
	for pair in hands:
		(pair[0] as Node3D).rotation.z = -TAU * fmod(hf, 12.0) / 12.0
		(pair[1] as Node3D).rotation.z = -TAU * m / 60.0
	var night := hf >= 19.0 or hf < 6.0
	for fm in _face_mats:
		fm.emission_energy_multiplier = 0.9 if night else 0.0


## Hand angle (radians, clockwise from 12) for tests.
func hour_hand_angle() -> float:
	return -(hands[0][0] as Node3D).rotation.z if not hands.is_empty() else 0.0


func _process(_delta: float) -> void:
	if hands.is_empty():
		return
	_update_hands()
	var h := TimeManager.hour()
	if h != _last_hour:
		var first := _last_hour < 0
		_last_hour = h
		var st := style()
		if not first and st and st.chime:
			chimes += 1
			var cam := get_viewport().get_camera_3d()
			if cam and cam.global_position.distance_to(global_position) < 90.0 and _chime:
				_chime.play()


static func _clock() -> String:
	return "%02d:%02d" % [TimeManager.hour(), TimeManager.minute()]
