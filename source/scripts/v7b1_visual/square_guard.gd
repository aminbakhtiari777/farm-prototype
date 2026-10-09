class_name SquareGuard
extends Node
## v7b.1: no one lies on the town square. Watches the townspeople near the
## square (and every other HumanoidModelVisual there: crews, officers) and
## stands up anyone whose body is tipped over / sunk into the paving / left in
## a lying or ground-sitting pose without a seat. `fixes` counts corrections.

const RADIUS := 16.0
var fixes: int = 0
var last_fixed: Array = []
var _t: float = 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 1.0
	check()


## Bodies near the square that look like they lie on the ground.
static func lying(tree: SceneTree) -> Array:
	var out: Array = []
	var c := TownLayout.TOWN_CENTER
	for n in tree.get_nodes_in_group(&"townspeople"):
		var bot := n as TownspersonBot
		if bot == null or not bot.is_visible_in_tree() or bot.visual == null:
			continue
		var p := bot.global_position
		if Vector2(p.x, p.z).distance_to(c) > RADIUS:
			continue
		var why := reason(bot)
		if why != "":
			out.append([bot, why])
	return out


static func reason(bot: TownspersonBot) -> String:
	var v := bot.visual as HumanoidModelVisual
	if v == null or not v.visible:
		return ""
	var p := bot.global_position
	var ground := Terrain.height_at(p.x, p.z)
	var seated := bot.get("_seat") != null
	if v.model and absf(v.model.rotation.x) > 0.35 and not seated:
		return "tipped (%.2f rad)" % v.model.rotation.x
	if v.get_pose() in [&"lie", &"ground_sit"] and not seated:
		return "pose %s" % v.get_pose()
	if absf(v.rotation.x) > 0.35 or absf(v.rotation.z) > 0.35 or absf(bot.rotation.x) > 0.35 or absf(bot.rotation.z) > 0.35:
		return "rotated"
	if p.y < ground - 0.6:
		return "sunk %.2f m" % (ground - p.y)
	return ""


func check() -> int:
	var n := 0
	last_fixed.clear()
	for e: Array in lying(get_tree()):
		var bot := e[0] as TownspersonBot
		var v := bot.visual as HumanoidModelVisual
		v.set_pose(&"")
		if v.model:
			v.model.rotation.x = 0.0
			v.model.position.y = 0.0
		v.rotation.x = 0.0
		v.rotation.z = 0.0
		bot.rotation.x = 0.0
		bot.rotation.z = 0.0
		var p := bot.global_position
		var ground := Terrain.height_at(p.x, p.z)
		if p.y < ground - 0.6:
			bot.global_position.y = ground + 0.1
		last_fixed.append("%s: %s" % [bot.display_name, e[1]])
		n += 1
	fixes += n
	return n
