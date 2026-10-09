class_name LampLightPool
extends Node3D
## Street lamps are cheap merged meshes; only the few lamps nearest to the
## camera get a real OmniLight3D (web/mobile can't afford 60 lights). The
## lights join the "night_lights" group, so DayNightCycle sets their energy.

@export var light_count: int = 8
var lamp_positions: PackedVector3Array = PackedVector3Array()
var _lights: Array[OmniLight3D] = []
var _timer: float = 0.0


func _ready() -> void:
	add_to_group(&"lamp_light_pools")
	_rebuild()


func set_light_count(n: int) -> void:
	n = clampi(n, 0, 16)
	if n == light_count and not _lights.is_empty():
		return
	light_count = n
	_rebuild()


func _rebuild() -> void:
	for l in _lights:
		if is_instance_valid(l):
			(l as Node).queue_free()
	_lights.clear()
	for i in light_count:
		var l := OmniLight3D.new()
		l.name = "PoolLight%d" % i
		l.light_color = Color(1.0, 0.78, 0.45)
		l.omni_range = 10.0
		l.omni_attenuation = 1.2
		l.light_energy = 0.0
		l.shadow_enabled = false
		l.visible = false
		l.add_to_group(&"night_lights")
		add_child(l)
		_lights.append(l)
	_timer = 0.0


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or lamp_positions.is_empty():
		return
	_timer = 0.4
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var origin := cam.global_position
	var order: Array = []
	for i in lamp_positions.size():
		order.append([lamp_positions[i].distance_squared_to(origin), i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in _lights.size():
		if k < order.size():
			_lights[k].global_position = lamp_positions[order[k][1]]
