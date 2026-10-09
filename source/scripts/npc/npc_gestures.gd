class_name NpcGestures
extends Node
## v5a "gestures" module (GestureStyle): townspeople wave at the farmer when
## they pass within wave_distance (chance, cooldown per bot). The bot turns
## to the farmer and a WaveModifier raises and waves its right arm.

var waves: int = 0
var _timer: float = 0.0
var _cool: Dictionary = {}  ## bot -> seconds left


func style() -> GestureStyle:
	return Modules.style("gestures") as GestureStyle


func _process(delta: float) -> void:
	for b in _cool.keys():
		_cool[b] = float(_cool[b]) - delta
		if float(_cool[b]) <= 0.0 or not is_instance_valid(b):
			_cool.erase(b)
	_timer -= delta
	if _timer > 0.0:
		return
	_timer = 0.35
	var st := style()
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if st == null or player == null:
		return
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var bot := n as TownspersonBot
		if bot == null or _cool.has(bot) or bot.hidden_inside or not bot.visual or not bot.visual.visible:
			continue
		if bot.global_position.distance_to(player.global_position) > st.wave_distance:
			continue
		_cool[bot] = st.cooldown
		if randf() < st.wave_chance:
			wave(bot, player)


## Makes `bot` wave at `target` now (public for tests and the --shots tool).
func wave(bot: TownspersonBot, target: Node3D, seconds: float = -1.0) -> void:
	var st := style()
	var secs := seconds if seconds > 0.0 else (st.wave_seconds if st else 1.8)
	if bot.controller is ScheduleController and target:
		(bot.controller as ScheduleController).glance(bot, target, secs)
	bot.start_wave(secs, (st.arm_raise if st else 2.3) / 2.3, st.wave_speed if st else 2.4)
	waves += 1
