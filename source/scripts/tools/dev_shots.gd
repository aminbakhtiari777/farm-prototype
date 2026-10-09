extends Node
## Screenshot + performance harness (added by DevTools for --shots / --perf).
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --shots=/workspace/farm-v5c [--only=wide,garden]
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --perf
## Each shot stages the world (time, player, camera, UI) and saves <prefix>-<name>.png.

const SHOTS: Array[String] = ["wide", "player-closeup", "interior-1", "interior-2", "town-signs", "npcs",
	"beach", "topbar", "topbar-settings", "night", "beach-fishing", "map-overview", "sitting", "carry",
	"voice-ui", "controls-menu",
	# v4
	"lamp-night", "power-cut", "garden", "garden-close", "tools", "fences", "house-styles", "house-stone", "house-interior",
	"landscape", "river", "minimap", "npc-chat",
	# v5a
	"market", "workshop-crafting", "square-fountain", "mosque", "church", "workplaces", "civic", "school-interior",
	"kitchen", "people-panel", "npc-wave", "university", "town-night",
	# v5b
	"npc-card", "persian-bubbles", "bubbles-en", "needs-hud", "doctor", "cook-ready", "cook-prepare", "cook-salt",
	"cook-spices", "cook-cook", "cook-eat", "mosque-dome", "settings-language",
	# v5c
	"price-board", "prices-panel", "shop-prices", "carpenter-coop", "coop-build", "coop-chickens", "barn",
	"feeding", "young-animals", "young-chicks",
	# v5d (real local server + a headless bot client, started by the shots run)
	"two-players", "chat", "module-update", "online-panel", "away-avatar", "welcome-back", "offline-indicator",
	# v6a
	"night-sky", "day-sky", "dry-tree-chop", "campfire", "boats", "deep-sea", "sunbathing", "gym", "hypermarket",
	"hypermarket-shop", "persian-topbar", "persian-settings",
	# v6b
	"creator", "wardrobe", "driving", "ambulance", "police", "pickup", "stove-flame", "open-fridge", "tv-paintings",
	"landmark", "fruit-garden", "herding", "cloud-shadows", "gym-v6b", "yard-boxes",
	# v7a
	"backstory-card", "kids-biking", "argument", "possess", "house-fire", "rebuilt-house", "storm-outage",
	"earthquake", "cityhall-fund", "public-works",
	# v7b
	"cafe-night-dj", "cafe-menu", "cafe-fight", "tipsy", "mechanic", "mechanic-panel", "dashboard-night", "passenger",
	"camping", "newspaper", "chat-log", "haggle"]

var _player: Player
var _rig: FollowCamera
var _hud: Node  ## hud.gd (CanvasLayer, no class_name)
var _town: TownBuilder
var _prefix: String = "/workspace/farm-v7b"
var _only: PackedStringArray = PackedStringArray()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var perf := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shots="):
			_prefix = arg.substr(8)
		elif arg.begins_with("--only="):
			_only = arg.substr(7).split(",")
		elif arg == "--perf":
			perf = true
	if perf:
		_run_perf.call_deferred()
	else:
		_run_shots.call_deferred()


func _find() -> bool:
	var scene := get_tree().current_scene
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_rig = get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	_hud = scene.get_node_or_null(^"HUD") 
	_town = scene.get_node_or_null(^"Town") as TownBuilder
	return _player != null and _rig != null and _hud != null and _town != null


## Waits `count` frames with 3D rendering off (llvmpipe/xvfb renders Forward+
## at a few seconds per frame), then renders a few real frames to settle.
func _frames(count: int) -> void:
	var vp := get_viewport()
	if count > 6:
		vp.disable_3d = true
		for i in count - 4:
			await get_tree().process_frame
		vp.disable_3d = false
		count = 4
	for i in count:
		await get_tree().process_frame


func _capture(shot: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s-%s.png" % [_prefix, shot]
	print("  t=%.1fs" % (Time.get_ticks_msec() / 1000.0))
	var err := img.save_png(path)
	print("SHOT %s -> %s (%s)" % [shot, path, "ok" if err == OK else error_string(err)])


## Teleport the player (feet on the ground) facing yaw_deg (0 = +Z).
func _place(p: Vector2, yaw_deg: float) -> void:
	if _player.carried:
		_player._try_place()
	_player.stand_up()
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.05, p.y)
	(_player.get_node(^"Visual") as Node3D).rotation.y = deg_to_rad(yaw_deg)


## Camera placed in direction `from_dir` (xz, from the player), pitch/dist absolute.
func _view(from_dir: Vector2, pitch_deg: float, dist: float, offset: Vector3 = Vector3.ZERO) -> void:
	_rig.target_offset = offset
	_rig.snap_view(rad_to_deg(atan2(from_dir.x, from_dir.y)), pitch_deg, dist)


func _yaw_towards(from: Vector2, to: Vector2) -> float:
	var d := to - from
	return rad_to_deg(atan2(d.x, d.y))


func _clean_ui() -> void:
	GameEvents.close_all_modals()
	_hud.settings_panel.close()
	_hud.controls_menu.close()
	_hud.inventory_panel.close()
	if (_hud.voice_hud as VoiceHud).panel.visible:
		_hud.voice_hud.toggle_panel()
	GameEvents.interaction_prompt_changed.emit("")


func _time(day: int, hour: float, weather: String = "sunny") -> void:
	TimeManager.reset_calendar(day, hour, weather)
	TimeManager.set_paused(true)


func _want(shot: String) -> bool:
	return _only.is_empty() or shot in _only


# ==========================================================================
func _run_shots() -> void:
	await _frames(20)
	if not _find():
		push_error("DevShots: scene actors missing")
		get_tree().quit(1)
		return
	for shot in SHOTS:
		if not _want(shot):
			continue
		_clean_ui()
		_rig.target_offset = Vector3.ZERO
		await call("_shot_" + shot.replace("-", "_"))
	# v7b.1 traffic shots (scripts/v7b1_traffic/traffic_shots.gd, names "traffic-*").
	var trf = load("res://scripts/v7b1_traffic/traffic_shots.gd").new(self)
	for shot in trf.NAMES:
		if not _want(shot):
			continue
		_clean_ui()
		_rig.target_offset = Vector3.ZERO
		await trf.run(shot)
	# v7b.1 weather shots (scripts/v7b1_weather/weather_shots.gd, "weather-*", only when named in --only).
	var wx = load("res://scripts/v7b1_weather/weather_shots.gd").new(self)
	for shot in wx.NAMES:
		if not (shot in _only):
			continue
		_clean_ui()
		_rig.target_offset = Vector3.ZERO
		await wx.run(shot)
	_net_cleanup()
	print("SHOTS DONE")
	get_tree().quit(0)


func _shot_wide() -> void:
	_time(3, 10.5)
	_place(Vector2(-3, 7.5), 200.0)
	_view(Vector2(0.55, 1.0), -24.0, 24.0, Vector3(0, 0, -6))
	await _frames(60)
	await _capture("wide")


func _shot_player_closeup() -> void:
	_time(3, 10.0)
	_place(Vector2(-1.5, 9.5), 20.0)
	_view(Vector2(0.35, 1.0), -6.0, 2.6, Vector3(0, -0.35, 0))
	await _frames(40)
	await _capture("player-closeup")


func _interior(id: String, shot: String, from_dir: Vector2) -> void:
	_time(3, 16.0)
	var b := _town.buildings[id] as Building
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_view(from_dir.rotated(-b.rotation.y), -32.0, 3.3)
	await _frames(30)
	await _capture(shot)


func _shot_interior_1() -> void:
	await _interior("farmhouse", "interior-1", Vector2(0.6, 1.0))


func _shot_interior_2() -> void:
	await _interior("cafe", "interior-2", Vector2(-0.6, 1.0))


func _shot_town_signs() -> void:
	_time(3, 11.0)
	var b := _town.buildings.get("post", _town.buildings["store"]) as Building  # v7b.1: post office removed
	var dp := b.door_world_position(3.0)
	var me := Vector2(dp.x, dp.z)
	var bc := Vector2(b.global_position.x, b.global_position.z)
	_place(me, _yaw_towards(me, bc))
	var away := (me - bc).normalized()
	var prompts: Variant = Settings.get_value("prompts")
	Settings.set_value("prompts", false)
	_view(away.rotated(0.8), -14.0, 7.0, Vector3(0, 1.2, 0))
	await _frames(60)
	await _capture("town-signs")
	Settings.set_value("prompts", prompts)


func _shot_npcs() -> void:
	var prompts: Variant = Settings.get_value("prompts")
	Settings.set_value("prompts", false)
	TimeManager.reset_calendar(3, 11.5, "sunny")
	TimeManager.set_paused(false)
	_place(TownLayout.TOWN_CENTER + Vector2(0, 8), 180.0)
	await _frames(240)
	TimeManager.set_paused(true)
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var npc := n as Node3D
		var d := Vector2(npc.global_position.x, npc.global_position.z).distance_to(TownLayout.TOWN_CENTER)
		var inside := false
		for b: Building in _town.buildings.values():
			if b.is_point_inside(npc.global_position):
				inside = true
		if not inside and d < best_d:
			best_d = d
			best = npc
	if best:
		var np := Vector2(best.global_position.x, best.global_position.z)
		var me := np + Vector2(2.4, 0.0)
		_place(me, _yaw_towards(me, np))
		var mid := (np - me) * 0.5
		# Look across the pair from the side facing away from the nearest building
		# (so the spring arm doesn't hit a wall and zoom in).
		var centre := me + mid
		var near_b := Vector2.ZERO
		var nd := INF
		for b: Building in _town.buildings.values():
			var bp := Vector2(b.global_position.x, b.global_position.z)
			if bp.distance_to(centre) < nd:
				nd = bp.distance_to(centre)
				near_b = bp
		var side := Vector2(0.0, 1.0)
		if (centre - near_b).dot(side) < 0.0:
			side = -side
		_view((side + Vector2(0.3, 0.0)).normalized(), -12.0, 6.5, Vector3(mid.x, 0.0, mid.y))
	await _frames(20)
	await _capture("npcs")
	Settings.set_value("prompts", prompts)


func _shot_beach() -> void:
	_time(4, 14.0)
	var p := Vector2(29.0, 25.0)
	_place(p, 45.0)
	_view(Vector2(-1.0, -0.6), -14.0, 9.0)
	await _frames(60)
	await _capture("beach")


func _shot_topbar() -> void:
	_time(3, 9.25)
	_place(Vector2(-3, 7.5), 160.0)
	_view(Vector2(0.55, 1.0), -20.0, 11.0)
	await _frames(30)
	await _capture("topbar")


func _shot_topbar_settings() -> void:
	_time(3, 9.25)
	_hud.toggle_settings()
	await _frames(10)
	await _capture("topbar-settings")
	_hud.settings_panel.close()


func _shot_night() -> void:
	_time(5, 21.5, "sunny")
	var p := TownLayout.TOWN_CENTER + Vector2(0, 12)
	_place(p, 180.0)
	_view(Vector2(0.4, 1), -12.0, 8.0, Vector3(0, 1.0, 0))
	await _frames(90)
	await _capture("night")


func _shot_beach_fishing() -> void:
	_time(4, 17.0)
	var p := Vector2(33.5, 31.5)
	_place(p, 45.0)
	for i in 30:
		if not _player.fishing.probe_water(_player).is_empty():
			break
		_player.global_position += Vector3(0.3, 0, 0.3)
		await _frames(2)
	_view(Vector2(-1.0, 0.2), -14.0, 5.0)
	await _frames(10)
	_player.fishing.start(_player)
	for i in 900:
		if _player.fishing.state == FishingMinigame.State.BITE:
			break
		await _frames(1)
	await _frames(4)
	await _capture("beach-fishing")
	_player.fishing._finish("")


func _shot_map_overview() -> void:
	_time(3, 12.0)
	_place(Vector2(0, -50), 180.0)
	_player.visible = false
	var prompts: Variant = Settings.get_value("prompts")
	Settings.set_value("prompts", false)
	# A map view: no distance fog / depth of field for this one picture.
	var we := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
	var env: Environment = we.environment if we else null
	var saved := {}
	if env:
		saved = {"fog": env.fog_enabled, "vfog": env.volumetric_fog_enabled}
		env.fog_enabled = false
		env.volumetric_fog_enabled = false
	var attrs: CameraAttributes = we.camera_attributes if we else null
	if we:
		we.camera_attributes = null
	_view(Vector2(0, 1), -78.0, 210.0, Vector3(0, 0, 0))
	await _frames(60)
	await _capture("map-overview")
	if we:
		we.camera_attributes = attrs
	if env:
		env.fog_enabled = saved["fog"]
		env.volumetric_fog_enabled = saved["vfog"]
	Settings.set_value("prompts", prompts)
	_player.visible = true


func _shot_sitting() -> void:
	_time(3, 15.0)
	var seat: Seat = null
	var best := INF
	for s in get_tree().get_nodes_in_group(&"seats"):
		var st := s as Seat
		if st == null or not st.is_free():
			continue
		var inside := false
		for b: Building in _town.buildings.values():
			if b.is_point_inside(st.global_position):
				inside = true
		var d := Vector2(st.global_position.x, st.global_position.z).distance_to(TownLayout.TOWN_CENTER)
		if not inside and d < best:
			best = d
			seat = st
	if seat:
		var fy := seat.facing_yaw()
		_place(Vector2(seat.global_position.x, seat.global_position.z) + Vector2(sin(fy), cos(fy)) * 1.0, 0.0)
		await _frames(5)
		_player.sit_on(seat)
		await _frames(40)
		_view(Vector2(sin(fy + 0.5), cos(fy + 0.5)), -8.0, 3.6, Vector3(0, -0.4, 0))
	await _frames(20)
	await _capture("sitting")
	_player.stand_up()


func _shot_carry() -> void:
	_time(3, 10.0)
	var crate := get_tree().current_scene.find_child("Carry_farm_crate_1", true, false) as Carryable
	_place(Vector2(3.2, 7.3), 180.0)
	await _frames(5)
	if crate:
		_player.pick_up(crate)
	await _frames(30)
	# Walk-off spot in the open field (teleport without placing the crate).
	var spot := Vector2(7.5, 1.5)
	_player.global_position = Vector3(spot.x, Terrain.height_at(spot.x, spot.y) + 0.05, spot.y)
	(_player.get_node(^"Visual") as Node3D).rotation.y = deg_to_rad(35.0)
	_view(Vector2(0.9, 0.7), -12.0, 4.2)
	await _frames(30)
	await _capture("carry")
	if _player.carried:
		_player._try_place()


func _shot_voice_ui() -> void:
	_time(3, 10.0)
	_place(Vector2(-3, 7.5), 160.0)
	_view(Vector2(0.55, 1.0), -20.0, 11.0)
	_hud.voice_hud.toggle_panel()
	var ev := InputEventAction.new()
	ev.action = &"push_to_talk"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _frames(20)
	await _capture("voice-ui")
	ev = InputEventAction.new()
	ev.action = &"push_to_talk"
	ev.pressed = false
	Input.parse_input_event(ev)
	_hud.voice_hud.toggle_panel()


func _shot_controls_menu() -> void:
	_hud.open_controls()
	await _frames(10)
	await _capture("controls-menu")
	_hud.controls_menu.close()


# ==========================================================================
## Draw calls / primitives / objects from representative viewpoints.
func _run_perf() -> void:
	await _frames(20)
	if not _find():
		get_tree().quit(1)
		return
	_clean_ui()
	var views: Array = [
		["farm (default view)", func() -> void:
			_place(Vector2(-3, 7.5), 180.0)
			_rig.reset_behind_target()
			_rig.snap()],
		["farm wide", func() -> void:
			_place(Vector2(-3, 7.5), 200.0)
			_view(Vector2(0.55, 1.0), -24.0, 24.0, Vector3(0, 0, -6))],
		["market (v5a)", func() -> void:
			_place(TownLayout.MARKET_CENTER + Vector2(-1.5, 9.0), 180.0)
			_view(Vector2(0.35, 1.0), -18.0, 9.0, Vector3(0, 1.2, -5.0))],
		["civic row (v5a)", func() -> void:
			_place(Vector2(-14.0, -86.0), 180.0)
			_view(Vector2(0.3, 1.0), -14.0, 12.0)],
		["town square", func() -> void:
			_place(TownLayout.TOWN_CENTER + Vector2(0, 14), 180.0)
			_view(Vector2(0, 1), -10.0, 7.0, Vector3(0, 1.0, 0))],
		["beach", func() -> void:
			_place(Vector2(29.0, 25.0), 45.0)
			_view(Vector2(-1.0, -0.6), -14.0, 9.0)],
		["forest edge (north)", func() -> void:
			_place(Vector2(-40, -120), 180.0)
			_view(Vector2(0, 1), -12.0, 8.0)],
		["map overview", func() -> void:
			_place(Vector2(0, -50), 180.0)
			_view(Vector2(0, 1), -78.0, 210.0)],
	]
	_time(3, 12.0)
	print("PERF renderer=%s" % ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	for v: Array in views:
		_rig.target_offset = Vector3.ZERO
		(v[1] as Callable).call()
		await _frames(45)
		var draws := 0.0
		var prims := 0.0
		var objs := 0.0
		var fps := 0.0
		for i in 10:
			await RenderingServer.frame_post_draw
			draws += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
			prims += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
			objs += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
			fps += Performance.get_monitor(Performance.TIME_FPS)
		print("PERF %-22s draw_calls=%5d primitives=%8d objects=%5d (xvfb fps %.0f)" % [str(v[0]), int(draws / 10.0), int(prims / 10.0), int(objs / 10.0), fps / 10.0])
	print("PERF video_mem=%.1f MB texture_mem=%.1f MB" % [RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_VIDEO_MEM_USED) / 1048576.0,
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TEXTURE_MEM_USED) / 1048576.0])
	print("PERF DONE")
	get_tree().quit(0)


# ------------------------------------------------------------------ v4 shots
func _plot() -> FarmPlot:
	return get_tree().current_scene.get_node(^"CropPlot") as FarmPlot


func _shot_lamp_night() -> void:
	PowerGrid.set_power(true)
	_time(5, 20.6)
	var fh := _town.buildings["farmhouse"] as Building
	var door := fh.door_world_position(3.5)
	_place(Vector2(door.x + 2.0, door.z + 2.5), 250.0)
	_view(Vector2(0.9, 0.55), -9.0, 7.5, Vector3(-1.5, 0.8, 0))
	await _frames(80)
	await _capture("lamp-night")


func _shot_power_cut() -> void:
	_time(5, 21.0)
	PowerGrid.set_power(false)
	var b := _town.buildings["farmhouse"] as Building
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_view(Vector2(0.6, 1.0).rotated(-b.rotation.y), -30.0, 3.4)
	await _frames(40)
	await _capture("power-cut")
	PowerGrid.set_power(true)


## A planted garden: tilled cells, sprouts, leaves, flowers and fruit.
func _stage_garden() -> void:
	var plot := _plot()
	var n := plot.cells_per_bed
	var row0 := [["turnip", 0.2], ["turnip", 1.2], ["turnip", 2.2], ["turnip", 3.5], ["carrot", 1.0], ["carrot", 3.0], ["", 0], ["", 0], ["potato", 2.5], ["potato", 4.0], ["potato", 5.5], ["", -1]]
	var row1 := [["tomato", 1.5], ["", -9], ["tomato", 4.0], ["", -9], ["tomato", 5.5], ["", -9], ["strawberry", 3.0], ["strawberry", 5.0], ["eggplant", 4.0], ["", -9], ["", 0], ["", -1]]
	var row2 := [["corn", 2.0], ["corn", 4.0], ["corn", 6.5], ["sunflower", 1.5], ["sunflower", 3.5], ["sunflower", 6.0], ["pumpkin", 5.0], ["", -9], ["apple_tree", 6.0], ["", -9], ["banana", 7.0], ["", -9]]
	var rows := [row0, row1, row2]
	for b in mini(rows.size(), plot.beds):
		var row: Array = rows[b]
		for c in mini(row.size(), n):
			var e: Array = row[c]
			var idx := plot.tile_index(b, c)
			if float(e[1]) <= -9.0:
				continue  # second cell of a 1 m² crop
			if float(e[1]) < 0.0:
				continue  # leave as grass
			plot.debug_set_tile(idx, str(e[0]), float(e[1]), c % 3 != 0)
	plot.flush()


func _shot_garden() -> void:
	_time(4, 10.0)
	_stage_garden()
	var plot := _plot()
	var gc := plot.global_position
	_place(Vector2(gc.x + 2.5, gc.z + 1.6), 200.0)
	_view(Vector2(0.75, 1.0), -38.0, 9.5, Vector3(-2.5, 0, -2.0))
	await _frames(60)
	await _capture("garden")


func _shot_garden_close() -> void:
	_time(4, 15.0)
	var plot := _plot()
	var p := plot.tile_world_position(plot.tile_index(0, 2))
	_place(Vector2(p.x + 0.4, p.z + 1.4), 180.0)
	_view(Vector2(0.2, 1.0), -30.0, 3.6, Vector3(0, -0.4, -1.0))
	await _frames(50)
	await _capture("garden-close")


func _shot_tools() -> void:
	_time(4, 11.0)
	var plot := _plot()
	var p := plot.tile_world_position(plot.tile_index(1, 10))
	_place(Vector2(p.x, p.z + 0.9), 180.0)
	_view(Vector2(1.0, -0.15), -10.0, 3.2, Vector3(0, 0.1, 0))
	await _frames(30)
	_player.play_tool("hoe")
	_player.tools.freeze_at(0.12)
	await _frames(3)
	await _capture("tools")
	_player.tools.freeze_at(5.0)
	await _frames(3)


func _shot_fences() -> void:
	_time(3, 10.0)
	# Back yard of a home: fence + top railing around the garden behind it.
	var b := _town.buildings["maple3"] as Building
	var back := b.global_transform * Vector3(2.0, 0.0, -b.size.z * 0.5 - 9.5)
	_place(Vector2(back.x, back.z), b.rotation_degrees.y)
	_view(Vector2(0.6, -1.0).rotated(-b.rotation.y), -22.0, 8.0, Vector3(0, 0, 0))
	await _frames(60)
	await _capture("fences")


func _shot_house_styles() -> void:
	_time(3, 10.5)
	_place(Vector2(-6.0, -90.0), 270.0)
	_view(Vector2(0.85, 0.35), -24.0, 30.0, Vector3(-6, 0, -2))
	await _frames(60)
	await _capture("house-styles")


func _shot_house_stone() -> void:
	_time(3, 15.5)
	var b := _town.buildings["maple4"] as Building
	var front := b.door_world_position(10.0)
	_place(Vector2(front.x, front.z), b.rotation_degrees.y + 180.0)
	_view(Vector2(-0.6, 1.0).rotated(-b.rotation.y), -14.0, 7.0, Vector3(0, 1.0, 0))
	await _frames(60)
	await _capture("house-stone")


func _shot_house_interior() -> void:
	_time(3, 16.0)
	var b := _town.buildings["maple2"] as Building
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_view(Vector2(-0.6, 1.0).rotated(-b.rotation.y), -32.0, 3.3)
	await _frames(30)
	await _capture("house-interior")


func _shot_landscape() -> void:
	_time(3, 11.0)
	_place(Vector2(-60.0, 22.0), 280.0)
	_view(Vector2(0.95, 0.15), -6.0, 16.0, Vector3(0, 6.0, 0))
	await _frames(80)
	await _capture("landscape")


func _shot_river() -> void:
	_time(3, 12.0)
	_place(Vector2(-52.0, 23.0), 0.0)
	_view(Vector2(-0.25, 1.0), -32.0, 14.0, Vector3(4.0, 0, -6.0))
	await _frames(70)
	await _capture("river")


func _shot_minimap() -> void:
	_time(3, 10.0)
	_place(TownLayout.TOWN_CENTER + Vector2(0, 14), 180.0)
	var mm := get_tree().get_first_node_in_group(&"minimap") as Control
	if mm and not mm.visible:
		mm.call("toggle")
	_view(Vector2(0.3, 1.0), -20.0, 9.0)
	await _frames(60)
	await _capture("minimap")


func _shot_npc_chat() -> void:
	_time(3, 13.0)
	var c := TownLayout.TOWN_CENTER + Vector2(-2.0, 11.0)
	_place(c, 180.0)
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var social := get_tree().get_first_node_in_group(&"npc_social") as NpcSocial
	if bots.size() >= 2 and social:
		var a := bots[0] as TownspersonBot
		var b := bots[1] as TownspersonBot
		for bot: TownspersonBot in [a, b]:
			var sc := bot.controller as ScheduleController
			sc.current = {"spot": "square", "activity": "wander", "from": 0.0, "to": 24.0}
			sc.arrived = true
		a.global_position = Vector3(c.x - 1.3, Terrain.height_at(c.x - 1.3, c.y - 3.0) + 0.1, c.y - 3.0)
		b.global_position = Vector3(c.x + 1.3, Terrain.height_at(c.x + 1.3, c.y - 3.0) + 0.1, c.y - 3.2)
		await _frames(4)
		social.start_chat(a, b)
	_view(Vector2(0.1, 1.0), -8.0, 5.0, Vector3(0, 0.9, -3.0))
	await _frames(12)
	# Stage the moment the partner answers (NpcSocial does this ~3 s in).
	if bots.size() >= 2 and social and social.style():
		(bots[1] as TownspersonBot).say(social.style().replies[0], 30.0)
		(bots[0] as TownspersonBot).say(social.style().lines[0], 30.0)
	await _frames(6)
	await _capture("npc-chat")



# ------------------------------------------------------------------ v5a shots
## Outside a building: player `dist` m in front of the door, camera turned
## by `side` (+ = right) and raised.
func _outside(id: String, dist: float, side: float, pitch: float, cam_dist: float, offset: Vector3 = Vector3(0, 2.0, 0)) -> void:
	var b := _town.buildings[id] as Building
	var front := b.door_world_position(dist)
	_place(Vector2(front.x, front.z), b.rotation_degrees.y + 180.0)
	_view(Vector2(side, 1.0).rotated(-b.rotation.y), pitch, cam_dist, offset)


func _shot_market() -> void:
	_time(3, 10.5)
	var c := TownLayout.MARKET_CENTER
	_place(c + Vector2(-1.5, 9.0), 180.0)
	_view(Vector2(0.35, 1.0), -18.0, 9.0, Vector3(0, 1.2, -5.0))
	await _frames(60)
	await _capture("market")


func _shot_workshop_crafting() -> void:
	Economy.add_item("wood_plank", 4)
	Economy.add_item("iron_nails", 1)
	await _interior("workshop", "workshop-tmp", Vector2(0.6, 1.0))
	GameEvents.crafting_requested.emit("workbench")
	await _frames(8)
	await _capture("workshop-crafting")
	(_hud.get("crafting_panel") as CraftingPanel).close()


func _shot_square_fountain() -> void:
	_time(3, 16.5)
	_place(TownLayout.TOWN_CENTER + Vector2(3.0, 11.0), 200.0)
	_view(Vector2(0.4, 1.0), -16.0, 8.0, Vector3(0, 1.5, -5.0))
	await _frames(60)
	await _capture("square-fountain")


func _shot_mosque() -> void:
	_time(3, 17.0)
	_place(Vector2(-3.5, -76.0), 270.0)
	_view(Vector2(1.0, 0.45), -30.0, 17.0, Vector3(-4.0, 3.0, 0))
	await _frames(60)
	await _capture("mosque")


func _shot_church() -> void:
	_time(3, 11.0)
	await _outside("church", 10.0, -0.5, -14.0, 11.0, Vector3(0, 6.0, 0))
	await _frames(60)
	await _capture("church")


func _shot_workplaces() -> void:
	_time(3, 10.0)
	var b := _town.buildings["blacksmith"] as Building
	var front := b.door_world_position(7.0)
	_place(Vector2(front.x, front.z), b.rotation_degrees.y + 180.0)
	_view(Vector2(0.9, 1.0).rotated(-b.rotation.y), -16.0, 14.0, Vector3(0, 2.0, 0))
	await _frames(60)
	await _capture("workplaces")


func _shot_civic() -> void:
	_time(3, 14.0)
	_place(Vector2(40.0, -88.5), 270.0)
	_view(Vector2(1.0, -0.3), -18.0, 18.0, Vector3(0, 2.0, 0))
	await _frames(60)
	await _capture("civic")


func _shot_school_interior() -> void:
	await _interior("school", "school-interior", Vector2(0.3, 1.0))


func _shot_kitchen() -> void:
	_time(3, 18.0)
	var b := _town.buildings["maple3"] as Building
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y + 180.0)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_view(Vector2(0.3, 1.0).rotated(-b.rotation.y), -22.0, 3.0, Vector3(0, 0.4, 0))
	await _frames(30)
	await _capture("kitchen")


func _shot_people_panel() -> void:
	_time(3, 10.0)
	_place(TownLayout.TOWN_CENTER + Vector2(0.0, 13.0), 180.0)
	_view(Vector2(0.3, 1.0), -14.0, 9.0, Vector3(0, 1.5, -5.0))
	await _frames(20)
	(_hud.get("people_panel") as PeoplePanel).open()
	await _frames(10)
	await _capture("people-panel")
	(_hud.get("people_panel") as PeoplePanel).close()


func _shot_npc_wave() -> void:
	_time(3, 11.0)
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var g := get_tree().current_scene.find_child("NpcGestures", true, false) as NpcGestures
	var c := TownLayout.TOWN_CENTER + Vector2(-3.0, 13.5)
	_place(c, 180.0)
	if bots.size() > 0 and g:
		var a := bots[0] as TownspersonBot
		var sc := a.controller as ScheduleController
		sc.current = {"spot": "square", "activity": "wander", "from": 0.0, "to": 24.0}
		sc.arrived = true
		a.global_position = Vector3(c.x, Terrain.height_at(c.x, c.y - 3.0) + 0.1, c.y - 3.0)
		a.visual.rotation.y = 0.0
		await _frames(4)
		g.wave(a, _player, 30.0)
	_view(Vector2(0.6, 1.0), -6.0, 4.5, Vector3(0, 0.9, -2.0))
	await _frames(14)
	await _capture("npc-wave")


func _shot_university() -> void:
	_time(3, 9.5)
	await _outside("university", 10.0, 0.6, -10.0, 12.0, Vector3(0, 3.0, 0))
	await _frames(60)
	await _capture("university")


func _shot_town_night() -> void:
	_time(3, 21.5)
	_place(TownLayout.TOWN_CENTER + Vector2(0.0, 13.0), 180.0)
	_view(Vector2(0.3, 1.0), -14.0, 9.0, Vector3(0, 1.5, -5.0))
	await _frames(60)
	await _capture("town-night")


# ------------------------------------------------------------------ v5b shots
func _bots() -> Array:
	return get_tree().get_nodes_in_group(&"townspeople")


## Pins a bot at world xz `p` facing yaw (0 = +Z) with a still schedule entry.
func _pin(bot: TownspersonBot, p: Vector2, yaw_deg: float) -> void:
	var sc := bot.controller as ScheduleController
	if sc:
		sc.current = {"spot": "square", "activity": "wander", "from": 0.0, "to": 24.0}
		sc.arrived = true
	bot.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.1, p.y)
	bot.velocity = Vector3.ZERO
	if bot.visual:
		bot.visual.rotation.y = deg_to_rad(yaw_deg)


func _bot_with(pred: Callable, skip: Array = []) -> TownspersonBot:
	for n in _bots():
		var b := n as TownspersonBot
		if b in skip:
			continue
		if pred.call(b):
			return b
	return null


func _gender(b: TownspersonBot) -> String:
	return str(b.resident.get("gender", ""))


func _shot_npc_card() -> void:
	_time(3, 10.0)
	Settings.set_value("dialogue_language", "fa")
	var c := TownLayout.TOWN_CENTER + Vector2(-2.0, 12.0)
	_place(c, 180.0)
	var b := _bot_with(func(x: TownspersonBot) -> bool: return str(x.resident.get("job", "")) != "" and int(x.resident.get("age", 30)) >= 20)
	if b:
		_pin(b, c + Vector2(0.0, -1.8), 0.0)
		await _frames(4)
		b._on_greeted(_player)
		(_hud.get("npc_card") as NpcCard).show_for(b)
	_view(Vector2(0.55, 1.0), -8.0, 4.2, Vector3(0, 1.0, -1.0))
	await _frames(14)
	await _capture("npc-card")


func _stage_bubbles(shot: String) -> void:
	_time(3, 17.5)
	var c := TownLayout.TOWN_CENTER + Vector2(-2.0, 11.0)
	_place(c, 180.0)
	var social := get_tree().get_first_node_in_group(&"npc_social") as NpcSocial
	var w := _bot_with(func(x: TownspersonBot) -> bool: return _gender(x) == "female" and int(x.resident.get("age", 30)) >= 18)
	var m := _bot_with(func(x: TownspersonBot) -> bool: return _gender(x) == "male" and int(x.resident.get("age", 30)) >= 18, [w])
	var k := _bot_with(func(x: TownspersonBot) -> bool: return int(x.resident.get("age", 30)) < 14, [w, m])
	seed(7)
	if w and m:
		_pin(w, c + Vector2(-1.6, -3.0), 90.0)
		_pin(m, c + Vector2(1.4, -3.2), -90.0)
		await _frames(4)
		w.say(Dialogue.greeting() + " " + Dialogue.chat_line(), 30.0)
		m.say(Dialogue.chat_reply(), 30.0)
	if k:
		_pin(k, c + Vector2(0.2, -1.4), 180.0)
		await _frames(2)
		k.say(Dialogue.player_greeting(), 30.0)
	_view(Vector2(0.1, 1.0), -6.0, 5.6, Vector3(0, 1.1, -2.6))
	await _frames(14)
	await _capture(shot)


func _shot_persian_bubbles() -> void:
	Settings.set_value("dialogue_language", "fa")
	await _stage_bubbles("persian-bubbles")


func _shot_bubbles_en() -> void:
	Settings.set_value("dialogue_language", "en")
	await _stage_bubbles("bubbles-en")
	Settings.set_value("dialogue_language", "fa")


func _shot_needs_hud() -> void:
	_time(3, 15.0)
	Settings.set_value("dialogue_language", "fa")
	Needs.hunger = 22.0
	Needs.fatigue = 78.0
	Needs.meals_today = 0
	Needs.fall_ill("cold")
	_place(Vector2(-3, 7.5), 200.0)
	_view(Vector2(0.5, 1.0), -12.0, 4.5, Vector3(0, 1.0, 0))
	await _frames(10)
	Needs.sneeze(_player)
	await _frames(8)
	await _capture("needs-hud")


func _shot_doctor() -> void:
	_time(3, 11.0)
	Settings.set_value("dialogue_language", "fa")
	if not Needs.is_ill():
		Needs.fall_ill("cold")
	Economy.add_money(200)
	var doc := _item_of("doctor", "hospital")
	var b := _town.buildings["hospital"] as Building
	if doc:
		var dp := doc.global_position
		var bx := b.global_transform.basis.x
		bx.y = 0.0
		bx = bx.normalized()
		var bz := b.global_transform.basis.z
		bz.y = 0.0
		bz = bz.normalized()
		var fl := b.floor_y() + 0.05
		# Farmer at the desk, the doctor behind it, a sick neighbour waiting.
		var pp := dp - bx * 0.1
		_place(Vector2(pp.x, pp.z), rad_to_deg(atan2(bx.x, bx.z)))
		_player.global_position.y = fl
		await _frames(20)
		var doctor := _bot_with(func(x: TownspersonBot) -> bool: return str(x.resident.get("job", "")).to_lower().contains("doctor"))
		var sick := _bot_with(func(x: TownspersonBot) -> bool: return int(x.resident.get("age", 30)) >= 18 and str(x.resident.get("gender", "")) == "female", [doctor])
		for n in _bots():
			var ob := n as TownspersonBot
			if ob != doctor and ob != sick and ob.global_position.distance_to(dp) < 25.0:
				ob.visible = false
				ob.global_position += Vector3(0, -50, 0)
		for pair: Array in [[doctor, dp + bx * 1.75, -bx], [sick, dp - bx * 0.7 + bz * 0.9, bx]]:
			var ob := pair[0] as TownspersonBot
			if ob == null:
				continue
			var sc := ob.controller as ScheduleController
			if sc:
				sc.current = {"spot": "square", "activity": "wander", "from": 0.0, "to": 24.0}
				sc.arrived = true
			var at: Vector3 = pair[1]
			var face: Vector3 = pair[2]
			ob.global_position = Vector3(at.x, fl, at.z)
			ob.velocity = Vector3.ZERO
			ob.visual.rotation.y = atan2(face.x, face.z)
		if sick:
			Needs.npc_fall_ill(sick, "cold")
			(sick.controller as ScheduleController).override_entry = {}
		await _frames(4)
		_view(Vector2(-bx.x, -bx.z).rotated(0.6), -16.0, 4.6, Vector3(0, 0.9, 0) + bx * 0.6)
		await _frames(6)
		var msg := Needs.treat_player()
		GameEvents.notification_requested.emit(msg)
		if doctor:
			doctor.say("بفرمایید! این شربت رو روزی سه بار بخور و استراحت کن." if Lang.is_fa() else "Here you go! Take this syrup three times a day and rest.", 30.0)
		if sick:
			sick.say(Lang.pick(Dialogue.style().ill_self) if Dialogue.style() else "آپچی!", 30.0)
	await _frames(10)
	await _capture("doctor")


func _item_of(kind: String, building_id: String) -> InteriorItem:
	for n in get_tree().get_nodes_in_group(&"interior_items"):
		var it := n as InteriorItem
		if it and it.kind == kind and it.building and it.building.layout_id == building_id:
			return it
	return null


var _cook_panel: CookingPanel


func _cook_stage() -> void:
	Settings.set_value("dialogue_language", "fa")
	Needs.cure(false)
	Needs.hunger = 30.0
	for k in ["eggs", "eggs", "tomato_fresh", "onion", "salt", "spices", "chicken", "rice", "herbs"]:
		Economy.add_item(k, 2)
	_time(3, 13.0)
	var b := _town.buildings["maple3"] as Building
	var stove := _item_of("stove", "maple3")
	var sp := stove.global_position
	var into := b.interior_center() - sp
	into.y = 0.0
	var p := sp + into.normalized() * 0.95
	_place(Vector2(p.x, p.z), _yaw_towards(Vector2(p.x, p.z), Vector2(sp.x, sp.z)))
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_cook_panel = _hud.get("cooking_panel") as CookingPanel
	_cook_panel.open(stove)
	_cook_panel.choose(Cooking.dish_by_id("omelette"))
	# Panel is on the left; frame the stove on the right half of the screen.
	var to_stove := Vector2(sp.x - p.x, sp.z - p.z)
	if to_stove.length() < 0.1:
		to_stove = Vector2(0, -1)
	_view((-to_stove).normalized().rotated(0.35), -28.0, 2.6, Vector3(0, 0.55, 0))


func _cook_step(shot: String) -> void:
	if _cook_panel == null or not _cook_panel.visible or _cook_panel.session == null:
		await _cook_stage()
		await _frames(6)
	if shot != "cook-ready":
		_cook_panel.do_next()
	await _frames(14)
	await _capture(shot)


func _shot_cook_ready() -> void:
	_cook_panel = null
	await _cook_stage()
	await _frames(8)
	await _capture("cook-ready")


func _shot_cook_prepare() -> void:
	await _cook_step("cook-prepare")


func _shot_cook_salt() -> void:
	await _cook_step("cook-salt")


func _shot_cook_spices() -> void:
	await _cook_step("cook-spices")


func _shot_cook_cook() -> void:
	await _cook_step("cook-cook")


func _shot_cook_eat() -> void:
	await _cook_step("cook-eat")
	_cook_panel.close()


func _shot_mosque_dome() -> void:
	_time(3, 16.5)
	_place(Vector2(-3.5, -76.0), 270.0)
	_view(Vector2(1.0, 0.25), -4.0, 22.0, Vector3(-9.0, 9.0, 0))
	await _frames(60)
	await _capture("mosque-dome")


func _shot_settings_language() -> void:
	_time(3, 10.0)
	_place(Vector2(-3, 7.5), 200.0)
	_view(Vector2(0.55, 1.0), -24.0, 14.0)
	await _frames(10)
	_hud.settings_panel.open()
	await _frames(8)
	await _capture("settings-language")
	_hud.settings_panel.close()


# ------------------------------------------------------------------ v5c
func _market_history() -> void:
	# A few market mornings with a shortage, a glut and a sick smith -> visible trends.
	Market.reset()
	Market.sim_enabled = false
	for d in 5:
		Market.take("eggs", Market.stock_of("eggs") * 0.35)
		Market.add("tomato", 6.0)
		Market.take("milk", Market.stock_of("milk") * 0.3)
		Market.take("wool", Market.stock_of("wool") * 0.25)
		Market.add("apple", 4.0)
		Market.npc_meal("x")
		Market.advance_day(d + 1)
	Market.take("eggs", Market.stock_of("eggs") * 0.75)
	Market.take("iron_nails", Market.stock_of("iron_nails") * 0.6)
	Market.add("potato", 25.0)
	Market.pay_wages()
	Market.prices_changed.emit()


func _shot_price_board() -> void:
	_time(4, 10.5)
	Settings.set_value("dialogue_language", "fa")
	_market_history()
	var st := Modules.style("price_board") as PriceBoardStyle
	var p := st.position
	var fwd := Vector2(0, 1).rotated(-deg_to_rad(st.yaw_deg))
	_place(p + fwd * 2.8 + Vector2(fwd.y, -fwd.x) * 0.9, st.yaw_deg + 180.0)
	_view(fwd.rotated(0.25), -8.0, 3.6, Vector3(-fwd.x * 2.4, 1.2, -fwd.y * 2.4))
	await _frames(60)
	await _capture("price-board")


func _shot_prices_panel() -> void:
	_time(4, 10.5)
	Settings.set_value("dialogue_language", "fa")
	_market_history()
	var st := Modules.style("price_board") as PriceBoardStyle
	var fwd := Vector2(0, 1).rotated(-deg_to_rad(st.yaw_deg))
	_place(st.position + fwd * 2.8, st.yaw_deg + 180.0)
	_view(fwd, -10.0, 4.6, Vector3(-fwd.x * 2.0, 1.1, -fwd.y * 2.0))
	await _frames(30)
	(_hud.get("prices_panel") as PricesPanel).open()
	await _frames(10)
	await _capture("prices-panel")
	(_hud.get("prices_panel") as PricesPanel).close()


func _shot_shop_prices() -> void:
	Settings.set_value("dialogue_language", "fa")
	_market_history()
	await _interior("supermarket", "supermarket-tmp", Vector2(0.6, 1.0))
	Economy.add_item("strawberry", 6)
	Economy.add_item("eggs", 4)
	Economy.add_money(500)
	_hud.shop_panel.call(&"open_shop_for", "grocery")
	await _frames(10)
	await _capture("shop-prices")
	_hud.shop_panel.call(&"close_shop")


func _ranch_stage(young: bool = false) -> void:
	Ranch.sim_enabled = false
	Ranch.reset()
	Ranch.finish_now("coop")
	Ranch.finish_now("barn")
	Economy.add_money(20000)
	for i in 5:
		Ranch.buy_animal("chicken")
	for i in 2:
		Ranch.buy_animal("cow")
	for i in 3:
		Ranch.buy_animal("sheep_flock")
	var k := 0
	for a: Dictionary in Ranch.animals:
		a["happiness"] = 70.0 + float(k * 7 % 30)
		a["product_ready"] = 1 if k % 2 == 0 else 0
		a["fed_today"] = k % 3 != 0
		k += 1
	if young:
		for kind in ["chicken", "chicken", "cow", "sheep_flock", "chicken"]:
			Ranch._new_animal(Ranch.animal_def(kind), false)
	Ranch.changed.emit()


func _shot_carpenter_coop() -> void:
	Settings.set_value("dialogue_language", "fa")
	Ranch.reset()
	Economy.add_money(3000)
	Economy.add_item("wood_plank", 12)
	Economy.add_item("iron_nails", 6)
	await _interior("carpenter", "carpenter-tmp", Vector2(0.6, 1.0))
	var desk := _item_of("livestock_desk", "carpenter")
	if desk:
		var b := _town.buildings["carpenter"] as Building
		var dp := desk.global_position
		_place(Vector2(dp.x, dp.z) + Vector2(0.9, 0.4).rotated(-b.rotation.y), 0.0)
		_player.global_position.y = b.floor_y() + 0.05
		_view(Vector2(1.0, 0.6).rotated(-b.rotation.y), -24.0, 3.6)
		await _frames(20)
	var lp := _hud.get("livestock_panel") as LivestockPanel
	lp.open()
	await _frames(4)
	lp.call(&"_say", Ranch.order("coop"))
	await _frames(10)
	await _capture("carpenter-coop")
	lp.close()


func _shot_coop_build() -> void:
	_time(4, 11.0)
	Settings.set_value("dialogue_language", "fa")
	Ranch.reset()
	Economy.add_money(5000)
	Economy.add_item("wood_plank", 40)
	Economy.add_item("iron_nails", 20)
	Ranch.order("coop")
	Ranch.order("barn")
	_place(Vector2(1.0, 24.0), 200.0)
	_view(Vector2(0.2, 1.0), -24.0, 13.0, Vector3(0, 1.0, -5.0))
	await _frames(60)
	await _capture("ranch-construction")


func _shot_coop_chickens() -> void:
	_time(4, 10.5)
	Settings.set_value("dialogue_language", "fa")
	_ranch_stage()
	var h := Ranch.housing_def("coop")
	_place(h.position + Vector2(2.6, 9.4), 200.0)
	_view(Vector2(0.45, 1.0), -24.0, 7.5, Vector3(-1.5, 0.6, -3.2))
	await _frames(70)
	await _capture("coop-chickens")


func _shot_barn() -> void:
	_time(4, 15.5)
	Settings.set_value("dialogue_language", "fa")
	_ranch_stage()
	var h := Ranch.housing_def("barn")
	_place(h.position + Vector2(-8.6, 6.4), 90.0)
	_view(Vector2(-1.0, 0.25), -22.0, 9.0, Vector3(4.5, 0.8, -1.0))
	await _frames(70)
	await _capture("barn")


func _shot_feeding() -> void:
	_time(4, 8.5)
	Settings.set_value("dialogue_language", "fa")
	_ranch_stage()
	Economy.add_item("chicken_feed", 12)
	for a: Dictionary in Ranch.animals_in("coop"):
		a["fed_today"] = false
	await _frames(20)
	var rw := get_tree().get_first_node_in_group(&"ranch_world") as RanchWorld
	var tz := rw.troughs.get("coop") as Interactable
	var tp := tz.global_position
	_place(Vector2(tp.x + 0.9, tp.z + 0.6), -120.0)
	_view(Vector2(0.9, 1.0), -26.0, 4.8, Vector3(-0.4, 0.4, 0.4))
	await _frames(30)
	GameEvents.notification_requested.emit(Ranch.feed_housing("coop"))
	# ...and collect an egg from the nearest hen.
	for a: Dictionary in Ranch.animals_in("coop"):
		if int(a["product_ready"]) > 0:
			GameEvents.notification_requested.emit(Ranch.collect(int(a["uid"])))
			break
	await _frames(12)
	await _capture("feeding")


func _shot_young_animals() -> void:
	_time(4, 16.0)
	Settings.set_value("dialogue_language", "fa")
	_ranch_stage(true)
	var h := Ranch.housing_def("barn")
	await _frames(20)
	var rw := get_tree().get_first_node_in_group(&"ranch_world") as RanchWorld
	# Gather the young near the camera so they read well.
	var r := rw.paddock_rect(h)
	var i := 0
	for uid in rw.animal_nodes:
		var fa := rw.animal_nodes[uid] as FarmAnimal
		if fa and not fa.adult and Ranch.animal_def(str(Ranch.animal(int(uid)).get("kind", ""))).housing == "barn":
			var p := r.get_center() + Vector2(-2.0 + i * 1.8, 2.2)
			fa.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
			i += 1
	_place(r.get_center() + Vector2(-1.0, 6.2), 180.0)
	_view(Vector2(0.3, 1.0), -22.0, 6.5, Vector3(0.5, 0.4, -3.5))
	await _frames(40)
	await _capture("young-animals")


func _shot_young_chicks() -> void:
	_time(4, 16.0)
	Settings.set_value("dialogue_language", "fa")
	_ranch_stage(true)
	var h := Ranch.housing_def("coop")
	await _frames(20)
	_place(h.position + Vector2(1.5, 8.6), 200.0)
	_view(Vector2(0.4, 1.0), -28.0, 5.2, Vector3(-1.0, 0.3, -2.6))
	await _frames(40)
	await _capture("young-chicks")


# ------------------------------------------------------------------ v5d shots
const NET_DIR := "/tmp/v5d-shots"
const NET_PORT := 8951
var _srv_pid: int = -1
var _bot_pid: int = -1
var _bot_cmds: Array = []
var _net_ready: bool = false


func _spawn(args: PackedStringArray, home: String) -> int:
	var old := OS.get_environment("XDG_DATA_HOME")
	OS.set_environment("XDG_DATA_HOME", home)
	var pid := OS.create_process(OS.get_executable_path(), args)
	if old != "":
		OS.set_environment("XDG_DATA_HOME", old)
	else:
		OS.unset_environment("XDG_DATA_HOME")
	return pid


func _bot(op: String, extra: Dictionary = {}) -> void:
	var c := {"n": _bot_cmds.size() + 1, "op": op}
	c.merge(extra)
	_bot_cmds.append(c)
	var f := FileAccess.open(NET_DIR + "/ctl_B.json", FileAccess.WRITE)
	f.store_string(JSON.stringify({"cmds": _bot_cmds}))
	f.close()


func _bot_status() -> Dictionary:
	var p := NET_DIR + "/status_B.json"
	if not FileAccess.file_exists(p):
		return {}
	var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(p))
	return v if v is Dictionary else {}


## Waits (real time) until cond is true; renders nothing meanwhile.
func _wait_for(cond: Callable, seconds: float) -> bool:
	var vp := get_viewport()
	vp.disable_3d = true
	var t0 := Time.get_ticks_msec()
	var ok := false
	while Time.get_ticks_msec() - t0 < int(seconds * 1000.0):
		if cond.call():
			ok = true
			break
		await get_tree().process_frame
	vp.disable_3d = false
	return ok


func _start_server() -> void:
	var proj := ProjectSettings.globalize_path("res://")
	_srv_pid = _spawn(PackedStringArray(["--headless", "--path", proj, "res://scenes/server/Server.tscn", "--", "--server",
		"--port=%d" % NET_PORT, "--bind=127.0.0.1", "--content=" + NET_DIR + "/content", "--data=" + NET_DIR + "/srvdata"]), NET_DIR + "/home_srv")
	print("v5d shots: server pid %d" % _srv_pid)


func _net_setup() -> bool:
	if _net_ready:
		return Net.state == "online"
	_net_ready = true
	DirAccess.make_dir_recursive_absolute(NET_DIR + "/content")
	for f in ["ctl_B.json", "status_B.json"]:
		DirAccess.remove_absolute(NET_DIR + "/" + f)
	_start_server()
	await _wait_for(func() -> bool: return false, 3.0)
	_bot_cmds = []
	_bot("noop")
	var proj := ProjectSettings.globalize_path("res://")
	_bot_pid = _spawn(PackedStringArray(["--headless", "--path", proj, "--", "--server-url=ws://127.0.0.1:%d" % NET_PORT,
		"--net-test=B", "--net-dir=" + NET_DIR, "--net-name=مریم"]), NET_DIR + "/home_B")
	Settings.set_value("player_name", "آرش")
	Net.connect_to("ws://127.0.0.1:%d" % NET_PORT)
	var ok: bool = await _wait_for(func() -> bool: return Net.state == "online" and Net.roster.size() >= 2, 90.0)
	print("v5d shots: online=%s roster=%d" % [Net.state, Net.roster.size()])
	return ok


func _net_cleanup() -> void:
	if _bot_pid > 0:
		OS.kill(_bot_pid)
	if _srv_pid > 0:
		OS.kill(_srv_pid)
	_bot_pid = -1
	_srv_pid = -1


func _remote() -> RemoteAvatar:
	var ra := get_tree().current_scene.get_node_or_null(^"RemoteAvatars") as RemoteAvatars
	if ra == null:
		return null
	for pid in ra.avatars:
		return ra.avatars[pid]
	return null


func _net_hud() -> NetHud:
	return get_tree().current_scene.get_node_or_null(^"NetHud") as NetHud


func _stage_pair() -> void:
	# Side by side, 2.6 m apart, turned half towards each other and half to the camera.
	_place(Vector2(-2.0, 12.0), 50.0)
	Net.mark_teleport()
	_bot("place", {"xz": [0.6, 12.0], "yaw": -50.0})
	await _wait_for(func() -> bool:
		var r := _remote()
		return r != null and r.global_position.distance_to(Vector3(0.6, r.global_position.y, 12.0)) < 0.5, 10.0)


func _shot_two_players() -> void:
	if not await _net_setup():
		push_error("v5d shots: server not reachable")
		return
	await _stage_pair()
	_view(Vector2(0.12, 1.0), -17.0, 6.5, Vector3(1.3, 0.6, 0.0))
	await _frames(30)
	await _capture("two-players")


func _shot_chat() -> void:
	if not await _net_setup():
		return
	await _stage_pair()
	_bot("chat", {"text": "سلام آرش! بریم بازار؟"})
	await _wait_for(func() -> bool: return Net.chat_log.size() >= 1, 8.0)
	Net.send_chat("سلام مریم! آره، الان میام")
	await _wait_for(func() -> bool: return Net.chat_log.size() >= 2, 8.0)
	var hud := _net_hud()
	hud.open_chat()
	hud.chat_input.text = "گوجه‌ها رو هم بیاریم؟"
	hud.chat_input.caret_column = hud.chat_input.text.length()
	_view(Vector2(0.12, 1.0), -17.0, 6.8, Vector3(1.3, 0.9, 0.0))
	await _frames(30)
	await _capture("chat")
	hud.close_chat()


func _shot_module_update() -> void:
	if not await _net_setup():
		return
	await _stage_pair()
	var src := FileAccess.get_file_as_string("res://modules/wages/fair_wages.tres").replace("default_wage = 60", "default_wage = 75")
	var tmp := NET_DIR + "/fair_wages.tres"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var out: Array = []
	var code := OS.execute("python3", PackedStringArray([ProjectSettings.globalize_path("res://tools/push_module.py"), "wages", "--file", tmp,
		"--variant", "fair_wages", "--content", NET_DIR + "/content", "--skip-gate", "--reason", "screenshot"]), out, true)
	print("v5d shots: push_module exit %d %s" % [code, str(out).right(160)])
	var hud := _net_hud()
	var n0 := hud.banners_shown
	await _wait_for(func() -> bool: return hud.banners_shown > n0, 20.0)
	_view(Vector2(0.12, 1.0), -20.0, 8.0, Vector3(1.3, 0.6, 0.0))
	await _frames(8)
	await _capture("module-update")


func _shot_online_panel() -> void:
	if not await _net_setup():
		return
	var hud := _net_hud()
	hud.open_panel()
	await _frames(20)
	await _capture("online-panel")
	hud.close_panel()


func _shot_away_avatar() -> void:
	if not await _net_setup():
		return
	var r := _remote()
	_bot("quit")
	await _wait_for(func() -> bool:
		var rr := _remote()
		return rr != null and rr.status in ["away_sit", "away_home"], 90.0)
	r = _remote()
	if r == null:
		return
	# Wait for a townsperson to bring tea.
	await _wait_for(func() -> bool: return r.teas >= 1, 40.0)
	var ra := get_tree().current_scene.get_node_or_null(^"RemoteAvatars") as RemoteAvatars
	await _wait_for(func() -> bool:
		for b in get_tree().get_nodes_in_group(&"townspeople"):
			if (b as TownspersonBot).controller is TeaVisitController and (b as Node3D).global_position.distance_to(r.global_position) < 2.5:
				return true
		return false, 30.0)
	var fwd := Vector3(sin(r.visual.rotation.y), 0, cos(r.visual.rotation.y))
	var me := r.global_position + fwd * 4.5 + Vector3(fwd.z, 0, -fwd.x) * 1.5
	_place(Vector2(me.x, me.z), _yaw_towards(Vector2(me.x, me.z), Vector2(r.global_position.x, r.global_position.z)))
	# Frame the avatar: camera behind the farmer looking at the table.
	_view(Vector2(me.x - r.global_position.x, me.z - r.global_position.z).normalized(), -14.0, 3.0, Vector3(0, 0.2, 0))
	await _frames(20)
	print("v5d shots: away avatar %s teas=%d visits=%d" % [r.status, r.teas, ra.visits_started if ra else -1])
	await _capture("away-avatar")


func _shot_welcome_back() -> void:
	if not await _net_setup():
		return
	_place(Vector2(-3, 7.5), 200.0)
	Net.go_offline()
	await _wait_for(func() -> bool: return false, 14.0)
	var hud := _net_hud()
	var n0 := hud.banners_shown
	Net.connect_to("ws://127.0.0.1:%d" % NET_PORT)
	await _wait_for(func() -> bool: return hud.banners_shown > n0 and Net.state == "online", 30.0)
	_view(Vector2(0.55, 1.0), -18.0, 9.0, Vector3(0, 0.3, -1.5))
	await _frames(8)
	await _capture("welcome-back")


func _shot_offline_indicator() -> void:
	if not await _net_setup():
		return
	_place(Vector2(-3, 7.5), 200.0)
	if _srv_pid > 0:
		OS.kill(_srv_pid)
		_srv_pid = -1
	await _wait_for(func() -> bool: return Net.state == "unreachable", 20.0)
	var hud := _net_hud()
	if hud:
		hud.banner.visible = false
	_view(Vector2(0.55, 1.0), -20.0, 14.0, Vector3(0, 0, -3))
	await _frames(30)
	await _capture("offline-indicator")
	Net.go_offline()



# ========================================================================== v6a
func _v6a() -> V6aWorld:
	return get_tree().current_scene.find_child("V6aWorld", true, false) as V6aWorld


## Puts a townsperson near `p` doing `activity` (sit / workout / sunbathe).
func _bot_doing(bot: TownspersonBot, p: Vector3, activity: String, spot: String) -> void:
	var sc := bot.controller as ScheduleController
	if sc:
		sc.current = {"spot": spot, "activity": activity, "from": 0.0, "to": 24.0}
		sc.override_entry = sc.current
		sc.arrived = true
		sc._seat = null
		sc.chat_timer = 0.0
		sc.chat_partner = null
		sc.social_cooldown = 9999.0
	bot.global_position = p + Vector3(0, 0.1, 0)
	bot.velocity = Vector3.ZERO


func _shot_night_sky() -> void:
	var p := Vector2(50.0, 2.0)
	_place(p, 45.0)
	var ns := _v6a().night_sky
	# Pick a night hour when the moon is ~20-35 degrees up (fits the view).
	var hour := 23.0
	for k in 24:
		var hh := 19.5 + k * 0.25
		_time(9, fmod(hh, 24.0), "sunny")
		await _frames(2)
		ns.refresh_now()
		if ns.moon_visible > 0.5 and ns.moon_dir.y > 0.3 and ns.moon_dir.y < 0.55:
			hour = hh
			break
	_time(9, fmod(hour, 24.0), "sunny")
	await _frames(10)
	ns.refresh_now()
	var md := ns.moon_dir
	_view(Vector2(-md.x, -md.z).normalized(), 16.0, 4.5, Vector3(0, 1.4, 0))
	await _frames(60)
	ns.refresh_now()
	await _frames(4)
	print("  moon phase %.2f (%s), dir %s" % [ns.phase, NightSky.phase_name(ns.phase, false), md])
	await _capture("night-sky")


func _shot_day_sky() -> void:
	_time(4, 11.0, "sunny")
	_place(Vector2(50.0, 2.0), 45.0)
	_view(Vector2(-0.7, -0.7), 14.0, 5.0, Vector3(0, 1.4, 0))
	await _frames(60)
	await _capture("day-sky")


func _shot_dry_tree_chop() -> void:
	_time(4, 10.0, "sunny")
	var dt := _v6a().dry_trees
	Lifestyle.reset()
	var i := 0
	var t := dt.spots[i]
	var p := t + Vector2(1.3, 0.4)
	_place(p, _yaw_towards(p, t))
	_view(Vector2(-0.35, 1.0), -10.0, 4.6, Vector3(0, 0.7, 0))
	await _frames(40)
	# Fell the neighbour first so a falling tree + stump show too.
	var j := 1
	var best := 1e9
	for k in range(1, dt.spots.size()):
		var d := dt.spots[k].distance_to(t)
		if d < best:
			best = d
			j = k
	for n in Lifestyle.hits_needed():
		Lifestyle.hit_tree(j)
	dt._fall_fx(j)
	dt.chop(i, _player)
	_player.tools.freeze_at(0.14)
	await _frames(3)
	await _capture("dry-tree-chop")
	_player.tools.freeze_at(5.0)


func _shot_campfire() -> void:
	_time(4, 20.5, "sunny")
	var cf := _v6a().campfire
	Lifestyle.sim_enabled = false
	Economy.add_item("firewood", 4)
	Lifestyle.campfire_until = 0.0
	cf.use(_player)
	var seat := cf.seats[0]
	_place(Vector2(seat.global_position.x, seat.global_position.z), 0.0)
	_player.sit_on(seat)
	var used: Array = []
	for k in range(1, mini(cf.seats.size(), 3)):
		var bot := _bot_with(func(b: TownspersonBot) -> bool: return true, used)
		if bot:
			used.append(bot)
			_bot_doing(bot, cf.seats[k].global_position, "sit", "beach")
	var c := cf.global_position
	_view(Vector2(c.x - seat.global_position.x, c.z - seat.global_position.z).normalized().rotated(0.9) * -1.0, -18.0, 6.5, Vector3(0, 0.2, 0))
	await _frames(80)
	await _capture("campfire")
	_player.stand_up()
	Lifestyle.sim_enabled = true


func _shot_boats() -> void:
	_time(4, 15.0, "sunny")
	var bs := _v6a().boats
	var b := bs.boats[0]
	var p := Vector2(b.board_point.x, b.board_point.z) - BeachBuilder.PIER_DIR * 3.0
	_place(p, 45.0)
	_player.global_position.y = bs.pier_deck() + 0.1
	_view(Vector2(-0.2, -1.0), -20.0, 12.0, Vector3(0, 0.5, 0))
	await _frames(60)
	await _capture("boats")


func _shot_deep_sea() -> void:
	_time(4, 16.5, "sunny")
	var bs := _v6a().boats
	var b := bs.boats[0]
	Economy.money = maxi(Economy.money, 100)
	Economy.add_item("pro_rod", 1)
	_place(Vector2(b.board_point.x, b.board_point.z), 45.0)
	_player.global_position.y = bs.pier_deck() + 0.1
	await _frames(5)
	b.board(_player)
	await _frames(10)
	b.finish_voyage()
	await _frames(10)
	var side := b.global_basis.x
	_player.global_position = b.to_global(Vector3(0.55, 0.3, -0.9))
	(_player.get_node(^"Visual") as Node3D).rotation.y = atan2(side.x, side.z)
	await _frames(10)
	_view(Vector2(-side.x, -side.z).rotated(0.8), -16.0, 7.0, Vector3(0, 0.3, 0))
	_player.fishing.start(_player)
	for k in 200:
		if _player.fishing.state == FishingMinigame.State.WAITING:
			break
		await _frames(1)
	await _frames(20)
	await _capture("deep-sea")
	_player.fishing._finish("")
	b.helm(_player)
	b.finish_voyage()
	await _frames(5)


func _shot_sunbathing() -> void:
	_time(4, 12.5, "sunny")
	var sb := _v6a().sunbathing
	var used: Array = []
	for k in mini(sb.towels.size() - 1, 4):
		var bot := _bot_with(func(b: TownspersonBot) -> bool: return true, used)
		if bot:
			used.append(bot)
			_bot_doing(bot, sb.towels[k + 1].global_position + Vector3(0.6, 0, -0.6), "sunbathe", "sun_beach")
	var t := sb.towels[0]
	_place(Vector2(t.global_position.x, t.global_position.z) + Vector2(-1.0, -1.0), 45.0)
	await _frames(5)
	_player.sit_on(t)
	var st := sb.style()
	var c := st.center
	_view(Vector2(-1.0, 0.25).normalized(), -24.0, 11.0, Vector3(0, 0.0, 0))
	await _frames(90)
	await _capture("sunbathing")
	_player.stand_up()


func _shot_gym() -> void:
	_time(4, 17.5, "sunny")
	var b := _town.buildings["gym"] as Building
	var stations := get_tree().get_nodes_in_group(&"gym_stations")
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y + 180.0)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(20)
	var tread: Seat = null
	for s in stations:
		if str((s as Seat).get_meta(&"pose", "")) == "jog" and tread == null:
			tread = s
	var used: Array = []
	for s in stations:
		if s == tread:
			continue
		var bot := _bot_with(func(bb: TownspersonBot) -> bool: return true, used)
		if bot and used.size() < 3:
			used.append(bot)
			_bot_doing(bot, (s as Seat).global_position, "workout", "in:gym")
	Economy.money = maxi(Economy.money, 100)
	_player.global_position = tread.global_position
	_player.sit_on(tread)
	_view(Vector2(0.7, 1.0).rotated(-b.rotation.y), -30.0, 5.2, Vector3(0, 0.2, 0))
	await _frames(70)
	await _capture("gym")
	_player.stand_up()


func _shot_hypermarket() -> void:
	_time(4, 11.0, "sunny")
	var b := _town.buildings["hypermarket"] as Building
	var c := b.interior_center()
	_place(Vector2(c.x, c.z) + Vector2(0, 0), b.rotation_degrees.y + 90.0)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_view(Vector2(-0.9, 1.0).rotated(-b.rotation.y), -24.0, 3.6, Vector3(0, 0.5, 0))
	await _frames(40)
	await _capture("hypermarket")


func _shot_hypermarket_shop() -> void:
	_time(4, 11.0, "sunny")
	var b := _town.buildings["hypermarket"] as Building
	var desk: InteriorItem = null
	for n in get_tree().get_nodes_in_group(&"interior_items"):
		var it := n as InteriorItem
		if it.kind == "shop_desk" and it.building == b:
			desk = it
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y + 180.0)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(20)
	if desk:
		desk._on_interacted(_player)
	await _frames(20)
	await _capture("hypermarket-shop")
	if _hud.shop_panel.visible:
		_hud.shop_panel.close_shop()
	GameEvents.close_all_modals()


func _shot_persian_topbar() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(3, 9.25)
	_place(Vector2(-3, 7.5), 160.0)
	_view(Vector2(0.55, 1.0), -20.0, 11.0)
	await _frames(30)
	await _capture("persian-topbar")


func _shot_persian_settings() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(3, 9.25)
	_hud.toggle_settings()
	await _frames(10)
	await _capture("persian-settings")
	_hud.settings_panel.close()


# ========================================================================== v6b
func _v6b() -> V6bWorld:
	return get_tree().current_scene.find_child("V6bWorld", true, false) as V6bWorld


func _shot_creator() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(3, 11.0)
	_place(Vector2(-3.0, 7.5), 200.0)
	_view(Vector2(0.0, 1.0), -8.0, 3.2, Vector3(0, 0.1, 0))
	await _frames(20)
	_v6b().creator.open()
	await _frames(30)
	await _capture("creator")
	_v6b().creator.cancel()


func _farm_room(face_to: Vector3, cam_dir: Vector2, pitch: float, dist: float, offset: Vector3 = Vector3(0, 0.4, 0)) -> Building:
	var b := _town.buildings["farmhouse"] as Building
	var c := b.interior_center()
	var p := c + (face_to - c) * 0.45
	_place(Vector2(p.x, p.z), _yaw_towards(Vector2(p.x, p.z), Vector2(face_to.x, face_to.z)))
	_player.global_position.y = b.floor_y() + 0.05
	GameEvents.building_entered.emit(b)
	await _frames(20)
	_view(cam_dir, pitch, dist, offset)
	return b


func _shot_wardrobe() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(3, 16.0)
	var wm := get_tree().get_nodes_in_group(&"wardrobes")
	var target := (wm[0] as Node3D).global_position if wm.size() > 0 else (_town.buildings["farmhouse"] as Building).interior_center()
	var b := _town.buildings["farmhouse"] as Building
	var c := b.interior_center()
	var dir := Vector2(target.x - c.x, target.z - c.z).normalized()
	var side := Vector2(-dir.y, dir.x)
	var p := target - Vector3(dir.x, 0, dir.y) * 1.5 + Vector3(side.x, 0, side.y) * 0.75
	_place(Vector2(p.x, p.z), _yaw_towards(Vector2(p.x, p.z), Vector2(target.x, target.z)))
	_player.global_position.y = b.floor_y() + 0.05
	GameEvents.building_entered.emit(b)
	await _frames(20)
	# The camera sits behind the player, looking at the wardrobe.
	_v6b().wardrobe.open()
	await _frames(2)
	# open() swings the camera round to face the farmer (outfit preview);
	# for the shot, frame the wardrobe itself from behind the farmer.
	_view((-dir).rotated(0.3), -12.0, 2.6, Vector3(dir.x * 0.6 - side.x * 0.4, 0.5, dir.y * 0.6 - side.y * 0.4))
	await _frames(30)
	await _capture("wardrobe")
	_v6b().wardrobe.close()
	GameEvents.building_exited.emit(b)


func _shot_driving() -> void:
	_time(3, 10.5)
	var w := _v6b()
	if w.vehicles.cars.is_empty():
		return
	var car := w.vehicles.cars[0]
	_place(Vector2(car.global_position.x - 2.0, car.global_position.z), 90.0)
	await _frames(6)
	car.get_in(_player)
	car.auto_input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await _frames(40)
	car.auto_input = {}
	car.frame_camera()
	_rig.snap_view(rad_to_deg(atan2(-car.forward().x, -car.forward().z)) + 25.0, -14.0, 7.5)
	await _frames(20)
	await _capture("driving")
	car.get_out()


func _road_view(car: Node3D, side: float, pitch: float, dist: float) -> void:
	var p := car.global_position + Vector3(2.5, 0, 2.5)
	_place(Vector2(p.x, p.z), 0.0)
	_player.visible = false
	var f := -car.global_transform.basis.z
	_view(Vector2(f.x, f.z).rotated(side), pitch, dist, car.global_position - _player.global_position + Vector3(0, 0.8, 0))


func _shot_ambulance() -> void:
	_time(3, 11.0)
	var w := _v6b()
	var amb := w.ambulance
	var bots := _bots()
	var bot: TownspersonBot = null
	for b in bots:
		var tb := b as TownspersonBot
		if tb and not tb.hidden_inside:
			bot = tb
			break
	var hdoor := TownNav.spot_position(Townspeople._spot_for("hospital", "door:"))
	var road := VehicleKit.nearest(hdoor)
	_bot_doing(bot, road.lerp(hdoor, 0.5), "idle", "")
	Needs.npc_fall_ill(bot, "flu")
	amb.call_patient(bot)
	var dd := hdoor - road
	amb.car.place(road, atan2(dd.x, dd.z) + PI * 0.5)
	amb.car.stop()
	amb._on_arrived()
	await _frames(30)
	_road_view(amb.car, 2.3, -14.0, 9.5)
	await _frames(30)
	await _capture("ambulance")
	_player.visible = true


func _shot_police() -> void:
	_time(3, 12.0)
	var w := _v6b()
	var pc := w.police.car
	var road := VehicleKit.nearest(Vector3(0.0, 0, -80.0))
	pc.place(road, 0.0)
	pc.stop()
	pc.set_flashing(true)
	await _frames(20)
	_road_view(pc, 2.6, -12.0, 9.0)
	await _frames(30)
	await _capture("police")
	pc.set_flashing(false)
	_player.visible = true


func _shot_pickup() -> void:
	_time(3, 9.0)
	var w := _v6b()
	var wp := w.pickup
	wp.tree_index = wp._pick_tree()
	var tp := wp._tree_pos() if wp.tree_index >= 0 else wp.forest_pos()
	var to_town := Vector3(0, 0, -50) - tp
	to_town.y = 0.0
	to_town = to_town.normalized()
	var cp := tp + to_town * 4.0
	wp.car.place(Vector3(cp.x, Terrain.height_at(cp.x, cp.z), cp.z), atan2(to_town.x, to_town.z) + PI * 0.5)
	wp._fell_and_load()
	# Freeze the loaded pickup by the felled tree (it would drive off to the yard).
	wp.car.place(Vector3(cp.x, 0, cp.z), atan2(to_town.x, to_town.z) + PI * 0.5)
	wp.car.stop()
	wp.state = WoodPickup.State.CHOPPING
	wp._show_worker(true)
	wp.state = WoodPickup.State.TO_YARD
	await _frames(30)
	wp.car.stop()
	_place(Vector2(cp.x, cp.z) + Vector2(to_town.x, to_town.z) * 2.0, 0.0)
	_player.visible = false
	_view(Vector2(to_town.x, to_town.z).rotated(0.5), -22.0, 9.0, Vector3(cp.x, cp.y + 0.8, cp.z) - _player.global_position - Vector3(to_town.x, 0, to_town.z) * 1.5)
	await _frames(30)
	await _capture("pickup")
	_player.visible = true


func _shot_stove_flame() -> void:
	_time(3, 19.0)
	var stove := _item_of("stove", "farmhouse")
	if stove == null:
		stove = _item_of("stove", "maple3")
	var b := stove.building
	var sp := stove.global_position
	var into := b.interior_center() - sp
	into.y = 0.0
	var p := sp + into.normalized() * 1.0
	_place(Vector2(p.x, p.z), _yaw_towards(Vector2(p.x, p.z), Vector2(sp.x, sp.z)))
	_player.global_position.y = b.floor_y() + 0.05
	GameEvents.building_entered.emit(b)
	await _frames(20)
	var cs := CookingStation.for_stove(stove)
	await _frames(2)
	cs._heat(true)
	var to_s := Vector2(sp.x - p.x, sp.z - p.z).normalized()
	# Low, close and side-on so the blue ring licking round the pan shows.
	_view((-to_s).rotated(0.75), -10.0, 1.3, Vector3(to_s.x * 0.55, -0.45, to_s.y * 0.55))
	await _frames(30)
	await _capture("stove-flame")
	cs._heat(false)
	GameEvents.building_exited.emit(b)


func _shot_open_fridge() -> void:
	_time(3, 15.0)
	for k in ["eggs", "tomato_fresh", "onion", "chicken", "rice"]:
		Economy.add_item(k, 2)
	var fu: FridgeUnit = null
	for n in get_tree().get_nodes_in_group(&"fridges"):
		var f := n as FridgeUnit
		if f and f.building and f.building.layout_id == "farmhouse":
			fu = f
	if fu == null and get_tree().get_nodes_in_group(&"fridges").size() > 0:
		fu = get_tree().get_nodes_in_group(&"fridges")[0] as FridgeUnit
	var b := fu.building
	var fp := fu.global_position
	var front := fu.global_transform.basis.z
	front.y = 0.0
	var p := fp + front.normalized() * 1.3
	_place(Vector2(p.x, p.z), _yaw_towards(Vector2(p.x, p.z), Vector2(fp.x, fp.z)))
	_player.global_position.y = b.floor_y() + 0.05
	GameEvents.building_entered.emit(b)
	await _frames(20)
	fu.refresh_contents()
	fu.open_door()
	_view(Vector2(front.x, front.z).normalized().rotated(0.5), -14.0, 2.4, Vector3(0, 0.6, 0) + (fp - _player.global_position) * 0.5)
	await _frames(40)
	await _capture("open-fridge")
	fu.close_door()
	GameEvents.building_exited.emit(b)


func _shot_tv_paintings() -> void:
	_time(3, 20.0)
	var tv := _item_of("tv", "farmhouse")
	var b := _town.buildings["farmhouse"] as Building
	var target := tv.global_position if tv else b.interior_center()
	var c := b.interior_center()
	var dir := Vector2(target.x - c.x, target.z - c.z).normalized()
	var p := target - Vector3(dir.x, 0, dir.y) * 2.6
	_place(Vector2(p.x, p.z), _yaw_towards(Vector2(p.x, p.z), Vector2(target.x, target.z)))
	_player.global_position.y = b.floor_y() + 0.05
	GameEvents.building_entered.emit(b)
	if tv:
		tv.set_on(true)
	await _frames(20)
	_view(-dir.rotated(0.25), -10.0, 2.2, Vector3(0, 0.6, 0))
	await _frames(30)
	await _capture("tv-paintings")
	GameEvents.building_exited.emit(b)


func _shot_landmark() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(3, 17.0)
	var lm := _v6b().landmark
	var lp := lm.global_position
	_place(Vector2(lp.x + 9.0, lp.z + 11.0), 0.0)
	_view(Vector2(9.0, 11.0).normalized().rotated(0.2), -4.0, 9.0, Vector3(0, 6.5, 0) + (lp - _player.global_position) * 0.45)
	await _frames(40)
	await _capture("landmark")


func _shot_fruit_garden() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(3, 10.0)
	var g := _v6b().gardens
	var t: Dictionary = g.trees[0]
	var tp: Vector3 = t["pos"]
	# Camera on the far side of the orchard, looking back at the family's house.
	var away := Vector2(1.0, 1.4).normalized()
	var hb := _town.buildings.get(str(t["home"])) as Building
	if hb:
		away = Vector2(tp.x - hb.global_position.x, tp.z - hb.global_position.z).normalized()
	_place(Vector2(tp.x, tp.z) + away * 2.2, _yaw_towards(Vector2.ZERO, -away))
	await _frames(20)
	_view(away.rotated(0.35), -24.0, 7.5, Vector3(-away.x * 1.5, 1.0, -away.y * 1.5))
	await _frames(30)
	await _capture("fruit-garden")


func _shot_herding() -> void:
	_time(3, 16.0)
	var h := _v6b().herding
	var st := h.style()
	var gate := Vector2(st.pen.position.x - 2.5, st.pen.get_center().y)
	h._place_in(gate + Vector2(-3.5, 0), 1.6)
	_place(gate + Vector2(-8.0, 0.5), 90.0)
	await _frames(30)
	_view(Vector2(-1.0, -0.8), -32.0, 13.0, Vector3(3.5, 0, 0))
	await _frames(30)
	await _capture("herding")


func _shot_cloud_shadows() -> void:
	_time(3, 12.5, "sunny")
	var cl := _v6b().clouds
	cl.cover_now = 0.45
	_place(Vector2(-3, 7.5), 200.0)
	_view(Vector2(0.55, 1.0), -38.0, 34.0, Vector3(0, 0, -6))
	await _frames(40)
	await _capture("cloud-shadows")


func _shot_gym_v6b() -> void:
	Settings.set_value("dialogue_language", "fa")
	_time(4, 17.5, "sunny")
	var b := _town.buildings["gym"] as Building
	var stations := get_tree().get_nodes_in_group(&"gym_stations")
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y + 180.0)
	_player.global_position.y = b.floor_y() + 0.05
	GameEvents.building_entered.emit(b)
	await _frames(20)
	var used: Array = []
	for s in stations:
		var bot := _bot_with(func(bb: TownspersonBot) -> bool: return true, used)
		if bot and used.size() < 3:
			used.append(bot)
			_bot_doing(bot, (s as Seat).global_position, "workout", "in:gym")
	# Looking at the mirror wall (back of the room) from the door side.
	var mir := get_tree().get_nodes_in_group(&"gym_mirror")
	var mp := (mir[0] as Node3D).global_position if mir.size() > 0 else c
	var d := Vector2(c.x - mp.x, c.z - mp.z).normalized()
	_place(Vector2(c.x, c.z) + d * 1.0, _yaw_towards(Vector2(c.x, c.z), Vector2(mp.x, mp.z)))
	_player.global_position.y = b.floor_y() + 0.05
	_view(d.rotated(0.35), -22.0, 3.4, Vector3(0, 0.4, 0))
	await _frames(60)
	await _capture("gym-v6b")
	GameEvents.building_exited.emit(b)


func _shot_yard_boxes() -> void:
	_time(3, 11.0)
	var pu := _v6b().pushables
	var a := pu.boxes[0]
	var b := pu.boxes[1]
	b.global_position = a.global_position + Vector3(0, pu.SIZE, 0)
	var dg := _v6b().digging
	for bn in get_tree().get_nodes_in_group(&"buildings"):
		(bn as Building).player_inside = false   # earlier shots teleport out of buildings
	var hp := a.global_position + Vector3(-2.0, 0, 1.5)
	dg.dig_at(hp, null)
	_place(Vector2(a.global_position.x - 1.5, a.global_position.z + 2.2), 135.0)
	await _frames(20)
	_view(Vector2(-0.6, 1.0), -24.0, 6.0, Vector3(1.0, 0.3, -1.0))
	await _frames(30)
	await _capture("yard-boxes")


# ========================================================================== v7a
func _v7a() -> V7aWorld:
	return get_tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld


func _hide_card() -> void:
	var card := _hud.get("npc_card") as NpcCard
	if card:
		card._hide()
		card._timer = 99.0


func _adult(skip: Array = []) -> TownspersonBot:
	return _bot_with(func(x: TownspersonBot) -> bool:
		return int(x.resident.get("age", 0)) >= 20 and str(x.resident.get("home", "")) != "" and x.controller is ScheduleController, skip)


func _shot_backstory_card() -> void:
	_time(4, 10.5)
	Settings.set_value("dialogue_language", "fa")
	var c := TownLayout.TOWN_CENTER + Vector2(-2.0, 12.0)
	_place(c, 180.0)
	var b := _adult()
	if b:
		_pin(b, c + Vector2(0.0, -1.8), 0.0)
		Backstories.remember(b, "helped", "You helped me carry the bags home.", "کمکم کردی کیسه‌ها را تا خانه ببرم.")
		await _frames(4)
		b._on_greeted(_player)
		(_hud.get("npc_card") as NpcCard).show_for(b)
	_view(Vector2(0.55, 1.0), -8.0, 4.2, Vector3(0, 1.0, -1.0))
	await _frames(14)
	await _capture("backstory-card")
	(_hud.get("npc_card") as NpcCard)._hide()


func _shot_kids_biking() -> void:
	_time(4, 16.0)
	var k := _v7a().kids
	k.start_play(true)
	await _frames(60)
	k.start_chat()
	var biker: TownspersonBot = null
	for kid: TownspersonBot in k.controllers.keys():
		if (k.controllers[kid] as KidsPlay.KidController).mode == "bike":
			biker = kid
			break
	var c := TownLayout.TOWN_CENTER
	var bp := biker.global_position if biker else Vector3(c.x, 0, c.y + 8.0)
	var out := Vector2(bp.x - c.x, bp.z - c.y).normalized()
	var pp := Vector2(bp.x, bp.z) + out * 3.5 + Vector2(-out.y, out.x) * 2.0
	_place(pp, 0.0)
	_player.visible = false
	_view(out.rotated(0.5), -12.0, 5.0, bp - _player.global_position + Vector3(0, 0.6, 0))
	_hide_card()
	await _frames(4)
	_hide_card()
	await _capture("kids-biking")
	_player.visible = true


func _shot_argument() -> void:
	_time(4, 12.0)
	_v7a().kids.stop_play()
	var c := Vector2(-12.0, -47.5)
	_place(c + Vector2(0, 4.0), 180.0)
	var a := _adult()
	var b := _adult([a])
	for o in _bots():
		var ob := o as TownspersonBot
		if ob != a and int(ob.resident.get("age", 0)) >= 20 and str(ob.resident.get("home", "")) != str(a.resident.get("home", "")) and ob.controller is ScheduleController and not str(ob.resident.get("job", "")).to_lower().contains("police"):
			b = ob
			break
	_bot_doing(a, V7aKit.ground(c.x - 0.7, c.y), "idle", "")
	_bot_doing(b, V7aKit.ground(c.x + 0.7, c.y), "idle", "")
	await _frames(4)
	var cf := _v7a().conflicts
	cf.end("")
	cf.start(a, b, "debt")
	await _frames(40)
	_view(Vector2(0.5, 1.0), -10.0, 5.5, Vector3(0, 1.0, -3.0))
	await _frames(30)
	_hide_card()
	await _capture("argument")
	cf.calm(false)


func _shot_possess() -> void:
	_time(4, 11.0)
	Settings.set_value("dialogue_language", "fa")
	var ps := _v7a().possession
	ps.release()
	var b := _adult()
	var c := Vector2(-20.0, -47.8)
	_bot_doing(b, V7aKit.ground(c.x, c.y), "idle", "")
	_place(c + Vector2(1.0, 0.0), 0.0)
	await _frames(4)
	ps.possess(b)
	await _frames(10)
	_view(Vector2(0.6, 1.0), -12.0, 4.6, Vector3(0, 0.9, 0))
	await _frames(20)
	_hide_card()
	await _capture("possess")
	# The Persian confirmation for a destructive act.
	var house := ps.home_building()
	if house:
		var d := house.door_world_position(3.0)
		_place(Vector2(d.x, d.z), house.rotation_degrees.y + 180.0)
		_view(Vector2(0.4, 1.0).rotated(-house.rotation.y), -14.0, 7.0, Vector3(0, 1.5, 0))
		await _frames(20)
		ps.request_demolish()
		await _frames(8)
		await _capture("possess-confirm")
		ps.dialog.answer(false)
	ps.release()
	await _frames(4)


var _fire_house: Building


func _shot_house_fire() -> void:
	_time(4, 17.3)
	var fs := _v7a().fire
	fs.frozen = true
	# A Maple St home (near the fire station route).
	_fire_house = fs.building_by_id("maple3")
	if _fire_house == null:
		_fire_house = fs.flammables()[2]
	fs.ignite(_fire_house, "Mina Karimi", false)
	var f: Node = fs.fires.get(FireService.id_of(_fire_house))
	if f:
		f.set("intensity", 1.0)
		f.set("burn", 0.35)
	fs.arrive_now()
	await _frames(40)
	if f:
		f.set("intensity", 1.0)
	var d := _fire_house.door_world_position(9.0)
	_place(Vector2(d.x, d.z), _fire_house.rotation_degrees.y + 180.0)
	_player.visible = false
	_view(Vector2(-1.1, 1.0).rotated(-_fire_house.rotation.y), -16.0, 14.0, Vector3(0, 2.0, 0))
	await _frames(30)
	_hide_card()
	await _capture("house-fire")
	fs.frozen = false
	_player.visible = true


func _shot_rebuilt_house() -> void:
	var fs := _v7a().fire
	if _fire_house == null:
		_fire_house = fs.building_by_id("maple3")
		fs.ignite(_fire_house, "accident")
	var id := FireService.id_of(_fire_house)
	var f: Node = fs.fires.get(id)
	if f:
		f.set("burn", 0.5)
		f.set("intensity", 0.0)
	await _frames(4)
	fs._next_or_return()
	fs.truck.place(fs.truck_base(), PI * 0.5)
	fs.truck_state = FireService.Truck.IDLE
	# Next day: scaffold, carpenter + mason at work.
	_time(5, 11.0)
	fs.start_rebuild(id)
	var site := TownNav.spot_position("door:" + id)
	var k := 0
	for job in ["carpenter", "stonemason"]:
		var w := V7aKit.bot_with_job(get_tree(), job)
		if w and site != Vector3.INF:
			_bot_doing(w, site + Vector3(-1.5 + k * 3.0, 0, 0.8), "idle", "")
			w.start_wave(1.0, 1.0, 4.0)
			k += 1
	var d := _fire_house.door_world_position(11.0)
	_place(Vector2(d.x, d.z), _fire_house.rotation_degrees.y + 180.0)
	_player.visible = false
	_view(Vector2(0.7, 1.0).rotated(-_fire_house.rotation.y), -12.0, 8.0, Vector3(0, 2.0, 0))
	await _frames(30)
	_hide_card()
	await _capture("rebuilding-house")
	_time(7, 11.0)
	fs.finish_rebuild(id)
	await _frames(30)
	_hide_card()
	await _capture("rebuilt-house")
	_player.visible = true


func _shot_storm_outage() -> void:
	_time(4, 20.6, "storm")
	var o := _v7a().outages
	o.repair_now()
	await _frames(4)
	o.cut("storm")
	o.van.place(o._line_spot, 0.0)
	o.van.stop()
	o._on_van_arrived()
	await _frames(30)
	var v := o.van.global_position
	var fw := o.van.forward()
	var side := Vector3(-fw.z, 0, fw.x)
	var pp := v + side * 4.0
	_place(Vector2(pp.x, pp.z), 0.0)
	_player.visible = false
	_view(Vector2(side.x, side.z).rotated(0.45), -16.0, 10.0, v - _player.global_position + Vector3(0, 0.8, 0))
	await _frames(40)
	_hide_card()
	await _capture("storm-outage")
	_player.visible = true
	# Candles + lanterns inside a home (v4 lights) while the grid is down.
	var b := _town.buildings["farmhouse"] as Building
	var c := b.interior_center()
	_place(Vector2(c.x, c.z), b.rotation_degrees.y)
	_player.global_position.y = b.floor_y() + 0.05
	await _frames(30)
	_view(Vector2(0.6, 1.0).rotated(-b.rotation.y), -30.0, 3.4)
	await _frames(40)
	await _capture("storm-candles")
	GameEvents.building_exited.emit(b)
	_player.inside_building = null
	o.repair_now()


func _shot_earthquake() -> void:
	_time(4, 13.0)
	var o := _v7a().outages
	var c := TownLayout.TOWN_CENTER + Vector2(-4.0, 9.0)
	_place(c, 160.0)
	_view(Vector2(-0.4, 1.0), -14.0, 6.0, Vector3(0, 0.6, 0))
	await _frames(20)
	o.force_quake(false)
	for i in 8:
		await get_tree().process_frame
	_hide_card()
	await _capture("earthquake")
	o.quake_t = 0.0
	await _frames(4)


func _shot_cityhall_fund() -> void:
	_time(6, 11.0)
	Settings.set_value("dialogue_language", "fa")
	var cf := _v7a().fund
	CityState.add_fine("speeding", 50, "Speeding in town (61 km/h)", "سرعت غیرمجاز در شهر (۶۱ کیلومتر)", false)
	CityState.add_fine("theft", 50, "Fruit taken from a family orchard", "چیدن میوه از باغ مردم بدون اجازه", false)
	CityState.add_income("tax", 40, "Shop taxes", "عوارض مغازه‌ها")
	var b := cf.board
	var p := b.global_position + b.global_transform.basis.z * 3.2
	_place(Vector2(p.x, p.z), b.rotation_degrees.y + 180.0)
	_view(Vector2(0.35, 1.0).rotated(-b.rotation.y), -6.0, 3.0, Vector3(0, 1.0, 0))
	await _frames(30)
	_hide_card()
	await _capture("cityhall-board")
	cf.panel.open()
	await _frames(10)
	await _capture("cityhall-fund")
	cf.panel.close()


func _shot_public_works() -> void:
	_time(8, 11.5)
	var cf := _v7a().fund
	var st := cf.style()
	for pr: Dictionary in st.projects:
		CityState.finish_project(str(pr.get("id", "")))
	var amb := _v6b().ambulance
	amb.state = AmbulanceService.State.IDLE
	amb.car.set_flashing(false)
	amb.car.place(amb.base_pos(), 0.0)
	amb.car.stop()
	await _frames(6)
	var c := Vector2(5.5, -36.0)
	_place(c + Vector2(-6.0, -7.0), 140.0)
	_view(Vector2(-0.8, -1.0), -18.0, 9.5, Vector3(4.0, 0, 4.5))
	await _frames(30)
	_hide_card()
	await _capture("public-works")
	# Flower beds + benches along Main St by City Hall.
	_place(Vector2(14.0, -53.0), 180.0)
	_player.visible = false
	_view(Vector2(0.15, 1.0), -22.0, 9.0, Vector3(0, 0, -4.0))
	await _frames(30)
	_hide_card()
	await _capture("public-works-2")
	_player.visible = true
	# New streetlights on Maple St at night.
	_time(8, 21.5)
	_place(Vector2(-20.0, -84.0), 90.0)
	_view(Vector2(-1.0, 0.25), -10.0, 9.0)
	await _frames(40)
	_hide_card()
	await _capture("public-works-night")


# ==========================================================================
# v7b
func _v7b() -> V7bWorld:
	return get_tree().current_scene.find_child("V7bWorld", true, false) as V7bWorld


func _put_car(car: DrivableCar, p: Vector2, yaw_rad: float) -> void:
	car.speed = 0.0
	car.yaw = yaw_rad
	car.rotation = Vector3(0, yaw_rad, 0)
	car.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.05, p.y)
	car.velocity = Vector3.ZERO


## Earlier v7b shots leave cars[0] near the square; park it at the garage.
func _park_car_away() -> void:
	var cars: Array = _v6b().vehicles.cars
	if not cars.is_empty():
		_put_car(cars[0], Vector2(54.5, -59.0), PI)


## Fill the terrace: staff on duty, guests seated (teleported next to seats).
func _cafe_evening(hour: float) -> TerraceCafe:
	var w := _v7b()
	w.chatter.auto = false
	w.cafe.auto = false
	_time(5, hour)
	w.staffing.tick()
	var cafe := w.cafe
	for i in 5:
		var g := cafe.invite_guest()
		if g == null:
			break
		var sc := g.controller as TerraceCafe.GuestController
		if sc and sc.seat:
			g.global_position = sc.seat.global_position + Vector3(0, 0.1, 0)
	for role in ["bartender", "dj"]:
		var b := w.staffing.holder(role)
		if b:
			b.global_position = (w.staffing.posts[role]["spot"] as Vector3) + Vector3(0, 0.1, 0)
	return cafe


func _cafe_view(dist: float, pitch: float, side: float = 0.0) -> void:
	var cafe := _v7b().cafe
	var c := cafe.root.global_position
	var out := cafe.root.global_transform.basis.z.normalized()  # terrace front
	var p := c + out.rotated(Vector3.UP, side) * 6.5
	_place(Vector2(p.x, p.z), 0.0)
	_player.visible = false
	var d := out.rotated(Vector3.UP, side)
	_view(Vector2(d.x, d.z), pitch, dist, c - _player.global_position + Vector3(0, 1.0, 0))


func _shot_cafe_night_dj() -> void:
	Settings.set_value("dialogue_language", "fa")
	var cafe := _cafe_evening(21.3)
	await _frames(40)
	_cafe_view(15.0, -20.0, 0.5)
	await _frames(30)
	var dj := cafe.dj()
	if dj:
		V7bKit.say_small(dj, V7bKit.line(cafe.style().lines.get("dj", [])), 30.0)
	var bt := cafe.bartender()
	if bt:
		V7bKit.say_small(bt, V7bKit.line(cafe.style().lines.get("bartender_greet", [])), 30.0)
	await _frames(20)
	_hide_card()
	await _capture("cafe-night-dj")
	_player.visible = true


func _shot_cafe_menu() -> void:
	var cafe := _cafe_evening(20.0)
	var bs := cafe.bar_spot.global_position
	_place(Vector2(bs.x, bs.z), 0.0)
	_player.visible = true
	await _frames(30)
	_cafe_view(9.0, -18.0, -0.3)
	await _frames(20)
	Economy.money = 300
	cafe.open_menu()
	cafe.menu_panel._status.text = Lang.tt("نوش جان! چای ایرانی", "Enjoy your tea!")
	await _frames(10)
	_hide_card()
	await _capture("cafe-menu")
	cafe.menu_panel.close()


func _shot_cafe_fight() -> void:
	var cafe := _cafe_evening(22.4)
	await _frames(30)
	cafe.start_fight()
	for i in 40:
		await get_tree().process_frame
	var f := cafe.fight
	if not f.is_empty():
		var a := f["a"] as TownspersonBot
		var b := f["b"] as TownspersonBot
		var mid: Vector3 = f["pos"]
		a.global_position = mid + Vector3(0.6, 0.1, 0)
		b.global_position = mid + Vector3(-0.6, 0.1, 0)
		V7bKit.say_small(a, Lang.tt("دیگر خسته شدم!", "I've had enough of this!"), 30.0)
		V7bKit.say_small(b, Lang.tt("تو همیشه همینی!", "You're always like this!"), 30.0)
		var bt := cafe.bartender()
		if bt:
			bt.global_position = mid + Vector3(0, 0.1, 1.2)
			V7bKit.say_small(bt, V7bKit.line(cafe.style().lines.get("breakup", [])), 30.0)
		_place(Vector2(mid.x + 4.0, mid.z + 3.0), 0.0)
		_player.visible = false
		_view(Vector2(1.0, 0.8), -16.0, 7.0, mid - _player.global_position + Vector3(0, 1.0, 0))
	await _frames(20)
	_hide_card()
	await _capture("cafe-fight")
	cafe.end_fight(true, "bartender")
	_player.visible = true


func _shot_tipsy() -> void:
	_cafe_evening(21.0)
	var w := _v7b()
	TownLife.tipsy = 55.0
	var c := w.cafe.root.global_position + w.cafe.root.global_transform.basis.z * 7.0
	_place(Vector2(c.x, c.z), 200.0)
	_player.visible = true
	_view(Vector2(0.6, -1.0), -14.0, 6.0, Vector3(0, 0.8, 0))
	for i in 50:
		await get_tree().process_frame
	await _frames(10)
	_hide_card()
	await _capture("tipsy")
	TownLife.tipsy = 0.0
	await _frames(4)


func _shot_mechanic() -> void:
	var w := _v7b()
	_time(5, 11.0)
	w.staffing.tick()
	var shop := w.mechanic
	var car := _v6b().vehicles.cars[0]
	_put_car(car, Vector2(54.5, -59.0), PI)
	w.driving.attach_all()
	var m := shop.mechanic()
	if m:
		m.global_position = shop.at(Vector3(-1.4, 0, 1.6)) + Vector3(0, 0.1, 0)
		V7bKit.say_small(m, V7bKit.line(shop.style().lines.get("greet", [])), 30.0)
	_place(Vector2(57.5, -55.0), 200.0)
	_player.visible = true
	_view(Vector2(0.55, 1.0), -14.0, 11.0, Vector3(-1.0, 1.0, -4.5))
	await _frames(40)
	_hide_card()
	await _capture("mechanic")


func _shot_mechanic_panel() -> void:
	var w := _v7b()
	_time(5, 11.0)
	w.staffing.tick()
	var car := _v6b().vehicles.cars[0]
	_put_car(car, Vector2(54.5, -59.0), PI)
	w.driving.last_car = car
	var s := TownLife.car(car.key)
	s["condition"] = 64.0
	s["fuel"] = 23.0
	s["upgrades"] = ["led_lights"]
	Economy.money = 900
	await _frames(20)
	w.mechanic.open_panel()
	await _frames(10)
	await _capture("mechanic-panel")
	w.mechanic_panel.close()


func _shot_dashboard_night() -> void:
	var w := _v7b()
	_time(5, 21.8)
	var car := _v6b().vehicles.cars[0]
	_put_car(car, Vector2(20.0, -54.7), PI * 0.5)
	w.driving.attach_all()
	TownLife.car(car.key)["fuel"] = 72.0
	TownLife.car(car.key)["condition"] = 88.0
	_place(Vector2(18.0, -52.5), 90.0)
	await _frames(6)
	car.get_in(_player)
	var sys := car.get_node(^"CarSystems") as CarSystems
	sys.set_auto(false)
	sys.gear = 3
	if not sys.lights_on:
		sys.toggle_lights()
	car.auto_input = {"throttle": 0.6, "steer": 0.0, "brake": false}
	await _frames(30)
	car.auto_input = {}
	car.frame_camera()
	_rig.snap_view(rad_to_deg(atan2(-car.forward().x, -car.forward().z)) + 20.0, -12.0, 8.0)
	await _frames(20)
	_hide_card()
	await _capture("dashboard-night")
	car.get_out()


func _shot_passenger() -> void:
	var w := _v7b()
	_time(5, 17.5)
	var ps := w.passengers
	var a := V7aKit.bot_named(get_tree(), "Parvin Ahmadi")
	ps.request(a, "square", "hospital")
	var car := _v6b().vehicles.cars[0]
	var sp := ps.stop_pos(ps.from_stop)
	# on Main St (z=-50), westbound lane, pulling up to the stop on the sidewalk
	_put_car(car, Vector2(sp.x + 11.0, -48.4), -PI * 0.5)
	_place(Vector2(sp.x + 11.0, -46.4), -90.0)
	await _frames(6)
	car.get_in(_player)
	await _frames(20)
	a.start_wave(30.0)
	V7bKit.say_small(a, V7bKit.line(ps.style().lines.get("hail", [])), 30.0)
	car.frame_camera()
	_rig.snap_view(rad_to_deg(atan2(-car.forward().x, -car.forward().z)) + 20.0, -15.0, 10.0)
	await _frames(20)
	_hide_card()
	await _capture("passenger")
	car.get_out()
	ps.cancel()


func _shot_camping() -> void:
	var w := _v7b()
	_time(6, 20.8)
	var cp := w.camping
	var spot: Dictionary = cp.style().spots[0]
	var sp: Vector2 = spot["pos"]
	_place(sp + Vector2(-1.5, 1.5), 120.0)
	Economy.money = 100
	cp.setup(str(spot["id"]))
	await _frames(30)
	_player.visible = true
	_view(Vector2(-0.9, 1.0), -16.0, 8.5, Vector3(1.4, 0.6, -0.6))
	await _frames(40)
	_hide_card()
	await _capture("camping")
	cp.pack()


func _shot_newspaper() -> void:
	var w := _v7b()
	_time(6, 9.0)
	Settings.set_value("dialogue_language", "fa")
	CityState.fires += 1
	CityState.arguments += 2
	CityState.calmed += 1
	CityState.add_fine("no_lights", 30, "Driving at night without headlights", "رانندگی در شب بدون چراغ", false)
	TownLife.cafe["fights"] = int(TownLife.cafe.get("fights", 0)) + 1
	TownLife.rides["delivered"] = int(TownLife.rides.get("delivered", 0)) + 2
	_park_car_away()
	var np := w.newspaper
	var st := np.style()
	var p := V7aKit.ground(st.stand_pos.x, st.stand_pos.y + 2.4)
	_place(Vector2(p.x, p.z), 180.0)
	_player.visible = true
	_view(Vector2(-1.0, 0.45), -16.0, 6.5, Vector3(0, 1.0, -1.2))
	await _frames(30)
	_hide_card()
	await _capture("newsstand")
	Economy.money = 50
	TownLife.paper_day = -1
	np.compose(true)
	np.buy()
	await _frames(10)
	await _capture("newspaper")
	w.newspaper_panel.close()


func _shot_chat_log() -> void:
	var w := _v7b()
	_time(6, 12.0)
	Settings.set_value("dialogue_language", "fa")
	var c := TownLayout.TOWN_CENTER + Vector2(-3.0, 6.0)
	var a := V7aKit.bot_named(get_tree(), "Shirin Moradi")
	var b := V7aKit.bot_named(get_tree(), "Golnar Tehrani")
	_bot_doing(a, V7aKit.ground(c.x + 1.0, c.y - 0.8), "chat", "")
	_bot_doing(b, V7aKit.ground(c.x + 2.2, c.y - 0.2), "chat", "")
	_place(c + Vector2(-1.5, 1.5), 120.0)
	_view(Vector2(-0.7, 1.0), -12.0, 6.5, Vector3(1.6, 0.8, -0.8))
	await _frames(20)
	w.chatter.end_chat()
	w.chatter.start_chat(a, b, "fund")
	for i in 3:
		w.chatter.step_chat()
	w.chatter.react("power_back", Vector3.INF, true)
	if not w.chat_log.visible:
		w.chat_log.toggle()
	w.chat_log.refresh()
	await _frames(20)
	_hide_card()
	await _capture("chat-log")
	w.chat_log.toggle()
	w.chatter.end_chat()


func _shot_haggle() -> void:
	var w := _v7b()
	_time(6, 15.0)
	_park_car_away()
	var s := V7aKit.bot_named(get_tree(), "Sara Ahmadi")
	var c := TownLayout.TOWN_CENTER + Vector2(4.0, 6.0)
	_bot_doing(s, V7aKit.ground(c.x + 1.2, c.y), "idle", "")
	_place(c, 90.0)
	var item := ""
	for id in ["tomato", "potato", "turnip", "milk", "egg"]:
		if Economy.item_type(id) in ["produce", "animal_product"]:
			item = id
			break
	Economy.add_item(item, 6)
	_view(Vector2(-0.3, -1.0), -10.0, 4.5, Vector3(0.6, 0.9, 0))
	await _frames(20)
	w.haggle.start(s, item)
	w.haggle.ask_more()
	await _frames(10)
	_hide_card()
	await _capture("haggle")
	w.haggle.close()
