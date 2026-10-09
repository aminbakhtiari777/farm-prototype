@tool
class_name StreetLamp
extends ProceduralProp
## Iron street lamp with a glowing lantern (emissive; its OmniLight3D is switched on at night by DayNightCycle).

@export var height: float = 3.0


static var _lantern: StandardMaterial3D


## Shared lantern glass; DayNightCycle raises its glow at night.
static func lantern_material() -> StandardMaterial3D:
	if _lantern == null:
		_lantern = StandardMaterial3D.new()
		_lantern.albedo_color = Color(1.0, 0.9, 0.7)
		_lantern.emission_enabled = true
		_lantern.emission = Color(1.0, 0.82, 0.5)
		_lantern.emission_energy_multiplier = 0.3
	return _lantern


func _build(_rng: RandomNumberGenerator) -> void:
	var iron := color_material(Color(0.12, 0.12, 0.13), 0.45, false)
	add_cylinder(0.12, 0.16, 0.3, Vector3(0, 0.1, 0), color_material(Color(0.5, 0.48, 0.45), 0.9))
	add_cylinder(0.045, 0.06, height, Vector3(0, height * 0.5, 0), iron)
	add_box(Vector3(0.05, 0.05, 0.55), Vector3(0, height - 0.05, 0.25), iron)
	var lantern := Node3D.new()
	lantern.position = Vector3(0, height - 0.32, 0.5)
	add_child(lantern)
	add_box(Vector3(0.26, 0.04, 0.26), Vector3(0, 0.22, 0), iron, Vector3.ZERO, lantern)
	add_cylinder(0.0, 0.2, 0.14, Vector3(0, 0.31, 0), iron, Vector3.ZERO, 4, lantern)
	add_box(Vector3(0.2, 0.32, 0.2), Vector3(0, 0.04, 0), lantern_material(), Vector3.ZERO, lantern)
	if not Engine.is_editor_hint():
		var light := OmniLight3D.new()
		light.name = "LampLight"
		light.light_color = Color(1.0, 0.78, 0.45)
		light.omni_range = 9.0
		light.omni_attenuation = 1.2
		light.light_energy = 0.0
		light.shadow_enabled = false
		light.visible = false
		light.position = Vector3(0, -0.1, 0)
		light.add_to_group(&"night_lights")
		lantern.add_child(light)
	add_box(Vector3(0.24, 0.04, 0.24), Vector3(0, -0.13, 0), iron, Vector3.ZERO, lantern)
	add_cylinder_collider(0.12, height, Vector3(0, height * 0.5, 0))
