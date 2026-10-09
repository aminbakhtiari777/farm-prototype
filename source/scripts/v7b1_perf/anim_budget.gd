class_name AnimBudget
extends Node
## Animation budget: AnimationPlayers / AnimationTrees that are not part of a
## townsperson (TownspersonBot runs its own preset-driven LOD) stop updating
## beyond the preset's anim_distance and resume when near. Skeletons of
## stopped mixers are not re-posed, so their cost drops to ~0.

var stopped: int = 0
var running: int = 0
var _timer: float = 0.0
var _off: Dictionary = {}  ## instance_id -> AnimationMixer we turned off
var _list: Array = []
var _list_age: float = 99.0


func _ready() -> void:
	name = "AnimBudget"
	add_to_group(&"anim_budget")


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.5
	_list_age += 0.5
	if _list_age > 4.0:
		_list_age = 0.0
		_list = get_tree().current_scene.find_children("*", "AnimationMixer", true, false).filter(func(m: Node) -> bool:
			var p := m.get_parent()
			while p:
				if p is TownspersonBot or p.is_in_group(&"player"):
					return false
				p = p.get_parent()
			return true)
	var lod := get_tree().get_first_node_in_group(&"auto_lod")
	var q: QualityStyle = lod.current_style() if lod else PerfQuality.style()
	var cam := get_viewport().get_camera_3d()
	if q == null or cam == null:
		return
	stopped = 0
	running = 0
	for m in _list:
		if not is_instance_valid(m) or not (m as Node).is_inside_tree():
			continue
		var mixer := m as AnimationMixer
		var owner3d := mixer.get_parent() as Node3D
		if owner3d == null:
			continue
		var far := owner3d.global_position.distance_to(cam.global_position) > q.anim_distance
		var id := mixer.get_instance_id()
		if far and mixer.active:
			mixer.active = false
			_off[id] = true
		elif not far and _off.has(id):
			mixer.active = true
			_off.erase(id)
		if mixer.active:
			running += 1
		else:
			stopped += 1
