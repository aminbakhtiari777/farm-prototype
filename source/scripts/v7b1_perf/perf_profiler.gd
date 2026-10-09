extends Node
## Dev-only profiler (never in normal play). Started with
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . -- --perf-profile=/tmp/out.json
## Census (nodes / meshes / lights / audio / animation / physics / processing scripts),
## per-view rendering info (draw calls, objects, primitives, fps, process + physics + render
## CPU/GPU ms) and an ablation pass (switch a subsystem off, measure the saving) so the
## biggest bottleneck is measured instead of guessed. Portable: no v7b1-only classes.

var _out: String = "/tmp/perf-profile.json"
var _report: Dictionary = {}
var _player: Node3D
var _rig: Node
var _vp_rid: RID
var _settle: int = 10  ## frames to settle before a sample (llvmpipe is ~1 s / frame)
var _n: int = 8  ## frames per sample
var _tri_cache: Dictionary = {}


var _walk_mode: bool = false
var _event_frames: Array = []


## Script class by name (portable: the v7b baseline has no perf classes).
func _class_or_null(cname: String) -> Variant:
	for c in ProjectSettings.get_global_class_list():
		if str(c["class"]) == cname:
			return load(str(c["path"]))
	return null
var _added: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-profile="):
			_out = arg.substr(15)
		elif arg.begins_with("--perf-walk="):
			_out = arg.substr(12)
			_walk_mode = true
	_report["boot_ms_at_ready"] = Time.get_ticks_msec()
	get_tree().node_added.connect(func(_n: Node) -> void: _added += 1)
	var shot := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-shot="):
			shot = arg.substr(12)
	if shot != "":
		_run_shot.call_deferred(shot)
	elif OS.get_cmdline_user_args().has("--perf-camera"):
		_run_camera.call_deferred()
	elif OS.get_cmdline_user_args().has("--perf-physics"):
		_run_physics.call_deferred()
	elif _walk_mode:
		_run_walk.call_deferred()
	else:
		_run.call_deferred()


func _pct(arr: Array, q: float) -> float:
	if arr.is_empty():
		return 0.0
	var a := arr.duplicate()
	a.sort()
	return snappedf(float(a[clampi(int(q * (a.size() - 1)), 0, a.size() - 1)]), 0.01)


## Walk a fixed route (farm -> town square -> main street -> market) by pressing
## move_forward with the camera turned toward the next waypoint. Records every
## frame's wall time (headless = scripts + physics only, no GPU).
func _walk_route(frames: int) -> Dictionary:
	var route: Array = [Vector2(-3, 7.5), Vector2(-3, -20), TownLayout.TOWN_CENTER + Vector2(0, 14), TownLayout.TOWN_CENTER,
		Vector2(0, -50), TownLayout.MARKET_CENTER, Vector2(20, -60), Vector2(-20, -80)]
	_player.global_position = Vector3(route[0].x, Terrain.height_at(route[0].x, route[0].y) + 0.05, route[0].y)
	await _frames(10)
	var times: Array = []
	var phys: Array = []
	var wp := 1
	var added0 := _added
	var obj0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var dist := 0.0
	var lastp := _player.global_position
	Input.action_press(&"move_forward")
	Input.action_press(&"sprint")
	var last := Time.get_ticks_usec()
	var stuck := 0
	var spikes: Array = []
	var ws := get_tree().get_first_node_in_group(&"world_streamer")
	var ist: Variant = _class_or_null("InteriorStreamer")
	var prev_added := _added
	var prev_wakes := int(ws.get("wakes")) if ws else 0
	var prev_sleeps := int(ws.get("sleeps")) if ws else 0
	var prev_builds := int(ist.get("builds_total")) if ist else 0
	var prev_frees := int(ist.get("frees_total")) if ist and "frees_total" in ist else 0
	for i in frames:
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		var ms := (now - last) / 1000.0
		times.append(ms)
		last = now
		# Spike attribution: what happened in this frame (robust to box noise).
		var ev := {"added": _added - prev_added}
		if ws:
			ev["wakes"] = int(ws.get("wakes")) - prev_wakes
			ev["sleeps"] = int(ws.get("sleeps")) - prev_sleeps
			prev_wakes = int(ws.get("wakes"))
			prev_sleeps = int(ws.get("sleeps"))
		if ist:
			ev["builds"] = int(ist.get("builds_total")) - prev_builds
			prev_builds = int(ist.get("builds_total"))
		prev_added = _added
		ev["phys_ms"] = snappedf(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0, 0.1)
		if ms > 25.0:
			ev["frame"] = i
			ev["ms"] = snappedf(ms, 0.1)
			ev["pos"] = "%.0f,%.0f" % [_player.global_position.x, _player.global_position.z]
			spikes.append(ev)
		elif ev["added"] > 0 or ev.get("wakes", 0) > 0 or ev.get("builds", 0) > 0:
			_event_frames.append(ms)
		phys.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		var pp := _player.global_position
		var moved := Vector2(pp.x - lastp.x, pp.z - lastp.z).length()
		dist += moved
		lastp = pp
		stuck = stuck + 1 if moved < 0.01 else 0
		var tgt: Vector2 = route[wp]
		var to := tgt - Vector2(pp.x, pp.z)
		if to.length() < 2.5 or stuck > 40:
			if stuck > 40:
				_player.global_position = Vector3(tgt.x, Terrain.height_at(tgt.x, tgt.y) + 0.1, tgt.y)
				stuck = 0
			wp = (wp + 1) % route.size()
			continue
		# Camera behind the player looking toward the waypoint (forward = camera dir).
		if _rig.has_method("snap_view"):
			_rig.snap_view(rad_to_deg(atan2(-to.x, -to.y)), -14.0, 7.0)
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	return {"frames": times.size(), "p50_ms": _pct(times, 0.5), "p95_ms": _pct(times, 0.95), "p99_ms": _pct(times, 0.99),
		"max_ms": _pct(times, 1.0), "mean_ms": snappedf(times.reduce(func(a: float, b: float) -> float: return a + b, 0.0) / maxf(times.size(), 1), 0.01),
		"physics_p50_ms": _pct(phys, 0.5), "physics_p99_ms": _pct(phys, 0.99), "walked_m": snappedf(dist, 0.1),
		"nodes_added": _added - added0, "objects_delta": Performance.get_monitor(Performance.OBJECT_COUNT) - obj0,
		"spikes_over_33ms": times.filter(func(t: float) -> bool: return t > 33.3).size(),
		"spikes": spikes.slice(0, 60), "event_frames_p50_ms": _pct(_event_frames, 0.5), "event_frames_max_ms": _pct(_event_frames, 1.0),
		"event_frames": _event_frames.size()}


func _run_walk() -> void:
	await _frames(40)
	_report["first_frames_ms"] = Time.get_ticks_msec()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_rig = get_tree().get_first_node_in_group(&"camera_rig")
	TimeManager.reset_calendar(3, 12.0, "sunny")
	await _frames(20)
	var frames := 900
	var walk_only := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--walk-frames="):
			frames = int(arg.substr(14))
		elif arg == "--walk-only":
			walk_only = true
		elif arg == "--perf-no-stream":
			var w := get_tree().get_first_node_in_group(&"world_streamer")
			if w:
				w.set("enabled", false)
				_report["no_stream"] = true
		elif arg == "--perf-eager-interiors":
			var c: Variant = _class_or_null("InteriorStreamer")
			if c:
				c.set("force_lazy", 0)
				for b in get_tree().get_nodes_in_group(&"buildings"):
					if b.has_method("ensure_interior"):
						b.call("ensure_interior")
				_report["eager_interiors"] = true
		elif arg.begins_with("--perf-quality="):
			Settings.set_value("quality", arg.substr(15))
			await _frames(10)
	_report["quality"] = str(Settings.get_value("quality")) if "quality" in Settings.values else "n/a"
	_report["walk"] = await _walk_route(frames)
	print("PERFWALK base ", JSON.stringify(_report["walk"]))
	if walk_only:
		_save_and_quit()
		return
	# Attribute: disable each processing script in turn and re-walk a short loop.
	var by := (census()["processing_by_script"] as Array)
	_report["census"] = census()
	var abl := {}
	var short := maxi(frames / 3, 200)
	var base_short := await _walk_route(short)
	abl["_base"] = base_short
	print("PERFWALK short_base ", JSON.stringify(base_short))
	for e: Array in by:
		var fname: String = e[0]
		if fname in ["player.gd", "follow_camera.gd", "perf_profiler.gd"]:
			continue
		var ls := _nodes_where(func(n: Node) -> bool: return n.get_script() != null and (n.get_script() as Script).resource_path.get_file() == fname and n != self and n != _player and n != _rig)
		var st: Array = []
		for a: Node in ls:
			st.append([a, a.is_processing(), a.is_physics_processing()])
			a.set_process(false)
			a.set_physics_process(false)
		var r := await _walk_route(short)
		for x: Array in st:
			if is_instance_valid(x[0]):
				(x[0] as Node).set_process(x[1])
				(x[0] as Node).set_physics_process(x[2])
		r["d_mean_ms"] = snappedf(float(r["mean_ms"]) - float(base_short["mean_ms"]), 0.01)
		r["d_p95_ms"] = snappedf(float(r["p95_ms"]) - float(base_short["p95_ms"]), 0.01)
		r["d_p99_ms"] = snappedf(float(r["p99_ms"]) - float(base_short["p99_ms"]), 0.01)
		abl[fname] = r
		print("PERFWALK without %-28s d_mean=%6.2f d_p95=%6.2f d_p99=%6.2f (n=%d)" % [fname, r["d_mean_ms"], r["d_p95_ms"], r["d_p99_ms"], int(e[1])])
	_report["walk_ablation"] = abl
	_save_and_quit()


func _save_and_quit() -> void:
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("PERFWALK DONE -> ", _out)
	get_tree().quit(0)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _sample(n: int = -1) -> Dictionary:
	if n < 0:
		n = _n
	var acc := {"fps": 0.0, "process_ms": 0.0, "physics_ms": 0.0, "render_cpu_ms": 0.0, "render_gpu_ms": 0.0,
		"draw_calls": 0.0, "objects": 0.0, "primitives": 0.0, "frame_ms": 0.0}
	var last := Time.get_ticks_usec()
	for i in n:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		acc["frame_ms"] += (now - last) / 1000.0
		last = now
		acc["fps"] += Performance.get_monitor(Performance.TIME_FPS)
		acc["process_ms"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		acc["physics_ms"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		acc["render_cpu_ms"] += RenderingServer.viewport_get_measured_render_time_cpu(_vp_rid) + RenderingServer.get_frame_setup_time_cpu()
		acc["render_gpu_ms"] += RenderingServer.viewport_get_measured_render_time_gpu(_vp_rid)
		acc["draw_calls"] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		acc["objects"] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		acc["primitives"] += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	for k in acc:
		acc[k] = snappedf(acc[k] / n, 0.01)
	return acc


func _walk(n: Node, out: Array) -> void:
	out.append(n)
	for c in n.get_children(true):
		_walk(c, out)


func census() -> Dictionary:
	var all: Array = []
	_walk(get_tree().root, all)
	var c := {"nodes": all.size(), "mesh_instances": 0, "mesh_visible": 0, "multimesh_instances": 0, "multimesh_total_instances": 0,
		"omni_spot_lights": 0, "lights_visible": 0, "lights_shadow": 0, "audio_players": 0, "audio_playing": 0,
		"animation_players": 0, "animation_active": 0, "animation_trees": 0, "skeletons": 0, "physics_bodies": 0,
		"character_bodies": 0, "rigid_bodies": 0, "areas": 0, "collision_shapes": 0, "processing_nodes": 0,
		"physics_processing_nodes": 0, "gpu_particles": 0, "cpu_particles": 0, "geometry_cast_shadow": 0,
		"geometry_with_vis_range": 0, "labels3d": 0}
	var by_script: Dictionary = {}
	for n: Node in all:
		if n is MeshInstance3D:
			c["mesh_instances"] += 1
			if (n as Node3D).is_visible_in_tree():
				c["mesh_visible"] += 1
		elif n is MultiMeshInstance3D:
			c["multimesh_instances"] += 1
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm:
				c["multimesh_total_instances"] += mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
		if n is GeometryInstance3D:
			var g := n as GeometryInstance3D
			if g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and g.is_visible_in_tree():
				c["geometry_cast_shadow"] += 1
			if g.visibility_range_end > 0.0:
				c["geometry_with_vis_range"] += 1
		if n is Label3D:
			c["labels3d"] += 1
		if n is OmniLight3D or n is SpotLight3D:
			c["omni_spot_lights"] += 1
			var l := n as Light3D
			if l.is_visible_in_tree() and l.light_energy > 0.001:
				c["lights_visible"] += 1
				if l.shadow_enabled:
					c["lights_shadow"] += 1
		if n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D:
			c["audio_players"] += 1
			if n.playing:
				c["audio_playing"] += 1
		if n is AnimationPlayer:
			c["animation_players"] += 1
			if (n as AnimationPlayer).is_playing() and (n as AnimationPlayer).active:
				c["animation_active"] += 1
		if n is AnimationTree:
			c["animation_trees"] += 1
		if n is Skeleton3D:
			c["skeletons"] += 1
		if n is PhysicsBody3D:
			c["physics_bodies"] += 1
		if n is CharacterBody3D:
			c["character_bodies"] += 1
		if n is RigidBody3D:
			c["rigid_bodies"] += 1
		if n is Area3D:
			c["areas"] += 1
		if n is CollisionShape3D:
			c["collision_shapes"] += 1
		if n is GPUParticles3D:
			c["gpu_particles"] += 1
		if n is CPUParticles3D:
			c["cpu_particles"] += 1
		var p := n.is_processing()
		var pp := n.is_physics_processing()
		if p:
			c["processing_nodes"] += 1
		if pp:
			c["physics_processing_nodes"] += 1
		if (p or pp) and n.get_script() != null:
			var path: String = (n.get_script() as Script).resource_path.get_file()
			by_script[path] = int(by_script.get(path, 0)) + 1
	c["static_mem_mb"] = snappedf(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0, 0.1)
	c["video_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / 1048576.0, 0.1)
	c["texture_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / 1048576.0, 0.1)
	c["buffer_mem_mb"] = snappedf(Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / 1048576.0, 0.1)
	c["objects"] = Performance.get_monitor(Performance.OBJECT_COUNT)
	c["resources"] = Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	var keys := by_script.keys()
	keys.sort_custom(func(a: String, b: String) -> bool: return int(by_script[a]) > int(by_script[b]))
	var top: Array = []
	for k in keys.slice(0, 40):
		top.append([k, by_script[k]])
	c["processing_by_script"] = top
	return c


func _tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var id := mesh.get_instance_id()
	if _tri_cache.has(id):
		return _tri_cache[id]
	var t := 0
	for i in mesh.get_surface_count():
		var arr := mesh.surface_get_arrays(i)
		if arr.is_empty():
			continue
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			t += (idx as PackedInt32Array).size() / 3
		else:
			t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	_tri_cache[id] = t
	return t


func _category(n: Node) -> String:
	var scene := get_tree().current_scene
	var p: Node = n
	var child_of_building := ""
	while p != null and p != scene:
		var sc: Script = p.get_script()
		if sc:
			var f := sc.resource_path.get_file()
			if f == "humanoid_model_visual.gd" or f == "animated_model_visual.gd":
				return "Humanoid"
			if f == "building.gd":
				return "Building/" + child_of_building
		child_of_building = p.name
		p = p.get_parent()
	var rel := str(scene.get_path_to(n)).split("/")
	var a := rel[0]
	var b := rel[1] if rel.size() > 2 else ""
	var re := RegEx.create_from_string("[-_]?\\d+")
	return re.sub(a + "/" + b, "", true)


## Draw-call (surfaces) and triangle estimate per category for every visible geometry
## within its visibility range of the active camera (frustum ignored, x2 when it casts shadows).
func geometry_breakdown() -> Dictionary:
	var cam := get_viewport().get_camera_3d()
	var all: Array = []
	_walk(get_tree().current_scene, all)
	var cats := {}
	for n: Node in all:
		if not (n is GeometryInstance3D) or not (n as Node3D).is_visible_in_tree():
			continue
		var g := n as GeometryInstance3D
		var d := cam.global_position.distance_to(g.global_position) if cam else 0.0
		if g.visibility_range_end > 0.0 and d > g.visibility_range_end + g.visibility_range_end_margin and not (n is MultiMeshInstance3D):
			continue
		var surf := 0
		var tris := 0
		if n is MeshInstance3D:
			var m := (n as MeshInstance3D).mesh
			if m:
				surf = m.get_surface_count()
				tris = _tris(m)
		elif n is MultiMeshInstance3D:
			var mm := (n as MultiMeshInstance3D).multimesh
			if mm and mm.mesh:
				var cnt := mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count
				if g.visibility_range_end > 0.0 and d > g.visibility_range_end + 60.0:
					continue
				surf = mm.mesh.get_surface_count()
				tris = _tris(mm.mesh) * cnt
		elif n is Label3D:
			surf = 1
			tris = 2 * (n as Label3D).text.length()
		else:
			surf = 1
		var shadow := g.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var cat := _category(n)
		if not cats.has(cat):
			cats[cat] = {"nodes": 0, "surfaces": 0, "tris": 0, "shadow_nodes": 0}
		var e: Dictionary = cats[cat]
		e["nodes"] += 1
		e["surfaces"] += surf
		e["tris"] += tris
		if shadow:
			e["shadow_nodes"] += 1
	var keys := cats.keys()
	keys.sort_custom(func(x: String, y: String) -> bool: return int(cats[x]["tris"]) > int(cats[y]["tris"]))
	var out := {}
	for k in keys.slice(0, 30):
		out[k] = cats[k]
		print("PERFPROF geo %-40s %s" % [k, JSON.stringify(cats[k])])
	var keys2 := cats.keys()
	keys2.sort_custom(func(x: String, y: String) -> bool: return int(cats[x]["surfaces"]) > int(cats[y]["surfaces"]))
	for k in keys2.slice(0, 15):
		print("PERFPROF geo-surf %-40s %s" % [k, JSON.stringify(cats[k])])
	return out


func _place(p: Vector2, cam_yaw: float, pitch: float, dist: float) -> void:
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.05, p.y)
	if _rig.has_method("snap_view"):
		_rig.snap_view(cam_yaw, pitch, dist)


func _views() -> Array:
	return [
		["farm", Vector2(-3, 7.5), 0.0, -18.0, 9.0],
		["town_square", TownLayout.TOWN_CENTER + Vector2(0, 14), 0.0, -12.0, 8.0],
		["main_street", Vector2(0, -50), 90.0, -10.0, 7.0],
		["market", TownLayout.MARKET_CENTER + Vector2(-1.5, 9.0), 20.0, -14.0, 9.0],
		["beach", Vector2(29.0, 25.0), -120.0, -12.0, 9.0],
		["overview", Vector2(0, -50), 0.0, -60.0, 120.0],
	]


## Switch something off, measure, switch it back.
func _ablate(label: String, apply: Callable, restore: Callable, base: Dictionary) -> Dictionary:
	var undo: Variant = apply.call()
	await _frames(_settle)
	var s := await _sample()
	restore.call(undo)
	await _frames(10)
	var d := {}
	for k in ["fps", "frame_ms", "process_ms", "physics_ms", "render_cpu_ms", "render_gpu_ms", "draw_calls", "objects", "primitives"]:
		d[k] = s[k]
		d["d_" + k] = snappedf(float(s[k]) - float(base[k]), 0.01)
	print("PERFPROF ablate %-24s %s" % [label, JSON.stringify(d)])
	return d


func _nodes_where(pred: Callable) -> Array:
	var all: Array = []
	_walk(get_tree().current_scene, all)
	return all.filter(pred)


func _run() -> void:
	await _frames(40)
	_report["first_frames_ms"] = Time.get_ticks_msec()
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_rig = get_tree().get_first_node_in_group(&"camera_rig")
	if _player == null or _rig == null:
		push_error("perf profiler: no player/rig")
		get_tree().quit(1)
		return
	_vp_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vp_rid, true)
	if TimeManager.has_method("reset_calendar"):
		TimeManager.reset_calendar(3, 12.0, "sunny")
		TimeManager.set_paused(true)
	await _frames(30)
	_report["renderer"] = str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	_report["census"] = census()
	print("PERFPROF census ", JSON.stringify(_report["census"]))
	var views := {}
	for v: Array in _views():
		_place(v[1], v[2], v[3], v[4])
		await _frames(_settle * 2)
		views[v[0]] = await _sample()
		if v[0] == "farm" or v[0] == "town_square":
			_report["geometry_" + str(v[0])] = geometry_breakdown()
		print("PERFPROF view %-12s %s" % [v[0], JSON.stringify(views[v[0]])])
	_report["views_noon"] = views
	# Night (lamps + windows on) at the square.
	TimeManager.reset_calendar(3, 22.0, "sunny")
	TimeManager.set_paused(true)
	var vs: Array = _views()[1]
	_place(vs[1], vs[2], vs[3], vs[4])
	await _frames(60)
	_report["night_square"] = await _sample()
	_report["census_night"] = census()
	print("PERFPROF night_square ", JSON.stringify(_report["night_square"]))
	if OS.get_cmdline_user_args().has("--perf-views-only"):
		_report["shadow_casters_visible"] = _nodes_where(func(n: Node) -> bool: return n is GeometryInstance3D and (n as GeometryInstance3D).is_visible_in_tree() and (n as GeometryInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF).size()
		var sun := get_tree().current_scene.get_node_or_null(^"Sun") as DirectionalLight3D
		if sun:
			_report["sun"] = {"shadow": sun.shadow_enabled, "mode": sun.directional_shadow_mode, "max_distance": sun.directional_shadow_max_distance}
			# Shadow share of the frame: same view with the sun's shadow off.
			var with_sh: Dictionary = await _sample()
			var was := sun.shadow_enabled
			sun.shadow_enabled = false
			await _frames(_settle)
			var no_sh: Dictionary = await _sample()
			sun.shadow_enabled = was
			_report["shadow_share_night_square"] = {"with": with_sh, "without": no_sh,
				"shadow_draw_calls": float(with_sh["draw_calls"]) - float(no_sh["draw_calls"]),
				"shadow_primitives": float(with_sh["primitives"]) - float(no_sh["primitives"])}
			print("PERFPROF shadow_share ", JSON.stringify(_report["shadow_share_night_square"]))
		var fv := FileAccess.open(_out, FileAccess.WRITE)
		fv.store_string(JSON.stringify(_report, "  "))
		fv.close()
		print("PERFPROF DONE -> ", _out)
		get_tree().quit(0)
		return
	# Ablation at the square (night = worst case).
	var base: Dictionary = await _sample()
	_report["ablation_base"] = base
	var abl := {}
	abl["no_shadows"] = await _ablate("no_shadows", func() -> Variant:
		var ls := _nodes_where(func(n: Node) -> bool: return n is Light3D and (n as Light3D).shadow_enabled)
		for l: Light3D in ls: l.shadow_enabled = false
		return ls, func(u: Variant) -> void:
		for l: Light3D in u: l.shadow_enabled = true, base)
	abl["no_point_lights"] = await _ablate("no_point_lights", func() -> Variant:
		var ls := _nodes_where(func(n: Node) -> bool: return (n is OmniLight3D or n is SpotLight3D) and (n as Node3D).visible)
		for l: Node3D in ls: l.visible = false
		return ls, func(u: Variant) -> void:
		for l: Node3D in u: l.visible = true, base)
	abl["no_animation"] = await _ablate("no_animation", func() -> Variant:
		var ls := _nodes_where(func(n: Node) -> bool: return (n is AnimationMixer) and n.get("active") == true)
		for a: Node in ls: a.set("active", false)
		return ls, func(u: Variant) -> void:
		for a: Node in u: a.set("active", true), base)
	abl["no_audio"] = await _ablate("no_audio", func() -> Variant:
		var ls := _nodes_where(func(n: Node) -> bool: return (n is AudioStreamPlayer or n is AudioStreamPlayer3D or n is AudioStreamPlayer2D) and n.playing)
		for a: Node in ls: a.stop()
		return ls, func(u: Variant) -> void:
		for a: Node in u: a.play(), base)
	abl["no_npcs"] = await _ablate("no_npcs (townspeople hidden+disabled)", func() -> Variant:
		var ls := get_tree().get_nodes_in_group(&"townspeople").filter(func(n: Node) -> bool: return n is Node3D and (n as Node3D).visible)
		for a: Node3D in ls:
			a.visible = false
			a.process_mode = Node.PROCESS_MODE_DISABLED
		return ls, func(u: Variant) -> void:
		for a: Node3D in u:
			a.visible = true
			a.process_mode = Node.PROCESS_MODE_INHERIT, base)
	abl["no_particles"] = await _ablate("no_particles", func() -> Variant:
		var ls := _nodes_where(func(n: Node) -> bool: return (n is GPUParticles3D or n is CPUParticles3D) and n.get("emitting") == true)
		for a: Node in ls: a.set("emitting", false)
		return ls, func(u: Variant) -> void:
		for a: Node in u: a.set("emitting", true), base)
	abl["no_scripts_process"] = await _ablate("no _process/_physics on scene scripts (except player/camera)", func() -> Variant:
		var ls := _nodes_where(func(n: Node) -> bool: return n.get_script() != null and (n.is_processing() or n.is_physics_processing()) and n != _player and n != _rig and not _player.is_ancestor_of(n) and not _rig.is_ancestor_of(n) and n != self)
		var st: Array = []
		for a: Node in ls:
			st.append([a, a.is_processing(), a.is_physics_processing()])
			a.set_process(false)
			a.set_physics_process(false)
		return st, func(u: Variant) -> void:
		for e: Array in u:
			if is_instance_valid(e[0]):
				(e[0] as Node).set_process(e[1])
				(e[0] as Node).set_physics_process(e[2]), base)
	# Per script (top 18 by count): process saving.
	var per_script := {}
	var scripts: Array = (_report["census"]["processing_by_script"] as Array).slice(0, 12)
	for e: Array in scripts:
		var fname: String = e[0]
		per_script[fname] = await _ablate("script " + fname, func() -> Variant:
			var ls := _nodes_where(func(n: Node) -> bool: return n.get_script() != null and (n.get_script() as Script).resource_path.get_file() == fname and n != self)
			var st: Array = []
			for a: Node in ls:
				st.append([a, a.is_processing(), a.is_physics_processing()])
				a.set_process(false)
				a.set_physics_process(false)
			return st, func(u: Variant) -> void:
			for x: Array in u:
				if is_instance_valid(x[0]):
					(x[0] as Node).set_process(x[1])
					(x[0] as Node).set_physics_process(x[2]), base)
	_report["ablation"] = abl
	_report["ablation_per_script"] = per_script
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("PERFPROF DONE -> ", _out)
	get_tree().quit(0)



## --perf-physics: stand at the town square and measure the physics tick with
## parts of the simulation switched off (what makes the 60 Hz tick heavy?).
func _phys_sample(n: int = 180) -> Dictionary:
	var a: Array = []
	var pr: Array = []
	for i in n:
		await get_tree().physics_frame
		a.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
		pr.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	return {"phys_p50": _pct(a, 0.5), "phys_p95": _pct(a, 0.95), "proc_p50": _pct(pr, 0.5),
		"active_bodies": Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"pairs": Performance.get_monitor(Performance.PHYSICS_3D_COLLISION_PAIRS), "islands": Performance.get_monitor(Performance.PHYSICS_3D_ISLAND_COUNT)}


func _toggle(ls: Array, on: bool, what: String) -> void:
	for n in ls:
		if not is_instance_valid(n):
			continue
		match what:
			"physics":
				(n as Node).set_physics_process(on)
			"process":
				(n as Node).set_process(on)
			"monitor":
				(n as Area3D).monitoring = on
			"disable":
				(n as Node).process_mode = Node.PROCESS_MODE_INHERIT if on else Node.PROCESS_MODE_DISABLED


func _run_physics() -> void:
	await _frames(60)
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-quality="):
			Settings.set_value("quality", arg.substr(15))
	TimeManager.reset_calendar(3, 12.0, "sunny")
	var spots := {"square": TownLayout.TOWN_CENTER + Vector2(0, 10), "farm": Vector2(-3, 7.5)}
	var out := {"physics_ticks_per_second": Engine.physics_ticks_per_second, "census": census()}
	for spot in spots:
		var sp: Vector2 = spots[spot]
		_player.global_position = Vector3(sp.x, Terrain.height_at(sp.x, sp.y) + 0.1, sp.y)
		await _frames(30)
		var res := {}
		res["base"] = await _phys_sample()
		var bots := _nodes_where(func(n: Node) -> bool: return n is CharacterBody3D and n != _player and n.is_in_group(&"townspeople"))
		if bots.is_empty():
			bots = _nodes_where(func(n: Node) -> bool: return n.get_script() != null and (n.get_script() as Script).resource_path.get_file() == "townsperson_bot.gd")
		_toggle(bots, false, "physics")
		res["no_bot_physics_process (%d)" % bots.size()] = await _phys_sample()
		_toggle(bots, true, "physics")
		var bodies := _nodes_where(func(n: Node) -> bool: return n is CharacterBody3D and n != _player)
		_toggle(bodies, false, "physics")
		res["no_characterbody_scripts (%d)" % bodies.size()] = await _phys_sample()
		_toggle(bodies, true, "physics")
		var areas := _nodes_where(func(n: Node) -> bool: return n is Area3D and (n as Area3D).monitoring)
		_toggle(areas, false, "monitor")
		res["areas_not_monitoring (%d)" % areas.size()] = await _phys_sample()
		_toggle(areas, true, "monitor")
		var phys_scripts := _nodes_where(func(n: Node) -> bool: return n.is_physics_processing() and n != _player and n.get_script() != null and not (n is CharacterBody3D))
		_toggle(phys_scripts, false, "physics")
		res["no_other_physics_scripts (%d)" % phys_scripts.size()] = await _phys_sample()
		_toggle(phys_scripts, true, "physics")
		# By script: top physics-processing scripts.
		var by := {}
		for n in _nodes_where(func(n: Node) -> bool: return n.is_physics_processing() and n.get_script() != null and n != _player):
			var f := (n.get_script() as Script).resource_path.get_file()
			if not by.has(f):
				by[f] = []
			by[f].append(n)
		for f in by:
			if (by[f] as Array).size() < 1:
				continue
			_toggle(by[f], false, "physics")
			var r := await _phys_sample(120)
			_toggle(by[f], true, "physics")
			r["d_p50"] = snappedf(float(r["phys_p50"]) - float(res["base"]["phys_p50"]), 0.01)
			res["script " + f + " (%d)" % (by[f] as Array).size()] = r
		out[spot] = res
		for k in res:
			print("PERFPHYS %-7s %-48s %s" % [spot, k, JSON.stringify(res[k])])
	var f2 := FileAccess.open(_out, FileAccess.WRITE)
	f2.store_string(JSON.stringify(out, "  "))
	f2.close()
	print("PERFPHYS DONE")
	get_tree().quit(0)


## --perf-camera: walk straight down the farm lane with the camera left alone
## (no snap) at several frame-rate caps and measure how far the camera trails
## the farmer (ms) and how much he wobbles on screen (judder). Headless = CPU
## timing only, which is what the camera/physics pacing depends on.
func _run_camera() -> void:
	await _frames(40)
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_rig = get_tree().get_first_node_in_group(&"camera_rig")
	TimeManager.reset_calendar(3, 12.0, "sunny")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-quality="):
			Settings.set_value("quality", arg.substr(15))
	await _frames(20)
	_report["quality"] = str(Settings.get_value("quality")) if "quality" in Settings.values else "n/a"
	_report["physics_interpolation"] = get_tree().physics_interpolation
	_report["follow_speed"] = float(_rig.get("follow_speed")) if "follow_speed" in _rig else -1.0
	_report["max_physics_steps"] = Engine.max_physics_steps_per_frame
	var res := {}
	for cap in [60, 45, 30, 24]:
		for sprint in [false, true]:
			var key := "%dfps_%s" % [cap, "run" if sprint else "walk"]
			res[key] = await _camera_pass(cap, sprint)
			print("PERFCAM %-10s %s" % [key, JSON.stringify(res[key])])
	Engine.max_fps = 0
	_report["camera"] = res
	var f := FileAccess.open(_out, FileAccess.WRITE)
	f.store_string(JSON.stringify(_report, "  "))
	f.close()
	print("PERFCAM DONE -> ", _out)
	get_tree().quit(0)


func _rendered(n: Node3D) -> Vector3:
	return n.get_global_transform_interpolated().origin if n.is_physics_interpolated_and_enabled() else n.global_position


func _camera_pass(cap: int, sprint: bool) -> Dictionary:
	Engine.max_fps = cap
	var start := Vector2(-3, 7.5)
	_player.velocity = Vector3.ZERO
	_player.global_position = Vector3(start.x, Terrain.height_at(start.x, start.y) + 0.05, start.y)
	if _player.has_method("reset_physics_interpolation"):
		_player.reset_physics_interpolation()
	if _rig.has_method("snap_view"):
		_rig.snap_view(0.0, -14.0, 7.0)
	await _frames(30)
	var cam := get_viewport().get_camera_3d()
	var off0: Vector3 = (_rig as Node3D).global_position - _rendered(_player)
	var dir := Vector3(0, 0, -1)
	Input.action_press(&"move_forward")
	if sprint:
		Input.action_press(&"sprint")
	var lags: Array = []
	var wob: Array = []
	var cam_v: Array = []
	var dts: Array = []
	var prev_rel := 0.0
	var prev_cam := cam.global_position
	var last := Time.get_ticks_usec()
	var p0 := _player.global_position
	var t0 := last
	var n := 0
	while n < 600:
		await get_tree().process_frame
		n += 1
		var now := Time.get_ticks_usec()
		var dt := (now - last) / 1000000.0
		last = now
		var pr := _rendered(_player)
		if Vector2(pr.x - p0.x, pr.z - p0.z).length() > 25.0:
			break
		if n < 25:  # accelerate + settle
			prev_rel = (pr - cam.global_position).dot(dir)
			prev_cam = cam.global_position
			t0 = now
			p0 = _player.global_position
			continue
		lags.append(((pr + off0) - (_rig as Node3D).global_position).dot(dir))
		var rel := (pr - cam.global_position).dot(dir)
		wob.append(absf(rel - prev_rel) * 1000.0)
		prev_rel = rel
		if dt > 0.0:
			cam_v.append((cam.global_position - prev_cam).dot(dir) / dt)
			dts.append(dt * 1000.0)
		prev_cam = cam.global_position
	Input.action_release(&"move_forward")
	Input.action_release(&"sprint")
	var secs := maxf((last - t0) / 1000000.0, 0.001)
	var speed := Vector2(_player.global_position.x - p0.x, _player.global_position.z - p0.z).length() / secs
	var mean := func(a: Array) -> float: return a.reduce(func(x: float, y: float) -> float: return x + y, 0.0) / maxf(a.size(), 1)
	var lag_m: float = mean.call(lags)
	var cv_mean: float = mean.call(cam_v)
	var cv_var := 0.0
	for v: float in cam_v:
		cv_var += (v - cv_mean) * (v - cv_mean)
	cv_var /= maxf(cam_v.size(), 1)
	return {"frames": lags.size(), "speed_mps": snappedf(speed, 0.01), "frame_ms_p50": _pct(dts, 0.5),
		"trail_m": snappedf(lag_m, 0.001), "trail_ms": snappedf(lag_m / maxf(speed, 0.01) * 1000.0, 0.1),
		"wobble_mm_p50": _pct(wob, 0.5), "wobble_mm_p95": _pct(wob, 0.95),
		"cam_speed_cv_pct": snappedf(sqrt(cv_var) / maxf(absf(cv_mean), 0.01) * 100.0, 0.1)}


## --perf-shot=PATH: town square at noon with the F7 overlay open, saved as PNG.
func _run_shot(path: String) -> void:
	await _frames(40)
	_player = get_tree().get_first_node_in_group(&"player") as Node3D
	_rig = get_tree().get_first_node_in_group(&"camera_rig")
	TimeManager.reset_calendar(3, 11.0, "sunny")
	TimeManager.set_paused(true)
	var v: Array = _views()[1]
	_place(v[1], v[2], v[3], v[4])
	var ov := get_tree().get_first_node_in_group(&"perf_overlay")
	if ov and ov.has_method("toggle") and not (ov.get("panel") as Control).visible:
		ov.call("toggle")
	await _frames(90)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("PERFSHOT saved ", path, " ", img.get_size())
	get_tree().quit(0)
