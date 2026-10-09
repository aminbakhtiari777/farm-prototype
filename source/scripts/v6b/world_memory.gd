extends Node
## v6b world memory (autoload "WorldMemory", module "world_memory"): every
## change the player makes to the world is remembered and saved with the game
## (SaveGame "world_memory" group, so the v5d save sync uploads / merges it):
##   moved   - pushed / stacked boxes, the sofa spot in each home (key -> pose)
##   holes   - dug holes (they fill back in after a few days, Digging)
##   drops   - items dropped on the ground
##   cars    - where each car was parked last
##   fruit   - orchard trees picked (and whether it was a gift or theft)
##   npc     - what each townsperson remembers about the player (helped them,
##             took fruit without asking, drove carefully...), shown in talk
##   routine - today's yard routine progress; herd - the flock's last state
## Also registers the v6b input actions (Y character, R horn).

signal changed(kind: String)

var moved: Dictionary = {}     ## key -> {"p": [x, y, z], "yaw": float}
var holes: Array = []          ## [{"x", "z", "day"}]
var drops: Array = []          ## [{"item", "p": [x, y, z], "day"}]
var cars: Dictionary = {}      ## car key -> {"p": [x, y, z], "yaw": float}
var fruit: Dictionary = {}     ## "home:index" -> {"day": int, "theft": bool}
var npc: Dictionary = {}       ## resident name -> [{"day", "kind", "en", "fa"}]
var routine: Dictionary = {}   ## {"day": int, "done": {task id: true}}
var herd: Dictionary = {}      ## {"penned_day": int, "pens": int}
var reports: Array = []        ## v7 hook: police reports [{"day", "kind", "who", "home", "fine"}]


func _ready() -> void:
	_register_inputs()
	TimeManager.day_started.connect(_on_day)


func style() -> WorldMemoryStyle:
	return Modules.style("world_memory") as WorldMemoryStyle


func keeps(kind: String) -> bool:
	var st := style()
	return st == null or st.remember.is_empty() or kind in st.remember


static func _key_event(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


func _register_inputs() -> void:
	for pair in [[&"character_panel", KEY_Y], [&"horn", KEY_R], [&"dig", KEY_R]]:
		if not InputMap.has_action(pair[0]):
			InputMap.add_action(pair[0])
			InputMap.action_add_event(pair[0], _key_event(pair[1]))


# ------------------------------------------------------------------ moved objects
func remember_pose(key: String, pos: Vector3, yaw: float = 0.0) -> void:
	if not keeps("moved"):
		return
	moved[key] = {"p": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "yaw": snappedf(yaw, 0.001)}
	changed.emit("moved")


func pose_of(key: String) -> Dictionary:
	return moved.get(key, {})


static func vec(a: Variant) -> Vector3:
	var arr: Array = a if a is Array else [0, 0, 0]
	return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))


# ------------------------------------------------------------------ holes
func add_hole(x: float, z: float) -> void:
	if not keeps("holes"):
		return
	holes.append({"x": snappedf(x, 0.01), "z": snappedf(z, 0.01), "day": TimeManager.day})
	var st := Modules.style("digging") as DiggingStyle
	var cap := st.max_holes if st else 24
	while holes.size() > cap:
		holes.pop_front()
	changed.emit("holes")


func hole_near(x: float, z: float, r: float) -> int:
	for i in holes.size():
		var h: Dictionary = holes[i]
		if Vector2(float(h["x"]) - x, float(h["z"]) - z).length() < r:
			return i
	return -1


# ------------------------------------------------------------------ drops
func add_drop(item: String, pos: Vector3) -> int:
	if not keeps("drops"):
		return -1
	drops.append({"item": item, "p": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "day": TimeManager.day})
	var st := style()
	while drops.size() > (st.drop_max if st else 40):
		drops.pop_front()
	changed.emit("drops")
	return drops.size() - 1


func take_drop(index: int) -> String:
	if index < 0 or index >= drops.size():
		return ""
	var d: Dictionary = drops[index]
	drops.remove_at(index)
	changed.emit("drops")
	return str(d.get("item", ""))


# ------------------------------------------------------------------ cars
func park(key: String, pos: Vector3, yaw: float) -> void:
	if not keeps("cars"):
		return
	cars[key] = {"p": [snappedf(pos.x, 0.01), snappedf(pos.y, 0.01), snappedf(pos.z, 0.01)], "yaw": snappedf(yaw, 0.001)}
	changed.emit("cars")


# ------------------------------------------------------------------ npc memories
## A townsperson remembers something the player did (shown when you talk).
func npc_remember(who: String, kind: String, en: String, fa: String) -> void:
	if who == "" or not keeps("npc"):
		return
	var list: Array = npc.get(who, [])
	list.append({"day": TimeManager.day, "kind": kind, "en": en, "fa": fa})
	var st := style()
	while list.size() > (st.npc_memory_max if st else 12):
		list.pop_front()
	npc[who] = list
	changed.emit("npc")


func npc_memories(who: String) -> Array:
	return npc.get(who, [])


func last_memory_line(who: String) -> String:
	var list := npc_memories(who)
	if list.is_empty():
		return ""
	var m: Dictionary = list[list.size() - 1]
	var ago := TimeManager.day - int(m.get("day", 0))
	if Lang.is_fa():
		var when := "امروز" if ago <= 0 else ("دیروز" if ago == 1 else "%s روز پیش" % Lang.digits(str(ago)))
		return "%s %s." % [when, str(m.get("fa", ""))]
	var when_en := "today" if ago <= 0 else ("yesterday" if ago == 1 else "%d days ago" % ago)
	return "I remember %s you %s." % [when_en, str(m.get("en", ""))]


## v7 hook: something the police should know about (fruit theft...).
func file_report(kind: String, who: String, home: String, fine: int) -> void:
	reports.append({"day": TimeManager.day, "kind": kind, "who": who, "home": home, "fine": fine})
	changed.emit("reports")


# ------------------------------------------------------------------ day
func _on_day(day: int) -> void:
	var st := style()
	if st and st.forget_days > 0:
		for who in npc.keys():
			var list: Array = (npc[who] as Array).filter(func(m: Dictionary) -> bool: return day - int(m.get("day", 0)) <= st.forget_days)
			npc[who] = list
		drops = drops.filter(func(d: Dictionary) -> bool: return day - int(d.get("day", 0)) <= 3)


func reset() -> void:
	moved.clear()
	holes.clear()
	drops.clear()
	cars.clear()
	fruit.clear()
	npc.clear()
	routine.clear()
	herd.clear()
	reports.clear()
	changed.emit("all")


func to_save() -> Dictionary:
	return {"moved": moved.duplicate(true), "holes": holes.duplicate(true), "drops": drops.duplicate(true),
		"cars": cars.duplicate(true), "fruit": fruit.duplicate(true), "npc": npc.duplicate(true),
		"routine": routine.duplicate(true), "herd": herd.duplicate(true), "reports": reports.duplicate(true)}


func from_save(d: Dictionary) -> void:
	moved = (d.get("moved", {}) as Dictionary).duplicate(true)
	holes = (d.get("holes", []) as Array).duplicate(true)
	drops = (d.get("drops", []) as Array).duplicate(true)
	cars = (d.get("cars", {}) as Dictionary).duplicate(true)
	fruit = (d.get("fruit", {}) as Dictionary).duplicate(true)
	npc = (d.get("npc", {}) as Dictionary).duplicate(true)
	routine = (d.get("routine", {}) as Dictionary).duplicate(true)
	herd = (d.get("herd", {}) as Dictionary).duplicate(true)
	reports = (d.get("reports", []) as Array).duplicate(true)
	changed.emit("all")
