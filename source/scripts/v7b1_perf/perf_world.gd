class_name PerfWorld
extends Node
## v7b.1 performance refresh. One node (added by main.gd after the feature
## worlds) that owns the swappable perf systems:
##   AutoLod          distance LOD, shadow culling, light fades, quality preset
##   WorldStreamer    cell streaming of buildings / street chunks / props
##   InteriorStreamer lazy home interiors + registered interiors
##   AudioBudget      far-sound pausing, voice cap, cache release
##   AnimBudget       far animations off
##   PerfOverlay      F7 stats (also mirrored to window.farmPerf on the web)
## and the frame-pacing fixes (physics interpolation for the player + camera,
## max physics steps per frame, snappier camera follow). Modules: quality,
## world_stream, lod_rules, audio_budget. Dev profiler: -- --perf-profile=...

var lod: AutoLod
var streamer: WorldStreamer
var interiors: InteriorStreamer
var audio: AudioBudget
var anims: AnimBudget
var overlay: PerfOverlay
var _web_timer: float = 0.0
var _player_cached: Node3D


## Far townspeople tick every Nth physics frame (off in the smoke test).
static var far_tick_enabled: bool = true


static func instance(tree: SceneTree) -> PerfWorld:
	return tree.get_first_node_in_group(&"perf_world") as PerfWorld


func _ready() -> void:
	name = "PerfWorld"
	add_to_group(&"perf_world")
	lod = AutoLod.new()
	add_child(lod)
	streamer = WorldStreamer.new()
	add_child(streamer)
	interiors = InteriorStreamer.new()
	add_child(interiors)
	audio = AudioBudget.new()
	add_child(audio)
	anims = AnimBudget.new()
	add_child(anims)
	overlay = PerfOverlay.new()
	add_child(overlay)
	lod.quality_applied.connect(_apply_motion)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--perf-profile") or arg.begins_with("--perf-walk"):
			add_child(load("res://scripts/v7b1_perf/perf_profiler.gd").new())
		if arg == "--perf-overlay":
			overlay.toggle.call_deferred()
	# Smoke test / screenshots: keep other sections deterministic. The perf
	# sections switch streaming and the budgets on themselves.
	for arg in OS.get_cmdline_user_args():
		if arg == "--smoke-test" or arg.begins_with("--shots") or arg.begins_with("--net-test"):
			streamer.enabled = false
			streamer.auto_scan_on_ready = false
			audio.set_process(false)
			anims.set_process(false)
			PerfWorld.far_tick_enabled = false
	# Dedicated / net-test servers have no player view: nothing to stream.
	if DisplayServer.get_name() == "headless" and OS.get_cmdline_user_args().has("--server"):
		streamer.enabled = false
	if OS.has_feature("web"):
		print("FARMPERF ready ms=%d quality=%s" % [Time.get_ticks_msec(), PerfQuality.style_id()])
	_hook_new_content.call_deferred()


## Streaming for the other v7b.1 workstreams' new content. Street lights, road
## markings, signs, plaques, street plants and the disco's lights are covered
## generically by AutoLod (node_added: ranges, shadow policy, light fades) and
## the street lights already use their own light pool. City Hall's furniture
## (CityHallInterior.ensure_built / unload) is registered here as a streamed
## interior: furnished when the player comes near the door, freed when far.
func _hook_new_content() -> void:
	for i in 6:
		await get_tree().process_frame
	if not is_inside_tree() or not InteriorStreamer.lazy_for_custom():
		return
	hook_city_hall()


## Returns true when City Hall's interior got registered (also used by the smoke).
func hook_city_hall() -> bool:
	var scene := get_tree().current_scene
	if scene == null:
		return false
	var ch := scene.find_child("CityHallInterior", true, false)
	if ch == null or not ch.has_method("ensure_built") or not ch.has_method("unload"):
		return false
	var b := ch.get("building") as Node3D
	if b == null:
		return false
	if b.has_meta(&"perf_interior_hooked"):
		return true
	b.set_meta(&"perf_interior_hooked", true)
	interiors.register_interior(b, Callable(ch, "ensure_built"), func() -> void:
		# Never drop the furniture while someone is inside.
		if b.get("player_inside"):
			return
		ch.call("unload"), 16.0)
	return true


## Frame pacing: the player is moved at 60 Hz physics while frames come at the
## display / browser rate. Without interpolation the farmer (and the camera
## chasing him) judders whenever fps != 60, which reads as "everything is a bit
## late". Interpolate only the player subtree (the rest of the world moves in
## _process and must not be interpolated), cap the physics catch-up steps,
## and make the camera catch up faster.
func _apply_motion(st: QualityStyle) -> void:
	Engine.max_physics_steps_per_frame = maxi(st.max_physics_steps, 1)
	var scene := get_tree().current_scene
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if scene == null:
		return
	get_tree().physics_interpolation = st.smooth_motion
	if st.smooth_motion:
		# Scene default OFF: world props that move in _process must not be
		# interpolated (would lag behind). Only the CharacterBody3Ds we drive
		# (player + cars) opt in.
		scene.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		if player:
			player.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
			player.reset_physics_interpolation()
		for c in get_tree().get_nodes_in_group(&"drivable_cars"):
			if c is Node3D:
				(c as Node3D).physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig and "follow_speed" in rig:
		rig.set("follow_speed", st.camera_follow_speed)


var _target_timer: float = 0.0


## Whatever the camera follows (farmer, a driven car, a possessed townsperson)
## moves in _physics_process, so it gets physics interpolation too.
func _interpolate_camera_target() -> void:
	if not get_tree().physics_interpolation:
		return
	var rig := get_tree().get_first_node_in_group(&"camera_rig")
	if rig == null or not ("target" in rig):
		return
	var tg = rig.get("target")
	if tg is CharacterBody3D or tg is RigidBody3D or tg is VehicleBody3D:
		var n := tg as Node3D
		if n.physics_interpolation_mode != Node.PHYSICS_INTERPOLATION_MODE_ON:
			n.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
			n.reset_physics_interpolation()


func _process(delta: float) -> void:
	_target_timer -= delta
	if _target_timer <= 0.0:
		_target_timer = 0.25
		_interpolate_camera_target()
	if not OS.has_feature("web"):
		return
	_web_timer -= delta
	if _web_timer > 0.0:
		return
	_web_timer = 1.0
	if overlay.stats.is_empty():
		return
	JavaScriptBridge.eval("window.farmPerf = %s;" % JSON.stringify(JSON.stringify(overlay.stats)), true)
