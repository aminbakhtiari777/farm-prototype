class_name RemoteAvatar
extends Node3D
## One other player as seen by this client (RemoteAvatars).

var pid: int = 0
var display_name: String = ""
var color: Color = Color(0.3, 0.5, 0.9)
var status: String = "active"
var dest: String = ""
var visual: HumanoidModelVisual
var tag: Label3D
var _bubble: Label3D
var _bubble_left: float = 0.0
var _furniture: Node3D
var _tea: Node3D
var teas: int = 0


static func make_bubble() -> Label3D:
	var l := Label3D.new()
	Lang.setup_label3d(l)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.0045
	l.outline_size = 10
	l.width = 380.0
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	l.outline_modulate = Color(0.08, 0.06, 0.05, 0.9)
	l.position.y = 2.45
	l.visible = false
	return l


func _ready() -> void:
	add_to_group(&"remote_players")
	visual = HumanoidModelVisual.new()
	visual.name = "Visual"
	visual.shirt_color = color
	visual.pants_color = Color(0.2, 0.22, 0.3)
	visual.hair_style = "Hair_Buzzed" if pid % 2 == 0 else "Hair_SimpleParted"
	visual.beard = pid % 3 == 0
	add_child(visual)
	tag = Label3D.new()
	Lang.setup_label3d(tag, 48)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.pixel_size = 0.0055
	tag.outline_size = 9
	tag.modulate = color.lightened(0.45)
	tag.position.y = 2.1
	add_child(tag)
	_bubble = make_bubble()
	add_child(_bubble)
	_refresh_tag()


func _refresh_tag() -> void:
	if tag == null:
		return
	var line2 := ""
	match status:
		"away_walk":
			line2 = Lang.pick({"fa": "(آفلاین - در راه %s)" % ("کافه" if dest == "cafe" else "خانه"), "en": "(offline - walking to the %s)" % dest})
		"away_sit":
			line2 = Lang.pick({"fa": "(آفلاین - در کافه)", "en": "(offline - at the cafe)"})
		"away_home":
			line2 = Lang.pick({"fa": "(آفلاین - دم خانه)", "en": "(offline - at home)"})
	tag.text = display_name + ("\n" + line2 if line2 != "" else "")


func set_status(s: String, d: String) -> void:
	if s == status and d == dest:
		return
	status = s
	dest = d
	_refresh_tag()
	tag.modulate = color.lightened(0.45) if s == "active" else Color(0.8, 0.8, 0.85)


func is_away() -> bool:
	return status != "active"


func apply(pos: Vector3, yaw: float, speed: float, state_code: int) -> void:
	global_position = pos
	visual.rotation.y = yaw
	var sitting := state_code == 2 or state_code == 3
	if sitting:
		_ensure_furniture()
		visual.set_ground_speed(0.0)
		visual.set_pose(&"sit")
		visual.position.y = 0.0
	else:
		if _furniture:
			_furniture.queue_free()
			_furniture = null
			_tea = null
		visual.set_pose(&"")
		visual.set_ground_speed(speed)


func bubble(text: String) -> void:
	_bubble.text = text
	_bubble.visible = true
	var st := Modules.style("chat") as ChatStyle
	_bubble_left = st.bubble_seconds if st else 6.0


func _process(delta: float) -> void:
	if _bubble_left > 0.0:
		_bubble_left -= delta
		if _bubble_left <= 0.0:
			_bubble.visible = false


func _box(parent: Node3D, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	bm.material = mat
	m.mesh = bm
	m.position = pos
	parent.add_child(m)
	return m


## A stool + small table (cafe terrace / porch) under the sitting avatar.
func _ensure_furniture() -> void:
	if _furniture:
		_furniture.rotation.y = visual.rotation.y
		return
	_furniture = Node3D.new()
	_furniture.name = "AwaySeat"
	add_child(_furniture)
	_furniture.rotation.y = visual.rotation.y
	var wood := Color(0.45, 0.3, 0.18)
	_box(_furniture, Vector3(0.46, 0.06, 0.46), Vector3(0, 0.44, -0.05), wood)
	for x in [-0.18, 0.18]:
		for z in [-0.23, 0.13]:
			_box(_furniture, Vector3(0.05, 0.44, 0.05), Vector3(x, 0.22, z), wood.darkened(0.2))
	# Table in front.
	var top := _box(_furniture, Vector3(0.7, 0.05, 0.6), Vector3(0, 0.72, 0.62), Color(0.92, 0.9, 0.85))
	top.name = "TableTop"
	_box(_furniture, Vector3(0.08, 0.72, 0.08), Vector3(0, 0.36, 0.62), Color(0.25, 0.25, 0.27))
	for i in teas:
		_add_cup(i)


func _add_cup(i: int) -> void:
	if _furniture == null:
		return
	var cup := Node3D.new()
	cup.name = "Tea%d" % i
	cup.position = Vector3(-0.15 + i * 0.2, 0.745, 0.5)
	_furniture.add_child(cup)
	_box(cup, Vector3(0.16, 0.012, 0.16), Vector3(0, 0.006, 0), Color(0.95, 0.95, 0.95))
	var glass := _box(cup, Vector3(0.07, 0.1, 0.07), Vector3(0, 0.06, 0), Color(0.6, 0.18, 0.08))
	glass.name = "Glass"
	_tea = cup


## A townsperson brought tea: a glass of tea appears on the little table.
func serve_tea() -> void:
	teas = mini(teas + 1, 3)
	if _furniture:
		_add_cup(teas - 1)
