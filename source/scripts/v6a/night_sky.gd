class_name NightSky
extends Node
## v6a night sky ("night_sky" module): pushes the star field, Milky Way and
## the moon (direction + phase) to the sky shader, and scales the moonlight
## with the phase. Also applies the "real_clock" module: with the real clock
## on, game time follows the device clock and the moon shows the real lunar
## phase. Group "night_sky".

## Reference new moon (2000-01-06 18:14 UTC) and the synodic month (days).
const NEW_MOON_UNIX := 947182440.0
const SYNODIC := 29.530588853

var phase: float = 0.5
var moon_dir: Vector3 = Vector3(0, 0.6, -0.8)
var moon_visible: float = 0.0
var _mat: ShaderMaterial
var _timer: float = 0.0
var _force: bool = true


func _ready() -> void:
	add_to_group(&"night_sky")
	Modules.on_swap("night_sky", self, func(_m: AssetModule) -> void: _force = true)
	Modules.on_swap("real_clock", self, func(_m: AssetModule) -> void: apply_clock_setting())
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "real_clock":
			apply_clock_setting())
	apply_clock_setting()


func style() -> NightSkyStyle:
	return Modules.style("night_sky") as NightSkyStyle


func clock_style() -> RealClockStyle:
	return Modules.style("real_clock") as RealClockStyle


## Real clock on/off from Settings + the module mode.
func apply_clock_setting() -> void:
	var cs := clock_style()
	var on := bool(Settings.get_value("real_clock"))
	if cs and cs.mode == "always":
		on = true
	if cs == null:
		on = false
	if on != TimeManager.real_clock:
		TimeManager.set_real_clock(on)
	_force = true


static func real_phase(unix: float = -1.0) -> float:
	var u := Time.get_unix_time_from_system() if unix < 0.0 else unix
	return fposmod((u - NEW_MOON_UNIX) / 86400.0 / SYNODIC, 1.0)


## 0 = new moon, 0.5 = full moon.
func moon_phase() -> float:
	var cs := clock_style()
	if TimeManager.real_clock and cs and cs.real_moon:
		return real_phase()
	var st := style()
	var cycle := st.moon_cycle_days if st else 8.0
	return fposmod((float(TimeManager.day - 1) + TimeManager.hours_float() / 24.0) / maxf(cycle, 1.0) + 0.5, 1.0)


## Lit fraction of the disc (0..1).
func illumination() -> float:
	return 0.5 * (1.0 - cos(moon_phase() * TAU))


static func phase_name(p: float, fa: bool) -> String:
	var names_en := ["new moon", "waxing crescent", "first quarter", "waxing gibbous", "full moon", "waning gibbous", "last quarter", "waning crescent"]
	var names_fa := ["ماه نو", "هلال رو به رشد", "تربیع اول", "ماه رو به بدر", "ماه کامل (بدر)", "ماه رو به کاهش", "تربیع دوم", "هلال آخر ماه"]
	var i := int(round(p * 8.0)) % 8
	return names_fa[i] if fa else names_en[i]


## Moonlight energy factor for DayNightCycle.
func light_factor() -> float:
	var st := style()
	var full := (st.moonlight_full if st else 0.3) / 0.3
	return full * lerpf(0.3, 1.15, illumination())


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 and not _force:
		return
	_timer = 0.25
	update_sky()


func _material() -> ShaderMaterial:
	if _mat == null:
		var env := get_tree().current_scene.find_child("WorldEnvironment", true, false) as WorldEnvironment
		if env and env.environment and env.environment.sky and env.environment.sky.sky_material is ShaderMaterial:
			_mat = env.environment.sky.sky_material
	return _mat


func update_sky() -> void:
	_force = false
	var mat := _material()
	var cycle := get_tree().get_first_node_in_group(&"day_night") as DayNightCycle
	if mat == null or cycle == null:
		return
	var st := style()
	var hour := cycle.lighting_hour()
	var elev := cycle.sun_elevation(hour)
	var night := 1.0 if elev <= -3.0 else 0.0
	phase = moon_phase()
	var sun := cycle.sun
	if sun and night > 0.5:
		moon_dir = sun.global_basis.z.normalized()
	var dl := clampf((elev + 6.0) / 16.0, 0.0, 1.0)
	dl = dl * dl * (3.0 - 2.0 * dl)
	moon_visible = clampf(1.0 - dl * 1.6, 0.0, 1.0) if night > 0.5 else 0.0
	mat.set_shader_parameter(&"night_mode", night)
	mat.set_shader_parameter(&"moon_dir", moon_dir)
	mat.set_shader_parameter(&"moon_phase", phase)
	mat.set_shader_parameter(&"moon_amount", moon_visible)
	mat.set_shader_parameter(&"star_rot", hour / 24.0 * PI)
	if st:
		mat.set_shader_parameter(&"star_density", st.star_density)
		mat.set_shader_parameter(&"star_brightness", st.star_brightness)
		mat.set_shader_parameter(&"star_twinkle", st.twinkle)
		mat.set_shader_parameter(&"milky_way", st.milky_way)
		mat.set_shader_parameter(&"moon_size", st.moon_size)
		mat.set_shader_parameter(&"moon_color", st.moon_color)
	else:
		mat.set_shader_parameter(&"moon_amount", 0.0)
		mat.set_shader_parameter(&"milky_way", 0.0)


## Shots / tests: refresh now.
func refresh_now() -> void:
	_force = true
	update_sky()
