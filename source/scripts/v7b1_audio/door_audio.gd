class_name DoorAudio
extends Node
## v7b.1 sound_fx module consumer (doors). Hooks every BuildingDoor - houses,
## shops, City Hall, the cafe / lounge, workplaces, the farmhouse, including
## doors built later (streamed interiors) via SceneTree.node_added. On open the
## door's own creak plays plus a latch click; on close the creak is cut and a
## wooden thud + latch plays instead, both from the door's real position (3D).
## Car doors are CarAudio's (per-model clunk).

var hooked: int = 0
var opens: Dictionary = {}    ## door instance id -> count of open sounds played
var closes: Dictionary = {}   ## door instance id -> count of close sounds played
var silent: int = 0           ## toggles too far from the listener to be heard
var range_override: float = -1.0


func style() -> SoundFxStyle:
	return Modules.style("sound_fx") as SoundFxStyle


func _ready() -> void:
	name = "DoorAudio"
	get_tree().node_added.connect(_on_node_added)
	_scan.call_deferred()


func _scan() -> void:
	for d in get_tree().get_nodes_in_group(&"doors"):
		hook(d)


func _on_node_added(n: Node) -> void:
	if n is BuildingDoor:
		hook.call_deferred(n)


func hook(n: Node) -> void:
	var d := n as BuildingDoor
	if d == null or not is_instance_valid(d) or d.has_meta(&"v7b1_door_audio"):
		return
	d.set_meta(&"v7b1_door_audio", true)
	var w := get_parent() as V7b1AudioWorld
	var creak := d.get("_audio") as AudioStreamPlayer3D
	if w and creak:
		w.configure(creak, 3.0, 25.0)
	var did := d.get_instance_id()
	d.toggled.connect(func(open: bool) -> void:
		var door := instance_from_id(did) as BuildingDoor
		if door:
			_on_toggled(door, open))
	hooked += 1


func doors() -> Array:
	return get_tree().get_nodes_in_group(&"doors")


func _on_toggled(d: BuildingDoor, open: bool) -> void:
	var st := style()
	var w := get_parent() as V7b1AudioWorld
	if st == null or not st.doors or w == null or not d.is_inside_tree():
		return
	var pos := d.global_position + d.global_basis.x * d.width * 0.5 + Vector3.UP * 1.1
	var reach := range_override if range_override > 0.0 else st.door_range
	if not open:
		# The closing creak is replaced by the thud.
		var creak := d.get("_audio") as AudioStreamPlayer3D
		if creak and creak.playing:
			creak.stop()
	var s := V7b1AudioWorld.stream(st.door_open if open else st.door_close)
	var p := w.play_at(s, pos, st.door_db, randf_range(0.93, 1.07), 3.5, reach)
	if p == null:
		silent += 1
		return
	var bucket := opens if open else closes
	bucket[d.get_instance_id()] = int(bucket.get(d.get_instance_id(), 0)) + 1
