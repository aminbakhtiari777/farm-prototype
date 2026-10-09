class_name Carryable
extends StaticBody3D
## Something the farmer can pick up (E/F), carry in both hands and put down
## somewhere else (placement ghost shows where). Positions are saved:
## pre-placed carryables by `save_id`, runtime-spawned ones (crates from the
## workbench) by kind.

const KINDS := {
	"crate": {"name": "wooden crate", "size": Vector3(0.62, 0.5, 0.5)},
	"bucket": {"name": "bucket", "size": Vector3(0.36, 0.38, 0.36)},
	"pumpkin": {"name": "pumpkin", "model": "food:pumpkin.glb", "size": Vector3(0.5, 0.42, 0.5)},
	"watermelon": {"name": "watermelon", "model": "food:watermelon.glb", "size": Vector3(0.42, 0.34, 0.5)},
	"barrel": {"name": "small barrel", "model": "food:barrel.glb", "size": Vector3(0.48, 0.62, 0.48)},
	"plant": {"name": "potted plant", "model": "furn:pottedPlant.glb", "size": Vector3(0.45, 0.8, 0.45)},
	"stool": {"name": "stool", "model": "furn:stoolBar.glb", "size": Vector3(0.42, 0.72, 0.42)},
	"box": {"name": "cardboard box", "model": "furn:cardboardBoxClosed.glb", "size": Vector3(0.5, 0.4, 0.5)},
}

@export var kind: String = "crate"
@export var save_id: String = ""
## Pre-placed carryables drop onto the terrain on load.
@export var snap_on_ready: bool = false
var spawned: bool = false
var carried_by: Node3D = null
var zone: Interactable
var visual: Node3D
var _shape: CollisionShape3D

static var _spawn_counter: int = 0


static func make(kind_id: String, id: String = "") -> Carryable:
	var c := Carryable.new()
	c.kind = kind_id
	if id == "":
		_spawn_counter += 1
		id = "spawned_%d_%d" % [Time.get_ticks_msec(), _spawn_counter]
		c.spawned = true
	c.save_id = id
	c.name = "Carry_" + id
	return c


static func make_crate() -> Carryable:
	return make("crate")


func info() -> Dictionary:
	return KINDS.get(kind, KINDS["crate"])


func size() -> Vector3:
	return info()["size"]


func _ready() -> void:
	add_to_group(&"carryables")
	if snap_on_ready and not Engine.is_editor_hint():
		global_position.y = Terrain.height_at(global_position.x, global_position.z)
	collision_layer = 1
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size()
	_shape.shape = box
	_shape.position.y = size().y * 0.5
	add_child(_shape)
	visual = _build_visual()
	add_child(visual)
	zone = Interactable.new()
	zone.name = "CarryInteraction"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.action_text = "pick up the %s" % info()["name"]
	zone.position.y = size().y * 0.5
	zone.set_meta(&"carryable", self)
	var zs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = maxf(size().x, size().z) * 0.5 + 0.75
	zs.shape = sphere
	zone.add_child(zs)
	add_child(zone)
	zone.interacted.connect(func(who: Node3D) -> void:
		if who.has_method("pick_up"):
			who.call("pick_up", self))


func _resolve_model(path: String) -> String:
	var f := Modules.style("furniture") as FurnitureStyle
	if path.begins_with("food:"):
		return (f.food_dir if f else "res://assets/third_party/kenney/food/") + path.trim_prefix("food:")
	if path.begins_with("furn:"):
		return (f.furniture_dir if f else "res://assets/third_party/kenney/furniture/") + path.trim_prefix("furn:")
	return path


func _build_visual() -> Node3D:
	var root := Node3D.new()
	root.name = "Visual"
	var s := size()
	var d := info()
	if d.has("model") and ResourceLoader.exists(d["model"]):
		var inst := (load(d["model"]) as PackedScene).instantiate() as Node3D
		var aabb := AABB()
		var first := true
		for mi in inst.find_children("*", "MeshInstance3D", true, false):
			var a := MeshMerger._relative_xform(mi as MeshInstance3D, inst) * (mi as MeshInstance3D).mesh.get_aabb()
			aabb = a if first else aabb.merge(a)
			first = false
		var k := s.y / maxf(aabb.size.y, 0.001)
		inst.scale = Vector3.ONE * k
		inst.position = Vector3(-aabb.get_center().x * k, -aabb.position.y * k, -aabb.get_center().z * k)
		root.add_child(inst)
	elif kind == "bucket":
		var mi := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = s.x * 0.5
		cyl.bottom_radius = s.x * 0.4
		cyl.height = s.y
		mi.mesh = cyl
		mi.material_override = ProceduralProp.color_material(Color(0.5, 0.55, 0.6), 0.4, false)
		mi.position.y = s.y * 0.5
		root.add_child(mi)
		var water := MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = s.x * 0.46
		disc.bottom_radius = s.x * 0.46
		disc.height = 0.01
		water.mesh = disc
		water.material_override = ProceduralProp.color_material(Color(0.25, 0.45, 0.6), 0.1, false)
		water.position.y = s.y * 0.85
		root.add_child(water)
	else:
		# Wooden crate: frame of planks.
		var wood := ProceduralProp.color_material(Color(0.62, 0.45, 0.26), 0.8)
		var dark := ProceduralProp.color_material(Color(0.45, 0.31, 0.17), 0.8)
		var core := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s * 0.96
		core.mesh = bm
		core.material_override = wood
		core.position.y = s.y * 0.5
		root.add_child(core)
		for y: float in [0.04, s.y - 0.04]:
			for z: float in [-1.0, 1.0]:
				var plank := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(s.x, 0.07, 0.03)
				plank.mesh = pm
				plank.material_override = dark
				plank.position = Vector3(0, y, z * s.z * 0.49)
				root.add_child(plank)
		for x: float in [-1.0, 1.0]:
			for z: float in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var qm := BoxMesh.new()
				qm.size = Vector3(0.06, s.y, 0.06)
				post.mesh = qm
				post.material_override = dark
				post.position = Vector3(x * s.x * 0.47, s.y * 0.5, z * s.z * 0.47)
				root.add_child(post)
	return root


## Called by the carrier when lifting: no collision, no prompt.
func on_picked_up(by: Node3D) -> void:
	carried_by = by
	collision_layer = 0
	zone.enabled = false
	zone.monitoring = false


## Called when put down (already moved to its new global transform).
func on_placed() -> void:
	carried_by = null
	collision_layer = 1
	zone.enabled = true
	zone.monitoring = true


func to_save() -> Dictionary:
	var p := global_position
	return {"id": save_id, "kind": kind, "spawned": spawned, "pos": [p.x, p.y, p.z], "yaw": global_rotation.y}
