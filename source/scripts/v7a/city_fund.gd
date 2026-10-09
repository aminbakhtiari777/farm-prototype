class_name CityFund
extends Node3D
## v7a "city_fund" module: the visible city economy.
##  - Fines go to the municipality fund (CityState): fruit theft (v6b reports),
##    fires + damages (FireService), speeding in town (driving a car too fast).
##  - A notice board by City Hall shows the balance; E (or F4) opens the City
##    Hall panel with income, spending, the ledger and the public works.
##  - The fund pays for public works that appear in town over the following
##    days (benches, streetlights, flower beds, a small park) and the doctor
##    subsidy (Needs). The market prices board shows the fund too.

var board: Node3D
var board_label: Label3D
var price_strip: Label3D
var panel: CityFundPanel
var built: Dictionary = {}   ## project id -> Node3D
var speeding_fines: int = 0
## v7b.1 traffic: false = per-street limits + cameras (TrafficRules) do the speed checks.
var speed_check: bool = true
var theft_fines: int = 0
var _speed_t: float = 0.0
var _last_speed_fine: float = -999.0
var _seen_reports: int = 0
var _timer: float = 0.0


func style() -> CityFundStyle:
	return Modules.style("city_fund") as CityFundStyle


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	panel = CityFundPanel.new()
	panel.theme = V6bWorld.ui_theme()
	layer.add_child(panel)
	_build_board()
	_seen_reports = WorldMemory.reports.size()
	WorldMemory.changed.connect(_on_memory)
	CityState.changed.connect(func(_k: String) -> void: _refresh())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language":
			_refresh())
	_attach_price_strip.call_deferred()
	_refresh.call_deferred()
	Modules.on_swap("city_fund", self, func(_m: Resource) -> void:
		for id in built.keys():
			(built[id] as Node3D).queue_free()
		built.clear()
		_refresh())


# ------------------------------------------------------------------ board
func _build_board() -> void:
	board = Node3D.new()
	board.name = "CityFundBoard"
	add_child(board)
	var p := Vector2(9.2, -58.6)
	board.position = V7aKit.ground(p.x, p.y)
	board.rotation.y = deg_to_rad(-30.0)
	var wood := V7aKit.mat(Color(0.35, 0.24, 0.15))
	for sx in [-0.95, 0.95]:
		V7aKit.box(board, Vector3(0.1, 2.3, 0.1), Vector3(sx, 1.15, 0), wood)
	V7aKit.box(board, Vector3(2.1, 1.2, 0.08), Vector3(0, 1.55, 0), Color(0.15, 0.32, 0.4))
	V7aKit.box(board, Vector3(2.3, 0.1, 0.25), Vector3(0, 2.2, 0.03), wood)
	board_label = Label3D.new()
	Lang.setup_label3d(board_label, 34)
	board_label.pixel_size = 0.004
	board_label.width = 480.0
	board_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board_label.outline_size = 0
	board_label.modulate = Color(0.98, 0.95, 0.85)
	board_label.position = Vector3(0, 1.58, 0.05)
	board.add_child(board_label)
	var zone := Interactable.new()
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.position = Vector3(0, 0.9, 0.9)
	zone.action_text = "read the city fund board"
	var zs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.6
	zs.shape = sp
	zone.add_child(zs)
	board.add_child(zone)
	zone.interacted.connect(func(_w: Node3D) -> void: panel.open())


func _attach_price_strip() -> void:
	if not is_inside_tree() or CityHallInterior.hide_price_strip():  # v7b.1: fund shown inside City Hall only
		return
	var pb := get_tree().get_first_node_in_group(&"price_board") as Node3D
	if pb == null:
		return
	if is_instance_valid(price_strip) and price_strip.get_parent() == pb and not price_strip.is_queued_for_deletion():
		return
	price_strip = Label3D.new()
	price_strip.name = "CityFundStrip"
	Lang.setup_label3d(price_strip, 30)
	price_strip.pixel_size = 0.0042
	price_strip.outline_size = 8
	price_strip.modulate = Color(1.0, 0.92, 0.55)
	price_strip.position = Vector3(0, 3.42, 0.08)
	pb.add_child(price_strip)
	price_strip.text = fund_line()


func fund_line() -> String:
	return Lang.tt("صندوق شهرداری: %s سکه · جریمه‌ها: %s" % [Lang.digits(str(CityState.fund)), Lang.digits(str(CityState.fines_total))],
			"City fund: %d G · fines: %d G" % [CityState.fund, CityState.fines_total])


func _refresh() -> void:
	if board_label:
		var lines: PackedStringArray = [Lang.tt("صندوق شهرداری", "City fund"), Lang.tt("%s سکه" % Lang.digits(str(CityState.fund)), "%d G" % CityState.fund)]
		var next := next_project()
		if not next.is_empty():
			lines.append(Lang.tt("کار بعدی: %s (%s سکه)" % [str(next.get("fa", "")), Lang.digits(str(int(next.get("cost", 0))))],
					"Next: %s (%d G)" % [str(next.get("en", "")), int(next.get("cost", 0))]))
		lines.append(Lang.tt("E: جزئیات (F4)", "E: details (F4)"))
		board_label.text = "\n".join(lines)
	# The prices board rebuilds its children on a module swap: re-attach.
	if not is_instance_valid(price_strip) or price_strip.is_queued_for_deletion() or not price_strip.is_inside_tree():
		price_strip = null
		_attach_price_strip()
	if price_strip:
		price_strip.text = fund_line()
	_sync_projects()
	if panel and panel.visible:
		panel.refresh()


func next_project() -> Dictionary:
	var st := style()
	if st == null:
		return {}
	for p: Dictionary in st.projects:
		if CityState.project_state(str(p.get("id", ""))) == "planned":
			return p
	return {}


# ------------------------------------------------------------------ fines
func _on_memory(kind: String) -> void:
	if kind != "reports" and kind != "all":
		return
	if kind == "all":
		_seen_reports = WorldMemory.reports.size()
		return
	while _seen_reports < WorldMemory.reports.size():
		var r: Dictionary = WorldMemory.reports[_seen_reports]
		_seen_reports += 1
		if str(r.get("kind", "")) == "fruit_theft" and str(r.get("who", "")) == "player" and int(r.get("fine", 0)) > 0:
			theft_fines += 1
			CityState.add_fine("theft", int(r["fine"]), "Fruit taken from a family orchard", "چیدن میوه از باغ مردم بدون اجازه")


func _process(delta: float) -> void:
	_timer -= delta
	var player := get_tree().get_first_node_in_group(&"player") as Player
	if speed_check and player and player.vehicle is DrivableCar:
		var car := player.vehicle as DrivableCar
		var st := style()
		var in_town := car.global_position.z < -30.0
		if st and in_town and absf(car.speed) > st.speed_limit:
			_speed_t += delta
			if _speed_t > 2.5 and Time.get_ticks_msec() / 1000.0 - _last_speed_fine > 60.0:
				fine_speeding(absf(car.speed))
		else:
			_speed_t = 0.0


func fine_speeding(speed_ms: float) -> void:
	var st := style()
	_last_speed_fine = Time.get_ticks_msec() / 1000.0
	_speed_t = 0.0
	speeding_fines += 1
	CityState.add_fine("speeding", st.speeding_fine if st else 50, "Speeding in town (%d km/h)" % int(speed_ms * 3.6),
			"سرعت غیرمجاز در شهر (%s کیلومتر)" % Lang.digits(str(int(speed_ms * 3.6))))
	WorldMemory.file_report("speeding", "player", "", st.speeding_fine if st else 50)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_pressed() and not event.is_echo() and event.is_action(&"city_panel"):
		if panel.visible:
			panel.close()
		elif not GameEvents.ui_open and not CityHallInterior.f4_allowed(get_tree()):
			# v7b.1: the city fund lives inside City Hall.
			GameEvents.notification_requested.emit(Lang.tt("صندوق شهر را داخل شهرداری ببین (F4 فقط داخل شهرداری).", "See the city fund inside City Hall (F4 works inside only)."))
		elif not GameEvents.ui_open:
			panel.open()
		get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ public works
func _sync_projects() -> void:
	var st := style()
	if st == null:
		return
	for p: Dictionary in st.projects:
		var id := str(p.get("id", ""))
		var state := CityState.project_state(id)
		var have: Node3D = built.get(id, null)
		var want := state if state != "planned" else ""
		if have and str(have.get_meta(&"state", "")) == want:
			continue
		if have:
			have.queue_free()
			built.erase(id)
		if want == "":
			continue
		var n := Node3D.new()
		n.name = "Work_" + id
		n.set_meta(&"state", want)
		add_child(n)
		built[id] = n
		for v: Vector2 in p.get("pos", []):
			var g := V7aKit.ground(v.x, v.y)
			if want == "building":
				_cones(n, g)
			else:
				match str(p.get("kind", "")):
					"bench":
						_bench(n, g, _face_road(v))
					"streetlight":
						_streetlight(n, g)
					"flowerbed":
						_flowerbed(n, g)
					"park":
						_park(n, g)


func _face_road(v: Vector2) -> float:
	# Main St runs along z = -50: benches north of it face south and vice versa.
	return 0.0 if v.y < -50.0 else PI


func _cones(n: Node3D, g: Vector3) -> void:
	var orange := V7aKit.mat(Color(1.0, 0.45, 0.05))
	for k in 4:
		var a := TAU * k / 4.0
		V7aKit.cyl(n, 0.16, 0.5, g + Vector3(cos(a) * 0.9, 0.25, sin(a) * 0.9), orange, 0.02)
	var l := Label3D.new()
	Lang.setup_label3d(l, 32)
	l.text = Lang.tt("شهرداری - در حال ساخت", "City works - under way")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color(1.0, 0.8, 0.3)
	l.position = g + Vector3(0, 1.4, 0)
	n.add_child(l)


func _bench(n: Node3D, g: Vector3, yaw: float) -> void:
	var holder := Node3D.new()
	holder.position = g
	holder.rotation.y = yaw
	n.add_child(holder)
	var wood := V7aKit.mat(Color(0.62, 0.4, 0.22))
	var iron := V7aKit.mat(Color(0.13, 0.13, 0.14), 0.5)
	for k in 3:
		V7aKit.box(holder, Vector3(1.6, 0.04, 0.11), Vector3(0, 0.46, -0.12 + k * 0.13), wood)
	for k in 2:
		V7aKit.box(holder, Vector3(1.6, 0.11, 0.035), Vector3(0, 0.66 + k * 0.17, -0.24), wood)
	for sx in [-0.7, 0.7]:
		V7aKit.box(holder, Vector3(0.06, 0.46, 0.45), Vector3(sx, 0.23, 0), iron)
	var seat := Seat.new()
	seat.display_name = "bench"
	seat.position = Vector3(0, 0, 0.05)
	holder.add_child(seat)


func _streetlight(n: Node3D, g: Vector3) -> void:
	var iron := V7aKit.mat(Color(0.18, 0.2, 0.22), 0.4)
	V7aKit.cyl(n, 0.07, 4.2, g + Vector3(0, 2.1, 0), iron, 0.05)
	V7aKit.box(n, Vector3(0.08, 0.08, 0.9), g + Vector3(0, 4.15, -0.4), iron)
	V7aKit.box(n, Vector3(0.36, 0.1, 0.5), g + Vector3(0, 4.08, -0.85), StreetLamp.lantern_material())
	var pool := get_tree().current_scene.find_child("LampLights", true, false) as LampLightPool
	if pool:
		pool.lamp_positions.append(g + Vector3(0, 3.9, -0.85))


func _flowerbed(n: Node3D, g: Vector3) -> void:
	var stone := V7aKit.mat(Color(0.7, 0.66, 0.58))
	V7aKit.box(n, Vector3(3.0, 0.3, 1.4), g + Vector3(0, 0.15, 0), stone)
	V7aKit.box(n, Vector3(2.8, 0.06, 1.2), g + Vector3(0, 0.3, 0), Color(0.28, 0.2, 0.13))
	var cols := [Color(0.92, 0.25, 0.3), Color(0.98, 0.82, 0.25), Color(0.7, 0.4, 0.88), Color(1, 1, 1), Color(1.0, 0.5, 0.2)]
	for i in 22:
		var x := -1.25 + (i % 11) * 0.25
		var z := -0.35 if i < 11 else 0.35
		V7aKit.cyl(n, 0.015, 0.25, g + Vector3(x, 0.42, z), Color(0.2, 0.45, 0.15))
		V7aKit.ball(n, 0.08, g + Vector3(x, 0.58, z), V7aKit.mat(cols[i % cols.size()], 0.6))


func _park(n: Node3D, g: Vector3) -> void:
	var lawn := V7aKit.mat(Color(0.3, 0.55, 0.22))
	V7aKit.box(n, Vector3(7.0, 0.08, 5.6), g + Vector3(0, 0.04, 0), lawn, false)
	var path := V7aKit.mat(Color(0.8, 0.74, 0.62))
	V7aKit.box(n, Vector3(1.0, 0.09, 5.6), g + Vector3(0, 0.05, 0), path, false)
	var fence := V7aKit.mat(Color(0.95, 0.95, 0.92))
	for sx in [-3.5, 3.5]:
		V7aKit.box(n, Vector3(0.06, 0.5, 5.6), g + Vector3(sx, 0.25, 0), fence)
	for i in 3:
		var tp := g + Vector3(-2.3 + i * 2.3 if i != 1 else 2.4, 0, -1.8 if i != 1 else 1.6)
		V7aKit.cyl(n, 0.12, 1.6, tp + Vector3(0, 0.8, 0), Color(0.4, 0.27, 0.15))
		V7aKit.ball(n, 0.9, tp + Vector3(0, 2.1, 0), V7aKit.mat(Color(0.22, 0.48, 0.2)))
	# Slide: ladder, platform, chute.
	var red := V7aKit.mat(Color(0.85, 0.2, 0.15), 0.4)
	var yel := V7aKit.mat(Color(0.98, 0.78, 0.15), 0.4)
	var sp := g + Vector3(-2.2, 0, 1.4)
	for sx in [-0.3, 0.3]:
		V7aKit.box(n, Vector3(0.06, 1.5, 0.06), sp + Vector3(sx, 0.75, -0.5), red)
	for k in 4:
		V7aKit.box(n, Vector3(0.6, 0.04, 0.05), sp + Vector3(0, 0.3 + k * 0.35, -0.5), red)
	V7aKit.box(n, Vector3(0.7, 0.06, 0.6), sp + Vector3(0, 1.5, -0.2), red)
	var chute := V7aKit.box(n, Vector3(0.6, 0.05, 2.0), sp + Vector3(0, 0.82, 0.75), yel)
	chute.rotation.x = 0.68
	_bench(n, g + Vector3(2.0, 0, 2.2), PI)
	var l := Label3D.new()
	Lang.setup_label3d(l, 36)
	l.text = Lang.tt("پارک کوچک شهر", "Town pocket park")
	l.pixel_size = 0.005
	l.outline_size = 8
	l.modulate = Color(0.95, 1.0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position = g + Vector3(0, 2.0, -2.8)
	n.add_child(l)
