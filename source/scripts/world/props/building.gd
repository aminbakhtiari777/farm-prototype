@tool
class_name Building
extends ProceduralProp
## A house you can walk into. Hollow walls (painted inside), a floor, a door
## that swings open (E, or automatically for townspeople), a furnished interior
## (scripts/world/interior/interior_builder.gd), a building-type sign above the
## door (Label3D board) and a street-address plaque by the door.
##
## Static geometry is baked into a few merged meshes (MeshMerger) to keep draw
## calls low on the web: exterior shell, roof, interior furniture. When the
## player is inside, the roof turns invisible (it still casts its shadow so the
## room stays indoor-dark), an interior light switches on and the camera rig
## shortens its arm. Interiors further than ~24 m away are hidden.
##
## Front faces +Z. Configure from TownLayout (layout_id) or the exports.

signal player_entered(building: Building)
signal player_exited(building: Building)

@export var layout_id: String = ""
@export var size: Vector3 = Vector3(7.0, 3.0, 6.0):  ## width, wall height, depth
	set(v):
		size = v
		_queue_rebuild()
@export var roof_height: float = 1.8
@export var wall_color: Color = Color(0.86, 0.8, 0.68)
@export var roof_color: Color = Color(0.45, 0.2, 0.15)
@export var trim_color: Color = Color(0.95, 0.93, 0.88)
@export var door_color: Color = Color(0.35, 0.22, 0.13)
@export var shutter_color: Color = Color(0.25, 0.4, 0.3)
@export var timber_frame: bool = false
@export var has_chimney: bool = true
@export var has_porch: bool = false
@export var upper_windows: bool = false
@export var door_offset: float = 0.0
## The farmer can sleep in this house's bed (skips to the next morning).
@export var sleep_here: bool = false
@export var kind: String = "home"
@export var sign_text: String = ""
@export var address: String = ""
@export var interior_theme: String = "home_a"
## Townsperson who lives here (NPC schedules look this up).
@export var owner_name: String = ""
## v5a: "gable" / "flat" (house styles, modern shops, mosque).
@export var roof_type: String = "gable"
## v5a: registry type that styles this building ("workplaces", "civic", ...).
var module_type: String = ""
## v5a: shop / desk id its counter opens.
var shop_id: String = ""

const FOUNDATION_HEIGHT := 0.3
const WALL_T := 0.2
const DOOR_W := 1.2
const DOOR_H := 2.25
const INTERIOR_VISIBLE_DISTANCE := 26.0

var exterior_mesh: MeshInstance3D
## v4 house_styles module (homes only): cladding, roof shape, interior palette.
var house_style: HouseStyle = null
var roof_mesh: MeshInstance3D
var interior_root: Node3D
var door: BuildingDoor
var sign_label: Label3D
var address_label: Label3D
var player_inside: bool = false
var _interior_light: OmniLight3D
var _check_timer: float = 0.0
## v7a: demolished (BuildingDamage) - the interior stays hidden.
var wrecked: bool = false
## v7b.1 perf: lazy interiors (InteriorStreamer). interior_built = furniture exists.
var interior_built: bool = true
var _interior_args: Array = []
var _interior_nodes: Array = []
var _interior_far_time: float = 0.0
var damage_args: Array = []
var exterior_built: bool = false
var _services_built: bool = false
var _visual_only: bool = false
var _exterior_nodes: Array = []
var _exterior_far_time: float = 0.0
static var force_exterior_lazy: int = -1


static func lazy_exteriors() -> bool:
	if force_exterior_lazy >= 0:
		return force_exterior_lazy == 1
	for a in OS.get_cmdline_user_args():
		if a == "--smoke-test" or a.begins_with("--net-test") or "shots" in a or a == "--perf":
			return false
	return true


func _rebuild() -> void:
	_services_built = false
	exterior_built = false
	_exterior_nodes.clear()
	super._rebuild()


## Build only visual children; keep doors, furniture, module attachments and
## collision identities intact. TownBuilder schedules at most one per frame.
func ensure_exterior() -> void:
	if exterior_built:
		return
	var before := get_children()
	_visual_only = true
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	_build(rng)
	_visual_only = false
	_exterior_nodes = get_children().filter(func(c: Node) -> bool: return not before.has(c))
	exterior_built = true
	if not damage_args.is_empty():
		BuildingDamage.apply(self, str(damage_args[0]), float(damage_args[1]), int(damage_args[2]))
	if player_inside and roof_mesh:
		roof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


func release_exterior() -> void:
	if not exterior_built or player_inside or not lazy_exteriors():
		return
	for c in _exterior_nodes:
		if is_instance_valid(c):
			remove_child(c)
			(c as Node).queue_free()
	_exterior_nodes.clear()
	exterior_mesh = null
	roof_mesh = null
	sign_label = null
	address_label = null
	exterior_built = false


func add_box_collider(box_size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	if not _visual_only:
		super.add_box_collider(box_size, pos, rot)


func add_cylinder_collider(radius: float, height: float, pos: Vector3) -> void:
	if not _visual_only:
		super.add_cylinder_collider(radius, height, pos)


## Cheap structural collision remains for NPCs and fast arrival/teleports.
func _build_structure() -> void:
	var w := size.x
	var h := size.y
	var d := size.z
	var base := FOUNDATION_HEIGHT
	add_box_collider(Vector3(w + 0.2, base, d + 0.2), Vector3(0, base * 0.5, 0))
	add_box_collider(Vector3(w, h, WALL_T), Vector3(0, base + h * 0.5, -d * 0.5 + WALL_T * 0.5))
	for side in [-1.0, 1.0]:
		add_box_collider(Vector3(WALL_T, h, d - WALL_T * 2.0), Vector3(side * (w * 0.5 - WALL_T * 0.5), base + h * 0.5, 0))
	var left_w := door_offset - DOOR_W * 0.5 + w * 0.5
	var right_w := w * 0.5 - door_offset - DOOR_W * 0.5
	add_box_collider(Vector3(left_w, h, WALL_T), Vector3(-w * 0.5 + left_w * 0.5, base + h * 0.5, d * 0.5 - WALL_T * 0.5))
	add_box_collider(Vector3(right_w, h, WALL_T), Vector3(w * 0.5 - right_w * 0.5, base + h * 0.5, d * 0.5 - WALL_T * 0.5))
	add_box_collider(Vector3(DOOR_W, h - DOOR_H, WALL_T), Vector3(door_offset, base + DOOR_H + (h - DOOR_H) * 0.5, d * 0.5 - WALL_T * 0.5))
	if has_porch:
		add_box_collider(Vector3(w * 0.75, base, 1.8), Vector3(door_offset, base * 0.5, d * 0.5 + 0.9))
		add_box_collider(Vector3(1.2, 0.46, 0.42), Vector3(door_offset - w * 0.75 * 0.3, base + 0.23, d * 0.5 + 0.45))
		_ramp(Vector3(door_offset, 0, d * 0.5 + 2.7), Vector3(door_offset, base, d * 0.5 + 1.7), 1.6)
	else:
		_ramp(Vector3(door_offset, 0, d * 0.5 + 0.9), Vector3(door_offset, base, d * 0.5 - 0.05), 1.8)


## Furnish the interior now (no-op when already built). Deterministic: same rng state as an eager build.
func ensure_interior() -> void:
	if interior_built or _interior_args.is_empty() or interior_root == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = int(_interior_args[2])
	rng.state = int(_interior_args[3])
	var before := interior_root.get_children()
	InteriorBuilder.build(self, interior_root, str(_interior_args[0]), _interior_args[1], rng)
	_interior_nodes = interior_root.get_children().filter(func(c: Node) -> bool: return not before.has(c))
	interior_built = true
	InteriorStreamer.note_built(self)


## Free the furniture again (only lazily-built interiors, never with the player inside).
func release_interior() -> void:
	if not interior_built or _interior_args.is_empty() or player_inside:
		return
	for c in _interior_nodes:
		if is_instance_valid(c):
			(c as Node).queue_free()
	_interior_nodes.clear()
	interior_built = false
	InteriorStreamer.note_released(self)


func _ready() -> void:
	if layout_id != "" and not Engine.is_editor_hint():
		_apply_layout(TownLayout.building(layout_id))
	add_to_group(&"buildings")
	super._ready()
	if kind == "home" and layout_id != "" and layout_id != "farmhouse" and not Engine.is_editor_hint():
		Modules.on_swap("house_styles", self, func(_m: Resource) -> void: restyle())
		# v6b: family colours, living room, fridge and gas stove rebuild homes live.
		for t: String in ["house_colors", "living_room", "fridge", "gas_stove"]:
			Modules.on_swap(t, self, func(_m: Resource) -> void: restyle())
	# v5b: the mosque module (dome shape, ribs, drum) rebuilds the mosque live.
	if kind == "mosque" and layout_id != "" and not Engine.is_editor_hint():
		Modules.on_swap("mosque", self, func(_m: Resource) -> void: restyle())


## v5a live house-style swap: re-reads the layout + style and rebuilds this
## building in place (exterior, roof, interior, kitchen).
var restyles: int = 0


func restyle() -> void:
	if player_inside:
		return  # never rebuild around the farmer; next swap will catch it
	_apply_layout(TownLayout.building(layout_id))
	_rebuild()
	if snap_to_terrain:
		global_position.y = _ground_height()
	restyles += 1


func _apply_layout(b: Dictionary) -> void:
	if b.is_empty():
		return
	var p: Vector2 = b["pos"]
	position = Vector3(p.x, position.y, p.y)
	rotation = Vector3(0, deg_to_rad(float(b["yaw"])), 0)
	size = b["size"]
	roof_height = float(b.get("roof", 1.8))
	wall_color = b.get("wall", wall_color)
	roof_color = b.get("roof_color", roof_color)
	has_porch = bool(b.get("porch", false))
	upper_windows = bool(b.get("tall", false))
	timber_frame = bool(b.get("timber", false))
	sleep_here = bool(b.get("sleep", false))
	kind = str(b.get("kind", "home"))
	sign_text = str(b.get("sign", ""))
	address = str(b.get("address", ""))
	interior_theme = str(b.get("interior", "home_a"))
	owner_name = str(b.get("owner", ""))
	roof_type = str(b.get("roof_type", "gable"))
	module_type = str(b.get("module", ""))
	shop_id = str(b.get("shop", ""))
	if sign_text == "" and kind == "home":
		# v5a population module: homes are named after the family living there.
		var fam := _family_for(layout_id)
		if fam != "":
			owner_name = fam
			sign_text = "The %s Family" % fam
		elif owner_name != "":
			sign_text = "%s's House" % owner_name
	var style := Modules.style("buildings") as BuildingStyle
	if style:
		wall_color = wall_color * style.wall_tint
		roof_color = style.roof_for(hash(layout_id), roof_color)
		trim_color = style.trim_color
		if not style.shutter_palette.is_empty():
			shutter_color = style.shutter_palette[hash(layout_id) % style.shutter_palette.size()]
	_apply_module_style()
	house_style = HouseStyle.for_layout(b)
	if house_style:
		roof_type = house_style.roof_type
		wall_color = house_style.wall_color
		roof_color = house_style.roof_color
		trim_color = house_style.trim_color
		has_chimney = house_style.chimney
		if house_style.kind != "wooden":
			timber_frame = false
	# v6b house_colors: walls in the owning family's colour.
	wall_color = HouseColors.wall_for(self, wall_color)
	HouseVariety.apply(self, b)  # v7b.1 house_variety module
	random_seed = hash(layout_id) % 1000


## v5a: colours / roof shape from the module that owns this building.
func _apply_module_style() -> void:
	match module_type:
		"crafting":
			var cs := Modules.style("crafting") as CraftingStyle
			if cs:
				wall_color = cs.wall_color
				roof_color = cs.roof_color
		"workplaces":
			var ws := Modules.style("workplaces") as WorkplaceStyle
			if ws:
				wall_color = wall_color * ws.wall_tint
				if ws.flat_roofs:
					roof_type = "flat"
		"civic":
			var cv := Modules.style("civic") as CivicStyle
			if cv:
				wall_color = wall_color * cv.wall_tint
		"mosque":
			var ms := Modules.style("mosque") as MosqueStyle
			if ms:
				wall_color = ms.wall_color
				roof_color = ms.wall_color.darkened(0.1)
				trim_color = ms.trim_color
				has_chimney = false
				roof_type = "flat"
		"gym":
			var gs := Modules.style("gym") as GymStyle
			if gs:
				trim_color = gs.accent
				has_chimney = false
		"hypermarket":
			var hs := Modules.style("hypermarket") as HypermarketStyle
			if hs:
				roof_color = hs.sign_color
				has_chimney = false
		"church":
			var ch := Modules.style("church") as ChurchStyle
			if ch:
				wall_color = ch.wall_color
				roof_color = ch.roof_color
				has_chimney = false


static func _family_for(home_id: String) -> String:
	for r in Population.residents():
		if str(r.get("home", "")) == home_id:
			return str(r.get("surname", ""))
	return ""


func _ground_height() -> float:
	var lowest := INF
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2.ZERO]:
		var local := Vector3(c.x * size.x * 0.5, 0.0, c.y * size.z * 0.5)
		var g := global_transform * local
		lowest = minf(lowest, Terrain.height_at(g.x, g.z))
	return lowest


func floor_y() -> float:
	return FOUNDATION_HEIGHT


## World position just inside / outside the door (NPC navigation, tests).
func door_world_position(outside: float) -> Vector3:
	return global_transform * Vector3(door_offset, FOUNDATION_HEIGHT if outside < 0.0 else 0.0, size.z * 0.5 + outside)


func interior_center() -> Vector3:
	return global_transform * Vector3(0, FOUNDATION_HEIGHT, 0)


func is_point_inside(world: Vector3) -> bool:
	var l := to_local(world)
	return absf(l.x) < size.x * 0.5 - 0.1 and absf(l.z) < size.z * 0.5 - 0.1 and l.y > -0.5 and l.y < size.y + 1.0


# ------------------------------------------------------------------ build
func _build(rng: RandomNumberGenerator) -> void:
	if not Engine.is_editor_hint() and lazy_exteriors() and not _visual_only:
		_build_structure()
		_build_services(rng)
		return
	exterior_built = true
	var w := size.x
	var h := size.y
	var d := size.z
	var base := FOUNDATION_HEIGHT
	var top := base + h
	var ext := Node3D.new()
	ext.name = "ExteriorParts"
	add_child(ext)
	var roof := Node3D.new()
	roof.name = "RoofParts"
	add_child(roof)

	var stone := color_material(Color(0.52, 0.5, 0.47), 0.95)
	var walls: Material = house_style.wall_material() if house_style else color_material(wall_color, 0.9)
	var roof_mat := color_material(roof_color, 0.8)
	var trim := color_material(trim_color, 0.7)
	var look := InteriorBuilder.theme_colors(interior_theme)
	if house_style:
		look = {"wall": house_style.interior_wall, "floor": house_style.interior_floor}
	var paint := color_material(look["wall"], 0.92)
	var floor_mat := color_material(look["floor"], 0.75)

	# Foundation + floor.
	add_box(Vector3(w + 0.2, base + 0.6, d + 0.2), Vector3(0, base * 0.5 - 0.3, 0), stone, Vector3.ZERO, ext)
	add_box(Vector3(w - WALL_T * 2.0, 0.04, d - WALL_T * 2.0), Vector3(0, base + 0.02, 0), floor_mat, Vector3.ZERO, ext)
	# Plank lines on the floor.
	for i in int((d - 0.4) / 0.32):
		add_box(Vector3(w - WALL_T * 2.0, 0.006, 0.012), Vector3(0, base + 0.043, -d * 0.5 + 0.3 + i * 0.32), color_material(Color(look["floor"]).darkened(0.35), 0.8), Vector3.ZERO, ext)
	add_box_collider(Vector3(w + 0.2, base, d + 0.2), Vector3(0, base * 0.5, 0))

	# Walls: outer skin (exterior colour) + inner skin (interior paint).
	var hw := w * 0.5
	var hd := d * 0.5
	_wall(Vector3(w, h, WALL_T), Vector3(0, base + h * 0.5, -hd + WALL_T * 0.5), walls, paint, Vector3(0, 0, 1), ext)
	_wall(Vector3(WALL_T, h, d - WALL_T * 2.0), Vector3(-hw + WALL_T * 0.5, base + h * 0.5, 0), walls, paint, Vector3(1, 0, 0), ext)
	_wall(Vector3(WALL_T, h, d - WALL_T * 2.0), Vector3(hw - WALL_T * 0.5, base + h * 0.5, 0), walls, paint, Vector3(-1, 0, 0), ext)
	var left_w := (door_offset - DOOR_W * 0.5) + hw
	var right_w := hw - (door_offset + DOOR_W * 0.5)
	_wall(Vector3(left_w, h, WALL_T), Vector3(-hw + left_w * 0.5, base + h * 0.5, hd - WALL_T * 0.5), walls, paint, Vector3(0, 0, -1), ext)
	_wall(Vector3(right_w, h, WALL_T), Vector3(hw - right_w * 0.5, base + h * 0.5, hd - WALL_T * 0.5), walls, paint, Vector3(0, 0, -1), ext)
	_wall(Vector3(DOOR_W, h - DOOR_H, WALL_T), Vector3(door_offset, base + DOOR_H + (h - DOOR_H) * 0.5, hd - WALL_T * 0.5), walls, paint, Vector3(0, 0, -1), ext)
	# Skirting board inside.
	var skirting := color_material(Color(look["floor"]).darkened(0.25), 0.7)
	add_box(Vector3(w - WALL_T * 2.0, 0.1, 0.02), Vector3(0, base + 0.05, -hd + WALL_T + 0.01), skirting, Vector3.ZERO, ext)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.02, 0.1, d - WALL_T * 2.0), Vector3(sx * (hw - WALL_T - 0.01), base + 0.05, 0), skirting, Vector3.ZERO, ext)

	# Corner trims / timber framing.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(Vector3(0.16, h, 0.16), Vector3(sx * (hw - 0.02), base + h * 0.5, sz * (hd - 0.02)), trim if not timber_frame else color_material(door_color, 0.6), Vector3.ZERO, ext)
	if timber_frame:
		var beam := color_material(Color(0.28, 0.18, 0.1), 0.8)
		add_box(Vector3(w + 0.02, 0.14, 0.06), Vector3(0, base + h * 0.52, hd + 0.01), beam, Vector3.ZERO, ext)
		add_box(Vector3(w + 0.02, 0.14, 0.06), Vector3(0, top - 0.07, hd + 0.01), beam, Vector3.ZERO, ext)

	# Roof: gables, slopes with shingle rows, ridge, ceiling, chimney.
	if roof_type == "flat":
		_flat_roof(w, d, top, paint, roof)
	else:
		_gable_roof(w, d, top, walls, paint, roof)
	if has_chimney:
		var brick := color_material(Color(0.55, 0.3, 0.24), 0.9)
		var chimney_h := roof_height + 1.3
		add_box(Vector3(0.62, chimney_h, 0.62), Vector3(hw - 0.9, top + chimney_h * 0.5 - 0.2, -d * 0.22), brick, Vector3.ZERO, roof)
		add_box(Vector3(0.74, 0.12, 0.74), Vector3(hw - 0.9, top + chimney_h - 0.14, -d * 0.22), stone, Vector3.ZERO, roof)
	_build_rest(rng, w, h, d, base, top, hw, hd, ext, roof, stone, walls, roof_mat, trim, look, paint, floor_mat)


## Modern style: flat roof slab with a parapet (no gables / shingles).
func _flat_roof(w: float, d: float, top: float, paint: Material, roof: Node3D) -> void:
	var slab := color_material(roof_color, 0.7)
	var edge := color_material(trim_color, 0.6)
	add_box(Vector3(w - 0.1, 0.06, d - 0.1), Vector3(0, top + 0.03, 0), paint, Vector3.ZERO, roof)
	add_box(Vector3(w + 0.5, 0.22, d + 0.5), Vector3(0, top + 0.17, 0), slab, Vector3.ZERO, roof)
	for sz in [-1.0, 1.0]:
		add_box(Vector3(w + 0.5, 0.3, 0.12), Vector3(0, top + 0.43, sz * (d * 0.5 + 0.19)), edge, Vector3.ZERO, roof)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.12, 0.3, d + 0.5), Vector3(sx * (w * 0.5 + 0.19), top + 0.43, 0), edge, Vector3.ZERO, roof)


func _gable_roof(w: float, d: float, top: float, walls: Material, paint: Material, roof: Node3D) -> void:
	var roof_mat := color_material(roof_color, 0.8)
	add_gable_to(d, roof_height, w - 0.02, Vector3(0, top + roof_height * 0.5, 0), walls, Vector3(0, PI * 0.5, 0), roof)
	add_box(Vector3(w - 0.1, 0.06, d - 0.1), Vector3(0, top + 0.03, 0), paint, Vector3.ZERO, roof)
	var overhang := 0.45
	var half_run := d * 0.5 + overhang
	var angle := atan2(roof_height, d * 0.5)
	var slab_len := half_run / cos(angle)
	var eave_drop := overhang * tan(angle)
	var shingle := color_material(roof_color.darkened(0.25), 0.85)
	for side in [-1.0, 1.0]:
		var centre_z: float = side * half_run * 0.5
		var centre_y := top + roof_height - (roof_height + eave_drop) * 0.5 + 0.06
		add_box(Vector3(w + overhang * 2.0, 0.14, slab_len), Vector3(0, centre_y, centre_z), roof_mat, Vector3(side * angle, 0, 0), roof)
		for r in range(1, 6):
			var t := float(r) / 6.0
			add_box(Vector3(w + overhang * 2.0 + 0.02, 0.04, 0.05),
					Vector3(0, top + roof_height - (roof_height + eave_drop) * t + 0.14, side * half_run * t), shingle, Vector3(side * angle, 0, 0), roof)
	add_box(Vector3(w + overhang * 2.0 + 0.1, 0.16, 0.24), Vector3(0, top + roof_height + 0.1, 0), color_material(roof_color.darkened(0.3), 0.8), Vector3.ZERO, roof)


func _build_rest(rng: RandomNumberGenerator, w: float, h: float, d: float, base: float, top: float, hw: float, hd: float, ext: Node3D, roof: Node3D,
		stone: Material, walls: Material, roof_mat: Material, trim: Material, look: Dictionary, paint: Material, floor_mat: Material) -> void:

	# Door frame, steps + invisible ramp so the farmer walks up onto the floor.
	add_box(Vector3(DOOR_W + 0.24, DOOR_H + 0.14, 0.06), Vector3(door_offset, base + (DOOR_H + 0.14) * 0.5, hd + 0.005), trim, Vector3.ZERO, ext)
	# The hinged BuildingDoor is the only panel: a baked dark rectangle here
	# used to remain across the opening after the actual door swung away.
	if not has_porch:
		add_box(Vector3(1.6, base * 0.5, 0.45), Vector3(door_offset, base * 0.25, hd + 0.22), stone, Vector3.ZERO, ext)
		add_box(Vector3(1.6, base * 0.5, 0.35), Vector3(door_offset, base * 0.75 - 0.01, hd + 0.08), stone, Vector3.ZERO, ext)
		_ramp(Vector3(door_offset, 0.0, hd + 0.9), Vector3(door_offset, base, hd - 0.05), 1.8)

	# Windows (outer face + inner face so they read from inside too).
	var row_y := base + h * 0.5 + 0.15 if not upper_windows else base + h * 0.3 + 0.15
	var front_slots: Array[float] = []
	for x in [-hw + 1.2, hw - 1.2, -w * 0.25, w * 0.25]:
		if absf(x - door_offset) > 1.35 and front_slots.size() < 2 + int(w > 8.0):
			var ok := true
			for other in front_slots:
				if absf(x - other) < 1.6:
					ok = false
			if ok:
				front_slots.append(x)
	for x in front_slots:
		_window(Vector3(x, row_y, hd), 0.0, trim, rng, ext)
		if upper_windows:
			_window(Vector3(x, base + h * 0.78, hd), 0.0, trim, rng, ext)
	if upper_windows:
		_window(Vector3(door_offset, base + h * 0.78, hd), 0.0, trim, rng, ext)
	for side in [-1.0, 1.0]:
		_window(Vector3(side * hw, row_y, 0.0), side * PI * 0.5, trim, rng, ext)
	_window(Vector3(-w * 0.22, row_y, -hd), PI, trim, rng, ext)

	if has_porch:
		_porch(rng, ext, roof_mat)

	# Wall lantern by the door (night lights module) + farmhouse extras.
	_wall_lantern(ext)
	if sleep_here and not Engine.is_editor_hint() and not has_node(^"BreakerBox"):
		_farmhouse_power()

	# Signs.
	if sign_text != "" and not DoorPlaques.hide_roof_sign(self):  # v7b.1: homes get a door plaque instead
		_sign_board(sign_text, ext)
	if address != "":
		_address_plaque(address, ext)
	if not Engine.is_editor_hint():
		DoorPlaques.attach(self, ext)  # v7b.1 door_plaques module

	if not _services_built:
		_build_services(rng)

	# v5a: module extras (awnings, porticos, dome + minaret, bell tower...).
	if not Engine.is_editor_hint():
		BuildingDecor.decorate(self, ext, roof)

	# Bake static geometry.
	exterior_mesh = MeshMerger.merge_children_baked(ext, self, "ExteriorMesh")
	ext.add_child(exterior_mesh)
	exterior_mesh.visibility_range_end = 260.0
	roof_mesh = MeshMerger.merge_children_baked(roof, self, "RoofMesh")
	roof.add_child(roof_mesh)
	roof_mesh.visibility_range_end = 260.0


func _build_services(rng: RandomNumberGenerator) -> void:
	_services_built = true
	if sleep_here and not Engine.is_editor_hint() and not has_node(^"BreakerBox"):
		_farmhouse_power()
	var w := size.x
	var h := size.y
	var d := size.z
	var base := FOUNDATION_HEIGHT
	var top := base + h
	var hd := d * 0.5
	if has_porch and not Engine.is_editor_hint() and not has_node(^"PorchSeat"):
		var seat := Seat.new()
		seat.name = "PorchSeat"
		seat.position = Vector3(door_offset - w * 0.75 * 0.3, base, hd + 0.57)
		seat.display_name = "porch bench"
		add_child(seat)
	door = BuildingDoor.new()
	door.name = "Door"
	door.width = DOOR_W - 0.06
	door.height = DOOR_H - 0.04
	door.panel_color = door_color
	door.position = Vector3(door_offset - DOOR_W * 0.5 + 0.03, base, hd - WALL_T * 0.5)
	add_child(door)

	# Interior (furniture + interactive items).
	interior_root = Node3D.new()
	interior_root.name = "Interior"
	add_child(interior_root)
	# v7b.1 perf (InteriorStreamer): homes furnish their interior only when the
	# player comes to the door / enters, and free it again when far away.
	if not Engine.is_editor_hint() and InteriorStreamer.lazy_for(self):
		_interior_args = [interior_theme, Vector3(w - WALL_T * 2.0, h, d - WALL_T * 2.0), rng.seed, rng.state]
		interior_built = false
	else:
		_interior_args = []
		interior_built = true
		InteriorBuilder.build(self, interior_root, interior_theme, Vector3(w - WALL_T * 2.0, h, d - WALL_T * 2.0), rng)

	_interior_light = OmniLight3D.new()
	_interior_light.name = "InteriorLight"
	_interior_light.position = Vector3(0, top - 0.5, 0)
	_interior_light.omni_range = maxf(w, d) * 0.95
	_interior_light.light_energy = 1.6
	_interior_light.light_color = Color(1.0, 0.86, 0.68)
	_interior_light.shadow_enabled = false
	_interior_light.visible = false
	add_child(_interior_light)
	if not Engine.is_editor_hint():
		_apply_power()
		if not PowerGrid.power_changed.is_connected(_on_power_changed):
			PowerGrid.power_changed.connect(_on_power_changed)

	if not Engine.is_editor_hint():
		var area := Area3D.new()
		area.name = "InsideArea"
		area.collision_layer = 0
		area.collision_mask = 2
		area.monitorable = false
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(w - WALL_T * 2.0 - 0.3, h, d - WALL_T * 2.0 - 0.3)
		shape.shape = box
		shape.position = Vector3(0, base + h * 0.5, 0)
		area.add_child(shape)
		add_child(area)
		area.body_entered.connect(func(body: Node3D) -> void:
			if body.is_in_group(&"player"):
				_set_inside(true))
		area.body_exited.connect(func(body: Node3D) -> void:
			if body.is_in_group(&"player"):
				_set_inside(false))


func add_gable_to(width: float, height: float, depth: float, pos: Vector3, mat: Material, rot: Vector3, parent: Node3D) -> void:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(width, height, depth)
	_add_mesh(mesh, pos, mat, rot, parent)


func _wall(box_size: Vector3, pos: Vector3, outer: Material, inner: Material, inward: Vector3, parent: Node3D) -> void:
	if box_size.x <= 0.01 or box_size.z <= 0.01 or box_size.y <= 0.01:
		return
	# Outer part (2/3 thickness) + inner paint layer (1/3), split along the inward axis.
	var inner_t := WALL_T * 0.34
	var outer_size := box_size
	var inner_size := box_size
	if absf(inward.z) > 0.5:
		outer_size.z = WALL_T - inner_t
		inner_size.z = inner_t
	else:
		outer_size.x = WALL_T - inner_t
		inner_size.x = inner_t
	add_box(outer_size, pos - inward * inner_t * 0.5, outer, Vector3.ZERO, parent)
	add_box(inner_size, pos + inward * (WALL_T - inner_t) * 0.5, inner, Vector3.ZERO, parent)
	add_box_collider(box_size, pos)


func _ramp(from: Vector3, to: Vector3, width: float) -> void:
	if _visual_only:
		return
	# Invisible slope from the ground (from) up to the floor (to); the farmer
	# can't step up ledges, so every doorway gets one.
	var run := absf(to.z - from.z)
	var rise := to.y - from.y
	var length := sqrt(run * run + rise * rise)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 0.1, length + 0.1)
	shape.shape = box
	var angle := atan2(rise, run) * (1.0 if to.z < from.z else -1.0)
	shape.rotation = Vector3(angle, 0, 0)
	var up := Basis(Vector3.RIGHT, angle) * Vector3.UP
	shape.position = (from + to) * 0.5 - up * 0.05
	_body.add_child(shape)


func _sign_board(text: String, parent: Node3D) -> void:
	var w := clampf(text.length() * 0.24 + 0.8, 1.6, size.x * 0.9)
	var y := FOUNDATION_HEIGHT + size.y + 0.5
	var z := size.z * 0.5 + 0.62
	var board_mat := color_material(Color(0.26, 0.17, 0.1), 0.7)
	add_box(Vector3(w, 0.62, 0.08), Vector3(door_offset, y, z), board_mat, Vector3.ZERO, parent)
	add_box(Vector3(w + 0.1, 0.06, 0.1), Vector3(door_offset, y + 0.33, z), color_material(Color(0.8, 0.65, 0.3), 0.4, false), Vector3.ZERO, parent)
	add_box(Vector3(w + 0.1, 0.06, 0.1), Vector3(door_offset, y - 0.33, z), color_material(Color(0.8, 0.65, 0.3), 0.4, false), Vector3.ZERO, parent)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.05, 0.9, 0.05), Vector3(door_offset + sx * (w * 0.5 - 0.2), y - 0.55, z - 0.3), board_mat, Vector3(0.6, 0, 0), parent)
	sign_label = _label(SignText.sign_of(text), 72, 0.0075, Color(1.0, 0.95, 0.82))
	Lang.setup_label3d(sign_label, 72)
	sign_label.outline_size = 10
	sign_label.name = "SignLabel"
	sign_label.position = Vector3(door_offset, y, z + 0.05)
	sign_label.width = w / 0.0075
	sign_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	add_child(sign_label)


func _address_plaque(text: String, parent: Node3D) -> void:
	var x := door_offset + DOOR_W * 0.5 + 0.55
	var y := FOUNDATION_HEIGHT + 1.75
	var z := size.z * 0.5 + 0.03
	add_box(Vector3(0.95, 0.3, 0.04), Vector3(x, y, z), color_material(Color(0.14, 0.24, 0.42), 0.5, false), Vector3.ZERO, parent)
	address_label = _label(SignText.address(text), 40, 0.0042, Color(1, 1, 1))
	Lang.setup_label3d(address_label, 40)
	address_label.name = "AddressLabel"
	address_label.position = Vector3(x, y, z + 0.03)
	address_label.outline_size = 4
	add_child(address_label)
	fit_address()


## v6b: shrink the address text to fit the 0.95 m plaque (Persian addresses are longer).
func fit_address() -> void:
	if address_label == null:
		return
	var f := address_label.font if address_label.font else ThemeDB.fallback_font
	var w := f.get_string_size(address_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, address_label.font_size).x
	address_label.pixel_size = minf(0.0042, 0.86 / maxf(w, 1.0))


func _label(text: String, font_size: int, pixel: float, color: Color) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = font_size
	l.pixel_size = pixel
	l.modulate = color
	l.outline_size = 10
	l.outline_modulate = Color(0.08, 0.05, 0.03, 0.9)
	l.double_sided = false
	l.visibility_range_end = 90.0
	l.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return l


func _porch(_rng: RandomNumberGenerator, parent: Node3D, roof_mat: Material) -> void:
	var wood := color_material(Color(0.5, 0.36, 0.24), 0.85)
	var base := FOUNDATION_HEIGHT
	var d := size.z
	var pw := size.x * 0.75
	var depth := 1.8
	add_box(Vector3(pw, 0.16, depth), Vector3(door_offset, base - 0.08, d * 0.5 + depth * 0.5), wood, Vector3.ZERO, parent)
	add_box_collider(Vector3(pw, base, depth), Vector3(door_offset, base * 0.5, d * 0.5 + depth * 0.5))
	for px in [-pw * 0.5 + 0.12, pw * 0.5 - 0.12]:
		add_box(Vector3(0.14, 2.4, 0.14), Vector3(door_offset + px, base + 1.15, d * 0.5 + depth - 0.12), wood, Vector3.ZERO, parent)
		add_cylinder_collider(0.1, 2.4, Vector3(door_offset + px, base + 1.15, d * 0.5 + depth - 0.12))
	add_box(Vector3(pw + 0.3, 0.1, depth + 0.35), Vector3(door_offset, base + 2.4, d * 0.5 + depth * 0.5 + 0.05), roof_mat, Vector3(0.18, 0, 0), parent)
	add_box(Vector3(1.4, 0.15, 0.5), Vector3(door_offset, base * 0.3, d * 0.5 + depth + 0.25), wood, Vector3.ZERO, parent)
	_ramp(Vector3(door_offset, 0.0, d * 0.5 + depth + 0.9), Vector3(door_offset, base, d * 0.5 + depth - 0.1), 1.6)
	# Porch bench (a real seat) and a barrel.
	var bench_pos := Vector3(door_offset - pw * 0.3, base, d * 0.5 + 0.45)
	add_box(Vector3(1.2, 0.08, 0.4), bench_pos + Vector3(0, 0.44, 0), wood, Vector3.ZERO, parent)
	add_box(Vector3(1.2, 0.42, 0.06), bench_pos + Vector3(0, 0.72, -0.18), wood, Vector3.ZERO, parent)
	for sx in [-0.5, 0.5]:
		add_box(Vector3(0.06, 0.44, 0.36), bench_pos + Vector3(sx, 0.22, 0), wood, Vector3.ZERO, parent)
	add_box_collider(Vector3(1.2, 0.46, 0.42), bench_pos + Vector3(0, 0.23, 0))
	if not Engine.is_editor_hint() and not has_node(^"PorchSeat"):
		var seat := Seat.new()
		seat.name = "PorchSeat"
		seat.position = bench_pos + Vector3(0, 0, 0.12)
		seat.display_name = "porch bench"
		add_child(seat)
	add_cylinder(0.3, 0.27, 0.75, Vector3(door_offset + pw * 0.38, base + 0.38, d * 0.5 + 0.4), color_material(Color(0.45, 0.3, 0.18), 0.8), Vector3.ZERO, 16, parent)


## Lantern on the front wall next to the door; glows when the night lights
## are on and the power is on (PowerFx.bulb_material, animated by NightLights).
func _wall_lantern(parent: Node3D) -> void:
	var x := door_offset - DOOR_W * 0.5 - 0.42
	var y := FOUNDATION_HEIGHT + 2.05
	var z := size.z * 0.5 + 0.02
	var iron := color_material(Color(0.12, 0.12, 0.13), 0.45, false)
	add_box(Vector3(0.08, 0.3, 0.06), Vector3(x, y, z + 0.03), iron, Vector3.ZERO, parent)
	add_box(Vector3(0.05, 0.05, 0.22), Vector3(x, y + 0.12, z + 0.13), iron, Vector3.ZERO, parent)
	add_box(Vector3(0.18, 0.04, 0.18), Vector3(x, y + 0.1, z + 0.24), iron, Vector3.ZERO, parent)
	add_box(Vector3(0.14, 0.2, 0.14), Vector3(x, y - 0.03, z + 0.24), PowerFx.bulb_material(), Vector3.ZERO, parent)
	add_box(Vector3(0.16, 0.03, 0.16), Vector3(x, y - 0.15, z + 0.24), iron, Vector3.ZERO, parent)
	if Engine.is_editor_hint():
		return
	var world := global_transform * Vector3(x, y - 0.05, z + 0.5)
	if sleep_here:
		# The farmhouse gets its own porch light (always a real light).
		var light := OmniLight3D.new()
		light.name = "PorchLight"
		light.position = Vector3(x, y - 0.05, z + 0.45)
		light.omni_range = 8.0
		light.omni_attenuation = 1.2
		light.light_energy = 0.0
		light.visible = false
		light.shadow_enabled = false
		light.add_to_group(&"porch_lights")
		add_child(light)
		# Hanging lamp under the porch roof as well.
		if has_porch:
			var lp := Vector3(door_offset + 0.9, FOUNDATION_HEIGHT + 2.05, size.z * 0.5 + 1.2)
			add_box(Vector3(0.02, 0.3, 0.02), lp + Vector3(0, 0.2, 0), iron, Vector3.ZERO, parent)
			add_box(Vector3(0.2, 0.2, 0.2), lp, PowerFx.bulb_material(), Vector3.ZERO, parent)
			add_box(Vector3(0.26, 0.05, 0.26), lp + Vector3(0, 0.12, 0), iron, Vector3.ZERO, parent)
			var l2 := OmniLight3D.new()
			l2.name = "PorchHangingLight"
			l2.position = lp + Vector3(0, -0.2, 0)
			l2.omni_range = 6.0
			l2.light_energy = 0.0
			l2.visible = false
			l2.shadow_enabled = false
			l2.add_to_group(&"porch_lights")
			add_child(l2)
	else:
		if not has_meta(&"porch_registered"):
			NightLights.porch_positions.append(world)
			set_meta(&"porch_registered", true)


## Farmhouse: main power switch (BreakerBox) on the front wall.
func _farmhouse_power() -> void:
	var box := BreakerBox.new()
	box.name = "BreakerBox"
	box.position = Vector3(door_offset + DOOR_W * 0.5 + 1.75, FOUNDATION_HEIGHT + 1.35, size.z * 0.5 + 0.01)
	add_child(box)


func _apply_power() -> void:
	if _interior_light == null:
		return
	var st := Modules.style("lighting") as LightingStyle
	if PowerGrid.power_on:
		_interior_light.light_color = st.bulb_color if st else Color(1.0, 0.86, 0.68)
		_interior_light.light_energy = 1.6
	else:
		_interior_light.light_color = st.candle_color if st else Color(1.0, 0.55, 0.2)
		_interior_light.light_energy = 0.55


# ------------------------------------------------------------------ runtime
func _process(delta: float) -> void:
	if Engine.is_editor_hint() or interior_root == null:
		return
	_check_timer -= delta
	if _check_timer > 0.0:
		return
	_check_timer = 0.3
	var cam := get_viewport().get_camera_3d()
	var near := player_inside
	if cam:
		near = near or cam.global_position.distance_to(global_position) < INTERIOR_VISIBLE_DISTANCE
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player:
		near = near or player.global_position.distance_to(global_position) < INTERIOR_VISIBLE_DISTANCE
	# v7a: a demolished house has no interior to show (BuildingDamage).
	if wrecked:
		near = false
	# v7b.1 perf: furnish only at the door (not for every house passed on the
	# street - that churn caused walking hitches), max one build per frame
	# across the town; free after a long while far away.
	if not _interior_args.is_empty():
		var dpos := door_world_position(1.0)
		var dd := player.global_position.distance_to(dpos) if player else 999.0
		if player_inside or (dd < InteriorStreamer.build_distance() and not wrecked):
			_interior_far_time = 0.0
			if not interior_built and InteriorStreamer.can_build_now():
				ensure_interior()
		elif interior_built:
			_interior_far_time = _interior_far_time + 0.3 if dd > InteriorStreamer.release_distance() else 0.0
			if _interior_far_time > InteriorStreamer.release_after():
				release_interior()
	if interior_root.visible != near:
		interior_root.visible = near
		interior_root.process_mode = Node.PROCESS_MODE_INHERIT if near else Node.PROCESS_MODE_DISABLED


func _set_inside(value: bool) -> void:
	if value == player_inside:
		return
	player_inside = value
	if value:
		ensure_exterior()
		ensure_interior()
	if roof_mesh:
		roof_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY if value else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	if sign_label:
		sign_label.visible = not value
	if _interior_light:
		_interior_light.visible = value
	if value:
		interior_root.visible = true
		interior_root.process_mode = Node.PROCESS_MODE_INHERIT
		player_entered.emit(self)
		GameEvents.building_entered.emit(self)
	else:
		player_exited.emit(self)
		GameEvents.building_exited.emit(self)


func _on_power_changed(_on: bool) -> void:
	_apply_power()


## Is the roof currently hidden (player inside)?
func roof_hidden() -> bool:
	return roof_mesh != null and roof_mesh.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY


## Shared window glass. Lit windows glow warmly at night (see set_night_glow).
static var _window_lit: StandardMaterial3D
static var _window_dark: StandardMaterial3D


static func window_material(lit: bool) -> StandardMaterial3D:
	if _window_lit == null:
		_window_dark = StandardMaterial3D.new()
		_window_dark.albedo_color = Color(0.16, 0.22, 0.28)
		_window_dark.roughness = 0.06
		_window_dark.metallic = 0.3
		_window_dark.metallic_specular = 0.9
		_window_lit = _window_dark.duplicate()
		_window_lit.emission_enabled = true
		_window_lit.emission = Color(1.0, 0.72, 0.38)
		_window_lit.emission_energy_multiplier = 0.0
	return _window_lit if lit else _window_dark


static var _window_inner: StandardMaterial3D


## Inside face of the glass: shows bright daylight sky by day, dark at night.
static func inner_window_material() -> StandardMaterial3D:
	if _window_inner == null:
		_window_inner = StandardMaterial3D.new()
		_window_inner.albedo_color = Color(0.55, 0.7, 0.85)
		_window_inner.roughness = 0.2
		_window_inner.emission_enabled = true
		_window_inner.emission = Color(0.72, 0.85, 1.0)
		_window_inner.emission_energy_multiplier = 0.9
	return _window_inner


## amount: 0 = day (plain glass), 1 = night. energy / colour of the lit
## windows come from NightLights (electric light, or candles in a power cut).
static func set_night_glow(amount: float, energy: float = -1.0, color: Color = Color(1.0, 0.72, 0.38)) -> void:
	if energy < 0.0:
		energy = amount * 2.2
	inner_window_material().emission_energy_multiplier = (1.0 - amount) * 0.9
	inner_window_material().albedo_color = Color(0.55, 0.7, 0.85).lerp(Color(0.05, 0.07, 0.12), amount)
	window_material(true).emission_energy_multiplier = energy
	window_material(true).emission = color
	window_material(true).albedo_color = Color(0.16, 0.22, 0.28).lerp(Color(0.45, 0.33, 0.2), minf(amount, energy))


func _window(pos: Vector3, yaw: float, trim: Material, rng: RandomNumberGenerator, parent: Node3D) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	var glass := window_material(rng.randf() < 0.7)
	add_box(Vector3(1.05, 1.2, 0.08), Vector3(0, 0, 0.02), trim, Vector3.ZERO, holder)
	add_box(Vector3(0.85, 1.0, 0.06), Vector3(0, 0, 0.05), glass, Vector3.ZERO, holder)
	add_box(Vector3(0.05, 1.0, 0.04), Vector3(0, 0, 0.09), trim, Vector3.ZERO, holder)
	add_box(Vector3(0.85, 0.05, 0.04), Vector3(0, 0, 0.09), trim, Vector3.ZERO, holder)
	add_box(Vector3(1.2, 0.08, 0.18), Vector3(0, -0.62, 0.08), trim, Vector3.ZERO, holder)
	# Inner side: frame + glass + sill.
	add_box(Vector3(1.0, 1.15, 0.03), Vector3(0, 0, -WALL_T - 0.01), trim, Vector3.ZERO, holder)
	add_box(Vector3(0.82, 0.95, 0.02), Vector3(0, 0, -WALL_T - 0.03), inner_window_material(), Vector3.ZERO, holder)
	add_box(Vector3(1.1, 0.05, 0.16), Vector3(0, -0.6, -WALL_T - 0.06), trim, Vector3.ZERO, holder)
	if rng.randf() < 0.75:
		var shutter := color_material(shutter_color, 0.75)
		for sx in [-1.0, 1.0]:
			add_box(Vector3(0.42, 1.12, 0.05), Vector3(sx * 0.76, 0, 0.04), shutter, Vector3.ZERO, holder)
	if rng.randf() < 0.5:
		add_box(Vector3(0.95, 0.16, 0.2), Vector3(0, -0.75, 0.14), color_material(Color(0.45, 0.3, 0.2), 0.8), Vector3.ZERO, holder)
		for i in 5:
			var col: Color = [Color(0.9, 0.3, 0.35), Color(0.95, 0.8, 0.3), Color(0.85, 0.5, 0.8)][rng.randi() % 3]
			add_sphere(0.07, Vector3(-0.36 + i * 0.18, -0.64, 0.15), color_material(col, 0.6, false), Vector3.ONE, holder)
