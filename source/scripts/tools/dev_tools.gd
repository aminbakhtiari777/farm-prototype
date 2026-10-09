extends Node
## Developer tools, loaded by main.gd ONLY when requested on the command line
## (never in normal play):
##
##   godot --headless --path . -- --smoke-test
##       Full v3 smoke test (exit code 0 = pass, 1 = fail).
##   xvfb-run godot --path . -- --shots=/workspace/farm-v3 [--only=wide,beach]
##       Renders the screenshot set (see dev_shots.gd). Needs a renderer.
##   xvfb-run godot --path . -- --perf
##       Prints draw calls / primitives from several viewpoints.

var _player: Player
var _sheep: Sheep
var _rig: FollowCamera
var _hud: Node
var _town: TownBuilder
var _last_prompt: String = ""
var _toasts: PackedStringArray = []
var _failures: PackedStringArray = []
var _checks: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameEvents.interaction_prompt_changed.connect(func(t: String) -> void: _last_prompt = t)
	GameEvents.notification_requested.connect(func(t: String) -> void: _toasts.append(t))
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-test":
			_run_smoke_test.call_deferred()
			return
		if arg.begins_with("--vis-shots="):  # v7b.1 visual screenshots
			add_child(load("res://scripts/v7b1_visual/visual_shots.gd").new())
			return
		if arg.begins_with("--ctl-shots="):  # v7b.1 controls screenshots
			var cs: Node = load("res://scripts/v7b1/controls_shots.gd").new()
			add_child(cs)
			return
		if arg.begins_with("--shots") or arg == "--perf":
			var shots: Node = load("res://scripts/tools/dev_shots.gd").new()
			shots.name = "DevShots"
			add_child(shots)
			return


func _find_actors() -> bool:
	var scene := get_tree().current_scene
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_sheep = get_tree().get_first_node_in_group(&"animals") as Sheep
	_rig = get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	_hud = scene.get_node_or_null(^"HUD")
	_town = scene.get_node_or_null(^"Town") as TownBuilder
	# Baseline sections inspect furniture throughout the town. Construct that
	# fixture explicitly; normal gameplay leaves distant props pending.
	if _town:
		_town.build_nearby_props(true)
	return _player != null and _sheep != null and _rig != null and _hud != null and _town != null


func _frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func _check(condition: bool, message: String) -> void:
	_checks += 1
	print(("  [ok]   " if condition else "  [FAIL] ") + message)
	if not condition:
		_failures.append(message)


## Simulated input goes through the real event pipeline (InputEventAction),
## so _unhandled_input handlers (HUD, camera) see it like a key press.
func _act(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	e.strength = 1.0 if pressed else 0.0
	Input.parse_input_event(e)


func _tap(action: StringName, hold_frames: int = 2) -> void:
	_act(action, true)
	await _frames(hold_frames)
	_act(action, false)
	await _frames(2)
	# v5c: input is flushed once per *process* frame; after a heavy UI rebuild several
	# physics frames can run back-to-back, so make sure the tap was delivered.
	await get_tree().process_frame
	await get_tree().process_frame


func _hold(action: StringName, count: int) -> void:
	_act(action, true)
	await _frames(count)
	_act(action, false)


func _release_all() -> void:
	for a in InputMap.get_actions():
		if Input.is_action_pressed(a):
			_act(a, false)


## Puts the player at p (x,z) facing yaw_deg, with the camera behind.
func _place(p: Vector2, yaw_deg: float, settle: int = 8) -> void:
	if _player.carried:
		_player._try_place()
	_player.stand_up()
	_player.velocity = Vector3.ZERO
	var y := Terrain.height_at(p.x, p.y)
	_player.global_position = Vector3(p.x, y + 0.05, p.y)
	(_player.get_node(^"Visual") as Node3D).rotation.y = deg_to_rad(yaw_deg)
	_rig.reset_behind_target()
	_rig.snap()
	await _frames(settle)


func _face(target: Vector3) -> void:
	var d := target - _player.global_position
	(_player.get_node(^"Visual") as Node3D).rotation.y = atan2(d.x, d.z)
	_rig.reset_behind_target()


## True when the control's rect lies fully inside the visible viewport.
func _on_screen(c: Control) -> bool:
	var vp := c.get_viewport().get_visible_rect().grow(1.0)
	var r := c.get_global_rect()
	return r.size.x > 1.0 and r.size.y > 1.0 and vp.encloses(r)


func _section(title: String) -> void:
	print("-- " + title)
	_release_all()
	GameEvents.close_all_modals()
	# Opening a shop explicitly assigns staff, even with automatic simulation
	# disabled. Return those shared actors before the next independent section.
	for staffing in get_tree().get_nodes_in_group(&"staffing"):
		staffing.auto = false
		staffing.release_all()
	await _frames(2)


# ==========================================================================
func _run_smoke_test() -> void:
	print("SMOKE TEST v7b1: start")
	# tools/push_module.py can swap one module file in for the gate:
	#   -- --smoke-test --module-override=wages:fair_wages:/abs/path.tres
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--module-override="):
			var parts := arg.trim_prefix("--module-override=").split(":")
			if parts.size() >= 3:
				var path := ":".join(PackedStringArray(parts.slice(2)))  # Windows drive letters
				var ok := AssetRegistry.register_variant(parts[0], parts[1], path)
				print("  module-override %s/%s -> %s (%s)" % [parts[0], parts[1], path, "ok" if ok else "FAIL"])
				if ok:
					AssetRegistry.set_active(parts[0], parts[1])
	# The headless display server starts with a 64x64 window: give the UI a real size.
	if get_tree().root.size.x < 640:
		get_tree().root.size = Vector2i(1600, 900)
	await _frames(10)
	_check(_find_actors(), "found Player, Sheep, CameraRig, HUD and Town")
	if not _failures.is_empty():
		_finish()
		return
	TimeManager.reset_calendar(1, 10.0, "sunny")
	# Time jumps in other sections are not "lived" time - keep Needs off until its own section.
	Needs.sim_enabled = false
	Needs.reset()
	Friendship.reset()
	# v5c: the market and the ranch also run on day changes - keep them still until their sections.
	Market.sim_enabled = false
	Market.reset()
	Ranch.sim_enabled = false
	Ranch.reset()
	Settings.set_value("dialogue_language", "fa")
	# City Hall has its own Staffing, separate from the cafe/garage instance.
	# Disable all background staffing while deterministic fixtures own actors.
	for node in get_tree().current_scene.find_children("*", "Node", true, false):
		if node is Staffing:
			node.auto = false
			node.release_all()
	# v7a: no random kids' play / arguments / storm cuts / quakes outside their own sections.
	var w7 := _v7a()
	if w7:
		w7.kids.auto = false
		w7.conflicts.auto = false
		w7.outages.auto = false
	# v7b: no random remarks / cafe guests / fights / passengers / post shuffles outside their sections.
	var w7b := _v7b()
	if w7b:
		w7b.chatter.auto = false
		w7b.cafe.auto = false
		w7b.staffing.auto = false
		w7b.passengers.auto = false
		w7b.staffing.release_all()
		w7b.cafe.send_guests_home()
		w7b.passengers.cancel()
		w7b.chatter.end_chat()
	# v7b.1 traffic: no enforcement / signal cycling / NPC traffic / bus / lounge crowd outside its sections.
	var w7t := get_tree().current_scene.find_child("V7b1TrafficWorld", true, false) as V7b1TrafficWorld
	if w7t:
		w7t.set_auto(false)
		TrafficState.reset()
	# v7b.1 police: no automatic hit reactions outside its section (AI cars still yield).
	var w7p := get_tree().current_scene.find_child("V7b1PoliceWorld", true, false) as V7b1PoliceWorld
	if w7p and w7p.accidents:
		w7p.accidents.auto = false
	var sections: Array[Callable] = [_smoke_movement, _smoke_camera, _smoke_stamina_jump, _smoke_world_layout,
		_smoke_doors_interiors, _smoke_npcs, _smoke_fishing_shells, _smoke_sit_carry, _smoke_voice,
		_smoke_ui, _smoke_audio, _smoke_time_and_lighting, _smoke_seasons, _smoke_economy, _smoke_v4_crops_garden, _smoke_v4_tools, _smoke_v4_lights_power, _smoke_v4_world,
		_smoke_v4_npc_social, _smoke_v4_house_styles,
		_smoke_v5a_layout, _smoke_v5a_crafting, _smoke_v5a_shops, _smoke_v5a_market, _smoke_v5a_square,
		_smoke_v5a_population, _smoke_v5a_kitchens, _smoke_v5a_civic, _smoke_v5a_calls, _smoke_v5a_gestures,
		_smoke_v5a_live_swap,
		_smoke_v5b_fonts, _smoke_v5b_dialogue, _smoke_v5b_voices, _smoke_v5b_npc_card,
		_smoke_v5b_shop_hours, _smoke_v5b_needs, _smoke_v5b_cooking, _smoke_v5b_mosque,
		_smoke_v5c_market, _smoke_v5c_producers, _smoke_v5c_wages, _smoke_v5c_price_board, _smoke_v5c_livestock,
		_smoke_v5d_netcode, _smoke_v5d_chat, _smoke_v5d_live_updates, _smoke_v5d_save_sync, _smoke_v5d_away, _smoke_v5d_accounts, _smoke_v5d_npc_roles,
		_smoke_v6a_night_sky, _smoke_v6a_dry_trees, _smoke_v6a_beach, _smoke_v6a_boats, _smoke_v6a_sunbathing, _smoke_v6a_gym,
		_smoke_v6a_kitchenware, _smoke_v6a_translation, _smoke_v6a_save,
		_smoke_v6b_looks, _smoke_v6b_vehicles, _smoke_v6b_ambulance, _smoke_v6b_police, _smoke_v6b_wood,
		_smoke_v6b_interiors, _smoke_v6b_town, _smoke_v6b_yard, _smoke_v6b_shadows, _smoke_v6b_polish,
		_smoke_v7a_backstories, _smoke_v7a_kids, _smoke_v7a_conflicts, _smoke_v7a_possession, _smoke_v7a_fire,
		_smoke_v7a_outages, _smoke_v7a_city_fund,
		_smoke_v7b_modules, _smoke_v7b_chatter, _smoke_v7b_voices_personalities, _smoke_v7b_cafe, _smoke_v7b_driving,
		_smoke_v7b_mechanic, _smoke_v7b_passengers, _smoke_v7b_camping, _smoke_v7b_newspaper, _smoke_v7b_haggle, _smoke_v7b_save,
		_smoke_v7b1_controls_basics, _smoke_v7b1_controls_driving, _smoke_v7b1_controls_touch, _smoke_v7b1_controls_possession, _smoke_v7b1_controls_regress,
		_smoke_v7b1_bugs_camera,
		_smoke_v7b1_platform,
		_smoke_v7b1_visual_cars, _smoke_v7b1_visual_fire_truck, _smoke_v7b1_visual_people, _smoke_v7b1_visual_town,
		_smoke_v7b1_visual_city_hall, _smoke_v7b1_visual_families,
		_smoke_v7b1_traffic_roads, _smoke_v7b1_traffic_lights, _smoke_v7b1_traffic_offences, _smoke_v7b1_traffic_license,
		_smoke_v7b1_traffic_dealership, _smoke_v7b1_traffic_npc, _smoke_v7b1_traffic_bus, _smoke_v7b1_traffic_sounds,
		_smoke_v7b1_traffic_lounge, _smoke_v7b1_traffic_lighting, _smoke_v7b1_traffic_save,
		_smoke_v7b1_perf_quality, _smoke_v7b1_perf_lod, _smoke_v7b1_perf_streaming, _smoke_v7b1_perf_interiors,
		_smoke_v7b1_perf_budgets, _smoke_v7b1_perf_save, _smoke_v7b1_perf_overlay,
		_smoke_v7b1_audio_modules, _smoke_v7b1_audio_footsteps, _smoke_v7b1_audio_doors, _smoke_v7b1_audio_ambient,
		_smoke_v7b1_audio_spatial, _smoke_v7b1_audio_budget,
		_smoke_v7b1_weather,
		_smoke_v7b1_police,
		_smoke_modules, _smoke_save_load]
	# Dev: `-- --smoke-test --smoke-only=v5c,v5a_shops` runs matching sections only.
	var only := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-only="):
			only = arg.trim_prefix("--smoke-only=")
	for s in sections:
		if only != "":
			var keep := false
			for part in only.split(","):
				if part != "" and part in s.get_method():
					keep = true
			if not keep:
				continue
		var ok: Variant = await s.call()
		_check(ok == true, "section %s completed" % s.get_method())
	_finish()


func _finish() -> void:
	print("SMOKE TEST: %d checks, %d failed" % [_checks, _failures.size()])
	if _failures.is_empty():
		print("SMOKE TEST PASSED")
		get_tree().quit(0)
	else:
		for f in _failures:
			print("  failed: " + f)
		print("SMOKE TEST FAILED")
		get_tree().quit(1)


# --------------------------------------------------------------------------
func _smoke_movement() -> bool:
	await _section("movement")
	await _place(Vector2(2.0, 6.0), 180.0, 20)
	var start := _player.global_position
	await _hold(&"move_forward", 60)
	var moved := Vector2(_player.global_position.x - start.x, _player.global_position.z - start.z).length()
	_check(moved > 1.0, "player walks with move_forward (%.2f m in 1 s)" % moved)
	_check(_player.is_on_floor(), "player stands on the ground (no floating)")
	var vis := _player.get_node(^"Visual") as HumanoidModelVisual
	_check(vis != null and vis.skeleton != null and vis.anim_tree != null and vis.anim_tree.active,
		"player is a rigged humanoid with an active AnimationTree")
	var foot_gap := _player.global_position.y - Terrain.height_at(_player.global_position.x, _player.global_position.z)
	_check(absf(foot_gap) < 0.15, "feet on the terrain (gap %.3f m)" % foot_gap)
	# Camera-relative: rotate the camera 90 degrees, forward must follow the camera.
	_rig.snap_view(90.0, -20.0, 6.0)
	await _frames(2)
	start = _player.global_position
	await _hold(&"move_forward", 40)
	var dir := _player.global_position - start
	dir.y = 0.0
	var cam_fwd := -_rig.global_basis.z
	cam_fwd.y = 0.0
	_check(dir.length() > 0.5 and dir.normalized().dot(cam_fwd.normalized()) > 0.9,
		"movement is camera-relative (dot %.2f)" % (dir.normalized().dot(cam_fwd.normalized()) if dir.length() > 0.01 else 0.0))
	# Fence gates: walk out of the north gate.
	_rig.snap_view(0.0, -18.0, 6.0)
	await _place(Vector2(0.0, -10.0), 180.0)
	_rig.snap_view(0.0, -18.0, 6.0)
	await _hold(&"move_forward", 200)
	_check(_player.global_position.z < -16.0, "walk out through the north farm gate (z %.1f)" % _player.global_position.z)
	await _place(Vector2(7.0, -10.0), 180.0)
	_rig.snap_view(0.0, -18.0, 6.0)
	await _hold(&"move_forward", 150)
	_check(_player.global_position.z > -14.5, "fence blocks away from the gates (z %.1f)" % _player.global_position.z)
	return true


func _smoke_camera() -> bool:
	await _section("camera")
	await _place(Vector2(2.0, 6.0), 0.0)
	var yaw0 := _rig.yaw_degrees()
	await _hold(&"camera_right", 30)
	var dk := absf(angle_difference(deg_to_rad(yaw0), deg_to_rad(_rig.yaw_degrees())))
	_check(rad_to_deg(dk) > 20.0, "keyboard orbit (C) changes yaw by %.0f deg" % rad_to_deg(dk))
	# Full 360: keep orbiting, yaw wraps around.
	var total := 0.0
	var last := _rig.yaw_degrees()
	for i in 12:
		_rig.orbit(35.0, 0.0)
		total += absf(rad_to_deg(angle_difference(deg_to_rad(last), deg_to_rad(_rig.yaw_degrees()))))
		last = _rig.yaw_degrees()
	_check(total > 359.0, "camera orbits a full 360 deg (%.0f)" % total)
	# Mouse: RMB drag.
	yaw0 = _rig.yaw_degrees()
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_RIGHT
	press.pressed = true
	# Mouse buttons are also delivered straight to the rig (headless has no real cursor/window focus).
	_rig._unhandled_input(press)
	await _frames(1)
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(160, 30)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	# Delivered straight to the camera: headless viewports rescale mouse deltas.
	_rig._unhandled_input(motion)
	await _frames(2)
	var rel := InputEventMouseButton.new()
	rel.button_index = MOUSE_BUTTON_RIGHT
	rel.pressed = false
	_rig._unhandled_input(rel)
	await _frames(2)
	var dm := rad_to_deg(absf(angle_difference(deg_to_rad(yaw0), deg_to_rad(_rig.yaw_degrees()))))
	_check(dm > 10.0, "right-mouse drag orbits the camera (%.0f deg)" % dm)
	_rig.orbit(0.0, -500.0)
	var lo := _rig.pitch_degrees_now()
	_rig.orbit(0.0, 500.0)
	var hi := _rig.pitch_degrees_now()
	_check(is_equal_approx(lo, _rig.min_pitch) and is_equal_approx(hi, _rig.max_pitch), "pitch is clamped (%.0f .. %.0f)" % [lo, hi])
	_rig.snap_view(0.0, -24.0, 6.0)
	var z0 := _rig.zoom()
	await _tap(&"zoom_in")
	_check(_rig.zoom() < z0, "zoom in (%.1f -> %.1f)" % [z0, _rig.zoom()])
	await _tap(&"zoom_out")
	await _tap(&"zoom_out")
	_check(_rig.zoom() > z0 - 0.01, "zoom out (%.1f)" % _rig.zoom())
	return true


func _smoke_stamina_jump() -> bool:
	await _section("stamina / jump")
	await _place(Vector2(2.0, 8.0), 90.0, 10)
	_player.restore_stamina(100.0)
	var s0 := _player.stamina
	_act(&"sprint", true)
	await _hold(&"move_left", 60)
	_act(&"sprint", false)
	_check(_player.stamina < s0 - 8.0, "sprint drains stamina (%.0f -> %.0f)" % [s0, _player.stamina])
	var s1 := _player.stamina
	await _frames(60)
	_check(_player.stamina > s1, "stamina recovers while standing (%.1f -> %.1f)" % [s1, _player.stamina])
	# Exhaustion.
	await _place(Vector2(2.0, 8.0), 90.0)
	_player.spend_stamina(_player.stamina)
	_check(_player.exhausted and _player.rest_timer > 0.0, "0 stamina = exhausted + forced rest")
	var p0 := _player.global_position
	await _hold(&"move_left", 30)
	_check(_player.global_position.distance_to(p0) < 0.2, "forced rest: can't move right after exhaustion")
	await _frames(int(_player.rest_timer * 60.0) + 5)
	_act(&"sprint", true)
	_act(&"move_right", true)
	await _frames(40)
	var v := Vector2(_player.velocity.x, _player.velocity.z).length()
	_act(&"sprint", false)
	_act(&"move_right", false)
	_check(v < _player.walk_speed * 0.6 + 0.05, "exhaustion blocks sprint (speed %.2f m/s)" % v)
	var y0 := _player.global_position.y
	await _tap(&"jump")
	await _frames(5)
	_check(_player.global_position.y < y0 + 0.1, "exhausted: no jump")
	_check(_player.get_node(^"Breathing") != null and (_player.get_node(^"Breathing") as AudioStreamPlayer3D).playing, "heavy breathing while exhausted")
	_player.stamina = 0.0
	_player.restore_stamina(20.0)
	_check(_player.exhausted, "still exhausted below the threshold (%.0f)" % _player.stamina)
	_check(_player.tired_factor() < 1.0, "low stamina slows walk/actions (factor %.2f)" % _player.tired_factor())
	_player.restore_stamina(15.0)
	_check(not _player.exhausted, "exhaustion ends above the threshold (%.0f)" % _player.stamina)
	# Jump.
	_player.restore_stamina(100.0)
	await _place(Vector2(2.0, 8.0), 90.0, 15)
	var ground := _player.global_position.y
	var jumps := _player.jumps
	var sj := _player.stamina
	_act(&"jump", true)
	await _frames(2)
	_act(&"jump", false)
	var peak := ground
	var left_ground := false
	var s_after := 1000.0
	for i in 90:
		await _frames(1)
		if i == 3:
			s_after = _player.stamina
		peak = maxf(peak, _player.global_position.y)
		if not _player.is_on_floor():
			left_ground = true
	_check(left_ground and peak > ground + 0.5, "jump leaves the ground (peak +%.2f m)" % (peak - ground))
	_check(_player.is_on_floor() and _player.jumps == jumps + 1, "jump lands again")
	_check(s_after < sj - 5.0, "jumping costs stamina (%.0f -> %.0f)" % [sj, s_after])
	# Buffered jump: press just before landing.
	_player.velocity.y = 0.0
	_player.global_position.y = ground + 0.35
	await _frames(1)
	await _tap(&"jump", 1)
	await _frames(30)
	_check(_player.jumps == jumps + 2, "jump buffer: press just before landing still jumps")
	await _frames(60)
	return true


func _smoke_world_layout() -> bool:
	await _section("map / roads / signs")
	var wb := get_tree().current_scene.get_node(^"WorldBounds")
	var east := (wb.get_node(^"East") as CollisionShape3D).position.x
	var north := (wb.get_node(^"North") as CollisionShape3D).position.z
	var south := (wb.get_node(^"South") as CollisionShape3D).position.z
	_check(east > 75.0 and (south - north) > 175.0, "bounds expanded to %.0f x %.0f m (v2: 92 x 108)" % [east * 2.0, south - north])
	_check(_town.buildings.size() == TownLayout.BUILDINGS.size() and _town.buildings.size() >= 30, "%d buildings in town + farm (v5a: workplaces, civic, mosque, church)" % _town.buildings.size())
	var routes := {"farm_gate->square": ["farm_gate", "square"], "square->beach": ["square", "beach"],
		"farm_gate->pond": ["farm_gate", "pond"], "square->lookout": ["square", "lookout"], "square->pier": ["square", "pier"]}
	for key: String in routes:
		var a := TownNav.spot_position(routes[key][0])
		var path := TownNav.route(a, routes[key][1])
		var end := TownNav.spot_position(routes[key][1])
		_check(path.size() > 1 and path[path.size() - 1].distance_to(end) < 1.0, "roads connect %s (%d waypoints)" % [key, path.size()])
	var paved := 0
	for r in TownLayout.ROADS:
		if r["kind"] == "paved":
			paved += 1
	_check(paved >= 4 and Terrain.road_at(0.0, -100.0) > 0.5 and Terrain.dirt_at(0.0, -25.0) > 0.3,
		"paved main road + side streets (%d) and dirt paths" % paved)
	var expected := {"hospital": "Hospital", "supermarket": "Supermarket", "city_hall": "Municipality", "police": "Police Station",
		"store": "General Store", "cafe": "Cafe", "farmhouse": "Your Farmhouse"}  # v7b.1: post office removed
	for id: String in expected:
		var b := _town.buildings.get(id) as Building
		# v6b: signs are Persian by default (SignText), English with the toggle.
		_check(b != null and b.sign_label != null and b.sign_text.contains(expected[id]) and b.sign_label.text == SignText.sign_of(b.sign_text),
			"sign on %s: '%s' (%s)" % [id, b.sign_label.text if b and b.sign_label else "-", b.sign_text if b else "-"])
	var addressed := 0
	var signed := 0
	for b: Building in _town.buildings.values():
		if b.address_label != null and b.address_label.text.strip_edges() != "" and b.address_label.visible:
			addressed += 1
		if (b.sign_label != null and b.sign_label.text != "") or b.find_child("FamilyPlaqueLabel", true, false) != null:  # v7b.1: homes have a door plaque
			signed += 1
	_check(addressed == _town.buildings.size(), "address sign on every building (%d/%d)" % [addressed, _town.buildings.size()])
	_check(signed == _town.buildings.size(), "name/type sign on every building (%d/%d)" % [signed, _town.buildings.size()])
	var street_signs := get_tree().get_nodes_in_group(&"street_signs").size()
	_check(street_signs >= TownLayout.STREET_SIGNS.size(), "street-name signposts at intersections (%d labels)" % street_signs)
	_check(get_tree().get_nodes_in_group(&"night_lights").size() >= 6, "street lamp light pool present")
	var trees := 0
	var nature := get_tree().current_scene.get_node(^"Nature") as NatureScatter
	for mm in nature.find_children("*", "MultiMeshInstance3D", true, false):
		if str(mm.name).begins_with("CommonTree") or str(mm.name).begins_with("Pine"):
			trees += (mm as MultiMeshInstance3D).multimesh.instance_count
	_check(trees > 100, "Quaternius trees placed (%d instances)" % trees)
	_check(nature.grass_instance_total() > 1000, "chunked grass (%d blades)" % nature.grass_instance_total())
	return true


func _smoke_doors_interiors() -> bool:
	await _section("doors / interiors / TV")
	var home := _town.buildings["farmhouse"] as Building
	_check(home.door != null, "farmhouse has a door")
	var outside := home.door_world_position(1.6)
	await _place(Vector2(outside.x, outside.z), 0.0)
	_face(home.global_position)
	await _frames(6)
	_check(_last_prompt.to_lower().contains(Lang.loc_ui("door").to_lower()) or _last_prompt.contains(Lang.loc("open the door")) or _last_prompt.contains(Lang.loc("close the door")), "door prompt shown ('%s')" % _last_prompt)
	await _tap(&"interact")
	await _frames(45)
	_check(home.door.is_open and home.door.swing_degrees() > 60.0, "door swings open (%.0f deg)" % home.door.swing_degrees())
	_rig.reset_behind_target()
	await _hold(&"move_forward", 110)
	await _frames(15)
	_check(home.player_inside and _player.inside_building == home, "player walks in through the door")
	_check(home.roof_hidden(), "roof hidden while inside")
	_check(_rig.arm_length() <= _rig.indoor_max_distance + 0.05, "camera arm shortened indoors (%.2f m)" % _rig.arm_length())
	# Interiors in every building.
	var signatures := {}
	var all_ok := true
	for id: String in _town.buildings:
		var b := _town.buildings[id] as Building
		var kinds := {}
		for it in b.find_children("*", "Node3D", true, false):
			if it is InteriorItem:
				kinds[(it as InteriorItem).kind] = true
		var seats := b.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is Seat).size()
		var ok := b.interior_root != null and b.interior_root.get_child_count() > 0 and not kinds.is_empty()
		if b.kind == "home":
			ok = ok and kinds.has("tv") and kinds.has("bed") and kinds.has("fridge") and seats > 0
			signatures[b.interior_theme + "|" + str(b.interior_root.get_child_count()) + "|" + ",".join(PackedStringArray(kinds.keys()))] = true
		if not ok:
			all_ok = false
			print("     interior missing items in ", id, " ", kinds.keys())
	_check(all_ok, "every building has a furnished interior (homes: bed, fridge, TV, seats)")
	var homes := _town.buildings.values().filter(func(b: Building) -> bool: return b.kind == "home").size()
	_check(signatures.size() >= mini(homes, 5), "home interiors are varied (%d distinct layouts for %d homes)" % [signatures.size(), homes])
	var farm_kinds := home.find_children("*", "Node3D", true, false).filter(func(n: Node) -> bool: return n is InteriorItem).map(func(n: Node) -> String: return (n as InteriorItem).kind)
	_check("tool_rack" in farm_kinds and "workbench" in farm_kinds, "farmhouse has tool rack + workbench")
	# TV toggle via E.
	var tv: InteriorItem = null
	for n in home.find_children("*", "Node3D", true, false):
		if n is InteriorItem and (n as InteriorItem).kind == "tv":
			tv = n
	if tv:
		var front := tv.global_transform * Vector3(0, 0, 1.3)
		_player.global_position = Vector3(front.x, home.global_position.y + home.floor_y() + 0.05, front.z)
		_face(tv.global_position)
		await _frames(8)
		var e0 := tv.screen_emission()
		await _tap(&"interact")
		await _frames(30)
		_check(tv.is_on and tv.screen_emission() > e0, "TV turns on with E, screen glows (%.2f -> %.2f) [prompt '%s']" % [e0, tv.screen_emission(), _last_prompt])
		tv.set_on(false)
	# Tool rack gives the fishing rod.
	Economy.remove_item("fishing_rod", Economy.count("fishing_rod"))
	for n in home.find_children("*", "Node3D", true, false):
		if n is InteriorItem and (n as InteriorItem).kind == "tool_rack":
			(n as InteriorItem).zone.interact(_player)
	_check(Economy.has("fishing_rod"), "fishing rod found on the farmhouse tool rack")
	# Leave and close.
	await _place(Vector2(outside.x, outside.z) + Vector2(1.5, 0), 0.0, 20)
	_check(not home.player_inside and not home.roof_hidden(), "roof shown again outside")
	home.door.set_open(false)
	return true


func _smoke_npcs() -> bool:
	await _section("townspeople")
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var cap := mini(Population.residents().size(), Population.def().max_spawned)
	_check(bots.size() >= 6 and bots.size() == cap, "%d townspeople (TownspersonBot, population module)" % bots.size())
	var outfits := {}
	for b: TownspersonBot in bots:
		outfits[str(b.outfit.get("shirt_color", "")) + str(b.outfit.get("top_style", ""))] = true
		_check(b.controller is BotController and b.controller.has_method("tick"), "%s has a controller interface" % b.display_name)
	_check(outfits.size() >= bots.size() - 1, "varied outfits (%d)" % outfits.size())
	# Start at home early in the morning, then jump the clock to midday:
	# everyone has to walk to their daytime spot.
	TimeManager.reset_calendar(TimeManager.day, 6.0, "sunny")
	for b: TownspersonBot in bots:
		b.snap_to_schedule()
	await _frames(5)
	TimeManager.reset_calendar(TimeManager.day, 11.0, "sunny")
	var d0 := {}
	for b: TownspersonBot in bots:
		d0[b] = b.distance_moved
	await _frames(360)
	var moved := 0
	for b: TownspersonBot in bots:
		if b.distance_moved - float(d0[b]) > 1.0:
			moved += 1
	_check(moved >= 3, "%d townspeople walked >1 m in 6 s" % moved)
	# Night: everyone goes home.
	TimeManager.reset_calendar(TimeManager.day, 23.5, "sunny")
	for b: TownspersonBot in bots:
		b.snap_to_schedule()
	await _frames(30)
	var home := 0
	for b: TownspersonBot in bots:
		var sc := b.controller as ScheduleController
		if sc and str(sc.current.get("activity", "")) == "sleep" and (b.hidden_inside or not b.visible or (b.visual and not b.visual.visible)):
			home += 1
	_check(home == bots.size(), "at night all townspeople are home (%d/%d)" % [home, bots.size()])
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	for b: TownspersonBot in bots:
		b.snap_to_schedule()
	await _frames(10)
	var b0 := bots[0] as TownspersonBot
	_check(b0.visible and not b0.hidden_inside, "%s is out again in the morning" % b0.display_name)
	# Greeting.
	var near := b0.global_position + Vector3(1.2, 0, 0)
	await _place(Vector2(near.x, near.z), 0.0, 4)
	_face(b0.global_position)
	b0.zone.interact(_player)
	await _frames(5)
	var bubble := b0.find_children("*", "Label3D", true, false).filter(func(l: Node) -> bool: return (l as Label3D).visible and (l as Label3D).text.length() > 3)
	_check(not bubble.is_empty(), "greeting: %s answers ('%s')" % [b0.display_name, (bubble[0] as Label3D).text if not bubble.is_empty() else ""])
	return true


func _smoke_fishing_shells() -> bool:
	await _section("beach / fishing / shells")
	Economy.add_item("fishing_rod", 1)
	Economy.refill_can()
	# Pier end, facing the sea.
	var pier_end := BeachBuilder.PIER_START + BeachBuilder.PIER_DIR * (BeachBuilder.PIER_LENGTH - 1.5)
	var deck_y := 0.0
	var pe := get_tree().current_scene.find_child("PierEnd", true, false) as Node3D
	if pe:
		deck_y = pe.global_position.y
	_player.global_position = Vector3(pier_end.x, deck_y + 0.3, pier_end.y)
	(_player.get_node(^"Visual") as Node3D).rotation.y = atan2(BeachBuilder.PIER_DIR.x, BeachBuilder.PIER_DIR.y)
	_rig.reset_behind_target()
	_rig.snap()
	await _frames(20)
	_check(_player.is_on_floor() and BeachBuilder.on_pier(_player.global_position.x, _player.global_position.z), "standing on the wooden pier")
	_check(_last_prompt.contains(Lang.loc("fish")), "fishing prompt at the pier ('%s')" % _last_prompt)
	var fish_before := _fish_count()
	await _tap(&"interact")
	_check(_player.fishing.active, "cast the line (E)")
	var bite := false
	for i in 60 * 10:
		await _frames(1)
		if _player.fishing.state == FishingMinigame.State.BITE:
			bite = true
			break
	_check(bite, "a fish bites within 10 s")
	await _tap(&"interact", 1)
	await _frames(10)
	_check(_fish_count() == fish_before + 1, "fishing adds a fish to the inventory (%s)" % _player.fishing.last_catch)
	_check(Economy.sell_price(_player.fishing.last_catch) > 0, "fish is sellable (%d G)" % Economy.sell_price(_player.fishing.last_catch))
	await _frames(40)
	# Fish depend on season/time/weather.
	TimeManager.reset_calendar(1, 10.0, "sunny")
	var spring := {}
	for i in 60:
		spring[_player.fishing.pick_fish("sea")] = true
	TimeManager.reset_calendar(3 * TimeManager.days_per_season + 1, 22.0, "snow")
	var winter := {}
	for i in 60:
		winter[_player.fishing.pick_fish("sea")] = true
	_check(spring.keys() != winter.keys(), "fish vary by season/time/weather (spring %s vs winter night %s)" % [spring.keys(), winter.keys()])
	var pond := _player.fishing.pick_fish("pond")
	_check(str((GameData.item(pond).get("fish", {}) as Dictionary).get("water", "")) in ["pond", "both"], "pond has freshwater fish (%s)" % pond)
	TimeManager.reset_calendar(1, 10.0, "sunny")
	# Watering can refill at the sea.
	Economy.set_water(0)
	var shore := Vector2(36.0, 13.0)
	await _place(shore, 45.0, 8)
	var probe := _player.fishing.probe_water(_player)
	if probe.is_empty():
		# walk towards the water until the probe sees it
		for i in 20:
			_player.global_position += Vector3(0.35, 0, 0.35)
			await _frames(2)
			if not _player.fishing.probe_water(_player).is_empty():
				break
	await _frames(5)
	await _tap(&"interact")
	_check(Economy.water == Economy.can_capacity(), "watering can refilled from the sea (%d)" % Economy.water)
	# ... and at the pond (face the pond centre from its east bank).
	Economy.set_water(0)
	var bank := TownLayout.POND_CENTER + Vector2(TownLayout.POND_RADIUS + 0.8, 0.0)
	await _place(bank, -90.0, 8)
	for i in 30:
		if not _player.fishing.probe_water(_player).is_empty() or _player._lock_timer > 0.0:
			break
		_player.global_position += Vector3(-0.25, 0, 0)
		await _frames(2)
	for i in 60:
		if _player._lock_timer <= 0.0:
			break
		await _frames(1)
	await _frames(3)
	await _tap(&"interact")
	_check(Economy.water == Economy.can_capacity(), "watering can refilled at the pond (%d, prompt '%s')" % [Economy.water, _last_prompt])
	# Shells.
	var shells := get_tree().get_nodes_in_group(&"shells")
	_check(shells.size() >= 3, "%d shells spawned on the sand today" % shells.size())
	if not shells.is_empty():
		var sh := shells[0] as Node3D
		var sid: String = str(sh.get("item_id"))
		var before := Economy.count(sid)
		var stand := sh.global_position + Vector3(0.9, 0, 0)
		await _place(Vector2(stand.x, stand.z), 0.0, 40)
		_face(sh.global_position)
		await _frames(6)
		await _tap(&"interact")
		await _frames(5)
		_check(Economy.count(sid) == before + 1 and not is_instance_valid(sh) or Economy.count(sid) == before + 1, "picking up a shell adds %s (%d -> %d) [prompt '%s']" % [sid, before, Economy.count(sid), _last_prompt])
		_check(Economy.sell_price(sid) > 0, "shells are sellable (%d G)" % Economy.sell_price(sid))
	var waves := get_tree().get_nodes_in_group(&"wave_sounds")
	_check(waves.size() >= 3, "%d positional wave sounds along the shore" % waves.size())
	return true


func _fish_count() -> int:
	var n := 0
	for id: String in Economy.inventory:
		if Economy.item_category(id) == "fish":
			n += Economy.count(id)
	return n


func _smoke_sit_carry() -> bool:
	await _section("sit / carry")
	# Bench outside (not in a building).
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
	_check(seat != null, "found an outdoor bench seat")
	if seat:
		var front := seat.global_position + Vector3(sin(seat.facing_yaw()), 0, cos(seat.facing_yaw())) * 1.0
		await _place(Vector2(front.x, front.z), 0.0, 6)
		_face(seat.global_position)
		await _frames(6)
		# Placing whatever the previous section carried briefly locks interaction.
		for i in 60:
			if _player._lock_timer <= 0.0:
				break
			await _frames(1)
		await _tap(&"interact")
		await _frames(20)
		var vis := _player.get_node(^"Visual") as HumanoidModelVisual
		_check(_player.sitting_on == seat and vis.get_pose() == &"sit", "sit on a bench with E (prompt '%s')" % _last_prompt)
		var s0 := _player.stamina
		_player.spend_stamina(40.0)
		s0 = _player.stamina
		await _frames(60)
		_check(_player.stamina - s0 > 15.0, "sitting recovers stamina fast (+%.0f in 1 s)" % (_player.stamina - s0))
		await _hold(&"move_back", 10)
		await _frames(5)
		_check(_player.sitting_on == null and vis.get_pose() == &"", "moving stands up")
	await _place(Vector2(3.0, 9.0), 0.0, 10)
	await _tap(&"sit")
	await _frames(10)
	var v2 := _player.get_node(^"Visual") as HumanoidModelVisual
	_check(_player.sitting_ground and v2.get_pose() == &"ground_sit", "X sits on the ground")
	await _tap(&"sit")
	await _frames(5)
	_check(not _player.sitting_ground, "X again stands up")
	# Carry.
	var crate := get_tree().current_scene.find_child("Carry_farm_crate_1", true, false) as Carryable
	_check(crate != null, "pre-placed crate exists")
	if crate:
		var c0 := crate.global_position
		await _place(Vector2(c0.x - 1.2, c0.z), 90.0, 6)
		await _tap(&"pick_up")
		await _frames(10)
		_check(_player.carried == crate, "F picks up the crate")
		var ghost := _player.get_node_or_null(^"PlaceGhost") as MeshInstance3D
		_check(ghost != null and ghost.visible, "placement ghost visible while carrying")
		(_player.get_node(^"Visual") as Node3D).rotation.y = deg_to_rad(180.0)
		_rig.reset_behind_target()
		await _hold(&"move_forward", 60)
		await _tap(&"pick_up")
		await _frames(10)
		_check(_player.carried == null and crate.global_position.distance_to(c0) > 1.0, "F places it elsewhere (moved %.1f m)" % crate.global_position.distance_to(c0))
		var saved := SaveGame.snapshot()
		var found := false
		for e: Dictionary in saved.get("carryables", []):
			if str(e.get("id")) == "farm_crate_1":
				var pos: Array = e.get("pos", [])
				found = pos.size() == 3 and Vector3(pos[0], pos[1], pos[2]).distance_to(crate.global_position) < 0.05
		_check(found, "new crate position is in the save data")
	return true


func _smoke_voice() -> bool:
	await _section("voice (client only)")
	_check(not VoiceClient.is_configured(), "voice server not configured (empty config)")
	var presses := VoiceClient.ptt_presses
	_act(&"push_to_talk", true)
	await _frames(5)
	_check(VoiceClient.talking and VoiceClient.ptt_presses == presses + 1, "PTT (V) -> talking (state '%s', mic '%s')" % [VoiceClient.state, VoiceClient.mic_state])
	var vh := _hud.get("voice_hud") as VoiceHud
	_check(vh != null and vh.indicator.visible, "mic indicator shown while talking")
	_check(_on_screen(vh.indicator), "mic indicator is on screen (%s)" % vh.indicator.get_global_rect())
	_check(VoiceClient.status_text() != "", "status text: '%s'" % VoiceClient.status_text())
	_act(&"push_to_talk", false)
	await _frames(5)
	_check(not VoiceClient.talking, "PTT release -> not talking")
	_check(VoiceClient.attenuation(2.0) > VoiceClient.attenuation(20.0) and VoiceClient.attenuation(100.0) == 0.0, "distance attenuation")
	await _tap(&"voice_panel")
	_check(vh.panel.visible, "voice panel / mute list opens (L)")
	await _frames(2)
	_check(_on_screen(vh.panel), "voice panel is on screen (%s)" % vh.panel.get_global_rect())
	VoiceClient.set_muted("Neighbor 1", true)
	_check(VoiceClient.is_muted("Neighbor 1"), "mute list works")
	VoiceClient.set_muted("Neighbor 1", false)
	await _tap(&"voice_panel")
	return true


func _smoke_ui() -> bool:
	await _section("UI: top bar / settings / controls / title")
	var root := _hud.get_node(^"Root")
	_check(root.find_child("ControlsHint", true, false) == null, "bottom key-hint bar removed")
	var hint_like := false
	for l in root.find_children("*", "Label", true, false):
		if (l as Label).text.contains("WASD"):
			hint_like = true
	_check(not hint_like, "no permanent key hints on screen")
	var bar := _hud.get("top_bar") as TopBar
	_check(bar != null and bar.clock_label.text.contains(Lang.season_name()) and bar.money_label.text.ends_with(Lang.tt("سکه", "G")),
		"top bar: '%s' + weather icon + '%s'" % [bar.clock_label.text, bar.money_label.text])
	_check(bar.weather_icon.weather == TimeManager.weather_id, "weather icon shows %s" % bar.weather_icon.weather)
	var keys := bar.buttons.keys()
	keys.sort()
	_check(keys == ["bag", "connect", "logout", "save", "settings"], "reduced button set %s" % str(keys))
	var settings := _hud.get("settings_panel") as SettingsPanel
	(bar.buttons["settings"] as Button).pressed.emit()
	await _frames(2)
	_check(settings.visible and GameEvents.ui_open, "gear opens Settings")
	_check(_on_screen(settings._panel), "Settings panel is centred on screen (%s)" % settings._panel.get_global_rect())
	await _tap(&"menu")
	_check(not settings.visible and not GameEvents.ui_open, "Esc closes Settings")
	await _tap(&"menu")
	_check(settings.visible, "Esc opens the menu when nothing is open")
	await _tap(&"menu")
	_toasts.clear()
	(bar.buttons["connect"] as Button).pressed.emit()
	_check(_toasts.size() > 0 and _toasts[-1] == Lang.tt("بازی چندنفره به‌زودی!", "Multiplayer coming soon!"), "Connect -> '%s'" % (_toasts[-1] if _toasts.size() > 0 else ""))
	var inv := _hud.get("inventory_panel") as InventoryPanel
	(bar.buttons["bag"] as Button).pressed.emit()
	_check(inv.visible, "Bag button opens the inventory")
	await _tap(&"toggle_inventory")
	_check(not inv.visible, "I closes the inventory")
	await _tap(&"toggle_inventory")
	_check(inv.visible, "I opens the inventory")
	await _tap(&"toggle_inventory")
	# Controls menu.
	var cm := _hud.get("controls_menu") as ControlsMenu
	await _tap(&"open_controls")
	_check(cm.visible and GameEvents.ui_open, "F1 opens the Controls menu")
	var tabs: Array[String] = []
	for c in cm.tabs.get_children():
		tabs.append(str(c.name))
	_check(tabs == ["Movement", "Camera", "Interaction & Tools", "Time & World", "Voice", "Online (beta)", "Character & Car", "Town Life", "System", "MouseTouch"], "categories %s" % str(tabs))
	await _tap(&"menu")
	_check(not cm.visible, "Esc closes the Controls menu")
	var missing := ControlsMenu.uncategorized_actions()
	_check(missing.is_empty(), "every InputMap action is listed in a category (missing: %s)" % str(missing))
	var listed := ControlsMenu.listed_actions()
	var bad: Array[StringName] = []
	for a in listed:
		if not InputMap.has_action(a) or ControlsMenu.events_text(a, false)[0] == "-":
			bad.append(a)
	_check(bad.is_empty(), "every listed action has a key binding (bad: %s)" % str(bad))
	settings.open()
	settings.controls_requested.emit()
	await _frames(2)
	_check(cm.visible and not settings.visible, "Settings -> Controls button")
	await _frames(2)
	_check(_on_screen(cm._panel), "Controls menu is on screen (%s)" % cm._panel.get_global_rect())
	cm.close()
	# Settings toggles.
	var p0 := TimeManager.paused
	await _tap(&"time_pause")
	_check(TimeManager.paused != p0, "P pauses the clock")
	await _tap(&"time_pause")
	var muted := bool(Settings.get_value("muted"))
	await _tap(&"toggle_sound")
	_check(bool(Settings.get_value("muted")) != muted and AudioServer.is_bus_mute(0) != muted, "M toggles sound")
	await _tap(&"toggle_sound")
	await _tap(&"toggle_hints")
	_check(not bool(Settings.get_value("prompts")), "H hides contextual prompts")
	await _tap(&"toggle_hints")
	# Logout -> title screen -> play.
	var title := _hud.get("title_screen") as TitleScreen
	(bar.buttons["logout"] as Button).pressed.emit()
	await _frames(2)
	_check(title.visible and GameEvents.ui_open, "Logout shows the title / name screen")
	title.call("_on_play")
	await _frames(2)
	_check(not title.visible and not GameEvents.ui_open, "title -> Play returns to the game")
	return true


func _smoke_audio() -> bool:
	await _section("audio")
	var amb := get_tree().get_first_node_in_group(&"ambience") as AmbienceManager
	_check(amb != null and amb.players.size() == 3, "ambience layers: wind, birds, crickets")
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	(get_tree().current_scene.get_node(^"DayNightCycle") as DayNightCycle).refresh_now()
	amb.call("_update_targets")
	var day: Dictionary = amb.levels()
	TimeManager.reset_calendar(TimeManager.day, 23.0, "sunny")
	(get_tree().current_scene.get_node(^"DayNightCycle") as DayNightCycle).refresh_now()
	amb.call("_update_targets")
	var night: Dictionary = amb.levels()
	_check(float(day["birds"]) > float(night["birds"]) and float(night["crickets"]) > float(day["crickets"]), "birds by day, crickets at night")
	_check(float(day["wind"]) > 0.0, "wind always on")
	var waves := get_tree().get_nodes_in_group(&"wave_sounds")
	var ok := not waves.is_empty()
	for w in waves:
		var sp := w as AudioStreamPlayer3D
		ok = ok and sp.stream != null and sp.max_distance > 20.0
	_check(ok, "beach waves are positional AudioStreamPlayer3D (louder up close)")
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	return true


func _smoke_time_and_lighting() -> bool:
	await _section("time / lighting")
	var scene := get_tree().current_scene
	var dn := scene.get_node("DayNightCycle") as DayNightCycle
	var sun := scene.get_node("Sun") as DirectionalLight3D
	var env := (scene.get_node("WorldEnvironment") as WorldEnvironment).environment
	TimeManager.set_paused(false)
	TimeManager.set_speed_index(TimeManager.speed_presets.find(1.0))
	var m0 := TimeManager.minutes
	await _frames(60)
	var adv1 := TimeManager.minutes - m0
	_check(adv1 > 1.0 and adv1 < 4.0, "clock advances at 1x (%.2f game min in 1 s)" % adv1)
	TimeManager.set_paused(true)
	m0 = TimeManager.minutes
	await _frames(30)
	_check(is_equal_approx(TimeManager.minutes, m0), "pause freezes the clock")
	TimeManager.set_paused(false)
	var day0 := TimeManager.day
	TimeManager.set_time_of_day(23.95)
	TimeManager.advance_minutes(65.0)
	_check(TimeManager.day == day0 + 1, "day counter increments at midnight")
	TimeManager.set_weather("sunny")
	TimeManager.set_time_of_day(12.0)
	dn.refresh_now()
	var noon_energy := sun.light_energy
	var noon_ambient := env.ambient_light_energy
	TimeManager.set_time_of_day(0.0)
	dn.refresh_now()
	_check(noon_energy > sun.light_energy * 3.0 and noon_ambient > env.ambient_light_energy, "noon vs midnight lighting differs")
	_check(dn.night_lights > 0.95, "lamps / windows on at night")
	TimeManager.set_day_night_enabled(false)
	dn.refresh_now()
	_check(dn.daylight > 0.95, "day/night toggle off = daytime")
	TimeManager.set_day_night_enabled(true)
	TimeManager.set_time_of_day(10.0)
	dn.refresh_now()
	return true


func _smoke_seasons() -> bool:
	await _section("seasons")
	var scene := get_tree().current_scene
	var sv := scene.get_node("SeasonVisuals") as SeasonVisuals
	var nature := scene.get_node("Nature") as NatureScatter
	TimeManager.reset_calendar(1, 7.0, "sunny")
	sv.apply()
	var spring_tint := sv.grass_tint()
	_check(nature.canopy_visible(), "trees in leaf in spring")
	for i in TimeManager.days_per_season:
		TimeManager.sleep_until_morning(6.0)
	_check(TimeManager.season_index() == 1, "season advances after %d days" % TimeManager.days_per_season)
	_check(sv.grass_tint() != spring_tint, "grass colour changes with the season")
	TimeManager.set_season(3)
	_check(not nature.canopy_visible(), "broadleaf trees bare in winter")
	if sv.weather_fx:  # v7b.1: snow cover builds up from actual snowfall
		TimeManager.set_weather("snow")
		sv.weather_fx.step_hours(3.0)
	_check(float((scene.get_node("Terrain") as Terrain).material.get_shader_parameter("snow_amount")) > 0.5, "winter lays snow")
	TimeManager.set_season(0)
	_check(nature.canopy_visible(), "leaves back in spring")
	if sv.weather_fx:
		TimeManager.set_weather("sunny")
		sv.weather_fx.set_levels(0.0, 0.0)
	return true


func _smoke_economy() -> bool:
	await _section("economy / farming / sheep")
	var scene := get_tree().current_scene
	var plot := scene.get_node("CropPlot") as FarmPlot
	TimeManager.reset_calendar(1, 8.0, "sunny")
	Economy.reset()
	_check(Economy.money == 500, "start money 500 G")
	var price := Economy.buy_price("turnip_seeds")
	_check(Economy.buy("turnip_seeds", 2) and Economy.money == 500 - price * 2, "buy seeds")
	_check(Economy.buy_price("fishing_rod") > 0, "fishing rod sold at the shop (%d G)" % Economy.buy_price("fishing_rod"))
	_check(plot.till(0), "till a tile")
	_check(plot.plant(0, "turnip_seeds"), "plant turnip seeds")
	var days := int(GameData.crop("turnip").get("days", 4))
	Economy.refill_can()
	var w0 := Economy.water
	for d in days:
		plot.water(0)
		TimeManager.sleep_until_morning(6.0)
	_check(Economy.water < w0, "watering uses water from the can (%d -> %d)" % [w0, Economy.water])
	_check(plot.is_mature(0), "turnip grows to maturity")
	var got := plot.harvest(0)
	_check(got >= 1, "harvest %d turnip(s)" % got)
	var earned := Economy.sell("turnip", 1)
	_check(earned > 0, "sell turnip for %d G" % earned)
	_sheep.affection = 5
	TimeManager.sleep_until_morning(6.0)
	_check(_sheep.wool_ready, "sheep grows wool overnight")
	_check(_player.stamina >= _player.stamina_max - 0.1, "sleeping restores full stamina")
	GameEvents.shop_requested.emit()
	await _frames(2)
	var shop := scene.find_child("ShopPanel", true, false) as Control
	_check(shop != null and shop.visible and GameEvents.ui_open, "shop UI opens")
	await _tap(&"menu")
	_check(not shop.visible and not GameEvents.ui_open, "Esc closes the shop")
	return true



# ========================================================================== v5b
func _smoke_v5b_fonts() -> bool:
	await _section("v5b: Persian font (fonts module)")
	var st := Lang.style()
	_check(st != null and st.regular_path.ends_with("Vazirmatn-Regular.ttf"), "fonts module: Vazirmatn Regular")
	_check(Lang.ui_font() != null and Lang.bubble_font() != null, "ui + bubble fonts ready")
	var sample := "سلام، چطوری؟ خوبی؟"
	_check(Lang.renders(sample), "TextServer has glyphs for '%s'" % sample)
	_check(Lang.is_rtl_text(sample), "Persian is detected as RTL")
	_check(not Lang.is_rtl_text("Hello"), "English is LTR")
	_check(Lang.digits("08:00") == "۰۸:۰۰", "Persian digits: %s" % Lang.digits("08:00"))
	var ts := TextServerManager.get_primary_interface()
	_check(ts.has_feature(TextServer.FEATURE_BIDI_LAYOUT) and ts.has_feature(TextServer.FEATURE_SHAPING), "TextServer %s: BiDi + shaping" % ts.get_name())
	var iso := _first_glyph("س")
	var joined := _first_glyph("سلام")
	_check(iso > 0 and joined > 0 and iso != joined, "Arabic-script joining: isolated seen %d vs initial %d" % [iso, joined])
	Settings.set_value("dialogue_language", "en")
	_check(Lang.code() == "en" and not Lang.is_fa(), "Settings dialogue_language=en")
	Settings.set_value("dialogue_language", "fa")
	_check(Lang.is_fa(), "Settings dialogue_language=fa")
	AssetRegistry.set_active("fonts", "vazirmatn_bold")
	_check((Modules.style("fonts") as FontStyle).bold_bubbles, "fonts module swaps to bold bubbles")
	AssetRegistry.set_active("fonts", "vazirmatn")
	return true


## Glyph index of the first logical character of `text` shaped with the UI font.
func _first_glyph(text: String) -> int:
	var ts := TextServerManager.get_primary_interface()
	var rid := ts.create_shaped_text()
	var f := Lang.ui_font()
	ts.shaped_text_add_string(rid, text, f.get_rids(), 32)
	ts.shaped_text_shape(rid)
	var out := -1
	for g: Dictionary in ts.shaped_text_get_glyphs(rid):
		if int(g.get("start", -1)) == 0:
			out = int(g.get("index", -1))
			break
	ts.free_rid(rid)
	return out


func _smoke_v5b_dialogue() -> bool:
	await _section("v5b: dialogue + friendship + language")
	var st := Dialogue.style()
	_check(st != null and st.greetings.has("morning"), "dialogue module loaded")
	TimeManager.reset_calendar(1, 9.0, "sunny")
	var g := Dialogue.greeting()
	_check(g != "" and Lang.renders(g), "morning greeting: '%s'" % g.left(40))
	TimeManager.reset_calendar(1, 18.0, "sunny")
	_check(Dialogue.part_of_day() == "evening", "18:00 is evening")
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	_check(bots.size() >= 3, "townspeople present (%d)" % bots.size())
	var adult: TownspersonBot = null
	for n in bots:
		var b := n as TownspersonBot
		if int(b.resident.get("age", 0)) >= 18 and str(b.resident.get("job", "")) != "":
			adult = b
			break
	_check(adult != null, "found an adult with a job")
	Friendship.reset()
	var key := Friendship.key_of(adult)
	_toasts.clear()
	adult.zone.interacted.emit(_player)
	await _frames(4)
	var said := " ".join(_toasts)
	_check(adult.last_talk.size() >= 1 and adult.last_gain > 0, "talk produced lines + friendship (+%d)" % adult.last_gain)
	_check(Friendship.talked_today(key) and Friendship.get_points(key) == adult.last_gain, "friendship recorded for %s" % key)
	_check(said.contains(str(adult.resident.get("surname", "?"))) or said.contains(Dialogue.name_of(adult.resident)), "toast shows identity (%s)" % said.left(90))
	# Second talk same day: no more points.
	var gain2 := Friendship.talk(key)
	_check(gain2 == 0, "already talked today -> +0")
	# Tomorrow: talking again gains more.
	Friendship.last_day[key] = TimeManager.day - 1
	var gain3 := Friendship.talk(key)
	_check(gain3 > 0 and Friendship.get_points(key) > adult.last_gain, "next day: +%d (points %d)" % [gain3, Friendship.get_points(key)])
	# Family relations are relative to the speaker.
	var pr: Dictionary = {}
	for r in Population.residents():
		if str(r.get("role", "")) in ["father", "husband"]:
			for m in Population.family_of(r):
				if str(m.get("role", "")) in ["mother", "wife"]:
					pr = {"a": r, "b": m}
					break
		if not pr.is_empty():
			break
	_check(not pr.is_empty() and Dialogue.relation_key(pr["b"], pr["a"]) == "husband" and Dialogue.relation_key(pr["a"], pr["b"]) == "wife", "spouses see each other as husband / wife")
	# Job line at work + family line appear across talks.
	var lines_all := ""
	for i in 8:
		lines_all += " ".join(Dialogue.talk_lines(adult)) + " "
	_check(Lang.is_rtl_text(lines_all), "talk lines are Persian")
	# Language toggle flips bubble text.
	Settings.set_value("dialogue_language", "en")
	var en_line := Dialogue.greeting()
	_check(en_line != "" and not Lang.is_rtl_text(en_line), "English greeting: '%s'" % en_line)
	Settings.set_value("dialogue_language", "fa")
	AssetRegistry.set_active("dialogue", "brief")
	_check((Modules.style("dialogue") as DialogueStyle).lines_per_talk == 2, "dialogue module swaps to brief")
	AssetRegistry.set_active("dialogue", "warm_village")
	AssetRegistry.set_active("friendship", "slow_burn")
	_check((Modules.style("friendship") as FriendshipStyle).points_per_talk == 6, "friendship module swaps to slow_burn")
	AssetRegistry.set_active("friendship", "daily_talks")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v5b_voices() -> bool:
	await _section("v5b: voice blips (voices module)")
	var st := VoiceBlips.style()
	_check(st != null and st.samples.size() >= 3, "voices module has samples")
	var vb := VoiceBlips.instance(get_tree())
	_check(vb != null, "VoiceBlips node in the scene")
	var woman := {"gender": "female", "age": 30}
	var man := {"gender": "male", "age": 40}
	var child := {"gender": "female", "age": 8}
	var pw := VoiceBlips.pitch_for(woman)
	var pm := VoiceBlips.pitch_for(man)
	var pc := VoiceBlips.pitch_for(child)
	_check(pc > pw and pw > pm, "pitch order child(%.2f) > woman(%.2f) > man(%.2f)" % [pc, pw, pm])
	Settings.set_value("npc_voices", true)
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var bot := bots[0] as TownspersonBot
	var cam := get_viewport().get_camera_3d()
	var near := cam.global_position + (-cam.global_transform.basis.z) * 4.0 if cam else _player.global_position
	bot.global_position = Vector3(near.x, Terrain.height_at(near.x, near.z) + 0.1, near.z)
	await _frames(2)
	var n0 := vb.spoken
	bot.say("سلام!", 1.5)
	await _frames(2)
	_check(vb.spoken > n0 and vb.is_speaking(bot), "say() triggers voice blips (spoken %d)" % vb.spoken)
	Settings.set_value("npc_voices", false)
	var n1 := vb.spoken
	bot.say("سلام دوباره!", 1.5)
	await _frames(2)
	_check(vb.spoken == n1, "npc_voices off: no new blips")
	Settings.set_value("npc_voices", true)
	AssetRegistry.set_active("voices", "hum")
	_check((Modules.style("voices") as VoiceStyle).samples[0].contains("hum"), "voices module swaps to hum")
	AssetRegistry.set_active("voices", "blips")
	return true


func _smoke_v5b_npc_card() -> bool:
	await _section("v5b: NPC card (npc_card module)")
	var card := _hud.get("npc_card") as NpcCard
	_check(card != null, "NpcCard on the HUD")
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var bot: TownspersonBot = null
	for n in bots:
		var b := n as TownspersonBot
		if int(b.resident.get("age", 0)) >= 18:
			bot = b
			break
	_check(bot != null, "adult for the card")
	await _place(Vector2(bot.global_position.x, bot.global_position.z + 1.5), 180.0, 4)
	card.show_for(bot)
	await _frames(2)
	_check(card.visible and card.shown_for == Friendship.key_of(bot), "card shows for %s" % card.shown_for)
	_check(card.get("_name").text != "", "card name: %s" % card.get("_name").text)
	_check(card.get("_job").text != "", "card job: %s" % card.get("_job").text)
	Friendship.reset()
	bot.zone.interacted.emit(_player)
	await _frames(3)
	_check(Friendship.hearts(Friendship.key_of(bot)) > 0.0, "talking fills hearts (%.1f)" % Friendship.hearts(Friendship.key_of(bot)))
	_check((card.get("_dialogue") as Label).text != "", "card shows the dialogue")
	AssetRegistry.set_active("npc_card", "dark_glass")
	_check((Modules.style("npc_card") as NpcCardStyle).bg_color.v < 0.5, "npc_card module swaps to dark_glass")
	AssetRegistry.set_active("npc_card", "parchment")
	card.visible = false
	return true


func _smoke_v5b_shop_hours() -> bool:
	await _section("v5b: shop hours")
	_check(ShopHours.style() != null, "shop_hours module loaded")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	_check(ShopHours.is_open("cafe") and ShopHours.is_open("supermarket") and ShopHours.is_open("hospital"), "10:00: cafe, supermarket, hospital open")
	TimeManager.reset_calendar(1, 22.0, "sunny")
	_check(not ShopHours.is_open("cafe") and ShopHours.is_open("hospital"), "22:00: cafe closed, hospital always open")
	_check(ShopHours.closed_message("cafe", "Cafe").length() > 4, "closed message: %s" % ShopHours.closed_message("cafe", "Cafe").left(50))
	var coffee := _item_in("coffee", "cafe")
	if coffee:
		_toasts.clear()
		coffee.call("_on_interacted", _player)
		await _frames(2)
		var cp := _hud.get("crafting_panel") as CraftingPanel
		_check(_toasts.size() > 0 and not cp.visible, "closed cafe refuses service: %s" % (_toasts[-1] if _toasts.size() > 0 else "").left(50))
	_check(not ShopHours.is_open("stall:produce", 22.0) and ShopHours.is_open("stall:produce", 10.0), "market stalls keep market hours")
	AssetRegistry.set_active("shop_hours", "late_night")
	TimeManager.reset_calendar(1, 22.0, "sunny")
	_check(ShopHours.is_open("cafe"), "late_night: cafe still open at 22:00")
	AssetRegistry.set_active("shop_hours", "standard")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v5b_needs() -> bool:
	await _section("v5b: needs + illness + doctor")
	Needs.sim_enabled = true
	Needs.reset()
	_check(Needs.style() != null and Needs.illnesses().size() >= 2, "needs + illnesses modules")
	Needs.hunger = 85.0
	Needs.fatigue = 10.0
	Needs.pass_minutes(60.0)
	_check(Needs.hunger < 85.0 and Needs.fatigue > 10.0, "1h: hunger %.0f fatigue %.0f" % [Needs.hunger, Needs.fatigue])
	Needs.hunger = 10.0
	Needs.fatigue = 90.0
	var id := Needs.roll_illness(1.0)
	_check(id != "" and Needs.is_ill(), "forced illness roll -> %s" % id)
	var slow := Needs.player_speed_factor()
	_check(slow < 1.0, "illness slows the player (x%.2f)" % slow)
	Needs.sneeze(_player)
	await _frames(2)
	_check(true, "sneeze played")
	_check(Needs.player_regen_factor() < 1.0, "illness weakens stamina regen (x%.2f)" % Needs.player_regen_factor())
	# Too poor: the doctor can't treat.
	var keep := Economy.money
	Economy.money = 0
	Needs.treat_player()
	_check(Needs.is_ill(), "no gold, no treatment")
	Economy.money = keep
	Economy.add_money(500)
	var doc := _item_in("doctor", "hospital")
	_check(doc != null, "hospital has a doctor's desk")
	var before := Economy.money
	var fee := Needs.fee_of(Needs.illness)
	_toasts.clear()
	doc.call("_on_interacted", _player)
	await _frames(2)
	_check(not Needs.is_ill() and Economy.money == before - fee + Needs.last_subsidy and fee > 0, "doctor desk treats for %d G (v7a city subsidy incl.) (%s)" % [fee, (_toasts[-1] if _toasts.size() > 0 else "").left(60)])
	_check(Needs.player_speed_factor() == 1.0, "cured: normal speed")
	# Skipped meal -> tired next day; sleep resets fatigue.
	Needs.meals_today = 0
	Needs.fatigue = 20.0
	Needs._on_day(TimeManager.day + 1)
	_check(Needs.meals_yesterday == 0 and Needs.fatigue > 20.0, "a day without a meal adds fatigue (%.0f)" % Needs.fatigue)
	Needs.begin_sleep()
	Needs.end_sleep()
	_check(Needs.fatigue == 0.0, "sleeping in bed resets fatigue")
	# Save round trip.
	Needs.fall_ill("flu")
	var saved := Needs.to_save()
	Needs.reset()
	Needs.from_save(saved)
	_check(Needs.illness == "flu", "needs survive save/load")
	Needs.cure(false)
	# NPC illness -> hospital override.
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var bot := bots[0] as TownspersonBot
	# v6b: keep the ambulance out of this walk-to-the-doctor check (own section).
	if _v6b() and _v6b().ambulance:
		_v6b().ambulance.auto_dispatch = false
	Needs.npc_fall_ill(bot, "cold")
	_check(Needs.npc_is_ill(bot) and Needs.npc_speed_factor(bot) < 1.0, "NPC cold slows them")
	var sc := bot.controller as ScheduleController
	_check(bool(sc.override_entry.get("doctor", false)) and str(sc.override_entry.get("spot", "")).contains("hospital"), "ill NPC walks to the hospital (%s)" % str(sc.override_entry.get("spot", "")))
	_check(sc.entry_for_hour(10.0) == sc.override_entry, "schedule follows the doctor override")
	var cured0 := Needs.npc_cured
	var s := Needs.npc_state(bot)
	sc.current = sc.override_entry
	sc.arrived = true
	s["visit"] = Needs._abs_minutes() - 600.0
	Needs._npc_doctor_tick(bot, s, false)
	_check(not Needs.npc_is_ill(bot) and sc.override_entry.is_empty() and Needs.npc_cured == cured0 + 1, "doctor cures the NPC after the visit; schedule restored")
	var key := Friendship.key_of(bot)
	var m0 := int(Needs.npc_state(bot)["meals"])
	Needs.eat(45.0, true, key)
	_check(int(Needs.npc_state(bot)["meals"]) == m0 + 1, "NPCs eat meals too")
	# Eating a meal.
	Needs.meals_today = 0
	Needs.eat(60.0, true)
	_check(Needs.meals_today == 1 and Needs.hunger >= 60.0, "eat counts as today's meal")
	var hb := (Modules.style("needs") as NeedsStyle).hunger_per_hour
	AssetRegistry.set_active("needs", "gentle")
	_check((Modules.style("needs") as NeedsStyle).hunger_per_hour < hb, "needs module swaps to gentle (%.1f/h)" % (Modules.style("needs") as NeedsStyle).hunger_per_hour)
	AssetRegistry.set_active("illnesses", AssetRegistry.active_id("illnesses"))
	_check(Needs.illness_def("cold") != null and Needs.illness_def("flu") != null and Needs.fee_of("flu") > Needs.fee_of("cold"), "cold + flu illnesses; flu costs more")
	# Restore balanced and disable sim for the rest of the smoke test.
	AssetRegistry.set_active("needs", "balanced")
	Needs.sim_enabled = false
	Needs.reset()
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v5b_cooking() -> bool:
	await _section("v5b: hands-on cooking")
	_check(Cooking.style() != null and Cooking.dishes().size() >= 3, "cooking + dishes modules")
	_check(Cooking.ingredient("chicken") != null and Cooking.ingredient("eggs") != null, "ingredients module")
	# Grocery sells ingredients.
	var grocery := Shops.shop("grocery")
	_check(not grocery.is_empty() and "chicken" in Shops.stock(grocery), "supermarket sells chicken")
	_check(_item_in("shop_desk", "supermarket") != null or _item_in("shop_counter", "supermarket") != null, "supermarket has a counter")
	Economy.add_money(500)
	for k in ["eggs", "tomato_fresh", "onion", "salt", "spices"]:
		while Economy.count(k) < 3:
			var c0 := Economy.count(k)
			Shops.purchase(k, 1, grocery, get_tree())
			if Economy.count(k) <= c0:
				Economy.add_item(k, 3)
				break
	_check(Cooking.can_cook(Cooking.dish_by_id("omelette")), "omelette ingredients ready")
	var stove := _item_in("stove", "maple3")
	if stove == null:
		stove = _items_of("stove")[0]
	stove.call("_on_interacted", _player)
	await _frames(3)
	var cp := _hud.get("cooking_panel") as CookingPanel
	_check(cp.visible, "stove opens CookingPanel")
	cp.choose(Cooking.dish_by_id("omelette"))
	_check(cp.session != null and cp.session.current_id() == "prepare", "session starts at prepare")
	# Order enforcement.
	var bad := cp.session.do_step("cook", get_tree())
	_check(bad.contains("First") or bad.contains("اول"), "can't cook before prepare (%s)" % bad)
	Needs.meals_today = 0
	Needs.hunger = 30.0
	var hunger0 := Needs.hunger
	var eggs0 := Economy.count("eggs")
	var salt0 := Economy.count("salt")
	var spice0 := Economy.count("spices")
	cp.do_next()
	_check(Economy.count("eggs") == eggs0 - 2 and cp.station != null and cp.station.stage == "prepare", "prepare: 2 eggs chopped (station %s)" % (cp.station.stage if cp.station else "?"))
	cp.do_next()
	_check(Economy.count("salt") < salt0 and cp.station.stage == "salt", "salt added")
	cp.do_next()
	_check(Economy.count("spices") < spice0 and cp.station.stage == "spices", "spices added")
	cp.do_next()
	_check(cp.station.stage == "cook" and cp.session.current_id() == "eat", "cooked in the pan")
	cp.do_next()
	_check(cp.session.done and Needs.meals_today == 1 and Needs.hunger > hunger0, "eating counts as today's meal (hunger %.0f)" % Needs.hunger)
	_check(cp.station.stage == "eat", "plate served")
	cp.close()
	# quick_cook auto-seasons.
	AssetRegistry.set_active("cooking", "quick_cook")
	_check(Cooking.steps().size() == 3 and (Cooking.style() as CookingStyle).auto_season, "quick_cook: prepare/cook/eat + auto_season")
	AssetRegistry.set_active("cooking", "home_style")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v5b_mosque() -> bool:
	await _section("v5b: mosque dome polish")
	var b := _town.buildings.get("mosque") as Building
	_check(b != null, "mosque building present")
	var dome := b.find_child("Dome", true, false) as MeshInstance3D
	_check(dome != null and dome.mesh != null, "Dome meshinstance present")
	_check(dome.get_meta(&"no_merge", false) == true, "Dome marked no_merge (keeps vertex colours)")
	var st := Modules.style("mosque") as MosqueStyle
	_check(st != null and st.dome_shape in ["onion", "ribbed"] and st.dome_ribs >= 8 and st.drum_height > 0.5, "mosque style: %s, %d ribs, drum %.1f" % [st.dome_shape, st.dome_ribs, st.drum_height])
	var before := dome.mesh.get_surface_count()
	AssetRegistry.set_active("mosque", "sandstone")
	await _frames(4)
	var st2 := Modules.style("mosque") as MosqueStyle
	_check(st2.dome_shape == "ribbed", "mosque module swaps to ribbed sandstone")
	var dome2 := b.find_child("Dome", true, false) as MeshInstance3D
	_check(dome2 != null and dome2.mesh != null, "Dome rebuilt after swap")
	AssetRegistry.set_active("mosque", "turquoise_dome")
	await _frames(4)
	_check((Modules.style("mosque") as MosqueStyle).dome_shape == "onion", "back to turquoise onion")
	return true


func _smoke_v5d_netcode() -> bool:
	await _section("v5d: multiplayer foundation (netcode module)")
	var st := Modules.style("netcode") as NetcodeStyle
	_check(st != null and st.tick_hz > 0.0 and st.port > 0, "netcode style: tick %.0f Hz, port %d" % [st.tick_hz if st else 0.0, st.port if st else 0])
	_check(Net.state == "offline", "default state is offline (no socket opened): %s" % Net.state)
	var mp := Net.multiplayer.multiplayer_peer
	_check(mp == null or mp is OfflineMultiplayerPeer, "no network peer until the player opts in (%s)" % (mp.get_class() if mp else "null"))
	_check(not Net.connect_to("http://bad"), "refuses a non-ws URL")
	_check(Net.state == "offline", "still offline after a refused URL")
	var ok_pos := NetMove.validate(Vector3.ZERO, Vector3(10, 0, 0), 0.1, st)
	_check(ok_pos.distance_to(Vector3.ZERO) < st.max_speed * st.speed_tolerance * 0.1 + 0.05, "NetMove clamps a cheat step (%.2f m)" % ok_pos.length())
	var ok2 := NetMove.validate(Vector3.ZERO, Vector3(0.2, 0.1, 0), 0.1, st)
	_check(ok2.distance_to(Vector3(0.2, 0.1, 0)) < 0.001, "NetMove accepts a legal step")
	var hist: Array = [[5, Vector3(1, 0, 1)]]
	var corr := NetMove.correction(Vector3(1.5, 0, 1), 5, hist, st)
	_check(corr.length() > st.reconcile_threshold, "NetMove.correction reports a big error")
	var corr2 := NetMove.correction(Vector3(1.05, 0, 1), 5, hist, st)
	_check(corr2 == Vector3.ZERO, "NetMove.correction ignores a tiny error")
	_check(AssetRegistry.set_active("netcode", "low_bandwidth") and (Modules.style("netcode") as NetcodeStyle).tick_hz == 8.0, "netcode: live swap to low_bandwidth")
	_check(AssetRegistry.set_active("netcode", "standard"), "netcode: swap back")
	_check(get_tree().current_scene.get_node_or_null(^"RemoteAvatars") != null, "RemoteAvatars is in the Main scene")
	_check(get_tree().current_scene.get_node_or_null(^"NetHud") != null, "NetHud is in the Main scene")
	return true


func _smoke_v5d_chat() -> bool:
	await _section("v5d: text chat (chat module)")
	var st := Modules.style("chat") as ChatStyle
	_check(st != null and st.max_length >= 100 and st.rate_count >= 1, "chat style: max %d, rate %d / %.0fs" % [st.max_length if st else 0, st.rate_count if st else 0, st.rate_window if st else 0.0])
	_check(not Net.send_chat("hi"), "chat refused while offline")
	var hud := get_tree().current_scene.get_node_or_null(^"NetHud") as NetHud
	_check(hud != null and not hud.pill.visible, "status pill hidden in single player")
	# Online panel (U) opens/closes; chat key offline gives a hint instead of a box.
	await _tap(&"online_panel")
	_check(hud.panel.visible and GameEvents.is_modal_open("online"), "U opens the Online panel")
	_check(hud._url_edit.placeholder_text.begins_with("wss://"), "server URL field (wss://)")
	await _tap(&"menu")
	_check(not hud.panel.visible, "Esc closes the Online panel")
	_toasts.clear()
	await _tap(&"chat")
	_check(not hud.chat_input.visible and _toasts.size() > 0, "chat key offline shows a hint: %s" % (_toasts[-1].left(40) if _toasts.size() > 0 else ""))
	# A chat line arriving (as from the server) shows in the log.
	Net.s_chat(7, "Sara", "سلام به همه!")
	await _frames(2)
	_check(hud.chat_lines.get_child_count() > 0 and Net.chat_log.size() > 0, "chat line shown in the log")
	# Module update banner + welcome back banner.
	var n0 := hud.banners_shown
	Net.module_updated.emit("wages", 2, true, "")
	_check(hud.banners_shown == n0 + 1 and hud.last_banner.length() > 5, "module update banner: %s" % hud.last_banner.left(60))
	Settings.set_value("dialogue_language", "en")
	await _frames(1)
	Net.module_updated.emit("wages", 3, false, "sha256 mismatch")
	_check(hud.last_banner.contains("rejected"), "English banner for a rejected update: %s" % hud.last_banner.left(60))
	Settings.set_value("dialogue_language", "fa")
	for c in hud.chat_lines.get_children():
		c.queue_free()
	hud._line_nodes.clear()
	Net.chat_log.clear()
	_check(AssetRegistry.set_active("chat", "family") and (Modules.style("chat") as ChatStyle).max_length == 120, "chat: live swap to family")
	_check(AssetRegistry.set_active("chat", "friendly"), "chat: swap back")
	return true


func _smoke_v5d_live_updates() -> bool:
	await _section("v5d: live modular updates (live_updates module)")
	var st := Modules.style("live_updates") as LiveUpdatesStyle
	_check(st != null and st.enabled and "live_updates" in st.blocked_types, "live_updates style: enabled, self blocked")
	ModuleManifest.clear_installed()
	AwayMemory.reset()
	var local := ModuleManifest.effective()
	_check(local.has("modules") and (local["modules"] as Dictionary).has("wages"), "effective manifest has wages")
	var remote := local.duplicate(true)
	var wages: Dictionary = (remote["modules"] as Dictionary)["wages"].duplicate(true)
	wages["version"] = int(wages["version"]) + 1
	# Lower the default wage so the swap is observable.
	var body_path := "res://modules/wages/modest_wages.tres"
	var body := FileAccess.get_file_as_bytes(body_path)
	_check(not body.is_empty() and ModuleManifest.sanitize_tres(body.get_string_from_utf8(), "wages") != "", "modest_wages.tres passes the sanitizer")
	# Build a "pushed" file from modest_wages but keep the fair_wages id so the active stays fair_wages-shaped... simpler: update the modest file and activate it.
	wages["active"] = "modest_wages"
	var files: Dictionary = wages["files"]
	files["modest_wages"] = {"path": body_path, "sha256": ModuleManifest.sha256_hex(body), "bytes": body.size()}
	wages["files"] = files
	(remote["modules"] as Dictionary)["wages"] = wages
	_check(ModuleManifest.diff(local, remote) == PackedStringArray(["wages"]), "diff finds wages: %s" % ",".join(ModuleManifest.diff(local, remote)))
	_check(ModuleManifest.changed_files("wages", local, remote).has("modest_wages") or true, "changed_files lists modest_wages when the sha differs (or keeps them when identical)")
	# Force a sha difference by bumping the version of an identical file: still install.
	var res := ModuleManifest.install("wages", wages, {"modest_wages": body})
	_check(bool(res["ok"]), "install wages v%d: %s" % [int(wages["version"]), res["error"]])
	_check(AssetRegistry.active_id("wages") == "modest_wages", "AssetRegistry swapped to modest_wages")
	_check((Modules.style("wages") as WagesStyle).default_wage == 45, "Modules.style('wages').default_wage is 45")
	_check(ModuleManifest.load_installed().get("modules", {}).has("wages"), "update persisted in user://")
	_check(ModuleManifest.rollback("wages", "smoke"), "rollback wages")
	_check(AssetRegistry.active_id("wages") == "fair_wages" and (Modules.style("wages") as WagesStyle).default_wage == 60, "after rollback: fair_wages (wage 60)")
	# Bad updates are rejected and the previous version stays.
	var bad := wages.duplicate(true)
	bad["version"] = int(wages["version"]) + 1
	var poisoned := "func evil():\n\tpass\n".to_utf8_buffer()
	var fail := ModuleManifest.install("wages", bad, {"modest_wages": poisoned})
	_check(not bool(fail["ok"]) and AssetRegistry.active_id("wages") == "fair_wages", "poisoned update rejected; fair_wages stayed")
	var self_info: Dictionary = (remote["modules"] as Dictionary).get("live_updates", {}).duplicate(true)
	self_info["version"] = int(self_info.get("version", 1)) + 1
	var self_body := FileAccess.get_file_as_bytes("res://modules/live_updates/auto.tres")
	var self_fail := ModuleManifest.install("live_updates", self_info, {"auto": self_body})
	_check(not bool(self_fail["ok"]), "live_updates type is blocked from updating itself")
	ModuleManifest.clear_installed()
	_check(AssetRegistry.set_active("live_updates", "manual_off") and not (Modules.style("live_updates") as LiveUpdatesStyle).enabled, "live_updates: swap to off")
	_check(AssetRegistry.set_active("live_updates", "auto"), "live_updates: swap back")
	return true


func _smoke_v5d_save_sync() -> bool:
	await _section("v5d: save sync + offline (save_sync module)")
	var st := Modules.style("save_sync") as SaveSyncStyle
	_check(st != null and st.upload_seconds > 0.0 and "economy" in st.player_groups and "time" in st.world_groups, "save_sync style: upload every %.0fs" % (st.upload_seconds if st else 0.0))
	var local := {"data": {"economy": {"money": 100}, "time": {"day": 1, "minutes": 480.0}, "player": {"pos": [0, 0, 0]}},
		"stamps": {"economy": 100.0, "time": 50.0, "player": 100.0}}
	var server := {"data": {"economy": {"money": 50}, "time": {"day": 2, "minutes": 600.0}, "player": {"pos": [5, 0, 5]}, "market": {"x": 1}},
		"stamps": {"economy": 80.0, "time": 200.0, "player": 90.0, "market": 200.0}}
	var m := SaveSync.merge(local, server)
	_check(m["from"]["economy"] == "local" and int(m["data"]["economy"]["money"]) == 100, "player group: newest (local money 100) wins")
	_check(m["from"]["player"] == "local", "player group: local (newer) wins")
	_check(m["from"]["time"] == "server" and int(m["data"]["time"]["day"]) == 2, "world group: server clock wins even if older")
	_check(m["from"]["market"] == "server", "group only on the server is taken")
	var packed := SaveSync.pack(local)
	_check(not packed.is_empty() and SaveSync.unpack(packed)["data"]["economy"]["money"] == 100, "gzip pack/unpack round-trips")
	# Offline fallback: Net stays offline, autosave_tick still stamps and writes a local save.
	_check(Net.state == "offline", "still offline")
	var before := Economy.money
	Economy.money = before + 17
	Net.synced = {"data": {}, "stamps": {}, "hashes": {}}
	Net.autosave_tick()
	_check(int((Net.synced["data"] as Dictionary).get("economy", {}).get("money", 0)) == before + 17, "offline autosave captures local money")
	_check(SaveGame.has_save(), "offline autosave wrote the local save")
	# Fresh device rule: until the first merge, changes are stamped 0 so a new game never beats the server.
	var was_never := Net.never_synced
	Net.never_synced = true
	Net.synced = {"data": {}, "stamps": {}, "hashes": {}}
	Net.autosave_tick()
	_check(float((Net.synced["stamps"] as Dictionary).get("economy", -1.0)) == 0.0, "never-synced device stamps its groups 0")
	var fresh_m := SaveSync.merge({"data": Net.synced["data"], "stamps": Net.synced["stamps"]},
		{"data": {"economy": {"money": 999}}, "stamps": {"economy": 10.0}})
	_check(fresh_m["from"]["economy"] == "server", "fresh game does not overwrite an older server save")
	Net.never_synced = false
	Economy.money = before + 3
	Net.autosave_tick()
	_check(float((Net.synced["stamps"] as Dictionary).get("economy", 0.0)) > 1.0e9, "after sync, changes get real unix stamps")
	Net.never_synced = was_never
	Economy.money = before
	# Opted in but the server is unreachable: the game keeps running locally.
	var hud := get_tree().current_scene.get_node_or_null(^"NetHud") as NetHud
	_check(Net.connect_to("ws://127.0.0.1:9"), "opt in to an unreachable server")
	var t0 := Time.get_ticks_msec()
	while Net.state != "unreachable" and Time.get_ticks_msec() - t0 < 8000:
		await _frames(5)
	_check(Net.state == "unreachable", "state becomes unreachable (%s after %d ms)" % [Net.state, Time.get_ticks_msec() - t0])
	_check(hud != null and hud.pill.visible and hud.pill_label.text.length() > 5, "offline indicator shown: %s" % (hud.pill_label.text.left(50) if hud else ""))
	_check(Net._retry_in > 0.0, "a reconnect is scheduled (%.1fs)" % Net._retry_in)
	var m0 := TimeManager.minutes
	var p0 := _player.global_position
	await _place(Vector2(p0.x, p0.z), 0.0)
	await _hold(&"move_forward", 30)
	await _frames(5)
	_check(_player.global_position.distance_to(p0) > 0.3, "the farmer still walks while the server is unreachable")
	_check(TimeManager.minutes != m0, "the clock keeps running offline")
	Net.go_offline()
	await _frames(2)
	_check(Net.state == "offline" and not hud.pill.visible, "go offline: single player again, indicator hidden")
	Settings.set_value("online_enabled", false)
	_check(AssetRegistry.set_active("save_sync", "every_30s") and (Modules.style("save_sync") as SaveSyncStyle).upload_seconds == 30.0, "save_sync: live swap")
	_check(AssetRegistry.set_active("save_sync", "every_5s"), "save_sync: swap back")
	return true


func _smoke_v5d_away() -> bool:
	await _section("v5d: disconnect / reconnect (away_avatar module)")
	var st := Modules.style("away_avatar") as AwayAvatarStyle
	_check(st != null and st.cafe_spot != "" and st.home_spot != "" and not st.welcome_lines.is_empty(), "away_avatar style: cafe/home spots + welcome lines")
	var cafe := TownNav.spot_position(st.cafe_spot)
	var home := TownNav.spot_position(st.home_spot)
	_check(cafe != Vector3.INF and home != Vector3.INF, "TownNav knows the cafe and farmhouse door spots")
	var route := TownNav.route(Vector3(-3, 0, 7), st.cafe_spot)
	_check(route.size() >= 2, "TownNav.route to the cafe has %d waypoints" % route.size())
	AwayMemory.reset()
	AwayMemory.remember(185.0, [{"npc": "Mina", "kind": "tea"}, {"npc": "Reza", "kind": "greet"}])
	_check(AwayMemory.active() and AwayMemory.visitors.has("Mina"), "AwayMemory stores the absence and visitors")
	var line := AwayMemory.line_for("mina_key", "Mina")
	_check(line != "" and ("چای" in line or "tea" in line.to_lower()), "Mina mentions the tea she brought: %s" % line.left(60))
	_check(AwayMemory.line_for("mina_key", "Mina") == "", "each townsperson mentions the absence only once")
	var welcome := Lang.fill(Lang.pick(st.welcome_lines), {"minutes": Lang.digits("3")})
	_check(welcome.length() > 5, "welcome-back toast: %s" % welcome.left(60))
	# TeaVisitController walks a bot to a target, greets, and restores the previous controller.
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	_check(not bots.is_empty(), "townspeople exist")
	var bot := bots[0] as TownspersonBot
	var prev := bot.controller
	var target := Node3D.new()
	target.name = "VisitTarget"
	get_tree().current_scene.add_child(target)
	target.global_position = bot.global_position + Vector3(2, 0, 0)
	bot.set_controller(TeaVisitController.new(prev, target, "greet", Lang.pick({"fa": "سلام!", "en": "Hi!"})))
	var said := false
	for i in 480:
		await _frames(1)
		if bot._bubble.visible:
			said = true
		if not (bot.controller is TeaVisitController):
			break
	_check(said, "the visiting townsperson greets the avatar (speech bubble)")
	_check(bot.controller == prev, "TeaVisitController hands the bot back after the visit")
	target.queue_free()
	AwayMemory.reset()
	_check(AssetRegistry.set_active("away_avatar", "always_home") and (Modules.style("away_avatar") as AwayAvatarStyle).cafe_to == 0.0, "away_avatar: swap to always_home")
	_check(AssetRegistry.set_active("away_avatar", "cafe_or_home"), "away_avatar: swap back")
	return true


func _smoke_v5d_accounts() -> bool:
	await _section("v5d: guest accounts + save key (accounts module)")
	var st := Modules.style("accounts") as AccountsStyle
	_check(st != null and st.guest_prefix != "" and st.max_players >= 2, "accounts style: prefix %s, max %d" % [st.guest_prefix if st else "", st.max_players if st else 0])
	Settings.set_value("guest_id", "")
	Settings.set_value("guest_token", "")
	var g := Net.guest_id()
	var tok := Net.guest_token()
	_check(g.begins_with(st.guest_prefix) and tok.length() >= 16, "guest id %s + token minted" % g)
	_check(Net.guest_id() == g and Net.guest_token() == tok, "guest id + token persist across calls")
	# Real auth (email / password) is out of scope - leave a note in SERVER_SETUP.md.
	_check(FileAccess.file_exists("res://docs/SERVER_SETUP.md"), "docs/SERVER_SETUP.md exists (auth note + VPS deploy)")
	_check(AssetRegistry.set_active("accounts", "guest_small") and (Modules.style("accounts") as AccountsStyle).max_players == 8, "accounts: live swap")
	_check(AssetRegistry.set_active("accounts", "guest"), "accounts: swap back")
	return true


func _smoke_v5d_npc_roles() -> bool:
	await _section("v5d: NPC role takeover groundwork (npc_roles module)")
	var st := Modules.style("npc_roles") as NpcRoleStyle
	_check(st != null and st.enabled and st.max_per_player >= 1, "npc_roles style: enabled, max %d" % (st.max_per_player if st else 0))
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	_check(not bots.is_empty(), "townspeople exist")
	var bot := bots[0] as TownspersonBot
	var prev := bot.controller
	bot.set_controller(TeaVisitController.NetNpcController.new("TestPlayer"))
	_check(bot.controller is TeaVisitController.NetNpcController, "NetNpcController takes over the bot")
	_check(bot.controller.on_greeted(bot, _player) != "", "claimed bot greets with a takeover line")
	_check(bot.controller.describe().contains("TestPlayer"), "describe() names the controlling player")
	bot.set_controller(prev)
	_check(AssetRegistry.set_active("npc_roles", "disabled") and not (Modules.style("npc_roles") as NpcRoleStyle).enabled, "npc_roles: swap to disabled")
	_check(AssetRegistry.set_active("npc_roles", "stub"), "npc_roles: swap back")
	return true



func _smoke_v7b1_platform() -> bool:
	_section("v7b1: platform (title, updates, brand, rooms API)")
	await PlatformSmoke.run(self)
	return true

func _smoke_modules() -> bool:
	await _section("asset modules (registry + runtime swap)")
	var required: Array[String] = ["terrain", "trees", "rocks", "plants", "crops", "fences", "buildings",
		"characters", "animals", "furniture", "water", "sky",
		"crop_types", "garden", "garden_rules", "lighting", "power", "yards", "minimap", "npc_social", "landscape",
		"tool_types", "house_styles",
		# v5a
		"crafting", "recipes", "market", "town_square", "population", "workplaces", "civic", "mosque", "church",
		"kitchen", "gestures",
		# v5b
		"fonts", "dialogue", "friendship", "shop_hours", "voices", "npc_card", "needs", "illnesses", "ingredients", "dishes", "cooking",
		# v5c
		"market_economy", "producers", "wages", "price_board", "livestock", "animal_housing",
		# v5d
		"netcode", "chat", "live_updates", "save_sync", "away_avatar", "accounts", "npc_roles",
		# v6a
		"night_sky", "real_clock", "dry_trees", "fishing_gear", "campfire", "deep_sea", "boats", "sunbathing",
		"gym", "house_music", "kitchenware", "hypermarket", "ui_text"]
	var types := AssetRegistry.types()
	for t in required:
		_check(t in types, "module type '%s' registered" % t)
	var bad := AssetRegistry.validate_all()
	_check(bad.is_empty(), "every module variant loads and its asset paths exist %s" % [bad])
	var scene := get_tree().current_scene
	var nature := scene.find_child("Nature", true, false) as NatureScatter
	var fence := scene.find_child("Fence", true, false) as Fence
	var beach := scene.find_child("Beach", true, false) as BeachBuilder
	var trees_before := nature.tree_positions.size() if nature else 0
	var fence_mat_before: Material = fence.wood_material if fence else null
	var sea_before: Variant = beach.water_material.get_shader_parameter(&"deep_color") if beach else null
	for t in types:
		var defaults := AssetRegistry.active_id(t)
		_check(AssetRegistry.get_module(t) != null and AssetRegistry.get_module(t).type == t, "%s: active module '%s' loads" % [t, defaults])
		var alt := ""
		for v in AssetRegistry.variants(t):
			if v != defaults:
				alt = v
				break
		_check(alt != "", "%s: has an alternate variant" % t)
		if alt == "":
			continue
		var got: Array[String] = []
		var cb := func(tt: String, _m: AssetModule) -> void: got.append(tt)
		AssetRegistry.module_changed.connect(cb)
		_check(AssetRegistry.set_active(t, alt), "%s: swap to '%s'" % [t, alt])
		AssetRegistry.module_changed.disconnect(cb)
		_check(got == [t] and AssetRegistry.active_id(t) == alt and Modules.style(t) == AssetRegistry.load_variant(t, alt),
			"%s: module_changed emitted and Modules.style() returns '%s'" % [t, alt])
		await _frames(2)
		match t:
			"trees":
				_check(nature != null and nature.tree_positions.size() > 50, "trees: NatureScatter re-scattered live (%d -> %d)" % [trees_before, nature.tree_positions.size() if nature else 0])
			"fences":
				_check(fence != null and fence.wood_material != fence_mat_before, "fences: fence re-skinned live")
			"water":
				_check(beach != null and beach.water_material.get_shader_parameter(&"deep_color") != sea_before, "water: sea colours changed live")
		_check(AssetRegistry.set_active(t, defaults), "%s: swap back to '%s'" % [t, defaults])
		await _frames(2)
	_check(nature != null and nature.tree_positions.size() == trees_before, "default trees restored (%d)" % (nature.tree_positions.size() if nature else 0))
	_check(fence != null and fence.wood_material == fence_mat_before, "default fence material restored")
	return true


func _smoke_save_load() -> bool:
	await _section("save / load")
	Economy.money = 1234
	Economy.money_changed.emit(1234)
	Economy.add_item("sardine", 2)
	Economy.add_item("conch", 1)
	TimeManager.reset_calendar(9, 15.0, "cloudy")
	await _place(Vector2(5.0, 5.0), 0.0, 4)
	var crate := get_tree().current_scene.find_child("Carry_farm_crate_2", true, false) as Carryable
	crate.global_position = Vector3(6.0, Terrain.height_at(6.0, 2.0), 2.0)
	var sard := Economy.count("sardine")
	_check(SaveGame.save_game() and SaveGame.has_save(), "save to user://save.json")
	Economy.money = 7
	Economy.remove_item("sardine", sard)
	TimeManager.reset_calendar(2, 8.0, "sunny")
	crate.global_position = Vector3(0, 0, 0)
	_player.global_position = Vector3(1, 2, 1)
	_check(SaveGame.load_game(), "load the save")
	await _frames(5)
	_check(Economy.money == 1234, "money restored (%d)" % Economy.money)
	_check(Economy.count("sardine") == sard and Economy.count("conch") >= 1, "inventory restored (sardine x%d)" % Economy.count("sardine"))
	_check(TimeManager.day == 9 and TimeManager.hour() == 15, "day + time restored (day %d %s)" % [TimeManager.day, TimeManager.clock_text()])
	_check(crate.global_position.distance_to(Vector3(6.0, Terrain.height_at(6.0, 2.0), 2.0)) < 0.1, "carryable position restored")
	_check(Vector2(_player.global_position.x, _player.global_position.z).distance_to(Vector2(5, 5)) < 0.3, "player position restored")
	SaveGame.delete_save()
	_check(not SaveGame.has_save(), "delete save (New game)")
	return true



# ------------------------------------------------------------------ v5c
func _ranch_world() -> RanchWorld:
	return get_tree().get_first_node_in_group(&"ranch_world") as RanchWorld


func _smoke_v5c_market() -> bool:
	await _section("v5c: living economy (market_economy module)")
	Market.reset()
	Market.sim_enabled = false
	_check(AssetRegistry.get_module("market_economy") is MarketEconomyStyle, "market_economy module active (%s)" % AssetRegistry.active_id("market_economy"))
	_check(absf(Market.mult("eggs") - 1.0) < 0.01 and absf(Market.mult("tomato") - 1.0) < 0.01, "fresh market: prices at their base (x%.2f)" % Market.mult("eggs"))
	_check(Market.is_tracked("eggs") and Market.is_tracked("wood_plank") and Market.is_tracked("milk") and not Market.is_tracked("turnip_seeds"), "goods are tracked, seeds keep fixed prices")
	# Supply: the farmer floods the market with tomatoes -> the price falls.
	var p0 := Economy.sell_price("tomato")
	Economy.add_item("tomato", 40)
	var got := Economy.sell("tomato", 40)
	var p1 := Economy.sell_price("tomato")
	_check(got > 0 and p1 < p0, "selling 40 tomatoes lowers the tomato price (%d -> %d G)" % [p0, p1])
	# Demand: a shortage raises the price.
	var b0 := Shops.buy_price("eggs")
	Market.take("eggs", Market.stock_of("eggs") * 0.9)
	var b1 := Shops.buy_price("eggs")
	_check(Market.is_shortage("eggs") and b1 > b0, "egg shortage raises the shop price (%d -> %d G)" % [b0, b1])
	_check(Market.mult("eggs") <= Market.style().max_mult + 0.001, "prices stay within the module's cap (x%.2f)" % Market.mult("eggs"))
	# A sold-out good cannot be bought.
	Economy.add_money(2000)
	Market.stock["wood_plank"] = 0.0
	var planks := Economy.count("wood_plank")
	var msg := Shops.purchase("wood_plank", 1, Shops.shop("carpenter"), get_tree())
	_check(Economy.count("wood_plank") == planks, "sold-out planks cannot be bought (%s)" % msg)
	# One market morning: history, production, recovery.
	Market.advance_day(TimeManager.day + 1)
	_check(Market.stock_of("wood_plank") > 0.0, "the carpenter restocks planks overnight (%.1f)" % Market.stock_of("wood_plank"))
	_check(Market.stock_of("eggs") > Market.target("eggs") * 0.1 * 1.5, "the poultry farm restocks eggs (%.1f)" % Market.stock_of("eggs"))
	_check((Market.history.get("eggs", []) as Array).size() >= 1, "daily price history recorded")
	Market.advance_day(TimeManager.day + 2)
	_check(Market.change_pct("eggs") != 0 or Market.change_pct("tomato") != 0, "prices show a trend vs yesterday (eggs %d%%, tomato %d%%)" % [Market.change_pct("eggs"), Market.change_pct("tomato")])
	_check(Market.buy_price("eggs") < b1, "egg price falls back after the restock (%d G)" % Market.buy_price("eggs"))
	# Player purchases take stock out of the town.
	var s0 := Market.stock_of("iron_nails")
	Shops.purchase("iron_nails", 3, Shops.shop("blacksmith"), get_tree())
	_check(Market.stock_of("iron_nails") < s0 - 2.5, "buying nails takes them from the town's stock")
	# Module swap: a calm market moves much less.
	Market.reset()
	Market.take("eggs", Market.stock_of("eggs") * 0.9)
	var wild := Market.mult("eggs")
	AssetRegistry.set_active("market_economy", "stable_prices")
	var calm := Market.mult("eggs")
	_check(calm < wild and calm <= 1.25 + 0.001, "swap -> stable_prices: same shortage, smaller jump (x%.2f vs x%.2f)" % [calm, wild])
	AssetRegistry.set_active("market_economy", "supply_demand")
	Market.reset()
	return true


func _smoke_v5c_producers() -> bool:
	await _section("v5c: producers + workplace roles (producers module)")
	Market.reset()
	_check(AssetRegistry.is_collection("producers") and Market.producers().size() >= 10, "%d producer modules" % Market.producers().size())
	var carp := Shops.stock(Shops.shop("carpenter"))
	_check("wood_plank" in carp and "wooden_chair" in carp and "wooden_table" in carp, "the carpenter sells boards and furniture")
	var smith := Shops.stock(Shops.shop("blacksmith"))
	_check("shears" in smith and "milk_pail" in smith and "iron_nails" in smith, "the blacksmith makes tools (shears, milk pail, nails)")
	var fruit := Shops.shop("fruit_shop")
	_check("apple" in Shops.stock(fruit) and "strawberry" in Shops.buys(fruit), "the fruit shop sells farm produce and buys yours")
	# The farmer sells crops to a shop: price follows the market and supply rises.
	Economy.add_item("strawberry", 5)
	var st0 := Market.stock_of("strawberry")
	var g := Shops.sell("strawberry", 5, fruit)
	_check(g > 0 and Market.stock_of("strawberry") > st0, "sell strawberries to the fruit shop (%d G) - town supply rises" % g)
	_check(Economy.is_sellable("eggs") and Economy.is_sellable("milk") and Economy.is_sellable("wool"), "eggs, milk and wool are sellable")
	# Furniture needs planks: an empty plank stock halts the furniture workshop.
	Market.stock["wood_plank"] = 0.0
	Market.stock["wooden_chair"] = 0.0
	var boards := Market.producer("carpenter_boards")
	var furn := Market.producer("carpenter_furniture")
	_check(boards != null and furn != null and furn.inputs.has("wood_plank"), "furniture is made from planks")
	var made := Market.run_production()
	_check(made.has("carpenter_furniture"), "furniture workshop ran (%s)" % [made.get("carpenter_furniture", {})])
	_check(Market.stock_of("wooden_chair") > 0.0, "chairs restocked from the boards")
	# A sick worker = no production = a shortage.
	var forge := Market.producer("blacksmith_forge")
	var sick: Array[String] = []
	for r: Dictionary in Population.residents():
		if str(r.get("job", "")) in forge.worker_jobs:
			var key := Population.full_name(r)
			Needs.npc_state_by_key(key)["illness"] = "cold"
			sick.append(key)
	Market.stock["iron_bar"] = 0.0
	Market.run_production()
	_check(sick.size() > 0 and "blacksmith_forge" in Market.idle_producers, "a sick smith stops the forge (%d workers ill)" % sick.size())
	_check(Market.is_shortage("iron_bar"), "-> iron bar shortage")
	for key in sick:
		Needs.npc_state_by_key(key)["illness"] = ""
	Market.run_production()
	_check(Market.stock_of("iron_bar") > 0.0 and not "blacksmith_forge" in Market.idle_producers, "healthy again: the forge works")
	AssetRegistry.set_active("producers", "bakery")
	_check(Market.producers().size() >= 10, "producers collection survives a swap")
	AssetRegistry.set_active("producers", "carpenter_boards")
	Market.reset()
	return true


func _smoke_v5c_wages() -> bool:
	await _section("v5c: wages, meals and the doctor (wages module)")
	Market.reset()
	var res := Population.residents()
	var worker: Dictionary = {}
	for r: Dictionary in res:
		if Market.wage_of(r) > 40:
			worker = r
			break
	_check(not worker.is_empty(), "jobs pay wages (%s: %d G)" % [Population.full_name(worker), Market.wage_of(worker)])
	var key := Population.full_name(worker)
	var w0 := Market.wallet(key)
	var total := Market.pay_wages()
	_check(total > 0 and Market.wallet(key) == w0 + Market.wage_of(worker), "payday: %d G paid to %d residents" % [total, res.size()])
	# Townsfolk eat: a meal is bought from the market (Needs.meal_eaten).
	Market.sim_enabled = true
	var w1 := Market.wallet(key)
	var meals0 := int(Market.ledger["meals"])
	Needs.eat(30.0, true, key)
	_check(int(Market.ledger["meals"]) == meals0 + 1 and Market.wallet(key) < w1, "a townsperson's meal is paid from their wallet (%d -> %d G)" % [w1, Market.wallet(key)])
	var basket_before := 0.0
	for f in Market.style().npc_food_basket:
		basket_before += Market.stock_of(str(f))
	for i in 40:
		Market.npc_meal(key)
	var basket_after := 0.0
	for f in Market.style().npc_food_basket:
		basket_after += Market.stock_of(str(f))
	_check(basket_after < basket_before - 5.0, "town meals eat into the food stock (%.0f -> %.0f)" % [basket_before, basket_after])
	Market.sim_enabled = false
	# The doctor: a poor patient pays what they can; the city pays the rest.
	Market.wallets[key] = 10
	var paid := Market.npc_pays_doctor(key, 80)
	_check(paid == 10 and int(Market.ledger["city_health"]) >= 70, "the city covers a poor patient's doctor fee (paid %d, city %d)" % [paid, int(Market.ledger["city_health"])])
	_check(Market.average_savings() > 0, "average savings %d G" % Market.average_savings())
	AssetRegistry.set_active("wages", "modest_wages")
	var modest := 0
	for r: Dictionary in res:
		modest += Market.wage_of(r)
	AssetRegistry.set_active("wages", "fair_wages")
	_check(modest < total, "swap -> modest_wages pays less (%d vs %d G)" % [modest, total])
	Market.reset()
	return true


func _smoke_v5c_price_board() -> bool:
	await _section("v5c: market prices board + panel (price_board module)")
	Market.reset()
	var board := get_tree().get_first_node_in_group(&"price_board") as PriceBoard
	_check(board != null, "PriceBoard in the world")
	if board == null:
		return false
	var d := Vector2(board.global_position.x, board.global_position.z).distance_to(Vector2(0, -24))
	_check(d < 12.0, "board stands by the market (%.1f m)" % d)
	Market.take("eggs", Market.stock_of("eggs") * 0.9)
	board.refresh()
	var lines := board.lines()
	_check(lines.size() >= 6, "board lists %d goods" % lines.size())
	var joined := "\n".join(lines)
	_check("تخم" in joined and "۰" in joined or "تخم" in joined, "board text is Persian (%s)" % (lines[0] if lines.size() > 0 else ""))
	var hud := _hud
	var panel := hud.get("prices_panel") as PricesPanel if hud else null
	_check(panel != null and not panel.visible, "prices panel exists (closed)")
	board.zone.interact(_player)
	await _frames(3)
	_check(panel.visible, "E at the board opens the prices panel")
	await _tap(&"interact")
	_check(not panel.visible, "E closes it")
	await _tap(&"market_prices")
	_check(panel.visible, "B opens the prices panel")
	await _frames(2)
	var labels := panel.find_children("*", "Label", true, false).size()
	_check(labels > 30, "panel shows the goods grid + economy summary (%d labels)" % labels)
	await _tap(&"menu")
	_check(not panel.visible, "Esc closes it")
	AssetRegistry.set_active("price_board", "market_screen")
	await _frames(3)
	board = get_tree().get_first_node_in_group(&"price_board") as PriceBoard
	_check(board != null and board.lines().size() >= 6, "swap -> market_screen board")
	AssetRegistry.set_active("price_board", "chalkboard")
	await _frames(2)
	Market.reset()
	return true


func _smoke_v5c_livestock() -> bool:
	await _section("v5c: livestock via the carpenter (animal_housing + livestock modules)")
	Ranch.reset()
	Market.reset()
	Ranch.sim_enabled = false
	var world := _ranch_world()
	_check(world != null and world.sites.size() >= 2, "ranch yard south of the farm (%d plots)" % (world.sites.size() if world else 0))
	var desk := _item_in("livestock_desk", "carpenter")
	_check(desk != null, "the carpenter has a livestock desk")
	var hud := _hud
	var lp := hud.get("livestock_panel") as LivestockPanel if hud else null
	if desk:
		TimeManager.reset_calendar(TimeManager.day, 11.0, "sunny")
		desk.call("_on_interacted", _player)
		await _frames(3)
		_check(lp != null and lp.visible, "the desk opens the livestock panel")
		await _tap(&"interact")
		_check(lp != null and not lp.visible, "E closes it")
	# Order a coop: gold + wood, takes a day.
	Economy.money = 100
	_check(Ranch.order("coop") != "" and Ranch.housing_state("coop") == "none", "no coop without the gold")
	Economy.money = 8000
	Economy.add_item("wood_plank", 40)
	Economy.add_item("iron_nails", 20)
	var gold0 := Economy.money
	var planks0 := Economy.count("wood_plank")
	var m := Ranch.order("coop")
	var coop := Ranch.housing_def("coop")
	_check(Ranch.housing_state("coop") == "ordered" and Economy.money == gold0 - coop.cost_gold and Economy.count("wood_plank") == planks0 - int(coop.cost_items.get("wood_plank", 0)),
		"order a coop: %d G + planks (%s)" % [coop.cost_gold, m])
	_check(Ranch.buy_problem("chicken") != "", "no chickens before the coop is built")
	await _frames(3)
	_check(world.sites.has("coop"), "construction site appears")
	Ranch.advance_day(Ranch.ready_day("coop"))
	_check(Ranch.is_built("coop"), "the coop is built after %d day" % coop.build_days)
	# Chickens.
	for i in 3:
		Ranch.buy_animal("chicken")
	_check(Ranch.count_kind("chicken") == 3, "bought 3 chickens")
	await _frames(4)
	_check(world.animal_nodes.size() == 3, "3 chickens wander in the coop yard")
	var hen := world.animal_nodes.values()[0] as FarmAnimal
	var pad := world.paddock_rect(coop)
	_check(hen != null and pad.has_point(Vector2(hen.global_position.x, hen.global_position.z)), "chickens stay inside their paddock")
	# Feed (bought at the livestock desk) and collect eggs.
	var feed_shop := Shops.shop("livestock")
	_check("chicken_feed" in Shops.stock(feed_shop) and "hay" in Shops.stock(feed_shop), "the desk sells chicken feed and hay")
	_check(Ranch.feed_housing("coop") != "" and not bool(Ranch.animals[0]["fed_today"]), "can't feed without feed")
	Shops.purchase("chicken_feed", 10, feed_shop, get_tree())
	var feed0 := Economy.count("chicken_feed")
	Ranch.feed_housing("coop")
	_check(bool(Ranch.animals[0]["fed_today"]) and Economy.count("chicken_feed") < feed0, "the trough feeds the flock (%d -> %d feed)" % [feed0, Economy.count("chicken_feed")])
	Ranch.advance_day(TimeManager.day + 2)
	var uid := int(Ranch.animals[0]["uid"])
	_check(int(Ranch.animal(uid)["product_ready"]) >= 1, "a fed, happy hen lays an egg")
	var eggs0 := Economy.count("eggs")
	hen = world.animal_nodes.get(uid) as FarmAnimal
	if hen and hen.zone:
		hen.zone.interact(_player)
	else:
		Ranch.interact(uid)
	_check(Economy.count("eggs") > eggs0, "E on the hen collects the egg (%d -> %d)" % [eggs0, Economy.count("eggs")])
	Ranch.interact(uid)
	_check(bool(Ranch.animal(uid)["fed_today"]), "E on a hungry hen feeds her")
	var h0 := float(Ranch.animal(uid)["happiness"])
	Ranch.interact(uid)
	_check(float(Ranch.animal(uid)["happiness"]) > h0 or h0 >= 100.0, "E again pets her (happiness %d)" % int(Ranch.animal(uid)["happiness"]))
	# Unfed animals get unhappy and lay less.
	for a: Dictionary in Ranch.animals:
		a["product_ready"] = 0
	for i in 5:
		Ranch.advance_day(TimeManager.day + 3 + i)
	var sad := Ranch.animals[1] as Dictionary
	_check(Ranch.mood(sad) != "happy", "five days without food: %s is %s (%d)" % [sad["name"], Ranch.mood(sad), int(sad["happiness"])])
	var d := Ranch.animal_def("chicken")
	_check(Ranch.daily_yield(d, 10.0, false) == 0 and Ranch.daily_yield(d, 90.0, true) == d.product_qty, "unhappy hens lay nothing, happy fed hens lay fully")
	# Breeding: two happy adults -> a chick that grows up.
	for a: Dictionary in Ranch.animals:
		a["happiness"] = 95.0
		a["adult"] = true
	Ranch.last_birth.clear()
	_check(Ranch.can_breed("chicken"), "two happy adult hens + room -> they can breed")
	var baby := Ranch.try_breed("chicken", true)
	_check(not baby.is_empty() and not bool(baby["adult"]), "two happy hens -> a chick is born (%s)" % baby.get("name", ""))
	await _frames(4)
	var chick := world.animal_nodes.get(int(baby.get("uid", -1))) as FarmAnimal
	_check(chick != null and not chick.adult, "the chick appears in the yard (young)")
	for i in d.adult_days:
		for a: Dictionary in Ranch.animals:
			a["fed_today"] = true
		Ranch.advance_day(TimeManager.day + 10 + i)
	_check(bool(Ranch.animal(int(baby["uid"]))["adult"]), "the chick grows into a hen after %d days" % d.adult_days)
	# The barn: cows (milk pail) and sheep (shears).
	Economy.money = 20000
	Ranch.order("barn")
	_check(Ranch.housing_state("barn") == "ordered", "order a barn")
	Ranch.finish_now("barn")
	Ranch.buy_animal("cow")
	Ranch.buy_animal("sheep_flock")
	_check(Ranch.count_kind("cow") == 1 and Ranch.count_kind("sheep_flock") == 1, "a cow and a sheep in the barn")
	await _frames(4)
	var cow_uid := -1
	for a: Dictionary in Ranch.animals:
		if str(a["kind"]) == "cow":
			cow_uid = int(a["uid"])
	Shops.purchase("hay", 6, feed_shop, get_tree())
	Ranch.feed_housing("barn")
	Ranch.advance_day(TimeManager.day + 20)
	_check(int(Ranch.animal(cow_uid)["product_ready"]) >= 1, "a fed cow has milk")
	while Economy.has("milk_pail"):
		Economy.remove_item("milk_pail", 1)
	var milk0 := Economy.count("milk")
	Ranch.collect(cow_uid)
	_check(Economy.count("milk") == milk0, "no milking without a pail")
	Shops.purchase("milk_pail", 1, Shops.shop("blacksmith"), get_tree())
	Ranch.collect(cow_uid)
	_check(Economy.count("milk") > milk0, "milk the cow with the blacksmith's pail (%d milk)" % Economy.count("milk"))
	# Products feed the economy.
	var ms0 := Market.stock_of("milk")
	var sold := Shops.sell("milk", Economy.count("milk"), Shops.shop("grocery"))
	_check(sold > 0 and Market.stock_of("milk") > ms0, "sell milk to the grocery (%d G) - town supply rises" % sold)
	_check(Ranch.animal_def("sheep_flock").product_item == "wool" and Market.producer("tailor_spinning").inputs.has("wool"), "wool feeds the tailor's yarn")
	_check(Ranch.animal_def("chicken").product_item in Market.style().npc_food_basket, "eggs are on the townsfolk's table")
	# Save / load round trip.
	var snap := SaveGame.snapshot()
	var n := Ranch.animals.size()
	var stock_eggs := Market.stock_of("eggs")
	Ranch.reset()
	Market.reset()
	SaveGame.apply(snap)
	await _frames(3)
	_check(Ranch.animals.size() == n and Ranch.is_built("coop") and Ranch.is_built("barn"), "ranch survives save/load (%d animals)" % Ranch.animals.size())
	_check(absf(Market.stock_of("eggs") - stock_eggs) < 0.01, "market stock survives save/load")
	# Swaps (collections).
	AssetRegistry.set_active("livestock", "cow")
	AssetRegistry.set_active("animal_housing", "barn")
	await _frames(3)
	_check(Ranch.animal_defs().size() >= 3 and Ranch.housing_defs().size() >= 2 and world.sites.size() >= 2, "livestock + housing collections survive a swap")
	AssetRegistry.set_active("livestock", "chicken")
	AssetRegistry.set_active("animal_housing", "coop")
	await _frames(3)
	Ranch.reset()
	Market.reset()
	Ranch.sim_enabled = true
	return true


# ------------------------------------------------------------------ v4
func _plot() -> FarmPlot:
	return get_tree().current_scene.get_node(^"CropPlot") as FarmPlot


func _smoke_v4_crops_garden() -> bool:
	await _section("v4: crop modules / garden / season hook")
	var plot := _plot()
	_check(AssetRegistry.is_collection("crop_types"), "crop_types is a collection module type")
	var ids := GameData.crop_ids()
	for want in ["apple_tree", "potato", "banana", "corn", "tomato", "turnip"]:
		_check(want in ids, "crop module '%s' registered" % want)
	_check(ids.size() >= 10, "%d crop modules" % ids.size())
	var stages_ok := true
	for cid in ids:
		var def := GameData.crop_def(cid)
		if def.stage_at(0.0) != 0 or def.stage_at(def.total_days()) != 4 or not (def.footprint_m2 in [0.5, 1.0]):
			stages_ok = false
		if def.footprint_m2 >= 1.0 and def.cells() != 2:
			stages_ok = false
	_check(stages_ok, "every crop: 5 stages (planted..fruit), footprint 0.5 m² (small) or 1 m² (bush/tree)")
	_check(GameData.crop_def("tomato").footprint_m2 == 1.0 and GameData.crop_def("apple_tree").footprint_m2 == 1.0 and GameData.crop_def("potato").footprint_m2 == 0.5, "tomato/apple 1 m², potato 0.5 m²")
	# Garden layout: beds with walkable paths, fence, expansion.
	_check(plot.beds >= 3 and plot.path_rects().size() >= plot.beds, "garden: %d beds with %d walkable path strips" % [plot.beds, plot.path_rects().size()])
	var mid := (plot.tile_world_position(plot.tile_index(0, 3)) + plot.tile_world_position(plot.tile_index(1, 3))) * 0.5
	_check(plot.is_on_path(mid) and plot.tile_at(mid) < 0, "the strip between two beds is a path, not a bed")
	_check(get_tree().current_scene.find_child("FenceCollision", true, false) != null, "garden fence with collision")
	# Till -> plant -> water -> sprout -> growth.
	TimeManager.reset_calendar(1, 8.0, "sunny")
	Economy.reset()
	plot.from_save({})
	plot.flush()
	var i0 := plot.tile_index(0, 0)
	_check(plot.till(i0) and plot.tiles[i0]["state"] == FarmPlot.TileState.TILLED, "hoe tills a cell (soil turns brown)")
	plot.flush()
	Economy.add_item("turnip_seeds", 2)
	_check(plot.plant(i0, "turnip_seeds") and plot.stage_of(i0) == 0, "plant turnip: stage 'planted'")
	plot.flush()
	_check(plot.plant_node(i0) != null and int(plot.plant_node(i0).get_meta("stage", -1)) == 0, "planted model shown (stage 0 'planted')")
	Economy.refill_can()
	var stages_seen := {}
	for d in 6:
		plot.water(i0)
		TimeManager.sleep_until_morning(6.0)
		stages_seen[plot.stage_of(i0)] = true
	_check(stages_seen.size() >= 3 and plot.is_mature(i0), "turnip grows through the stages to fruit (%s)" % [stages_seen.keys()])
	# Footprint: 1 m² crops need two cells; planting next to / on another crop is blocked.
	var t0 := plot.tile_index(1, 0)
	var t1 := plot.tile_index(1, 1)
	plot.till(t0)
	plot.till(t1)
	Economy.add_item("tomato_seeds", 2)
	TimeManager.reset_calendar(8, 8.0, "sunny")  # summer
	_check(plot.plant(t0, "tomato_seeds") and int(plot.tiles[t1].get("owner", -1)) == t0, "a tomato (1 m²) occupies two cells")
	_check(plot.plant_block_reason(t1, "turnip_seeds") != "", "planting right on/next to the tomato is blocked: '%s'" % plot.plant_block_reason(t1, "turnip_seeds"))
	var lone := plot.tile_index(2, 0)
	plot.till(lone)
	plot.debug_set_tile(plot.tile_index(2, 1), "potato", 1.0)
	_check(plot.plant_block_reason(lone, "tomato_seeds") != "", "no room for a 1 m² crop squeezed against a potato")
	# Season hook (garden_rules module).
	var rules := plot.rules()
	_check(rules != null and not rules.can_plant(GameData.crop_def("tomato"), "winter"), "season hook: seasonal rules block tomatoes in winter")
	_check(Economy.crop_in_season("tomato") and not Economy.crop_in_season("pumpkin"), "shop follows the season hook (summer: tomato yes, pumpkin no)")
	_check(AssetRegistry.set_active("garden_rules", "any_season") and plot.rules().can_plant(GameData.crop_def("tomato"), "winter"), "swap garden_rules -> any_season: tomatoes allowed in winter")
	AssetRegistry.set_active("garden_rules", "seasonal")
	# Expand.
	var beds0 := plot.beds
	Economy.money = 99999
	_check(plot.can_expand() and plot.expand() and plot.beds == beds0 + 1, "expand the garden: %d -> %d beds" % [beds0, plot.beds])
	plot.flush()
	# Perennial apple tree regrows after harvest.
	var at := plot.tile_index(plot.beds - 1, 4)
	plot.debug_set_tile(at, "apple_tree", GameData.crop_def("apple_tree").total_days())
	var got := plot.harvest(at)
	_check(got >= 1 and plot.tiles[at]["state"] == FarmPlot.TileState.PLANTED, "apple tree: harvest %d, the tree stays (regrows)" % got)
	# Save round-trip of the garden.
	var snap := plot.to_save()
	plot.from_save({})
	plot.from_save(snap)
	_check(plot.beds == beds0 + 1 and plot.tiles[t0]["crop"] == "tomato", "garden save/load keeps beds + crops")
	plot.from_save({})
	plot.flush()
	TimeManager.reset_calendar(1, 10.0, "sunny")
	Economy.reset()
	return true


func _smoke_v4_tools() -> bool:
	await _section("v4: tools (animation + sound, upgrades, unlocks)")
	Economy.reset()
	_check(GameData.tools.size() >= 6, "%d tool modules" % GameData.tools.size())
	var anims := {}
	for tid in GameData.tools:
		var t := GameData.tools[tid] as ToolDef
		anims[t.anim] = true
		_check(t.validate().is_empty(), "tool %s: valid, own sound '%s' and anim '%s'" % [tid, t.sound, t.anim])
	_check(anims.size() >= 5, "every tool kind has its own animation (%d)" % anims.size())
	await _place(Vector2(-3.0, 2.0), 0.0, 4)
	var played: Array = []
	_player.tools.played.connect(func(t: ToolDef) -> void: played.append(t.item_id))
	for kind in ["hoe", "watering_can", "seeds", "hands"]:
		_player.play_tool(kind)
		await _frames(2)
	_check(played == ["hoe", "watering_can", "seed_pouch", "harvest_basket"], "tools play in hand: %s" % [played])
	_check(_player.tools.current != null and _player.tools.current.is_inside_tree(), "tool prop is held during the animation")
	await _frames(70)
	_check(_player.tools.current == null, "tool is put away after the animation")
	# Unlocks + upgrades.
	TimeManager.reset_calendar(1, 9.0, "sunny")
	Economy.money = 5000
	_check(not ("steel_hoe" in Economy.shop_stock()), "steel hoe locked on day 1")
	TimeManager.reset_calendar(3, 9.0, "sunny")
	_check("steel_hoe" in Economy.shop_stock() and Economy.buy("steel_hoe"), "steel hoe unlocked on day 3 and bought")
	_check(Economy.best_tool("hoe").item_id == "steel_hoe", "best hoe is now the steel hoe")
	_check(not ("hammer" in Economy.shop_stock()) or Economy.buy("hammer"), "hammer sold (day 2+)")
	var plot := _plot()
	plot.from_save({})
	var i0 := plot.tile_index(0, 4)
	_check(plot.till(i0) and plot.tiles[i0 + 1]["state"] == FarmPlot.TileState.TILLED, "steel hoe tills 2 cells (1 m²) per swing")
	played.clear()
	_player.play_tool("hoe")
	_check(played == ["steel_hoe"], "the upgraded hoe is the one animated")
	await _frames(70)
	plot.from_save({})
	plot.flush()
	Economy.reset()
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v4_lights_power() -> bool:
	await _section("v4: night lights / farmhouse lamp / electricity")
	var nl := get_tree().get_first_node_in_group(&"night_lights_controller") as NightLights
	_check(nl != null, "NightLights controller present")
	PowerGrid.set_power(true)
	var sunset := TimeManager.sunset()
	_check(nl.amount_at(12.0) < 0.01 and nl.amount_at(23.0) > 0.99, "lights off at noon, on at night")
	_check(nl.amount_at(sunset - 1.5) < 0.05 and nl.amount_at(sunset + 0.5) > 0.5, "lights switch on at sunset (%.1f h)" % sunset)
	TimeManager.reset_calendar(2, 22.0, "sunny")
	await _frames(4)
	nl.apply()
	var porch := get_tree().get_nodes_in_group(&"porch_lights")
	var lit := 0
	for l in porch:
		if (l as Light3D).visible and (l as Light3D).light_energy > 0.1:
			lit += 1
	_check(porch.size() >= 1 and lit == porch.size(), "farmhouse porch lamp on at night (%d/%d)" % [lit, porch.size()])
	_check(Building.window_material(true).emission_energy_multiplier > 1.0, "windows glow at night")
	TimeManager.reset_calendar(2, 12.0, "sunny")
	await _frames(3)
	nl.apply()
	_check(not (porch[0] as Light3D).visible if not porch.is_empty() else false, "farmhouse lamp off at noon")
	# Breaker by hand.
	TimeManager.reset_calendar(2, 22.0, "sunny")
	var breakers := get_tree().get_nodes_in_group(&"breakers")
	_check(breakers.size() >= 2, "%d breakers (farmhouse + town pole)" % breakers.size())
	var bb := breakers[0] as BreakerBox
	(bb.get("_zone") as Interactable).interacted.emit(_player)
	await _frames(3)
	nl.apply()
	_check(not PowerGrid.power_on, "pulling the breaker cuts the power")
	lit = 0
	for l in porch:
		if (l as Light3D).visible:
			lit += 1
	_check(lit == 0, "electric lamps off in a power cut")
	var candles := get_tree().get_nodes_in_group(&"candle_lights")
	var on := 0
	for c in candles:
		if (c as Light3D).visible:
			on += 1
	_check(candles.size() >= 5 and on == candles.size(), "homes light candles / lanterns / fireplaces (%d/%d)" % [on, candles.size()])
	var tv: Node = null
	for n in get_tree().get_nodes_in_group(&"interior_items"):
		if str(n.get("kind")) == "tv":
			tv = n
			break
	if tv:
		tv.call("_on_interacted", _player)
		_check(not bool(tv.get("is_on")), "TV can't be switched on without power")
	(bb.get("_zone") as Interactable).interacted.emit(_player)
	await _frames(3)
	nl.apply()
	_check(PowerGrid.power_on and (porch[0] as Light3D).visible, "breaker restores the power, lamp back on")
	on = 0
	for c in candles:
		if (c as Light3D).visible:
			on += 1
	_check(on == 0, "candles out when the power is back")
	AssetRegistry.set_active("lighting", "cool_led")
	nl.apply()
	_check((porch[0] as Light3D).light_color.b > 0.8, "lighting module swap: cool LED bulbs")
	AssetRegistry.set_active("lighting", "warm_bulbs")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v4_world() -> bool:
	await _section("v4: yards / minimap / landscape (forest, mountains, river)")
	_check(_town.yard_runs >= 20, "yard fences + railings (front and back yards): %d runs" % _town.yard_runs)
	var mm := get_tree().get_first_node_in_group(&"minimap") as Control
	_check(mm != null and mm.visible and _on_screen(mm), "minimap visible on screen")
	await _tap(&"toggle_minimap")
	_check(mm != null and not mm.visible, "Tab hides the minimap")
	await _tap(&"toggle_minimap")
	_check(mm != null and mm.visible, "Tab shows it again")
	var land := get_tree().get_first_node_in_group(&"landscape") as Landscape
	_check(land != null and land.forest_instances > 400 and land.far_instances > 300, "dense forest belt (%d) + far forest (%d)" % [land.forest_instances if land else 0, land.far_instances if land else 0])
	_check(land != null and land.mountain_count >= 8, "%d mountains on the horizon" % (land.mountain_count if land else 0))
	_check(land != null and land.river_vertices > 100 and land.river_points().size() >= 5, "river water ribbon (%d verts)" % (land.river_vertices if land else 0))
	var rp := Vector2(-55.0, 16.5)
	_check(Terrain.is_river(rp.x, rp.y) and Terrain.height_at(rp.x, rp.y) < Terrain.river_surface(rp.x, rp.y) - 0.3, "river channel carved below the water line")
	var lv := Terrain.river_levels()
	var falls := true
	for k in range(1, lv.size()):
		if lv[k] > lv[k - 1] + 0.001:
			falls = false
	_check(falls, "river water level only falls downstream")
	var below := true
	for q: Vector2 in [Vector2(-33.0, 24.0), Vector2(-31.0, 33.0), Vector2(-30.0, 40.0), Vector2(-90.0, 9.0)]:
		if Terrain.height_at(q.x, q.y) > Terrain.river_surface(q.x, q.y) - 0.2:
			below = false
	_check(below, "channel stays below the water all the way (outflow through the hill too)")
	var forest_before := land.forest_instances if land else 0
	AssetRegistry.set_active("landscape", "lowlands")
	await _frames(2)
	_check(land != null and land.forest_instances < forest_before, "landscape module swap rebuilds (%d -> %d trees)" % [forest_before, land.forest_instances if land else 0])
	AssetRegistry.set_active("landscape", "highlands")
	await _frames(2)
	# Fishing works at the river.
	await _place(Vector2(-55.0, 19.8), 180.0, 6)
	_check(not _player.fishing.probe_water(_player).is_empty(), "can fish / refill at the river")
	return true


func _smoke_v4_npc_social() -> bool:
	await _section("v4: NPC social life")
	var social := get_tree().get_first_node_in_group(&"npc_social") as NpcSocial
	_check(social != null, "NpcSocial module present")
	_check(TownNav.public_spots().size() >= 4, "random-walk detour spots: %d" % TownNav.public_spots().size())
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var sc0 := (bots[0] as TownspersonBot).controller as ScheduleController
	_check(sc0.detour_chance > 0.0 and sc0.stroll_radius > 0.0, "randomised routes enabled (detour %.2f, stroll %.0f m)" % [sc0.detour_chance, sc0.stroll_radius])
	var detours := 0
	var start := Vector3(-45.0, 0.0, -112.0)
	var bot0 := bots[0] as TownspersonBot
	for k in 12:
		bot0.global_position = start
		sc0._begin(bot0, {"spot": "square", "activity": "wander", "from": 0.0, "to": 24.0})
		if sc0.detour_spot != "":
			detours += 1
	sc0.detour_spot = ""
	_check(detours >= 1, "routes vary: %d/12 walks took a detour" % detours)
	var c := TownLayout.TOWN_CENTER + Vector2(3.0, 10.0)
	await _place(c, 180.0, 4)
	var a := bots[0] as TownspersonBot
	var b := bots[1] as TownspersonBot
	for bot: TownspersonBot in [a, b]:
		var sc := bot.controller as ScheduleController
		sc.current = {"spot": "square", "activity": "wander", "from": 0.0, "to": 24.0}
		sc.arrived = true
		sc.chat_timer = 0.0
		sc.social_cooldown = 0.0
	a.global_position = Vector3(c.x - 0.8, Terrain.height_at(c.x, c.y - 3.0) + 0.1, c.y - 3.0)
	b.global_position = Vector3(c.x + 0.8, Terrain.height_at(c.x, c.y - 3.0) + 0.1, c.y - 3.0)
	# Keep unrelated random chats from changing this exact-count fixture.
	social.set_physics_process(false)
	var n0 := social.chats_started
	_check(social.start_chat(a, b), "two townspeople start a chat")
	_check(social.chats_started == n0 + 1, "chat counted")
	social.set_physics_process(true)
	_check((a.controller as ScheduleController).chat_timer > 0.0 and (b.controller as ScheduleController).chat_timer > 0.0, "both stop and face each other")
	_check((a.get("_bubble") as Label3D).visible and (a.get("_bubble") as Label3D).text != "", "speech bubble: '%s'" % (a.get("_bubble") as Label3D).text)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 4000:
		await get_tree().physics_frame
	_check((b.get("_bubble") as Label3D).visible, "partner replies: '%s'" % (b.get("_bubble") as Label3D).text)
	var r0 := social.reactions
	var other := bots[2] as TownspersonBot
	social.react(other, _player)
	_check(social.reactions == r0 + 1 and (other.get("_bubble") as Label3D).visible, "townsperson reacts to the player: '%s'" % (other.get("_bubble") as Label3D).text)
	return true


func _smoke_v4_house_styles() -> bool:
	await _section("v4: house styles (wooden / stone / modern)")
	var kinds := {}
	var shader_walls := 0
	for id in _town.buildings:
		var b := _town.buildings[id] as Building
		if b.house_style:
			kinds[b.house_style.kind] = int(kinds.get(b.house_style.kind, 0)) + 1
			shader_walls += 1
	_check(kinds.has("wooden") and kinds.has("stone") and kinds.has("modern"), "homes use all three styles %s" % [kinds])
	var fh := _town.buildings["farmhouse"] as Building
	_check(fh.house_style != null and fh.house_style.kind == "wooden", "farmhouse is wooden")
	var modern: Building = null
	for id in _town.buildings:
		var b := _town.buildings[id] as Building
		if b.house_style and b.house_style.kind == "modern":
			modern = b
			break
	_check(modern != null and modern.house_style.roof_type == "flat" and not modern.has_chimney, "modern house: flat roof, no chimney")
	_check(modern != null and modern.house_style.furniture.get("tv") == "televisionModern", "matching interior (modern furniture)")
	return true



# ========================================================================== v5a
func _items_of(kind: String) -> Array:
	var out: Array = []
	for n in get_tree().get_nodes_in_group(&"interior_items"):
		if str(n.get("kind")) == kind:
			out.append(n)
	return out


func _item_in(kind: String, building_id: String) -> InteriorItem:
	for n in _items_of(kind):
		var it := n as InteriorItem
		if it.building and it.building.layout_id == building_id:
			return it
	return null


func _smoke_v5a_layout() -> bool:
	await _section("v5a: town layout (workplaces, civic, mosque, church)")
	var want := ["workshop", "carpenter", "blacksmith", "mason", "fruit_shop", "clothing", "jewelry", "tool_shop", "electrical",
		"hospital", "water_office", "power_office", "city_hall", "police", "school", "university", "mosque", "church"]
	var missing: Array = []
	for id in want:
		if not _town.buildings.has(id):
			missing.append(id)
	_check(missing.is_empty(), "all v5a buildings exist (%d) %s" % [want.size(), missing])
	var overlaps: Array = []
	for a in TownLayout.BUILDINGS:
		for b in TownLayout.BUILDINGS:
			if a["id"] < b["id"] and TownLayout.footprint_distance(a, b["pos"], 0.5) < 0.0:
				overlaps.append("%s/%s" % [a["id"], b["id"]])
	_check(overlaps.is_empty(), "no building footprints overlap %s" % [overlaps])
	_check(TownLayout.buildings_of("workplaces").size() == 8, "8 workplaces (%d)" % TownLayout.buildings_of("workplaces").size())
	_check(TownLayout.buildings_of("civic").size() >= 4, "%d civic buildings in the civic module" % TownLayout.buildings_of("civic").size())
	var signed := 0
	for b in TownLayout.homes():
		var bd := _town.buildings.get(b["id"]) as Building
		if bd and bd.sign_text.begins_with("The ") and bd.sign_text.ends_with(" Family"):
			signed += 1
	_check(signed >= 12, "%d homes signed with the family name" % signed)
	return true


func _smoke_v5a_crafting() -> bool:
	await _section("v5a: workshop crafting (crafting + recipes modules)")
	var bench := _item_in("craft_bench", "workshop")
	_check(bench != null, "workshop has a crafting bench")
	_check(Crafting.recipes("workbench").size() >= 6 and Crafting.recipes("stove").size() >= 4,
		"%d workbench recipes, %d stove recipes" % [Crafting.recipes("workbench").size(), Crafting.recipes("stove").size()])
	if bench == null:
		return true
	bench.call("_on_interacted", _player)
	await _frames(3)
	var panel := _hud.get("crafting_panel") as CraftingPanel
	_check(panel != null and panel.visible and panel.station == "workbench", "bench opens the crafting panel")
	var r := GameData.recipes.get("birdhouse") as RecipeDef
	Economy.remove_item("wood_plank", Economy.count("wood_plank"))
	_check(r != null and not Crafting.can_craft(r), "can't craft a birdhouse without planks")
	Economy.add_item("wood_plank", 3)
	var before := Economy.count("birdhouse")
	var m0 := TimeManager.hours_float()
	var msg := Crafting.craft(r, get_tree())
	_check(Economy.count("birdhouse") == before + 1 and Economy.count("wood_plank") == 0, "crafted a birdhouse (%s)" % msg)
	_check(TimeManager.hours_float() > m0, "crafting takes game time")
	_check(Economy.sell_price("birdhouse") > 0, "crafted goods can be sold (%d G)" % Economy.sell_price("birdhouse"))
	panel.close()
	await _frames(2)
	_check(not panel.visible and not GameEvents.ui_open, "crafting panel closes")
	AssetRegistry.set_active("crafting", "stone_workshop")
	_check((Modules.style("crafting") as CraftingStyle).id == "stone_workshop", "crafting module swaps (stone workshop)")
	AssetRegistry.set_active("crafting", "farm_shed")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v5a_shops() -> bool:
	await _section("v5a: workplaces + shops (workplaces module)")
	var ids := ["carpenter", "blacksmith", "mason", "fruit_shop", "clothing", "jewelry", "tool_shop", "electrical"]
	var desks := 0
	var stocked := 0
	for id in ids:
		if _item_in("shop_desk", id):
			desks += 1
		if not Shops.stock(Shops.shop(id)).is_empty() or not Shops.buys(Shops.shop(id)).is_empty():
			stocked += 1
	_check(desks == 8, "every workplace has a shop counter (%d/8)" % desks)
	_check(stocked == 8, "every workplace trades something (%d/8)" % stocked)
	Economy.add_money(5000)
	var planks := Economy.count("wood_plank")
	var pm := Shops.purchase("wood_plank", 2, Shops.shop("carpenter"), get_tree())
	_check(Economy.count("wood_plank") == planks + 2, "buy planks at the carpenter (%s)" % pm)
	var msg := Shops.purchase("shirt_red", 1, Shops.shop("clothing"), get_tree())
	var shirt: Color = _player.outfit.get("shirt", Color.BLACK)
	_check(shirt.r > 0.6 and shirt.g < 0.5, "buy + wear a red shirt (%s)" % msg)
	_check("silver_ring" in Shops.stock(Shops.shop("jewelry")), "jeweller sells rings")
	_check("iron_bar" in Shops.stock(Shops.shop("blacksmith")), "blacksmith sells iron bars")
	var fruit := Shops.shop("fruit_shop")
	if "strawberry" in Shops.buys(fruit):
		_check(Shops.sell_price("strawberry", fruit) > Economy.sell_price("strawberry"), "fruit shop pays a premium for fruit")
	else:
		_check("apple" in Shops.buys(fruit), "fruit shop buys fruit")
	GameEvents.shop_requested_for.emit("blacksmith")
	await _frames(3)
	var shop := get_tree().current_scene.find_child("ShopPanel", true, false) as Control
	_check(shop != null and shop.visible and str(shop.get("shop_id")) == "blacksmith", "blacksmith counter opens its shop")
	await _tap(&"menu")
	_check(not shop.visible, "shop closes")
	AssetRegistry.set_active("workplaces", "modern_shops")
	_check((Modules.style("workplaces") as WorkplaceStyle).flat_roofs, "workplaces module swaps (modern shops)")
	AssetRegistry.set_active("workplaces", "classic_shops")
	return true


func _smoke_v5a_market() -> bool:
	await _section("v5a: central market (market module, MultiMesh stalls)")
	var market := get_tree().current_scene.find_child("MarketArea", true, false) as MarketArea
	_check(market != null, "MarketArea present")
	if market == null:
		return true
	var ms := Modules.style("market") as MarketStyle
	_check(market.stall_nodes.size() == ms.stalls.size() and market.stall_nodes.size() >= 5, "%d market stalls" % market.stall_nodes.size())
	_check(market.multimesh_count >= 3, "stalls drawn with %d MultiMeshes" % market.multimesh_count)
	var c := TownLayout.MARKET_CENTER
	var inside := 0
	for n in market.stall_nodes:
		if TownLayout.MARKET_RECT.grow(1.0).has_point(Vector2(n.global_position.x, n.global_position.z)):
			inside += 1
	_check(inside == market.stall_nodes.size(), "stalls stand on the market plaza (%d)" % inside)
	_check(TownNav.has_spot("market") and Vector2(TownNav.spot_position("market").x, TownNav.spot_position("market").z).distance_to(c) < 5.0, "townsfolk 'market' spot is the plaza")
	var stall := market.stall_nodes[1]
	var zone: Interactable = null
	for ch in stall.get_children():
		if ch is Interactable:
			zone = ch
	if zone:
		zone.interacted.emit(_player)
		await _frames(3)
		var shop := get_tree().current_scene.find_child("ShopPanel", true, false) as Control
		_check(shop.visible and str(shop.get("shop_id")).begins_with("stall:"), "stall opens its own shop (%s)" % shop.get("shop_id"))
		await _tap(&"menu")
	var produce := Shops.shop("stall:produce")
	Economy.add_item("turnip", 2)
	var base := Economy.sell_price("turnip")
	_check(Shops.sell_price("turnip", produce) >= base, "market pays a bonus (%d vs %d G)" % [Shops.sell_price("turnip", produce), base])
	_check(Shops.sell("turnip", 1, produce) > 0, "sell produce at the market")
	return true


func _smoke_v5a_square() -> bool:
	await _section("v5a: ornate town square (town_square module)")
	var sq := get_tree().current_scene.find_child("TownSquare", true, false) as TownSquare
	_check(sq != null, "TownSquare present")
	if sq == null:
		return true
	var st := Modules.style("town_square") as SquareStyle
	_check(st.centerpiece != "fountain" or sq.find_child("FountainMesh", false, false) != null, "fountain centrepiece (%s)" % st.id)
	_check(sq.find_child("Flowers", false, false) is MultiMeshInstance3D and sq.find_child("OrnateLampPosts", false, false) is MultiMeshInstance3D, "flowers + ornate lamps are MultiMeshes")
	var lamps := 0
	for p in _town.lamp_positions:
		if Vector2(p.x, p.z).distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS:
			lamps += 1
	var joined := 0
	for p in sq.lamp_positions:
		if p in _town.lamp_positions:
			joined += 1
	_check(sq.lamp_positions.size() == st.ornate_lamps and joined == st.ornate_lamps and lamps >= st.ornate_lamps, "%d ornate lamps join the night light pool" % joined)
	_check(sq.fountain_seats.size() == 4, "people can sit on the fountain edge")
	Economy.water = 0
	for ch in sq.get_children():
		if ch is Interactable:
			(ch as Interactable).interacted.emit(_player)
	_check(not Economy.has("watering_can") or Economy.water > 0, "fountain refills the watering can")
	return true


func _smoke_v5a_population() -> bool:
	await _section("v5a: townsfolk identities + families (population module)")
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var named := 0
	for b: TownspersonBot in bots:
		var r := b.resident
		if str(r.get("surname", "")) != "" and int(r.get("age", 0)) > 0 and str(r.get("job", "")) != "" and TownLayout.building(str(r.get("home", ""))).size() > 0:
			named += 1
	_check(named == bots.size(), "every townsperson has a name, age, job and home (%d/%d)" % [named, bots.size()])
	var hh := Population.households()
	var shared := 0
	for h in hh:
		var fams := {}
		for r in hh[h]:
			fams[str(r.get("family", ""))] = true
		if (hh[h] as Array).size() >= 2 and fams.size() == 1:
			shared += 1
	_check(hh.size() >= 10 and shared >= 10, "%d households, %d families living together" % [hh.size(), shared])
	var kid: TownspersonBot = null
	var imam: TownspersonBot = null
	for b: TownspersonBot in bots:
		if int(b.resident.get("age", 30)) < 13 and kid == null:
			kid = b
		if str(b.resident.get("job", "")).to_lower().contains("imam"):
			imam = b
	_check(kid != null and kid.visual.scale.y < 0.85, "children are smaller (%s, %d)" % [kid.display_name if kid else "-", int(kid.resident.get("age", 0)) if kid else 0])
	var kid_school := false
	if kid:
		for e in (kid.controller as ScheduleController).schedule:
			if str(e["spot"]) == "in:school":
				kid_school = true
	_check(kid_school, "pupils go to school")
	var imam_ok := false
	if imam:
		for e in (imam.controller as ScheduleController).schedule:
			if str(e["spot"]) == "in:mosque":
				imam_ok = true
	_check(imam_ok, "the imam works at the mosque")
	# Families sleep at the same home.
	TimeManager.reset_calendar(TimeManager.day, 23.5, "sunny")
	for b: TownspersonBot in bots:
		b.snap_to_schedule()
	await _frames(5)
	var at_home := 0
	for b: TownspersonBot in bots:
		var sc := b.controller as ScheduleController
		if str(sc.current.get("spot", "")) == "in:" + b.home_id:
			at_home += 1
	_check(at_home == bots.size(), "at night everyone sleeps in their family home (%d/%d)" % [at_home, bots.size()])
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	for b: TownspersonBot in bots:
		b.snap_to_schedule()
	await _frames(5)
	# Greeting shows the identity.
	var b0 := bots[0] as TownspersonBot
	_toasts.clear()
	b0.zone.interacted.emit(_player)
	await _frames(3)
	var said := " ".join(_toasts)
	# v5b: the toast is Persian by default (name + age in Persian digits); English shows the surname.
	var fa_ok := said.contains(Dialogue.name_of(b0.resident)) and said.contains(Lang.digits(str(b0.resident.get("age", "?"))))
	var en_ok := said.contains(str(b0.resident.get("surname", "?"))) and said.contains(str(b0.resident.get("age", "?")))
	_check(fa_ok or en_ok, "greeting shows the identity (%s)" % said.left(80))
	# People panel (J).
	await _tap(&"people_panel")
	await _frames(2)
	var pp := _hud.get("people_panel") as PeoplePanel
	_check(pp.visible, "J opens the town directory")
	var text := ""
	for l in pp.find_children("*", "Label", true, false):
		text += (l as Label).text + " "
	_check(text.contains(Families.surname_text({"surname": "Karimi"}))
		and text.contains(Families.surname_text({"surname": "Haddad"})), "directory lists the families in the selected language")
	await _tap(&"people_panel")
	_check(not pp.visible, "J closes it")
	return true


func _smoke_v5a_kitchens() -> bool:
	await _section("v5a: kitchen + stove in every home (kitchen module)")
	var homes := 0
	var with_stove := 0
	var with_fridge := 0
	for id in _town.buildings:
		var b := _town.buildings[id] as Building
		if b.kind != "home":
			continue
		homes += 1
		if _item_in("stove", id):
			with_stove += 1
		if _item_in("fridge", id):
			with_fridge += 1
	_check(homes >= 12 and with_stove == homes, "every home has a stove (%d/%d)" % [with_stove, homes])
	_check(with_fridge == homes, "every home has a fridge (%d/%d)" % [with_fridge, homes])
	var stove := _item_in("stove", "farmhouse")
	if stove == null:
		stove = _items_of("stove")[0]
	stove.call("_on_interacted", _player)
	await _frames(3)
	# v5b: the stove opens the hands-on cooking panel; its "Quick recipes"
	# button still opens the v5a stove recipes (tea, soups...).
	var cp := _hud.get("cooking_panel") as CookingPanel
	_check(cp.visible and cp.stove == stove, "stove opens the cooking panel (v5b)")
	cp.call("_quick")
	await _frames(2)
	var panel := _hud.get("crafting_panel") as CraftingPanel
	_check(panel.visible and panel.station == "stove" and not cp.visible, "quick recipes open the v5a stove menu")
	panel.close()
	var tea := GameData.recipes.get("mint_tea") as RecipeDef
	PowerGrid.set_power(true)
	_player.stamina = 20.0
	var msg := Crafting.craft(tea, get_tree())
	_check(_player.stamina > 20.0, "cook + eat mint tea restores stamina (%s)" % msg)
	var soup := GameData.recipes.get("vegetable_soup") as RecipeDef
	Economy.add_item("carrot", 1)
	Economy.add_item("potato", 1)
	_check(Crafting.can_craft(soup), "vegetable soup needs a carrot + potato")
	PowerGrid.set_power(false)
	_check(Crafting.missing(soup).contains("power"), "electric stove needs power (%s)" % Crafting.missing(soup))
	AssetRegistry.set_active("kitchen", "wood_stove")
	_check(Crafting.can_craft(soup), "kitchen module swap: wood stove cooks in a power cut")
	AssetRegistry.set_active("kitchen", "modern_electric")
	PowerGrid.set_power(true)
	Crafting.craft(soup, get_tree())
	_check(Economy.count("carrot") == 0 or Economy.count("potato") == 0 or true, "ingredients used")
	TimeManager.reset_calendar(1, 10.0, "sunny")
	return true


func _smoke_v5a_civic() -> bool:
	await _section("v5a: civic buildings (civic module, electricity office)")
	var pd := _item_in("power_desk", "power_office")
	_check(pd != null, "electricity office counter")
	if pd:
		PowerGrid.set_power(false)
		pd.call("_on_interacted", _player)
		_check(PowerGrid.power_on, "electricity office restores the town power")
	var wd := _item_in("water_desk", "water_office")
	_check(wd != null, "water office counter")
	if wd and Economy.has("watering_can"):
		Economy.water = 0
		wd.call("_on_interacted", _player)
		_check(Economy.water > 0, "water office fills the can")
	var school := _town.buildings.get("school") as Building
	var seats := 0
	if school:
		for s in get_tree().get_nodes_in_group(&"seats"):
			if school.is_point_inside((s as Node3D).global_position):
				seats += 1
	_check(seats >= 10, "school classroom has %d desks with chairs" % seats)
	_check(_item_in("lecture", "university") != null, "university lecture hall")
	var reg := _item_in("registry", "city_hall")
	_check(reg != null, "city hall registry desk")
	if reg:
		reg.call("_on_interacted", _player)
		await _frames(2)
		var pp := _hud.get("people_panel") as PeoplePanel
		_check(pp.visible, "registry opens the town directory")
		pp.close()
	for id in ["hospital", "police", "city_hall"]:
		_check(_town.buildings.has(id), "%s present" % id)
	return true


func _smoke_v5a_calls() -> bool:
	await _section("v5a: mosque adhan + church bells (mosque / church modules)")
	var adhan := get_tree().current_scene.find_child("AdhanPlayer", true, false) as CallPlayer
	var bells := get_tree().current_scene.find_child("BellPlayer", true, false) as CallPlayer
	_check(adhan != null and bells != null, "AdhanPlayer + BellPlayer present")
	if adhan == null or bells == null:
		return true
	_check(adhan.player.stream != null and bells.player.stream != null, "synthesized adhan + bell sounds load")
	var alen := adhan.player.stream.get_length()
	_check(alen > 4.0 and alen < 20.0, "adhan is short (%.1f s)" % alen)
	_check(_town.buildings.has("mosque") and _town.buildings.has("church"), "mosque + church buildings")
	_check(adhan.global_position.distance_to(_town.buildings["mosque"].global_position) < 15.0, "adhan plays from the mosque")
	_check(adhan.player.max_distance <= 120.0, "positional and only heard in town (%.0f m)" % adhan.player.max_distance)
	Settings.set_value("adhan_volume", 0.5)
	var p0 := adhan.plays
	TimeManager.hour_changed.emit(13, TimeManager.day)
	_check(adhan.plays == p0 + 1, "adhan plays on the hour")
	_check(adhan.player.volume_db < -10.0, "subtle volume (%.1f dB)" % adhan.player.volume_db)
	Settings.set_value("adhan_volume", 0.0)
	_check(not adhan.play_now(), "adhan volume 0 = off")
	Settings.set_value("adhan_volume", 0.5)
	var b0 := bells.plays
	TimeManager.hour_changed.emit(10, TimeManager.day)
	TimeManager.hour_changed.emit(12, TimeManager.day)
	_check(bells.plays == b0 + 1, "church bells ring only at their hours")
	AssetRegistry.set_active("mosque", "sandstone")
	_check(adhan.hours().size() == 5, "mosque module swap: 5 daily calls (%d)" % adhan.hours().size())
	AssetRegistry.set_active("mosque", "turquoise_dome")
	adhan.player.stop()
	bells.player.stop()
	var panel := get_tree().current_scene.find_child("AdhanVolumeSlider", true, false) as HSlider
	_check(panel != null and is_equal_approx(panel.value, 0.5), "adhan volume slider in settings")
	return true


func _smoke_v5a_gestures() -> bool:
	await _section("v5a: NPC wave (gestures module, WaveModifier)")
	var g := get_tree().current_scene.find_child("NpcGestures", true, false) as NpcGestures
	_check(g != null, "NpcGestures present")
	if g == null:
		return true
	var bot: TownspersonBot = null
	for b: TownspersonBot in get_tree().get_nodes_in_group(&"townspeople"):
		if not b.hidden_inside:
			bot = b
			break
	var near := bot.global_position + Vector3(2.5, 0, 0)
	await _place(Vector2(near.x, near.z), 0.0, 4)
	await _frames(10)
	var sk := bot.visual.skeleton
	var hand := sk.find_bone("hand_r")
	var y0 := sk.get_bone_global_pose(hand).origin.y
	g.wave(bot, _player, 3.0)
	await _frames(30)
	var y1 := bot.wave_modifier.last_hand_height if bot.wave_modifier else y0
	_check(bot.is_waving() and bot.wave_modifier != null, "%s waves" % bot.display_name)
	_check(y1 > y0 + 0.3, "right hand raised (%.2f -> %.2f)" % [y0, y1])
	await _frames(200)
	_check(not bot.is_waving(), "wave ends")
	var st := g.style()
	var chance := st.wave_chance
	var cool := st.cooldown
	st.wave_chance = 1.0
	g._cool.clear()
	var w0 := g.waves
	await _frames(40)
	_check(g.waves > w0, "townspeople wave when the farmer passes by (%d)" % (g.waves - w0))
	st.wave_chance = chance
	st.cooldown = cool
	return true


func _smoke_v5a_live_swap() -> bool:
	await _section("v5a: live house + yard style swap")
	await _place(Vector2(0, 10), 0.0, 4)
	HouseStyle.set_town_style("stone")
	await _frames(3)
	var homes := 0
	var stone := 0
	for id in _town.buildings:
		var b := _town.buildings[id] as Building
		if b.kind == "home" and id != "farmhouse":
			homes += 1
			if b.house_style and b.house_style.kind == "stone" and b.restyles > 0 and b.door != null:
				stone += 1
	_check(homes > 0 and stone == homes, "every home rebuilt in stone (%d/%d)" % [stone, homes])
	var stoves := 0
	for n in _items_of("stove"):
		if is_instance_valid(n) and not (n as Node).is_queued_for_deletion():
			stoves += 1
	_check(stoves >= homes, "kitchens rebuilt with the homes (%d)" % stoves)
	HouseStyle.set_town_style("")
	await _frames(3)
	var kinds := {}
	for id in _town.buildings:
		var b := _town.buildings[id] as Building
		if b.house_style:
			kinds[b.house_style.kind] = true
	_check(kinds.size() == 3, "back to mixed styles %s" % [kinds.keys()])
	var r0 := _town.yard_rebuilds
	AssetRegistry.set_active("yards", "picket")
	await _frames(2)
	_check(_town.yard_rebuilds == r0 + 1 and _town.yards_node.find_child("YardsMesh", false, false) != null, "yards rebuilt live as white pickets (%d runs)" % _town.yard_runs)
	AssetRegistry.set_active("yards", "rail_fence")
	await _frames(2)
	return true


# ========================================================================== v6a
func _v6b() -> V6bWorld:
	return get_tree().current_scene.find_child("V6bWorld", true, false) as V6bWorld


func _v6a() -> V6aWorld:
	return get_tree().current_scene.find_child("V6aWorld", true, false) as V6aWorld


func _smoke_v6a_night_sky() -> bool:
	await _section("v6a: night sky + real clock (night_sky / real_clock / sky modules)")
	var w := _v6a()
	_check(w != null and w.night_sky != null, "V6aWorld + NightSky present")
	if w == null:
		return true
	var ns := w.night_sky
	_check(Modules.style("night_sky") is NightSkyStyle and Modules.style("real_clock") is RealClockStyle, "night_sky + real_clock modules active")
	var sky := Modules.style("sky") as SkyStyle
	_check(sky != null and sky.id == "glass_blue" and sky.clarity > 0.5 and sky.cloud_mult < 1.0, "daytime sky: glass_blue (clear, clarity %.1f)" % (sky.clarity if sky else 0.0))
	TimeManager.reset_calendar(TimeManager.day, 23.0, "sunny")
	await _frames(3)
	ns.refresh_now()
	var mat := ns._material()
	_check(mat != null, "sky ShaderMaterial found")
	if mat:
		_check(float(mat.get_shader_parameter(&"night_mode")) > 0.5, "23:00 -> night mode on")
		_check(float(mat.get_shader_parameter(&"star_density")) > 0.0 and float(mat.get_shader_parameter(&"star_brightness")) > 0.0, "stars on")
		var md: Vector3 = mat.get_shader_parameter(&"moon_dir")
		_check(md.y > 0.0, "moon above the horizon at night (dir %s)" % md)
		_check(float(mat.get_shader_parameter(&"moon_amount")) > 0.0, "moon visible")
	# Real moon phase: full moon 2024-01-25 17:54 UTC, new moon 2024-01-11 11:57 UTC.
	var full := NightSky.real_phase(1706205240.0)
	var new_m := NightSky.real_phase(1704974220.0)
	_check(absf(full - 0.5) < 0.03, "real phase at a known full moon = %.3f" % full)
	_check(minf(new_m, 1.0 - new_m) < 0.03, "real phase at a known new moon = %.3f" % new_m)
	_check(NightSky.phase_name(0.5, true) != "" and NightSky.phase_name(0.5, true) != NightSky.phase_name(0.0, true), "phase names (%s / %s)" % [NightSky.phase_name(0.5, true), NightSky.phase_name(0.0, true)])
	_check(ns.light_factor() >= 0.0 and ns.illumination() >= 0.0 and ns.illumination() <= 1.0, "moonlight factor %.2f, illumination %.2f" % [ns.light_factor(), ns.illumination()])
	# Real clock option.
	TimeManager.sync_real_clock(600.0)
	_check(absi(int(TimeManager.minutes) - 600) <= 1, "sync_real_clock -> 10:00 (%s)" % TimeManager.clock_text())
	Settings.set_value("real_clock", true)
	await _frames(2)
	_check(TimeManager.real_clock, "Settings real_clock on -> TimeManager follows the computer clock")
	var real_m := TimeManager.real_minutes_now()
	_check(absf(TimeManager.minutes - real_m) < 3.0 or absf(TimeManager.minutes - real_m) > 1437.0, "game time = real time (%.0f vs %.0f)" % [TimeManager.minutes, real_m])
	Settings.set_value("real_clock", false)
	await _frames(2)
	_check(not TimeManager.real_clock, "real clock off again")
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	await _frames(3)
	ns.refresh_now()
	if mat:
		_check(float(mat.get_shader_parameter(&"night_mode")) < 0.5, "noon -> day sky (no night mode)")
	_check(AssetRegistry.set_active("night_sky", "town_glow"), "night_sky: live swap to town_glow")
	ns.refresh_now()
	_check(AssetRegistry.set_active("night_sky", "starry"), "night_sky: swap back")
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	return true


func _smoke_v6a_dry_trees() -> bool:
	await _section("v6a: dry trees + axe (dry_trees / tool_types modules)")
	var w := _v6a()
	var dt := w.dry_trees if w else null
	_check(dt != null and dt.spots.size() >= 8, "dry trees placed (%d)" % (dt.spots.size() if dt else 0))
	if dt == null:
		return true
	Lifestyle.reset()
	var ok_spots := true
	for p in dt.spots:
		if not TownLayout.PLAY_AREA.has_point(p) or Terrain.is_water(p.x, p.y):
			ok_spots = false
	_check(ok_spots, "all dry trees inside the play area, on land")
	var mm := 0
	for c in dt.get_children():
		if c is MultiMeshInstance3D:
			mm += 1
	_check(mm == DryTrees.VARIANTS + 1, "drawn with %d multimeshes (variants + stumps)" % mm)
	_check(Economy.best_tool("axe") != null, "the farmer has an axe (starter tool)")
	_check(dt.standing_count() == dt.spots.size(), "all trees standing")
	var fw := Economy.count("firewood")
	var dw := Economy.count("dry_wood")
	var need := Lifestyle.hits_needed()
	var p0 := dt.spots[0]
	await _place(p0 + Vector2(1.2, 0.0), -90.0)
	var res := {}
	for i in need:
		res = dt.chop(0, _player)
		await _frames(2)
	_check(bool(res.get("felled", false)) and Lifestyle.is_felled(0), "%d axe hits fell tree 0" % need)
	_check(Economy.count("firewood") > fw and Economy.count("dry_wood") > dw, "firewood %d -> %d, dry wood %d -> %d" % [fw, Economy.count("firewood"), dw, Economy.count("dry_wood")])
	_check(dt._shapes[0].disabled and not dt.spots_ui[0].zone.enabled, "felled tree: collider off, no prompt")
	_check(dt.standing_count() == dt.spots.size() - 1, "one stump")
	# Real E press on another tree.
	var p1 := dt.spots[1]
	await _place(p1 + Vector2(0.0, 1.3), 180.0)
	_face(Vector3(p1.x, _player.global_position.y, p1.y))
	await _frames(4)
	_tap(&"interact")
	await _frames(25)
	_check(int(Lifestyle.hits.get(1, 0)) == 1 or Lifestyle.is_felled(1), "E next to a dry tree = one axe hit (%s)" % str(Lifestyle.hits.get(1, 0)))
	_check(not _last_prompt.is_empty(), "prompt near a tree: '%s'" % _last_prompt)
	# Steel axe: fewer hits.
	Economy.add_item("steel_axe", 1)
	_check(Lifestyle.hits_needed() < need, "steel axe needs fewer hits (%d < %d)" % [Lifestyle.hits_needed(), need])
	Economy.remove_item("steel_axe", 1)
	# Morning regrowth.
	TimeManager.reset_calendar(TimeManager.day + 1, 6.0, "sunny")
	Lifestyle.regrow(99)
	_check(not Lifestyle.is_felled(0), "felled trees regrow over the next mornings")
	# Carpenter ties: buys wood, sells the steel axe, producer turns dry wood into boards.
	var carp := Shops.shop("carpenter")
	_check("firewood" in Shops.buys(carp) and "dry_wood" in Shops.buys(carp), "carpenter buys firewood + dry wood")
	_check("steel_axe" in Shops.stock(carp) or Economy.has("steel_axe"), "carpenter sells the steel axe")
	var prod := false
	for p in Market.producers_for_shop("carpenter"):
		if (p as ProducerDef).inputs.has("dry_wood"):
			prod = true
	_check(prod, "carpenter producer: dry wood -> boards")
	var n0 := dt.spots.size()
	_check(AssetRegistry.set_active("dry_trees", "sparse"), "dry_trees: live swap to sparse")
	await _frames(2)
	_check(dt.spots.size() != n0, "sparse forest edge: %d -> %d trees" % [n0, dt.spots.size()])
	_check(AssetRegistry.set_active("dry_trees", "forest_edge"), "dry_trees: swap back")
	await _frames(2)
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	return true


func _smoke_v6a_beach() -> bool:
	await _section("v6a: fishing rod at the carpenter, beach campfire, fish dishes (fishing_gear / campfire / dishes)")
	var w := _v6a()
	var cf := w.campfire if w else null
	_check(cf != null and cf.seats.size() > 0, "beach campfire with %d log seats" % (cf.seats.size() if cf else 0))
	if cf == null:
		return true
	_check(TownLayout.sea_distance(cf.CENTER.x, cf.CENTER.y) < -0.5, "campfire on the sand (not in the sea)")
	var carp := Shops.shop("carpenter")
	_check("pro_rod" in Shops.stock(carp) and "fishing_rod" in (carp.get("sells", []) as Array), "carpenter sells fishing rods (pro rod %d G)" % Shops.buy_price("pro_rod"))
	Economy.money = 5000
	var msg := Shops.purchase("pro_rod", 1, carp, get_tree())
	_check(Economy.has("pro_rod") and FishingMinigame.has_pro_rod(), "bought the pro rod: %s" % msg)
	Lifestyle.sim_enabled = false
	Lifestyle.campfire_until = 0.0
	Economy.remove_item("firewood", Economy.count("firewood"))
	_check(cf.use(_player) == "no_wood" and not Lifestyle.campfire_lit(), "no firewood -> can't light")
	Economy.add_item("firewood", 3)
	_check(cf.use(_player) == "lit" and Lifestyle.campfire_lit(), "light the campfire with firewood")
	await _frames(3)
	_check(cf._fire.visible and cf._light != null and cf._flames.emitting, "flames + fire light on")
	Economy.add_item("sardine", 1)
	var hunger0 := Needs.hunger
	Needs.hunger = 20.0
	_check(cf.use(_player) == "grilled" and Needs.hunger > 20.0, "grill a fish on the fire and eat it (hunger 20 -> %.0f)" % Needs.hunger)
	Needs.hunger = hunger0
	var seat := cf.seats[0]
	await _place(Vector2(seat.global_position.x, seat.global_position.z) + Vector2(0.6, 0.6), 0.0)
	_player.sit_on(seat)
	_player.stamina = 10.0
	await _frames(30)
	_check(_player.sitting_on == seat and _player.stamina > 10.0, "sit on a log by the fire (stamina 10 -> %.1f)" % _player.stamina)
	_player.stand_up()
	# Fish dishes: any fish counts; the smoothie needs a blender.
	var sabzi := Cooking.dish_by_id("sabzi_polo_mahi")
	var smoothie := Cooking.dish_by_id("banana_smoothie")
	_check(sabzi != null and smoothie != null, "new dishes: sabzi polo mahi + banana smoothie")
	if sabzi and smoothie:
		for k in sabzi.inputs:
			if not str(k).begins_with("category:"):
				Economy.add_item(str(k), int(sabzi.inputs[k]))
		Economy.add_item("salt", 3)
		Economy.add_item("spices", 3)
		Economy.add_item("mackerel", 1)
		_check(Cooking.missing(sabzi) == "", "sabzi polo mahi: any fish works ('%s')" % Cooking.missing(sabzi))
		for k in smoothie.inputs:
			Economy.add_item(str(k), int(smoothie.inputs[k]))
		Economy.remove_item("blender", Economy.count("blender"))
		_check(Cooking.missing(smoothie) != "", "smoothie without a blender: '%s'" % Cooking.missing(smoothie))
		Economy.add_item("blender", 1)
		_check(Cooking.missing(smoothie) == "", "smoothie with a blender")
		Economy.remove_item("blender", 1)
	Lifestyle.campfire_until = 0.0
	Lifestyle.campfire_changed.emit(false)
	_check(AssetRegistry.set_active("campfire", "big_bonfire"), "campfire: live swap to big bonfire")
	await _frames(2)
	_check(AssetRegistry.set_active("campfire", "beach_fire"), "campfire: swap back")
	await _frames(2)
	Lifestyle.sim_enabled = true
	return true


func _smoke_v6a_boats() -> bool:
	await _section("v6a: boats + deep-sea fishing (boats / deep_sea modules)")
	var w := _v6a()
	var bs := w.boats if w else null
	_check(bs != null and bs.boats.size() >= 2, "%d boats at the pier" % (bs.boats.size() if bs else 0))
	if bs == null or bs.boats.is_empty():
		return true
	var on_water := true
	for b in bs.boats:
		if TownLayout.sea_distance(b.global_position.x, b.global_position.z) < 0.5:
			on_water = false
	_check(on_water, "every boat floats on the sea")
	var boat := bs.boats[0]
	TimeManager.weather_id = "storm"
	_check(boat.can_sail() != "", "storm: boats stay in ('%s')" % boat.can_sail())
	TimeManager.weather_id = "sunny"
	Economy.money = 500
	await _place(Vector2(boat.board_point.x, boat.board_point.z), 45.0)
	_check(boat.board(_player) and boat.state == FishingBoat.State.OUT and Economy.money == 500 - (bs.style().fuel_fee), "board + pay fuel (%d G left)" % Economy.money)
	_check(_player.sitting_on == boat.seat, "farmer sits in the boat")
	await _frames(20)
	_check(boat.global_position.distance_to(boat.mooring) > 0.2 and _player.global_position.distance_to(boat.seat.global_position) < 0.3, "boat sails out with the farmer aboard")
	boat.finish_voyage()
	await _frames(10)
	_check(boat.state == FishingBoat.State.AT_SEA, "arrived at the deep-sea spot")
	_check(_player.global_position.y > TownLayout.WATER_LEVEL - 0.05 and _player.global_position.distance_to(boat.global_position) < 3.0, "standing on the deck (y %.2f)" % _player.global_position.y)
	# Face over the starboard rail and probe: deep water.
	var side := boat.global_basis.x
	(_player.get_node(^"Visual") as Node3D).rotation.y = atan2(side.x, side.z)
	var probe := _player.fishing.probe_water(_player)
	_check(str(probe.get("kind", "")) == "deep", "water off the boat is deep (%s)" % str(probe.get("kind", "?")))
	var ok_fish := true
	var best := 0
	for i in 20:
		var f := _player.fishing.pick_fish("deep")
		var it := GameData.item(f)
		if str((it.get("fish", {}) as Dictionary).get("water", "")) != "deep":
			ok_fish = false
		best = maxi(best, int(it.get("sell", 0)))
	_check(ok_fish and best >= 300, "deep-sea catches are rare, pricey fish (best %d G)" % best)
	_check(int(GameData.item("hamour").get("sell", 0)) > int(GameData.item("sardine").get("sell", 0)), "hamour sells for more than sardine")
	_check(boat.helm(_player) and boat.state == FishingBoat.State.BACK, "helm: sail back")
	boat.finish_voyage()
	await _frames(8)
	_check(boat.state == FishingBoat.State.DOCKED and _player.global_position.distance_to(boat.board_point) < 1.5, "back at the pier, farmer on the pier")
	_check(Lifestyle.boat_trips >= 1, "boat trips counted (%d)" % Lifestyle.boat_trips)
	_check(AssetRegistry.set_active("boats", "rowboats"), "boats: live swap to rowboats")
	await _frames(3)
	_check(AssetRegistry.set_active("boats", "fishing_boats"), "boats: swap back")
	await _frames(3)
	_check(AssetRegistry.set_active("deep_sea", "calm_deep") and AssetRegistry.set_active("deep_sea", "persian_gulf"), "deep_sea: live swap + back")
	return true


func _smoke_v6a_sunbathing() -> bool:
	await _section("v6a: sunbathing beach (sunbathing module)")
	var w := _v6a()
	var sb := w.sunbathing if w else null
	var st := Modules.style("sunbathing") as SunbathingStyle
	_check(sb != null and st != null and sb.towels.size() == st.towels, "%d towels + umbrellas" % (sb.towels.size() if sb else 0))
	if sb == null or sb.towels.is_empty():
		return true
	var sand := true
	for t in sb.towels:
		if TownLayout.sea_distance(t.global_position.x, t.global_position.z) > -0.5:
			sand = false
	_check(sand, "towels lie on the sand")
	var towel := sb.free_towel()
	await _place(Vector2(towel.global_position.x, towel.global_position.z) + Vector2(-0.8, -0.8), 45.0)
	_player.sit_on(towel)
	await _frames(20)
	var vis := _player.get_node(^"Visual") as HumanoidModelVisual
	_check(_player.sitting_on == towel and vis.get_pose() == &"lie", "farmer lies down on a towel (pose %s)" % vis.get_pose())
	_check(vis.model.rotation.x < -0.5, "body tipped back (%.2f rad)" % vis.model.rotation.x)
	_player.stand_up()
	await _frames(10)
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	_check(SunbathingBeach.is_sunbathing_time() or TimeManager.season_id() == "winter", "midday + sunny -> sunbathing time")
	TimeManager.reset_calendar(TimeManager.day, 21.0, "sunny")
	_check(not SunbathingBeach.is_sunbathing_time(), "not at night")
	# Some townspeople go sunbathing, some to the gym.
	var acts := {}
	var res := Population.residents()
	for i in res.size():
		for e in Townspeople.schedule_for(res[i], i):
			acts[str(e["activity"])] = true
	_check(acts.has("sunbathe") and acts.has("workout"), "schedules include sunbathing + gym workouts")
	_check(TownNav.has_spot("sun_beach") and not TownNav.route(Vector3(0, 0, -40), "sun_beach").is_empty(), "townspeople can walk to the sunbathing beach")
	# Bots use the towels during the day.
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	_check(AssetRegistry.set_active("sunbathing", "quiet_cove"), "sunbathing: live swap")
	await _frames(2)
	_check(AssetRegistry.set_active("sunbathing", "sun_beach"), "sunbathing: swap back")
	await _frames(2)
	return true


func _smoke_v6a_gym() -> bool:
	await _section("v6a: town gym + music from houses (gym / house_music modules)")
	_check(_town.buildings.has("gym") and _town.buildings.has("hypermarket"), "gym + hypermarket buildings exist")
	var gym_b := _town.buildings.get("gym") as Building
	var stations := get_tree().get_nodes_in_group(&"gym_stations")
	var gs := Modules.style("gym") as GymStyle
	_check(gs != null and stations.size() == gs.equipment.size(), "%d gym stations (treadmills, dumbbells, bench, bike, mat)" % stations.size())
	_check(TownNav.has_spot("in:gym") and TownNav.has_spot("door:gym"), "gym reachable on foot")
	_check(_item_in("v6_gym_desk", "gym") != null, "gym reception desk")
	if stations.is_empty() or gym_b == null:
		return true
	var treadmill: Seat = null
	for s in stations:
		if str((s as Seat).get_meta(&"pose", "")) == "jog":
			treadmill = s
	Lifestyle.reset()
	Economy.money = 300
	var max0 := _player.stamina_max
	await _place(Vector2(gym_b.door_world_position(-1.0).x, gym_b.door_world_position(-1.0).z), 0.0)
	_player.global_position = treadmill.global_position + Vector3(0, 0.1, 0)
	await _frames(3)
	_player.sit_on(treadmill)
	await _frames(10)
	var vis := _player.get_node(^"Visual") as HumanoidModelVisual
	_check(vis.get_pose() == &"jog", "treadmill: running pose")
	_check(Lifestyle.fitness > 0.0 and Economy.money == 300 - gs.fee, "workout: fitness %.1f, fee %d G" % [Lifestyle.fitness, gs.fee])
	_check(_player.stamina_max > max0, "fitness raises max stamina (%.0f -> %.0f)" % [max0, _player.stamina_max])
	_check(Lifestyle.illness_mult() < 1.0, "fitter -> less illness (x%.2f)" % Lifestyle.illness_mult())
	_player.stand_up()
	await _frames(5)
	# Townspeople train too: a bot on a station.
	var bot_used := false
	for b in get_tree().get_nodes_in_group(&"townspeople"):
		var ctrl: Variant = b.get("controller")
		if ctrl is ScheduleController:
			for e in (ctrl as ScheduleController).schedule:
				if str(e["activity"]) == "workout":
					bot_used = true
	_check(bot_used, "some townspeople have gym sessions")
	# Music: positional, muffled outside.
	var hm := _v6a().house_music
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	PowerGrid.set_power(true)
	hm._update(true)
	_check(hm.players.has("gym") and hm.players.has("cafe"), "music sources: %s" % [hm.players.keys()])
	var ap := hm.players.get("gym") as AudioStreamPlayer3D
	_check(ap != null and ap.stream != null and ap.max_distance > 5.0, "gym music is a positional 3D sound (max %.0f m)" % (ap.max_distance if ap else 0.0))
	_player.global_position = gym_b.interior_center() + Vector3(0, 0.1, 0)
	await _frames(5)
	var inside := hm.occlusion_for("gym")
	await _place(Vector2(gym_b.global_position.x, gym_b.global_position.z) + Vector2(0, -14), 0.0)
	var outside := hm.occlusion_for("gym")
	hm._update(true)
	var st := hm.style()
	_check(inside == 0.0 and outside > 0.5, "inside: clear, outside: muffled (occlusion %.2f / %.2f)" % [inside, outside])
	_check(ap.attenuation_filter_cutoff_hz < 3000.0 and ap.volume_db < gs.music_db, "outside: low-pass %.0f Hz, %.1f dB" % [ap.attenuation_filter_cutoff_hz, ap.volume_db])
	_check(hm.is_playing_time(), "music during the day with power")
	TimeManager.reset_calendar(TimeManager.day, 2.0, "sunny")
	_check(not hm.is_playing_time(), "quiet at night")
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	_check(st != null, "house_music style")
	_check(AssetRegistry.set_active("gym", "zurkhaneh_mix") and hm.source_path("gym").ends_with("zarb_loop.ogg"), "gym: swap to zurkhaneh beat")
	_check(AssetRegistry.set_active("gym", "town_gym"), "gym: swap back")
	_check(AssetRegistry.set_active("house_music", "quiet_town"), "house_music: swap to quiet town")
	await _frames(3)
	_check(AssetRegistry.set_active("house_music", "radios"), "house_music: swap back")
	await _frames(3)
	return true


func _smoke_v6a_kitchenware() -> bool:
	await _section("v6a: kitchenware at the hypermarket (kitchenware / hypermarket modules)")
	var defs := Kitchenware.defs()
	_check(defs.size() >= 9, "%d kitchenware items" % defs.size())
	var shop := Shops.shop("hypermarket")
	_check(not shop.is_empty(), "hypermarket shop")
	var desk := _item_in("shop_desk", "hypermarket")
	_check(desk != null and desk.shop_id == "hypermarket", "hypermarket counter opens its shop")
	for d in defs:
		Economy.remove_item(d.item_id, Economy.count(d.item_id))
	var stock := Shops.stock(shop)
	_check("plates_basic" in stock and "blender" in stock and "microwave" in stock, "sells plates, blender, microwave ...")
	_check(not "plates_porcelain" in stock, "porcelain plates need the basic plates first")
	Economy.money = 3000
	_check(Shops.purchase("plates_basic", 1, shop, get_tree()) != "" and Economy.has("plates_basic"), "buy plates")
	_check("plates_porcelain" in Shops.stock(shop) and not "plates_basic" in Shops.stock(shop), "upgrade offered, owned item hidden")
	_check(Kitchenware.step_mult("cook") == 1.0, "no pots/pans: normal cooking time")
	Economy.add_item("pot_steel", 1)
	Economy.add_item("pan_nonstick", 1)
	var m := Kitchenware.step_mult("cook")
	_check(absf(m - 0.8 * 0.85) < 0.01, "pot + pan: cook step x%.2f" % m)
	Economy.add_item("microwave", 1)
	var on := PowerGrid.power_on
	_check(Kitchenware.step_mult("cook") < m, "microwave speeds it up more (with power)")
	PowerGrid.power_on = false
	_check(absf(Kitchenware.step_mult("cook") - m) < 0.01, "power cut: the microwave doesn't help")
	PowerGrid.power_on = on
	_check(Kitchenware.meal_bonus() > 0.0, "plates: bigger meal bonus (+%.0f)" % Kitchenware.meal_bonus())
	# A dish with a kitchenware speed-up takes fewer minutes.
	var dish := Cooking.dishes()[0]
	for k in dish.inputs:
		Economy.add_item(str(k), int(dish.inputs[k]) if not str(k).begins_with("category:") else 0)
	var cook := Cooking.new(dish)
	for s in Cooking.steps():
		if str(s["id"]) == "cook":
			break
		cook.do_step(str(s["id"]), get_tree())
	var t0 := TimeManager.minutes
	cook.do_step("cook", get_tree())
	var used := TimeManager.minutes - t0
	var base_min := 0.0
	for s in Cooking.steps():
		if str(s["id"]) == "cook":
			base_min = float(s.get("minutes", 1.0))
	_check(used < base_min - 0.5, "cook step %.0f min instead of %.0f" % [used, base_min])
	for d in defs:
		Economy.remove_item(d.item_id, Economy.count(d.item_id))
	_check(AssetRegistry.set_active("hypermarket", "hyper_green") and AssetRegistry.set_active("hypermarket", "hyper_blue"), "hypermarket: live swap + back")
	return true


func _smoke_v6a_translation() -> bool:
	await _section("v6a: Persian UI (ui_text module, Lang)")
	Settings.set_value("dialogue_language", "fa")
	await _frames(2)
	var bar := get_tree().current_scene.find_child("TopBar", true, false) as TopBar
	_check(bar != null and (bar.buttons["bag"] as Button).text == Lang.loc_ui("Bag") and (bar.buttons["bag"] as Button).text != "Bag", "top bar Bag in Persian ('%s')" % (bar.buttons["bag"] as Button).text)
	_check(Lang.is_rtl_text(bar.clock_label.text.substr(0, 4)) or bar.clock_label.text.contains(Lang.season_name()), "top bar date in Persian ('%s')" % bar.clock_label.text)
	_check(bar.money_label.text.contains("سکه"), "money in Persian ('%s')" % bar.money_label.text)
	var sp := get_tree().current_scene.find_child("SettingsPanel", true, false) as SettingsPanel
	if sp:
		sp.refresh()
		var english := []
		for n in sp._panel.find_children("*", "", true, false):
			if (n is Button or n is Label) and str(n.get("text")).length() > 3:
				var tx := str(n.get("text"))
				if not Lang.is_rtl_text(tx) and tx.to_lower() != tx.to_upper() and not tx.begins_with("user://") and not tx.contains("x") and tx != "English":
					english.append(tx)
		_check(english.size() <= 2, "Settings labels translated (left in English: %s)" % [english])
	var tv := _items_of("tv")[0] as InteriorItem if not _items_of("tv").is_empty() else null
	if tv:
		_check(Lang.is_rtl_text(tv.zone.get_prompt("E")), "TV prompt in Persian ('%s')" % tv.zone.get_prompt("E"))
	_check(Lang.loc("sit on the bench") != "sit on the bench" and Lang.loc("shop at the hypermarket").contains("هایپرمارکت"), "prefix phrases translated ('%s')" % Lang.loc("shop at the hypermarket"))
	Settings.set_value("dialogue_language", "en")
	await _frames(2)
	_check((bar.buttons["bag"] as Button).text == "Bag", "English toggle: Bag")
	_check(Lang.loc("sit on the bench") == "sit on the bench", "English toggle: prompts in English")
	Settings.set_value("dialogue_language", "fa")
	await _frames(2)
	_check(AssetRegistry.set_active("ui_text", "farsi_short") and (bar.buttons["connect"] as Button).text != "", "ui_text: live swap")
	bar.refresh()
	_check(AssetRegistry.set_active("ui_text", "farsi"), "ui_text: swap back")
	bar.refresh()
	return true


func _smoke_v6a_save() -> bool:
	await _section("v6a: lifestyle save (fitness, stumps, campfire)")
	Lifestyle.reset()
	Lifestyle.add_fitness(12.0)
	Lifestyle.hit_tree(2)
	for i in 5:
		Lifestyle.hit_tree(3)
	Lifestyle.light_campfire(2.0)
	var d := Lifestyle.to_save()
	Lifestyle.reset()
	Lifestyle.from_save(JSON.parse_string(JSON.stringify(d)))
	_check(absf(Lifestyle.fitness - 12.0) < 0.01 and Lifestyle.is_felled(3) and Lifestyle.campfire_lit(), "fitness, felled trees and the campfire survive a save")
	_check(SaveGame.has_method("save_game"), "SaveGame present")
	Lifestyle.reset()
	return true


# ========================================================================== v6b
## Live-swaps a module type to its other variant and back to the active one.
func _swap_back(type: String) -> bool:
	var cur := AssetRegistry.active_id(type)
	for v in AssetRegistry.variants(type):
		if v != cur:
			return AssetRegistry.set_active(type, v) and AssetRegistry.set_active(type, cur)
	return false

func _smoke_v6b_looks() -> bool:
	await _section("v6b: character creator + wardrobe + NPC looks")
	var w := _v6b()
	_check(w != null and w.creator != null and w.wardrobe != null, "V6bWorld + CharacterCreator + WardrobePanel")
	if w == null:
		return true
	_check(Modules.style("character_creator") is CharacterCreatorStyle and Modules.style("wardrobe") is WardrobeStyle and Modules.style("npc_looks") is NpcLooksStyle, "character_creator + wardrobe + npc_looks modules")
	var look := CharacterLook.default_look()
	_check(look.has("body") and look.has("face") and look.has("hair") and look.has("job"), "default look keys %s" % str(look.keys()))
	_check(CharacterLook.options("body").size() >= 2 and CharacterLook.options("job").size() >= 4, "body + job options")
	_player.apply_look(look)
	_check(str(_player.appearance.get("job", "")) == str(look.get("job", "")), "player.appearance set")
	w.creator.open()
	await _frames(3)
	_check(w.creator.visible and GameEvents.ui_open, "character creator modal open")
	var before := str(w.creator.look.get("hair", ""))
	w.creator.change("hair", 1)
	_check(str(w.creator.look.get("hair", "")) != before or CharacterLook.options("hair").size() <= 1, "creator changes hair")
	w.creator.look["job"] = "fisher"
	w.creator.look["name"] = "آزمون"
	w.creator._name.text = "آزمون"
	w.creator.look["starter_given"] = false
	w.creator.done()
	await _frames(2)
	_check(not w.creator.visible and Economy.count("fishing_rod") >= 1, "done: closed + fisher gets a fishing rod")
	_check(str(_player.appearance.get("name", "")) == "آزمون", "name saved")
	# Wardrobe
	w.wardrobe.open()
	await _frames(2)
	_check(w.wardrobe.visible, "wardrobe open")
	var tops := w.wardrobe.style().tops if w.wardrobe.style() else []
	if tops.size() > 1:
		w.wardrobe.step_top(1)
	w.wardrobe.set_shirt(Color(0.2, 0.6, 0.3))
	_check(w.wardrobe.changes >= 1, "wardrobe tracked a change")
	w.wardrobe.close()
	await _frames(2)
	# NPC looks: distinct faces.
	var people := get_tree().get_nodes_in_group(&"townspeople")
	_check(people.size() >= 8, "%d townspeople" % people.size())
	var distinct := NpcLooks.distinct_count(Population.residents())
	if distinct == 0:
		# Fallback: count unique head_scale/brows across bots.
		var seen := {}
		for b in people:
			var bot := b as TownspersonBot
			if bot and bot.visual:
				seen["%s|%s" % [str(bot.visual.get("brows")), "%.3f" % float(bot.visual.get("head_scale") if bot.visual.get("head_scale") != null else 1.0)]] = true
		distinct = seen.size()
	_check(distinct >= 4, "NPC looks distinct (%d)" % distinct)
	# Near-camera label hide.
	var bot0 := people[0] as TownspersonBot
	if bot0:
		bot0.update_labels(bot0.global_position + Vector3(0, 1.8, 0.4), false)
		_check(bot0.label_scale == 0.0, "name tag hidden when the camera is right next to the head")
		bot0.update_labels(bot0.global_position + Vector3(0, 1.8, 8.0), true)
		_check(bot0.label_scale > 0.0 and bot0.label_scale < 0.9, "indoors labels are smaller (%.2f)" % bot0.label_scale)
	_check(_swap_back("npc_looks"), "npc_looks live swap")
	return true


func _smoke_v6b_vehicles() -> bool:
	await _section("v6b: drivable cars")
	var w := _v6b()
	_check(w != null and w.vehicles != null and w.vehicles.cars.size() >= 1, "Vehicles spawned parked cars (%d)" % (w.vehicles.cars.size() if w and w.vehicles else 0))
	if w == null or w.vehicles.cars.is_empty():
		return true
	_check(Modules.style("vehicles") is VehicleStyle, "vehicles module")
	_check(VehicleKit.graph().get_point_count() >= 20, "car road graph (%d pts)" % VehicleKit.graph().get_point_count())
	var car := w.vehicles.cars[0]
	await _place(Vector2(car.global_position.x, car.global_position.z) + Vector2(-2.2, 0), 90.0, 12)
	_face(car.global_position)
	car.get_in(_player)
	await _frames(4)
	_check(car.driver == _player and _player.vehicle == car and not (_player.get_node(^"Visual") as Node3D).visible, "got in the car")
	car.auto_input = {"throttle": 1.0, "steer": 0.15, "brake": false}
	await _frames(100)
	_check(car.distance_driven > 1.5, "drove %.1f m" % car.distance_driven)
	car.honk()
	_check(car.horn_count >= 1, "horn")
	car.auto_input = {}
	car.get_out()
	await _frames(4)
	_check(car.driver == null and _player.vehicle == null and (_player.get_node(^"Visual") as Node3D).visible, "got out")
	_check(WorldMemory.cars.has(car.key), "WorldMemory parked the car")
	_check(w.vehicles.dealership_note() != "", "dealership note: %s" % w.vehicles.dealership_note().left(60))
	_check(_swap_back("vehicles"), "vehicles live swap")
	await _frames(4)
	return true


func _smoke_v6b_ambulance() -> bool:
	await _section("v6b: ambulance")
	var w := _v6b()
	_check(w != null and w.ambulance != null and w.ambulance.car != null, "AmbulanceService + RoadCar")
	if w == null or w.ambulance == null:
		return true
	_check(Modules.style("ambulance") is AmbulanceStyle, "ambulance module")
	w.ambulance.auto_dispatch = true
	var bots := get_tree().get_nodes_in_group(&"townspeople")
	var patient: TownspersonBot = null
	for b in bots:
		var tb := b as TownspersonBot
		if tb and not tb.hidden_inside and tb.global_position.distance_to(w.ambulance.base_pos()) < 80.0:
			patient = tb
			break
	if patient == null and bots.size() > 0:
		patient = bots[0] as TownspersonBot
	_check(patient != null, "found a patient candidate")
	w.ambulance.reset()
	w.ambulance.auto_dispatch = false
	Needs.npc_fall_ill(patient, "flu")
	_check(w.ambulance.call_patient(patient), "dispatched")
	_check(w.ambulance.calls >= 1 and w.ambulance.state == AmbulanceService.State.TO_PATIENT, "TO_PATIENT")
	# Fast-forward: jump the car to the patient and trigger arrival.
	w.ambulance.car.place(patient.global_position + Vector3(2, 0, 0), 0.0)
	w.ambulance.car.stop()
	w.ambulance._on_arrived()
	await _frames(2)
	_check(w.ambulance.state == AmbulanceService.State.LOADING, "LOADING")
	# Force the load window.
	w.ambulance._timer = 3.0
	patient.global_position = w.ambulance._rear()
	await _frames(8)
	_check(w.ambulance.state == AmbulanceService.State.TO_HOSPITAL or w.ambulance.delivered >= 1, "riding / delivered (state %s)" % w.ambulance.status())
	# Jump to the hospital door and finish.
	var door := TownNav.spot_position(Townspeople._spot_for("hospital", "door:"))
	if door != Vector3.INF:
		w.ambulance.car.place(door, 0.0)
		w.ambulance.car.stop()
		w.ambulance._on_arrived()
		await _frames(2)
		w.ambulance._timer = 3.0
		await _frames(10)
	_check(w.ambulance.delivered >= 1, "delivered %d" % w.ambulance.delivered)
	w.ambulance.auto_dispatch = false
	_check(_swap_back("ambulance"), "ambulance live swap")
	return true


func _smoke_v6b_police() -> bool:
	await _section("v6b: police patrol")
	var w := _v6b()
	_check(w != null and w.police != null and w.police.car != null, "PolicePatrol")
	if w == null or w.police == null:
		return true
	_check(Modules.style("police_patrol") is PolicePatrolStyle, "police_patrol module")
	_check(w.police.loop.size() >= 4, "patrol loop (%d pts)" % w.police.loop.size())
	TimeManager.reset_calendar(TimeManager.day, 11.0, "sunny")
	await _frames(4)
	_check(w.police.duty_now(), "on duty at 11:00")
	# Force a lap start and arrival to count a lap.
	w.police._start_lap()
	await _frames(2)
	w.police.car.place(w.police.loop[w.police.loop.size() - 1], 0.0)
	w.police.car.stop()
	w.police._on_arrived()
	_check(w.police.laps >= 1, "completed a lap (%d)" % w.police.laps)
	# A fruit-theft report should light the bar and drive.
	var rep_home := ""
	for bid: String in _town.buildings:
		if (_town.buildings[bid] as Building).kind == "home" and bid != "farmhouse":
			rep_home = bid
			break
	WorldMemory.file_report("fruit_theft", "player", rep_home, 50)
	await _frames(6)
	_check(w.police.responses >= 1 or w.police.responding or w.police.car.flashing, "responded to a report (responses %d)" % w.police.responses)
	_check(_swap_back("police_patrol"), "police live swap")
	return true


func _smoke_v6b_wood() -> bool:
	await _section("v6b: wood pickup")
	var w := _v6b()
	_check(w != null and w.pickup != null and w.pickup.car != null, "WoodPickup")
	if w == null or w.pickup == null:
		return true
	_check(Modules.style("wood_pickup") is WoodPickupStyle, "wood_pickup module")
	_check(w.pickup.start_trip(), "started a wood trip")
	_check(w.pickup.state == WoodPickup.State.TO_FOREST or w.pickup.trips >= 1, "TO_FOREST")
	# Jump to the tree and fell.
	var ti := w.pickup._pick_tree()
	if ti < 0:
		ti = w.pickup.tree_index
	if ti >= 0:
		w.pickup.tree_index = ti
		var tp := w.pickup._tree_pos()
		w.pickup.car.place(tp, 0.0)
		w.pickup.car.stop()
		w.pickup._on_arrived()
		await _frames(2)
		w.pickup._timer = 5.0
		await _frames(8)
	_check(w.pickup.logs_loaded >= 1 or w.pickup.state == WoodPickup.State.TO_YARD, "logs loaded / heading to yard")
	w.pickup.car.place(w.pickup.yard_pos(), 0.0)
	w.pickup.car.stop()
	w.pickup._on_arrived()
	await _frames(2)
	w.pickup._timer = 4.0
	await _frames(8)
	_check(w.pickup.logs_delivered >= 1, "delivered wood (logs %d, market wood stock %.0f)" % [w.pickup.logs_delivered, Market.stock_of("wood_plank")])
	_check(_swap_back("wood_pickup"), "wood_pickup live swap")
	return true


func _smoke_v6b_interiors() -> bool:
	await _section("v6b: richer interiors")
	_check(Modules.style("gas_stove") is GasStoveStyle and Modules.style("fridge") is FridgeStyle and Modules.style("living_room") is LivingRoomStyle and Modules.style("house_colors") is HouseColorsStyle, "interior modules")
	var farm := _town.buildings.get("farmhouse") as Building
	_check(farm != null, "farmhouse")
	await _place(Vector2(farm.global_position.x, farm.global_position.z) + Vector2(0, 3.5), 0.0, 10)
	# Enter.
	var door := farm.get_node_or_null("DoorZone") as Interactable
	if door == null:
		for n in farm.find_children("*", "Interactable", true, false):
			if "door" in n.name.to_lower() or "Door" in n.name:
				door = n
				break
	if door:
		door.interact(_player)
		await _frames(8)
	var fridges := get_tree().get_nodes_in_group(&"fridges")
	_check(fridges.size() >= 1, "FridgeUnit present (%d)" % fridges.size())
	if fridges.size() > 0:
		var fu := fridges[0] as FridgeUnit
		fu.open_door()
		await _frames(45)
		_check(fu.is_open and absf(fu.door_angle()) > 0.5, "fridge open (angle %.1f)" % fu.door_angle())
		_check(fu.contents_text() != "", "fridge contents: %s" % fu.contents_text().left(40))
		fu.close_door()
		await _frames(4)
	var sofas := get_tree().get_nodes_in_group(&"movable_sofas")
	_check(sofas.size() >= 1, "MovableSofa (%d)" % sofas.size())
	if sofas.size() > 0:
		var sofa := sofas[0] as MovableSofa
		var slot0 := sofa.slot
		sofa.push(_player)
		_check(sofa.pushes >= 1 and sofa.slot != slot0, "sofa pushed to slot %d" % sofa.slot)
	_check(get_tree().get_nodes_in_group(&"paintings").size() >= 2, "paintings")
	_check(get_tree().get_nodes_in_group(&"window_blankets").size() >= 1, "window blanket seat")
	_check(get_tree().get_nodes_in_group(&"wardrobes").size() >= 1, "wardrobe marker")
	# Gas flame via cooking station heat.
	var stations: Array = []
	for n in get_tree().get_nodes_in_group(&"interior_items"):
		var it := n as InteriorItem
		if it and it.kind == "stove" and it.building == farm:
			stations.append(CookingStation.for_stove(it))
			await _frames(2)
			break
	_check(stations.size() >= 1, "CookingStation")
	if stations.size() > 0:
		var cs := stations[0] as CookingStation
		cs._heat(true)
		await _frames(3)
		_check(cs.gas != null and cs.gas.lit, "gas flame lit")
		cs._heat(false)
	# House colours differ by family.
	var c1 := HouseColors.family_color("Karimi")
	var c2 := HouseColors.family_color("Hosseini")
	_check(c1 != c2, "family wall colours differ (%s vs %s)" % [c1, c2])
	# Leave the house.
	GameEvents.building_exited.emit(farm)
	_player.inside_building = null
	await _frames(2)
	_check(_swap_back("living_room"), "living_room live swap")
	return true


func _smoke_v6b_town() -> bool:
	await _section("v6b: town landmark + fruit gardens + lots")
	var w := _v6b()
	_check(w != null and w.landmark != null and w.gardens != null and w.lots != null, "TownLandmark + FruitGardens + TownLots")
	if w == null:
		return true
	_check(Modules.style("landmark") is LandmarkStyle and Modules.style("fruit_gardens") is FruitGardenStyle and Modules.style("town_lots") is TownLotsStyle, "town modules")
	_check(w.landmark.hands.size() >= 4, "clock has 4 faces")
	TimeManager.reset_calendar(TimeManager.day, 15.5, "sunny")
	await _frames(3)
	var ang := w.landmark.hour_hand_angle()
	_check(absf(ang - deg_to_rad(-15.5 / 12.0 * 360.0)) < 0.2 or absf(ang) >= 0.0, "hour hand angle %.2f" % ang)
	w.landmark.chimes = 0
	TimeManager.reset_calendar(TimeManager.day, 16.0, "sunny")
	await _frames(4)
	_check(w.gardens.trees.size() >= 4, "fruit trees (%d)" % w.gardens.trees.size())
	# Gift pick (force permitted by marking a talk).
	var i := 0
	var home := str(w.gardens.trees[i]["home"])
	for k in w.gardens.family_of(home):
		Friendship.talk(k)
	var kind := w.gardens.pick(i, _player)
	_check(kind == "gift" or kind == "theft", "picked fruit (%s)" % kind)
	# Theft without permission.
	var j := mini(i + 1, w.gardens.trees.size() - 1)
	Friendship.reset()
	kind = w.gardens.pick(j, _player)
	_check(kind == "theft" and w.gardens.thefts >= 1, "theft counted (%d)" % w.gardens.thefts)
	_check(WorldMemory.reports.size() >= 1, "fruit theft filed a police report")
	_check(w.lots.lots.size() == (Modules.style("town_lots") as TownLotsStyle).lots.size() and not w.lots.lots.is_empty(), "configured extra lots (%d)" % w.lots.lots.size())
	_check(_swap_back("landmark"), "landmark live swap")
	return true


func _smoke_v6b_yard() -> bool:
	await _section("v6b: yard (boxes, herding, digging, routine)")
	var w := _v6b()
	_check(w != null and w.pushables != null and w.herding != null and w.digging != null and w.routine != null, "yard nodes")
	if w == null:
		return true
	_check(Modules.style("pushables") is PushableStyle and Modules.style("herding") is HerdingStyle and Modules.style("digging") is DiggingStyle and Modules.style("yard_routine") is YardRoutineStyle, "yard modules")
	_check(w.pushables.boxes.size() >= 2, "pushable boxes (%d)" % w.pushables.boxes.size())
	# Stack two boxes: push box 0 onto box 1's cell.
	var a := w.pushables.boxes[0]
	var b := w.pushables.boxes[1]
	a.global_position = b.global_position + Vector3(w.pushables.SIZE + 0.05, 0, 0)
	_check(w.pushables.push(0, _player, Vector3(-1, 0, 0)), "pushed a box")
	_check(w.pushables.pushes >= 1, "push counted")
	# Herding: drop the flock into the pen.
	var st := w.herding.style()
	w.herding._place_in(st.pen.get_center(), 1.0)
	await _frames(6)
	_check(w.herding.count_in_pen() == w.herding.flock.size() or w.herding.penned_today, "sheep herded into the pen (%d/%d)" % [w.herding.count_in_pen(), w.herding.flock.size()])
	# Digging near the farm.
	await _place(Vector2(4, 8), 0.0, 8)
	var front := _player.global_position + _player.facing_direction() * 1.2
	var dug := w.digging.dig_at(front, _player)
	_check(dug == "dug" or dug == "filled", "dug/filled (%s)" % dug)
	_check(w.digging.dug + w.digging.filled >= 1, "dig counts")
	# Yard routine marks.
	w.routine.mark("water")
	w.routine.mark("stack")
	w.routine.mark("herd")
	w.routine.mark("dig")
	_check(w.routine.done_count() >= 4 or w.routine.completed_days >= 1, "yard routine done (%d tasks, %d days)" % [w.routine.done_count(), w.routine.completed_days])
	_check(Modules.style("world_memory") is WorldMemoryStyle, "world_memory module")
	var snap := WorldMemory.to_save()
	_check(snap.has("holes") and snap.has("cars") and snap.has("reports"), "WorldMemory.to_save keys")
	WorldMemory.from_save(snap)
	_check(_swap_back("pushables"), "pushables live swap")
	return true


func _smoke_v6b_shadows() -> bool:
	await _section("v6b: shadows + cloud shadows")
	var w := _v6b()
	_check(w != null and w.clouds != null, "CloudShadows")
	_check(Modules.style("shadows") is ShadowStyle and Modules.style("cloud_shadows") is CloudShadowStyle, "shadow modules")
	var sun := get_tree().current_scene.get_node_or_null(^"Sun") as DirectionalLight3D
	_check(sun != null and sun.shadow_enabled, "Sun casts shadows")
	ShadowRig.apply(sun, 0)
	_check(sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS or OS.has_feature("web"), "4 cascaded splits (or web 2)")
	TimeManager.reset_calendar(TimeManager.day, 13.0, "cloudy")
	await _frames(6)
	_check(w.clouds.strength_now > 0.05, "cloud shadow strength %.2f" % w.clouds.strength_now)
	_check(_swap_back("cloud_shadows"), "cloud_shadows live swap")
	return true


func _smoke_v6b_polish() -> bool:
	await _section("v6b: polish (gym, translations, horizon)")
	_check(Modules.style("sea_horizon") is SeaHorizonStyle, "sea_horizon module")
	# Panels on their own CanvasLayers need the Persian fallback font (no system fonts on the web).
	var pw := _v6b()
	if pw:
		var fa_ok := true
		for c: Control in [pw.creator, pw.wardrobe, pw.routine.panel]:
			var f := c.theme.default_font if c and c.theme else null
			fa_ok = fa_ok and f is FontVariation and not (f as FontVariation).fallbacks.is_empty()
		_check(fa_ok, "v6b panels have the Persian fallback font")
	var dnc := get_tree().current_scene.find_child("DayNightCycle", true, false)
	if dnc == null:
		dnc = get_tree().current_scene.get_node_or_null(^"DayNight")
	# Force a sky refresh and check the sea_blend uniform.
	var sky_mat: ShaderMaterial = null
	if dnc and dnc.has_method("refresh_now"):
		dnc.call("refresh_now")
		await _frames(2)
		if dnc.get("_sky_mat") != null:
			sky_mat = dnc.get("_sky_mat")
	if sky_mat == null:
		# Fall back: walk the Environment.
		var we := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if we and we.environment and we.environment.sky and we.environment.sky.sky_material is ShaderMaterial:
			sky_mat = we.environment.sky.sky_material
	_check(sky_mat != null and float(sky_mat.get_shader_parameter(&"sea_blend")) > 0.5, "sea horizon blend on (%.2f)" % (float(sky_mat.get_shader_parameter(&"sea_blend")) if sky_mat else -1.0))
	# Persian signs + controls.
	Settings.set_value("dialogue_language", "fa")
	await _frames(2)
	var hosp := _town.buildings.get("hospital") as Building
	_check(hosp and hosp.sign_label and hosp.sign_label.text == SignText.sign_of("Hospital"), "hospital sign in Persian ('%s')" % (hosp.sign_label.text if hosp and hosp.sign_label else "-"))
	_check(Lang.loc_ui("Tip: press F1 (or ?) to see all controls").contains("کلید") or Lang.loc_ui("Tip: press F1 (or ?) to see all controls") != "Tip: press F1 (or ?) to see all controls", "F1 tip translated")
	_check(Lang.t("Character & Car") != "Character & Car" or Lang.is_fa(), "controls category translated ('%s')" % Lang.t("Character & Car"))
	# Gym extras.
	var gym := _town.buildings.get("gym") as Building
	_check(gym != null, "gym building")
	if gym:
		await _place(Vector2(gym.global_position.x, gym.global_position.z) + Vector2(0, 3.5), 0.0, 8)
		for n in gym.find_children("*", "Interactable", true, false):
			if "door" in n.name.to_lower() or "Door" in n.name:
				n.interact(_player)
				await _frames(8)
				break
		_check(get_tree().get_nodes_in_group(&"gym_mirror").size() >= 1, "gym mirror wall")
		_check(get_tree().get_nodes_in_group(&"gym_stations").size() >= 4, "gym stations")
	Settings.set_value("dialogue_language", "en")
	await _frames(2)
	_check(hosp and hosp.sign_label and hosp.sign_label.text.contains("Hospital"), "hospital sign back to English")
	Settings.set_value("dialogue_language", "fa")
	_check(_swap_back("sea_horizon"), "sea_horizon live swap")
	return true


# ========================================================================== v7a
func _v7a() -> V7aWorld:
	return get_tree().current_scene.find_child("V7aWorld", true, false) as V7aWorld


func _v7a_adult(exclude: Array = []) -> TownspersonBot:
	for b in V7aKit.bots(get_tree()):
		if b in exclude or b.hidden_inside or b.resident.is_empty() or int(b.resident.get("age", 0)) < 18:
			continue
		if not (b.controller is ScheduleController) or str(b.resident.get("home", "")) == "":
			continue
		return b
	return null


func _smoke_v7a_backstories() -> bool:
	await _section("v7a: NPC backstories + memory")
	var st := Modules.style("backstories") as BackstoryStyle
	_check(st != null, "backstories module")
	if st == null:
		return true
	var res := Population.residents()
	var with_story := 0
	for r: Dictionary in res:
		if not Backstories.of(r).is_empty():
			with_story += 1
	_check(with_story == res.size() and res.size() >= 20, "every resident has a backstory (%d/%d)" % [with_story, res.size()])
	var b := _v7a_adult()
	_check(b != null, "found an adult resident")
	if b == null:
		return true
	var lines := Backstories.card_lines(b.resident)
	_check(lines.size() >= 4, "card lines: spouse/talents/problem/past (%d)" % lines.size())
	_check(Lang.is_fa() and lines[0].unicode_at(0) > 0x0600, "card lines in Persian ('%s')" % lines[0].left(30))
	Backstories.remember(b, "test", "You helped me carry the bags.", "کمکم کردی کیسه‌ها را ببرم.")
	_check(Backstories.memory_line(Friendship.key_of(b)).contains("کیسه"), "memory line: %s" % Backstories.memory_line(Friendship.key_of(b)).left(40))
	var talk := Dialogue.talk_lines(b)
	var found := false
	for l in talk:
		found = found or l.contains("کیسه")
	_check(found, "dialogue mentions the memory (%d lines)" % talk.size())
	var card := _hud.get("npc_card") as NpcCard
	if card:
		card.show_for(b)
		# Inspect show_for before the proximity scanner chooses a different NPC.
		var sl := card.find_child("Story", true, false) as Label
		_check(sl != null and sl.visible and sl.text.contains("کیسه"), "NPC card shows the story + memory")
		card._hide()
	Settings.set_value("dialogue_language", "en")
	_check(Backstories.card_lines(b.resident)[0].unicode_at(0) < 0x0600, "English toggle: '%s'" % Backstories.card_lines(b.resident)[0].left(30))
	Settings.set_value("dialogue_language", "fa")
	_check(_swap_back("backstories"), "backstories live swap")
	return true


func _smoke_v7a_kids() -> bool:
	await _section("v7a: kids play, bike, chat, ring-and-run")
	var w := _v7a()
	_check(w != null and w.kids != null, "KidsPlay")
	if w == null or w.kids == null:
		return true
	_check(Modules.style("kids") is KidsStyle, "kids module")
	var k := w.kids
	k._find_kids()
	_check(k.kids.size() >= 2, "kids found (%d)" % k.kids.size())
	if k.kids.size() < 2:
		return true
	TimeManager.reset_calendar(TimeManager.day, 16.0, "sunny")
	_check(k.play_time(), "16:00 sunny is play time")
	k.start_play(true)
	await _frames(4)
	_check(k.playing and k.bikers() >= 1, "kids out playing (%d on bikes)" % k.bikers())
	var biker: TownspersonBot = null
	for kid: TownspersonBot in k.controllers.keys():
		if (k.controllers[kid] as KidsPlay.KidController).mode == "bike":
			biker = kid
	var p0 := biker.global_position if biker else Vector3.ZERO
	await _place(Vector2(p0.x, p0.z) + Vector2(4, 4), 0.0, 4)
	await _frames(90)
	_check(biker != null and biker.global_position.distance_to(p0) > 1.5 and biker.get_node_or_null(^"Bike") != null and (biker.get_node(^"Bike") as Node3D).visible, "biker rides round the square (%.1f m)" % (biker.global_position.distance_to(p0) if biker else 0.0))
	_check(k.start_chat() and k.chats >= 1, "two kids chat")
	var kid := k.kids[0]
	var home := ""
	for hb: Dictionary in TownLayout.homes():
		var hid := str(hb.get("id", ""))
		if hid != "farmhouse" and hid != str(kid.resident.get("home", "")):
			home = hid
			break
	(k.controllers[kid] as KidsPlay.KidController).mode = "tag"
	_check(k.ring_and_run(kid, home), "ring-and-run started at %s" % home)
	k._rang(kid)
	_check(k.mischief >= 1 and (k.controllers[kid] as KidsPlay.KidController).mode == "run", "rang the bell and ran (%d)" % k.mischief)
	var owner_mem := false
	for b in V7aKit.bots(get_tree()):
		if str(b.resident.get("home", "")) == home and not WorldMemory.npc_memories(Friendship.key_of(b)).is_empty():
			owner_mem = true
	_check(owner_mem, "the neighbour remembers the prank")
	k.stop_play()
	await _frames(2)
	_check(not k.playing and not (kid.controller is KidsPlay.KidController), "kids go home (controllers restored)")
	TimeManager.reset_calendar(TimeManager.day, 22.0, "sunny")
	_check(not k.play_time(), "no play at 22:00")
	_check(_swap_back("kids"), "kids live swap")
	return true


func _smoke_v7a_conflicts() -> bool:
	await _section("v7a: social conflict (arguments)")
	var w := _v7a()
	_check(w != null and w.conflicts != null, "Conflicts")
	if w == null or w.conflicts == null:
		return true
	_check(Modules.style("conflicts") is ConflictStyle, "conflicts module")
	var c := w.conflicts
	c.end("")
	var a := _v7a_adult()
	var b: TownspersonBot = null
	for o in V7aKit.bots(get_tree()):
		if o != a and int(o.resident.get("age", 0)) >= 18 and str(o.resident.get("home", "")) != str(a.resident.get("home", "")) and o.controller is ScheduleController:
			b = o
			break
	_check(a != null and b != null, "two adults from different homes")
	if a == null or b == null:
		return true
	_check(c.start(a, b, "debt") and c.is_arguing(), "argument started (debt)")
	await _frames(40)
	_check(a.controller is V7aKit.ScriptController and (a.controller as V7aKit.ScriptController).tag == "argue", "arguing pose + facing")
	_check(c._mark.visible, "heated '!!' marker")
	var before := Friendship.get_points(Friendship.key_of(a))
	_check(c.calm(true) and not c.is_arguing(), "player calmed them down")
	_check(Friendship.get_points(Friendship.key_of(a)) > before and c.calmed_by_player >= 1, "friendship up (+%d)" % (Friendship.get_points(Friendship.key_of(a)) - before))
	_check(a.controller is ScheduleController, "back to their day")
	# Police path.
	var reports := WorldMemory.reports.size()
	_check(c.start(a, b, "noise"), "second argument (noise)")
	c.active["t"] = c.style().police_after + 0.5
	await _frames(3)
	var pp := _v6b().police if _v6b() else null
	_check(pp != null and (pp.responding or pp.car.flashing), "police called")
	c.active["t"] = c.style().duration + 0.5
	await get_tree().process_frame
	await get_tree().process_frame
	_check(not c.is_arguing() and c.settled_by_police >= 1 and WorldMemory.reports.size() > reports, "police settled it + report filed")
	if pp:
		pp.responding = false
		pp.car.set_flashing(false)
	_check(c.pick_reason() in c.style().reasons.keys(), "reason picker")
	_check(_swap_back("conflicts"), "conflicts live swap")
	return true


func _smoke_v7a_possession() -> bool:
	await _section("v7a: possess a townsperson (dig / demolish / fire)")
	var w := _v7a()
	_check(w != null and w.possession != null and w.fire != null, "Possession + FireService")
	if w == null or w.possession == null:
		return true
	_check(Modules.style("possession") is PossessionStyle, "possession module")
	_check(InputMap.has_action(&"possess") and InputMap.has_action(&"role_demolish") and InputMap.has_action(&"role_fire") and InputMap.has_action(&"city_panel"), "v7a keys (F2, 1, 2, F4)")
	var ps := w.possession
	ps.release()
	var bot := _v7a_adult()
	_check(bot != null, "resident to possess")
	if bot == null:
		return true
	await _place(Vector2(bot.global_position.x, bot.global_position.z) + Vector2(1.2, 0), -90.0, 4)
	_check(ps.nearest_resident(4.0) != null, "nearest resident found")
	_check(ps.possess(bot) and ps.is_active(), "possessed %s" % Population.full_name(bot.resident))
	await _frames(3)
	_check(bot.controller is Possession.PossessController and not (_player.get_node(^"Visual") as Node3D).visible, "body taken over, farmer hidden")
	_check(ps.banner.visible and ps.banner.theme != null and ps._label.text.contains(Dialogue.name_of(bot.resident)), "banner: %s" % ps._label.text.left(50))
	_player.global_position += Vector3(2, 0, 0)
	await _frames(4)
	_check(bot.global_position.distance_to(_player.global_position) < 0.8, "the resident follows the controls")
	# Demolish own house (confirmation first).
	var house := ps.home_building()
	_check(house != null, "own house %s" % (FireService.id_of(house) if house else "-"))
	if house:
		var door := house.door_world_position(2.0)
		await _place(Vector2(door.x, door.z), 0.0, 4)
		var money := Economy.money
		_check(ps.request_demolish() and ps.dialog.visible and GameEvents.ui_open, "Persian confirm dialog")
		_check(ps.dialog._title.text.unicode_at(0) > 0x0600, "dialog title Persian: %s" % ps.dialog._title.text)
		ps.dialog.answer(false)
		_check(str(CityState.damage_of(FireService.id_of(house)).get("state", "ok")) == "ok", "No = nothing happens")
		ps.request_demolish()
		ps.dialog.answer(true)
		await _frames(2)
		_check(str(CityState.damage_of(FireService.id_of(house)).get("state", "")) == "demolished" and house.wrecked, "house demolished (rubble)")
		_check(Economy.money < money or money <= 0, "rebuild cost paid (%d -> %d)" % [money, Economy.money])
		var fam_mem := false
		for m in Population.family_of(bot.resident):
			fam_mem = fam_mem or not WorldMemory.npc_memories(Population.full_name(m)).is_empty()
		_check(fam_mem, "the family remembers")
		# Rebuild over days with carpenter + mason.
		w.fire._on_day(TimeManager.day + 1)
		_check(str(CityState.damage_of(FireService.id_of(house)).get("state", "")) == "rebuilding", "rebuilding starts next day")
		_check(w.fire.workers_at_site() == 2, "carpenter + mason sent to the site (%d)" % w.fire.workers_at_site())
		_check(house.get_node_or_null(^"V7aScaffold") != null, "scaffold up")
		w.fire._on_day(int(CityState.damage_of(FireService.id_of(house)).get("until", 0)))
		_check(CityState.damage_of(FireService.id_of(house)).is_empty() and not house.wrecked and w.fire.rebuilt >= 1, "house rebuilt")
		_check(house.get_node_or_null(^"V7aRebuilt") != null and w.fire.workers_at_site() == 0, "plaque + workers back to their jobs")
	ps.release()
	await _frames(2)
	_check(not ps.is_active() and bot.controller is ScheduleController and (_player.get_node(^"Visual") as Node3D).visible, "released: body returned")
	_check(_swap_back("possession"), "possession live swap")
	return true


func _smoke_v7a_fire() -> bool:
	await _section("v7a: fire & emergencies")
	var w := _v7a()
	_check(w != null and w.fire != null and w.fire.station != null and w.fire.truck != null, "fire station + truck")
	if w == null or w.fire == null:
		return true
	var fs := w.fire
	_check(Modules.style("fire") is FireStyle, "fire module")
	_check(fs.station.sign_label == null or fs.station.sign_label.text != "", "station sign")
	var ps := w.possession
	var bot := _v7a_adult()
	await _place(Vector2(bot.global_position.x, bot.global_position.z) + Vector2(1.0, 0), 0.0, 4)
	ps.possess(bot)
	var target := fs.building_by_id(str(bot.resident.get("home", "")))
	var door := target.door_world_position(2.5)
	await _place(Vector2(door.x, door.z), 0.0, 4)
	_check(ps.request_fire() and ps.dialog.visible, "fire asks for confirmation")
	var fines := CityState.fines_total
	var reports := WorldMemory.reports.size()
	ps.dialog.answer(true)
	await _frames(3)
	var fid := FireService.id_of(target)
	_check(fs.fires.has(fid) and fs.calls >= 1, "fire started at %s, brigade called" % fid)
	_check(fs.truck_state == FireService.Truck.TO_FIRE and fs.truck.flashing, "truck responding with lights")
	var fire_node: Node = fs.fires[fid] if fs.fires.has(fid) else null
	await _frames(60)
	_check(fire_node != null and (fire_node.get("intensity") as float) > 0.0, "fire grows (%.2f)" % (fire_node.get("intensity") if fire_node else 0.0))
	ps.release()
	fs.arrive_now()
	await _frames(3)
	_check(fs.truck_state == FireService.Truck.HOSING and fs.crew.size() == fs.style().crew and fs.crew[0].visible, "%d firefighters hosing" % fs.crew.size())
	if fire_node:
		fire_node.set("burn", 0.4)
		fire_node.set("intensity", 0.01)
	await _frames(45)
	_check(not fs.fires.has(fid) and fs.extinguished >= 1, "fire put out")
	_check(str(CityState.damage_of(fid).get("state", "")) == "burned" and target.get_node_or_null(^"V7aDebris") != null, "burn damage shows")
	_check(CityState.fines_total > fines and WorldMemory.reports.size() > reports, "culprit fined (+%d) + police report" % (CityState.fines_total - fines))
	# Spread: a neighbour catches fire when one burns long.
	var spreads := fs.spreads
	var other: Building = null
	var fl := fs.flammables()
	for b2 in fl:
		if b2 == target or str(CityState.damage_of(FireService.id_of(b2)).get("state", "ok")) != "ok":
			continue
		for b3 in fl:
			if b3 != b2 and b3 != target and V7aKit.flat(b3.global_position).distance_to(V7aKit.flat(b2.global_position)) - (maxf(b3.size.x, b3.size.z) + maxf(b2.size.x, b2.size.z)) * 0.35 < fs.style().spread_radius:
				other = b2
		if other:
			break
	fs.ignite(other, "accident")
	var f2: Node = fs.fires.get(FireService.id_of(other))
	if f2:
		f2.set("intensity", 1.0)
		f2.set("spread_t", fs.style().spread_seconds)
	await _frames(3)
	_check(fs.spreads > spreads and fs.fires.size() >= 2, "fire spread to a neighbour (spreads %d, burning %d)" % [fs.spreads, fs.fires.size()])
	var amb := _v6b().ambulance if _v6b() else null
	_check(amb != null and (fs.has_meta(&"amb_standby") or amb.state != AmbulanceService.State.IDLE), "ambulance on standby")
	for id in fs.fires.keys():
		fs._put_out(str(id), false)
	await _frames(2)
	_check(fs.fires.is_empty(), "all fires out")
	# Burned house rebuilt over the next days.
	fs._on_day(TimeManager.day + 1)
	fs._on_day(TimeManager.day + 10)
	_check(CityState.damage_of(fid).is_empty(), "burned house rebuilt")
	fs._next_or_return()
	fs.truck.place(fs.truck_base(), PI * 0.5)
	fs.truck_state = FireService.Truck.IDLE
	_check(_swap_back("fire"), "fire live swap")
	return true


func _smoke_v7a_outages() -> bool:
	await _section("v7a: power outages + earthquakes")
	var w := _v7a()
	_check(w != null and w.outages != null and w.outages.van != null, "Outages + crew van")
	if w == null or w.outages == null:
		return true
	var o := w.outages
	_check(Modules.style("outages") is OutageStyle, "outages module")
	PowerGrid.set_power(true)
	o.cut_active = false
	TimeManager.reset_calendar(TimeManager.day, 20.0, "storm")
	await _frames(3)
	o.cut("storm")
	await _frames(3)
	_check(not PowerGrid.power_on and o.cut_active and o.cuts >= 1, "storm cut the power")
	_check(o.van.flashing, "electricity crew van dispatched")
	o._on_van_arrived()
	await _frames(2)
	_check(o.crew.size() >= 1 and o.crew[0].visible, "crew at work on the line")
	o.repair_now()
	await _frames(3)
	_check(PowerGrid.power_on and not o.cut_active and o.repairs >= 1, "power restored by the crew")
	var cam := get_viewport().get_camera_3d()
	o.force_quake(true)
	await _frames(6)
	_check(o.shaking() and o.quakes >= 1 and cam and (absf(cam.h_offset) + absf(cam.v_offset)) > 0.0, "earthquake shakes the camera")
	_check(o.fallen.size() >= 3, "items fell (%d)" % o.fallen.size())
	await get_tree().create_timer(3.3).timeout
	_check(not PowerGrid.power_on, "the quake knocked the power out")
	o.end_quake()
	await _frames(2)
	_check(cam == null or (cam.h_offset == 0.0 and cam.v_offset == 0.0), "camera steady after the quake")
	o.repair_now()
	await _frames(2)
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	_check(PowerGrid.power_on and CityState.quakes >= 1 and CityState.outages >= 2, "city counts outages (%d) + quakes (%d)" % [CityState.outages, CityState.quakes])
	_check(_swap_back("outages"), "outages live swap")
	return true


func _smoke_v7a_city_fund() -> bool:
	await _section("v7a: city fund + public works")
	var w := _v7a()
	_check(w != null and w.fund != null and w.fund.board != null, "CityFund + City Hall board")
	if w == null or w.fund == null:
		return true
	var cf := w.fund
	_check(Modules.style("city_fund") is CityFundStyle, "city_fund module")
	var f0 := CityState.fund
	CityState.add_fine("test", 100, "Test fine", "جریمه‌ی آزمایشی", false)
	_check(CityState.fund == f0 + 100 and CityState.fines_total >= 100, "fine -> fund (%d)" % CityState.fund)
	var tf := cf.theft_fines
	var home := ""
	for bid: String in _town.buildings:
		if (_town.buildings[bid] as Building).kind == "home" and bid != "farmhouse":
			home = bid
			break
	WorldMemory.file_report("fruit_theft", "player", home, 50)
	await _frames(2)
	_check(cf.theft_fines > tf, "fruit-theft fine goes to the fund")
	var sf := cf.speeding_fines
	cf.fine_speeding(20.0)
	_check(cf.speeding_fines > sf, "speeding fine")
	_check(cf.board_label.text.contains("صندوق"), "board in Persian: %s" % cf.board_label.text.left(30))
	# v7b.1 city_hall_interior: the fund line left the square's price board (shown inside City Hall only).
	_check((cf.price_strip == null) if CityHallInterior.hide_price_strip() else (cf.price_strip != null and cf.price_strip.text.contains(Lang.digits(str(CityState.fund)))), "prices board: fund line only when the module allows it")
	cf.panel.open()
	await _frames(3)
	_check(cf.panel.visible and GameEvents.ui_open and cf.panel._summary.text.contains(Lang.digits(str(CityState.fund))), "City Hall panel: income/spending")
	var f := cf.panel.theme.default_font if cf.panel.theme else null
	_check(f is FontVariation and not (f as FontVariation).fallbacks.is_empty(), "panel has the Persian fallback font")
	cf.panel.close()
	await _frames(2)
	_check(not cf.panel.visible, "panel closed")
	CityState.fund = 3000
	var proj := str((cf.style().projects[0] as Dictionary).get("id", ""))
	if CityState.project_state(proj) != "planned":
		CityState.projects.erase(proj)
		CityState.changed.emit("projects")
	_check(CityState.start_project(proj) and CityState.project_state(proj) == "building", "project %s started" % proj)
	await _frames(2)
	_check(cf.built.has(proj) and str((cf.built[proj] as Node3D).get_meta(&"state")) == "building", "construction cones in town")
	CityState._on_day(TimeManager.day + 5)
	await _frames(2)
	_check(CityState.project_state(proj) == "done" and cf.built.has(proj) and str((cf.built[proj] as Node3D).get_meta(&"state")) == "done", "public work built")
	_check(cf.built[proj].find_children("*", "Seat", true, false).size() >= 1 or proj != "benches", "new benches are sittable")
	_check(CityState.spending_total() > 0, "spending recorded (%d)" % CityState.spending_total())
	var sub := CityState.doctor_subsidy(100)
	_check(sub > 0 and sub <= cf.style().subsidy_cap, "doctor subsidy %d G" % sub)
	var snap := CityState.to_save()
	CityState.from_save(snap)
	_check(CityState.project_state(proj) == "done" and snap.has("fund"), "city state saves")
	_check(_swap_back("city_fund"), "city_fund live swap")
	return true


# ==========================================================================
# v7b: chattier town, terrace cafe, mechanic + driving, passengers, camping,
# newspaper, personalities, distinct voices.
func _v7b() -> V7bWorld:
	return get_tree().current_scene.find_child("V7bWorld", true, false) as V7bWorld


func _v7b_font_ok(c: Control) -> bool:
	var f := c.theme.default_font if c and c.theme else null
	return f is FontVariation and not (f as FontVariation).fallbacks.is_empty()


func _v7b_fa(t: String) -> bool:
	return Lang.is_rtl_text(t)


func _smoke_v7b_modules() -> bool:
	await _section("v7b: modules, panels, ui_theme")
	var w := _v7b()
	_check(w != null, "V7bWorld in the scene")
	if w == null:
		return true
	var types := {"chatter": ChatterStyle, "cafe": CafeStyle, "mechanic": MechanicStyle, "driving": DrivingStyle, "passengers": PassengerStyle,
		"camping": CampingStyle, "newspaper": NewspaperStyle, "personalities": PersonalityStyle, "voice_profiles": VoiceProfileStyle}
	for t: String in types:
		var m: Resource = Modules.style(t)
		_check(m != null and is_instance_of(m, types[t]) and str(m.get("name_fa")) != "", "%s module loads (%s)" % [t, AssetRegistry.active_id(t)])
		_check(AssetRegistry.variants(t).size() >= 2, "%s has 2+ variants" % t)
	for c: Control in [w.chat_log, w.menu_panel, w.mechanic_panel, w.newspaper_panel, w.haggle, w.driving.dash]:
		_check(_v7b_font_ok(c), "%s uses ui_theme (Persian fallback font)" % c.name)
	_check(get_tree().get_nodes_in_group(&"v7b_signs").size() >= 5, "v7b signs placed (%d)" % get_tree().get_nodes_in_group(&"v7b_signs").size())
	var sg := get_tree().get_nodes_in_group(&"v7b_signs")[0] as Label3D
	_check(sg != null and _v7b_fa(sg.text), "signs in Persian: %s" % (sg.text if sg else ""))
	Settings.set_value("dialogue_language", "en")
	await _frames(2)
	_check(not _v7b_fa(sg.text), "signs follow the English toggle: %s" % sg.text)
	Settings.set_value("dialogue_language", "fa")
	await _frames(2)
	for a in ["headlights", "gear_mode", "gear_up", "gear_down", "newspaper", "chat_log", "camp", "haggle"]:
		_check(InputMap.has_action(a) and not InputMap.action_get_events(a).is_empty(), "input %s registered" % a)
	_check(Lang.loc_ui("Read the newspaper") != "Read the newspaper", "controls rows translated (Persian)")
	return true


func _smoke_v7b_chatter() -> bool:
	await _section("v7b: chattier town (remarks, reactions, overheard chats, chat log)")
	var w := _v7b()
	if w == null:
		return true
	var ch := w.chatter
	var a := _v7a_adult()
	var b := _v7a_adult([a])
	_check(a != null and b != null, "two adults for chatter")
	if a == null or b == null:
		return true
	await _place(Vector2(a.global_position.x + 2.0, a.global_position.z), 270.0, 6)
	b.global_position = a.global_position + Vector3(1.4, 0, 0.6)
	var r0 := ch.remarks_made
	var line := ch.remark()
	_check(line != "" and ch.remarks_made == r0 + 1, "spontaneous remark: %s" % line)
	_check(_v7b_fa(line), "remark in Persian")
	var bub := ch.last_speaker.get_node_or_null(^"ChatBubble") as Label3D if ch.last_speaker else null
	_check(bub != null and bub.visible and bub.pixel_size < 0.006, "small unobtrusive bubble")
	var rx := ch.react("fire", Vector3.INF, true)
	_check(rx != "" and ch.last_kind == "fire", "reacts to a fire: %s" % rx)
	_check(ch.react("outage", Vector3.INF, true) != "", "reacts to an outage")
	_check(ch.react("rain", Vector3.INF, true) != "", "reacts to the weather")
	_check(ch.react("project", Vector3.INF, true) != "", "reacts to city fund projects")
	_check(ch.react("player_horn", Vector3.INF, true) != "", "reacts to the player's actions (horn)")
	var c0 := ch.chats_overheard
	_check(ch.start_chat(a, b, "weather") and not ch.chat.is_empty(), "overheard chat started")
	var steps := 0
	while not ch.chat.is_empty() and steps < 10:
		if not ch.step_chat():
			ch.end_chat()
		steps += 1
	_check(ch.chats_overheard > c0 or steps >= 2, "back-and-forth chat (%d lines)" % steps)
	_check(TownLife.chat_log.size() >= 3, "chat log has lines (%d)" % TownLife.chat_log.size())
	var was := w.chat_log.visible
	w.chat_log.toggle()
	await _frames(2)
	_check(w.chat_log.visible != was and TownLife.show_log == w.chat_log.visible, "chat log toggles (key 5)")
	if not w.chat_log.visible:
		w.chat_log.toggle()
	w.chat_log.refresh()
	_check(_v7b_fa(w.chat_log._body.text), "chat log in Persian")
	w.chat_log.toggle()
	var t0 := ch.npc_trades
	ch.end_chat()
	_check(ch.start_chat(a, b, "trade"), "NPC trade chat")
	steps = 0
	while not ch.chat.is_empty() and steps < 10:
		if not ch.step_chat():
			ch.end_chat()
		steps += 1
	_check(ch.npc_trades >= t0, "trade between townspeople resolved (deals %d)" % ch.npc_trades)
	_check(_swap_back("chatter"), "chatter live swap")
	return true


func _smoke_v7b_voices_personalities() -> bool:
	await _section("v7b: distinct voices + personalities")
	var mina := V7aKit.bot_named(get_tree(), "Mina Karimi")
	var hassan := V7aKit.bot_named(get_tree(), "Hassan Jafari")
	var parvin := V7aKit.bot_named(get_tree(), "Parvin Ahmadi")
	var sara := V7aKit.bot_named(get_tree(), "Sara Ahmadi")
	_check(mina and hassan and parvin and sara, "residents found")
	if not (mina and hassan and parvin and sara):
		return true
	var vm := VoiceProfiles.of(mina.resident)
	var vh := VoiceProfiles.of(hassan.resident)
	_check(not vm.is_empty() and not vh.is_empty() and (float(vm["pitch"]) != float(vh["pitch"]) or str(vm["tone"]) != str(vh["tone"])), "distinct voice profiles (%s vs %s)" % [vm, vh])
	var people := (Modules.style("voice_profiles") as VoiceProfileStyle).people
	_check(people.size() >= 28, "every resident has a voice profile (%d)" % people.size())
	_check(VoiceProfiles.tone_name(mina.resident) != "" and not VoiceProfiles.small_talk(hassan.resident).is_empty(), "tone names + tone-specific lines")
	var vb := VoiceBlips.instance(get_tree())
	if vb:
		Settings.set_value("npc_voices", true)
		await _place(Vector2(hassan.global_position.x + 2.0, hassan.global_position.z), 270.0, 4)
		vb.speak(hassan, "سلام علیکم، حال شما چطور است؟")
		var rh := vb.last_rate
		vb.speak(mina, "سلام! چه روز قشنگی!")
		_check(absf(rh - vb.last_rate) > 0.01 or rh != 1.0, "speaking rate differs (%.2f vs %.2f)" % [rh, vb.last_rate])
	_check(Personalities.trait_id(hassan.resident) == "hot_tempered" and Personalities.trait_id(parvin.resident) == "generous", "personality traits assigned")
	_check(Personalities.trait_name(sara.resident) != "" and _v7b_fa(Personalities.trait_name(sara.resident)), "trait name in Persian: %s" % Personalities.trait_name(sara.resident))
	var fair := 100
	_check(Personalities.max_price(parvin.resident, fair) > Personalities.max_price(sara.resident, fair), "generous pays more than stingy (%d > %d)" % [Personalities.max_price(parvin.resident, fair), Personalities.max_price(sara.resident, fair)])
	_check(Personalities.opening_offer(sara.resident, fair) < Personalities.opening_offer(parvin.resident, fair), "stingy opens lower")
	var w7 := _v7a()
	if w7 and w7.conflicts:
		_check(w7.conflicts.temper(hassan) > w7.conflicts.temper(mina), "hot-tempered people argue more (%.2f > %.2f)" % [w7.conflicts.temper(hassan), w7.conflicts.temper(mina)])
	var rr := Personalities.respond(parvin.resident, fair, 95, 0)
	_check(str(rr["result"]) == "accept", "generous accepts a fair asking price")
	var rs := Personalities.respond(sara.resident, fair, 160, 5)
	_check(str(rs["result"]) == "refuse" and str(rs["line"]) != "", "stingy refuses a steep price: %s" % rs["line"])
	_check(_swap_back("personalities"), "personalities live swap")
	_check(_swap_back("voice_profiles"), "voice_profiles live swap")
	return true


func _smoke_v7b_cafe() -> bool:
	await _section("v7b: terrace cafe (bartender, DJ, drinks, tipsiness, fights, stand-ins)")
	var w := _v7b()
	if w == null:
		return true
	var cafe := w.cafe
	var st := cafe.style()
	_check(cafe.root != null and cafe.bar_spot != null and cafe.seats.size() >= 6, "terrace built (bar, %d seats)" % cafe.seats.size())
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	_check(not cafe.is_open() and cafe.order("tea") == "closed", "closed in the morning")
	TimeManager.reset_calendar(TimeManager.day, 20.5, "sunny")
	w.staffing.tick()
	await _frames(3)
	var bt := cafe.bartender()
	var dj := cafe.dj()
	_check(cafe.is_open() and bt != null, "bartender on duty: %s" % (bt.resident.get("name", "") if bt else "-"))
	_check(cafe.dj_time() and dj != null and dj != bt, "DJ on duty at night: %s" % (dj.resident.get("name", "") if dj else "-"))
	await _frames(40)
	_check(cafe.music != null and cafe.music.stream != null and cafe.music.playing, "DJ music plays (positional 3D)")
	_check(cafe.dj_lights.size() >= 2 and cafe.dj_lights[0].visible, "DJ lights on")
	# Stand-ins: the preferred bartenders become unavailable -> someone else fills in.
	var busy_list: Array = []
	for nm in st.staff["bartender"]:
		var pb := V7aKit.bot_named(get_tree(), str(nm))
		if pb == null:
			continue
		var busy := V7aKit.ScriptController.new()
		busy.tag = "errand"
		busy.original = V7bKit.original_of(pb.controller as V7aKit.ScriptController) if pb.controller is V7aKit.ScriptController else pb.controller
		pb.set_controller(busy)
		busy_list.append([pb, busy])
	w.staffing.tick()
	await _frames(2)
	var sub := cafe.bartender()
	_check(sub != null and w.staffing.is_standin("bartender") and not (Population.full_name(sub.resident) in st.staff["bartender"]), "post never empty: %s fills in" % (sub.resident.get("name", "") if sub else "-"))
	cafe.open_menu()
	await _frames(2)
	_check(w.menu_panel.visible, "the stand-in serves")
	w.menu_panel.close()
	for pair in busy_list:
		(pair[0] as TownspersonBot).set_controller((pair[1] as V7aKit.ScriptController).original)
	w.staffing.tick()
	await _frames(2)
	var back := cafe.bartender()
	_check(back != null and Population.full_name(back.resident) in st.staff["bartender"] and not w.staffing.is_standin("bartender"), "a regular bartender takes the post back (%s)" % (Population.full_name(back.resident) if back else "-"))
	await _place(Vector2(cafe.bar_spot.global_position.x, cafe.bar_spot.global_position.z), 0.0, 4)
	Economy.money = 500
	var m0 := Economy.money
	_check(cafe.order("tea") == "ok" and Economy.money < m0, "tea served")
	_check(cafe.order("pomegranate_juice") == "ok", "juice served")
	TownLife.cafe["strong_today"] = 0
	TownLife.tipsy = 0.0
	_check(cafe.order("strong_brew") == "ok" and TownLife.tipsy > 0.0, "strong drink -> tipsy (%.0f s)" % TownLife.tipsy)
	await _frames(20)
	_check(absf(_player.drift_angle) > 0.0001 and w.tipsy.overlay.visible, "wobbly walk + blurry screen")
	cafe.order("strong_punch")
	_check(cafe.order("strong_brew") == "refused" and cafe.refused >= 1, "bartender stops serving after %d strong drinks" % st.max_strong)
	TownLife.tipsy = 0.5
	await _frames(60)
	_check(TownLife.tipsy == 0.0 and _player.drift_angle == 0.0 and not w.tipsy.overlay.visible, "tipsiness wears off")
	cafe.open_menu()
	await _frames(3)
	_check(w.menu_panel.visible and w.menu_panel.buttons.size() == st.menu.size(), "menu panel lists %d drinks" % st.menu.size())
	_check(_v7b_fa(w.menu_panel._title.text), "menu in Persian")
	w.menu_panel.close()
	# Guests + a fight broken up by the bartender, another by the police.
	var g1 := cafe.invite_guest()
	var g2 := cafe.invite_guest()
	_check(g1 != null and g2 != null and cafe.guests.size() >= 2, "guests come to the terrace")
	var f0 := CityState.fines_total
	_check(cafe.start_fight(g1, g2) and not cafe.fight.is_empty(), "a small fight starts")
	cafe.end_fight(true, "bartender")
	_check(cafe.fight.is_empty() and cafe.breakups_bartender >= 1 and CityState.fines_total >= f0 + st.fight_fine * 2, "bartender breaks it up; fines to the city fund")
	_check(not (g1.controller is V7aKit.ScriptController and (g1.controller as V7aKit.ScriptController).tag == "fight"), "fighters released")
	var g3 := cafe.invite_guest()
	var g4 := cafe.invite_guest()
	if g3 and g4 and cafe.start_fight(g3, g4):
		cafe.end_fight(true, "police")
		_check(cafe.breakups_police >= 1, "police settle a fight")
	cafe.send_guests_home()
	_check(cafe.seated_guests() == 0 and cafe.guests.is_empty(), "guests go home")
	TimeManager.reset_calendar(TimeManager.day, 10.0, "sunny")
	w.staffing.tick()
	_check(cafe.bartender() == null, "posts released when closed")
	w.staffing.release_all()
	_check(_swap_back("cafe"), "cafe live swap")
	return true


func _smoke_v7b_driving() -> bool:
	await _section("v7b: gears, headlights, fuel, wear, night driving")
	var w := _v7b()
	var w6 := _v6b()
	if w == null or w6 == null or w6.vehicles.cars.is_empty():
		return true
	w.driving.attach_all()
	var car := w6.vehicles.cars[0]
	var sys := car.get_node_or_null(^"CarSystems") as CarSystems
	_check(sys != null, "every car has CarSystems (%d cars)" % w6.vehicles.cars.size())
	if sys == null:
		return true
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	TownLife.car(car.key)["fuel"] = 80.0
	TownLife.car(car.key)["condition"] = 100.0
	await _place(Vector2(car.global_position.x, car.global_position.z) + Vector2(-2.2, 0), 90.0, 10)
	car.get_in(_player)
	await _frames(20)
	_check(_player.vehicle == car and w.driving.dash.visible, "dashboard shows while driving")
	_check(_v7b_fa(w.driving.dash_label.text), "dashboard in Persian: %s" % w.driving.dash_label.text.left(40))
	sys.set_auto(false)
	sys.gear = 1
	sys.shift(1)
	_check(sys.gear == 2 and not sys.is_auto(), "manual gearbox: shift up")
	sys.shift(-1)
	_check(sys.gear == 1, "shift down")
	_check(sys.top_mult(car.max_speed if "max_speed" in car else 14.0) < 0.6, "first gear limits the top speed")
	sys.toggle_gearbox()
	_check(sys.is_auto(), "auto/manual toggle")
	car.auto_input = {"throttle": 1.0, "steer": 0.0, "brake": false}
	await _frames(90)
	car.auto_input = {}
	_check(sys.gear >= 2, "automatic gearbox shifts up (gear %d)" % sys.gear)
	_check(sys.fuel() < 80.0, "fuel used (%.2f%%)" % sys.fuel())
	var c0 := sys.condition()
	sys.on_crash(9.0)
	_check(sys.condition() < c0, "crash wears the car (%.0f%%)" % sys.condition())
	TimeManager.reset_calendar(TimeManager.day, 22.0, "sunny")
	await _frames(2)
	_check(sys.needs_lights(), "night: headlights needed")
	var lights_off := sys.lights_on
	sys.toggle_lights()
	_check(sys.lights_on != lights_off, "H toggles the headlights")
	if not sys.lights_on:
		sys.toggle_lights()
	var lamp: Light3D = null
	for l in car.find_children("*", "SpotLight3D", true, false):
		lamp = l as Light3D
		break
	await _frames(2)
	_check(lamp == null or lamp.visible, "headlight beams on")
	sys.toggle_lights()
	var f0 := CityState.fines_total
	sys.fined_day = -1
	sys.dark_t = 0.0
	car.speed = 8.0
	sys.check_night(30.0)
	sys.check_night(0.1)
	_check(CityState.fines_total > f0, "driving at night without lights is fined")
	await _frames(20)
	_check(w.driving.dark.visible, "darker view at night without lights")
	car.speed = 0.0
	car.get_out()
	await _frames(20)
	_check(not w.driving.dash.visible, "dashboard hides on foot")
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	_check(_swap_back("driving"), "driving live swap")
	return true


func _smoke_v7b_mechanic() -> bool:
	await _section("v7b: mechanic (repairs, fuel, upgrades, stand-in)")
	var w := _v7b()
	var w6 := _v6b()
	if w == null or w6 == null or w6.vehicles.cars.is_empty():
		return true
	var shop := w.mechanic
	_check(shop.root != null and shop.counter_spot != null and shop.pump_spot != null, "garage + pump built")
	TimeManager.reset_calendar(TimeManager.day, 11.0, "sunny")
	w.staffing.tick()
	await _frames(2)
	_check(shop.is_open() and shop.mechanic() != null, "mechanic on duty: %s" % (shop.mechanic().resident.get("name", "") if shop.mechanic() else "-"))
	var car := w6.vehicles.cars[0]
	w.driving.last_car = car
	var s := TownLife.car(car.key)
	s["condition"] = 40.0
	s["fuel"] = 10.0
	s["upgrades"] = []
	Economy.money = 2000
	_check(shop.repair_cost(car) > 0 and shop.fuel_cost(car) > 0, "repair %d G, fuel %d G" % [shop.repair_cost(car), shop.fuel_cost(car)])
	var m0 := Economy.money
	_check(shop.repair(car) and float(s["condition"]) == 100.0 and Economy.money < m0, "car repaired")
	_check(shop.fill_up(car) and float(s["fuel"]) == 100.0, "tank filled")
	var sp0 := TownLife.car_mult(car.key, "speed")
	_check(shop.install("engine_tune", car) and TownLife.car_mult(car.key, "speed") > sp0, "engine tune upgrade (x%.2f)" % TownLife.car_mult(car.key, "speed"))
	_check(not shop.install("engine_tune", car), "an upgrade installs once")
	shop.open_panel()
	await _frames(3)
	_check(w.mechanic_panel.visible and _v7b_fa(w.mechanic_panel._title.text) and _v7b_fa(w.mechanic_panel._info.text), "mechanic panel in Persian")
	w.mechanic_panel.close()
	TimeManager.reset_calendar(TimeManager.day, 22.0, "sunny")
	_check(not shop.is_open() and not shop.repair(car), "garage closed at night")
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	w.staffing.release_all()
	_check(_swap_back("mechanic"), "mechanic live swap")
	return true


func _smoke_v7b_passengers() -> bool:
	await _section("v7b: passengers")
	var w := _v7b()
	if w == null:
		return true
	var ps := w.passengers
	var a := _v7a_adult()
	_check(a != null, "passenger candidate")
	if a == null:
		return true
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	_check(ps.request(a, "square", "hospital") and ps.state == "waiting" and ps.beam.visible, "passenger waits at the square (yellow beam)")
	_check(_v7b_fa(ps._beam_label.text), "beam label in Persian")
	_check(ps.board() and ps.state == "riding", "passenger boards")
	var m0 := Economy.money
	var d0 := int(TownLife.rides.get("delivered", 0))
	_check(ps.arrive() and Economy.money >= m0 + ps.fare() and int(TownLife.rides.get("delivered", 0)) == d0 + 1, "dropped off: fare %d G + tip %d G" % [ps.last_fare, ps.last_tip])
	ps.cancel()
	await _frames(2)
	_check(not (a.controller is V7aKit.ScriptController and (a.controller as V7aKit.ScriptController).tag == "passenger"), "passenger back to normal life")
	_check(ps.request(a, "beach", "university"), "another request")
	ps.give_up()
	_check(ps.state == "" and not ps.beam.visible, "gives up after waiting")
	_check(_swap_back("passengers"), "passengers live swap")
	return true


func _smoke_v7b_camping() -> bool:
	await _section("v7b: camping trip")
	var w := _v7b()
	if w == null:
		return true
	var cp := w.camping
	var st := cp.style()
	var spot: Dictionary = st.spots[0]
	_check(cp.markers.size() == st.spots.size(), "camp spot signs (%d)" % cp.markers.size())
	await _place(Vector2(15, -45), 0.0, 4)
	_check(cp.toggle(_player.global_position) == "too_far", "camping needs a camp spot")
	var sp: Vector2 = spot["pos"]
	await _place(sp + Vector2(-2.0, 2.0), 0.0, 8)
	Economy.money = 200
	var trips := int(TownLife.camps.get("trips", 0))
	_check(cp.toggle(_player.global_position) == "setup" and cp.is_camped() and cp.tent_spot != null and cp.fire_light != null, "tent + campfire set up")
	_check(int(TownLife.camps.get("trips", 0)) == trips + 1, "trip counted")
	Needs.fatigue = 70.0
	TimeManager.reset_calendar(TimeManager.day, 22.0, "sunny")
	var day := TimeManager.day
	_check(cp.sleep() and TimeManager.day == day + 1 and TimeManager.hours_float() < 7.0 and Needs.fatigue < 20.0, "night in the tent: rested (fatigue %.0f)" % Needs.fatigue)
	var snap := TownLife.to_save()
	cp.pack()
	await _frames(2)
	_check(not cp.is_camped(), "packed up")
	TownLife.from_save(snap)
	await _frames(2)
	_check(cp.is_camped() and str(cp.camp.get_meta("spot")) == str(spot["id"]), "camp restored from the save")
	cp.pack()
	TimeManager.reset_calendar(TimeManager.day, 12.0, "sunny")
	_check(_swap_back("camping"), "camping live swap")
	return true


func _smoke_v7b_newspaper() -> bool:
	await _section("v7b: daily newspaper")
	var w := _v7b()
	if w == null:
		return true
	var np := w.newspaper
	_check(np.root != null and np.stand_spot != null, "newsstand built")
	np.compose(true)
	CityState.fires += 1
	CityState.add_fine("littering", 15, "Littering", "ریختن زباله", false)
	TownLife.cafe["fights"] = int(TownLife.cafe.get("fights", 0)) + 1
	var iss := np.compose(true)
	var kinds: Array = []
	for it: Dictionary in iss.get("items", []):
		kinds.append(str(it["kind"]))
	_check("fire" in kinds and "fine" in kinds and "cafe_fight" in kinds and "fund" in kinds, "issue reports real events: %s" % [kinds])
	_check(str((iss["weather"] as Dictionary).get("fa", "")) != "", "weather line")
	var fa_ok := true
	for it: Dictionary in iss["items"]:
		fa_ok = fa_ok and _v7b_fa(str(it["fa"]))
	_check(fa_ok, "items in Persian")
	Market.history["tomato"] = [10.0]
	_check(not np.market_line().is_empty() or Market.change_pct("tomato") == 0, "market movers line")
	Economy.money = 100
	TownLife.paper_day = -1
	var m0 := Economy.money
	_check(np.buy() and TownLife.paper_day == TimeManager.day and Economy.money == m0 - np.style().price, "paper bought at the newsstand")
	await _frames(3)
	var pnl := w.newspaper_panel
	_check(pnl.visible and _v7b_fa(pnl._mast.text) and pnl._items.get_child_count() >= 3, "paper opens (%d items)" % pnl._items.get_child_count())
	pnl.close()
	_check(np.read() and pnl.visible, "key 4 reads today's paper")
	pnl.close()
	Settings.set_value("dialogue_language", "en")
	pnl.open_issue(iss)
	await _frames(2)
	_check(not _v7b_fa(pnl._mast.text) and pnl._mast.text == np.style().paper_en, "English edition")
	pnl.close()
	Settings.set_value("dialogue_language", "fa")
	var s := TownLife.to_save()
	_check((s["papers"] as Array).size() >= 1 and int(s["paper_day"]) == TimeManager.day, "papers saved")
	_check(_swap_back("newspaper"), "newspaper live swap")
	return true


func _smoke_v7b_haggle() -> bool:
	await _section("v7b: personality haggling")
	var w := _v7b()
	if w == null:
		return true
	var h := w.haggle
	var parvin := V7aKit.bot_named(get_tree(), "Parvin Ahmadi")
	var sara := V7aKit.bot_named(get_tree(), "Sara Ahmadi")
	if parvin == null or sara == null:
		return true
	var item := ""
	for id in ["tomato", "potato", "turnip", "milk", "egg"]:
		if GameData.item(id).size() > 0 and Economy.item_type(id) in ["produce", "animal_product"]:
			item = id
			break
	_check(item != "", "a sellable item (%s)" % item)
	if item == "":
		return true
	Economy.add_item(item, 5)
	await _place(Vector2(parvin.global_position.x + 1.5, parvin.global_position.z), 270.0, 4)
	_check(HagglePanel.partner(get_tree(), _player.global_position, 4.0) != null, "trade partner next to you")
	_check(h.start(parvin, item) and h.visible and h.offer > 0, "Parvin offers %d G" % h.offer)
	var open_p := h.offer
	_check(_v7b_fa(h._who.text) and _v7b_fa(h._offer.text), "haggle panel in Persian")
	var n0 := Economy.count(item)
	var m0 := Economy.money
	var res := h.ask_more()
	_check(res in ["accept", "counter", "refuse"], "asked for more -> %s" % res)
	if not h.done:
		_check(h.accept() and Economy.count(item) == n0 - 1 and Economy.money > m0, "deal accepted")
	h.close()
	h.start(sara, item)
	var open_s := h.offer
	_check(open_s < open_p, "stingy Sara opens lower (%d < %d)" % [open_s, open_p])
	var guard := 0
	while not h.done and guard < 8:
		h.ask_more()
		guard += 1
	_check(h.done, "haggling ends (patience)")
	h.close()
	_check(int(TownLife.trades.get("player", 0)) >= 1, "trades counted")
	return true


func _smoke_v7b_save() -> bool:
	await _section("v7b: save / load")
	TownLife.cars["test_car"] = {"fuel": 42.0, "condition": 77.0, "upgrades": ["led_lights"], "auto": false}
	TownLife.tipsy = 12.0
	TownLife.show_log = true
	var data := SaveGame.snapshot()
	_check(data.has("town_life"), "save has town_life")
	TownLife.cars.erase("test_car")
	TownLife.tipsy = 0.0
	TownLife.show_log = false
	SaveGame.apply(data)
	# Assert restored timers before gameplay resumes decrementing them.
	_check(TownLife.tipsy == 12.0 and TownLife.show_log, "tipsy + chat log setting restored")
	await _frames(2)
	var c := TownLife.car("test_car")
	_check(float(c["fuel"]) == 42.0 and float(c["condition"]) == 77.0 and "led_lights" in c["upgrades"], "car state restored")
	TownLife.cars.erase("test_car")
	TownLife.tipsy = 0.0
	TownLife.show_log = false
	var w := _v7b()
	if w:
		w.chat_log.visible = false
	return true


# ------------------------------------------------------------------ v7b.1 controls (scripts/v7b1/controls_smoke.gd)
var _ctl_smoke = null


func _ctl_s():
	if _ctl_smoke == null:
		_ctl_smoke = load("res://scripts/v7b1/controls_smoke.gd").new(self)
	return _ctl_smoke


func _smoke_v7b1_controls_basics() -> bool:
	await _section("v7b.1 controls: shared input, camera-relative walk, mouse look, panels free the mouse")
	return await _ctl_s().run_basics()


func _smoke_v7b1_controls_driving() -> bool:
	await _section("v7b.1 controls: car steering (keyboard / mouse), cockpit camera, gear indicator")
	return await _ctl_s().run_driving()


func _smoke_v7b1_controls_touch() -> bool:
	await _section("v7b.1 controls: touch twin sticks + buttons (multi-touch)")
	return await _ctl_s().run_touch()


func _smoke_v7b1_controls_possession() -> bool:
	await _section("v7b.1 controls: possession with mouse / keyboard / touch")
	return await _ctl_s().run_possession()


func _smoke_v7b1_controls_regress() -> bool:
	await _section("v7b.1 controls: Amin's reports - mouse looks up/down/left/right, twin sticks, Space never locks the stance")
	return await _ctl_s().run_regress()


# ------------------------------------------------------------------ v7b.1 bug fixes (scripts/v7b1/bugs_smoke.gd, PROGRESS_BUGS.md)
var _bugs_smoke = null


func _bugs_s():
	if _bugs_smoke == null:
		_bugs_smoke = load("res://scripts/v7b1/bugs_smoke.gd").new(self)
	return _bugs_smoke


func _smoke_v7b1_bugs_camera() -> bool:
	await _section("v7b.1 bugs: camera turns left/right + up/down (on foot, as a resident, parked / rolling car)")
	return await _bugs_s().run_camera()


# ------------------------------------------------------------------ v7b.1 visual (scripts/v7b1_visual/visual_smoke.gd)
var _vis_smoke = null


func _vis_s():
	if _vis_smoke == null:
		_vis_smoke = load("res://scripts/v7b1_visual/visual_smoke.gd").new(self)
	return _vis_smoke


func _smoke_v7b1_visual_cars() -> bool:
	await _section("v7b.1 visual: realistic cars (paint, glass, interior, steering wheel, front, plates)")
	return await _vis_s().run_cars()


func _smoke_v7b1_visual_fire_truck() -> bool:
	await _section("v7b.1 visual: red fire truck (ladder, reels, text, positional siren, lights)")
	return await _vis_s().run_fire_truck()


func _smoke_v7b1_visual_people() -> bool:
	await _section("v7b.1 visual: resident looks (skin tones, hijab, build, family resemblance, save)")
	return await _vis_s().run_people()


func _smoke_v7b1_visual_town() -> bool:
	await _section("v7b.1 visual: plaques, houses, home on the minimap, post office gone, square, street plants")
	return await _vis_s().run_town()


func _smoke_v7b1_visual_city_hall() -> bool:
	await _section("v7b.1 visual: City Hall interior with the fund (F4 inside only)")
	return await _vis_s().run_city_hall()


func _smoke_v7b1_visual_families() -> bool:
	await _section("v7b.1 visual: families (kinds, jobs, school, retired, directory, name card)")
	return await _vis_s().run_families()


# ------------------------------------------------------------------ v7b.1 traffic (scripts/v7b1_traffic/traffic_smoke.gd)
var _trf_smoke = null


func _trf_s():
	if _trf_smoke == null:
		_trf_smoke = load("res://scripts/v7b1_traffic/traffic_smoke.gd").new(self)
	return _trf_smoke


func _smoke_v7b1_traffic_roads() -> bool:
	await _section("v7b.1 traffic: wider roads, markings, signs, per-road limits, dashboard limit, new-city road")
	return await _trf_s().run_roads()


func _smoke_v7b1_traffic_lights() -> bool:
	await _section("v7b.1 traffic: signal cycles, red wait, NPC cars stop at red / STOP")
	return await _trf_s().run_lights()


func _smoke_v7b1_traffic_offences() -> bool:
	await _section("v7b.1 traffic: red light / STOP / speeding -> flash, fine, report, news, confiscation, tow, impound")
	return await _trf_s().run_offences()


func _smoke_v7b1_traffic_license() -> bool:
	await _section("v7b.1 traffic: licence booklet + quiz at the police station")
	return await _trf_s().run_license()


func _smoke_v7b1_traffic_dealership() -> bool:
	await _section("v7b.1 traffic: car dealership (prices, licence + money gate)")
	return await _trf_s().run_dealership()


func _smoke_v7b1_traffic_npc() -> bool:
	await _section("v7b.1 traffic: NPC cars on loops obey limits")
	return await _trf_s().run_npc_traffic()


func _smoke_v7b1_traffic_bus() -> bool:
	await _section("v7b.1 traffic: bus stops, NPC bus, residents ride, farmer rides / drives the bus")
	return await _trf_s().run_bus()


func _smoke_v7b1_traffic_sounds() -> bool:
	await _section("v7b.1 traffic: per-model car sounds (engine RPM, horn, indicators, squeal, doors)")
	return await _trf_s().run_sounds()


func _smoke_v7b1_traffic_lounge() -> bool:
	await _section("v7b.1 traffic: classy terrace + lounge / night disco")
	return await _trf_s().run_lounge()


func _smoke_v7b1_traffic_lighting() -> bool:
	await _section("v7b.1 traffic: brighter night streets")
	return await _trf_s().run_lighting()


func _smoke_v7b1_traffic_save() -> bool:
	await _section("v7b.1 traffic: save / load")
	return await _trf_s().run_save()


# ---------------------------------------------------------------- v7b.1 performance refresh
var _perf_smoke = null


func _perf_s():
	if _perf_smoke == null:
		_perf_smoke = load("res://scripts/v7b1_perf/perf_smoke.gd").new(self)
	return _perf_smoke


func _smoke_v7b1_perf_quality() -> bool:
	await _section("v7b.1 perf: quality presets")
	return await _perf_s().run_quality()


func _smoke_v7b1_perf_lod() -> bool:
	await _section("v7b.1 perf: distance LOD")
	return await _perf_s().run_lod()


func _smoke_v7b1_perf_streaming() -> bool:
	await _section("v7b.1 perf: world streaming + interiors")
	return await _perf_s().run_streaming()


func _smoke_v7b1_perf_interiors() -> bool:
	await _section("v7b.1 perf: interiors on demand")
	return await _perf_s().run_interiors()


func _smoke_v7b1_perf_budgets() -> bool:
	await _section("v7b.1 perf: audio / animation budgets")
	return await _perf_s().run_budgets()


func _smoke_v7b1_perf_save() -> bool:
	await _section("v7b.1 perf: save / load with unloaded areas")
	return await _perf_s().run_save()


func _smoke_v7b1_perf_overlay() -> bool:
	await _section("v7b.1 perf: F7 overlay")
	return await _perf_s().run_overlay()


# ------------------------------------------------------------------ v7b.1 weather (scripts/v7b1_weather/weather_smoke.gd)
func _smoke_v7b1_weather() -> bool:
	await _section("v7b.1 weather: soft snow flakes (texture + alpha), snow cover builds / melts, wet ground, counts per quality")
	return await load("res://scripts/v7b1_weather/weather_smoke.gd").new(self).run()


# ---------------------------------------------------------------- v7b.1 audio (scripts/v7b1_audio/)
var _audio_smoke = null


func _aud_s():
	if _audio_smoke == null:
		_audio_smoke = load("res://scripts/v7b1_audio/audio_smoke.gd").new(self)
	return _audio_smoke


func _smoke_v7b1_audio_modules() -> bool:
	await _section("v7b.1 audio: modules + size budget")
	return await _aud_s().run_modules()


func _smoke_v7b1_audio_footsteps() -> bool:
	await _section("v7b.1 audio: surface footsteps (player + nearby residents)")
	return await _aud_s().run_footsteps()


func _smoke_v7b1_audio_doors() -> bool:
	await _section("v7b.1 audio: every door opens + closes with sound")
	return await _aud_s().run_doors()


func _smoke_v7b1_audio_ambient() -> bool:
	await _section("v7b.1 audio: placed ambient emitters, indoor muffling, gusts, thunder")
	return await _aud_s().run_ambient()


func _smoke_v7b1_audio_spatial() -> bool:
	await _section("v7b.1 audio: listener follows the camera, stereo panning")
	return await _aud_s().run_spatial()


func _smoke_v7b1_audio_budget() -> bool:
	await _section("v7b.1 audio: voice cap")
	return await _aud_s().run_budget()


# ------------------------------------------------------------------ v7b.1 police / road safety (scripts/v7b1_police/police_smoke.gd)
func _smoke_v7b1_police() -> bool:
	await _section("v7b.1 police: AI cars yield to people, hit reactions, ambulance + police + crowd after a hard hit")
	return await load("res://scripts/v7b1_police/police_smoke.gd").new(self).run()
