class_name InteriorStreamer
extends Node
## Interior streaming. Homes (Building.kind == "home", not the farmhouse) are
## furnished lazily: the furniture / kitchen / interactive items are only
## instantiated when the player comes to the door or enters, and freed again
## after `release_after()` seconds away (or when their streaming cell sleeps).
## Other buildings keep their interior but stay dormant (hidden, process and
## physics off) beyond ~26 m - building.gd already did that.
## Other modules can register their own interiors (City Hall hall, disco...):
##   InteriorStreamer.register_interior(anchor, build_fn, free_fn, radius)
## build_fn() is called when the player gets within radius of the anchor,
## free_fn() when they are far again (radius + 15 m) and not inside.

static var built_count: int = 0  ## lazily built interiors right now
static var builds_total: int = 0
static var releases_total: int = 0
## Smoke tests force eager interiors (old sections count every interior item);
## the perf section flips this to test lazy mode on one home.
static var force_lazy: int = -1  ## -1 auto, 0 never, 1 always

var _custom: Array = []  ## [{anchor, build, free, radius, built}]
var _timer: float = 0.0


static func lazy_for(b: Node) -> bool:
	if force_lazy == 0:
		return false
	if force_lazy == -1:
		for a in OS.get_cmdline_user_args():
			if a == "--smoke-test" or a.begins_with("--shots") or a.begins_with("--net-test") or a == "--perf":
				return false
	var st := Modules.style("world_stream") as WorldStreamStyle
	if st == null or not st.enabled:
		return false
	return str(b.get("kind")) == "home" and str(b.get("layout_id")) != "farmhouse" and not bool(b.get("sleep_here"))


## Registered (module) interiors stream only in the real game; smoke tests,
## screenshots and net tests keep them deterministic (built on entry, never freed).
static func lazy_for_custom() -> bool:
	if force_lazy == 0:
		return false
	if force_lazy == -1:
		for a in OS.get_cmdline_user_args():
			if a == "--smoke-test" or a.begins_with("--shots") or a.begins_with("--vis-shots") or a.begins_with("--ctl-shots") or a.begins_with("--net-test") or a == "--perf":
				return false
	var st := Modules.style("world_stream") as WorldStreamStyle
	return st != null and st.enabled


static func release_after() -> float:
	return 45.0


## Player distance to the front door that furnishes a lazy home.
static func build_distance() -> float:
	return 11.0


## Interiors are only freed this far away (hysteresis against churn).
static func release_distance() -> float:
	return 45.0


static var _build_frame: int = -1


## At most one lazy interior build per frame (spreads the cost when several
## doors come into range at once, e.g. after a teleport).
static func can_build_now() -> bool:
	var f := Engine.get_process_frames()
	if f == _build_frame:
		return false
	_build_frame = f
	return true


static func note_built(_b: Node) -> void:
	built_count += 1
	builds_total += 1


static func note_released(_b: Node) -> void:
	built_count = maxi(built_count - 1, 0)
	releases_total += 1


func _ready() -> void:
	name = "InteriorStreamer"
	add_to_group(&"interior_streamer")


func register_interior(anchor: Node3D, build_fn: Callable, free_fn: Callable, radius: float = 22.0) -> void:
	_custom.append({"anchor": anchor, "build": build_fn, "free": free_fn, "radius": radius, "built": false})


func unregister_interior(anchor: Node3D) -> void:
	_custom = _custom.filter(func(x: Dictionary) -> bool: return x["anchor"] != anchor)


func custom_built() -> int:
	var n := 0
	for e in _custom:
		if e["built"]:
			n += 1
	return n


func awake_interiors() -> int:
	var n := 0
	for b in get_tree().get_nodes_in_group(&"buildings"):
		var ir: Node3D = b.get("interior_root")
		if ir and ir.visible:
			n += 1
	return n + custom_built()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer > 0.0 or _custom.is_empty():
		return
	_timer = 0.3
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p == null:
		return
	# Drop entries whose anchor was freed (module unloaded).
	_custom = _custom.filter(func(x: Dictionary) -> bool: return is_instance_valid(x["anchor"]))
	for e in _custom:
		var a := e["anchor"] as Node3D
		if a == null:
			continue
		var d := a.global_position.distance_to(p.global_position)
		if not e["built"] and d < float(e["radius"]):
			e["built"] = true
			(e["build"] as Callable).call()
		elif e["built"] and d > float(e["radius"]) + 15.0:
			e["built"] = false
			if (e["free"] as Callable).is_valid():
				(e["free"] as Callable).call()
