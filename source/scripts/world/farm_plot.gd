class_name FarmPlot
extends Node3D
## v4 garden (node "CropPlot" in Main.tscn). Beds (rows) of soil separated by
## walkable paths, a wooden fence with a gate, and an expansion sign.
##
##  - Each bed is 1.0 m wide and `cells_per_bed` cells long; one cell is
##    1.0 x 0.5 m = 0.5 m². Small crops take 1 cell (0.5 m²); bushes and trees
##    take 2 cells (1 m²). A crop can't be planted on ground another crop
##    already occupies (its footprint), so crops can't be crammed together.
##  - Hoe (E on grass) tills a cell: the turf turns into brown furrowed soil.
##    Then plant (E with seeds), water (darker soil), see sprouts, leaves,
##    flowers and fruit (CropDef stages) and harvest.
##  - Crops are modules (res://modules/crop_types/<id>/), the soil/path/fence
##    look is the "garden" module, and the season hook is the active
##    "garden_rules" module (can_plant / growth_multiplier / withers).
##  - The garden can be expanded with extra beds (sign by the gate).
##
## The node sits at TownLayout.GARDEN_ORIGIN (front-centre, gate side); beds
## extend towards -Z.

signal garden_changed
signal expanded(beds: int)
## v6b: the farmer watered at least one planted bed (yard routine).
signal watered_beds(count: int)

enum TileState { UNTILLED, TILLED, PLANTED }

const CELL_LEN := 0.5
const BED_W := 1.0
const PATH_W := 0.6
const FRONT_PATH := 0.8
const BACK_MARGIN := 0.4
const FENCE_MARGIN := 0.35
const GATE_W := 1.5

@export var cells_per_bed: int = 12
@export var beds: int = 3
@export var max_beds: int = 5
@export var height_offset: float = 0.0
## Kept for scene compatibility (v3); the look now comes from the garden module.
@export var tilled_material: Material
@export var untilled_material: Material

## Compatibility with v3 tests/tools: columns = cells per bed, rows = beds.
var columns: int:
	get: return cells_per_bed
var rows: int:
	get: return beds

var tiles: Array[Dictionary] = []
var _zone: Interactable
var _zone_shape: BoxShape3D
var _cursor: Node3D
var _cursor_bars: Array[MeshInstance3D] = []
var _target_tile: int = -1
var _player: Node3D
var _bed_nodes: Array[Node3D] = []
var _static_root: Node3D
var _fence_body: StaticBody3D
var _sign: Interactable
var _snow: MeshInstance3D
var _mats: Dictionary = {}
var _dirty_beds: Dictionary = {}


func _ready() -> void:
	add_to_group(&"farm_plot")
	add_to_group(&"garden")
	for child in get_children():
		# v3 static soil box + borders are replaced by the generated beds.
		if child is MeshInstance3D:
			child.queue_free()
	var o := TownLayout.GARDEN_ORIGIN
	global_position = Vector3(o.x, Terrain.height_at(o.x, o.y - 4.0) + height_offset, o.y)
	Modules.on_swap("garden", self, func(_m: AssetModule) -> void:
		_mats.clear()
		_rebuild_static()
		_mark_all_dirty())
	Modules.on_swap("crops", self, func(_m: AssetModule) -> void: _mark_all_dirty())
	Modules.on_swap("crop_types", self, func(_m: AssetModule) -> void: _mark_all_dirty())
	Modules.on_swap("yards", self, func(_m: AssetModule) -> void: _rebuild_static())
	_static_root = Node3D.new()
	_static_root.name = "GardenStatic"
	add_child(_static_root)
	_build_zone()
	_build_cursor()
	_build_sign()
	_resize_tiles()
	_rebuild_static()
	TimeManager.day_started.connect(_on_day_started)
	TimeManager.season_changed.connect(_on_season_changed)
	_on_season_changed(TimeManager.season_index())
	_mark_all_dirty()


func style() -> GardenStyle:
	return Modules.style("garden") as GardenStyle


func rules() -> GardenRules:
	return Modules.style("garden_rules") as GardenRules


# ------------------------------------------------------------------ layout
func bed_center_z(b: int) -> float:
	return -(FRONT_PATH + b * (BED_W + PATH_W) + BED_W * 0.5)


func cell_local(b: int, c: int) -> Vector3:
	return Vector3((c - (cells_per_bed - 1) * 0.5) * CELL_LEN, 0.0, bed_center_z(b))


func garden_depth(bed_count: int = -1) -> float:
	var n := beds if bed_count < 0 else bed_count
	return FRONT_PATH + n * BED_W + maxi(n - 1, 0) * PATH_W + BACK_MARGIN


func garden_width() -> float:
	return cells_per_bed * CELL_LEN + 0.6


func bed_of(idx: int) -> int:
	@warning_ignore("integer_division")
	return idx / cells_per_bed


func cell_of(idx: int) -> int:
	return idx % cells_per_bed


func tile_index(b: int, c: int) -> int:
	return b * cells_per_bed + c


func tile_world_position(index: int) -> Vector3:
	return to_global(cell_local(bed_of(index), cell_of(index)))


func _resize_tiles() -> void:
	while tiles.size() < beds * cells_per_bed:
		tiles.append(_empty_tile())
	while _bed_nodes.size() < beds:
		var n := Node3D.new()
		n.name = "Bed%d" % _bed_nodes.size()
		add_child(n)
		_bed_nodes.append(n)


func _empty_tile() -> Dictionary:
	return {"state": TileState.UNTILLED, "crop": "", "growth": 0.0, "watered": false, "fertilized": false,
		"quality": 1.0, "dead": false, "owner": -1}


## Rect (local x/z) of the whole garden inside the fence.
func local_rect() -> Rect2:
	var w := garden_width()
	var d := garden_depth()
	return Rect2(-w * 0.5, -d, w, d)


## Path areas between/around the beds (local rects) - kept clear of plants.
func path_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var w := garden_width()
	out.append(Rect2(-w * 0.5, -FRONT_PATH, w, FRONT_PATH))
	for b in beds - 1:
		var z1 := bed_center_z(b) - BED_W * 0.5
		out.append(Rect2(-w * 0.5, z1 - PATH_W, w, PATH_W))
	out.append(Rect2(-w * 0.5, -garden_depth(), w, BACK_MARGIN))
	return out


func is_on_path(world: Vector3) -> bool:
	var l := to_local(world)
	for r in path_rects():
		if r.has_point(Vector2(l.x, l.z)):
			return true
	return false


# ------------------------------------------------------------------ expansion
func can_expand() -> bool:
	return beds < max_beds


func expand_cost() -> int:
	var st := style()
	return st.expand_cost if st else 150


## Adds one bed row (pays expand_cost unless free). Rebuilds fence, paths and zone.
func expand(free: bool = false) -> bool:
	if not can_expand():
		GameEvents.notification_requested.emit("The garden is as big as the farm allows")
		return false
	if not free:
		if Economy.money < expand_cost():
			GameEvents.notification_requested.emit("Expanding needs %d G" % expand_cost())
			return false
		Economy.add_money(-expand_cost())
	beds += 1
	_resize_tiles()
	_rebuild_static()
	_mark_all_dirty()
	expanded.emit(beds)
	GameEvents.notification_requested.emit("Garden expanded: %d beds" % beds)
	return true


# ------------------------------------------------------------------ zone / cursor / sign
func _build_zone() -> void:
	_zone = Interactable.new()
	_zone.name = "FarmZone"
	_zone.collision_layer = 8
	_zone.collision_mask = 2
	_zone.action_text = "till the soil"
	var shape := CollisionShape3D.new()
	_zone_shape = BoxShape3D.new()
	shape.shape = _zone_shape
	shape.name = "ZoneShape"
	_zone.add_child(shape)
	add_child(_zone)
	_zone.interacted.connect(_on_interacted)


func _update_zone() -> void:
	var r := local_rect()
	_zone_shape.size = Vector3(r.size.x + 1.0, 3.0, r.size.y + 1.0)
	(_zone.get_node(^"ZoneShape") as CollisionShape3D).position = Vector3(r.get_center().x, 1.0, r.get_center().y)


func _build_cursor() -> void:
	_cursor = Node3D.new()
	_cursor.name = "Cursor"
	add_child(_cursor)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.95, 0.6, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for i in 4:
		var bar := MeshInstance3D.new()
		bar.mesh = BoxMesh.new()
		bar.material_override = mat
		bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_cursor.add_child(bar)
		_cursor_bars.append(bar)
	_cursor.visible = false
	_zone.focus_node = _cursor


func _size_cursor(len_x: float) -> void:
	var hx := len_x * 0.5 - 0.03
	var hz := BED_W * 0.5 - 0.03
	for i in 4:
		var bar := _cursor_bars[i]
		(bar.mesh as BoxMesh).size = Vector3(len_x - 0.04, 0.02, 0.035) if i < 2 else Vector3(0.035, 0.02, BED_W - 0.04)
		bar.position = [Vector3(0, 0.2, -hz), Vector3(0, 0.2, hz), Vector3(-hx, 0.2, 0), Vector3(hx, 0.2, 0)][i]


func _build_sign() -> void:
	_sign = Interactable.new()
	_sign.name = "ExpandSign"
	_sign.collision_layer = 8
	_sign.collision_mask = 2
	var shape := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.0
	shape.shape = sph
	shape.position.y = 0.8
	_sign.add_child(shape)
	add_child(_sign)
	_sign.interacted.connect(func(who: Node3D) -> void:
		if expand() and who and who.has_method("play_tool"):
			who.call("play_tool", "hammer"))


func _update_sign() -> void:
	var w := garden_width()
	_sign.position = Vector3(-w * 0.5 - FENCE_MARGIN - 0.9, 0.0, 0.6)
	_sign.set_action_text(("expand the garden (+1 bed, %d G)" % expand_cost()) if can_expand() else "read the sign (garden fully expanded)")


# ------------------------------------------------------------------ targeting
func _physics_process(_delta: float) -> void:
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
		if _player == null:
			return
	for b in _dirty_beds.keys():
		_rebuild_bed(int(b))
	_dirty_beds.clear()
	var idx := _pick_tile()
	_target_tile = idx
	_cursor.visible = idx >= 0 and to_local(_player.global_position).distance_to(cell_local(bed_of(idx), cell_of(idx))) < 3.0
	if idx >= 0:
		var anchor := anchor_of(idx)
		var span := _span(anchor) if tiles[anchor]["state"] == TileState.PLANTED else _planned_span(idx)
		var first := cell_local(bed_of(span[0]), cell_of(span[0]))
		var last := cell_local(bed_of(span[span.size() - 1]), cell_of(span[span.size() - 1]))
		_cursor.position = (first + last) * 0.5
		_size_cursor(CELL_LEN * span.size())
	_zone.set_action_text(_action_text(idx))


## Tile index in front of the farmer (-1 = facing a path / outside).
func _pick_tile() -> int:
	var facing := Vector3(0, 0, 1)
	if _player.has_method("facing_direction"):
		facing = _player.call("facing_direction")
	return tile_at(_player.global_position + facing * 0.7)


func tile_at(world: Vector3) -> int:
	var p := to_local(world)
	var c := int(floor(p.x / CELL_LEN + cells_per_bed * 0.5))
	if c < 0 or c >= cells_per_bed:
		return -1
	for b in beds:
		if absf(p.z - bed_center_z(b)) <= BED_W * 0.5 + 0.12:
			return tile_index(b, c)
	return -1


func anchor_of(idx: int) -> int:
	var o := int(tiles[idx].get("owner", -1))
	return o if o >= 0 else idx


func _span(anchor: int) -> Array[int]:
	var out: Array[int] = [anchor]
	var crop := GameData.crop_def(str(tiles[anchor]["crop"]))
	if crop and crop.cells() > 1:
		for i in tiles.size():
			if i != anchor and int(tiles[i].get("owner", -1)) == anchor:
				out.append(i)
	out.sort()
	return out


## Cells a new planting at idx would use (with the selected seed).
func _planned_span(idx: int) -> Array[int]:
	var crop := GameData.crop_def(str(GameData.item(Economy.selected_seed).get("crop", "")))
	if crop == null or crop.cells() < 2 or tiles[idx]["state"] != TileState.TILLED:
		return [idx]
	var partner := _partner_cell(idx, crop.cells())
	if partner < 0:
		return [idx]
	var out: Array[int] = [idx, partner]
	out.sort()
	return out


func _cell_free(i: int) -> bool:
	return tiles[i]["state"] != TileState.PLANTED and int(tiles[i].get("owner", -1)) < 0


## Neighbour cell in the same bed for a 2-cell (1 m²) crop, -1 if none free.
func _partner_cell(idx: int, _cells: int) -> int:
	var b := bed_of(idx)
	var c := cell_of(idx)
	for dc in [1, -1]:
		var nc: int = c + dc
		if nc >= 0 and nc < cells_per_bed and _cell_free(tile_index(b, nc)):
			return tile_index(b, nc)
	return -1


func _crop_name(id: String) -> String:
	var def := GameData.crop_def(id)
	return def.display_name if def else id.capitalize()


func _action_text(idx: int) -> String:
	if idx < 0:
		return "garden (stand on a path, face a bed)"
	var a := anchor_of(idx)
	var t := tiles[a]
	if t["state"] == TileState.PLANTED:
		var crop := str(t["crop"])
		var def := GameData.crop_def(crop)
		var name_l := _crop_name(crop).to_lower()
		if t["dead"]:
			return "clear the withered %s" % name_l
		if is_mature(a):
			return "harvest the %s" % name_l
		if not t["watered"]:
			if Economy.water <= 0:
				return "water the %s (can is empty - refill at the well/pond)" % name_l
			return "water the %s (can %d/%d)" % [name_l, Economy.water, Economy.can_capacity()]
		var stage := def.stage_at(float(t["growth"])) if def else 0
		return "check the %s (%s, watered)" % [name_l, CropDef.STAGES[stage]]
	if t["state"] == TileState.UNTILLED:
		return "till the soil (hoe)"
	var seed_id := Economy.selected_seed
	if seed_id == "":
		return "plant (no seeds - buy some in town)"
	var why := plant_block_reason(idx, seed_id)
	if why != "":
		return "plant - " + why
	var crop_def := GameData.crop_def(str(GameData.item(seed_id).get("crop", "")))
	return "plant %s (%s m², %d left)" % [GameData.item_name(seed_id).to_lower(), str(crop_def.footprint_m2) if crop_def else "?", Economy.count(seed_id)]


func _on_interacted(_interactor: Node3D) -> void:
	if _target_tile < 0:
		return
	var result := use_tile(_target_tile)
	if _interactor and _interactor.has_method("play_tool"):
		_interactor.call("play_tool", {"tilled": "hoe", "watered": "watering_can", "planted": "seeds", "harvested": "hands", "cleared": "hoe"}.get(result, "hands"))


## Context action on a tile (what pressing E does). Returns a short result id.
func use_tile(idx: int) -> String:
	var a := anchor_of(idx)
	var t := tiles[a]
	if t["state"] == TileState.PLANTED:
		if t["dead"]:
			_clear(a)
			return "cleared"
		if is_mature(a):
			harvest(a)
			return "harvested"
		if not t["watered"]:
			return "watered" if water(a) else "no_water"
		GameEvents.notification_requested.emit("Growing nicely - come back tomorrow")
		return "info"
	if t["state"] == TileState.UNTILLED:
		return "tilled" if till(idx) else "no_hoe"
	var seed_id := Economy.selected_seed
	if seed_id == "":
		GameEvents.notification_requested.emit("No seeds - buy some at the town market")
		return "no_seed"
	return "planted" if plant(idx, seed_id) else "blocked"


# ------------------------------------------------------------------ actions
func till(idx: int) -> bool:
	if not Economy.has("hoe") or idx < 0 or tiles[idx]["state"] != TileState.UNTILLED or int(tiles[idx].get("owner", -1)) >= 0:
		return false
	tiles[idx]["state"] = TileState.TILLED
	_mark_dirty(idx)
	# Tool upgrade: a better hoe tills more cells along the bed per swing.
	var hoe := Economy.best_tool("hoe")
	var extra := (hoe.reach - 1) if hoe else 0
	var c := cell_of(idx)
	for k in range(1, extra + 1):
		if c + k >= cells_per_bed:
			break
		var j := tile_index(bed_of(idx), c + k)
		if tiles[j]["state"] == TileState.UNTILLED and int(tiles[j].get("owner", -1)) < 0:
			tiles[j]["state"] = TileState.TILLED
			_mark_dirty(j)
	return true


## "" if the seed can be planted on idx, else a short reason.
func plant_block_reason(idx: int, seed_id: String) -> String:
	if idx < 0:
		return "not on a bed"
	var t := tiles[idx]
	if t["state"] == TileState.PLANTED or int(t.get("owner", -1)) >= 0:
		return "this spot is taken by the %s" % _crop_name(str(tiles[anchor_of(idx)]["crop"])).to_lower()
	if t["state"] != TileState.TILLED:
		return "till the soil first"
	var crop_id := str(GameData.item(seed_id).get("crop", ""))
	var def := GameData.crop_def(crop_id)
	if def == null:
		return "not a seed"
	var r := rules()
	if r and not r.can_plant(def, TimeManager.season_id()):
		return "%s only grows in %s" % [def.display_name, ", ".join(def.seasons).capitalize()]
	if def.cells() > 1 and _partner_cell(idx, def.cells()) < 0:
		return "a %s needs %s m² - too close to other crops" % [def.display_name.to_lower(), str(def.footprint_m2)]
	return ""


func plant(idx: int, seed_id: String) -> bool:
	if idx < 0 or not Economy.has(seed_id):
		return false
	var why := plant_block_reason(idx, seed_id)
	if why != "":
		GameEvents.notification_requested.emit("Can't plant: " + why)
		return false
	var crop_id := str(GameData.item(seed_id).get("crop", ""))
	var def := GameData.crop_def(crop_id)
	Economy.remove_item(seed_id, 1)
	var t := tiles[idx]
	t["state"] = TileState.PLANTED
	t["crop"] = crop_id
	t["growth"] = 0.0
	t["quality"] = 1.0
	t["dead"] = false
	t["owner"] = -1
	t["fertilized"] = Economy.remove_item("fertilizer", 1)
	t["watered"] = bool(GameData.weather(TimeManager.weather_id).get("waters_crops", false))
	if def.cells() > 1:
		var partner := _partner_cell(idx, def.cells())
		var p := tiles[partner]
		p["state"] = TileState.TILLED
		p["owner"] = idx
		_mark_dirty(partner)
	_mark_dirty(idx)
	return true


func water(idx: int) -> bool:
	if not Economy.has("watering_can"):
		return false
	if Economy.water <= 0:
		GameEvents.notification_requested.emit("The watering can is empty - refill it at the well, the pond or the sea")
		return false
	var targets: Array[int] = [anchor_of(idx)]
	if Economy.has("copper_can"):
		targets = _neighbourhood(anchor_of(idx))
	var any := false
	for i in targets:
		var a := anchor_of(i)
		if tiles[a]["state"] == TileState.PLANTED and not tiles[a]["dead"] and not tiles[a]["watered"]:
			tiles[a]["watered"] = true
			_mark_dirty(a)
			any = true
	if any:
		Economy.use_water()
		watered_beds.emit(targets.size())
	return any


## Snapshot for SaveGame.
func to_save() -> Dictionary:
	var out: Array = []
	for t in tiles:
		out.append({"state": int(t["state"]), "crop": t["crop"], "growth": t["growth"], "watered": t["watered"],
			"dead": t.get("dead", false), "quality": t.get("quality", 1.0), "fertilized": t.get("fertilized", false),
			"owner": int(t.get("owner", -1))})
	return {"beds": beds, "cells_per_bed": cells_per_bed, "tiles": out}


func from_save(data: Variant) -> void:
	var list: Array = []
	if data is Dictionary:
		var want := clampi(int((data as Dictionary).get("beds", beds)), 1, max_beds)
		if want != beds:
			beds = want
			for i in range(tiles.size() - 1, -1, -1):
				if i >= beds * cells_per_bed:
					tiles.remove_at(i)
			_resize_tiles()
			_rebuild_static()
		list = (data as Dictionary).get("tiles", [])
	elif data is Array:
		list = data  # v3 saves: old 4x6 grid - ignored layout, keep states in order
	for i in tiles.size():
		tiles[i] = _empty_tile()
	for i in mini(list.size(), tiles.size()):
		var d: Dictionary = list[i]
		var t := tiles[i]
		t["state"] = int(d.get("state", 0)) as TileState
		t["crop"] = str(d.get("crop", ""))
		t["growth"] = float(d.get("growth", 0.0))
		t["watered"] = bool(d.get("watered", false))
		t["dead"] = bool(d.get("dead", false))
		t["quality"] = float(d.get("quality", 1.0))
		t["fertilized"] = bool(d.get("fertilized", false))
		t["owner"] = int(d.get("owner", -1))
		if t["state"] == TileState.PLANTED and GameData.crop_def(str(t["crop"])) == null:
			t["state"] = TileState.TILLED
			t["crop"] = ""
	_mark_all_dirty()


func _neighbourhood(idx: int) -> Array[int]:
	var out: Array[int] = []
	var c0 := cell_of(idx)
	var b0 := bed_of(idx)
	for b in range(b0 - 1, b0 + 2):
		for c in range(c0 - 2, c0 + 3):
			if c >= 0 and c < cells_per_bed and b >= 0 and b < beds:
				out.append(tile_index(b, c))
	return out


func is_mature(idx: int) -> bool:
	var t := tiles[anchor_of(idx)]
	if t["state"] != TileState.PLANTED or t["dead"]:
		return false
	var def := GameData.crop_def(str(t["crop"]))
	return def != null and float(t["growth"]) >= def.total_days() - 0.001


## Growth stage index (0..4, see CropDef.STAGES) of the crop on idx, -1 if none.
func stage_of(idx: int) -> int:
	var t := tiles[anchor_of(idx)]
	if t["state"] != TileState.PLANTED:
		return -1
	var def := GameData.crop_def(str(t["crop"]))
	return def.stage_at(float(t["growth"])) if def else -1


func harvest(idx: int) -> int:
	var a := anchor_of(idx)
	if not is_mature(a):
		return 0
	var t := tiles[a]
	var def := GameData.crop_def(str(t["crop"]))
	var amount := maxi(1, int(round(float(def.yield_amount) * float(t["quality"]))))
	Economy.add_item(def.produce_item_id(), amount)
	GameEvents.notification_requested.emit("Harvested %d %s" % [amount, GameData.item_name(def.produce_item_id())])
	if def.is_perennial():
		t["growth"] = maxf(def.total_days() - def.regrow_days, 0.0)
		t["watered"] = false
		_mark_dirty(a)
	else:
		_clear(a)
	return amount


func _clear(idx: int) -> void:
	for i in _span(idx):
		var t := tiles[i]
		t["state"] = TileState.TILLED
		t["crop"] = ""
		t["growth"] = 0.0
		t["dead"] = false
		t["watered"] = false
		t["fertilized"] = false
		t["owner"] = -1
		_mark_dirty(i)


# ------------------------------------------------------------------ daily update
func _on_day_started(_day: int) -> void:
	var yesterday := GameData.weather(TimeManager.yesterday_weather_id)
	var today := GameData.weather(TimeManager.weather_id)
	var r := rules()
	var season := TimeManager.season_id()
	for i in tiles.size():
		var t := tiles[i]
		if t["state"] != TileState.PLANTED or t["dead"]:
			continue
		var def := GameData.crop_def(str(t["crop"]))
		if t["watered"]:
			var rate := 1.5 if t["fertilized"] else 1.0
			rate *= r.growth_multiplier(def, season, TimeManager.yesterday_weather_id) if r else 1.0
			if rate > 0.0:
				rate += float(yesterday.get("growth_bonus", 0.0))
			t["growth"] = minf(float(t["growth"]) + rate, def.total_days() if def else 99.0)
		t["quality"] = clampf(float(t["quality"]) + float(yesterday.get("quality_delta", 0.0)), 0.5, 1.3)
		t["watered"] = bool(today.get("waters_crops", false))
		if r and r.withers(def, season):
			t["dead"] = true
		_mark_dirty(i)


func _on_season_changed(season_index: int) -> void:
	var winter := str(GameData.season(season_index).get("id", "")) == "winter"
	if _snow:
		_snow.visible = winter
	var r := rules()
	for i in tiles.size():
		var t := tiles[i]
		if t["state"] == TileState.PLANTED and not t["dead"] and r and r.withers(GameData.crop_def(str(t["crop"])), TimeManager.season_id()):
			t["dead"] = true
		_mark_dirty(i)


## Grows every planted crop by `days` (dev/demo helper; also used by tests).
func debug_grow(days: float) -> void:
	for i in tiles.size():
		if tiles[i]["state"] == TileState.PLANTED and not tiles[i]["dead"]:
			var def := GameData.crop_def(str(tiles[i]["crop"]))
			tiles[i]["growth"] = minf(float(tiles[i]["growth"]) + days, def.total_days() if def else 99.0)
			_mark_dirty(i)


## Demo/test helper: put a crop at a given growth on a tile (no season check).
## Returns false if the crop's footprint doesn't fit.
func debug_set_tile(idx: int, crop_id: String, growth: float, watered: bool = true) -> bool:
	if tiles[idx]["state"] == TileState.PLANTED or int(tiles[idx].get("owner", -1)) >= 0:
		_clear(anchor_of(idx))
	var t := tiles[idx]
	if crop_id == "":
		t["state"] = TileState.TILLED
		_mark_dirty(idx)
		return true
	var def := GameData.crop_def(crop_id)
	if def == null:
		return false
	var partner := -1
	if def.cells() > 1:
		partner = _partner_cell(idx, def.cells())
		if partner < 0:
			return false
	t["state"] = TileState.PLANTED
	t["crop"] = crop_id
	t["growth"] = growth
	t["watered"] = watered
	t["dead"] = false
	t["quality"] = 1.0
	t["owner"] = -1
	if partner >= 0:
		tiles[partner]["state"] = TileState.TILLED
		tiles[partner]["owner"] = idx
		_mark_dirty(partner)
	_mark_dirty(idx)
	return true


## Counts for tests / UI.
func count_state(state: TileState) -> int:
	var n := 0
	for t in tiles:
		if t["state"] == state:
			n += 1
	return n


## Rebuilds dirty beds right away (tests / screenshots).
func flush() -> void:
	for b in _dirty_beds.keys():
		_rebuild_bed(int(b))
	_dirty_beds.clear()


func plant_node(idx: int) -> Node3D:
	var b := bed_of(anchor_of(idx))
	if b >= _bed_nodes.size():
		return null
	return _bed_nodes[b].get_node_or_null("Plant_%d" % anchor_of(idx)) as Node3D


# ------------------------------------------------------------------ visuals
func _mark_dirty(idx: int) -> void:
	_dirty_beds[bed_of(idx)] = true
	garden_changed.emit()


func _mark_all_dirty() -> void:
	for b in beds:
		_dirty_beds[b] = true


func _ground_mat(kind: String) -> ShaderMaterial:
	if _mats.has(kind):
		return _mats[kind]
	var st := style()
	var m := ShaderMaterial.new()
	m.shader = preload("res://assets/shaders/garden_ground.gdshader")
	match kind:
		"dry":
			var c := st.soil_dry if st else Color(0.4, 0.27, 0.16)
			m.set_shader_parameter(&"color_a", c)
			m.set_shader_parameter(&"color_b", c.darkened(0.35))
			m.set_shader_parameter(&"furrows", 1.0)
			m.set_shader_parameter(&"speckle", 0.25)
			m.set_shader_parameter(&"speckle_color", c.lightened(0.3))
		"wet":
			var c := st.soil_wet if st else Color(0.24, 0.16, 0.1)
			m.set_shader_parameter(&"color_a", c)
			m.set_shader_parameter(&"color_b", c.darkened(0.3))
			m.set_shader_parameter(&"furrows", 1.0)
			m.set_shader_parameter(&"speckle", 0.1)
			m.set_shader_parameter(&"speckle_color", c.lightened(0.2))
			m.set_shader_parameter(&"roughness_v", 0.55)
		"turf":
			m.set_shader_parameter(&"color_a", Color(0.33, 0.47, 0.17))
			m.set_shader_parameter(&"color_b", Color(0.24, 0.36, 0.12))
			m.set_shader_parameter(&"furrows", 0.0)
			m.set_shader_parameter(&"speckle", 0.35)
			m.set_shader_parameter(&"speckle_color", Color(0.45, 0.55, 0.22))
		_:  # path
			var c := st.path_color if st else Color(0.62, 0.55, 0.42)
			m.set_shader_parameter(&"color_a", c)
			m.set_shader_parameter(&"color_b", c.darkened(0.18))
			m.set_shader_parameter(&"furrows", 0.0)
			m.set_shader_parameter(&"speckle", 0.6)
			m.set_shader_parameter(&"speckle_color", c.lightened(0.25))
	_mats[kind] = m
	return m


func _hash01(a: float, b: float) -> float:
	return fposmod(sin(a * 12.9898 + b * 78.233) * 43758.5453, 1.0)


## Furrowed mound for one tilled cell (natural, slightly uneven soil).
func _add_mound(st: SurfaceTool, b: int, c: int, joined_left: bool, joined_right: bool) -> void:
	var centre := cell_local(b, c)
	var nx := 5
	var nz := 7
	var x0 := centre.x - CELL_LEN * 0.5
	var z0 := centre.z - BED_W * 0.5 + 0.06
	var dz := (BED_W - 0.12) / (nz - 1)
	var dx := CELL_LEN / (nx - 1)
	var raised := style() != null and style().raised_beds
	var base_y := 0.1 if raised else 0.0
	var grid: Array[Vector3] = []
	for iz in nz:
		for ix in nx:
			var x := x0 + ix * dx
			var z := z0 + iz * dz
			var tz := float(iz) / (nz - 1)
			var across := pow(sin(PI * tz), 0.55)
			var ex := 1.0
			if ix == 0 and not joined_left:
				ex = 0.35
			elif ix == nx - 1 and not joined_right:
				ex = 0.35
			var jitter := (_hash01(x * 3.1, z * 2.7) - 0.5) * 0.03
			var furrow := 0.018 * sin(z * 4.0 * TAU)
			grid.append(Vector3(x, base_y + 0.015 + 0.1 * across * ex + jitter * across + furrow * across, z))
	for iz in nz - 1:
		for ix in nx - 1:
			var a := grid[iz * nx + ix]
			var bb := grid[iz * nx + ix + 1]
			var cc := grid[(iz + 1) * nx + ix]
			var dd := grid[(iz + 1) * nx + ix + 1]
			var n1 := (cc - a).cross(bb - a).normalized()
			var n2 := (cc - bb).cross(dd - bb).normalized()
			for v: Vector3 in [a, cc, bb]:
				st.set_normal(n1)
				st.add_vertex(v)
			for v: Vector3 in [bb, cc, dd]:
				st.set_normal(n2)
				st.add_vertex(v)


func _add_quad(st: SurfaceTool, r: Rect2, y: float) -> void:
	var a := Vector3(r.position.x, y, r.position.y)
	var b := Vector3(r.end.x, y, r.position.y)
	var c := Vector3(r.position.x, y, r.end.y)
	var d := Vector3(r.end.x, y, r.end.y)
	for v: Vector3 in [a, c, b, b, c, d]:
		st.set_normal(Vector3.UP)
		st.add_vertex(v)


func _rebuild_bed(b: int) -> void:
	if b >= _bed_nodes.size():
		return
	var node := _bed_nodes[b]
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()
	var dry := SurfaceTool.new()
	dry.begin(Mesh.PRIMITIVE_TRIANGLES)
	var wet := SurfaceTool.new()
	wet.begin(Mesh.PRIMITIVE_TRIANGLES)
	var turf := SurfaceTool.new()
	turf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n_dry := 0
	var n_wet := 0
	var n_turf := 0
	for c in cells_per_bed:
		var i := tile_index(b, c)
		var t := tiles[i]
		if t["state"] == TileState.UNTILLED and int(t.get("owner", -1)) < 0:
			var centre := cell_local(b, c)
			_add_quad(turf, Rect2(centre.x - CELL_LEN * 0.5, centre.z - BED_W * 0.5, CELL_LEN, BED_W), 0.025)
			n_turf += 1
			continue
		var a := anchor_of(i)
		var is_wet: bool = bool(tiles[a]["watered"]) and tiles[a]["state"] == TileState.PLANTED
		var left: bool = c > 0 and tiles[i - 1]["state"] != TileState.UNTILLED
		var right: bool = c < cells_per_bed - 1 and tiles[i + 1]["state"] != TileState.UNTILLED
		_add_mound(wet if is_wet else dry, b, c, left, right)
		if is_wet:
			n_wet += 1
		else:
			n_dry += 1
	var mesh := ArrayMesh.new()
	for pair: Array in [[turf, n_turf, "turf"], [dry, n_dry, "dry"], [wet, n_wet, "wet"]]:
		if int(pair[1]) > 0:
			(pair[0] as SurfaceTool).commit(mesh)
			mesh.surface_set_material(mesh.get_surface_count() - 1, _ground_mat(str(pair[2])))
	if mesh.get_surface_count() > 0:
		var mi := MeshInstance3D.new()
		mi.name = "Soil"
		mi.mesh = mesh
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mi)
	# Plants (one merged mesh each).
	var cstyle := Modules.style("crops") as CropStyle
	var pscale := float(cstyle.plant_scale) if cstyle else 1.0
	for c in cells_per_bed:
		var i := tile_index(b, c)
		var t := tiles[i]
		if t["state"] != TileState.PLANTED:
			continue
		var def := GameData.crop_def(str(t["crop"]))
		if def == null:
			continue
		var growth := float(t["growth"])
		var model := def.build_model(def.stage_at(growth), def.stage_progress(growth), bool(t["dead"]), pscale)
		var span := _span(i)
		var holder := Node3D.new()
		holder.name = "Plant_%d" % i
		var first := cell_local(b, cell_of(span[0]))
		var last := cell_local(b, cell_of(span[span.size() - 1]))
		holder.position = (first + last) * 0.5 + Vector3(0, 0.1 + (0.1 if style() and style().raised_beds else 0.0), 0)
		holder.rotation.y = float(i * 37 % 360) * PI / 180.0
		holder.set_meta(&"stage", def.stage_at(growth))
		holder.set_meta(&"crop", def.id)
		holder.add_child(model)
		node.add_child(holder)
		var merged := MeshMerger.merge_children(model, holder, "Mesh")
		holder.add_child(merged)
		model.queue_free()


func _rebuild_static() -> void:
	if _static_root == null:
		return
	for child in _static_root.get_children():
		_static_root.remove_child(child)
		child.queue_free()
	_update_zone()
	_update_sign()
	var st := style()
	var parts := Node3D.new()
	_static_root.add_child(parts)
	# Row paths (packed earth / gravel) under and between the beds.
	var pst := SurfaceTool.new()
	pst.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_quad(pst, local_rect().grow(0.05), 0.012)
	var pmesh := ArrayMesh.new()
	pst.commit(pmesh)
	pmesh.surface_set_material(0, _ground_mat("path"))
	var pmi := MeshInstance3D.new()
	pmi.name = "Paths"
	pmi.mesh = pmesh
	pmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_static_root.add_child(pmi)
	# Stepping boards across each row path.
	var plank := CropModelBuilder.mat(Color(0.52, 0.4, 0.27), 0.85)
	var rects := path_rects()
	for k in range(1, rects.size() - 1):
		var r: Rect2 = rects[k]
		var x := r.position.x + 0.5
		while x < r.end.x - 0.3:
			_box(parts, Vector3(0.32, 0.04, PATH_W * 0.8), Vector3(x, 0.03, r.get_center().y), plank)
			x += 0.9
	# Bed edging boards.
	var edge := CropModelBuilder.mat(st.edge_color if st else Color(0.45, 0.32, 0.2), 0.85)
	var eh := 0.22 if st and st.raised_beds else 0.08
	var bed_len := cells_per_bed * CELL_LEN
	for b in beds:
		var zc := bed_center_z(b)
		for s in [-1.0, 1.0]:
			_box(parts, Vector3(bed_len + 0.08, eh, 0.05), Vector3(0, eh * 0.5, zc + s * (BED_W * 0.5 + 0.02)), edge)
			_box(parts, Vector3(0.05, eh, BED_W + 0.08), Vector3(s * (bed_len * 0.5 + 0.02), eh * 0.5, zc), edge)
	# Expansion sign.
	var sp := _sign.position
	var wood := CropModelBuilder.mat(Color(0.45, 0.32, 0.2), 0.85)
	_box(parts, Vector3(0.08, 1.1, 0.08), sp + Vector3(0, 0.55, 0), wood)
	_box(parts, Vector3(0.7, 0.42, 0.05), sp + Vector3(0, 1.05, 0.05), CropModelBuilder.mat(Color(0.75, 0.6, 0.4), 0.8))
	var label := Label3D.new()
	label.text = "Garden\n+1 bed: %d G" % expand_cost() if can_expand() else "Garden\n(full)"
	label.font_size = 40
	label.pixel_size = 0.004
	label.modulate = Color(0.2, 0.12, 0.05)
	label.outline_size = 0
	label.position = sp + Vector3(0, 1.05, 0.085)
	_static_root.add_child(label)
	_build_fence(parts)
	var merged := MeshMerger.merge_children(parts, _static_root, "GardenParts")
	_static_root.add_child(merged)
	parts.queue_free()
	# Snow cover (winter).
	_snow = MeshInstance3D.new()
	_snow.name = "SnowCover"
	var snow_mesh := BoxMesh.new()
	var r0 := local_rect()
	snow_mesh.size = Vector3(r0.size.x, 0.05, r0.size.y)
	_snow.mesh = snow_mesh
	_snow.position = Vector3(r0.get_center().x, 0.1, r0.get_center().y)
	_snow.material_override = CropModelBuilder.mat(Color(0.93, 0.95, 1.0), 0.8)
	_snow.visible = TimeManager.season_id() == "winter"
	_static_root.add_child(_snow)


## Wooden post-and-rail fence (yards module colours) with a gate gap at the front.
func _build_fence(parts: Node3D) -> void:
	var ys := Modules.style("yards") as YardStyle
	var wood := CropModelBuilder.mat(ys.wood_color if ys else Color(0.5, 0.36, 0.22), 0.85)
	var gst := style()
	var h := gst.fence_height if gst else 1.0
	var picket := ys != null and ys.kind == "picket"
	var r := local_rect().grow(FENCE_MARGIN)
	_fence_body = StaticBody3D.new()
	_fence_body.name = "FenceCollision"
	_fence_body.collision_layer = 1
	_fence_body.collision_mask = 0
	_static_root.add_child(_fence_body)
	var corners := [Vector2(r.position.x, r.end.y), Vector2(r.end.x, r.end.y), Vector2(r.end.x, r.position.y), Vector2(r.position.x, r.position.y)]
	# front side (z = end.y) has the gate in the middle
	var sides: Array = [
		[corners[0], Vector2(-GATE_W * 0.5, r.end.y)], [Vector2(GATE_W * 0.5, r.end.y), corners[1]],
		[corners[1], corners[2]], [corners[2], corners[3]], [corners[3], corners[0]]]
	for s: Array in sides:
		var a: Vector2 = s[0]
		var b: Vector2 = s[1]
		var length := a.distance_to(b)
		var dir := (b - a) / maxf(length, 0.001)
		var yaw := atan2(dir.x, dir.y)
		var n := maxi(1, int(ceil(length / 1.6)))
		for k in n + 1:
			var p := a + dir * (length * k / n)
			_box(parts, Vector3(0.11, h + 0.15, 0.11), Vector3(p.x, (h + 0.15) * 0.5, p.y), wood)
		var mid := (a + b) * 0.5
		if picket:
			var count := int(length / 0.2)
			for k in count:
				var p := a + dir * ((k + 0.5) * length / count)
				_box(parts, Vector3(0.07, h * 0.9, 0.025), Vector3(p.x, h * 0.45, p.y), wood, yaw)
			_box(parts, Vector3(0.05, 0.07, length), Vector3(mid.x, h * 0.65, mid.y), wood, yaw)
		else:
			for y in [h * 0.42, h * 0.85]:
				_box(parts, Vector3(0.06, 0.1, length), Vector3(mid.x, y, mid.y), wood, yaw)
			# top railing (wider handrail)
			_box(parts, Vector3(0.14, 0.05, length + 0.1), Vector3(mid.x, h + 0.1, mid.y), wood, yaw)
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.15, h + 0.2, length)
		cs.shape = box
		cs.position = Vector3(mid.x, (h + 0.2) * 0.5, mid.y)
		cs.rotation.y = yaw
		_fence_body.add_child(cs)
	# Gate posts (taller) with an arch board.
	for sx in [-1.0, 1.0]:
		_box(parts, Vector3(0.14, h + 0.6, 0.14), Vector3(sx * GATE_W * 0.5, (h + 0.6) * 0.5, r.end.y), wood)
	_box(parts, Vector3(GATE_W + 0.3, 0.12, 0.1), Vector3(0, h + 0.55, r.end.y), wood)


func _box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, yaw: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
