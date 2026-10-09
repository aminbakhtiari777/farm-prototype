class_name SeasonVisuals
extends Node3D
## Applies the current season and weather to the world: grass/terrain tint and
## snow, tree foliage colours (blossom / green / autumn / bare), flowers, pine
## frost, and weather particles (petals, falling leaves, rain, snow) that
## follow the player. Listens to TimeManager.season_changed / weather_changed.

@export var nature: NatureScatter
@export var terrain_material: ShaderMaterial
@export var grass_material: ShaderMaterial
@export var foliage_materials: Array[StandardMaterial3D] = []
@export var pine_material: StandardMaterial3D
## Scales all particle counts (lower for the web build).
@export var particle_scale: float = 1.0

## Per-season look. foliage = colours for foliage_materials (a, b, c).
const LOOKS := {
	"spring": {"grass_tint": Color(1.02, 1.12, 0.92), "terrain_tint": Color(1.02, 1.1, 0.95), "snow": 0.0,
		"foliage": [Color(0.34, 0.54, 0.2), Color(0.92, 0.66, 0.76), Color(0.3, 0.5, 0.2)], "pine": Color(0.15, 0.28, 0.16),
		"flowers": 1.0, "grass": 1.0, "canopy": true},
	"summer": {"grass_tint": Color(0.86, 0.98, 0.74), "terrain_tint": Color(0.86, 0.96, 0.76), "snow": 0.0,
		"foliage": [Color(0.17, 0.33, 0.12), Color(0.23, 0.39, 0.13), Color(0.14, 0.27, 0.13)], "pine": Color(0.12, 0.24, 0.14),
		"flowers": 0.55, "grass": 1.0, "canopy": true},
	"autumn": {"grass_tint": Color(1.55, 1.12, 0.55), "terrain_tint": Color(1.45, 1.05, 0.6), "snow": 0.0,
		"foliage": [Color(0.78, 0.4, 0.08), Color(0.62, 0.16, 0.07), Color(0.8, 0.6, 0.12)], "pine": Color(0.13, 0.24, 0.14),
		"flowers": 0.12, "grass": 1.0, "canopy": true},
	"winter": {"grass_tint": Color(1.1, 1.05, 0.9), "terrain_tint": Color(1.0, 0.95, 0.85), "snow": 0.92,
		"foliage": [Color(0.17, 0.33, 0.12), Color(0.23, 0.39, 0.13), Color(0.14, 0.27, 0.13)], "pine": Color(0.36, 0.45, 0.42),
		"flowers": 0.0, "grass": 0.3, "canopy": false},
}

var current_season: String = ""
var _particles: Dictionary = {}  ## kind -> CPUParticles3D
var _follow: Node3D
## v7b.1 weather visuals (scripts/v7b1_weather/, module "weather_fx"): soft snow,
## wind-angled rain, snow cover that builds / melts, wet ground. null = v4 particles.
## (Loaded by path + untyped so this file never depends on the class cache.)
var weather_fx = null
const _WT := preload("res://scripts/v7b1_weather/weather_textures.gd")
const _WFX_PATH := "res://scripts/v7b1_weather/weather_fx.gd"


func _ready() -> void:
	var wfx: Script = load(_WFX_PATH) if ResourceLoader.exists(_WFX_PATH) else null
	if wfx and wfx.call("is_enabled"):
		weather_fx = wfx.new()
	elif OS.has_feature("web"):
		print("WEATHER: v4 fallback particles (script %s)" % str(wfx != null))
		weather_fx.terrain_material = terrain_material
		weather_fx.grass_material = grass_material
		add_child(weather_fx)
	_build_particles()
	TimeManager.season_changed.connect(func(_i: int) -> void: apply())
	TimeManager.weather_changed.connect(func(_w: String) -> void: apply())
	apply.call_deferred()


func _process(_delta: float) -> void:
	if _follow == null:
		_follow = get_tree().get_first_node_in_group(&"player") as Node3D
	if _follow:
		global_position = _follow.global_position


func apply() -> void:
	current_season = TimeManager.season_id()
	var look: Dictionary = LOOKS.get(current_season, LOOKS["summer"])
	if terrain_material:
		terrain_material.set_shader_parameter("grass_tint", look["terrain_tint"])
		if weather_fx == null:  # v7b.1: WeatherFx drives snow cover from actual snowfall
			terrain_material.set_shader_parameter("snow_amount", look["snow"])
	if grass_material:
		grass_material.set_shader_parameter("tint", look["grass_tint"])
		if weather_fx == null:
			grass_material.set_shader_parameter("snow_amount", look["snow"])
	var cols: Array = look["foliage"]
	for i in foliage_materials.size():
		if foliage_materials[i]:
			foliage_materials[i].albedo_color = cols[i % cols.size()]
	if pine_material:
		pine_material.albedo_color = look["pine"]
	if nature:
		nature.apply_season(current_season)
		nature.set_canopy_visible(look["canopy"])
		nature.set_flower_fraction(look["flowers"])
		nature.set_grass_fraction(look["grass"])
	_update_particles()


## Current grass tint (used by tests to confirm the season changed the look).
func grass_tint() -> Color:
	return grass_material.get_shader_parameter("tint") if grass_material else Color.WHITE


func _update_particles() -> void:
	var weather := TimeManager.weather_id
	var wanted := {}
	if weather == "rain":
		wanted["rain"] = 1.0
	elif weather == "storm":
		wanted["rain"] = 1.0
		wanted["storm"] = 1.0
	if current_season == "winter":
		wanted["snow"] = 1.0 if weather == "snow" else 0.35
		wanted.erase("rain")
		wanted.erase("storm")
	elif current_season == "autumn" and not wanted.has("rain"):
		wanted["leaves"] = 1.0
	elif current_season == "spring" and not wanted.has("rain"):
		wanted["petals"] = 1.0
	if weather_fx:
		var snow_i := 1.0 if weather == "snow" else 0.0
		if snow_i == 0.0 and current_season == "winter" and weather == "cloudy":
			snow_i = weather_fx.style.flurry_intensity
		var rain_i := 1.0 if weather == "storm" else (0.7 if weather == "rain" else 0.0)
		weather_fx.set_precip(snow_i, rain_i, weather == "storm")
		for k in ["snow", "rain", "storm"]:
			wanted.erase(k)
	for kind in _particles:
		var p := _particles[kind] as CPUParticles3D
		var on := wanted.has(kind)
		if on:
			p.amount = maxi(4, int(p.get_meta("base_amount") * float(wanted[kind]) * particle_scale))
		p.emitting = on
		p.visible = on


func is_effect_active(kind: String) -> bool:
	if weather_fx and kind in ["snow", "rain", "storm"]:
		return weather_fx.is_active(kind)
	return _particles.has(kind) and (_particles[kind] as CPUParticles3D).emitting


func _build_particles() -> void:
	if weather_fx == null:
		_particles["snow"] = _make(&"Snow", 700, 9.0, Vector3(36, 1, 36), 12.0,
				_quad(0.06, Color(0.97, 0.98, 1.0), true), Vector3(0, -1.1, 0), 0.4, Color.WHITE)
		_particles["rain"] = _make(&"Rain", 900, 0.9, Vector3(30, 1, 30), 13.0,
				_streak(), Vector3(0, -24, 0), 0.0, Color(0.75, 0.8, 0.88, 0.55))
		_particles["storm"] = _make(&"StormRain", 700, 0.7, Vector3(30, 1, 30), 13.0,
				_streak(), Vector3(-3, -30, 0), 0.0, Color(0.7, 0.75, 0.82, 0.5))
	# v7b.1: leaves / petals are soft textured billboards (were opaque squares).
	_particles["leaves"] = _make(&"Leaves", 90, 11.0, Vector3(30, 1, 30), 9.0,
			_WT.soft_quad(0.14, _WT.leaf(), true, true), Vector3(0.4, -0.7, 0.2), 1.2, Color(0.85, 0.42, 0.1))
	_particles["petals"] = _make(&"Petals", 60, 12.0, Vector3(30, 1, 30), 7.0,
			_WT.soft_quad(0.07, _WT.petal(), true, true), Vector3(0.3, -0.35, 0.1), 0.9, Color(0.98, 0.78, 0.86))
	var leaf_ramp := Gradient.new()
	leaf_ramp.set_color(0, Color(0.9, 0.5, 0.1))
	leaf_ramp.set_color(1, Color(0.65, 0.15, 0.06))
	leaf_ramp.add_point(0.5, Color(0.85, 0.7, 0.15))
	(_particles["leaves"] as CPUParticles3D).color_initial_ramp = leaf_ramp


func _make(node_name: StringName, amount: int, lifetime: float, box: Vector3, height: float, mesh: Mesh,
		gravity: Vector3, spin: float, color: Color) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.name = node_name
	p.set_meta("base_amount", amount)
	p.amount = amount
	p.lifetime = lifetime
	p.preprocess = lifetime
	p.local_coords = false
	p.emitting = false
	p.visible = false
	p.mesh = mesh
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	p.emission_box_extents = box * 0.5
	p.position = Vector3(0, height, 0)
	p.gravity = gravity
	p.direction = Vector3(0, -1, 0)
	p.spread = 15.0
	p.initial_velocity_min = absf(gravity.y) * 0.2
	p.initial_velocity_max = absf(gravity.y) * 0.4
	p.damping_min = 0.0
	if spin > 0.0:
		p.angular_velocity_min = -180.0 * spin
		p.angular_velocity_max = 180.0 * spin
		p.angle_min = 0.0
		p.angle_max = 360.0
		p.damping_min = 0.4
		p.damping_max = 0.8
		p.gravity = gravity
	p.color = color
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-25, -20, -25), Vector3(50, 30, 50))
	add_child(p)
	return p


## v4 fallback (module weather_fx disabled). v7b.1: soft round texture + alpha
## so it is never a hard square.
func _quad(size: float, color: Color, billboard: bool) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size * (1.0 if billboard else 0.7))
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.albedo_texture = _WT.flake()
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 0.8
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	q.material = m
	return q


func _streak() -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(0.015, 0.55)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 1, 1, 1)
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	q.material = m
	return q
