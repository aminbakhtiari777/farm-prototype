class_name Minimap
extends Control
## Feature module "minimap" (HUD, top-right). North-up map centred on the
## farmer: roads and paths, buildings, sea, pond, river, the garden, forest
## edge, the farmer (arrow) and townspeople (dots). Colours/size from the
## active "minimap" module; Tab toggles it.

var _timer: float = 0.0
var _player: Node3D
var _river: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	name = "Minimap"
	add_to_group(&"minimap")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_apply_style()
	Modules.on_swap("minimap", self, func(_m: AssetModule) -> void: _apply_style())


func style() -> MinimapStyle:
	return Modules.style("minimap") as MinimapStyle


func _apply_style() -> void:
	var st := style()
	var s := float(st.size if st else 220)
	custom_minimum_size = Vector2(s, s)
	size = Vector2(s, s)
	offset_left = -s - 14.0
	offset_right = -14.0
	offset_top = 58.0
	offset_bottom = 58.0 + s
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.1
	queue_redraw()


func toggle() -> void:
	visible = not visible


## World (x, z) -> minimap pixel.
func world_to_map(p: Vector2, centre: Vector2) -> Vector2:
	var st := style()
	var metres := st.metres if st else 90.0
	return size * 0.5 + (p - centre) * (size.x / metres)


func _draw() -> void:
	var st := style()
	if st == null:
		return
	if _player == null:
		_player = get_tree().get_first_node_in_group(&"player") as Node3D
	var centre := Vector2.ZERO
	var heading := 0.0
	if _player:
		centre = Vector2(_player.global_position.x, _player.global_position.z)
		var vis := _player.get_node_or_null(^"Visual") as Node3D
		heading = vis.global_rotation.y if vis else 0.0
	var k := size.x / st.metres
	draw_rect(Rect2(Vector2.ZERO, size), st.grass)
	# Forest belt beyond the play area.
	var pa := TownLayout.PLAY_AREA
	var tl := world_to_map(pa.position, centre)
	var br := world_to_map(pa.end, centre)
	var far := 2000.0
	draw_rect(Rect2(Vector2(-far, -far), Vector2(far * 2 + size.x, tl.y + far)), st.forest)
	draw_rect(Rect2(Vector2(-far, br.y), Vector2(far * 2 + size.x, far)), st.forest)
	draw_rect(Rect2(Vector2(-far, -far), Vector2(tl.x + far, far * 2 + size.y)), st.forest)
	draw_rect(Rect2(Vector2(br.x, -far), Vector2(far, far * 2 + size.y)), st.forest)
	# Sea (half-plane x + z > SHORE_SUM) as a big polygon.
	var s0 := TownLayout.SHORE_SUM
	var sea := PackedVector2Array()
	for p: Vector2 in [Vector2(s0 + 400, -400), Vector2(-400 + s0, 400), Vector2(s0 + 400, 400)]:
		sea.append(world_to_map(p, centre))
	draw_colored_polygon(sea, st.water)
	# Pond and river.
	draw_circle(world_to_map(TownLayout.POND_CENTER, centre), TownLayout.POND_RADIUS * k, st.water)
	if _river.is_empty():
		var land := get_tree().get_first_node_in_group(&"landscape")
		if land and land.has_method(&"river_points"):
			_river = land.call(&"river_points")
	if _river.size() > 1:
		var pts := PackedVector2Array()
		for p in _river:
			pts.append(world_to_map(p, centre))
		draw_polyline(pts, st.water, maxf(3.5 * k, 2.0))
	# Roads.
	for road in TownLayout.ROADS:
		var pts := PackedVector2Array()
		for p: Vector2 in road["points"]:
			pts.append(world_to_map(p, centre))
		var paved: bool = road["kind"] == "paved"
		draw_polyline(pts, st.road if paved else st.dirt, maxf(float(road["half"]) * 2.0 * k, 2.0))
	draw_circle(world_to_map(TownLayout.TOWN_CENTER, centre), TownLayout.SQUARE_RADIUS * k, st.road.lightened(0.15))
	# Garden.
	var gr := TownLayout.GARDEN_MAX_RECT
	var garden := get_tree().get_first_node_in_group(&"garden") as FarmPlot
	if garden:
		var lr := garden.local_rect()
		gr = Rect2(garden.global_position.x + lr.position.x, garden.global_position.z + lr.position.y, lr.size.x, lr.size.y)
	draw_rect(Rect2(world_to_map(gr.position, centre), gr.size * k), st.dirt.darkened(0.25))
	# Buildings.
	for b in TownLayout.BUILDINGS:
		var poly := PackedVector2Array()
		for c in TownLayout.footprint(b):
			poly.append(world_to_map(c, centre))
		draw_colored_polygon(poly, st.building if b["id"] != "farmhouse" else st.building.lightened(0.25))
	# Townspeople.
	for npc in get_tree().get_nodes_in_group(&"townspeople"):
		var n3 := npc as Node3D
		if n3 and n3.is_visible_in_tree():
			draw_circle(world_to_map(Vector2(n3.global_position.x, n3.global_position.z), centre), 3.0, st.npc)
	# Farmer arrow (heading).
	var c0 := size * 0.5
	var fwd := Vector2(sin(heading), cos(heading))
	var right := Vector2(fwd.y, -fwd.x)
	draw_colored_polygon(PackedVector2Array([c0 + fwd * 8.0, c0 - fwd * 5.0 + right * 5.0, c0 - fwd * 2.0, c0 - fwd * 5.0 - right * 5.0]), st.player)
	# Frame + north marker.
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.2, 0.14, 0.08, 0.9), false, 3.0)
	var font := get_theme_default_font()
	draw_string(font, Vector2(size.x * 0.5 - 5, 16), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.15, 0.1, 0.05))
