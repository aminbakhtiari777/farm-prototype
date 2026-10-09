class_name FootstepAudio
extends Node
## v7b.1 sound_fx module consumer (footsteps). The farmer's own stride timer
## (Player._update_footsteps: one step per stride, shorter strides when running,
## silent when idle / airborne / sitting) keeps firing; this node only swaps the
## step sounds + volume for the surface under the feet every 0.2 s:
##   wood    indoors, pier, porches / decks (feet clearly above the terrain)
##   sand    the beach strip
##   stone   town square + market plaza
##   asphalt paved roads + sidewalks
##   grass   everything else (fields, dirt paths, meadows)
## Residents near the listener get their own quieter steps (nearest npc_max,
## from their real position). A possessed resident walks with the farmer's own
## full-volume steps (the invisible farmer drives its body), so it is skipped here.

var surface: String = "grass"
var npc_steps: int = 0
var possessed_steps: int = 0
var swaps: int = 0
var _timer: float = 0.0
var _npc_timer: float = 0.0
var _tracked: Dictionary = {}      ## bot instance id -> [bot, last_pos, distance]
var _surface_streams: Dictionary = {}  ## surface -> Array[AudioStream]


func style() -> SoundFxStyle:
	return Modules.style("sound_fx") as SoundFxStyle


func _ready() -> void:
	name = "FootstepAudio"
	Modules.on_swap("sound_fx", self, func(_m: Resource) -> void:
		_surface_streams.clear()
		surface = ""
		update_player())


func _world() -> V7b1AudioWorld:
	return get_parent() as V7b1AudioWorld


func player() -> Player:
	return get_tree().get_first_node_in_group(&"player") as Player


func streams_for(surf: String) -> Array:
	if not _surface_streams.has(surf):
		var out: Array = []
		var st := style()
		var spec: Dictionary = st.surfaces.get(surf, {}) if st else {}
		for p in spec.get("streams", []):
			var s := V7b1AudioWorld.stream(str(p))
			if s:
				out.append(s)
		_surface_streams[surf] = out
	return _surface_streams[surf]


func surface_db(surf: String) -> float:
	var st := style()
	var spec: Dictionary = st.surfaces.get(surf, {}) if st else {}
	return float(spec.get("db", -9.0))


func surface_pitch(surf: String) -> float:
	var st := style()
	var spec: Dictionary = st.surfaces.get(surf, {}) if st else {}
	return float(spec.get("pitch", 1.0))


## Surface under a world position (cheap: layout maths, no physics queries).
static func surface_at(pos: Vector3, indoors: bool = false) -> String:
	if indoors:
		return "wood"
	var ground := Terrain.height_at(pos.x, pos.z)
	if pos.y - ground > 0.28:
		return "wood"   # pier, porch, deck, floor above the terrain
	if TownLayout.sea_distance(pos.x, pos.z) > -TownLayout.SAND_WIDTH + 1.0:
		return "sand"
	var p := Vector2(pos.x, pos.z)
	if p.distance_to(TownLayout.TOWN_CENTER) < TownLayout.SQUARE_RADIUS + 3.0 or TownLayout.MARKET_RECT.grow(0.5).has_point(p):
		return "stone"
	for r in TownLayout.ROADS:
		var road: Dictionary = r
		if str(road.get("kind", "")) != "paved":
			continue
		var reach := float(road.get("half", 3.0)) + 1.8   # + sidewalk
		var pts: Array = road["points"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, a, b)) < reach:
				return "asphalt"
	return "grass"


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.2
		update_player()


## Swap the farmer's step sounds / volume for the current surface.
func update_player() -> void:
	var st := style()
	var pl := player()
	if pl == null or st == null or not st.footsteps:
		return
	var surf := surface_at(pl.global_position, pl.inside_building != null)
	var fs := pl.get_node_or_null(^"Footsteps") as AudioStreamPlayer3D
	if surf != surface:
		var list := streams_for(surf)
		if not list.is_empty():
			var typed: Array[AudioStream] = []
			for s in list:
				typed.append(s as AudioStream)
			pl.footstep_sounds = typed
			surface = surf
			swaps += 1
			if fs and _world():
				_world().configure(fs, 4.0, 30.0)
	if fs:
		var running := Vector2(pl.velocity.x, pl.velocity.z).length() > pl.walk_speed * 1.25
		fs.volume_db = surface_db(surface) + (st.run_db if running else 0.0)
		fs.pitch_scale = surface_pitch(surface) * randf_range(0.94, 1.06)


func _physics_process(delta: float) -> void:
	var st := style()
	if st == null or not st.footsteps:
		return
	_npc_timer -= delta
	if _npc_timer <= 0.0:
		_npc_timer = 0.5
		_pick_npcs(st)
	for id in _tracked.keys():
		var rec: Array = _tracked[id]
		var bot := rec[0] as TownspersonBot
		if bot == null or not is_instance_valid(bot) or not bot.is_inside_tree():
			_tracked.erase(id)
			continue
		var pos := bot.global_position
		var last: Vector3 = rec[1]
		var moved := Vector2(pos.x - last.x, pos.z - last.z).length()
		rec[1] = pos
		if moved > 1.5 or not bot.is_on_floor():
			continue  # teleport / falling
		rec[2] = float(rec[2]) + moved
		var possessed := _is_possessed(bot)
		var stride := st.npc_stride * (0.85 if possessed and moved / maxf(delta, 0.001) > 3.0 else 1.0)
		if float(rec[2]) >= stride:
			rec[2] = 0.0
			step_npc(bot, possessed)


func _possessed_bot() -> Node3D:
	var v7a: Node = get_tree().current_scene.get_node_or_null(^"V7aWorld") if get_tree().current_scene else null
	if v7a and "possession" in v7a:
		var p: Node = v7a.get("possession")
		if p and p.has_method("is_active") and p.call("is_active"):
			return p.get("bot") as Node3D
	return null


func _is_possessed(bot: Node3D) -> bool:
	return bot == _possessed_bot()


func _pick_npcs(st: SoundFxStyle) -> void:
	var w := _world()
	if w == null:
		return
	var e := w.ear()
	var cands: Array = []
	var pb := _possessed_bot()
	if st.npc_footsteps:
		for n in get_tree().get_nodes_in_group(&"townspeople"):
			var b := n as TownspersonBot
			if b == null or not b.visible or b == pb:
				continue
			var d := b.global_position.distance_to(e)
			if d < st.npc_radius:
				cands.append([d, b])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	var keep: Dictionary = {}
	for i in mini(cands.size(), st.npc_max):
		var b2: TownspersonBot = cands[i][1]
		keep[b2.get_instance_id()] = b2
	for id in _tracked.keys():
		if not keep.has(id):
			_tracked.erase(id)
	for id in keep:
		if not _tracked.has(id):
			var nb := keep[id] as Node3D
			_tracked[id] = [nb, nb.global_position, 0.0]


func tracked_count() -> int:
	return _tracked.size()


func step_npc(bot: Node3D, possessed: bool) -> void:
	var st := style()
	var w := _world()
	if st == null or w == null:
		return
	var surf := surface_at(bot.global_position, false)
	var list := streams_for(surf)
	if list.is_empty():
		return
	var db := surface_db(surf) if possessed else st.npc_db + (surface_db(surf) - surface_db("grass"))
	var p := w.play_at(list.pick_random() as AudioStream, bot.global_position + Vector3.UP * 0.1, db,
		surface_pitch(surf) * randf_range(0.9, 1.1), 3.0 if not possessed else 4.0, st.npc_radius + 4.0)
	if p:
		if possessed:
			possessed_steps += 1
		else:
			npc_steps += 1
