extends RefCounted
## v7b.1 performance smoke checks (DevTools sections _smoke_v7b1_perf_*):
## quality presets, distance LOD, cell streaming on teleport, interiors built
## on enter / freed on exit, audio + animation budgets, save/load with
## unloaded areas, F7 overlay.

var t  # DevTools


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func _pw() -> PerfWorld:
	return PerfWorld.instance(_tree())


func _frames(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _sun() -> DirectionalLight3D:
	return _tree().current_scene.get_node_or_null(^"Sun") as DirectionalLight3D


func run_quality() -> bool:
	var pw := _pw()
	t._check(pw != null, "PerfWorld present")
	if pw == null:
		return true
	var ids := []
	for m in Modules.all("quality"):
		ids.append(m.id)
	t._check("low" in ids and "medium" in ids and "high" in ids, "quality presets low / medium / high registered (%s)" % str(ids))
	t._check(str(Settings.DEFAULTS["quality"]) == "auto", "Settings default quality = auto")
	Settings.set_value("quality", "auto")  # the dev box may have a saved choice
	await _frames(2)
	t._check(PerfQuality.key() == "auto" and PerfQuality.style_id() == ("medium" if OS.has_feature("web") else "high"), "default Auto -> %s" % PerfQuality.style_id())
	Settings.set_value("quality", "low")
	await _frames(3)
	var sun := _sun()
	t._check(pw.lod.current_style().id == "low", "Low preset applied")
	t._check(sun != null and not sun.shadow_enabled, "Low: no sun shadows")
	t._check(is_equal_approx(t.get_viewport().scaling_3d_scale, 0.6), "Low: 60% 3D render scale")
	t._check(Engine.max_physics_steps_per_frame == 3, "Low: max 3 physics steps / frame")
	var pool := _tree().current_scene.find_child("LampLights", true, false)
	await _frames(2)
	if pool:
		t._check(int(pool.get("light_count")) == 1, "Low: 1 real lamp light")
	Settings.set_value("quality", "medium")
	await _frames(3)
	t._check(sun != null and sun.shadow_enabled and sun.directional_shadow_mode == DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS and is_equal_approx(sun.directional_shadow_max_distance, 35.0), "Medium: 2 cheap cascades to 35 m")
	t._check(is_equal_approx(t.get_viewport().scaling_3d_scale, 1.0), "Medium: full render scale")
	Settings.set_value("quality", "high")
	await _frames(3)
	t._check(sun != null and sun.shadow_enabled, "High: sun shadows on")
	if pool:
		t._check(int(pool.get("light_count")) == 8, "High: 8 real lamp lights")
	t._check(_tree().physics_interpolation and t._player.physics_interpolation_mode == Node.PHYSICS_INTERPOLATION_MODE_ON, "smooth motion: player physics-interpolated")
	var rig = t._rig
	t._check(is_equal_approx(float(rig.get("follow_speed")), 20.0), "camera follow speed 20 (was 12)")
	# Settings panel button cycles.
	var panel = t._hud.settings_panel
	t._check(panel.get("_quality_btn") != null, "Settings: Graphics button")
	Settings.set_value("quality", "auto")
	panel.call("refresh")
	await _frames(2)
	var b: Button = panel.get("_quality_btn")
	t._check(b != null and b.text == Lang.loc_ui("Graphics: Auto"), "Graphics button label (%s)" % (b.text if b else "?"))
	return true


func run_lod() -> bool:
	var pw := _pw()
	if pw == null:
		return true
	await _frames(4)
	var town := _tree().current_scene.get_node_or_null(^"Town")
	var total := 0
	var ranged := 0
	var small_shadow := 0
	for g in town.find_children("*", "GeometryInstance3D", true, false):
		var gi := g as GeometryInstance3D
		var ancestor := gi.get_parent()
		var hinged := false
		while ancestor and ancestor != town:
			if ancestor is BuildingDoor:
				hinged = true
				break
			ancestor = ancestor.get_parent()
		if hinged:
			t._check(gi.visibility_range_end == 0, "hinged panel stays visible with its streamed building")
			continue
		total += 1
		if gi.visibility_range_end > 0.0:
			ranged += 1
	t._check(total > 0 and ranged >= int(total * 0.8), "LOD: %d / %d town geometries have a visibility range" % [ranged, total])
	var st := pw.lod.current_style()
	for g in _tree().current_scene.find_children("*", "MeshInstance3D", true, false):
		var mi := g as MeshInstance3D
		if mi.mesh == null or not mi.is_inside_tree() or mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
			continue
		var s := mi.get_aabb().size * mi.global_transform.basis.get_scale().abs()
		if maxf(s.x, maxf(s.y, s.z)) < st.shadow_min_size * 0.5 and mi.visibility_range_end > 0.0 and not _under_bot(mi):
			small_shadow += 1
	t._check(small_shadow == 0, "LOD: small props cast no shadows (%d left)" % small_shadow)
	var lights_ok := true
	var nl := 0
	for l in _tree().current_scene.find_children("*", "OmniLight3D", true, false):
		nl += 1
		if not (l as Light3D).distance_fade_enabled:
			lights_ok = false
	t._check(nl > 0 and lights_ok, "LOD: %d point lights fade with distance" % nl)
	# New content from any module is picked up automatically.
	var mi2 := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.3, 0.3)
	mi2.mesh = bm
	_tree().current_scene.add_child(mi2)
	mi2.global_position = Vector3(5, 0.5, 5)
	await _frames(8)
	t._check(mi2.visibility_range_end > 0.0 and mi2.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "LOD: newly added prop gets range %.0f m + no shadow" % mi2.visibility_range_end)
	mi2.queue_free()
	return true


func _under_bot(n: Node) -> bool:
	var p := n.get_parent()
	while p:
		if p is TownspersonBot or p.is_in_group(&"player"):
			return true
		p = p.get_parent()
	return false


func _far_building(from: Vector3) -> Building:
	var best: Building = null
	var bd := 0.0
	for b in _tree().get_nodes_in_group(&"buildings"):
		var d := (b as Node3D).global_position.distance_to(from)
		if d > bd:
			bd = d
			best = b
	return best


func run_streaming() -> bool:
	var pw := _pw()
	if pw == null:
		return true
	var ws := pw.streamer
	ws.enabled = true
	ws.call("_auto_scan")
	t._check(ws.unit_count() > 30, "streaming: %d units registered (buildings, street chunks, props)" % ws.unit_count())
	Settings.set_value("quality", "medium")
	await t._place(Vector2(-3, 7.5), 180.0, 6)
	ws.call("_update_queues", true)
	ws.call("_drain", 999.0)
	await _frames(2)
	var far_b := _far_building(t._player.global_position)
	t._check(far_b != null and far_b.process_mode == Node.PROCESS_MODE_DISABLED, "streaming: far building %s is dormant (process + physics off)" % (far_b.name if far_b else "?"))
	t._check(far_b != null and far_b.visible, "streaming: far building exterior still drawn (LOD handles it)")
	var awake0 := ws.awake_units()
	t._check(awake0 < ws.unit_count(), "streaming: only %d / %d units awake at the farm" % [awake0, ws.unit_count()])
	var late := Node3D.new()
	_tree().current_scene.add_child(late)
	late.global_position = far_b.global_position + Vector3(1, 0, 1)
	ws.register(late, late.global_position)
	t._check(late.process_mode == Node.PROCESS_MODE_DISABLED and not late.visible,
		"streaming: late content in a sleeping cell starts dormant")
	ws.call("_update_queues", false)
	ws.call("_update_queues", false)
	var pending: Array = ws.get("_queue_in")
	var unique := {}
	for key in pending:
		unique[key] = true
	t._check(unique.size() == pending.size(), "streaming: repeated updates do not duplicate pending cells")
	# Builders: called when their cell first loads.
	var hits := []
	ws.register_builder(func(k: Vector2i, _r: Rect2) -> void: hits.append(k))
	# Teleport next to the far building: its cell wakes within a few frames.
	var bp := far_b.global_position
	await t._place(Vector2(bp.x + 6.0, bp.z + 6.0), 0.0, 4)
	await _frames(3)
	t._check(far_b.process_mode != Node.PROCESS_MODE_DISABLED, "streaming: teleport wakes the building's cell at once")
	t._check(ws.is_loaded(bp), "streaming: cell under the player loaded")
	t._check(late.process_mode != Node.PROCESS_MODE_DISABLED and late.visible,
		"streaming: approaching wakes late content too")
	t._check(hits.size() > 0, "streaming: progressive cell builders ran (%d cells)" % hits.size())
	# Back to the farm: the town cell sleeps again (unload with hysteresis).
	await t._place(Vector2(-3, 7.5), 180.0, 4)
	ws.call("_update_queues", true)
	ws.call("_drain", 999.0)
	t._check(far_b.process_mode == Node.PROCESS_MODE_DISABLED, "streaming: leaving unloads the far cell again")
	late.queue_free()
	# Exercise the actual town's deferred builder, without eagerly populating
	# its fixture. A distant job must wait and run exactly once on approach.
	var town := t._town as TownBuilder
	var jobs := []
	town._queue_prop(Vector2(1000, 1000), func() -> void: jobs.append(true))
	town.build_nearby_props()
	t._check(jobs.is_empty(), "town: distant furniture stays uninstantiated")
	var old_pos: Vector3 = t._player.global_position
	t._player.global_position = Vector3(1000, 0, 1000)
	town.build_nearby_props()
	town.build_nearby_props()
	t._check(jobs.size() == 1, "town: approaching builds pending furniture exactly once")
	t._player.global_position = old_pos
	await _exterior_regressions()
	return true


func run_interiors() -> bool:
	var home: Building = null
	for b in _tree().get_nodes_in_group(&"buildings"):
		if str(b.get("kind")) == "home" and str(b.get("layout_id")) != "farmhouse" and not bool(b.get("sleep_here")):
			home = b
			break
	t._check(home != null, "interiors: found a home")
	if home == null:
		return true
	var eager_children := home.interior_root.get_child_count()
	InteriorStreamer.force_lazy = 1
	await t._place(Vector2(-3, 7.5), 180.0, 2)
	home.restyle()
	await _frames(2)
	t._check(not home.interior_built and home.interior_root.get_child_count() < eager_children, "interiors: home %s not furnished while far (%d < %d nodes)" % [home.layout_id, home.interior_root.get_child_count(), eager_children])
	var door := home.door_world_position(2.0)
	await t._place(Vector2(door.x, door.z), 0.0, 25)
	t._check(home.interior_built and home.interior_root.get_child_count() == eager_children, "interiors: furnished at the door (%d nodes, same as eager)" % home.interior_root.get_child_count())
	var built := InteriorStreamer.builds_total
	await t._place(Vector2(-3, 7.5), 180.0, 4)
	home.set("_interior_far_time", 999.0)
	home.release_interior()
	await _frames(2)
	t._check(not home.interior_built and home.interior_root.get_child_count() < eager_children, "interiors: freed after leaving")
	home.ensure_interior()
	await _frames(1)
	t._check(home.interior_built and InteriorStreamer.builds_total == built + 1, "interiors: rebuilt deterministically on the next visit")
	# Generic API for other modules' interiors.
	var anchor := Node3D.new()
	_tree().current_scene.add_child(anchor)
	anchor.global_position = Vector3(40, 0, 40)
	var state := {"built": 0, "freed": 0}
	_pw().interiors.register_interior(anchor, func() -> void: state["built"] += 1, func() -> void: state["freed"] += 1, 10.0)
	await t._place(Vector2(41, 41), 0.0, 22)
	t._check(int(state["built"]) == 1, "interiors: registered interior built on approach")
	await t._place(Vector2(-3, 7.5), 0.0, 22)
	t._check(int(state["freed"]) == 1, "interiors: registered interior freed when far")
	_pw().interiors.unregister_interior(anchor)
	# City Hall furniture (visual workstream) streams the same way in the game.
	var ch := _tree().current_scene.find_child("CityHallInterior", true, false)
	if ch and ch.get("building"):
		var chb := ch.get("building") as Node3D
		t._check(_pw().hook_city_hall(), "interiors: City Hall interior registered for streaming")
		var cp := chb.global_position
		await t._place(Vector2(cp.x + 3.0, cp.z + 3.0), 0.0, 22)
		t._check(is_instance_valid(ch.get("props")), "interiors: City Hall furnished on approach")
		await t._place(Vector2(-3, 7.5), 0.0, 22)
		await _frames(2)
		t._check(not is_instance_valid(ch.get("props")), "interiors: City Hall furniture freed when far")
		_pw().interiors.unregister_interior(chb)
		chb.remove_meta(&"perf_interior_hooked")
		ch.call("ensure_built")
	anchor.queue_free()
	InteriorStreamer.force_lazy = -1
	home.restyle()
	await _frames(2)
	t._check(home.interior_built and home.interior_root.get_child_count() == eager_children, "interiors: eager again for the other sections")
	return true


func run_budgets() -> bool:
	var pw := _pw()
	if pw == null:
		return true
	await t._place(Vector2(-3, 7.5), 180.0, 4)
	var cam: Camera3D = t.get_viewport().get_camera_3d()
	var far_p: Vector3 = cam.global_position + Vector3(0, 0, -400)
	var a := AudioStreamPlayer3D.new()
	var gen := AudioStreamGenerator.new()
	a.stream = gen
	_tree().current_scene.add_child(a)
	a.global_position = far_p
	a.play()
	var holder := Node3D.new()
	_tree().current_scene.add_child(holder)
	holder.global_position = far_p
	var ap := AnimationPlayer.new()
	holder.add_child(ap)
	pw.audio.set_process(true)
	pw.anims.set_process(true)
	pw.audio.set("_cache_age", 99.0)
	pw.anims.set("_list_age", 99.0)
	pw.audio.set("_timer", 0.0)
	pw.anims.set("_timer", 0.0)
	await _frames(4)
	t._check(a.stream_paused, "audio: far positional sound paused (no mixing)")
	t._check(not ap.active, "animation: far AnimationPlayer stopped")
	a.global_position = cam.global_position + Vector3(0, 0, -3)
	holder.global_position = cam.global_position + Vector3(0, 0, -3)
	pw.audio.set("_timer", 0.0)
	pw.anims.set("_timer", 0.0)
	await _frames(4)
	t._check(not a.stream_paused, "audio: resumes when near")
	t._check(ap.active, "animation: resumes when near")
	# Sfx cache release.
	var sfx: Node = t.get_node_or_null(^"/root/Sfx")
	if sfx and "_cache" in sfx:
		(sfx.get("_cache") as Dictionary)["__perf_test"] = null
		pw.audio.call("_release_cache", 999.0)
		pw.audio.set("_last_used", {"__perf_test": 0})
		pw.audio.call("_release_cache", 0.001)
		t._check(not (sfx.get("_cache") as Dictionary).has("__perf_test"), "audio: idle cached stream released")
	a.queue_free()
	holder.queue_free()
	return true


func run_save() -> bool:
	var pw := _pw()
	if pw == null:
		return true
	var ws := pw.streamer
	ws.enabled = true
	await t._place(Vector2(-3, 7.5), 180.0, 4)
	ws.call("_update_queues", true)
	ws.call("_drain", 999.0)
	t._check(ws.awake_units() < ws.unit_count(), "save: areas unloaded before saving")
	var money0 := Economy.money
	t._check(SaveGame.save_game(), "save: saved with unloaded areas")
	Economy.money = money0 + 123
	t._check(SaveGame.load_game(), "save: loaded with unloaded areas")
	await _frames(4)
	t._check(Economy.money == money0, "save: money restored (%d)" % Economy.money)
	t._check(CityState.to_save() is Dictionary and TownLife.to_save() is Dictionary, "save: city + town data still available for unloaded areas")
	var far_b := _far_building(t._player.global_position)
	t._check(far_b != null and far_b.process_mode == Node.PROCESS_MODE_DISABLED, "save: far building stays dormant after load (data, not nodes)")
	# Leave everything awake for the remaining sections.
	_wake_all(ws)
	ws.enabled = false
	return true


func _wake_all(ws: WorldStreamer) -> void:
	for u in ws.get("_units"):
		ws.call("_set_awake", u, true)
	for k in (ws.get("_by_key") as Dictionary).keys():
		(ws.get("_loaded") as Dictionary)[k] = true


func run_overlay() -> bool:
	var pw := _pw()
	if pw == null:
		return true
	var ov := pw.overlay
	t._check(not ov.panel.visible, "overlay hidden by default")
	var e := InputEventKey.new()
	e.physical_keycode = KEY_F7
	e.pressed = true
	Input.parse_input_event(e)
	await _frames(3)
	var e2 := InputEventKey.new()
	e2.physical_keycode = KEY_F7
	e2.pressed = false
	Input.parse_input_event(e2)
	await _frames(2)
	t._check(ov.panel.visible, "F7 opens the performance overlay")
	ov.call("_collect")
	ov.call("_refresh")
	t._check(ov.stats.has("draw_calls") and ov.stats.has("p95") and ov.stats.has("cells"), "overlay stats: fps, p50/p95/p99, draw calls, cells, interiors, sounds")
	t._check(ov.panel.theme != null and ov.label.text.length() > 20, "overlay uses the UI theme (Persian font)")
	ov.toggle()
	t._check(not ov.panel.visible, "F7 closes it")
	return true


func _exterior_regressions() -> void:
	var old_lazy := Building.force_exterior_lazy
	var old_interior := InteriorStreamer.force_lazy
	Building.force_exterior_lazy = 1
	InteriorStreamer.force_lazy = 1
	var town: TownBuilder = t._town
	var before: Dictionary = town.buildings
	var position_before: Vector3 = t._player.global_position
	var fixtures: Array[Building] = []
	for offset in [Vector3(10, 0, 0), Vector3(20, 0, 0), Vector3(500, 0, 500)]:
		var b := Building.new()
		b.layout_id = "maple3"
		_tree().current_scene.add_child(b)
		b.global_position = position_before + offset
		fixtures.append(b)
	var near := fixtures[0]
	var door_before := near.door
	var interior_before := near.interior_root
	var shapes := near._body.get_child_count()
	var attachment := Node3D.new()
	near.add_child(attachment)
	t._check(fixtures.all(func(b: Building) -> bool: return not b.exterior_built and b.exterior_mesh == null), "exteriors: initial logical buildings contain no heavy exterior meshes")
	t._check(door_before != null and interior_before != null and shapes >= 6, "exteriors: doors, interior anchors and collision exist before visual construction")
	town.buildings = {"one": fixtures[0], "two": fixtures[1], "far": fixtures[2]}
	town.stream_buildings(0.0)
	t._check(fixtures[0].exterior_built and not fixtures[1].exterior_built and not fixtures[2].exterior_built, "exteriors: nearest first, at most one construction per frame, distant building stays pending")
	town.stream_buildings(0.0)
	t._check(fixtures[1].exterior_built and not fixtures[2].exterior_built, "exteriors: next nearby building loads on the next scheduler pass")
	t._check(near._body.get_child_count() == shapes, "exteriors: visual construction does not duplicate structural collision")
	near.ensure_interior()
	near.release_exterior()
	near.ensure_exterior()
	t._check(near.door == door_before and near.interior_root == interior_before and attachment.get_parent() == near and near.interior_built, "exteriors: unloading/reloading preserves door, furniture and module-owned attachments")
	BuildingDamage.apply(near, "burned", 0.8)
	near.release_exterior()
	near.ensure_exterior()
	t._check(not near.get_node("RoofParts").visible, "exteriors: damage survives unloading and re-entry")
	t._player.global_position = fixtures[2].global_position
	town.stream_buildings(16.0)
	t._check(fixtures[2].exterior_built and not fixtures[0].exterior_built and not fixtures[1].exterior_built, "exteriors: teleport loads the destination and releases distant visual geometry")
	town.buildings = before
	t._player.global_position = position_before
	Building.force_exterior_lazy = old_lazy
	InteriorStreamer.force_lazy = old_interior
	for b in fixtures:
		b.queue_free()
	await _frames(2)
	var map := _tree().get_first_node_in_group(&"minimap") as Minimap
	t._check(map != null and map.size.x <= 150.0, "minimap: compact responsive widget")
	if map:
		t._check(map._labels.size() == TownLayout.BUILDINGS.size(), "minimap: every layout location has a label independent of rendered buildings")
		var names_ok := true
		for b in TownLayout.BUILDINGS:
			names_ok = names_ok and not map.place_name(b).is_empty() and Lang.renders(map.place_name(b))
		t._check(names_ok, "minimap: all place names render in the selected language")
