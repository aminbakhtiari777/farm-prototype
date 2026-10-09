class_name SunbathingBeach
extends Node3D
## v6a "sunbathing" module: a separate sunbathing beach with towels and beach
## umbrellas. Anyone (player or townspeople, on sunny days around midday) can
## lie down on a towel (pose "lie"); resting in the sun restores stamina.

var towels: Array[Seat] = []
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"sunbathing")
	Modules.on_swap("sunbathing", self, func(_m: AssetModule) -> void: rebuild())
	rebuild()


func style() -> SunbathingStyle:
	return Modules.style("sunbathing") as SunbathingStyle


static func is_sunbathing_time() -> bool:
	var st := Modules.style("sunbathing") as SunbathingStyle
	if st == null:
		return false
	var h := TimeManager.hours_float()
	return h >= st.hours.x and h < st.hours.y and TimeManager.weather_id in st.weather and TimeManager.season_id() != "winter"


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	towels.clear()
	var st := style()
	if st == null:
		return
	var along := Vector2(0.7071, -0.7071)
	var sea := Vector2(0.7071, 0.7071)
	var yaw := atan2(sea.x, sea.y)
	var n := st.towels
	for k in n:
		var c := st.center + along * (k - (n - 1) * 0.5) * 2.3
		var feet := c + sea * 0.85
		var seat := Seat.new()
		seat.display_name = "towel"
		seat.interact_radius = 1.0
		seat.set_meta(&"pose", &"lie")
		seat.set_meta(&"special", true)
		seat.position = Vector3(feet.x, Terrain.height_at(feet.x, feet.y), feet.y)
		seat.rotation.y = yaw
		seat.name = "Towel%d" % k
		seat.add_to_group(&"sun_towels")
		var col: Color = st.towel_colors[k % st.towel_colors.size()] if not st.towel_colors.is_empty() else Color.WHITE
		var towel := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(0.85, 0.02, 1.9)
		towel.mesh = b
		towel.material_override = ProceduralProp.color_material(col, 0.95, false)
		towel.position = Vector3(0, 0.03, -0.85)
		seat.add_child(towel)
		var stripe := MeshInstance3D.new()
		var sb := BoxMesh.new()
		sb.size = Vector3(0.86, 0.022, 0.18)
		stripe.mesh = sb
		stripe.material_override = ProceduralProp.color_material(Color(0.97, 0.96, 0.92), 0.95, false)
		stripe.position = Vector3(0, 0.035, -0.3)
		seat.add_child(stripe)
		add_child(seat)
		seat.ready.connect(func() -> void: seat.zone.action_text = "lie down on the towel", CONNECT_ONE_SHOT)
		seat.used.connect(_on_used)
		towels.append(seat)
		if k % 2 == 0:
			var u := c + along * 1.15 - sea * 1.0
			_umbrella(Vector3(u.x, Terrain.height_at(u.x, u.y), u.y), st.umbrella_colors[(k / 2) % st.umbrella_colors.size()] if not st.umbrella_colors.is_empty() else Color.RED)
	# Sign
	var sp := st.center - sea * 4.2
	var post := MeshInstance3D.new()
	var pb := BoxMesh.new()
	pb.size = Vector3(0.1, 1.6, 0.1)
	post.mesh = pb
	post.material_override = ProceduralProp.color_material(Color(0.55, 0.4, 0.26), 0.8, false)
	post.position = Vector3(sp.x, Terrain.height_at(sp.x, sp.y) + 0.8, sp.y)
	add_child(post)
	var lbl := Label3D.new()
	Lang.setup_label3d(lbl)
	lbl.text = "ساحل آفتاب\nSun Beach" if st.id == "sun_beach" else "خلیج آرام\nQuiet Cove"
	lbl.font_size = 44
	lbl.pixel_size = 0.006
	lbl.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	lbl.position = post.position + Vector3(0, 1.0, 0)
	lbl.modulate = Color(1.0, 0.95, 0.8)
	lbl.outline_modulate = Color(0.2, 0.12, 0.05)
	add_child(lbl)


func _umbrella(p: Vector3, col: Color) -> void:
	var pole := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 0.03
	cy.bottom_radius = 0.03
	cy.height = 2.3
	cy.radial_segments = 6
	pole.mesh = cy
	pole.material_override = ProceduralProp.color_material(Color(0.9, 0.9, 0.88), 0.5, false)
	pole.position = p + Vector3(0, 1.1, 0)
	pole.rotation.z = 0.12
	add_child(pole)
	var top := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.03
	cone.bottom_radius = 1.35
	cone.height = 0.55
	cone.radial_segments = 12
	cone.rings = 1
	top.mesh = cone
	top.material_override = ProceduralProp.color_material(col, 0.7, false)
	top.position = p + Vector3(0.27, 2.2, 0)
	top.rotation.z = 0.12
	add_child(top)


func _on_used(who: Node3D) -> void:
	if who and who.is_in_group(&"player"):
		GameEvents.notification_requested.emit(Lang.tt("روی حوله دراز کشیدی و آفتاب می‌گیری. (برای بلند شدن حرکت کن)", "You lie down on the towel and soak up the sun. (move to get up)"))


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	var dt := _t
	_t = 0.0
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p and p.get("sitting_on") in towels:
		var st := style()
		Lifestyle.sunbathed_minutes += dt
		if p.has_method("restore_stamina"):
			p.call("restore_stamina", dt * 2.0 * ((st.rest_mult if st else 1.5) - 1.0))


func free_towel() -> Seat:
	for t in towels:
		if is_instance_valid(t) and t.is_free():
			return t
	return null
