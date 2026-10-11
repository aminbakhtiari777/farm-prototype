class_name FishingBoat
extends Node3D
## One boat of the v6a boats module (see Boats). States: docked at the pier,
## sailing out, at sea (stand on deck and fish deep water), sailing back.

enum State { DOCKED, OUT, AT_SEA, BACK }

var index: int = 0
var island_trip: bool = false
var engine_running: bool = false
var engine_sound: AudioStreamPlayer3D
var owner_boats: Boats
var hull_color: Color = Color.WHITE
var has_cabin: bool = true
var mooring: Vector3
var mooring_yaw: float = 0.0
var sea_spot: Vector3
var board_point: Vector3
var state: State = State.DOCKED
var passenger: Node3D = null
var seat: Seat
var board_spot: ActionSpot
var helm_spot: ActionSpot
var _t: float = 0.0
var _dur: float = 6.0
var _hull: Node3D
var _bob: float = 0.0


func _ready() -> void:
	add_to_group(&"fishing_boats")
	engine_sound = AudioStreamPlayer3D.new()
	engine_sound.stream = load("res://assets/audio/boat_engine.ogg") if ResourceLoader.exists("res://assets/audio/boat_engine.ogg") else null
	if engine_sound.stream is AudioStreamOggVorbis:
		(engine_sound.stream as AudioStreamOggVorbis).loop = true
	engine_sound.volume_db = -22
	engine_sound.max_distance = 24
	engine_sound.unit_size = 2.0
	add_child(engine_sound)
	global_position = mooring
	rotation.y = mooring_yaw
	_build()
	board_spot = ActionSpot.make(get_parent(), board_point, 1.2, _board_text, func(_who: Node3D) -> void: TownGameplay.open_boat_menu(), func() -> bool: return is_instance_valid(self) and state == State.DOCKED)
	board_spot.name = "BoardBoat%d" % index


func _exit_tree() -> void:
	# The boarding spot lives on the pier (sibling node): remove it with the boat.
	if is_instance_valid(board_spot):
		board_spot.queue_free()
	board_spot = null


static func hull_mesh(color: Color) -> ArrayMesh:
	# Outline (x, z) from stern to bow, mirrored.
	var outline := [Vector2(0.95, -2.5), Vector2(1.1, -1.2), Vector2(1.12, 0.4), Vector2(0.9, 1.6), Vector2(0.45, 2.4), Vector2(0.0, 2.85)]
	var pts: Array[Vector2] = []
	for p in outline:
		pts.append(p)
	for i in range(outline.size() - 2, -1, -1):
		pts.append(Vector2(-outline[i].x, outline[i].y))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top := 0.55
	var bot := -0.55
	var stripe := color.darkened(0.45)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var a2 := Vector2(a.x * 0.35, a.y * 0.85)
		var b2 := Vector2(b.x * 0.35, b.y * 0.85)
		# upper side (hull colour) and lower side (anti-fouling red/dark)
		var am := Vector3(a.x * 0.8, -0.05, a.y * 0.95)
		var bm := Vector3(b.x * 0.8, -0.05, b.y * 0.95)
		for tri in [[Vector3(a.x, top, a.y), Vector3(b.x, top, b.y), bm, color], [Vector3(a.x, top, a.y), bm, am, color],
				[am, bm, Vector3(b2.x, bot, b2.y), stripe], [am, Vector3(b2.x, bot, b2.y), Vector3(a2.x, bot, a2.y), stripe]]:
			st.set_color(tri[3]); st.add_vertex(tri[0])
			st.set_color(tri[3]); st.add_vertex(tri[1])
			st.set_color(tri[3]); st.add_vertex(tri[2])
	# Deck (wood) a bit below the gunwale.
	var deck := Color(0.62, 0.47, 0.3)
	for i in n:
		var a := pts[i] * 0.93
		var b := pts[(i + 1) % n] * 0.93
		st.set_color(deck); st.add_vertex(Vector3(0, 0.12, 0))
		st.set_color(deck); st.add_vertex(Vector3(b.x, 0.12, b.y))
		st.set_color(deck); st.add_vertex(Vector3(a.x, 0.12, a.y))
	# Gunwale cap
	var cap := Color(0.95, 0.95, 0.92)
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var ai := a * 0.92
		var bi := b * 0.92
		st.set_color(cap); st.add_vertex(Vector3(a.x, top + 0.04, a.y))
		st.set_color(cap); st.add_vertex(Vector3(ai.x, top + 0.04, ai.y))
		st.set_color(cap); st.add_vertex(Vector3(b.x, top + 0.04, b.y))
		st.set_color(cap); st.add_vertex(Vector3(b.x, top + 0.04, b.y))
		st.set_color(cap); st.add_vertex(Vector3(ai.x, top + 0.04, ai.y))
		st.set_color(cap); st.add_vertex(Vector3(bi.x, top + 0.04, bi.y))
	st.generate_normals()
	return st.commit()


func _build() -> void:
	_hull = Node3D.new()
	_hull.name = "Hull"
	add_child(_hull)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mi := MeshInstance3D.new()
	mi.mesh = hull_mesh(hull_color)
	mi.material_override = mat
	_hull.add_child(mi)
	var white := ProceduralProp.color_material(Color(0.95, 0.95, 0.93), 0.5, false)
	var glass := ProceduralProp.color_material(Color(0.2, 0.3, 0.38), 0.15, false)
	if has_cabin:
		_box(_hull, Vector3(1.3, 1.15, 1.3), Vector3(0, 0.7, 0.35), white)
		_box(_hull, Vector3(1.45, 0.08, 1.5), Vector3(0, 1.32, 0.35), ProceduralProp.color_material(hull_color.darkened(0.2), 0.5, false))
		_box(_hull, Vector3(1.32, 0.4, 0.04), Vector3(0, 0.95, 1.0), glass)
		_box(_hull, Vector3(0.04, 0.35, 0.8), Vector3(0.66, 0.95, 0.35), glass)
		_box(_hull, Vector3(0.04, 0.35, 0.8), Vector3(-0.66, 0.95, 0.35), glass)
		_box(_hull, Vector3(0.05, 1.6, 0.05), Vector3(0, 2.1, 0.35), white)
	# Name on the stern (Persian/English).
	var lbl := Label3D.new()
	lbl.text = ["مروارید", "دریادل", "ستاره", "نسیم"][index % 4]
	Lang.setup_label3d(lbl)
	lbl.font_size = 40
	lbl.pixel_size = 0.006
	lbl.position = Vector3(0, 0.35, -2.52)
	lbl.rotation.y = PI
	lbl.modulate = hull_color.darkened(0.6) if hull_color.get_luminance() > 0.5 else Color.WHITE
	_hull.add_child(lbl)
	# Colliders: deck + rails (high enough that you can't hop overboard) + cabin.
	var body := StaticBody3D.new()
	body.name = "BoatBody"
	add_child(body)
	_col(body, Vector3(2.0, 0.2, 5.0), Vector3(0, 0.02, 0.1))
	_col(body, Vector3(0.12, 1.6, 4.6), Vector3(1.05, 0.9, 0.0))
	_col(body, Vector3(0.12, 1.6, 4.6), Vector3(-1.05, 0.9, 0.0))
	_col(body, Vector3(2.0, 1.6, 0.12), Vector3(0, 0.9, -2.45))
	_col(body, Vector3(1.4, 1.6, 0.12), Vector3(0, 0.9, 2.3))
	if has_cabin:
		_col(body, Vector3(1.3, 1.2, 1.3), Vector3(0, 0.75, 0.35))
	seat = Seat.new()
	seat.display_name = "boat bench"
	seat.position = Vector3(0, 0.12, -1.6)
	seat.rotation.y = 0.0
	seat.interact_radius = 0.6
	seat.name = "BoatSeat"
	seat.set_meta(&"special", true)
	_box(seat, Vector3(1.6, 0.08, 0.4), Vector3(0, 0.42, -0.2), ProceduralProp.color_material(Color(0.5, 0.36, 0.22), 0.8, false))
	add_child(seat)
	seat.ready.connect(func() -> void: seat.zone.enabled = false, CONNECT_ONE_SHOT)
	helm_spot = ActionSpot.make(self, Vector3(0.6, 0.12, -0.6), 0.9, _helm_text, func(_who: Node3D) -> void: TownGameplay.open_boat_menu(), func() -> bool: return state == State.AT_SEA)
	helm_spot.name = "Helm"


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _col(body: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	cs.shape = b
	cs.position = pos
	body.add_child(cs)


func _board_text() -> String:
	var st := owner_boats.style() if owner_boats else null
	var fee := st.fuel_fee if st else 20
	return Lang.tt("سوار قایق شو و برای ماهیگیری به دریای عمیق برو (%s سکه سوخت)" % Lang.digits(str(fee)), "board the boat for deep-sea fishing (%d G fuel)" % fee)


func _helm_text() -> String:
	return Lang.tt("برگشت به اسکله", "sail back to the pier")


func can_sail() -> String:
	if TimeManager.weather_id == "storm":
		return Lang.tt("دریا طوفانی است - امروز قایق‌ها بیرون نمی‌روند.", "The sea is stormy - no boats go out today.")
	var st := owner_boats.style() if owner_boats else null
	var fee := st.fuel_fee if st else 20
	if Economy.money < fee:
		return Lang.tt("برای سوخت %s سکه لازم داری." % Lang.digits(str(fee)), "You need %d G for fuel." % fee)
	return ""


## E on the pier: pay fuel, sit in the boat and sail out.
func board(who: Node3D) -> bool:
	if state != State.DOCKED or who == null:
		return false
	if island_trip and not is_instance_valid(TownGameplay.island):
		TownGameplay._build_island()
	var why := can_sail()
	if why != "":
		GameEvents.notification_requested.emit(why)
		return false
	var st := owner_boats.style() if owner_boats else null
	Economy.add_money(-(st.fuel_fee if st else 20))
	passenger = who
	_seat_passenger()
	state = State.OUT
	engine_running = true
	if engine_sound.stream:
		engine_sound.play()
	_t = 0.0
	_dur = st.sail_seconds if st else 6.0
	Lifestyle.boat_trips += 1
	TimeManager.advance_minutes(30.0)
	if board_spot:
		board_spot.refresh()
	GameEvents.notification_requested.emit(Lang.tt("قایق به سمت آب‌های عمیق راه افتاد...", "The boat heads out to deep water..."))
	return true


## E at the helm (at sea): sail back to the pier.
func helm(who: Node3D) -> bool:
	if state != State.AT_SEA:
		return false
	passenger = who if who else passenger
	_seat_passenger()
	state = State.BACK
	engine_running = true
	if engine_sound.stream:
		engine_sound.play()
	_t = 0.0
	TimeManager.advance_minutes(30.0)
	helm_spot.refresh()
	return true


func _seat_passenger() -> void:
	if passenger == null:
		return
	if passenger.get("sitting_on") != seat:
		if passenger.has_method("stand_up"):
			passenger.call("stand_up")
		if seat.occupant:
			seat.release(seat.occupant)
		if passenger.has_method("sit_on"):
			passenger.call("sit_on", seat)
	passenger.global_position = seat.global_position


func _bezier(t: float, back: bool) -> Array:
	var p0 := mooring
	var p1 := mooring + Vector3(Boats.PIER_DIR.x, 0, Boats.PIER_DIR.y) * 14.0
	var p2 := TownGameplay.ISLAND_DOCK if island_trip else sea_spot
	if back:
		var tmp := p0
		p0 = p2
		p2 = tmp
	var a := p0.lerp(p1, t)
	var b := p1.lerp(p2, t)
	var pos := a.lerp(b, t)
	var tan := (b - a)
	return [pos, atan2(tan.x, tan.z)]


func _physics_process(delta: float) -> void:
	_bob += delta
	if _hull:
		_hull.position.y = sin(_bob * 1.3 + index) * 0.04
		_hull.rotation.z = sin(_bob * 0.9 + index * 2.0) * 0.025
	if state == State.OUT or state == State.BACK:
		_t = minf(_t + delta / maxf(_dur, 0.1), 1.0)
		var e := smoothstep(0.0, 1.0, _t)
		var r := _bezier(e, state == State.BACK)
		global_position = r[0]
		var yaw: float = r[1]
		if state == State.BACK and _t > 0.8:
			yaw = lerp_angle(yaw, mooring_yaw, (_t - 0.8) / 0.2)
		rotation.y = lerp_angle(rotation.y, yaw, minf(delta * 4.0, 1.0)) if _t < 0.999 else yaw
		if passenger:
			if passenger.get("sitting_on") != seat:
				_seat_passenger()
			passenger.global_position = seat.global_position
			var vis := passenger.get_node_or_null(^"Visual") as Node3D
			if vis:
				vis.rotation.y = seat.facing_yaw()
		if _t >= 1.0:
			_arrive()


func _arrive() -> void:
	engine_running = false
	if engine_sound:
		engine_sound.stop()
	if state == State.OUT:
		state = State.AT_SEA
		global_position = TownGameplay.ISLAND_DOCK if island_trip else sea_spot
		if passenger and passenger.has_method("stand_up"):
			passenger.call("stand_up")
			passenger.global_position = TownGameplay.ISLAND + Vector3(0, 1.3, -12) if island_trip else to_global(Vector3(0, 0.25, -0.6))
			passenger.reset_physics_interpolation()
		helm_spot.refresh()
		GameEvents.notification_requested.emit(Lang.tt("جزیرهٔ میوه؛ میوه بچین. کنار اسکله برای بازگشت E بزن.", "Fruit island; pick fruit. Use E at the landing to return.") if island_trip else Lang.tt("آب‌های عمیق؛ E برای قلاب، B برای تور و بازگشت.", "Deep water; E to fish, B for net and return."))
	elif state == State.BACK:
		state = State.DOCKED
		global_position = mooring
		rotation.y = mooring_yaw
		if passenger:
			if passenger.has_method("stand_up"):
				passenger.call("stand_up")
			passenger.global_position = board_point + Vector3(0, 0.2, 0)
		passenger = null
		if board_spot:
			board_spot.refresh()
		helm_spot.refresh()
		GameEvents.notification_requested.emit(Lang.tt("به اسکله برگشتی.", "Back at the pier."))


## Test helpers: jump straight to the end of the current voyage.
func finish_voyage() -> void:
	if state == State.OUT or state == State.BACK:
		_t = 1.0
		_arrive()
