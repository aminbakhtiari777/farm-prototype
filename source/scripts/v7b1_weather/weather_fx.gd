class_name WeatherFx
extends Node3D
## v7b.1 weather visuals (module "weather_fx", style WeatherFxStyle).
## Fixes Amin's "white square pixels falling from the sky": the v4 particles were
## untextured opaque QuadMeshes. Now:
##  - snow: soft round flakes (_WT.flake radial gradient, alpha blend,
##    billboard), size variety, slow fall, gentle sway + drift;
##  - rain: thin semi-transparent streaks that lean with the wind (+ splashes);
##  - snow_amount 0..1 builds up while it snows, holds, then melts (terrain +
##    grass shaders "snow_amount", roof colours); wetness 0..1 rises in rain and
##    dries slowly (terrain + grass shaders "wetness").
## CPUParticles3D (same on Forward+ and the web Compatibility renderer), in a
## small box that follows the camera, counts from the graphics preset
## (PerfQuality.style_id(): low / medium / high). Created by SeasonVisuals.

signal levels_changed(snow_amount: float, wetness: float)

var style  ## WeatherFxStyle (untyped: works before the class cache knows it)
var terrain_material: ShaderMaterial
var grass_material: ShaderMaterial

## Ground state (0..1).
var snow_amount: float = 0.0
var wetness: float = 0.0
## Falling now (0..1), set by SeasonVisuals from the weather.
var snow_intensity: float = 0.0
var rain_intensity: float = 0.0
var storm: bool = false
## Tests / screenshots: stop the game clock from changing snow_amount / wetness.
var hold_levels: bool = false

var snow: CPUParticles3D
var rain: CPUParticles3D
var splash: CPUParticles3D
var quality_id: String = ""

var _hours_since_snow: float = 999.0
var _hours_since_rain: float = 999.0
var _last_abs_min: float = -1.0
var _t: float = 0.0
var _slow_t: float = 0.0
var _indoors: bool = false
var _light: float = 1.0


const _WT := preload("res://scripts/v7b1_weather/weather_textures.gd")
const _STYLE := preload("res://modules/weather_fx/weather_fx_style.gd")


static func active_style() -> Resource:
	return Modules.style("weather_fx")


static func is_enabled() -> bool:
	var s = active_style()
	return s != null and bool(s.get("enabled"))


static func instance(tree: SceneTree) -> WeatherFx:
	return tree.get_first_node_in_group(&"weather_fx") as WeatherFx


func _ready() -> void:
	name = "WeatherFx"
	add_to_group(&"weather_fx")
	top_level = true
	style = active_style()
	if style == null:
		style = _STYLE.new()
	_build()
	quality_id = PerfQuality.style_id()
	GameEvents.building_entered.connect(func(_b: Node3D) -> void:
		_indoors = true
		_apply_counts())
	GameEvents.building_exited.connect(func(_b: Node3D) -> void:
		_indoors = false
		_apply_counts())
	Modules.on_swap("weather_fx", self, func(m: Resource) -> void:
		if m != null and m.get("snow_counts") != null:
			style = m
			_rebuild())
	_last_abs_min = _abs_minutes()
	_push_levels()
	if OS.has_feature("web"):
		print("WEATHER: ready style=%s quality=%s" % [str(style.get("id")), quality_id])
		_web_preview.call_deferred()


## Web preview / test hook: ?wx=snow | snowground | rain | storm forces that
## weather (and ground state) once after load, and logs "WEATHER:" lines.
func _web_preview() -> void:
	if not OS.has_feature("web"):
		return
	var q := str(JavaScriptBridge.eval("window.location.search", true))
	var m := RegEx.create_from_string("[?&]wx=([a-z]+)").search(q)
	print("WEATHER: query=%s match=%s" % [q, str(m != null)])
	if m == null:
		return
	var kind := m.get_string(1)
	await get_tree().create_timer(4.0).timeout
	match kind:
		"snow", "snowground":
			TimeManager.set_season(3)
			TimeManager.set_weather("snow" if kind == "snow" else "cloudy")
			set_levels(0.5 if kind == "snow" else 1.0, 0.0)
		"rain", "storm":
			TimeManager.set_season(0)
			TimeManager.set_weather(kind)
			set_levels(0.0, 1.0)
	restart_particles()
	await get_tree().create_timer(1.0).timeout
	var tex := ((snow.mesh as QuadMesh).material as StandardMaterial3D).albedo_texture
	print("WEATHER: wx=%s season=%s weather=%s snow_amount=%.2f wetness=%.2f counts=%s flake_tex=%s alpha=%s" % [kind,
		TimeManager.season_id(), TimeManager.weather_id, snow_amount, wetness, str(particle_counts()),
		str(tex.get_width()) if tex else "none",
		str(((snow.mesh as QuadMesh).material as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA)])


func _abs_minutes() -> float:
	return float(TimeManager.day - 1) * TimeManager.MINUTES_PER_DAY + TimeManager.minutes


# ---------------------------------------------------------------- particles
func _build() -> void:
	# Snow: soft round flakes.
	snow = CPUParticles3D.new()
	snow.name = "SoftSnow"
	snow.mesh = _WT.soft_quad(style.flake_size.y, _WT.flake())
	snow.scale_amount_min = clampf(style.flake_size.x / maxf(style.flake_size.y, 0.001), 0.1, 1.0)
	snow.scale_amount_max = 1.0
	snow.lifetime = style.snow_height / maxf(style.snow_fall_speed, 0.1)
	snow.direction = Vector3(0, -1, 0)
	snow.spread = 22.0
	snow.initial_velocity_min = style.snow_fall_speed * 0.75
	snow.initial_velocity_max = style.snow_fall_speed * 1.25
	snow.gravity = Vector3(0, -0.05, 0)
	snow.tangential_accel_min = -0.15
	snow.tangential_accel_max = 0.15
	snow.color_ramp = _fade_ramp(0.06, 0.88)
	_common(snow)
	add_child(snow)
	# Rain: thin crossed streaks aligned with their velocity (lean with the wind).
	rain = CPUParticles3D.new()
	rain.name = "RainStreaks"
	rain.mesh = _WT.streak_mesh(style.rain_width, style.rain_length)
	rain.particle_flag_align_y = true
	rain.lifetime = 7.0 / maxf(style.rain_speed, 1.0)
	rain.spread = 3.0
	rain.initial_velocity_min = style.rain_speed * 0.9
	rain.initial_velocity_max = style.rain_speed * 1.1
	rain.gravity = Vector3(0, -3.0, 0)
	rain.color_ramp = _fade_ramp(0.05, 0.92)
	_common(rain)
	add_child(rain)
	# Splashes: tiny soft droplets bouncing up from the ground.
	splash = CPUParticles3D.new()
	splash.name = "RainSplashes"
	splash.mesh = _WT.soft_quad(0.07, _WT.flake())
	splash.lifetime = 0.32
	splash.direction = Vector3(0, 1, 0)
	splash.spread = 55.0
	splash.initial_velocity_min = 0.6
	splash.initial_velocity_max = 1.3
	splash.gravity = Vector3(0, -9.0, 0)
	splash.scale_amount_min = 0.4
	splash.scale_amount_max = 1.0
	splash.color_ramp = _fade_ramp(0.0, 0.5)
	_common(splash)
	add_child(splash)
	_apply_counts(true)


func _common(p: CPUParticles3D) -> void:
	p.local_coords = false
	p.emitting = false
	p.visible = false
	p.amount = 8
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = Vector3(8, 0.5, 8)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.draw_order = CPUParticles3D.DRAW_ORDER_INDEX
	p.visibility_aabb = AABB(Vector3(-20, -14, -20), Vector3(40, 28, 40))


func _fade_ramp(fade_in: float, fade_out: float) -> Gradient:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 0.0 if fade_in > 0.0 else 1.0))
	g.set_color(1, Color(1, 1, 1, 0.0))
	if fade_in > 0.0:
		g.add_point(fade_in, Color(1, 1, 1, 1))
	g.add_point(fade_out, Color(1, 1, 1, 1))
	return g


func _rebuild() -> void:
	for p in [snow, rain, splash]:
		if is_instance_valid(p):
			p.queue_free()
	_build()


func box_size() -> float:
	return float(style.box_sizes.get(quality_id, 22.0))


func wanted_count(kind: String) -> int:
	var table: Dictionary = style.snow_counts
	var inten := snow_intensity
	match kind:
		"rain":
			table = style.rain_counts
			inten = rain_intensity
		"splash":
			table = style.splash_counts
			inten = rain_intensity if style.splashes else 0.0
	return int(round(float(table.get(quality_id, table.get("medium", 0))) * clampf(inten, 0.0, 1.0)))


## Sets amount / emitting / box for the current intensities + quality preset.
func _apply_counts(force: bool = false) -> void:
	var b := box_size()
	for pair in [[snow, "snow"], [rain, "rain"], [splash, "splash"]]:
		var p: CPUParticles3D = pair[0]
		var n := wanted_count(pair[1])
		var on := n > 0 and not _indoors
		if on:
			var amt := maxi(n, 4)
			if force or p.amount != amt:
				p.amount = amt  # (re)starts the system
				p.preprocess = p.lifetime if pair[1] != "splash" else 0.0
			p.emission_box_extents = Vector3(b * 0.5, 0.5 if pair[1] != "splash" else 0.05, b * 0.5)
			var ext := b * 0.5 + 6.0
			p.visibility_aabb = AABB(Vector3(-ext, -16, -ext), Vector3(ext * 2.0, 32, ext * 2.0))
		if p.emitting != on:
			p.emitting = on
		p.visible = on


## Called by SeasonVisuals whenever weather / season changes.
func set_precip(snow_i: float, rain_i: float, is_storm: bool) -> void:
	snow_intensity = clampf(snow_i, 0.0, 1.0)
	rain_intensity = clampf(rain_i, 0.0, 1.0)
	storm = is_storm
	_apply_counts()


func is_active(kind: String) -> bool:
	match kind:
		"snow":
			return snow != null and snow.emitting
		"rain":
			return rain != null and rain.emitting
		"storm":
			return storm and rain != null and rain.emitting
	return false


# ---------------------------------------------------------------- per frame
func _process(delta: float) -> void:
	_t += delta
	_follow()
	# Gentle global sway for the flakes (acceleration -> smooth back-and-forth drift).
	var sway: float = style.snow_sway
	snow.gravity = Vector3(sin(_t * 0.7) * sway + _wind().x * 0.3, -0.05, cos(_t * 0.53) * sway * 0.7 + _wind().z * 0.3)
	_slow_t -= delta
	if _slow_t <= 0.0:
		_slow_t = 0.5
		var q := PerfQuality.style_id()
		if q != quality_id:
			quality_id = q
			_apply_counts(true)
			_apply_roofs()
		_update_light()
		_aim_rain()
		if OS.has_feature("web"):
			var st := particle_counts()
			st["snow_amount"] = snappedf(snow_amount, 0.01)
			st["wetness"] = snappedf(wetness, 0.01)
			st["weather"] = TimeManager.weather_id
			st["roofs"] = roof_overlay_count()
			JavaScriptBridge.eval("window.farmWeather = %s;" % JSON.stringify(st), true)
		_roof_scan_t -= 0.5
		if _roof_scan_t <= 0.0:
			_roof_scan_t = 6.0
			if roof_snow_on() and snow_amount > 0.01:
				_scan_roofs()
			else:
				_apply_roofs()
	if not hold_levels:
		var now := _abs_minutes()
		var dm := now - _last_abs_min
		_last_abs_min = now
		if dm > 0.0:
			step_hours(minf(dm, TimeManager.MINUTES_PER_DAY) / 60.0)


func _wind() -> Vector3:
	var k: float = style.rain_wind * (2.0 if storm else 1.0)
	# Slowly veering wind (deterministic, no RNG state).
	var a := 0.6 + sin(_t * 0.05) * 0.5
	return Vector3(cos(a), 0, sin(a)) * k


func _aim_rain() -> void:
	var w := _wind()
	rain.direction = Vector3(w.x, -1.0, w.z).normalized()


## Particle box above the ground around (and a bit ahead of) the camera.
func _follow() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var c := cam.global_position
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	if fwd.length() > 0.01:
		fwd = fwd.normalized() * box_size() * 0.22
	var x := c.x + fwd.x
	var z := c.z + fwd.z
	var g := Terrain.height_at(x, z)
	global_position = Vector3(x, g, z)
	var top := maxf(style.snow_height, c.y - g + 3.0)
	snow.position = Vector3(0, top, 0)
	var life := top / maxf(style.snow_fall_speed, 0.1)
	if absf(snow.lifetime - life) > 1.0:
		snow.lifetime = life
	var w := _wind()
	var rh := maxf(7.0, c.y - g + 3.0)
	# Drops start upwind so they land around the camera.
	rain.position = Vector3(-w.x * rh, rh, -w.z * rh)
	var rlife := rh / maxf(style.rain_speed, 1.0)
	if absf(rain.lifetime - rlife) > 0.08:
		rain.lifetime = rlife
	splash.position = Vector3(0, 0.03, 0)


func _update_light() -> void:
	var dn: Node = get_tree().current_scene.get_node_or_null(^"DayNightCycle") if get_tree().current_scene else null
	var d := 1.0
	if dn and "daylight" in dn:
		d = clampf(float(dn.get("daylight")), 0.0, 1.0)
	_light = lerpf(0.38, 1.0, d)
	snow.color = Color(_light, _light, _light * 1.02, 0.92)
	rain.color = Color(0.74 * _light, 0.79 * _light, 0.88 * _light, style.rain_alpha)
	splash.color = Color(0.8 * _light, 0.84 * _light, 0.9 * _light, 0.55)


# ---------------------------------------------------------------- ground state
func _sun_factor() -> float:
	match TimeManager.weather_id:
		"sunny":
			return 1.5
		"heatwave":
			return 3.0
		"cloudy":
			return 0.7
		"rain", "storm":
			return 1.2  # rain washes snow away
	return 1.0


## Advances snow cover / wetness by `hours` of game time.
func step_hours(hours: float) -> void:
	if hours <= 0.0:
		return
	var old_snow := snow_amount
	var old_wet := wetness
	# Snow builds up while it snows ...
	if snow_intensity > 0.0:
		_hours_since_snow = 0.0
		snow_amount = minf(style.max_cover, snow_amount + style.accumulate_per_hour * snow_intensity * hours)
	else:
		# ... stays a while, then melts (slowly in winter, faster in sun / rain).
		var hold_left := maxf(style.snow_hold_hours - _hours_since_snow, 0.0)
		_hours_since_snow += hours
		var melt_h := maxf(hours - hold_left, 0.0)
		if melt_h > 0.0 and snow_amount > 0.0:
			var base := float(style.melt_per_hour.get("winter" if TimeManager.season_id() == "winter" else "other", 0.2))
			var melted := minf(snow_amount, base * _sun_factor() * melt_h)
			snow_amount -= melted
			wetness = minf(1.0, wetness + melted * 1.5)  # melt water
	# Rain soaks the ground ...
	if rain_intensity > 0.0:
		_hours_since_rain = 0.0
		wetness = minf(1.0, wetness + style.wet_per_hour * rain_intensity * hours)
	else:
		# ... it stays soaked a little, then dries.
		var hold := maxf(style.dry_hold_hours - _hours_since_rain, 0.0)
		_hours_since_rain += hours
		var dry_h := maxf(hours - hold, 0.0)
		if dry_h > 0.0 and snow_amount < 0.05:
			wetness = maxf(0.0, wetness - style.dry_per_hour * _sun_factor() * dry_h)
	if absf(old_snow - snow_amount) > 0.0005 or absf(old_wet - wetness) > 0.0005:
		_push_levels()


## Tests / screenshots / loading: set the ground state directly.
func set_levels(new_snow: float, new_wet: float) -> void:
	snow_amount = clampf(new_snow, 0.0, 1.0)
	wetness = clampf(new_wet, 0.0, 1.0)
	_push_levels()


func _push_levels() -> void:
	if terrain_material:
		terrain_material.set_shader_parameter("snow_amount", snow_amount)
		terrain_material.set_shader_parameter("wetness", wetness)
	if grass_material:
		grass_material.set_shader_parameter("snow_amount", snow_amount)
		grass_material.set_shader_parameter("wetness", wetness)
	_apply_roofs()
	levels_changed.emit(snow_amount, wetness)


## Roof snow: building roofs are baked into one merged mesh per house (vertex
## colours + a shared white material), so instead of recolouring materials a
## shared snow overlay (material_overlay, upward faces only, patchy noise) is put
## on each Building.roof_mesh while there is snow, and removed when it melts.
## One extra draw per roof only while snowy; skipped on the Low preset.
const ROOF_SNOW_SHADER := """shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.92, 0.94, 0.97);
varying vec3 wn;
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}
void vertex() {
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float up = smoothstep(0.3, 0.7, wn.y);
	float n = noise(wp.xz * 1.6) * 0.6 + noise(wp.xz * 5.1) * 0.4;
	float cover = clamp((snow_amount * 1.35 - n * 0.55) * 3.0, 0.0, 1.0);
	ALBEDO = snow_color * (0.94 + 0.06 * n);
	ALPHA = up * cover * 0.96;
	ROUGHNESS = 0.8;
}
"""

var _roof_overlay: ShaderMaterial
var _roof_meshes: Array[MeshInstance3D] = []
var _roof_scan_t: float = 0.0


func roof_snow_on() -> bool:
	return bool(style.roof_snow) and quality_id != "low"


func _apply_roofs() -> void:
	var on := roof_snow_on() and snow_amount > 0.01
	if not on:
		if not _roof_meshes.is_empty():
			for mi in _roof_meshes:
				if is_instance_valid(mi) and mi.material_overlay == _roof_overlay:
					mi.material_overlay = null
			_roof_meshes.clear()
		return
	if _roof_overlay == null:
		var sh := Shader.new()
		sh.code = ROOF_SNOW_SHADER
		_roof_overlay = ShaderMaterial.new()
		_roof_overlay.shader = sh
	_roof_overlay.set_shader_parameter("snow_amount", snow_amount)
	if _roof_meshes.is_empty():
		_scan_roofs()


## (Re)attach the overlay to every building roof (houses can be rebuilt / streamed).
func _scan_roofs() -> void:
	_roof_meshes.clear()
	for n in get_tree().get_nodes_in_group(&"buildings"):
		var mi: MeshInstance3D = n.get("roof_mesh") as MeshInstance3D if n is Building else null
		if mi and is_instance_valid(mi):
			if mi.material_overlay == null:
				mi.material_overlay = _roof_overlay
			if mi.material_overlay == _roof_overlay:
				_roof_meshes.append(mi)


func roof_overlay_count() -> int:
	var c := 0
	for mi in _roof_meshes:
		if is_instance_valid(mi) and mi.material_overlay == _roof_overlay:
			c += 1
	return c


func roof_overlay_amount() -> float:
	return float(_roof_overlay.get_shader_parameter("snow_amount")) if _roof_overlay else 0.0


## Screenshots / teleports: move the box to the camera now and refill it
## (preprocess) so flakes / drops are already falling around the new spot.
func restart_particles() -> void:
	_follow()
	_aim_rain()
	_update_light()
	for p in [snow, rain, splash]:
		if p.emitting:
			p.restart()


## Re-read the graphics preset now (normally polled twice a second).
func refresh_quality() -> void:
	quality_id = PerfQuality.style_id()
	_apply_counts(true)
	_apply_roofs()


func particle_counts() -> Dictionary:
	return {"snow": snow.amount if snow.emitting else 0, "rain": rain.amount if rain.emitting else 0,
		"splash": splash.amount if splash.emitting else 0, "quality": quality_id, "box": box_size()}
