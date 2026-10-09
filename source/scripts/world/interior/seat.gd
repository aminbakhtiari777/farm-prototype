class_name Seat
extends Node3D
## Somewhere to sit: chair, sofa, bench. This node marks where the sitter's
## feet/root go; the sitter faces this node's +Z. Anyone with sit_on(Seat)
## (the Player, TownspersonBot) can use it.

@export var display_name: String = "bench"
@export var interact_radius: float = 1.1

var occupant: Node3D = null
## v6a: emitted after someone sits (gym stations / towels hook into it). The
## node meta "pose" (sit, lie, jog, lift, ground_sit) picks the pose.
signal used(who: Node3D)
var zone: Interactable


func _ready() -> void:
	add_to_group(&"seats")
	zone = Interactable.new()
	zone.name = "SeatInteraction"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.action_text = "sit on the %s" % display_name
	zone.position = Vector3(0, 0.6, 0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = interact_radius
	shape.shape = sphere
	zone.add_child(shape)
	add_child(zone)
	zone.interacted.connect(_on_interacted)


func _on_interacted(who: Node3D) -> void:
	if occupant == null and who.has_method("sit_on"):
		who.call("sit_on", self)


func is_free() -> bool:
	return occupant == null


func claim(who: Node3D) -> bool:
	if occupant != null and occupant != who:
		return false
	occupant = who
	zone.enabled = false
	return true


func release(who: Node3D) -> void:
	if occupant == who:
		occupant = null
		zone.enabled = true


## Yaw (radians) a sitter should face.
func facing_yaw() -> float:
	var f := global_basis.z
	return atan2(f.x, f.z)
