extends RefCounted
## v7b.1 weather screenshots, run by DevShots (names "weather-*"):
##   xvfb-run -a godot --path . [--rendering-method gl_compatibility] -- --shots=/workspace/farm-v7b1 --only=weather-snowfall,weather-snow-ground,weather-rain-wet

const NAMES: PackedStringArray = ["weather-snowfall", "weather-snow-ground", "weather-rain-wet"]

var s  # DevShots


func _init(shots: Node) -> void:
	s = shots


func run(shot: String) -> void:
	var fx := WeatherFx.instance(s.get_tree())
	if fx == null:
		push_error("WeatherShots: no WeatherFx")
		return
	fx.hold_levels = true
	await call("_" + shot.replace("-", "_"), fx)
	fx.hold_levels = false
	s._player.visible = true


func _settle(fx: WeatherFx) -> void:
	await s._frames(30)
	fx.restart_particles()
	# a few real frames so the flakes / drops move and sort
	for i in 40:
		await s.get_tree().process_frame


## Close-up of snow falling in front of the farmhouse (snow just starting to settle).
func _weather_snowfall(fx: WeatherFx) -> void:
	s._time(22, 11.0, "snow")
	fx.set_levels(0.45, 0.0)
	s._place(Vector2(-1.5, 9.5), 20.0)
	s._view(Vector2(0.35, 1.0), -4.0, 3.2, Vector3(0, 0.1, 0))
	await _settle(fx)
	await s._capture("weather-snowfall")


## Wide view after a snowy day: white ground, frosted grass, white roofs.
func _weather_snow_ground(fx: WeatherFx) -> void:
	s._time(23, 12.0, "cloudy")
	fx.set_levels(1.0, 0.0)
	s._place(Vector2(-3, 7.5), 200.0)
	s._view(Vector2(0.55, 1.0), -22.0, 22.0, Vector3(0, 0, -6))
	await _settle(fx)
	await s._capture("weather-snow-ground")


## Storm rain with soaked, darker, glossy ground.
func _weather_rain_wet(fx: WeatherFx) -> void:
	s._time(3, 15.0, "storm")
	fx.set_levels(0.0, 1.0)
	s._place(Vector2(-1.5, 9.5), 20.0)
	s._view(Vector2(0.45, 1.0), -10.0, 6.0, Vector3(0, 0.2, 0))
	await _settle(fx)
	await s._capture("weather-rain-wet")
