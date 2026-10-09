class_name CityHallInterior
extends Node3D
## v7b.1 "city_hall_interior" module: the city fund lives INSIDE City Hall.
##  - the outdoor fund board moves onto the back wall inside (still the
##    CityFund.board, E opens the fund panel) and the fund line on the square's
##    price board is removed;
##  - a service counter with two clerks, the manager's desk (talk to the
##    manager = the fund panel), a queue rope, plants and a portrait frame;
##  - F4 (city fund panel) only works while you are inside City Hall;
##  - the furniture is a separate node ("CityHallInteriorProps") built the
##    first time the player walks in (or ensure_built()), so the perf
##    streaming layer can drop / rebuild it with the rest of the interior.
## Staff: the module's `staff` list = [manager, clerk, clerk]; a private
## Staffing instance keeps them at their posts in office hours (stand-ins
## only come from the other City Hall staff first).

const HOURS := Vector2(8.0, 16.0)

var building: Building
var props: Node3D
var staffing: Staffing
var fund: CityFund
var manager_zone: Interactable
var built_count: int = 0


static func style() -> CityHallInteriorStyle:
	return Modules.style("city_hall_interior") as CityHallInteriorStyle


static func active() -> bool:
	var st := style()
	return st != null and st.enabled


## Called by CityFund before attaching the fund strip to the square's price board.
static func hide_price_strip() -> bool:
	var st := style()
	return st != null and st.enabled and st.hide_price_strip


## Called by CityFund on F4: false = only inside City Hall and the player is outside.
static func f4_allowed(tree: SceneTree) -> bool:
	var st := style()
	if st == null or not st.enabled or not st.f4_only_inside:
		return true
	return player_inside(tree)


static func city_hall(tree: SceneTree) -> Building:
	for n in tree.get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b and b.layout_id == "city_hall":
			return b
	return null


static func player_inside(tree: SceneTree) -> bool:
	var b := city_hall(tree)
	if b == null:
		return false
	if b.player_inside:
		return true
	var p := tree.get_first_node_in_group(&"player") as Node3D
	return p != null and b.is_point_inside(p.global_position)


func setup(b: Building, f: CityFund) -> void:
	building = b
	fund = f
	name = "CityHallInterior"
	staffing = Staffing.new()
	staffing.name = "CityHallStaffing"
	add_child(staffing)
	if building:
		building.player_entered.connect(func(_b: Building) -> void: ensure_built.call_deferred())
	_move_board.call_deferred()
	_setup_posts()


## Local (building space) -> world.
func at(local: Vector3) -> Vector3:
	return building.global_transform * Vector3(local.x, building.floor_y() + local.y, local.z) if building else local


func _dims() -> Vector2:
	return Vector2(building.size.x - 0.4, building.size.z - 0.4)


## The outdoor board -> back wall inside (keeps CityFund.board / board_label).
func _move_board() -> void:
	var st := style()
	if fund == null or not is_instance_valid(fund.board) or building == null or st == null or not st.enabled or not st.hide_outdoor_board:
		return
	var d := _dims()
	var b := fund.board
	b.reparent(building, false)
	b.position = Vector3(0, building.floor_y(), -d.y * 0.5 + 0.22)
	b.rotation = Vector3.ZERO
	b.scale = Vector3.ONE * 0.92
	b.set_meta(&"inside_city_hall", true)
	b.add_to_group(&"city_hall_interior")
	if fund.price_strip and is_instance_valid(fund.price_strip):
		fund.price_strip.queue_free()
		fund.price_strip = null


func _setup_posts() -> void:
	var st := style()
	if building == null or st == null or not st.enabled:
		return
	var staff: Array = st.staff
	if staff.is_empty():
		return
	var d := _dims()
	var spots := [
		[Vector3(-d.x * 0.25, 0, -d.y * 0.5 + 2.0), Vector3(-d.x * 0.25, 0, d.y * 0.5)],     # manager behind the left desk
		[Vector3(-0.8, 0, -1.05), Vector3(-0.8, 0, 2.0)],                                     # counter clerk 1
		[Vector3(0.8, 0, -1.05), Vector3(0.8, 0, 2.0)],                                       # counter clerk 2
	]
	var roles := ["city_manager", "city_clerk_1", "city_clerk_2"]
	for i in mini(staff.size(), 3):
		var pref: Array = [staff[i]]
		for j in staff.size():
			if j != i:
				pref.append(staff[j])
		staffing.add_post(roles[i], pref, at(spots[i][0]), at(spots[i][1]), HOURS)


func ensure_built() -> void:
	if is_instance_valid(props) or building == null:
		return
	var st := style()
	if st == null or not st.enabled:
		return
	built_count += 1
	props = Node3D.new()
	props.name = "CityHallInteriorProps"
	props.add_to_group(&"city_hall_interior")
	props.set_meta(&"streamable_interior", "city_hall")
	building.add_child(props)
	props.position = Vector3(0, building.floor_y(), 0)
	var d := _dims()
	var wood := V7aKit.mat(Color(0.42, 0.27, 0.15), 0.6)
	var top := V7aKit.mat(Color(0.86, 0.84, 0.78), 0.35)
	var brass := V7aKit.mat(Color(0.8, 0.65, 0.3), 0.3)
	# Service counter (front of the clerks), glass partition, number display.
	var counter := Node3D.new()
	counter.name = "ServiceCounter"
	props.add_child(counter)
	V7aKit.box(counter, Vector3(3.4, 1.05, 0.6), Vector3(0, 0.525, -0.35), wood)
	V7aKit.box(counter, Vector3(3.5, 0.05, 0.72), Vector3(0, 1.075, -0.35), top)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.75, 0.88, 0.95, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	V7aKit.box(counter, Vector3(3.4, 0.6, 0.02), Vector3(0, 1.4, -0.5), glass, false)
	for x in [-1.7, 0.0, 1.7]:
		V7aKit.box(counter, Vector3(0.04, 0.62, 0.04), Vector3(x, 1.4, -0.5), brass)
	var sign := Label3D.new()
	Lang.setup_label3d(sign, 40)
	sign.name = "CounterSign"
	sign.text = Lang.tt("پیشخوان خدمات شهری", "City services counter")
	sign.pixel_size = 0.004
	sign.modulate = Color(1, 0.96, 0.85)
	sign.outline_size = 6
	sign.position = Vector3(0, 1.85, -0.5)
	counter.add_child(sign)
	V7aKit.box(counter, Vector3(1.7, 0.26, 0.05), Vector3(0, 1.85, -0.53), V7aKit.mat(Color(0.12, 0.25, 0.4), 0.5))
	# Queue posts + rope.
	for x in [-1.2, 1.2]:
		V7aKit.cyl(counter, 0.04, 0.95, Vector3(x, 0.475, 1.0), brass)
	V7aKit.box(counter, Vector3(2.4, 0.04, 0.04), Vector3(0, 0.85, 1.0), V7aKit.mat(Color(0.6, 0.1, 0.12), 0.6))
	# Manager desk (bigger, nameplate, leather chair) over the left back desk area.
	var mgr := Node3D.new()
	mgr.name = "ManagerDesk"
	props.add_child(mgr)
	var mx := -d.x * 0.25
	var mz := -d.y * 0.5 + 1.25
	V7aKit.box(mgr, Vector3(1.9, 0.08, 0.95), Vector3(mx, 0.8, mz + 0.05), V7aKit.mat(Color(0.3, 0.18, 0.1), 0.45))
	V7aKit.box(mgr, Vector3(1.8, 0.76, 0.06), Vector3(mx, 0.38, mz + 0.48), V7aKit.mat(Color(0.3, 0.18, 0.1), 0.45))
	V7aKit.box(mgr, Vector3(0.5, 0.12, 0.08), Vector3(mx, 0.9, mz + 0.45), brass)
	var plate := Label3D.new()
	Lang.setup_label3d(plate, 28)
	plate.name = "ManagerPlate"
	var mname := ""
	var st2 := style()
	if st2 and not st2.staff.is_empty():
		mname = str(st2.staff[0])
	var mr := Population.by_name(mname.get_slice(" ", 0)) if mname != "" else {}
	plate.text = Lang.tt("مدیر شهرداری", "City Hall manager") + ("\n" + Dialogue.name_of(mr) if not mr.is_empty() else "")
	plate.pixel_size = 0.0022
	plate.modulate = Color(0.15, 0.1, 0.05)
	plate.outline_size = 0
	plate.position = Vector3(mx, 0.9, mz + 0.5)
	mgr.add_child(plate)
	# A portrait frame and a flag behind the manager.
	V7aKit.box(mgr, Vector3(0.7, 0.9, 0.04), Vector3(mx, 2.2, -d.y * 0.5 + 0.06), brass)
	V7aKit.box(mgr, Vector3(0.6, 0.8, 0.05), Vector3(mx, 2.2, -d.y * 0.5 + 0.07), V7aKit.mat(Color(0.35, 0.45, 0.4), 0.8))
	# Plants in the corners.
	for sx in [-1.0, 1.0]:
		V7aKit.cyl(props, 0.22, 0.45, Vector3(sx * (d.x * 0.5 - 0.5), 0.225, d.y * 0.5 - 1.6), V7aKit.mat(Color(0.65, 0.4, 0.25)))
		var leaf := V7aKit.ball(props, 0.35, Vector3(sx * (d.x * 0.5 - 0.5), 0.8, d.y * 0.5 - 1.6), V7aKit.mat(Color(0.22, 0.45, 0.22)))
		leaf.scale = Vector3(1, 1.4, 1)
	# Talk to the manager: the city fund panel.
	manager_zone = Interactable.new()
	manager_zone.name = "ManagerTalk"
	manager_zone.collision_layer = 8
	manager_zone.collision_mask = 2
	manager_zone.position = Vector3(mx, 0.9, mz + 1.1)
	manager_zone.action_text = Lang.tt("با مدیر شهرداری درباره‌ی صندوق شهر صحبت کن", "talk to the manager about the city fund")
	var zs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.1
	zs.shape = sp
	manager_zone.add_child(zs)
	props.add_child(manager_zone)
	manager_zone.interacted.connect(func(_w: Node3D) -> void:
		if fund and fund.panel:
			fund.panel.open())


## Drop the furniture again (perf streaming may call this when far away).
func unload() -> void:
	if is_instance_valid(props):
		props.queue_free()
	props = null


## Fund line on the inside board is visible?
func fund_visible_inside() -> bool:
	return fund != null and is_instance_valid(fund.board) and fund.board.get_parent() == building
