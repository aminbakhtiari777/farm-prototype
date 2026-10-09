extends RefCounted
## v7b.1 weather smoke checks (DevTools section _smoke_v7b1_weather): the snow
## flakes are soft round textured alpha billboards (not squares), rain streaks
## are textured + wind-angled, snow_amount builds while snowing / holds / melts,
## wetness rises in rain and dries, roofs whiten and restore, particle counts
## follow the graphics preset.

var t  # DevTools


func _init(dev: Node) -> void:
	t = dev


func _alpha(tex: Texture2D, x: int, y: int) -> float:
	var img := tex.get_image()
	return img.get_pixel(x, y).a


func run() -> bool:
	var tree: SceneTree = t.get_tree()
	var scene := tree.current_scene
	var sv := scene.get_node("SeasonVisuals") as SeasonVisuals
	var fx := WeatherFx.instance(tree)
	t._check(fx != null and sv.weather_fx == fx, "WeatherFx present under SeasonVisuals (module weather_fx)")
	if fx == null:
		return false
	t._check(AssetRegistry.get_module("weather_fx") != null and fx.style.id == str(AssetRegistry.get_module("weather_fx").id),
		"weather_fx module active: %s" % fx.style.id)
	var terrain := (scene.get_node("Terrain") as Terrain).material as ShaderMaterial
	var old_quality: Variant = Settings.get_value("quality")
	Settings.set_value("quality", "medium")
	fx.refresh_quality()

	# ---- snow flake material: texture + alpha + billboard, round (corners transparent)
	var sm := (fx.snow.mesh as QuadMesh).material as StandardMaterial3D
	t._check(sm != null and sm.albedo_texture != null, "snow flake material has a texture")
	t._check(sm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "snow flake material is alpha-blended")
	t._check(sm.billboard_mode == BaseMaterial3D.BILLBOARD_PARTICLES, "snow flakes are billboards")
	var tex := sm.albedo_texture
	var n := tex.get_width()
	var a_corner := _alpha(tex, 0, 0)
	var a_edge := _alpha(tex, 0, n / 2)
	var a_mid := _alpha(tex, n / 2, n / 2)
	t._check(a_corner < 0.01 and a_edge < 0.15 and a_mid > 0.9,
		"flake texture is a soft round dot, not a square (alpha corner %.2f edge %.2f centre %.2f)" % [a_corner, a_edge, a_mid])
	t._check(n <= 64, "flake texture is tiny (%d px)" % n)
	t._check(fx.snow.scale_amount_min < 0.8 and fx.snow.scale_amount_max >= 1.0,
		"flake size variety (scale %.2f..%.2f)" % [fx.snow.scale_amount_min, fx.snow.scale_amount_max])
	t._check(fx.snow.initial_velocity_max <= 2.0, "flakes fall slowly (%.1f m/s max)" % fx.snow.initial_velocity_max)
	# rain streak material
	var rm := (fx.rain.mesh as ArrayMesh).surface_get_material(0) as StandardMaterial3D
	t._check(rm != null and rm.albedo_texture != null and rm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
		"rain streak material has a texture and alpha blending")
	t._check(fx.rain.particle_flag_align_y, "rain streaks follow their velocity (lean with the wind)")
	# leaves / petals (were opaque squares too)
	for k: String in ["leaves", "petals"]:
		var p := sv.get_node_or_null(NodePath(k.capitalize())) as CPUParticles3D
		var pm: StandardMaterial3D = ((p.mesh as QuadMesh).material as StandardMaterial3D) if p else null
		t._check(pm != null and pm.albedo_texture != null and pm.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
			"%s particles are soft textured alpha quads" % k)

	# ---- snowfall: emits, counts, accumulation
	fx.hold_levels = true
	fx.set_levels(0.0, 0.0)
	TimeManager.set_season(3)
	TimeManager.set_weather("snow")
	t._check(fx.is_active("snow") and sv.is_effect_active("snow"), "snow falls on a snowy day")
	t._check(fx.snow.amount == int(fx.style.snow_counts["medium"]),
		"snow count = medium preset (%d)" % fx.snow.amount)
	await t._frames(90)
	# (capture_aabb() is empty in --headless: the dummy renderer skips particle simulation)
	var cam := tree.root.get_viewport().get_camera_3d()
	var cxz := Vector2(cam.global_position.x, cam.global_position.z) if cam else Vector2.ZERO
	var exz := Vector2(fx.snow.global_position.x, fx.snow.global_position.z)
	var top := fx.snow.global_position.y - Terrain.height_at(exz.x, exz.y)
	t._check(cam != null and cxz.distance_to(exz) < fx.box_size() * 0.5 and top >= fx.style.snow_height - 0.01
		and is_equal_approx(fx.snow.emission_box_extents.x, fx.box_size() * 0.5),
		"flake box follows the camera (%.1f m away, %.1f m above ground, %.0f m wide)" % [cxz.distance_to(exz), top, fx.snow.emission_box_extents.x * 2.0])
	t._check(fx.snow.local_coords == false and absf(fx.snow.lifetime * fx.style.snow_fall_speed - top) < 1.5,
		"flakes live until they reach the ground (lifetime %.1f s)" % fx.snow.lifetime)
	var seq: Array[float] = [fx.snow_amount]
	for i in 4:
		fx.step_hours(0.5)
		seq.append(fx.snow_amount)
	t._check(seq[1] > seq[0] and seq[2] > seq[1] and seq[3] > seq[2], "snow_amount rises while snowing (%s)" % _fmt(seq))
	t._check(seq[4] > 0.9, "ground fully white after 2 h of snow (%.2f)" % seq[4])
	t._check(absf(float(terrain.get_shader_parameter("snow_amount")) - fx.snow_amount) < 0.001,
		"terrain shader snow_amount follows (%.2f)" % float(terrain.get_shader_parameter("snow_amount")))
	t._check(fx.roof_overlay_count() > 5, "snow overlay on the roofs (%d roofs)" % fx.roof_overlay_count())
	t._check(absf(fx.roof_overlay_amount() - fx.snow_amount) < 0.001, "roof snow follows snow_amount (%.2f)" % fx.roof_overlay_amount())
	# ---- snow stops: holds, then slowly melts
	TimeManager.set_weather("sunny")
	t._check(not fx.is_active("snow"), "snow stops falling on a sunny day")
	var full := fx.snow_amount
	fx.step_hours(2.0)
	var held := fx.snow_amount
	t._check(absf(held - full) < 0.001, "snow stays after it stops (%.2f -> %.2f after 2 h)" % [full, held])
	fx.step_hours(6.0)
	var melting := fx.snow_amount
	t._check(melting < held and melting > 0.3, "winter snow melts slowly (%.2f after 8 h)" % melting)
	TimeManager.set_season(0)
	TimeManager.set_weather("sunny")
	fx.step_hours(6.0)
	t._check(fx.snow_amount < 0.05, "spring sun melts the rest (%.2f)" % fx.snow_amount)
	t._check(fx.roof_overlay_count() == 0, "roof snow overlay removed after the melt")
	# ---- rain: wetness rises, then dries
	fx.set_levels(0.0, 0.0)
	TimeManager.set_weather("rain")
	t._check(fx.is_active("rain") and not fx.is_active("snow"), "rain falls on a rainy day")
	var rain_med := fx.rain.amount
	t._check(rain_med == int(round(fx.style.rain_counts["medium"] * 0.7)), "rain count = medium preset x 0.7 (%d)" % rain_med)
	t._check(fx.splash.emitting == (int(fx.style.splash_counts["medium"]) > 0), "splashes follow the preset (%d)" % fx.splash.amount)
	var wseq: Array[float] = [fx.wetness]
	for i in 3:
		fx.step_hours(0.2)
		wseq.append(fx.wetness)
	t._check(wseq[1] > wseq[0] and wseq[3] > wseq[2] and wseq[3] > 0.8, "wetness rises while raining (%s)" % _fmt(wseq))
	t._check(absf(float(terrain.get_shader_parameter("wetness")) - fx.wetness) < 0.001, "terrain shader wetness follows")
	TimeManager.set_weather("storm")
	var dirx := Vector2(fx.rain.direction.x, fx.rain.direction.z).length()
	fx._aim_rain()
	dirx = Vector2(fx.rain.direction.x, fx.rain.direction.z).length()
	t._check(fx.storm and dirx > 0.1, "storm rain is angled by the wind (horizontal %.2f)" % dirx)
	TimeManager.set_weather("cloudy")
	var soaked := fx.wetness
	fx.step_hours(0.4)
	t._check(fx.wetness >= soaked - 0.001, "ground stays soaked right after the rain (%.2f)" % fx.wetness)
	fx.step_hours(1.5)
	var drying := fx.wetness
	t._check(drying < soaked and drying > 0.2, "ground dries slowly (%.2f after 1.9 h)" % drying)
	fx.step_hours(8.0)
	t._check(fx.wetness < 0.01, "dry again later (%.2f)" % fx.wetness)

	# ---- counts per quality preset
	TimeManager.set_weather("snow")
	var counts := {}
	for q in ["low", "medium", "high"]:
		Settings.set_value("quality", q)
		fx.refresh_quality()
		counts[q] = [fx.snow.amount, fx.box_size()]
		t._check(fx.snow.amount == int(fx.style.snow_counts[q]) and fx.snow.amount <= 900,
			"quality %s: %d flakes in a %.0f m box" % [q, fx.snow.amount, fx.box_size()])
	t._check(counts["low"][0] < counts["medium"][0] and counts["medium"][0] < counts["high"][0], "low < medium < high flake counts")
	TimeManager.set_weather("storm")
	for q in ["low", "medium", "high"]:
		Settings.set_value("quality", q)
		fx.refresh_quality()
		t._check(fx.rain.amount == int(fx.style.rain_counts[q]) and fx.rain.amount <= 800,
			"quality %s: %d rain streaks, %d splashes" % [q, fx.rain.amount, fx.splash.amount if fx.splash.emitting else 0])
	# ---- light_weather variant swaps in live
	var cur: String = fx.style.id
	AssetRegistry.set_active("weather_fx", "light_weather")
	await t._frames(2)
	var light_fx := WeatherFx.instance(tree)
	t._check(light_fx.style.id == "light_weather" and not light_fx.splash.emitting, "light_weather variant swaps in (no splashes)")
	AssetRegistry.set_active("weather_fx", cur)
	await t._frames(2)

	# cleanup
	Settings.set_value("quality", old_quality)
	fx = WeatherFx.instance(tree)
	fx.refresh_quality()
	TimeManager.reset_calendar(1, 10.0, "sunny")
	fx.set_levels(0.0, 0.0)
	fx.hold_levels = false
	sv.apply()
	t._check(not fx.is_active("snow") and not fx.is_active("rain"), "weather particles off on a sunny day")
	return true


func _fmt(a: Array[float]) -> String:
	var parts := PackedStringArray()
	for v in a:
		parts.append("%.2f" % v)
	return " ".join(parts)
