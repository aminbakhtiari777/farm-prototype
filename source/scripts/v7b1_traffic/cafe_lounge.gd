class_name CafeLounge
extends Node3D
## v7b.1 cafe_lounge module: a classier v7b terrace (stone tiles, cushions,
## table linen + candles, a pergola with warm pendant lights, potted plants and
## brass sconces) and, next to it, an indoor cafe-lounge you walk into. From
## `disco_hours` it becomes a disco: coloured dance-floor tiles, a mirror ball,
## sweeping coloured spot lights, the DJ booth (a v7b Staffing post), the bar
## (the v7b bartender post + the cafe menu, so the tipsy limit applies) and
## positional music, with a crowd of residents dancing. Dress code: stylish and
## modest - dancers wear a jacket / long sleeves (`dress_up`) for the evening
## and change back when they leave. Fights from the terrace still happen.

var cafe: TerraceCafe
var staffing: Staffing
var hall: Node3D
var roof: Node3D
var decor: Node3D
var music: AudioStreamPlayer3D
var tiles: Array[StandardMaterial3D] = []
var spots: Array[SpotLight3D] = []
var ball: MeshInstance3D
var glow: OmniLight3D
var dancers: Array = []          ## [{bot, sc, spot, top, phase}]
var auto: bool = true
var force_disco: int = -1        ## -1 = by the clock, 0 off, 1 on (tests / shots)
var _t: float = 0.0
var _crowd_t: float = 0.0
var _rng := RandomNumberGenerator.new()


func style() -> CafeLoungeStyle:
	return Modules.style("cafe_lounge") as CafeLoungeStyle


func _ready() -> void:
	_rng.randomize()
	rebuild.call_deferred()
	Modules.on_swap("cafe_lounge", self, func(_m: Resource) -> void: rebuild())
	Modules.on_swap("cafe", self, func(_m: Resource) -> void: _decorate.call_deferred())


func rebuild() -> void:
	send_home()
	if staffing:
		staffing.remove_post("lounge_bartender")
		staffing.remove_post("lounge_dj")
	if hall:
		hall.queue_free()
		hall = null
	tiles.clear()
	spots.clear()
	var st := style()
	if st == null:
		return
	_build_hall(st)
	_decorate()


# ------------------------------------------------------------------ terrace decor
func _decorate() -> void:
	if decor and is_instance_valid(decor):
		decor.queue_free()
	decor = null
	var st := style()
	if st == null or not st.terrace_decor or cafe == null or cafe.root == null:
		return
	var cs := cafe.style()
	var w := cs.size.x if cs else 11.0
	var d := cs.size.y if cs else 9.0
	decor = Node3D.new()
	decor.name = "ClassyDecor"
	cafe.root.add_child(decor)
	var stone := TrafficKit.mat(Color(0.86, 0.82, 0.74), 0.35)
	var stone2 := TrafficKit.mat(Color(0.74, 0.7, 0.63), 0.35)
	# Polished stone tiles over the deck (chequer).
	var n := 6
	for ix in n:
		for iz in 5:
			var tw := (w - 0.2) / n
			var td := (d - 0.4) / 5
			V7aKit.box(decor, Vector3(tw - 0.02, 0.02, td - 0.02), Vector3(-w * 0.5 + 0.1 + tw * (ix + 0.5), 0.231, -d * 0.5 + 0.2 + td * (iz + 0.5)),
				stone if (ix + iz) % 2 == 0 else stone2, false)
	var brass := TrafficKit.mat(st.trim, 0.25)
	brass.metallic = 0.8
	# Table linen + candle lanterns on every round table, cushions on chairs.
	var linen := TrafficKit.mat(Color(0.97, 0.96, 0.93), 0.8)
	var cushion := TrafficKit.mat(Color(0.48, 0.12, 0.16), 0.9)
	var candle := TrafficKit.mat(Color(1.0, 0.75, 0.4), 0.3, 3.0)
	for i in 3:
		var tp := Vector3(-0.6 + i * 2.2, 0, 1.6 if i != 1 else 2.9)
		V7aKit.cyl(decor, 0.56, 0.12, tp + Vector3(0, 0.92, 0), linen, 0.5)
		V7aKit.cyl(decor, 0.07, 0.14, tp + Vector3(-0.15, 1.05, -0.1), TrafficKit.mat(Color(0.95, 0.95, 1.0, 0.5), 0.05))
		V7aKit.cyl(decor, 0.03, 0.07, tp + Vector3(-0.15, 1.02, -0.1), candle)
		for sgn: float in [-1.0, 1.0]:
			var cp := tp + Vector3(sgn * 0.85, 0, 0)
			V7aKit.box(decor, Vector3(0.42, 0.06, 0.42), cp + Vector3(0, 0.72, 0), cushion, false)
			V7aKit.box(decor, Vector3(0.05, 0.42, 0.4), cp + Vector3(sgn * 0.17, 0.95, 0), cushion, false)
	# Pergola: slim dark beams over the deck + warm pendant lamps.
	var beam := TrafficKit.mat(Color(0.18, 0.13, 0.1), 0.6)
	for k in 5:
		var z := -d * 0.5 + 0.8 + k * (d - 1.2) / 4.0
		V7aKit.box(decor, Vector3(w - 0.3, 0.1, 0.12), Vector3(0, 3.15, z), beam)
	for sx: float in [-w * 0.5 + 0.25, w * 0.5 - 0.25]:
		V7aKit.box(decor, Vector3(0.12, 0.1, d - 0.4), Vector3(sx, 3.25, 0), beam)
	var shade := TrafficKit.mat(Color(0.95, 0.72, 0.4), 0.4, 2.2)
	for k in 3:
		var pz := -0.4 + k * 1.6
		V7aKit.cyl(decor, 0.01, 0.7, Vector3(-0.6 + k * 1.1, 2.8, pz), brass)
		V7aKit.cyl(decor, 0.22, 0.22, Vector3(-0.6 + k * 1.1, 2.4, pz), shade, 0.08)
	# Potted plants (olive trees / ferns) along the railing and by the entrance.
	var pot := TrafficKit.mat(Color(0.82, 0.78, 0.7), 0.6)
	var leaf := TrafficKit.mat(Color(0.25, 0.42, 0.22), 0.85)
	var leaf2 := TrafficKit.mat(Color(0.35, 0.5, 0.25), 0.85)
	for p: Vector3 in [Vector3(-w * 0.5 + 0.5, 0, d * 0.5 - 0.5), Vector3(w * 0.5 - 0.5, 0, d * 0.5 - 0.5), Vector3(-w * 0.5 + 0.5, 0, 0.6),
			Vector3(w * 0.5 - 0.5, 0, 0.6), Vector3(1.6, 0, d * 0.5 + 0.6), Vector3(-1.6, 0, d * 0.5 + 0.6)]:
		V7aKit.cyl(decor, 0.28, 0.6, p + Vector3(0, 0.52, 0), pot, 0.34)
		V7aKit.cyl(decor, 0.03, 0.7, p + Vector3(0, 1.1, 0), beam)
		V7aKit.ball(decor, 0.45, p + Vector3(0, 1.55, 0), leaf)
		V7aKit.ball(decor, 0.3, p + Vector3(0.2, 1.8, 0.1), leaf2)
	# Brass wall sconces on the back wall.
	for k in 3:
		var sp := Vector3(-3.0 + k * 3.0, 2.1, -d * 0.5 + 0.1)
		V7aKit.box(decor, Vector3(0.12, 0.3, 0.08), sp, brass)
		V7aKit.ball(decor, 0.1, sp + Vector3(0, 0.12, 0.1), TrafficKit.mat(Color(1.0, 0.8, 0.5), 0.3, 3.0))
	# One warm light under the pergola (night only, with the cafe glow).
	var warm := OmniLight3D.new()
	warm.name = "PergolaWarm"
	warm.light_color = Color(1.0, 0.76, 0.45)
	warm.omni_range = 8.0
	warm.light_energy = 0.0
	warm.position = Vector3(0, 2.6, 1.0)
	warm.shadow_enabled = false
	decor.add_child(warm)
	warm.add_to_group(&"night_lights")


# ------------------------------------------------------------------ the hall
func hall_xform() -> Transform3D:
	var st := style()
	var p := TrafficKit.ground(st.hall_pos)
	return Transform3D(Basis(Vector3.UP, deg_to_rad(st.hall_yaw)), p)


func at(local: Vector3) -> Vector3:
	return hall.global_transform * local if hall else local


func _build_hall(st: CafeLoungeStyle) -> void:
	hall = Node3D.new()
	hall.name = "LoungeHall"
	add_child(hall)
	hall.global_transform = hall_xform()
	var w := st.hall_size.x
	var h := st.hall_size.y
	var d := st.hall_size.z
	V7bKit.clear_trees(get_tree(), Rect2(st.hall_pos - Vector2(maxf(w, d), maxf(w, d)) * 0.65, Vector2(maxf(w, d), maxf(w, d)) * 1.3))
	var wall := TrafficKit.mat(st.wall, 0.8)
	var outer := TrafficKit.mat(Color(0.93, 0.9, 0.84), 0.85)
	var brass := TrafficKit.mat(st.trim, 0.25)
	brass.metallic = 0.8
	var body := StaticBody3D.new()
	body.name = "HallBody"
	hall.add_child(body)
	# Foundation / floor.
	V7aKit.box(hall, Vector3(w + 0.4, 0.3, d + 0.4), Vector3(0, 0.0, 0), outer)
	V7aKit.box(hall, Vector3(w - 0.1, 0.04, d - 0.1), Vector3(0, 0.17, 0), TrafficKit.mat(Color(0.25, 0.17, 0.12), 0.35))
	_col(body, Vector3(w + 0.4, 0.3, d + 0.4), Vector3(0, 0.0, 0))
	# Walls (outer cream, inner plum) with a door gap in the front (+z).
	var door_w := 2.2
	for side in [[Vector3(0, h * 0.5, -d * 0.5), Vector3(w, h, 0.2)], [Vector3(-w * 0.5, h * 0.5, 0), Vector3(0.2, h, d)], [Vector3(w * 0.5, h * 0.5, 0), Vector3(0.2, h, d)],
			[Vector3(-(w + door_w) * 0.25, h * 0.5, d * 0.5), Vector3((w - door_w) * 0.5, h, 0.2)], [Vector3((w + door_w) * 0.25, h * 0.5, d * 0.5), Vector3((w - door_w) * 0.5, h, 0.2)]]:
		var p: Vector3 = side[0]
		var s: Vector3 = side[1]
		V7aKit.box(hall, s, p + Vector3(0, 0.15, 0), outer)
		var inner := s - Vector3(0.0 if s.x > 1.0 else -0.02, 0.0, 0.0 if s.z > 1.0 else -0.02)
		var inward := -p.normalized() * 0.05
		inward.y = 0.0
		V7aKit.box(hall, Vector3(maxf(inner.x - 0.1, 0.02), h - 0.05, maxf(inner.z - 0.1, 0.02)), p + Vector3(0, 0.15, 0) + inward, wall, false)
		_col(body, s, p + Vector3(0, 0.15, 0))
	V7aKit.box(hall, Vector3(door_w + 0.2, 0.6, 0.22), Vector3(0, h - 0.15, d * 0.5), outer)
	# Big front windows (glass) either side of the door, brass frames.
	var glass := TrafficKit.mat(Color(1.0, 0.82, 0.55, 0.45), 0.05, 0.6)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for sx: float in [-1.0, 1.0]:
		V7aKit.box(hall, Vector3(2.4, 1.6, 0.05), Vector3(sx * (door_w * 0.5 + 1.8), 1.7, d * 0.5 + 0.12), glass, false)
		V7aKit.box(hall, Vector3(2.5, 0.06, 0.08), Vector3(sx * (door_w * 0.5 + 1.8), 2.53, d * 0.5 + 0.13), brass, false)
		V7aKit.box(hall, Vector3(2.5, 0.06, 0.08), Vector3(sx * (door_w * 0.5 + 1.8), 0.88, d * 0.5 + 0.13), brass, false)
	# Awning + sign over the door.
	V7aKit.box(hall, Vector3(door_w + 1.2, 0.08, 1.2), Vector3(0, h - 0.3, d * 0.5 + 0.6), TrafficKit.mat(Color(0.35, 0.08, 0.12), 0.7))
	var sign := TrafficKit.label(hall, "%s\n%s" % [str(st.name.get("fa", "کافه لانژ")), str(st.name.get("en", "Lounge Cafe"))], "", Vector3(0, h + 0.45, d * 0.5 + 0.13), 0.0, 0.006, 64, st.trim, 10)
	sign.remove_from_group(&"v7b_signs")
	sign.name = "LoungeSign"
	V7aKit.box(hall, Vector3(3.6, 1.0, 0.06), Vector3(0, h + 0.45, d * 0.5 + 0.08), TrafficKit.mat(Color(0.1, 0.07, 0.08), 0.5))
	# Roof (hidden while you are inside).
	roof = Node3D.new()
	roof.name = "Roof"
	hall.add_child(roof)
	V7aKit.box(roof, Vector3(w + 0.6, 0.25, d + 0.6), Vector3(0, h + 0.2, 0), TrafficKit.mat(Color(0.25, 0.22, 0.24), 0.8))
	V7aKit.box(roof, Vector3(w + 0.7, 0.1, d + 0.7), Vector3(0, h + 0.36, 0), brass)
	# ---- inside: bar along the back wall, DJ booth on the left, dance floor centre, lounge sofas right.
	var bz := -d * 0.5 + 1.2
	V7aKit.box(hall, Vector3(4.6, 1.05, 0.65), Vector3(1.0, 0.7, bz), TrafficKit.mat(Color(0.15, 0.1, 0.08), 0.4))
	V7aKit.box(hall, Vector3(4.8, 0.06, 0.8), Vector3(1.0, 1.25, bz), TrafficKit.mat(Color(0.9, 0.88, 0.84), 0.2))
	_col(body, Vector3(4.6, 1.1, 0.65), Vector3(1.0, 0.7, bz))
	V7aKit.box(hall, Vector3(4.6, 0.05, 0.08), Vector3(1.0, 0.3, bz + 0.34), brass, false)
	for k in 3:
		V7aKit.box(hall, Vector3(4.0, 0.04, 0.26), Vector3(1.0, 1.5 + k * 0.45, -d * 0.5 + 0.25), brass, false)
		for j in 10:
			var c: Color = [Color(0.85, 0.5, 0.1), Color(0.2, 0.55, 0.25), Color(0.9, 0.85, 0.75), Color(0.55, 0.15, 0.2)][(j + k) % 4]
			V7aKit.cyl(hall, 0.05, 0.24, Vector3(-0.8 + j * 0.4, 1.64 + k * 0.45, -d * 0.5 + 0.25), TrafficKit.mat(c, 0.15, 0.3))
	var bar_spot := ActionSpot.make(hall, Vector3(1.0, 0.2, bz + 0.95), 1.3,
		func() -> String: return Lang.tt("سفارش در بار لانژ", "order at the lounge bar"),
		func(_w: Node3D) -> void:
			if cafe:
				cafe.open_menu())
	bar_spot.name = "LoungeBar"
	# DJ booth.
	var djx := -w * 0.5 + 1.1
	V7aKit.box(hall, Vector3(1.0, 1.05, 2.0), Vector3(djx, 0.7, -0.6), TrafficKit.mat(Color(0.06, 0.06, 0.08), 0.4))
	V7aKit.box(hall, Vector3(1.02, 0.08, 2.02), Vector3(djx, 0.95, -0.6), TrafficKit.mat(Color(0.3, 0.55, 1.0), 0.3, 2.0), false)
	_col(body, Vector3(1.0, 1.05, 2.0), Vector3(djx, 0.7, -0.6))
	for k in 2:
		V7aKit.cyl(hall, 0.2, 0.04, Vector3(djx, 1.25, -1.0 + k * 0.8), TrafficKit.mat(Color(0.03, 0.03, 0.03), 0.2))
	for zz: float in [-2.4, 1.3]:
		V7aKit.box(hall, Vector3(0.7, 1.6, 0.6), Vector3(djx - 0.1, 0.95, zz), TrafficKit.mat(Color(0.05, 0.05, 0.06), 0.7))
		_col(body, Vector3(0.7, 1.6, 0.6), Vector3(djx - 0.1, 0.95, zz))
	# Lounge sofas (velvet) + low tables on the right.
	var velvet := TrafficKit.mat(Color(0.3, 0.12, 0.35), 0.9)
	for k in 2:
		var sz := -1.6 + k * 3.0
		V7aKit.box(hall, Vector3(0.8, 0.45, 2.0), Vector3(w * 0.5 - 0.7, 0.42, sz), velvet)
		V7aKit.box(hall, Vector3(0.2, 0.55, 2.0), Vector3(w * 0.5 - 0.25, 0.8, sz), velvet)
		V7aKit.cyl(hall, 0.4, 0.06, Vector3(w * 0.5 - 1.7, 0.6, sz), TrafficKit.mat(Color(0.12, 0.1, 0.1), 0.2))
		V7aKit.cyl(hall, 0.06, 0.4, Vector3(w * 0.5 - 1.7, 0.38, sz), brass)
		_col(body, Vector3(0.8, 0.5, 2.0), Vector3(w * 0.5 - 0.7, 0.42, sz))
	# Dance floor: 5 x 4 glowing tiles.
	var cols: Array = st.dance_colors if not st.dance_colors.is_empty() else [Color(1, 0.7, 0.4)]
	for c: Variant in cols:
		var m := StandardMaterial3D.new()
		m.albedo_color = (c as Color).darkened(0.5)
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = 0.2
		m.roughness = 0.2
		tiles.append(m)
	for ix in 5:
		for iz in 4:
			V7aKit.box(hall, Vector3(0.88, 0.03, 0.88), Vector3(-1.2 + ix * 0.9, 0.205, 0.3 + iz * 0.9 - 1.35), tiles[(ix * 3 + iz) % tiles.size()], false)
	# Mirror ball + coloured sweeping spots + one ambient glow.
	var mirror := TrafficKit.mat(Color(0.85, 0.85, 0.9), 0.05)
	mirror.metallic = 1.0
	ball = V7aKit.ball(hall, 0.32, Vector3(0.6, h - 0.55, 0.0), mirror)
	ball.name = "MirrorBall"
	V7aKit.cyl(hall, 0.01, 0.4, Vector3(0.6, h - 0.15, 0.0), brass)
	for k in 3:
		var s := SpotLight3D.new()
		s.light_color = cols[k % cols.size()]
		s.spot_range = 9.0
		s.spot_angle = 22.0
		s.light_energy = 0.0
		s.shadow_enabled = false
		s.position = Vector3(-2.0 + k * 2.6, h - 0.2, -0.8)
		hall.add_child(s)
		spots.append(s)
	glow = OmniLight3D.new()
	glow.name = "LoungeGlow"
	glow.light_color = Color(1.0, 0.75, 0.5)
	glow.omni_range = 9.0
	glow.light_energy = 0.0
	glow.position = Vector3(0, h - 0.6, 0.6)
	glow.shadow_enabled = false
	hall.add_child(glow)
	# Positional music (heard in and around the lounge).
	music = AudioStreamPlayer3D.new()
	music.name = "LoungeMusic"
	music.position = Vector3(djx, 1.4, -0.6)
	music.unit_size = 6.0
	music.max_distance = 26.0
	music.volume_db = st.music_db
	if not st.music.is_empty():
		var s0 := load(st.music[0]) as AudioStream
		if s0:
			var s1 := s0.duplicate() as AudioStream
			if s1 is AudioStreamOggVorbis:
				(s1 as AudioStreamOggVorbis).loop = true
			music.stream = s1
	hall.add_child(music)
	# Staff posts (v7b Staffing): the DJ and a bartender during disco / open hours.
	if auto:
		set_staff(true)


## Staff posts on / off (tests switch them off so other sections keep their people).
func set_staff(on: bool) -> void:
	if staffing == null:
		return
	if not on:
		staffing.remove_post("lounge_bartender")
		staffing.remove_post("lounge_dj")
	elif not staffing.posts.has("lounge_bartender"):
		var st := style()
		var cs := cafe.style() if cafe else null
		if st and cs:
			var bz := -st.hall_size.z * 0.5 + 1.2
			var djx := -st.hall_size.x * 0.5 + 1.1
			staffing.add_post("lounge_bartender", Array(cs.staff.get("bartender", [])), at(Vector3(1.0, 0.2, bz - 0.6)), at(Vector3(1.0, 0, 0)), st.open_hours)
			if st.disco:
				staffing.add_post("lounge_dj", Array(cs.staff.get("dj", [])), at(Vector3(djx - 0.9, 0.2, -0.6)), at(Vector3(0, 0, -0.6)), st.disco_hours)


func _col(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	cs.position = pos
	body.add_child(cs)


# ------------------------------------------------------------------ disco
func disco_on() -> bool:
	var st := style()
	if st == null or not st.disco:
		return false
	if force_disco >= 0:
		return force_disco == 1
	return Staffing.open_at(st.disco_hours, TimeManager.hours_float())


func is_open() -> bool:
	var st := style()
	return st != null and (force_disco == 1 or Staffing.open_at(st.open_hours, TimeManager.hours_float()))


func _inside(p: Vector3) -> bool:
	var st := style()
	var l := hall.global_transform.affine_inverse() * p
	return absf(l.x) < st.hall_size.x * 0.5 and absf(l.z) < st.hall_size.z * 0.5


func player_inside() -> bool:
	var p := V7bKit.player(get_tree())
	if p == null or hall == null:
		return false
	var st := style()
	var l := hall.global_transform.affine_inverse() * p.global_position
	return absf(l.x) < st.hall_size.x * 0.5 and absf(l.z) < st.hall_size.z * 0.5 and l.y < st.hall_size.y + 1.0


## Dance spots on the floor (world).
func dance_spot(i: int) -> Vector3:
	var gx := i % 4
	var gz := i / 4
	var j := Vector3(sin(i * 2.3) * 0.2, 0.2, cos(i * 1.7) * 0.2)
	return at(Vector3(-1.1 + gx * 1.1, 0, -1.2 + gz * 1.0) + j)


## Invite residents to dance (up to the crowd size). Returns how many joined.
func fill_crowd(n: int = -1) -> int:
	var st := style()
	if st == null or hall == null:
		return 0
	var want := st.crowd if n < 0 else n
	var added := 0
	var by_d: Array = []
	for b in V7aKit.bots(get_tree()):
		if b.resident.is_empty() or int(b.resident.get("age", 0)) < 18:
			continue
		if not (b.controller is ScheduleController):
			continue
		var skip := false
		for dd: Dictionary in dancers:
			if dd["bot"] == b:
				skip = true
		if skip:
			continue
		by_d.append([b.global_position.distance_to(hall.global_position), b])
	by_d.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for e: Array in by_d:
		if dancers.size() >= want:
			break
		var b := e[1] as TownspersonBot
		var was_home := b.hidden_inside
		var sc := V7aKit.ScriptController.new()
		sc.original = b.controller
		sc.tag = "dance"
		sc.speed = 1.6
		var spot := dance_spot(dancers.size())
		sc.target = spot
		sc.face_to = at(Vector3(-st.hall_size.x * 0.5 + 1.1, 1.0, -0.6))
		b.set_controller(sc)
		# Guests "arrive" at the door (also ones coming out of their homes at
		# night) and walk in through the door gap to the dance floor.
		if was_home or not _inside(b.global_position):
			b.global_position = at(Vector3(0, 0.25, st.hall_size.z * 0.5 + 1.0))
		var top := b.visual.top_style if b.visual else ""
		dancers.append({"bot": b, "sc": sc, "spot": spot, "top": top, "phase": _rng.randf() * TAU})
		_dress(b)
		added += 1
	return added


## Modest, stylish evening wear: anything not on the allowed list becomes `dress_up`.
func _dress(b: TownspersonBot) -> void:
	var st := style()
	if b.visual == null or st == null:
		return
	if not (b.visual.top_style in st.dress_tops):
		b.visual.set_top_style(st.dress_up)


func outfit_ok(b: TownspersonBot) -> bool:
	var st := style()
	return b.visual != null and st != null and b.visual.top_style in st.dress_tops


func send_home() -> void:
	for dd: Dictionary in dancers:
		var b := dd["bot"] as TownspersonBot
		if not is_instance_valid(b):
			continue
		if b.visual:
			b.visual.position.y = 0.0
			if str(dd["top"]) != "":
				b.visual.set_top_style(str(dd["top"]))
		if b.controller == dd["sc"]:
			b.set_controller(V7bKit.original_of(dd["sc"]))
	dancers.clear()


static func _flat_d(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z))


func dancing_count() -> int:
	var n := 0
	for dd: Dictionary in dancers:
		var b := dd["bot"] as TownspersonBot
		if is_instance_valid(b) and _flat_d(b.global_position, dd["spot"]) < 1.2:
			n += 1
	return n


func _process(delta: float) -> void:
	if hall == null:
		return
	_t += delta
	var on := disco_on()
	var open := is_open()
	var night := 0.0
	var nl := get_tree().get_first_node_in_group(&"night_lights_controller")
	if nl:
		night = float(nl.get(&"amount"))
	# Roof hides while you are inside (like the town buildings).
	if roof:
		roof.visible = not player_inside()
	if glow:
		glow.light_energy = (1.6 if open else 0.0) * maxf(night, 0.5 if player_inside() else 0.0)
	for i in tiles.size():
		tiles[i].emission_energy_multiplier = (1.2 + 1.6 * maxf(sin(_t * 3.2 + i * 1.7), 0.0)) if on else 0.15
	for k in spots.size():
		var s := spots[k]
		s.light_energy = 3.0 if on else 0.0
		s.rotation = Vector3(-PI * 0.5 + 0.55 * sin(_t * 0.9 + k * 2.0), _t * (0.7 + k * 0.25), 0)
	if ball:
		ball.rotation.y = _t * 0.8
	if music:
		if on and music.stream and not music.playing:
			music.play()
		elif not on and music.playing:
			music.stop()
	# Dancers: talk pose (arm gestures) + sway + a little bounce to the beat.
	for dd: Dictionary in dancers:
		var b := dd["bot"] as TownspersonBot
		if not is_instance_valid(b) or b.controller != dd["sc"]:
			continue
		var sc := dd["sc"] as V7aKit.ScriptController
		var close := _flat_d(b.global_position, dd["spot"]) < 1.0
		if close and on:
			sc.pose = &"talk"
			var ph := float(dd["phase"])
			var c: Vector3 = dd["spot"]
			sc.face_to = c + Vector3(sin(_t * 1.6 + ph), 0, cos(_t * 1.6 + ph)) * 3.0
			if b.visual:
				b.visual.position.y = absf(sin(_t * 4.2 + ph)) * 0.07
		elif b.visual:
			b.visual.position.y = 0.0
	if not auto:
		return
	_crowd_t -= delta
	if _crowd_t <= 0.0:
		_crowd_t = 5.0
		if on and dancers.size() < style().crowd:
			fill_crowd()
		elif not on and not dancers.is_empty():
			send_home()
