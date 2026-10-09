extends Node
## v6a lifestyle state (autoload "Lifestyle"): fitness from the gym, the dry
## trees (felled / regrowing), the beach campfire, boat trips and grilled
## fish. Saved with the game (SaveGame "lifestyle"). The world nodes
## (DryTrees, Campfire, Gym, Boats) read and change it; the healthy-life rules
## (fitness -> more stamina, faster recovery, fewer colds) live here.

signal fitness_changed(value: float)
signal trees_changed
signal campfire_changed(lit: bool)

const BASE_STAMINA := 100.0

var fitness: float = 0.0
var workouts: int = 0
var last_workout_day: int = 0
## tree index -> day it was felled (stump until it regrows).
var felled: Dictionary = {}
## tree index -> hits so far.
var hits: Dictionary = {}
var trees_chopped: int = 0
## Absolute game minute when the campfire goes out (0 = not lit).
var campfire_until: float = 0.0
var fish_grilled: int = 0
var boat_trips: int = 0
var sunbathed_minutes: float = 0.0
var sim_enabled: bool = true


func _ready() -> void:
	TimeManager.day_started.connect(_on_day)
	TimeManager.time_changed.connect(func(_h: int, _m: int) -> void:
		if campfire_until > 0.0 and abs_minutes() >= campfire_until:
			campfire_until = 0.0
			campfire_changed.emit(false))


static func abs_minutes() -> float:
	return float(TimeManager.day) * 1440.0 + TimeManager.minutes


# ------------------------------------------------------------------ fitness
func gym_style() -> GymStyle:
	return Modules.style("gym") as GymStyle


func fitness_ratio() -> float:
	var st := gym_style()
	return clampf(fitness / (st.fitness_max if st else 100.0), 0.0, 1.0)


func stamina_bonus() -> float:
	var st := gym_style()
	return (st.stamina_bonus if st else 40.0) * fitness_ratio()


## Illness chance multiplier (1.0 = untrained, lower = healthier).
func illness_mult() -> float:
	var st := gym_style()
	return lerpf(1.0, st.illness_mult if st else 0.5, fitness_ratio())


func add_fitness(amount: float) -> void:
	var st := gym_style()
	fitness = clampf(fitness + amount, 0.0, st.fitness_max if st else 100.0)
	workouts += 1
	last_workout_day = TimeManager.day
	apply_fitness()
	fitness_changed.emit(fitness)


## Pushes the stamina bonus to the player.
func apply_fitness() -> void:
	var tree := get_tree()
	var player := tree.get_first_node_in_group(&"player") if tree else null
	if player == null:
		return
	var base := float(GameData.data.get("stamina", {}).get("max", BASE_STAMINA))
	player.set("stamina_max", base + stamina_bonus())


# ------------------------------------------------------------------ dry trees
func dry_style() -> DryTreeStyle:
	return Modules.style("dry_trees") as DryTreeStyle


func is_felled(index: int) -> bool:
	return felled.has(index)


func hits_needed() -> int:
	var st := dry_style()
	var n := st.hits if st else 3
	var axe := Economy.best_tool("axe")
	if axe and axe.reach > 1:
		n -= axe.reach - 1
	return maxi(n, 1)


## One axe hit on tree `index`. Returns {"felled": bool, "items": {id: n}}.
func hit_tree(index: int, rng: RandomNumberGenerator = null) -> Dictionary:
	if is_felled(index):
		return {"felled": false, "items": {}}
	hits[index] = int(hits.get(index, 0)) + 1
	if int(hits[index]) < hits_needed():
		trees_changed.emit()
		return {"felled": false, "items": {}, "hits": hits[index]}
	hits.erase(index)
	felled[index] = TimeManager.day
	trees_chopped += 1
	var st := dry_style()
	var got := {}
	var y: Dictionary = st.yields if st else {"firewood": 3, "dry_wood": 2}
	for k in y:
		got[str(k)] = int(y[k])
	var r := rng.randf() if rng else randf()
	if st and r < st.board_chance:
		got["wood_plank"] = 1
	for k in got:
		Economy.add_item(str(k), int(got[k]))
		GameEvents.item_collected.emit(str(k))
	trees_changed.emit()
	return {"felled": true, "items": got}


## Morning: a few felled trees grow back (oldest first) so dry wood is always there.
func regrow(count: int) -> int:
	var order := felled.keys()
	order.sort_custom(func(a: int, b: int) -> bool: return int(felled[a]) < int(felled[b]))
	var n := 0
	for k in order:
		if n >= count:
			break
		if int(felled[k]) < TimeManager.day:
			felled.erase(k)
			n += 1
	if n > 0:
		trees_changed.emit()
	return n


# ------------------------------------------------------------------ campfire
func campfire_lit() -> bool:
	return campfire_until > 0.0 and abs_minutes() < campfire_until


func light_campfire(hours: float) -> void:
	campfire_until = abs_minutes() + hours * 60.0
	campfire_changed.emit(true)


func campfire_hours_left() -> float:
	return maxf(campfire_until - abs_minutes(), 0.0) / 60.0 if campfire_lit() else 0.0


# ------------------------------------------------------------------ day
func _on_day(day: int) -> void:
	var st := dry_style()
	regrow(st.regrow_per_day if st else 3)
	if not sim_enabled:
		return
	var g := gym_style()
	if g and day - last_workout_day > 1 and fitness > 0.0:
		fitness = maxf(fitness - g.decay_per_day, 0.0)
		apply_fitness()
		fitness_changed.emit(fitness)


func reset() -> void:
	fitness = 0.0
	workouts = 0
	last_workout_day = 0
	felled.clear()
	hits.clear()
	trees_chopped = 0
	campfire_until = 0.0
	fish_grilled = 0
	boat_trips = 0
	sunbathed_minutes = 0.0
	apply_fitness()
	trees_changed.emit()
	campfire_changed.emit(false)


func to_save() -> Dictionary:
	var f := {}
	for k in felled:
		f[str(k)] = felled[k]
	return {"fitness": fitness, "workouts": workouts, "last_workout_day": last_workout_day, "felled": f,
		"trees_chopped": trees_chopped, "campfire_until": campfire_until, "fish_grilled": fish_grilled,
		"boat_trips": boat_trips}


func from_save(d: Dictionary) -> void:
	fitness = float(d.get("fitness", 0.0))
	workouts = int(d.get("workouts", 0))
	last_workout_day = int(d.get("last_workout_day", 0))
	felled.clear()
	var f: Dictionary = d.get("felled", {})
	for k in f:
		felled[int(k)] = int(f[k])
	hits.clear()
	trees_chopped = int(d.get("trees_chopped", 0))
	campfire_until = float(d.get("campfire_until", 0.0))
	fish_grilled = int(d.get("fish_grilled", 0))
	boat_trips = int(d.get("boat_trips", 0))
	apply_fitness()
	fitness_changed.emit(fitness)
	trees_changed.emit()
	campfire_changed.emit(campfire_lit())
