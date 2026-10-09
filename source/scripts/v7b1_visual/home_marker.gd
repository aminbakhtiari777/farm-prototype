class_name HomeMarker
extends Control
## v7b.1 door_plaques module: the player's home on the minimap - a pulsing
## green house badge on the farmhouse, and when it is off the map an arrow on
## the minimap edge pointing home with the distance (a simple waypoint).

var minimap: Minimap
var _t: float = 0.0
var last_pos: Vector2 = Vector2.ZERO   ## minimap pixel of the badge (tests)
var off_map: bool = false


func _ready() -> void:
	name = "HomeMarker"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	add_to_group(&"home_marker")


func home_world() -> Vector2:
	var b := TownLayout.building(DoorPlaques.player_home_id())
	return b.get("pos", Vector2.ZERO) if not b.is_empty() else Vector2.ZERO


func _process(delta: float) -> void:
	_t += delta
	if minimap and is_instance_valid(minimap) and size != minimap.size:
		position = Vector2.ZERO
		size = minimap.size
	if is_visible_in_tree():
		queue_redraw()


func _draw() -> void:
	if minimap == null or not is_instance_valid(minimap):
		return
	var col := DoorPlaques.home_color()
	if col.a <= 0.0:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var centre := Vector2.ZERO
	if player:
		centre = Vector2(player.global_position.x, player.global_position.z)
	var hp := home_world()
	var p := minimap.world_to_map(hp, centre)
	if size.x < 40.0 or size.y < 40.0:
		return
	# Headless / tiny viewports can yield a zero or negative Control size
	# before the minimap settles; abs() keeps has_point from erroring.
	var rect := Rect2(Vector2(12, 12), size - Vector2(24, 24)).abs()
	if rect.size.x < 8.0 or rect.size.y < 8.0:
		return
	off_map = not rect.has_point(p)
	var st := DoorPlaques.style()
	var pulse := 1.0 + (0.18 * sin(_t * 4.0) if st and st.home_pulse else 0.0)
	if off_map:
		# Waypoint arrow on the edge, pointing home.
		var c := size * 0.5
		var dir := (p - c).normalized()
		var edge := c + dir * (minf(size.x, size.y) * 0.5 - 14.0)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([edge + dir * 10.0 * pulse, edge - dir * 6.0 + side * 7.0, edge - dir * 6.0 - side * 7.0]), col)
		var dist := hp.distance_to(centre)
		var font := get_theme_default_font()
		draw_string(font, edge - dir * 22.0 + Vector2(-14, 4), Lang.digits("%d" % int(dist)) + Lang.tt("م", "m"), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, col.darkened(0.3))
		last_pos = edge
		return
	last_pos = p
	var r := 9.0 * pulse
	draw_circle(p, r + 3.0, Color(col.r, col.g, col.b, 0.35))
	draw_circle(p, r, col)
	# Little house glyph.
	var w := 5.0
	draw_colored_polygon(PackedVector2Array([p + Vector2(-w, 0), p + Vector2(0, -w - 1), p + Vector2(w, 0)]), Color.WHITE)
	draw_rect(Rect2(p + Vector2(-w * 0.7, 0), Vector2(w * 1.4, w * 0.9)), Color.WHITE)
