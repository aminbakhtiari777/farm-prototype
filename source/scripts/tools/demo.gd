class_name Demo
extends RefCounted
## Scene setups for screenshots, tests and web demo links. Used by
## dev_tools.gd (desktop) and main.gd (web URL parameters such as
## index.html?season=winter&hour=22&demo=shop). Not needed for normal play.

const SEASONS := ["spring", "summer", "autumn", "winter"]


static func season_index(name_or_index: String) -> int:
	if name_or_index.is_valid_int():
		return clampi(name_or_index.to_int(), 0, 3)
	return maxi(SEASONS.find(name_or_index.to_lower()), 0)


## Season (0..3), hour (e.g. 18.25) and weather id ("" = roll).
static func set_clock(tree: SceneTree, season: int, hour: float, weather: String = "sunny") -> void:
	var day := season * TimeManager.days_per_season + 2
	TimeManager.reset_calendar(day, hour, weather)
	refresh(tree)


static func refresh(tree: SceneTree) -> void:
	var scene := tree.current_scene
	var dn := scene.get_node_or_null(^"DayNightCycle") as DayNightCycle
	if dn:
		dn.refresh_now()
	var sv := scene.get_node_or_null(^"SeasonVisuals") as SeasonVisuals
	if sv:
		sv.apply()


static func _rig(tree: SceneTree) -> FollowCamera:
	return tree.current_scene.find_child("CameraRig", true, false) as FollowCamera


static func place_player(tree: SceneTree, pos: Vector2, yaw_deg: float) -> Node3D:
	var player := tree.get_first_node_in_group(&"player") as Node3D
	player.global_position = Vector3(pos.x, Terrain.height_at(pos.x, pos.y) + 0.02, pos.y)
	var visual := player.get_node_or_null(^"Visual") as Node3D
	if visual:
		visual.rotation.y = deg_to_rad(yaw_deg)
	return player


## Fills the crop plot with crops of the current season at various stages.
static func setup_crops(tree: SceneTree) -> void:
	var plot := tree.current_scene.get_node_or_null(^"CropPlot") as FarmPlot
	if plot == null:
		return
	var season := TimeManager.season_id()
	var crops: Array[String] = []
	for id in GameData.data.get("crops", {}):
		if season in GameData.crop(id).get("seasons", []):
			crops.append(id)
	for i in plot.tiles.size():
		if crops.is_empty():
			plot.debug_set_tile(i, "", 0.0, false)
			continue
		var row := int(i / float(plot.columns))
		var crop := crops[row % crops.size()]
		var days := float(GameData.crop(crop).get("days", 4))
		var stage: float = [1.0, 1.0, 0.75, 0.5, 0.25, 0.05][row % 6]
		plot.debug_set_tile(i, crop, days * stage, i % 3 != 0)
	Economy.add_item("turnip", 3)
	Economy.add_item("wool", 1)
	place_player(tree, Vector2(-4.0, -6.6), -100.0)
	var rig := _rig(tree)
	if rig:
		rig.target_offset = Vector3(-1.6, 0.6, 0.2)
		rig.snap_view(65.0, -24.0, 6.2)


## Teleports to the market stall and opens the shop UI.
static func setup_shop(tree: SceneTree) -> void:
	Economy.add_item("turnip", 4)
	Economy.add_item("strawberry", 6)
	Economy.add_item("wool", 2)
	var stall := tree.current_scene.find_child("MarketStall1", true, false) as Node3D
	var front := stall.global_transform * Vector3(0, 0, 2.2)
	var to_stall := stall.global_position - front
	place_player(tree, Vector2(front.x, front.z), rad_to_deg(atan2(to_stall.x, to_stall.z)))
	var rig := _rig(tree)
	if rig:
		rig.target_offset = Vector3(0, 1.4, 0)
		rig.snap_view(rad_to_deg(atan2(-to_stall.x, -to_stall.z)) + 20.0, -14.0, 5.0)
	GameEvents.shop_requested.emit()


static func setup_town(tree: SceneTree) -> void:
	place_player(tree, Vector2(1.5, -40.5), 160.0)
	var rig := _rig(tree)
	if rig:
		rig.target_offset = Vector3(0.0, 2.2, -4.0)
		rig.snap_view(8.0, -10.0, 11.0)


## Applies web URL parameters: ?season=winter&hour=22&weather=snow&demo=town|shop|crops&speed=2
static func apply_url_params(tree: SceneTree, query: String) -> void:
	var params := {}
	for pair in query.trim_prefix("?").split("&", false):
		var kv := pair.split("=", true, 1)
		params[kv[0].uri_decode()] = kv[1].uri_decode() if kv.size() > 1 else ""
	if params.is_empty():
		return
	var season := season_index(str(params.get("season", "0")))
	var hour := float(str(params.get("hour", "10")))
	if params.has("season") or params.has("hour") or params.has("weather"):
		set_clock(tree, season, hour, str(params.get("weather", "")))
	if params.has("speed"):
		var idx: int = TimeManager.speed_presets.find(float(str(params["speed"])))
		if idx >= 0:
			TimeManager.set_speed_index(idx)
	match str(params.get("demo", "")):
		"town":
			setup_town(tree)
		"shop":
			setup_shop(tree)
		"crops":
			setup_crops(tree)
