class_name DayNightCycle
extends Node
## Drives the sun/moon, sky, ambient light, fog and night lights from
## TimeManager (time of day, season day length, weather).
##
## Put one in the main scene and point it at the DirectionalLight3D and
## WorldEnvironment. Night lights: anything in the "night_lights" group
## (OmniLight3D) plus the shared window/lantern materials.

@export var sun: DirectionalLight3D
@export var world_environment: WorldEnvironment
## Lamp light energy at full night.
@export var lamp_energy: float = 2.2
## Azimuth (deg) of sunrise; the sun travels through the south to the west.
@export var sunrise_azimuth: float = 100.0

## 0 = deep night, 1 = full day (read by the smoke test / other systems).
var daylight: float = 1.0
## 0..1 how "golden hour" the light is.
var twilight: float = 0.0
## 0 = lamps off, 1 = lamps fully on.
var night_lights: float = 0.0

var _env: Environment
var _sky_mat: ShaderMaterial
var _base_ambient: float = 1.0
var _base_sun_energy: float = 1.35
var _sky_cache: Dictionary = {}
var _sky_timer: float = 0.0
var _force_sky: bool = true

const SUN_NOON := Color(1.0, 0.95, 0.86)
const SUN_LOW := Color(1.0, 0.56, 0.3)
const MOON := Color(0.6, 0.7, 1.0)


func _sky_color(key: String) -> Color:
	var style := Modules.style("sky") as SkyStyle
	if style == null:
		match key:
			"day_zenith": return Color(0.23, 0.42, 0.74)
			"day_horizon": return Color(0.70, 0.80, 0.90)
			"dusk_zenith": return Color(0.22, 0.27, 0.5)
			"dusk_horizon": return Color(0.98, 0.58, 0.32)
			"night_zenith": return Color(0.012, 0.02, 0.06)
			_: return Color(0.05, 0.075, 0.15)
	match key:
		"day_zenith": return style.day_zenith
		"day_horizon": return style.day_horizon
		"dusk_zenith": return style.dusk_zenith
		"dusk_horizon": return style.dusk_horizon
		"night_zenith": return style.night_zenith
		_: return style.night_horizon


func _ready() -> void:
	Modules.on_swap("sky", self, func(_m: AssetModule) -> void: _force_sky = true)
	Modules.on_swap("sea_horizon", self, func(_m: AssetModule) -> void: _force_sky = true)

	if world_environment:
		_env = world_environment.environment
		_base_ambient = _env.ambient_light_energy
		if _env.sky and _env.sky.sky_material is ShaderMaterial:
			_sky_mat = _env.sky.sky_material
	if sun:
		_base_sun_energy = sun.light_energy
	add_to_group(&"day_night")
	TimeManager.weather_changed.connect(func(_w: String) -> void: _force_sky = true)
	TimeManager.season_changed.connect(func(_s: int) -> void: _force_sky = true)
	TimeManager.settings_changed.connect(func() -> void: _force_sky = true)
	apply()


func _process(delta: float) -> void:
	_sky_timer -= delta
	apply()


## Effective hour used for lighting (frozen at midday when the cycle is off).
func lighting_hour() -> float:
	if not TimeManager.day_night_enabled:
		return (TimeManager.sunrise() + TimeManager.sunset()) * 0.5
	return TimeManager.hours_float()


## Sun elevation in degrees for an hour of the current season (negative = below horizon).
func sun_elevation(hour: float) -> float:
	var rise := TimeManager.sunrise()
	var set_h := TimeManager.sunset()
	var max_elev := float(GameData.season(TimeManager.season_index()).get("max_sun_elevation", 55.0))
	var day_len := set_h - rise
	var p := (hour - rise) / day_len
	if p >= 0.0 and p <= 1.0:
		return sin(p * PI) * max_elev
	# Night: dips below the horizon, deepest at the middle of the night.
	var night_len := 24.0 - day_len
	var q := fposmod(hour - set_h, 24.0) / night_len
	return -sin(q * PI) * 40.0


func apply() -> void:
	var hour := lighting_hour()
	var elev := sun_elevation(hour)
	var weather := GameData.weather(TimeManager.weather_id)
	var weather_light := float(weather.get("light", 1.0))
	var season := TimeManager.season_id()

	daylight = clampf((elev + 6.0) / 16.0, 0.0, 1.0)
	daylight = daylight * daylight * (3.0 - 2.0 * daylight)
	twilight = clampf(1.0 - absf(elev - 2.0) / 14.0, 0.0, 1.0) * (0.4 + 0.6 * weather_light)
	night_lights = 1.0 - clampf((daylight - 0.15) / 0.35, 0.0, 1.0)

	# --- Sun / moon ---
	if sun:
		var rise := TimeManager.sunrise()
		var set_h := TimeManager.sunset()
		var p := clampf((hour - rise) / (set_h - rise), 0.0, 1.0)
		var az := deg_to_rad(sunrise_azimuth + p * 160.0)
		var is_day := elev > -3.0
		var light_elev := elev
		if not is_day:
			# Moonlight from a fixed high angle across the night sky.
			var q := fposmod(hour - set_h, 24.0) / (24.0 - (set_h - rise))
			light_elev = 25.0 + sin(q * PI) * 25.0
			az = deg_to_rad(sunrise_azimuth + 40.0 + q * 100.0)
		var e := deg_to_rad(maxf(light_elev, 2.0))
		var to_light := Vector3(cos(e) * sin(az), sin(e), cos(e) * cos(az)).normalized()
		sun.global_basis = Basis.looking_at(-to_light, Vector3.UP)
		if is_day:
			var sun_amount := clampf((elev + 3.0) / 8.0, 0.0, 1.0)
			sun.light_color = SUN_NOON.lerp(SUN_LOW, clampf(1.0 - elev / 22.0, 0.0, 1.0))
			if season == "winter":
				sun.light_color = sun.light_color.lerp(Color(0.92, 0.95, 1.0), 0.35)
			elif season == "autumn":
				sun.light_color = sun.light_color.lerp(Color(1.0, 0.85, 0.65), 0.2)
			sun.light_energy = _base_sun_energy * sun_amount * weather_light
		else:
			var moon_amount := clampf((-elev - 3.0) / 6.0, 0.0, 1.0)
			sun.light_color = MOON
			sun.light_energy = 0.22 * moon_amount * clampf(weather_light * 1.4, 0.3, 1.0)
			# v6a: moonlight follows the moon phase (NightSky, "night_sky" module).
			var ns := get_tree().get_first_node_in_group(&"night_sky")
			if ns:
				sun.light_energy *= float(ns.call(&"light_factor"))
		sun.shadow_opacity = 1.0 if is_day else 0.7

	# --- Sky colours ---
	var zenith := _sky_color("night_zenith").lerp(_sky_color("day_zenith"), daylight)
	var horizon := _sky_color("night_horizon").lerp(_sky_color("day_horizon"), daylight)
	var dusk_mix := twilight * 0.85
	zenith = zenith.lerp(_sky_color("dusk_zenith") * maxf(daylight, 0.25), dusk_mix * 0.5)
	horizon = horizon.lerp(_sky_color("dusk_horizon") * maxf(daylight, 0.2) * 1.2, dusk_mix)
	var overcast := clampf((1.0 - weather_light) * 1.3, 0.0, 0.85)
	var grey := (zenith.r + zenith.g + zenith.b) / 3.0
	zenith = zenith.lerp(Color(grey, grey, grey * 1.08) * 1.15, overcast)
	grey = (horizon.r + horizon.g + horizon.b) / 3.0
	horizon = horizon.lerp(Color(grey, grey, grey * 1.05), overcast)
	if season == "winter":
		horizon = horizon.lerp(Color(0.8, 0.85, 0.92) * maxf(daylight, 0.1), 0.25 * daylight)
	elif season == "autumn":
		horizon = horizon.lerp(Color(0.85, 0.78, 0.66) * maxf(daylight, 0.1), 0.15 * daylight)
	var cloud_tint := Color(1, 1, 1).lerp(Color(1.0, 0.68, 0.5), twilight * 0.8) * lerpf(0.06, 1.0, daylight)
	cloud_tint = cloud_tint.lerp(cloud_tint * 0.7, overcast)
	var sky_vals := {
		"zenith_color": zenith, "horizon_color": horizon,
		"ground_color": Color(0.3, 0.33, 0.28) * lerpf(0.08, 1.0, daylight),
		"cloud_tint": cloud_tint,
		"cloud_coverage": float(weather.get("cloud_coverage", 0.5)) * _cloud_mult(weather_light),
		"clarity": _clarity() * daylight,
		"star_amount": clampf(1.0 - daylight * 2.5, 0.0, 1.0) * (1.0 - overcast),
		"sun_glow": lerpf(0.6, 1.2, twilight),
	}
	# v6b: blend the far sea into the horizon haze ("sea_horizon" module).
	var shs := Modules.style("sea_horizon") as SeaHorizonStyle
	sky_vals["sea_blend"] = shs.blend if shs else 0.0
	if shs:
		sky_vals["sea_color"] = (shs.sea_color * lerpf(0.08, 1.0, daylight)).lerp(horizon, clampf(shs.haze, 0.0, 1.0))
		sky_vals["sea_sharpness"] = shs.sharpness
	_set_sky(sky_vals)

	# --- Ambient / fog / exposure ---
	if _env:
		_env.ambient_light_energy = _base_ambient * lerpf(0.35, 1.0, daylight) * lerpf(0.85, 1.0, weather_light)
		_env.ambient_light_color = Color(0.25, 0.32, 0.55).lerp(Color(1, 1, 1), daylight)
		var fog := Color(0.07, 0.09, 0.16).lerp(Color(0.7, 0.79, 0.88), daylight)
		fog = fog.lerp(Color(0.92, 0.66, 0.5) * maxf(daylight, 0.3), twilight * 0.5)
		fog = fog.lerp(Color(0.62, 0.64, 0.68) * maxf(daylight, 0.15), overcast * 0.7)
		# v6b "sea_horizon": haze in the sky's horizon colour, so the far sea melts
		# into the sky instead of ending in a grey strip.
		if shs:
			fog = fog.lerp(horizon, clampf(shs.fog_match, 0.0, 1.0) * (1.0 - overcast * 0.5))
		_env.fog_light_color = fog
		_env.fog_density = 0.0045 * (1.0 + overcast * 1.5 + (0.6 if season == "winter" else 0.0))

	# --- Night lights --- (v4: the NightLights module drives lamps, windows
	# and power cuts from TimeManager; this is only the fallback.)
	var ctrl := get_tree().get_first_node_in_group(&"night_lights_controller")
	if ctrl:
		night_lights = float(ctrl.call(&"amount_at", hour))
		return
	var lamps := night_lights
	Building.set_night_glow(lamps)
	StreetLamp.lantern_material().emission_energy_multiplier = lerpf(0.3, 3.5, lamps)
	for node in get_tree().get_nodes_in_group(&"night_lights"):
		var light := node as Light3D
		if light:
			light.visible = lamps > 0.02
			light.light_energy = lamp_energy * lamps


## v6a: glassy clear skies - the sky style thins the clouds on fine days.
func _cloud_mult(weather_light: float) -> float:
	var st := Modules.style("sky") as SkyStyle
	if st == null or weather_light < 0.9:
		return 1.0
	return st.cloud_mult


func _clarity() -> float:
	var st := Modules.style("sky") as SkyStyle
	return st.clarity if st else 0.0


func _set_sky(values: Dictionary) -> void:
	if _sky_mat == null:
		return
	# Updating sky uniforms re-renders the (small) radiance map, so only push
	# changes a few times per second or when something jumped.
	if not _force_sky and _sky_timer > 0.0:
		return
	_sky_timer = 0.25
	_force_sky = false
	for key in values:
		var v: Variant = values[key]
		var old: Variant = _sky_cache.get(key)
		if old == null or _differs(old, v):
			_sky_mat.set_shader_parameter(key, v)
			_sky_cache[key] = v


func _differs(a: Variant, b: Variant) -> bool:
	if a is Color:
		var ca := a as Color
		var cb := b as Color
		return absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b) > 0.004
	return absf(float(a) - float(b)) > 0.003


## Forces an immediate full update (after time jumps, for screenshots/tests).
func refresh_now() -> void:
	_force_sky = true
	apply()
