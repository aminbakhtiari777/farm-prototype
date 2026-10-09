class_name NpcTraffic
extends Node3D
## v7b.1 npc_traffic module: a few townsfolk cars drive loops on the road graph
## in the right-hand lane. They obey red lights, STOP signs and the speed limits
## and keep a gap (TrafficRules.ai_gate via the RoadCar.traffic_gate hook), and
## park at their first waypoint outside `active_hours`.

var cars: Array[TrafficCar] = []
var active: bool = true


class TrafficCar extends RoadCar:
	var loop: PackedVector3Array = PackedVector3Array()
	var loop_name: String = ""
	var laps: int = 0

	func _ready() -> void:
		add_to_group(&"road_cars")
		add_to_group(&"npc_traffic_cars")
		arrived.connect(_on_lap)

	func start_loop() -> void:
		if loop.size() < 2:
			return
		follow(loop)

	func _on_lap() -> void:
		laps += 1
		start_loop.call_deferred()


func style() -> NpcTrafficStyle:
	return Modules.style("npc_traffic") as NpcTrafficStyle


func _ready() -> void:
	rebuild.call_deferred()
	Modules.on_swap("npc_traffic", self, func(_m: Resource) -> void: rebuild())


## Lane path for a list of V2 waypoints, closed into a loop.
static func loop_path(points: Array) -> PackedVector3Array:
	var centre := PackedVector3Array()
	for i in points.size():
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % points.size()]
		var seg := VehicleKit.route(Vector3(a.x, 0, a.y), Vector3(b.x, 0, b.y))
		for k in seg.size():
			if not centre.is_empty() and centre[centre.size() - 1].distance_to(seg[k]) < 0.5:
				continue
			centre.append(seg[k])
	# Drop immediate back-and-forth spikes (u-turn artefacts of the graph's
	# short junction links, < 5.5 m). Real u-turns at a dead end (Harbor Rd,
	# north Oak Ave) retrace ~6 m road steps and are kept, so a loop that
	# drives up a road and back no longer collapses to nothing.
	var clean := PackedVector3Array()
	for p in centre:
		if clean.size() >= 2 and clean[clean.size() - 2].distance_to(p) < 0.5 \
				and clean[clean.size() - 1].distance_to(p) < 5.8:
			clean.remove_at(clean.size() - 1)
			continue
		clean.append(p)
	return VehicleKit.lane(clean)


func rebuild() -> void:
	for c in cars:
		if is_instance_valid(c):
			c.queue_free()
	cars.clear()
	var st := style()
	if st == null:
		return
	var k := 0
	for spec: Dictionary in st.cars:
		var car := TrafficCar.new()
		car.name = "TrafficCar%d" % k
		car.model_name = str(spec.get("model", "sedan"))
		car.speed = 9.0
		car.loop = loop_path(spec.get("loop", []))
		car.loop_name = "loop%d" % k
		add_child(car)
		car.build_model()
		cars.append(car)
		if car.loop.size() > 1:
			var p0 := car.loop[0]
			var p1 := car.loop[1]
			car.place(p0, atan2(p1.x - p0.x, p1.z - p0.z))
		k += 1
	_apply_hours()


func _apply_hours() -> void:
	var st := style()
	if st == null:
		return
	var h := TimeManager.hours_float()
	if not active:
		return
	var on := h >= st.active_hours.x and h < st.active_hours.y
	for c in cars:
		if not is_instance_valid(c):
			continue
		if on and not c.moving:
			c.start_loop()
		elif not on and c.moving:
			c.stop()
		# Off-hours the cars are "parked at home" (hidden, no collision).
		c.visible = on
		c.collision_layer = 1 if on else 0


var _t: float = 0.0


func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0:
		return
	_t = 2.0
	_apply_hours()


func set_active(on: bool) -> void:
	active = on
	for c in cars:
		if is_instance_valid(c):
			if on:
				c.start_loop()
			else:
				c.stop()
			c.visible = on
			c.collision_layer = 1 if on else 0
