class_name BreakerBox
extends Node3D
## Main power switch (electricity module). E toggles PowerGrid: cut the power
## and homes switch to candles / lanterns / firelight; flip it back to restore.
## The look (box + lever colours) comes from the active "power" module.

@export var label_text: String = "MAIN POWER"
var _lever: Node3D
var _zone: Interactable
var _lamp: MeshInstance3D
var _on_mat: StandardMaterial3D
var _off_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group(&"breakers")
	_build()
	PowerGrid.power_changed.connect(func(_on: bool) -> void: _refresh())
	Modules.on_swap("power", self, func(_m: AssetModule) -> void:
		for c in get_children():
			c.queue_free()
		_build())
	_refresh()


func _build() -> void:
	var st := Modules.style("power") as PowerStyle
	var box_col := st.box_color if st else Color(0.62, 0.64, 0.66)
	var lever_col := st.lever_color if st else Color(0.85, 0.15, 0.1)
	_mesh(BoxMesh.new(), Vector3(0.5, 0.62, 0.14), Vector3(0, 0, 0.07), _mat(box_col, 0.5))
	_mesh(BoxMesh.new(), Vector3(0.44, 0.04, 0.04), Vector3(0, 0.26, 0.15), _mat(box_col.darkened(0.3), 0.5))
	_lever = Node3D.new()
	_lever.position = Vector3(0, -0.02, 0.15)
	add_child(_lever)
	var stick := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.05, 0.22, 0.05)
	stick.mesh = sm
	stick.position = Vector3(0, 0.1, 0.03)
	stick.material_override = _mat(lever_col, 0.4)
	_lever.add_child(stick)
	_on_mat = _mat(Color(0.2, 1.0, 0.3), 0.3)
	_on_mat.emission_enabled = true
	_on_mat.emission = Color(0.2, 1.0, 0.3)
	_off_mat = _mat(Color(0.35, 0.05, 0.05), 0.3)
	_lamp = _mesh(SphereMesh.new(), Vector3(0.05, 0.05, 0.05), Vector3(0.17, 0.2, 0.15), _on_mat)
	var label := Label3D.new()
	label.text = label_text
	label.font_size = 28
	label.pixel_size = 0.0035
	label.modulate = Color(0.1, 0.1, 0.1)
	label.outline_size = 0
	label.position = Vector3(0, -0.22, 0.145)
	add_child(label)
	_zone = Interactable.new()
	_zone.name = "BreakerZone"
	_zone.collision_layer = 8
	_zone.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = 1.3
	cs.shape = sph
	cs.position = Vector3(0, -0.6, 0.8)
	_zone.add_child(cs)
	add_child(_zone)
	_zone.interacted.connect(func(_who: Node3D) -> void:
		PowerGrid.toggle()
		Sfx.play_at(&"switch", global_position))
	_refresh()


func _refresh() -> void:
	if _lever == null:
		return
	_lever.rotation.x = 0.0 if PowerGrid.power_on else PI
	if _lamp:
		_lamp.material_override = _on_mat if PowerGrid.power_on else _off_mat
	if _zone:
		_zone.set_action_text("cut the power (main switch)" if PowerGrid.power_on else "restore the power (main switch)")


func _mat(c: Color, r: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = r
	return m


func _mesh(mesh: PrimitiveMesh, size: Vector3, pos: Vector3, m: Material) -> MeshInstance3D:
	if mesh is BoxMesh:
		(mesh as BoxMesh).size = size
	elif mesh is SphereMesh:
		(mesh as SphereMesh).radius = size.x
		(mesh as SphereMesh).height = size.x * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = m
	add_child(mi)
	return mi
