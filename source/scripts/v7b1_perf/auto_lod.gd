class_name AutoLod
extends Node
## Distance-based detail. On every GeometryInstance3D / Light3D / Label3D added
## to the scene (and once at start), apply a visibility range and shadow policy
## from the lod_rules module x the active quality preset. Preset also drives
## sun shadows, render scale, MSAA, mesh LOD threshold, Nature view distances
## and the LampLightPool size. New content from any other module is covered
## automatically via SceneTree.node_added.

signal quality_applied(style: QualityStyle)

var _pending: Array = []
var _flush_left: float = 0.0
var _fps_window: PackedFloat32Array = PackedFloat32Array()
var _fps_timer: float = 0.0
var _auto_stepped: bool = false
var _applied_id: String = ""
## Nodes we already tagged (instance_id) so we do not fight modules that set
## their own ranges, and so we can re-apply when the preset changes.
var _tagged: Dictionary = {}  ## int -> Dictionary {kind, base_end, had_range}


func _ready() -> void:
	name = "AutoLod"
	add_to_group(&"auto_lod")
	get_tree().node_added.connect(_on_node_added)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "quality":
			_auto_stepped = false
			_force_id = ""  # an explicit choice cancels the automatic step-down
			apply_quality())
	ControlInput.scheme_changed.connect(func(_on: bool) -> void:
		if PerfQuality.is_auto():
			apply_quality())
	Modules.on_swap("quality", self, func(_m: Resource) -> void:
		PerfQuality.invalidate()
		apply_quality())
	Modules.on_swap("lod_rules", self, func(_m: Resource) -> void: apply_quality())
	Modules.on_swap("shadows", self, func(_m: Resource) -> void: apply_quality())
	apply_quality.call_deferred()
	_scan.call_deferred(get_tree().current_scene)


func _process(delta: float) -> void:
	_flush_left -= delta
	if _flush_left <= 0.0 and not _pending.is_empty():
		_flush_left = 0.05
		var n := mini(_pending.size(), 48)
		for i in n:
			_apply_one(_pending.pop_front())
	# Auto: step down if fps stays below the floor for a few seconds.
	if not PerfQuality.is_auto():
		return
	_fps_timer += delta
	if _fps_timer < 0.5:
		return
	_fps_timer = 0.0
	_fps_window.append(Performance.get_monitor(Performance.TIME_FPS))
	if _fps_window.size() > 12:
		_fps_window.remove_at(0)
	if _fps_window.size() < 8 or _auto_stepped:
		return
	var avg := 0.0
	for f in _fps_window:
		avg += f
	avg /= _fps_window.size()
	var st := PerfQuality.style()
	if st and avg > 1.0 and avg < st.auto_fps_floor and PerfQuality.style_id() != "low":
		_auto_stepped = true
		var nxt := "low" if PerfQuality.style_id() == "medium" else "medium"
		# Don't write Settings (stay on Auto); temporarily force via a soft override.
		_force_id = nxt
		apply_quality()
		GameEvents.notification_requested.emit(Lang.loc_ui("Graphics lowered to keep the game smooth"))


var _force_id: String = ""  ## temporary step-down while Settings stays "auto"


func current_style() -> QualityStyle:
	if _force_id != "":
		var m := AssetRegistry.load_variant("quality", _force_id) as QualityStyle
		if m:
			return m
	return PerfQuality.style()


func apply_quality() -> void:
	var st := current_style()
	if st == null:
		return
	_applied_id = st.id
	_apply_renderer(st)
	_apply_sun(st)
	_apply_nature(st)
	_apply_lamps(st)
	_retag_all(st)
	quality_applied.emit(st)


func _apply_renderer(st: QualityStyle) -> void:
	var vp := get_viewport()
	if vp:
		vp.scaling_3d_scale = clampf(st.render_scale, 0.5, 1.0)
		match st.msaa:
			0:
				vp.msaa_3d = Viewport.MSAA_DISABLED
			1:
				vp.msaa_3d = Viewport.MSAA_2X
			_:
				vp.msaa_3d = Viewport.MSAA_4X
	# Mesh LOD threshold (pixels of screen coverage before a lower LOD kicks in).
	vp.mesh_lod_threshold = st.mesh_lod_threshold
	# Shadow atlas size.
	if st.sun_shadows > 0:
		# Runtime change needs the RenderingServer call (ProjectSettings is boot-only).
		RenderingServer.directional_shadow_atlas_set_size(st.shadow_atlas, true)


func _apply_sun(st: QualityStyle) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var sun := scene.get_node_or_null(^"Sun") as DirectionalLight3D
	if sun == null:
		return
	if st.sun_shadows <= 0 or not bool(Settings.get_value("shadows")):
		sun.shadow_enabled = false
		return
	sun.shadow_enabled = true
	if st.sun_shadows >= 2:
		# Full ShadowRig (respects the existing High / Low / Off button).
		var panel := scene.find_child("SettingsPanel", true, false)
		var level := 0
		if panel and "shadow_level" in panel:
			level = int(panel.shadow_level)
		ShadowRig.apply(sun, level if level < 2 else 0)
		if st.shadow_distance > 0.0:
			sun.directional_shadow_max_distance = minf(sun.directional_shadow_max_distance, st.shadow_distance)
	else:
		sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
		sun.directional_shadow_max_distance = st.shadow_distance
		sun.directional_shadow_split_1 = 0.3
		sun.directional_shadow_blend_splits = false
		sun.shadow_blur = 1.0


func _apply_nature(st: QualityStyle) -> void:
	var nature := get_tree().current_scene.get_node_or_null(^"Nature") as NatureScatter if get_tree().current_scene else null
	if nature == null:
		return
	var base_tree := 150.0 if OS.has_feature("web") else 150.0
	var base_grass := 55.0 if OS.has_feature("web") else 55.0
	# Apply to every MultiMeshInstance under Nature.
	for mmi in nature.find_children("*", "MultiMeshInstance3D", true, false):
		var g := mmi as MultiMeshInstance3D
		var is_grass := g.name.begins_with("Grass") or g.name.begins_with("Flower") or "Grass" in str(g.get_parent().name)
		var end := (base_grass * st.grass_view_scale) if is_grass else (base_tree * st.tree_view_scale)
		# Keep modules that already set a shorter range.
		if g.visibility_range_end <= 0.0 or g.visibility_range_end > end or _tagged.has(g.get_instance_id()):
			g.visibility_range_end = end
			g.visibility_range_end_margin = 8.0 if is_grass else 12.0
		# On Low / Medium: only the nearest tree chunks cast shadows.
		if st.sun_shadows <= 1:
			if is_grass or st.sun_shadows == 0:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif g.visibility_range_end > 80.0:
				g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_lamps(st: QualityStyle) -> void:
	for pool in get_tree().get_nodes_in_group(&"lamp_light_pools"):
		if pool.has_method("set_light_count"):
			pool.call("set_light_count", st.lamp_lights)


func _scan(n: Node) -> void:
	if n == null:
		return
	_on_node_added(n)
	for c in n.get_children():
		_scan(c)


func _on_node_added(n: Node) -> void:
	if n is GeometryInstance3D or n is Light3D or n is Label3D:
		_pending.append(n)


func _retag_all(st: QualityStyle) -> void:
	var rules := Modules.style("lod_rules") as LodRulesStyle
	if rules == null:
		return
	# Forget freed nodes (lazy interiors / streamed props churn instance ids).
	for id in _tagged.keys():
		if not is_instance_id_valid(id):
			_tagged.erase(id)
	# Re-scan visible scene so ranges pick up the new lod_scale.
	_pending.clear()
	_scan(get_tree().current_scene)
	# Flush immediately (startup / preset change).
	while not _pending.is_empty():
		_apply_one(_pending.pop_front())


func _apply_one(obj: Variant) -> void:
	# Untyped on purpose: queued nodes may be freed before the flush.
	if not is_instance_valid(obj):
		return
	var n := obj as Node
	if n == null or not n.is_inside_tree():
		return
	var st := current_style()
	var rules := Modules.style("lod_rules") as LodRulesStyle
	if st == null or rules == null:
		return
	if n is Label3D:
		_apply_label(n as Label3D, st, rules)
		return
	if n is Light3D and not (n is DirectionalLight3D):
		_apply_light(n as Light3D, st)
		return
	if n is GeometryInstance3D:
		_apply_geom(n as GeometryInstance3D, st, rules)


func _size_of(g: GeometryInstance3D) -> float:
	var aabb := g.get_aabb()
	var s := aabb.size * g.global_transform.basis.get_scale().abs()
	return maxf(s.x, maxf(s.y, s.z))


func _apply_geom(g: GeometryInstance3D, st: QualityStyle, rules: LodRulesStyle) -> void:
	var id := g.get_instance_id()
	var size := _size_of(g)
	# Huge things (terrain, sea, mountains) keep no auto range.
	if size >= rules.large_size * 2.5:
		return
	var end: float
	if size < rules.tiny_size:
		end = rules.tiny_range
	elif size < rules.small_size:
		end = rules.small_range
	elif size < rules.medium_size:
		end = rules.medium_range
	elif size < rules.large_size:
		end = rules.large_range
	else:
		return
	# base_end is stored UNSCALED so switching presets never compounds lod_scale.
	if _tagged.has(id):
		end = float(_tagged[id]["base_end"]) * st.lod_scale
	elif g.visibility_range_end > 0.0:
		if rules.scale_existing:
			# First time: remember the author's range, then scale it.
			_tagged[id] = {"base_end": g.visibility_range_end}
			end = g.visibility_range_end * st.lod_scale
		else:
			# Honour a shorter range a module already set; only shorten longer ones.
			end = minf(end * st.lod_scale, g.visibility_range_end)
	else:
		_tagged[id] = {"base_end": end}
		end *= st.lod_scale
	g.visibility_range_end = end
	g.visibility_range_end_margin = rules.margin
	g.visibility_range_fade_mode = (GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF if rules.fade
			else GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED)
	# Shadow policy: tiny / small things and Low preset never cast.
	if st.sun_shadows == 0 or size < st.shadow_min_size:
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _apply_label(l: Label3D, st: QualityStyle, rules: LodRulesStyle) -> void:
	var id := l.get_instance_id()
	if not _tagged.has(id):
		if l.visibility_range_end > 0.0 and not rules.scale_existing:
			return
		# Unscaled base, so re-applying a preset never compounds lod_scale.
		_tagged[id] = {"base_end": l.visibility_range_end if l.visibility_range_end > 0.0 else rules.label_range}
	l.visibility_range_end = float(_tagged[id]["base_end"]) * st.lod_scale
	l.visibility_range_end_margin = rules.margin


func _apply_light(l: Light3D, st: QualityStyle) -> void:
	l.distance_fade_enabled = true
	l.distance_fade_begin = maxf(st.light_fade_distance * 0.65, 4.0)
	l.distance_fade_length = maxf(st.light_fade_distance * 0.35, 4.0)
	if l is OmniLight3D:
		(l as OmniLight3D).omni_range = minf((l as OmniLight3D).omni_range, st.light_fade_distance)
	elif l is SpotLight3D:
		(l as SpotLight3D).spot_range = minf((l as SpotLight3D).spot_range, st.light_fade_distance)
	if st.sun_shadows == 0:
		l.shadow_enabled = false
