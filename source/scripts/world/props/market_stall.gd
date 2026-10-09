@tool
class_name MarketStall
extends ProceduralProp
## Market stall: counter, crates of produce and a striped canopy.

@export var stripe_a: Color = Color(0.85, 0.25, 0.22)
@export var stripe_b: Color = Color(0.95, 0.92, 0.85)
## This stall is the town shop: pressing E in front of it opens the shop UI.
@export var is_shop: bool = false


func _build(rng: RandomNumberGenerator) -> void:
	var wood := color_material(Color(0.5, 0.35, 0.22), 0.85)
	var dark := color_material(Color(0.35, 0.24, 0.15), 0.85)
	add_box(Vector3(2.6, 0.9, 1.0), Vector3(0, 0.45, 0), wood)
	add_box(Vector3(2.75, 0.06, 1.15), Vector3(0, 0.92, 0), dark)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			add_box(Vector3(0.09, 2.3, 0.09), Vector3(sx * 1.3, 1.15, sz * 0.5), dark)
	# Striped canopy (sloping toward the front).
	for i in 7:
		var col := stripe_a if i % 2 == 0 else stripe_b
		add_box(Vector3(0.42, 0.04, 1.6), Vector3(-1.26 + i * 0.42, 2.38, 0.1), color_material(col, 0.9, false), Vector3(0.25, 0, 0))
	# Crates with produce.
	var produce: Array[Color] = [Color(0.85, 0.2, 0.15), Color(0.95, 0.6, 0.15), Color(0.5, 0.7, 0.2), Color(0.6, 0.3, 0.55)]
	for i in 3:
		var x := -0.85 + i * 0.85
		add_box(Vector3(0.7, 0.22, 0.5), Vector3(x, 1.06, 0.05), wood)
		var col := produce[rng.randi() % produce.size()]
		for k in 9:
			add_sphere(0.075, Vector3(x - 0.22 + (k % 3) * 0.22 + rng.randf_range(-0.02, 0.02), 1.2, -0.1 + floorf(k / 3.0) * 0.13), color_material(col, 0.45, false))
	add_box(Vector3(0.6, 0.45, 0.45), Vector3(1.7, 0.22, 0.4), wood, Vector3(0, 0.3, 0))
	add_box(Vector3(0.55, 0.4, 0.45), Vector3(-1.75, 0.2, 0.3), wood, Vector3(0, -0.2, 0))
	add_box_collider(Vector3(2.8, 2.4, 1.2), Vector3(0, 1.2, 0))
	if is_shop and not Engine.is_editor_hint():
		var zone := add_interaction("shop at the market", 1.6, Vector3(0, 0.9, 1.3))
		zone.interacted.connect(func(_who: Node3D) -> void: GameEvents.shop_requested.emit())
		# Small sign board on the canopy.
		add_box(Vector3(1.4, 0.36, 0.05), Vector3(0, 2.75, 0.9), color_material(Color(0.95, 0.9, 0.75), 0.8, false), Vector3(-0.1, 0, 0))
