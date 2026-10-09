class_name FridgeUnit
extends Node3D
## v6b "fridge" module: a fridge whose door swings open (E on the fridge) and
## whose shelves show what is stored - your groceries in the farmhouse (the
## ingredients in your bag), everyday food in the townspeople's homes.

var building: Building
var is_open: bool = false
var _door: Node3D
var _contents: Node3D
var _light: OmniLight3D
var _tween: Tween
var opens: int = 0
## +1: hinge on the +x edge (door swings toward +x), -1: on the -x edge.
var hinge: float = 1.0
const W := 0.72
const H := 1.82
const D := 0.66


func style() -> FridgeStyle:
	return Modules.style("fridge") as FridgeStyle


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _ready() -> void:
	add_to_group(&"fridges")
	var st := style()
	var body := ProceduralProp.color_material(st.body_color if st else Color(0.93, 0.94, 0.95), 0.35, false)
	var inside := ProceduralProp.color_material(st.inside_color if st else Color(0.97, 0.98, 1.0), 0.6, false)
	var t := 0.04
	# Shell: back, sides, top, bottom (open front).
	_box(self, Vector3(W, H, t), Vector3(0, H * 0.5, -D * 0.5 + t * 0.5), body)
	_box(self, Vector3(t, H, D), Vector3(-W * 0.5 + t * 0.5, H * 0.5, 0), body)
	_box(self, Vector3(t, H, D), Vector3(W * 0.5 - t * 0.5, H * 0.5, 0), body)
	_box(self, Vector3(W, t, D), Vector3(0, H - t * 0.5, 0), body)
	_box(self, Vector3(W, 0.1, D), Vector3(0, 0.05, 0), body)
	_box(self, Vector3(W - 2 * t, H - 0.14, 0.01), Vector3(0, H * 0.5, -D * 0.5 + t + 0.006), inside)
	var shelves := st.shelves if st else 3
	for i in shelves:
		var y := 0.35 + (H - 0.6) * float(i) / maxf(shelves, 1)
		_box(self, Vector3(W - 2 * t, 0.015, D - 0.1), Vector3(0, y, 0.0), ProceduralProp.color_material(Color(0.85, 0.92, 0.95), 0.1, false))
	# Door on a hinge at the right edge (local +x).
	_door = Node3D.new()
	_door.name = "Door"
	_door.position = Vector3(W * 0.5 * hinge, 0, D * 0.5)
	add_child(_door)
	_box(_door, Vector3(W, H - 0.02, 0.05), Vector3(-W * 0.5 * hinge, H * 0.5, 0.025), body)
	_box(_door, Vector3(0.03, 0.5, 0.04), Vector3((-W + 0.08) * hinge, H * 0.62, 0.07), ProceduralProp.color_material(Color(0.6, 0.62, 0.65), 0.3, false))
	_box(_door, Vector3(W - 0.12, 0.012, 0.1), Vector3(-W * 0.5 * hinge, H * 0.45, -0.05), inside)
	_box(_door, Vector3(W - 0.12, 0.012, 0.1), Vector3(-W * 0.5 * hinge, H * 0.72, -0.05), inside)
	_contents = Node3D.new()
	_contents.name = "Contents"
	_contents.visible = false
	add_child(_contents)
	if st == null or st.light:
		_light = OmniLight3D.new()
		_light.light_color = Color(0.85, 0.92, 1.0)
		_light.light_energy = 0.0
		_light.omni_range = 1.4
		_light.position = Vector3(0, H * 0.75, 0.1)
		_light.visible = false
		add_child(_light)


func stored_items() -> Array:
	var out: Array = []
	var st := style()
	if building and building.layout_id == "farmhouse":
		for id: String in Economy.inventory:
			if Economy.count(id) <= 0:
				continue
			var it := GameData.item(id)
			if str(it.get("category", "")) in ["ingredient", "fish", "fruit"] or str(it.get("type", "")) in ["produce", "ingredient", "fruit", "food"]:
				out.append([id, mini(Economy.count(id), 4)])
		return out
	if st:
		var r := RandomNumberGenerator.new()
		r.seed = hash(building.layout_id if building else "home")
		for id: String in st.npc_items:
			if r.randf() < 0.75:
				out.append([id, 1 + r.randi() % 3])
	return out


func _color_of(id: String) -> Color:
	for ing in Modules.all("ingredients"):
		if str(ing.get("id")) == id:
			return ing.get("color")
	match id:
		"milk": return Color(0.97, 0.97, 0.95)
		"eggs": return Color(0.95, 0.88, 0.75)
	var h := absi(hash(id))
	return Color.from_hsv(float(h % 360) / 360.0, 0.55, 0.85)


func refresh_contents() -> void:
	for c in _contents.get_children():
		c.queue_free()
	var items := stored_items()
	var st := style()
	var shelves := st.shelves if st else 3
	var slot := 0
	for pair in items:
		var col := _color_of(str(pair[0]))
		for k in int(pair[1]):
			var shelf := slot / 5
			if shelf > shelves:
				break
			var x := -W * 0.5 + 0.12 + float(slot % 5) * 0.12
			var y := 0.12 + (H - 0.6) * float(shelf) / maxf(shelves, 1) + 0.24
			if shelf == 0:
				y = 0.17
			var mi := _box(_contents, Vector3(0.09, 0.11 + (k % 2) * 0.04, 0.09), Vector3(x, y + 0.05, 0.02 - (k % 2) * 0.12),
				ProceduralProp.color_material(col, 0.6, false))
			mi.name = str(pair[0])
			slot += 1


func open_door() -> void:
	if is_open:
		return
	is_open = true
	opens += 1
	refresh_contents()
	_contents.visible = true
	if _light:
		_light.visible = true
		_light.light_energy = 0.7
	_swing(deg_to_rad(105.0) * hinge)
	Sfx.play_at(&"door", global_position, -12.0, 1.4)


func close_door() -> void:
	if not is_open:
		return
	is_open = false
	if _light:
		_light.light_energy = 0.0
		_light.visible = false
	_swing(0.0)


func _swing(angle: float) -> void:
	if _tween:
		_tween.kill()
	if not is_inside_tree():
		_door.rotation.y = angle
		return
	_tween = create_tween()
	_tween.tween_property(_door, "rotation:y", angle, 0.35).set_trans(Tween.TRANS_SINE)
	if angle == 0.0:
		_tween.tween_callback(func() -> void: _contents.visible = false)


func door_angle() -> float:
	return _door.rotation.y


## Short line listing what is inside (toast when you open it).
func contents_text() -> String:
	var items := stored_items()
	if items.is_empty():
		return Lang.tt("یخچال خالی است - از سوپرمارکت خرید کن.", "The fridge is empty - shop at the supermarket.")
	var parts: PackedStringArray = PackedStringArray()
	for pair in items:
		var nm := Market.local_name(str(pair[0])) if Market.has_method("local_name") else str(pair[0])
		parts.append("%s %s" % [Lang.digits(str(pair[1])), nm])
	return Lang.tt("داخل یخچال: ", "In the fridge: ") + ("، " if Lang.is_fa() else ", ").join(parts)
