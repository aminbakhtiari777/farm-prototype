extends RefCounted
## v7b.1 audio smoke checks (DevTools sections _smoke_v7b1_audio_*): modules +
## size budget, surface footsteps (walk fires / idle stops / run faster),
## every door open + close, placed ambient emitters (beach / square / trees /
## fields / river / traffic) and their day-night switching, listener follows
## the active camera (incl. a swapped-in cockpit-style camera + possession),
## stereo panning by direction, indoor muffling, voice cap.

var t  # DevTools


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func _aw() -> V7b1AudioWorld:
	return V7b1AudioWorld.instance(_tree())


func _pframes(n: int) -> void:
	for i in n:
		await _tree().process_frame


func _set_time(h: float, weather: String = "sunny") -> void:
	TimeManager.reset_calendar(TimeManager.day, h, weather)
	var dn := _tree().current_scene.get_node_or_null(^"DayNightCycle")
	if dn and dn.has_method("refresh_now"):
		dn.call("refresh_now")


func run_modules() -> bool:
	var aw := _aw()
	t._check(aw != null and aw.listener != null and aw.footsteps != null and aw.doors != null and aw.ambient != null,
		"V7b1AudioWorld with listener / footsteps / doors / ambient emitters")
	if aw == null:
		return true
	var types := AssetRegistry.types()
	for ty in ["spatial_audio", "sound_fx", "ambient_sounds"]:
		t._check(ty in types and AssetRegistry.variants(ty).size() >= 2, "module type '%s' registered with 2 variants" % ty)
	var paths: Array = []
	var fx := Modules.style("sound_fx") as SoundFxStyle
	for surf in fx.surfaces:
		paths.append_array((fx.surfaces[surf] as Dictionary).get("streams", []))
	paths.append(fx.door_open)
	paths.append(fx.door_close)
	var amb := Modules.style("ambient_sounds") as AmbientSoundsStyle
	for k in amb.kinds:
		paths.append(str((amb.kinds[k] as Dictionary).get("stream", "")))
	paths.append_array(Array(amb.gusts))
	paths.append_array(Array(amb.thunder))
	var bad: Array = []
	for p in paths:
		if V7b1AudioWorld.stream(str(p)) == null:
			bad.append(p)
	t._check(bad.is_empty(), "all %d audio streams load %s" % [paths.size(), str(bad)])
	var total := 0
	var files := 0
	var d := DirAccess.open("res://assets/audio/v7b1")
	if d:
		for f in d.get_files():
			if f.ends_with(".ogg"):
				var fa := FileAccess.open("res://assets/audio/v7b1/" + f, FileAccess.READ)
				if fa:
					total += fa.get_length()
					files += 1
	t._check(files >= 15 and total < 600 * 1024, "new audio: %d files, %.1f KB (< 600 KB)" % [files, total / 1024.0])
	return true


func run_footsteps() -> bool:
	var aw := _aw()
	var fa := aw.footsteps
	var pl: Player = t._player
	_set_time(10.0)
	await t._place(Vector2(2.0, 6.0), 180.0, 12)
	fa.update_player()
	t._check(fa.surface == "grass", "farm field = grass steps (%s)" % fa.surface)
	var s0 := pl.footsteps_played
	await t._hold(&"move_forward", 90)
	var walked := pl.footsteps_played - s0
	t._check(walked >= 3, "footsteps fire while walking (%d steps in 1.5 s)" % walked)
	await t._frames(20)
	var s1 := pl.footsteps_played
	await t._frames(60)
	t._check(pl.footsteps_played == s1, "footsteps stop when idle (%d extra)" % (pl.footsteps_played - s1))
	await t._place(Vector2(2.0, 6.0), 180.0, 12)
	var s2 := pl.footsteps_played
	t._act(&"sprint", true)
	await t._hold(&"move_forward", 90)
	t._act(&"sprint", false)
	var ran := pl.footsteps_played - s2
	t._check(ran > walked, "running steps come faster (%d vs %d walking)" % [ran, walked])
	# Surfaces.
	var beach := Vector2(37.0, 25.0) + Vector2(0.7071, -0.7071) * -10.0 + Vector2(-0.7071, -0.7071) * 5.0
	var pier := BeachBuilder.PIER_START + BeachBuilder.PIER_DIR * 8.0
	var bb := _tree().current_scene.find_child("Beach", true, false) as BeachBuilder
	var deck := bb.pier_deck_height if bb else 1.0
	var got := {
		"grass": FootstepAudio.surface_at(Vector3(2, Terrain.height_at(2, 6), 6)),
		"asphalt": FootstepAudio.surface_at(Vector3(30, Terrain.height_at(30, -50), -50)),
		"stone": FootstepAudio.surface_at(Vector3(4, Terrain.height_at(4, -50), -50)),
		"sand": FootstepAudio.surface_at(Vector3(beach.x, Terrain.height_at(beach.x, beach.y), beach.y)),
		"wood": FootstepAudio.surface_at(Vector3(pier.x, deck + 0.05, pier.y)),
	}
	var ok := true
	for k in got:
		ok = ok and got[k] == k
	t._check(ok and FootstepAudio.surface_at(Vector3(2, 0, 6), true) == "wood", "surfaces: road asphalt, square stone, beach sand, pier / indoors wood, field grass %s" % str(got))
	await t._place(Vector2(30.0, -50.0), 90.0, 12)
	fa.update_player()
	var first: AudioStream = pl.footstep_sounds[0] if not pl.footstep_sounds.is_empty() else null
	t._check(fa.surface == "asphalt" and first != null and "step_asphalt" in first.resource_path,
		"walking onto the road swaps the farmer's steps to asphalt (%s)" % (first.resource_path if first else "-"))
	var s3 := pl.footsteps_played
	await t._hold(&"move_forward", 60)
	t._check(pl.footsteps_played > s3, "asphalt steps fire while walking (%d)" % (pl.footsteps_played - s3))
	# Residents nearby: quieter steps from their own position.
	var bot: TownspersonBot = null
	var best := INF
	for n in _tree().get_nodes_in_group(&"townspeople"):
		var b := n as TownspersonBot
		if b and b.visible and b.is_inside_tree():
			var dd := b.global_position.distance_to(pl.global_position)
			if dd < best:
				best = dd
				bot = b
	t._check(bot != null, "a resident to listen to")
	if bot:
		await t._place(Vector2(bot.global_position.x + 2.5, bot.global_position.z), 0.0, 4)
		await t._frames(40)
		t._check(fa.tracked_count() >= 1 and fa.tracked_count() <= (Modules.style("sound_fx") as SoundFxStyle).npc_max,
			"nearest residents get footsteps (%d tracked)" % fa.tracked_count())
		var n0 := fa.npc_steps
		for p in aw.pool:
			p.stop()
		fa.step_npc(bot, false)
		var last: AudioStreamPlayer3D = null
		for p in aw.pool:
			if p.playing:
				last = p
		var fs := pl.get_node(^"Footsteps") as AudioStreamPlayer3D
		t._check(fa.npc_steps == n0 + 1 and last != null and last.global_position.distance_to(bot.global_position) < 0.5
			and last.volume_db < fs.volume_db, "resident step plays at the resident, quieter than the farmer's (%.0f vs %.0f dB)" % [last.volume_db if last else 0.0, fs.volume_db])
	return true


func run_doors() -> bool:
	var aw := _aw()
	var da := aw.doors
	var all := da.doors()
	t._check(all.size() >= 20, "doors in town: %d" % all.size())
	t._check(da.hooked >= all.size(), "every door hooked for sound (%d / %d)" % [da.hooked, all.size()])
	da.range_override = 1.0e6
	var missing: Array = []
	var creak_cut := true
	for n in all:
		var d := n as BuildingDoor
		var id := d.get_instance_id()
		if d.is_open:
			d.set_open(false, true)
		var o0 := int(da.opens.get(id, 0))
		var c0 := int(da.closes.get(id, 0))
		for p in aw.pool:
			p.stop()
		d.set_open(true)
		for p in aw.pool:
			p.stop()
		d.set_open(false)
		var creak := d.get("_audio") as AudioStreamPlayer3D
		if creak and creak.playing:
			creak_cut = false
		if int(da.opens.get(id, 0)) <= o0 or int(da.closes.get(id, 0)) <= c0:
			var b := d.get_parent()
			missing.append(str(b.name) if b else str(d.name))
	da.range_override = -1.0
	t._check(missing.is_empty(), "every door plays an open AND a close sound (%d doors, missing %s)" % [all.size(), str(missing.slice(0, 6))])
	t._check(creak_cut, "closing cuts the creak (thud instead)")
	# Range: a far door stays silent.
	var far: BuildingDoor = null
	var e := aw.ear()
	for n in all:
		if (n as Node3D).global_position.distance_to(e) > 60.0:
			far = n as BuildingDoor
			break
	if far:
		var s0 := da.silent
		far.set_open(true)
		far.set_open(false)
		t._check(da.silent >= s0 + 2, "doors far from the listener stay silent (no wasted voices)")
	return true


func run_ambient() -> bool:
	var aw := _aw()
	var ae := aw.ambient
	var em: Dictionary = ae.emitters
	for k in ["birds", "crickets", "murmur", "river", "traffic"]:
		t._check(em.has(k) and (em[k] as Array).size() >= 2, "%s emitters placed (%d)" % [k, (em.get(k, []) as Array).size()])
	var nature := _tree().current_scene.find_child("Nature", true, false) as NatureScatter
	var in_trees := 0
	for p in em.get("birds", []):
		var bp := (p as Node3D).global_position
		for tp in nature.tree_positions:
			if Vector2(tp.x - bp.x, tp.z - bp.z).length() < 0.5 and bp.y > tp.y + 2.0:
				in_trees += 1
				break
	t._check(in_trees == (em.get("birds", []) as Array).size() and in_trees > 0, "birds sit in tree crowns (%d)" % in_trees)
	var sq_ok := true
	for p in em.get("murmur", []):
		var q := (p as Node3D).global_position
		sq_ok = sq_ok and Vector2(q.x, q.z).distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 1.0
	t._check(sq_ok, "murmur emitters stand in the town square")
	var riv_ok := true
	for p in em.get("river", []):
		var q2 := (p as Node3D).global_position
		riv_ok = riv_ok and TownLayout.river_distance(Vector2(q2.x, q2.z)) < 3.0
	t._check(riv_ok, "river emitters on the river")
	var cr_ok := true
	for p in em.get("crickets", []):
		var q3 := (p as Node3D).global_position
		cr_ok = cr_ok and FootstepAudio.surface_at(Vector3(q3.x, Terrain.height_at(q3.x, q3.z), q3.z)) == "grass"
	t._check(cr_ok, "crickets in grassy fields")
	var waves := ae.wave_emitters()
	var shore_ok := not waves.is_empty()
	for w in waves:
		var wp := (w as Node3D).global_position
		shore_ok = shore_ok and absf(TownLayout.sea_distance(wp.x, wp.z)) < 8.0 and w is AudioStreamPlayer3D
	t._check(shore_ok, "beach waves: %d positional emitters along the shore" % waves.size())
	var all_3d := true
	for p in ae.all_emitters():
		var a := p as AudioStreamPlayer3D
		all_3d = all_3d and a != null and a.stream != null and a.max_distance > 10.0 and a.panning_strength > 0.0
	t._check(all_3d, "ambient beds are AudioStreamPlayer3D with streams, range and panning (%d)" % ae.all_emitters().size())
	# Day at the square: murmur + birds may play, crickets silent.
	_set_time(12.0)
	await t._place(Vector2(3.0, -44.0), 180.0, 6)
	await _pframes(2)
	ae.update_levels()
	ae.refresh()
	var murmur_on := false
	for p in em["murmur"]:
		murmur_on = murmur_on or ae.is_active(p)
	var crickets_on := false
	for p in em["crickets"]:
		crickets_on = crickets_on or ae.is_active(p)
	t._check(not murmur_on and not crickets_on, "noon: synthetic crowd loop and night crickets are silent")
	# Night in a field: crickets near you, no birds, no murmur.
	_set_time(23.0)
	var c0 := (em["crickets"][0] as Node3D).global_position
	await t._place(Vector2(c0.x + 3.0, c0.z), 0.0, 6)
	await _pframes(2)
	ae.update_levels()
	ae.refresh()
	var birds_on := false
	for p in em["birds"]:
		birds_on = birds_on or ae.is_active(p)
	var night_lv := float(ae.levels.get("night", 0.0))
	t._check((ae.is_active(em["crickets"][0]) == (night_lv > 0.02)) and not birds_on,
		"night in a field: nearby crickets play (level %.2f, %s), birds silent" % [night_lv, TimeManager.season_id()])
	var far_off := true
	for p in ae.all_emitters():
		if ae.is_active(p):
			far_off = far_off and (p as Node3D).global_position.distance_to(aw.ear()) < 80.0
	t._check(far_off and ae.active_count() <= aw.voice_cap(), "only nearby emitters play (%d active, cap %d)" % [ae.active_count(), aw.voice_cap()])
	# Indoors: outdoor beds muffled, restored outside.
	var bld: Node3D = null
	for dn in aw.doors.doors():
		var up: Node = dn as Node
		while up and not (up is Building):
			up = up.get_parent()
		if up:
			bld = up as Node3D
			break
	t._check(bld != null, "a building to step into")
	var probe := ae.all_emitters()[0] as AudioStreamPlayer3D
	var cut_out := probe.attenuation_filter_cutoff_hz
	GameEvents.building_entered.emit(bld)
	var cut_in := probe.attenuation_filter_cutoff_hz
	var wave_in := (waves[0] as AudioStreamPlayer3D).attenuation_filter_cutoff_hz if not waves.is_empty() else 0.0
	GameEvents.building_exited.emit(bld)
	t._check(cut_in < 1500.0 and cut_out > 4000.0 and probe.attenuation_filter_cutoff_hz == cut_out and wave_in < 1500.0,
		"indoors: outdoor sounds low-passed (%.0f Hz inside, %.0f Hz outside, waves too)" % [cut_in, cut_out])
	# Sky: gusts overhead, thunder only with rain / storm.
	_set_time(14.0, "sunny")
	for p in aw.pool:
		p.stop()
	var g0 := ae.gusts
	var gust_ok := ae.play_gust()
	t._check(gust_ok and ae.gusts == g0 + 1 and ae.gust.global_position.y > aw.ear().y + 4.0, "wind gust blows overhead (sky)")
	var th0 := ae.thunders
	var st := ae.style()
	for i in 40:
		ae.call("_sky", 5.0, st)
	t._check(ae.thunders == th0, "no thunder on a sunny day")
	_set_time(14.0, "storm")
	for i in 40:
		ae.call("_sky", 5.0, st)
	t._check(ae.thunders > th0 and ae.thunder.global_position.distance_to(aw.ear()) > 45.0, "distant thunder in a storm (%d rolls, %.0f m away)" % [ae.thunders - th0, ae.thunder.global_position.distance_to(aw.ear())])
	ae.thunder.stop()
	ae.gust.stop()
	_set_time(10.0, "sunny")
	return true


func run_spatial() -> bool:
	var aw := _aw()
	var l := aw.listener
	await t._place(Vector2(2.0, 6.0), 180.0, 8)
	await _pframes(3)
	var cam := l.get_viewport().get_camera_3d()
	t._check(l.is_current(), "the audio listener is current")
	var focus := l.focus_point()
	var pull := (Modules.style("spatial_audio") as SpatialAudioStyle).listener_pull
	var expect := cam.global_position.lerp(focus, pull)
	t._check(l.global_basis.z.dot(cam.global_basis.z) > 0.999 and l.global_position.distance_to(expect) < 0.3,
		"listener follows the camera (turned like it, %.2f m from camera->player point)" % l.global_position.distance_to(expect))
	# Turn the camera: the listener turns with it.
	t._rig.snap_view(90.0, -20.0, 6.0)
	await _pframes(3)
	cam = l.get_viewport().get_camera_3d()
	t._check(l.global_basis.z.dot(cam.global_basis.z) > 0.999, "listener turns with the camera")
	# Any other active camera (cockpit / possessed resident) takes over the listener.
	var tmp := Camera3D.new()
	tmp.name = "CockpitProbe"
	_tree().current_scene.add_child(tmp)
	tmp.global_transform = Transform3D(Basis(Vector3.UP, 1.3), Vector3(10, 3, -20))
	tmp.make_current()
	await _pframes(3)
	t._check(l.follows == "CockpitProbe" and l.global_basis.z.dot(tmp.global_basis.z) > 0.999, "a swapped-in camera (cockpit-style) drives the listener (%s)" % l.follows)
	cam.make_current()
	tmp.queue_free()
	await _pframes(3)
	t._check(l.follows == String(cam.name), "back on the follow camera (%s)" % l.follows)
	var v7a := _tree().current_scene.get_node_or_null(^"V7aWorld")
	var pos: Possession = v7a.get("possession") if v7a and "possession" in v7a else null
	if pos:
		var bot := pos.nearest_resident(9999.0)
		if bot and pos.possess(bot):
			await _pframes(4)
			var fp := l.focus_point()
			t._check(fp.distance_to(bot.global_position + Vector3.UP * 1.6) < 0.5, "possessed resident: listener centred on the resident")
			pos.release()
			await t._frames(4)
	# Panning.
	await t._place(Vector2(2.0, 6.0), 180.0, 8)
	await _pframes(3)
	var o := l.global_position
	var left := o - l.global_basis.x * 6.0
	var right := o + l.global_basis.x * 6.0
	var front := o - l.global_basis.z * 6.0
	var gl := l.gains_of(left)
	t._check(l.pan_of(left) < -0.9 and gl.x > gl.y * 3.0, "emitter on the left: pan %.2f, left ear %.2f > right %.2f" % [l.pan_of(left), gl.x, gl.y])
	t._check(l.pan_of(right) > 0.9 and absf(l.pan_of(front)) < 0.1, "right emitter pans right (%.2f), front stays centred (%.2f)" % [l.pan_of(right), l.pan_of(front)])
	t._rig.snap_view(t._rig.yaw_degrees() + 180.0, -20.0, 6.0)
	await _pframes(3)
	t._check(l.pan_of(left) > 0.6, "turn around: the same sound moves to the other ear (%.2f)" % l.pan_of(left))
	t._rig.reset_behind_target()
	var pl_fs := t._player.get_node(^"Footsteps") as AudioStreamPlayer3D
	var cfg_ok := pl_fs.panning_strength > 0.0
	for p in aw.pool:
		cfg_ok = cfg_ok and p.panning_strength > 0.0 and p.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and p.max_distance > 0.0
	t._check(cfg_ok, "3D players: inverse-distance attenuation, max distance, panning on")
	return true


func run_budget() -> bool:
	var aw := _aw()
	await t._place(Vector2(3.0, -44.0), 180.0, 6)
	_set_time(12.0)
	aw.ambient.update_levels()
	aw.ambient.refresh()
	var cap := aw.voice_cap()
	var s := V7b1AudioWorld.stream((Modules.style("sound_fx") as SoundFxStyle).door_close)
	var e := aw.ear()
	var max_seen := 0
	var st0 := aw.stolen
	for i in 40:
		var a := randf() * TAU
		aw.play_at(s, e + Vector3(cos(a), 0, sin(a)) * randf_range(1.0, 20.0), -10.0, 1.0, 4.0, 30.0)
		max_seen = maxi(max_seen, aw.voices_playing())
	t._check(max_seen <= cap, "voice cap respected: at most %d of %d voices while 40 sounds fire" % [max_seen, cap])
	t._check(aw.stolen > st0, "nearest win: far one-shots are replaced (%d)" % (aw.stolen - st0))
	t._check(aw.play_at(s, e + Vector3(200, 0, 0), -10.0, 1.0, 4.0, 30.0) == null, "sounds beyond their range are not played")
	var pw := PerfWorld.instance(_tree())
	if pw and pw.audio:
		pw.audio.set_process(true)
		pw.audio.call("_process", 5.0)
		var q: QualityStyle = PerfQuality.style()
		t._check(q == null or pw.audio.playing_now <= q.max_voices, "perf audio budget still holds (%d playing, max %d)" % [pw.audio.playing_now, q.max_voices if q else -1])
		pw.audio.set_process(false)
		for p in pw.audio.get("_paused").values():
			if is_instance_valid(p):
				(p as AudioStreamPlayer3D).stream_paused = false
		(pw.audio.get("_paused") as Dictionary).clear()
	for p in aw.pool:
		p.stop()
	_set_time(10.0)
	return true
