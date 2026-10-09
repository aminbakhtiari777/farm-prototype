@tool
class_name Signpost
extends ProceduralProp
## Wooden signpost with a text board (Label3D on both sides).

@export var text: String = "Town ->":
	set(v):
		text = v
		_queue_rebuild()


func _build(_rng: RandomNumberGenerator) -> void:
	var wood := color_material(Color(0.45, 0.31, 0.2), 0.85)
	add_box(Vector3(0.12, 1.9, 0.12), Vector3(0, 0.95, 0), wood)
	add_box(Vector3(1.3, 0.42, 0.06), Vector3(0.35, 1.55, 0), color_material(Color(0.62, 0.47, 0.3), 0.8))
	add_cylinder(0.0, 0.12, 0.22, Vector3(1.09, 1.55, 0), color_material(Color(0.62, 0.47, 0.3), 0.8), Vector3(0, 0, -PI * 0.5), 4)
	for side in [1.0, -1.0]:
		var label := Label3D.new()
		# Seen from behind, the arrow must point the other way to stay correct.
		label.text = text if side > 0 else ("<- " + text.trim_suffix("->").strip_edges() if text.ends_with("->") else text)
		label.font_size = 64
		label.pixel_size = 0.004
		label.outline_size = 0
		label.modulate = Color(0.22, 0.13, 0.07)
		label.position = Vector3(0.35, 1.55, side * 0.035)
		label.rotation.y = 0.0 if side > 0 else PI
		label.double_sided = false
		add_child(label)
	add_cylinder_collider(0.1, 1.9, Vector3(0, 0.95, 0))
