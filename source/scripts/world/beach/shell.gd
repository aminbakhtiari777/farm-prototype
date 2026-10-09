class_name Shell
extends Node3D
## One collectable shell lying on the sand.

@export var item_id: String = "seashell"
var zone: Interactable


func _ready() -> void:
	add_to_group(&"shells")
	var mi := MeshInstance3D.new()
	match item_id:
		"conch":
			var cone := CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.09
			cone.height = 0.22
			cone.radial_segments = 8
			mi.mesh = cone
			mi.rotation = Vector3(0, 0, PI * 0.5)
			mi.position.y = 0.07
			mi.material_override = ProceduralProp.color_material(Color(0.95, 0.72, 0.6), 0.4, false)
		"scallop_shell":
			var fan := CylinderMesh.new()
			fan.top_radius = 0.11
			fan.bottom_radius = 0.11
			fan.height = 0.025
			fan.radial_segments = 7
			mi.mesh = fan
			mi.scale = Vector3(1, 1, 0.8)
			mi.position.y = 0.015
			mi.material_override = ProceduralProp.color_material(Color(0.95, 0.55, 0.4), 0.5, false)
		_:
			var s := SphereMesh.new()
			s.radius = 0.06
			s.height = 0.06
			s.radial_segments = 8
			s.rings = 4
			mi.mesh = s
			mi.scale = Vector3(1, 0.5, 1.3)
			mi.position.y = 0.012
			mi.material_override = ProceduralProp.color_material(Color(0.97, 0.93, 0.85), 0.4, false)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	zone = Interactable.new()
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.action_text = "pick up the %s" % GameData.item_name(item_id).to_lower()
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.9
	cs.shape = sp
	zone.add_child(cs)
	add_child(zone)
	zone.interacted.connect(_collect)


func _collect(_who: Node3D) -> void:
	Economy.add_item(item_id, 1)
	GameEvents.item_collected.emit(item_id)
	GameEvents.notification_requested.emit("+1 %s" % GameData.item_name(item_id))
	Sfx.play_at(&"pickup", global_position)
	queue_free()
