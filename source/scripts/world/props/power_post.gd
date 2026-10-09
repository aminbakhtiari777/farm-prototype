class_name PowerPost
extends Node3D
## Wooden utility pole with the town's main breaker (electricity module).


func _ready() -> void:
	add_to_group(&"power_posts")
	global_position.y = Terrain.height_at(global_position.x, global_position.z)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.36, 0.26, 0.17)
	wood.roughness = 0.9
	var pole := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.12
	cm.height = 5.5
	pole.mesh = cm
	pole.position = Vector3(0, 2.75, 0)
	pole.material_override = wood
	add_child(pole)
	var arm := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.6, 0.1, 0.1)
	arm.mesh = bm
	arm.position = Vector3(0, 5.1, 0)
	arm.material_override = wood
	add_child(arm)
	for sx in [-0.7, 0.7]:
		var ins := MeshInstance3D.new()
		var im := CylinderMesh.new()
		im.top_radius = 0.04
		im.bottom_radius = 0.06
		im.height = 0.16
		ins.mesh = im
		ins.position = Vector3(sx, 5.23, 0)
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.4, 0.6, 0.5)
		ins.material_override = glass
		add_child(ins)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.14
	cyl.height = 5.5
	shape.shape = cyl
	shape.position.y = 2.75
	body.add_child(shape)
	add_child(body)
	var box := BreakerBox.new()
	box.name = "BreakerBox"
	box.label_text = "TOWN POWER"
	box.position = Vector3(0, 1.35, 0.13)
	add_child(box)
