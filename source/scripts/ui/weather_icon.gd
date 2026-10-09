class_name WeatherIcon
extends Control
## Draws a little weather icon (sun / moon / cloud / rain / storm / snow / heat).

var weather: String = "sunny"
var night: bool = false


func _ready() -> void:
	custom_minimum_size = Vector2(34, 30)
	mouse_filter = Control.MOUSE_FILTER_PASS


func set_weather(id: String, is_night: bool) -> void:
	if id != weather or is_night != night:
		weather = id
		night = is_night
		tooltip_text = GameData.weather(id).get("name", id.capitalize()) + (" (night)" if is_night else "")
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var sun := Color(1.0, 0.82, 0.25)
	var cloud := Color(0.92, 0.94, 0.97)
	var dark := Color(0.55, 0.58, 0.65)
	match weather:
		"sunny", "heatwave":
			if night:
				_moon(c)
			else:
				var col := sun if weather == "sunny" else Color(1.0, 0.55, 0.2)
				draw_circle(c, 7.0, col)
				for i in 8:
					var a := TAU * i / 8.0
					draw_line(c + Vector2.from_angle(a) * 10.0, c + Vector2.from_angle(a) * 14.0, col, 2.0, true)
		"cloudy":
			if night:
				_moon(c + Vector2(-6, -5))
			else:
				draw_circle(c + Vector2(-6, -6), 6.0, sun)
			_cloud(c + Vector2(2, 3), cloud)
		"rain":
			_cloud(c + Vector2(0, -2), dark)
			for i in 3:
				var x := c.x - 7 + i * 7
				draw_line(Vector2(x, c.y + 6), Vector2(x - 3, c.y + 13), Color(0.45, 0.65, 1.0), 2.0, true)
		"storm":
			_cloud(c + Vector2(0, -3), Color(0.4, 0.42, 0.48))
			draw_polyline(PackedVector2Array([c + Vector2(1, 3), c + Vector2(-4, 10), c + Vector2(1, 10), c + Vector2(-3, 16)]), Color(1, 0.9, 0.3), 2.5, true)
		"snow":
			_cloud(c + Vector2(0, -3), cloud)
			for i in 3:
				draw_circle(Vector2(c.x - 7 + i * 7, c.y + 10 + (i % 2) * 3), 2.0, Color(1, 1, 1))
		_:
			draw_circle(c, 7.0, sun)


func _moon(c: Vector2) -> void:
	draw_circle(c, 8.0, Color(0.95, 0.93, 0.8))
	draw_circle(c + Vector2(4, -3), 7.0, Color(0.13, 0.12, 0.1, 1.0))


func _cloud(c: Vector2, col: Color) -> void:
	draw_circle(c + Vector2(-6, 1), 5.5, col)
	draw_circle(c + Vector2(0, -3), 7.0, col)
	draw_circle(c + Vector2(7, 1), 5.5, col)
	draw_rect(Rect2(c + Vector2(-11, 1), Vector2(23, 6)), col)
