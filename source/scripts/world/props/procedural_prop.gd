@tool
class_name ProceduralProp
extends Node3D
## Base class for primitive-built props (houses, lamps, well, stall, sign).
## Subclasses override _build(). Children are regenerated when exports change
## (also in the editor) and are not saved into the scene. Collisions go into a
## StaticBody3D on the "world" layer. At runtime the prop snaps onto the terrain.
## Swap for a real .glb by replacing the instance in the scene.

@export var snap_to_terrain: bool = true
@export var random_seed: int = 1:
	set(v):
		random_seed = v
		_queue_rebuild()

static var _material_cache: Dictionary = {}
var _body: StaticBody3D
var _rebuild_queued := false


func _ready() -> void:
	if snap_to_terrain and not Engine.is_editor_hint():
		global_position.y = _ground_height()
	_rebuild()


## Lowest terrain height under the footprint corners, so nothing floats.
func _ground_height() -> float:
	return Terrain.height_at(global_position.x, global_position.z)


func _queue_rebuild() -> void:
	if not is_inside_tree() or _rebuild_queued:
		return
	_rebuild_queued = true
	_deferred_rebuild.call_deferred()


## Skipped when a synchronous _rebuild() already ran (e.g. from _ready).
func _deferred_rebuild() -> void:
	if _rebuild_queued:
		_rebuild()


func _rebuild() -> void:
	_rebuild_queued = false
	for child in get_children():
		child.queue_free()
	_body = StaticBody3D.new()
	_body.name = "Collision"
	_body.collision_layer = 1
	_body.collision_mask = 0
	add_child(_body)
	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed
	_build(rng)


func _build(_rng: RandomNumberGenerator) -> void:
	pass


# ------------------------------------------------------------------ helpers
static func color_material(color: Color, roughness: float = 0.85, detail: bool = true) -> StandardMaterial3D:
	var key := "%s_%.2f_%s" % [color.to_html(), roughness, detail]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	if detail:
		m.albedo_texture = preload("res://assets/materials/detail_noise_tex.tres")
		m.normal_enabled = true
		m.normal_texture = preload("res://assets/materials/detail_normal_tex.tres")
		m.normal_scale = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.7, 0.7, 0.7)
	_material_cache[key] = m
	return m


static func emissive_material(color: Color, energy: float) -> StandardMaterial3D:
	var key := "emit_%s_%.2f" % [color.to_html(), energy]
	if _material_cache.has(key):
		return _material_cache[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	_material_cache[key] = m
	return m


func add_box(size: Vector3, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(mesh, pos, mat, rot, parent)


func add_cylinder(top: float, bottom: float, height: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO, segments: int = 16, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	return _add_mesh(mesh, pos, mat, rot, parent)


func add_sphere(radius: float, pos: Vector3, mat: Material, scale_v: Vector3 = Vector3.ONE, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	var mi := _add_mesh(mesh, pos, mat, Vector3.ZERO, parent)
	mi.scale = scale_v
	return mi


func _add_mesh(mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3, parent: Node3D) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	(parent if parent else self).add_child(mi)
	return mi


## Adds an Interactable (layer "interaction", detects the player) to this prop.
func add_interaction(action: String, radius: float, pos: Vector3) -> Interactable:
	var zone := Interactable.new()
	zone.name = "Interaction"
	zone.action_text = action
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.position = pos
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)
	add_child(zone)
	return zone


func add_box_collider(size: Vector3, pos: Vector3, rot: Vector3 = Vector3.ZERO) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	shape.rotation = rot
	_body.add_child(shape)


func add_cylinder_collider(radius: float, height: float, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = radius
	cyl.height = height
	shape.shape = cyl
	shape.position = pos
	_body.add_child(shape)


## Triangular prism (for gables): triangle in the XY plane, extruded along Z by depth.
func add_gable(width: float, height: float, depth: float, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mesh := PrismMesh.new()
	mesh.size = Vector3(width, height, depth)
	return _add_mesh(mesh, pos, mat, rot, null)
