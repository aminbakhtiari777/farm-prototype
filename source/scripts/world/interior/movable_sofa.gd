class_name MovableSofa
extends Node3D
## v6b living_room: a sofa you can push to the next spot along the room (E).
## The chosen spot is remembered (WorldMemory "sofa:<home>").

var key: String = ""
var base: Vector3
var yaw: float = 0.0
var slots: Array = [0.0]
var slot: int = 0
var size: Vector3 = Vector3(1.8, 0.85, 0.9)
var building: Building
var seat: Seat
var spot: ActionSpot
var _body: StaticBody3D
var pushes: int = 0


func _ready() -> void:
	add_to_group(&"movable_sofas")
	_body = StaticBody3D.new()
	_body.name = "SofaBody"
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size * Vector3(0.9, 1.0, 0.9)
	cs.shape = bs
	cs.position = Vector3(0, size.y * 0.5, 0)
	cs.rotation.y = yaw
	_body.add_child(cs)
	add_child(_body)
	var mem := WorldMemory.pose_of(key)
	if not mem.is_empty():
		slot = clampi(int(float(mem.get("yaw", 0.0))), 0, slots.size() - 1)
	_apply()
	# Push from the free side (the room side faces the TV).
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	spot = ActionSpot.make(self, -fwd * 0.95, 0.6,
		func() -> String: return Lang.tt("هل دادن مبل به جای دیگر", "push the sofa to another spot"), push)
	spot.name = "PushSofa"
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "all" and is_instance_valid(self):
			var m := WorldMemory.pose_of(key)
			slot = clampi(int(float(m.get("yaw", 0.0))), 0, slots.size() - 1) if not m.is_empty() else 0
			_apply())


func _apply() -> void:
	# Slots run along the wall the sofa faces away from (local x of the room).
	var along := Vector3(0, 0, 1)
	position = base + along * float(slots[slot])


func push(_who: Node3D = null) -> void:
	if seat and seat.occupant:
		return
	slot = (slot + 1) % slots.size()
	_apply()
	pushes += 1
	Sfx.play_at(&"land", global_position, -8.0, 0.7)
	# Store the slot index in "yaw" (a pose record: position + index).
	WorldMemory.remember_pose(key, position, float(slot))
