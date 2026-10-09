class_name Digging
extends Node3D
## v6b "digging" module: R (on foot) digs a hole in open ground with the
## spade - not on roads, the square, water, the crop garden or indoors.
## Sometimes something turns up (a stone, a worm for bait, rarely an old
## coin); finds land next to the hole and stay there until picked up (E).
## R next to a hole fills it in; holes fill in by themselves after a few
## days. Holes and dropped finds are remembered (WorldMemory holes / drops).

var _holes_root: Node3D
var _drops_root: Node3D
var dug: int = 0
var filled: int = 0
var _rng := RandomNumberGenerator.new()
signal dug_hole(pos: Vector3, found: String)


func style() -> DiggingStyle:
	return Modules.style("digging") as DiggingStyle


func _ready() -> void:
	add_to_group(&"digging")
	_rng.randomize()
	_holes_root = Node3D.new()
	_holes_root.name = "Holes"
	add_child(_holes_root)
	_drops_root = Node3D.new()
	_drops_root.name = "Drops"
	add_child(_drops_root)
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind in ["all", "holes"]:
			_sync_holes()
		if kind in ["all", "drops"]:
			_sync_drops())
	TimeManager.day_started.connect(func(_d: int) -> void: refill_old())
	_sync_holes()
	_sync_drops()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"dig") or event.is_echo() or GameEvents.ui_open:
		return
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p == null or p.vehicle != null:
		return
	var f := p.facing_direction()
	dig_at(p.global_position + f * 0.9, p)
	get_viewport().set_input_as_handled()


func _indoors() -> bool:
	for b in get_tree().get_nodes_in_group(&"buildings"):
		if (b as Building).player_inside:
			return true
	return false


## Why you can't dig at (x, z) ("" = you can).
func blocked_reason(x: float, z: float) -> String:
	if Terrain.road_at(x, z) > 0.25 or Terrain.square_at(x, z) > 0.3:
		return Lang.tt("روی خیابان نمی‌شود کند.", "You can't dig up the road.")
	if Terrain.is_water(x, z):
		return Lang.tt("اینجا آب است.", "That's water.")
	if TownLayout.GARDEN_MAX_RECT.has_point(Vector2(x, z)):
		return Lang.tt("در باغچه با بیلچه کار کن، نه بیل.", "Use the hoe in the crop garden.")
	if _indoors():
		return Lang.tt("داخل خانه نمی‌شود کند.", "Not indoors.")
	return ""


## Dig (or fill) at a point. Returns "dug", "filled" or "" (blocked).
func dig_at(pos: Vector3, who: Node3D = null) -> String:
	var st := style()
	if st == null:
		return ""
	var hi := WorldMemory.hole_near(pos.x, pos.z, 0.7)
	if hi >= 0:
		WorldMemory.holes.remove_at(hi)
		WorldMemory.changed.emit("holes")
		filled += 1
		if who and who.has_method("play_tool"):
			who.call("play_tool", "hoe")
		GameEvents.notification_requested.emit(Lang.tt("چاله را پر کردی.", "You filled the hole in."))
		return "filled"
	var why := blocked_reason(pos.x, pos.z)
	if why != "":
		GameEvents.notification_requested.emit(why)
		return ""
	if who and who.has_method("play_tool"):
		who.call("play_tool", "hoe")
	if who and who.has_method("spend_stamina"):
		who.call("spend_stamina", st.stamina)
	WorldMemory.add_hole(pos.x, pos.z)
	dug += 1
	Sfx.play_at(&"hoe_dig", pos, -4.0)
	var found := ""
	var r := _rng.randf()
	var acc := 0.0
	for fd: Dictionary in st.finds:
		acc += float(fd.get("chance", 0.0))
		if r < acc:
			found = str(fd.get("item", ""))
			var side := Vector3(0.55, 0, 0.25)
			WorldMemory.add_drop(found, Vector3(pos.x + side.x, Terrain.height_at(pos.x + side.x, pos.z + side.z), pos.z + side.z))
			GameEvents.notification_requested.emit(Lang.tt("پیدا کردی: %s - برش دار (E)." % str(fd.get("fa", found)), "You found %s - pick it up (E)." % str(fd.get("en", found))))
			break
	if found == "":
		GameEvents.notification_requested.emit(Lang.tt("یک چاله کندی. چیزی نبود.", "You dug a hole. Nothing in it."))
	dug_hole.emit(pos, found)
	return "dug"


func refill_old() -> int:
	var st := style()
	var days := st.refill_days if st else 4
	var before := WorldMemory.holes.size()
	WorldMemory.holes = WorldMemory.holes.filter(func(h: Dictionary) -> bool: return TimeManager.day - int(h.get("day", 0)) < days)
	if WorldMemory.holes.size() != before:
		WorldMemory.changed.emit("holes")
	return before - WorldMemory.holes.size()


static var _hole_mesh: CylinderMesh
static var _mound_mesh: SphereMesh
static var _hole_mat: StandardMaterial3D
static var _mound_mat: StandardMaterial3D


func _sync_holes() -> void:
	for c in _holes_root.get_children():
		c.queue_free()
	var st := style()
	if _hole_mesh == null:
		_hole_mesh = CylinderMesh.new()
		_hole_mesh.top_radius = 0.36
		_hole_mesh.bottom_radius = 0.3
		_hole_mesh.height = 0.04
		_hole_mesh.radial_segments = 12
		_mound_mesh = SphereMesh.new()
		_mound_mesh.radius = 0.32
		_mound_mesh.height = 0.26
		_mound_mesh.radial_segments = 10
		_mound_mesh.rings = 4
		_hole_mat = StandardMaterial3D.new()
		_hole_mat.albedo_color = Color(0.16, 0.11, 0.07)
		_hole_mat.roughness = 1.0
		_mound_mat = StandardMaterial3D.new()
		_mound_mat.albedo_color = Color(0.42, 0.3, 0.19)
		_mound_mat.roughness = 1.0
	var r := st.radius if st else 0.35
	for h: Dictionary in WorldMemory.holes:
		var x := float(h["x"])
		var z := float(h["z"])
		var y := Terrain.height_at(x, z)
		var hole := MeshInstance3D.new()
		hole.mesh = _hole_mesh
		hole.material_override = _hole_mat
		hole.scale = Vector3(r / 0.35, 1, r / 0.35)
		hole.position = Vector3(x, y + 0.012, z)
		hole.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_holes_root.add_child(hole)
		var mound := MeshInstance3D.new()
		mound.mesh = _mound_mesh
		mound.material_override = _mound_mat
		mound.position = Vector3(x - 0.5, y + 0.02, z - 0.2)
		_holes_root.add_child(mound)


func _sync_drops() -> void:
	for c in _drops_root.get_children():
		c.queue_free()
	for i in WorldMemory.drops.size():
		var d: Dictionary = WorldMemory.drops[i]
		var p := WorldMemory.vec(d.get("p"))
		var item := str(d.get("item", ""))
		var holder := Node3D.new()
		holder.position = p
		_drops_root.add_child(holder)
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09 if item != "stone" else 0.13
		sm.height = sm.radius * (1.2 if item == "stone" else 2.0)
		mi.mesh = sm
		var m := StandardMaterial3D.new()
		m.albedo_color = {"stone": Color(0.55, 0.55, 0.52), "worm": Color(0.75, 0.42, 0.42), "old_coin": Color(0.82, 0.8, 0.75)}.get(item, Color(0.7, 0.6, 0.3))
		m.metallic = 0.8 if item == "old_coin" else 0.0
		m.roughness = 0.3 if item == "old_coin" else 0.9
		mi.material_override = m
		mi.position.y = sm.height * 0.5
		holder.add_child(mi)
		var idx := i
		ActionSpot.make(holder, Vector3.ZERO, 0.9,
			func() -> String: return Lang.tt("برداشتن %s" % Market.local_name(item), "pick up the %s" % GameData.item_name(item)),
			func(_who: Node3D) -> void: pick_drop(idx))


func pick_drop(i: int) -> String:
	var item := WorldMemory.take_drop(i)
	if item != "":
		Economy.add_item(item, 1)
		GameEvents.item_collected.emit(item)
	return item
