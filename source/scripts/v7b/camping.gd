class_name Camping
extends Node3D
## v7b "camping" module: drive out to the pine forest or the lookout hill,
## press 6 at the camp spot to pitch a tent and light a campfire (firewood
## from your bag, or buy a bundle), E at the tent sleeps under the stars
## until morning (full rest = healthy life). 6 again packs everything up.
## The camp (spot) is saved.

var camp: Node3D
var tent_spot: ActionSpot
var fire_light: OmniLight3D
var markers: Array[Node3D] = []
var _rng := RandomNumberGenerator.new()


func style() -> CampingStyle:
	return Modules.style("camping") as CampingStyle


func _ready() -> void:
	_rng.randomize()
	rebuild()
	Modules.on_swap("camping", self, func(_m: Resource) -> void: rebuild())
	TownLife.changed.connect(func(k: String) -> void:
		if k == "all":
			_sync())


func spot_pos(s: Dictionary) -> Vector3:
	var p: Vector2 = s.get("pos", Vector2.ZERO)
	return V7aKit.ground(p.x, p.y)


func spot(id: String) -> Dictionary:
	var st := style()
	if st:
		for s: Dictionary in st.spots:
			if str(s.get("id", "")) == id:
				return s
	return {}


func rebuild() -> void:
	for m in markers:
		m.queue_free()
	markers.clear()
	var st := style()
	if st == null:
		return
	for s: Dictionary in st.spots:
		var p: Vector2 = s["pos"]
		V7bKit.clear_trees(get_tree(), Rect2(p - Vector2(5.5, 5.5), Vector2(11.0, 11.0)))
		var m := Node3D.new()
		m.name = "CampSpot_" + str(s["id"])
		add_child(m)
		m.global_position = spot_pos(s) + Vector3(-3.6, 0, -3.0)
		var post := V7aKit.box(m, Vector3(0.12, 1.3, 0.12), Vector3(0, 0.65, 0), V7aKit.mat(Color(0.4, 0.27, 0.15)))
		post.name = "Post"
		V7bKit.sign(m, Vector3(0, 1.0, 0), 0.6, str(s["fa"]) + " (۶)", str(s["en"]) + " (6)", Color(0.25, 0.4, 0.2), 2.2)
		markers.append(m)
	_sync()


func _sync() -> void:
	var id := str(TownLife.camps.get("spot", ""))
	if id == "":
		_remove_camp()
	elif camp == null or str(camp.get_meta("spot", "")) != id:
		_build_camp(spot(id))


func is_camped() -> bool:
	return camp != null


## The spot within reach of pos (or {}).
func near_spot(pos: Vector3) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	for s: Dictionary in st.spots:
		if V7aKit.flat(spot_pos(s)).distance_to(V7aKit.flat(pos)) <= st.radius:
			return s
	return {}


## Key 6.
func toggle(pos: Vector3) -> String:
	var st := style()
	if st == null:
		return "none"
	if camp and V7aKit.flat(camp.global_position).distance_to(V7aKit.flat(pos)) <= st.radius + 4.0:
		pack()
		return "packed"
	var s := near_spot(pos)
	if s.is_empty():
		GameEvents.notification_requested.emit(V7bKit.line(st.lines.get("too_far", [])))
		return "too_far"
	return setup(str(s["id"]))


func setup(id: String) -> String:
	var st := style()
	var s := spot(id)
	if st == null or s.is_empty():
		return "none"
	if Economy.count("firewood") > 0:
		Economy.remove_item("firewood", 1)
	elif st.firewood_cost > 0:
		if Economy.money < st.firewood_cost:
			GameEvents.notification_requested.emit(Lang.tt("هیزم نداری و پول خریدنش را هم نداری (%s سکه)." % Lang.digits(str(st.firewood_cost)), "No firewood and not enough money to buy some (%d G)." % st.firewood_cost))
			return "poor"
		Economy.add_money(-st.firewood_cost)
	TownLife.camps["spot"] = id
	TownLife.camps["trips"] = int(TownLife.camps.get("trips", 0)) + 1
	TownLife.count_event("camp")
	_build_camp(s)
	GameEvents.notification_requested.emit(V7bKit.line(st.lines.get("setup", [])))
	return "setup"


func pack() -> void:
	var st := style()
	TownLife.camps["spot"] = ""
	_remove_camp()
	if st:
		GameEvents.notification_requested.emit(V7bKit.line(st.lines.get("packed", [])))


func sleep() -> bool:
	var st := style()
	if camp == null or st == null:
		return false
	var p := V7bKit.player(get_tree())
	if p:
		p.restore_stamina(1000.0)
	Needs.begin_sleep()
	TimeManager.sleep_until_morning(6.0)
	Needs.end_sleep()
	Needs.fatigue = maxf(Needs.fatigue * (1.0 - st.rest_bonus), 0.0)
	TownLife.camps["nights"] = int(TownLife.camps.get("nights", 0)) + 1
	GameEvents.notification_requested.emit(V7bKit.line(st.lines.get("sleep", [])))
	return true


func _remove_camp() -> void:
	if camp:
		camp.queue_free()
	camp = null
	tent_spot = null
	fire_light = null


func _build_camp(s: Dictionary) -> void:
	_remove_camp()
	var st := style()
	if s.is_empty() or st == null:
		return
	camp = Node3D.new()
	camp.name = "Camp"
	camp.set_meta("spot", str(s["id"]))
	add_child(camp)
	camp.global_position = spot_pos(s)
	# Tent: two slanted cloth panels + floor + door flap.
	var tent := Node3D.new()
	tent.name = "Tent"
	tent.position = Vector3(2.4, 0, -1.2)
	tent.rotation.y = 0.5
	camp.add_child(tent)
	var cloth := V7aKit.mat(st.tent_color, 0.9)
	for sx: float in [-1.0, 1.0]:
		var pnl := V7aKit.box(tent, Vector3(0.06, 2.0, 2.6), Vector3(sx * 0.62, 0.78, 0), cloth)
		pnl.rotation.z = sx * 0.62
	V7aKit.box(tent, Vector3(2.0, 0.04, 2.6), Vector3(0, 0.02, 0), V7aKit.mat(st.tent_color.darkened(0.45)))
	var back := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(2.0, 1.6, 0.05)
	back.mesh = pm
	back.material_override = cloth
	back.position = Vector3(0, 0.8, -1.3)
	tent.add_child(back)
	V7aKit.box(tent, Vector3(0.08, 1.75, 0.08), Vector3(0, 0.87, 1.3), V7aKit.mat(Color(0.35, 0.25, 0.15)))
	tent_spot = ActionSpot.make(tent, Vector3(0, 0, 1.9), 1.6, func() -> String: return Lang.loc_ui("sleep in the tent"), func(_w: Node3D) -> void: sleep())
	tent_spot.name = "TentSpot"
	# Campfire: stones, logs, flames, light, crackle.
	var fire := Node3D.new()
	fire.name = "Campfire"
	camp.add_child(fire)
	for k in 8:
		var a := TAU * k / 8.0
		V7aKit.ball(fire, 0.2, Vector3(cos(a) * 0.65, 0.1, sin(a) * 0.65), Color(0.45, 0.44, 0.42))
	for k in 3:
		var lg := V7aKit.cyl(fire, 0.08, 0.9, Vector3(0, 0.12, 0), Color(0.35, 0.22, 0.12))
		lg.rotation = Vector3(PI * 0.5, k * TAU / 3.0, 0)
	var fl := V7aKit.particles("flame", 26, Vector3(0.22, 0.05, 0.22))
	fl.name = "Flames"
	fl.position.y = 0.2
	fl.scale = Vector3.ONE * 0.6
	fire.add_child(fl)
	fire_light = OmniLight3D.new()
	fire_light.name = "FireLight"
	fire_light.light_color = Color(1.0, 0.6, 0.25)
	fire_light.omni_range = 9.0
	fire_light.light_energy = 2.2
	fire_light.position.y = 0.9
	fire.add_child(fire_light)
	var au := AudioStreamPlayer3D.new()
	var path := "res://assets/audio/ambience/campfire_loop.ogg"
	if ResourceLoader.exists(path):
		var a2 := (load(path) as AudioStream).duplicate() as AudioStream
		if a2 is AudioStreamOggVorbis:
			(a2 as AudioStreamOggVorbis).loop = true
		au.stream = a2
	au.max_distance = 20.0
	au.volume_db = -6.0
	au.autoplay = true
	fire.add_child(au)
	# A log to sit on.
	var seat := Seat.new()
	seat.display_name = "log"
	seat.interact_radius = 0.9
	seat.position = Vector3(-1.6, 0, 0.4)
	seat.rotation.y = atan2(1.6, -0.4)
	seat.name = "CampLog"
	var lgm := V7aKit.cyl(seat, 0.2, 1.1, Vector3(0, 0.22, -0.12), Color(0.38, 0.25, 0.14))
	lgm.rotation = Vector3(0, 0, PI * 0.5)
	camp.add_child(seat)


func _process(_d: float) -> void:
	if fire_light:
		fire_light.light_energy = 2.0 + sin(Time.get_ticks_msec() * 0.013) * 0.25 + _rng.randf() * 0.2
