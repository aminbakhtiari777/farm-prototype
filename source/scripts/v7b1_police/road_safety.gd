class_name RoadSafety
extends RefCounted
## v7b.1 "road_safety" module, part 1 (police workstream): every AI vehicle
## (RoadCar: police, ambulance, fire truck, outage van, wood pickup, NPC
## traffic, bus) yields to people.
##  - people_gate (RoadCar.people_gate hook): looks ahead along the car's own
##    route (curves included) for nose + stop margin + reaction + braking
##    distance, also where walkers will be in ~1 s, and caps the speed so the
##    car stops `stop_margin` m before them. No time-out: the old v6b check let a
##    car drive on through a person after 12 s blocked.
##  - a townsperson blocking a waiting car for `step_aside_s` steps aside;
##  - pedestrian_filter (TownspersonBot.move_filter hook): walkers wait at the
##    kerb instead of stepping in front of a close moving car.
## Cheap: one spatial grid of people per physics frame (16 m cells), cars far
## from the camera re-check every `far_interval` s.

const CELL := 16.0
const PERSON_R := 0.3

static var _frame: int = -1
static var _grid: Dictionary = {}          ## Vector2i -> Array[Node3D]
static var _cam: Vector3 = Vector3.INF
static var _road_cars: Dictionary = {}     ## instance id -> RoadCar (registered by the gate)
static var _mov_frame: int = -1
static var _moving: Array = []             ## [{car, pos: Vector2, fwd: Vector2, speed, hw, hl}]
## Tests / diagnostics.
static var gate_calls: int = 0
static var yields: int = 0
static var step_asides: int = 0
static var kerb_waits: int = 0


static var _st: RoadSafetyStyle
static var _st_frame: int = -1


## Cached once per physics frame (called by every bot / car).
static func style() -> RoadSafetyStyle:
	var f := Engine.get_physics_frames()
	if f != _st_frame or _st == null:
		_st_frame = f
		_st = Modules.style("road_safety") as RoadSafetyStyle
	return _st


static func flat(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


# ------------------------------------------------------------------ people grid
static func _refresh(tree: SceneTree) -> void:
	var f := Engine.get_physics_frames()
	if f == _frame or tree == null:
		return
	_frame = f
	_grid.clear()
	var cam := tree.root.get_viewport().get_camera_3d() if tree.root else null
	_cam = cam.global_position if cam else Vector3.INF
	for g: StringName in [&"player", &"townspeople"]:
		for n in tree.get_nodes_in_group(g):
			var b := n as Node3D
			if b == null or not b.is_inside_tree() or not b.is_visible_in_tree():
				continue
			if b is TownspersonBot and (b as TownspersonBot).hidden_inside:
				continue
			if b is Player and (b as Player).vehicle != null:
				continue
			var k := Vector2i(floori(b.global_position.x / CELL), floori(b.global_position.z / CELL))
			if _grid.has(k):
				(_grid[k] as Array).append(b)
			else:
				_grid[k] = [b]


## People (townspeople + the farmer on foot) within `r` m of `p` (approx: grid cells).
static func people_near(tree: SceneTree, p: Vector2, r: float) -> Array:
	_refresh(tree)
	var out: Array = []
	var a := Vector2i(floori((p.x - r) / CELL), floori((p.y - r) / CELL))
	var b := Vector2i(floori((p.x + r) / CELL), floori((p.y + r) / CELL))
	for x in range(a.x, b.x + 1):
		for z in range(a.y, b.y + 1):
			var k := Vector2i(x, z)
			if _grid.has(k):
				out.append_array(_grid[k])
	return out


static func camera_pos(tree: SceneTree) -> Vector3:
	_refresh(tree)
	return _cam


# ------------------------------------------------------------------ AI car gate
## RoadCar.people_gate target: (car, wanted m/s) -> capped m/s.
static func people_gate(car: RoadCar, want: float) -> float:
	var st := style()
	if st == null or not st.enabled or not is_instance_valid(car) or not car.is_inside_tree() or not car._stop_for_people:
		return want
	gate_calls += 1
	_road_cars[car.get_instance_id()] = car
	var tree := car.get_tree()
	_refresh(tree)
	var now := Time.get_ticks_msec()
	var far := _cam != Vector3.INF and _cam.distance_to(car.global_position) > st.near_radius
	if far and now < int(car.get_meta(&"rs_next", 0)):
		return minf(want, float(car.get_meta(&"rs_cap", want)))
	var res := _compute(car, want, st, st.far_interval if far else 0.0)
	var cap: float = res[0]
	car.set_meta(&"rs_cap", cap)
	car.set_meta(&"rs_next", now + int(st.far_interval * 1000.0))
	# Waiting for a person: count, and ask a standing townsperson to step aside.
	var who: Node3D = res[1]
	var dt := car.get_physics_process_delta_time() * (st.far_interval * 60.0 if far else 1.0)
	if who != null and cap < want - 0.01:
		if cap < 0.3 and car.cur_speed < 0.5:
			var w := float(car.get_meta(&"rs_wait", 0.0)) + dt
			car.set_meta(&"rs_wait", w)
			if w >= st.step_aside_s and who is TownspersonBot:
				_ask_step_aside(who as TownspersonBot, car)
				car.set_meta(&"rs_wait", 0.0)
		if not car.has_meta(&"rs_yielding"):
			car.set_meta(&"rs_yielding", true)
			yields += 1
	else:
		car.remove_meta(&"rs_yielding")
		car.set_meta(&"rs_wait", 0.0)
	car.set_meta(&"rs_blocker", who)
	return minf(want, cap)


## [cap m/s, blocking person or null]
static func _compute(car: RoadCar, want: float, st: RoadSafetyStyle, extra_t: float) -> Array:
	var v := maxf(car.cur_speed, minf(want, car.cur_speed + 1.5))
	var nose := car.size.z * 0.5
	var look := nose + st.stop_margin + v * (st.reaction_s + extra_t) + v * v / (2.0 * st.brake_decel) + 1.5
	var p0 := flat(car.global_position)
	var f3 := car.forward()
	var fwd := Vector2(f3.x, f3.z).normalized()
	# Corridor = straight ahead past the bumper + the car's own route (curves).
	var pts := PackedVector2Array([p0])
	var acc := 0.0
	if car.moving and car.path.size() > 0:
		for i in range(car.path_i, car.path.size()):
			var q := flat(car.path[i])
			var seg := q - pts[pts.size() - 1]
			var l := seg.length()
			if l < 0.05:
				continue
			if acc + l >= look:
				pts.append(pts[pts.size() - 1] + seg * ((look - acc) / l))
				acc = look
				break
			pts.append(q)
			acc += l
	var straight := PackedVector2Array([p0, p0 + fwd * minf(look, nose + st.stop_margin + 3.0)])
	var hw := car.size.x * 0.5 + st.lane_margin + PERSON_R
	var body_hw := car.size.x * 0.5 + PERSON_R + 0.05
	var best := INF
	var who: Node3D = null
	for n in people_near(car.get_tree(), p0, look + 2.0):
		var b := n as Node3D
		if b == null or not is_instance_valid(b):
			continue
		var q := flat(b.global_position)
		if q.distance_squared_to(p0) > (look + 2.0) * (look + 2.0):
			continue
		var cands: Array[Vector2] = [q]
		if st.predict_s > 0.0 and b is CharacterBody3D:
			var vel := Vector2((b as CharacterBody3D).velocity.x, (b as CharacterBody3D).velocity.z)
			if vel.length_squared() > 0.09:
				var along0 := (q - p0).dot(fwd)
				var t := clampf(along0 / maxf(v, 2.0), 0.0, st.predict_s)
				cands.append(q + vel * t)
		for c in cands:
			for poly in [straight, pts]:
				var hit := _along(poly as PackedVector2Array, c)
				if hit.is_empty():
					continue
				var along: float = hit[0]
				var lat: float = hit[1]
				if along < nose:
					# Beside the car body: only a real overlap stops it.
					if along < -0.5 or lat > body_hw:
						continue
				elif lat > hw:
					continue
				var free := along - nose - st.stop_margin
				if free < best:
					best = free
					who = b
	if who == null:
		return [want, null]
	if best <= 0.15:
		return [0.0, who]
	# v * react + v^2 / 2a = free  ->  v
	var a := st.brake_decel
	var r := st.reaction_s + extra_t
	var cap := a * (-r + sqrt(r * r + 2.0 * best / a))
	return [cap, who]


## Distance along / from a polyline: [along, lateral] of the closest point, [] if none.
static func _along(poly: PackedVector2Array, q: Vector2) -> Array:
	if poly.size() < 2:
		return []
	var acc := 0.0
	var best := INF
	var out: Array = []
	for i in poly.size() - 1:
		var a := poly[i]
		var d := poly[i + 1] - a
		var l2 := d.length_squared()
		if l2 < 0.0001:
			continue
		var t := clampf((q - a).dot(d) / l2, 0.0, 1.0)
		var proj := a + d * t
		var dist := q.distance_to(proj)
		# Points beyond the start of the first segment are behind the car.
		if i == 0 and t <= 0.0 and (q - a).dot(d) < 0.0:
			var behind := (q - a).dot(d.normalized())
			if dist < best:
				best = dist
				out = [behind, absf((q - a).dot(Vector2(-d.y, d.x).normalized()))]
			acc += sqrt(l2)
			continue
		if dist < best:
			best = dist
			out = [acc + sqrt(l2) * t, dist]
		acc += sqrt(l2)
	return out


static func _ask_step_aside(b: TownspersonBot, car: RoadCar) -> void:
	if b.has_meta(&"rs_down") or b.has_meta(&"rs_step"):
		return
	var f3 := car.forward()
	var right := Vector3(-f3.z, 0.0, f3.x)
	var rel := b.global_position - car.global_position
	# Step to whichever side they are already on; dead centre = the kerb side (right-hand traffic).
	var side := signf(rel.dot(right))
	if absf(rel.dot(right)) < 0.2:
		side = 1.0
	b.set_meta(&"rs_step", {"dir": right * side, "until": Time.get_ticks_msec() + 1800})
	step_asides += 1


# ------------------------------------------------------------------ pedestrians
## Moving cars this physics frame (AI cars that called the gate + driven cars).
static func moving_cars(tree: SceneTree) -> Array:
	var f := Engine.get_physics_frames()
	if f == _mov_frame:
		return _moving
	_mov_frame = f
	_moving = []
	for id in _road_cars.keys():
		var rc := _road_cars[id] as RoadCar if is_instance_valid(_road_cars[id]) else null
		if rc == null or not rc.is_inside_tree():
			_road_cars.erase(id)
			continue
		if rc.cur_speed > 0.8 and rc.is_visible_in_tree():
			_moving.append(_entry(rc, rc.cur_speed, rc.forward(), rc.size))
	for n in tree.get_nodes_in_group(&"drivable_cars"):
		var dc := n as DrivableCar
		if dc and dc.driver != null and absf(dc.speed) > 0.8:
			var fw := dc.forward() * signf(dc.speed)
			_moving.append(_entry(dc, absf(dc.speed), fw, dc.size))
	return _moving


static func _entry(car: Node3D, spd: float, f3: Vector3, size: Vector3) -> Dictionary:
	return {"car": car, "pos": flat(car.global_position), "fwd": Vector2(f3.x, f3.z).normalized(), "speed": spd,
		"hw": size.x * 0.5, "hl": size.z * 0.5}


## TownspersonBot.move_filter target: (bot, wanted move) -> move.
static func pedestrian_filter(bot: TownspersonBot, move: Vector3) -> Vector3:
	if bot.has_meta(&"rs_step"):
		var s: Dictionary = bot.get_meta(&"rs_step")
		if Time.get_ticks_msec() < int(s["until"]):
			return (s["dir"] as Vector3) * 1.4
		bot.remove_meta(&"rs_step")
	if move.length_squared() < 0.0025:
		return move
	var st := style()
	if st == null or not st.enabled or not st.pedestrian_wait or bot.is_far_from_player():
		return move
	var q := flat(bot.global_position)
	var step := Vector2(move.x, move.z).normalized()
	var nxt := q + step * 1.0
	for e: Dictionary in moving_cars(bot.get_tree()):
		var cp: Vector2 = e["pos"]
		if cp.distance_squared_to(q) > st.pedestrian_look * st.pedestrian_look:
			continue
		var fwd: Vector2 = e["fwd"]
		var perp := Vector2(-fwd.y, fwd.x)
		var reach := float(e["hl"]) + 1.0 + float(e["speed"]) * 1.6
		var rel1 := nxt - cp
		var a1 := rel1.dot(fwd)
		if a1 < -float(e["hl"]) or a1 > reach:
			continue
		var lane := float(e["hw"]) + 0.8
		var l1 := absf(rel1.dot(perp))
		var l0 := absf((q - cp).dot(perp))
		# Stepping into (or deeper into) the strip the car is about to drive through.
		if l1 < lane and l1 <= l0 + 0.02:
			kerb_waits += 1
			return Vector3.ZERO
	return move
