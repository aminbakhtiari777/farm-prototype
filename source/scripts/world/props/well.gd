@tool
class_name TownWell
extends ProceduralProp
## Stone well with a little wooden roof, crank and bucket.


func _build(rng: RandomNumberGenerator) -> void:
	var stone := preload("res://assets/materials/rock.tres")
	var wood := color_material(Color(0.42, 0.29, 0.18), 0.85)
	var roof := color_material(Color(0.38, 0.22, 0.16), 0.8)
	# Ring of stones.
	for i in 14:
		var a := TAU * i / 14.0
		for layer in 3:
			var off := 0.5 * float(layer % 2) * TAU / 14.0
			var p := Vector3(cos(a + off), 0.0, sin(a + off)) * 0.85
			var m := add_box(Vector3(0.36, 0.26, 0.3), p + Vector3(0, 0.13 + layer * 0.25, 0), stone, Vector3(0, -(a + off), 0))
			m.scale = Vector3(rng.randf_range(0.9, 1.1), 1, 1)
	add_cylinder(0.75, 0.75, 0.05, Vector3(0, 0.45, 0), color_material(Color(0.05, 0.08, 0.1), 0.05, false))
	add_cylinder(0.97, 0.97, 0.08, Vector3(0, 0.8, 0), stone)
	# Posts, roof, crank.
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.12, 2.0, 0.12), Vector3(sx * 0.8, 1.0, 0), wood)
	add_cylinder(0.06, 0.06, 1.7, Vector3(0, 1.55, 0), wood, Vector3(0, 0, PI * 0.5))
	add_gable(1.9, 0.6, 1.4, Vector3(0, 2.25, 0), roof, Vector3(0, PI * 0.5, 0))
	for side in [-1.0, 1.0]:
		add_box(Vector3(2.1, 0.07, 0.9), Vector3(0, 2.28, side * 0.37), roof, Vector3(side * 0.7, 0, 0))
	add_cylinder(0.13, 0.11, 0.2, Vector3(0.2, 1.15, 0), color_material(Color(0.45, 0.3, 0.18), 0.8))
	add_box(Vector3(0.02, 0.35, 0.02), Vector3(0.2, 1.37, 0), color_material(Color(0.6, 0.55, 0.45), 0.6, false))
	add_cylinder_collider(1.0, 1.0, Vector3(0, 0.5, 0))
	if not Engine.is_editor_hint():
		var zone := add_interaction("refill the watering can", 1.9, Vector3(0, 0.8, 0))
		zone.interacted.connect(func(_who: Node3D) -> void:
			if not Economy.has("watering_can"):
				GameEvents.notification_requested.emit("You have no watering can")
				return
			Economy.refill_can()
			Sfx.play_at(&"splash", global_position + Vector3.UP, -10.0)
			GameEvents.notification_requested.emit("Watering can refilled (%d/%d)" % [Economy.water, Economy.can_capacity()]))
