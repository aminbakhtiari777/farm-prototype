class_name ShellSpawner
extends Node3D
## Scatters a handful of seashells on the sand every morning. Walk up and
## press E to pick one up (goes into the inventory, sellable at the shipping
## bin / shop). Uncollected shells wash away overnight.

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 2024
	TimeManager.day_started.connect(func(_d: int) -> void: spawn_for_day())
	spawn_for_day.call_deferred()


func spawn_for_day() -> void:
	for c in get_children():
		c.queue_free()
	var cfg: Dictionary = GameData.data.get("fishing", {})
	var range_v: Array = cfg.get("shells_per_day", [5, 9])
	var weights: Dictionary = cfg.get("shell_weights", {"seashell": 1.0})
	_rng.seed = 7919 * TimeManager.day + 13
	var count := _rng.randi_range(int(range_v[0]), int(range_v[1]))
	var placed := 0
	var attempts := 0
	while placed < count and attempts < 400:
		attempts += 1
		var p := Vector2(_rng.randf_range(15.0, 80.0), _rng.randf_range(-25.0, 40.0))
		var sd := TownLayout.sea_distance(p.x, p.y)
		if sd < -9.0 or sd > -0.6 or not Terrain.PLAY_AREA.grow(-1.0).has_point(p) or BeachBuilder.on_pier(p.x, p.y):
			continue
		var kind := _pick(weights)
		var shell := Shell.new()
		shell.item_id = kind
		shell.name = "Shell%d" % placed
		add_child(shell)
		shell.global_position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.02, p.y)
		shell.rotation.y = _rng.randf() * TAU
		placed += 1


func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := _rng.randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return str(k)
	return str(weights.keys()[0])


func active_shells() -> Array[Node]:
	var out: Array[Node] = []
	for c in get_children():
		if c is Shell and not c.is_queued_for_deletion():
			out.append(c)
	return out
