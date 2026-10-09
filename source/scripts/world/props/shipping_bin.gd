@tool
class_name ShippingBin
extends ProceduralProp
## Wooden shipping bin by the farmhouse. Pressing E ships (sells) all produce
## in the inventory at today's prices; money is paid instantly.


func _build(_rng: RandomNumberGenerator) -> void:
	var wood := color_material(Color(0.52, 0.36, 0.22), 0.85)
	var dark := color_material(Color(0.36, 0.25, 0.15), 0.85)
	add_box(Vector3(1.3, 0.75, 0.85), Vector3(0, 0.375, 0), wood)
	for i in 3:
		add_box(Vector3(1.32, 0.04, 0.87), Vector3(0, 0.12 + i * 0.25, 0), dark)
	for sx in [-1.0, 1.0]:
		add_box(Vector3(0.08, 0.8, 0.9), Vector3(sx * 0.63, 0.4, 0), dark)
	add_box(Vector3(1.4, 0.07, 0.95), Vector3(0, 0.82, -0.12), dark, Vector3(-0.35, 0, 0))
	add_box_collider(Vector3(1.4, 0.9, 0.95), Vector3(0, 0.45, 0))
	if not Engine.is_editor_hint():
		var zone := add_interaction("ship produce (sell)", 1.5, Vector3(0, 0.6, 0.9))
		zone.interacted.connect(_on_ship)


func _on_ship(_who: Node3D) -> void:
	if Economy.sellable_items().is_empty():
		GameEvents.notification_requested.emit("Nothing to ship - harvest crops or collect wool")
		return
	var total := Economy.sell_all()
	GameEvents.notification_requested.emit("Shipped! +%d G" % total)
