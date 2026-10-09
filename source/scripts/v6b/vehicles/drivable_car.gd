class_name DrivableCar
extends CharacterBody3D
## v6b "vehicles" module: a parked car you can get into (E at the driver's
## door) and drive on the existing roads - W/S throttle/brake/reverse,
## A/D steer, Space handbrake, R horn, E get out. Simple arcade handling:
## bicycle-model steering, grip, drag, terrain-following. Where you leave it
## is remembered (WorldMemory "cars"). Headlights after dark.

var key: String = ""
var model_name: String = "sedan"
var speed: float = 0.0
signal pedestrian_hit(person: Node3D, impact_speed: float)
var yaw: float = 0.0
var steer: float = 0.0
var driver: Player = null
var size: Vector3 = Vector3(1.9, 1.6, 4.2)
var model_root: Node3D
var door_spot: ActionSpot
var distance_driven: float = 0.0
var horn_count: int = 0
var _lights: Array[SpotLight3D] = []
var _exit_lock: float = 0.0
var _horn: AudioStreamPlayer3D
## Test hook: when set, used instead of the keyboard ({throttle, steer, brake}).
var auto_input: Dictionary = {}
## v7b.1: steering-wheel position for the cockpit / wheel mesh (-1..1, + = turning left).
var steer_amount: float = 0.0


func style() -> VehicleStyle:
	return Modules.style("vehicles") as VehicleStyle


func _ready() -> void:
	add_to_group(&"drivable_cars")
	collision_layer = 1
	collision_mask = 1 | 16
	motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
	var m := VehicleKit.model(model_name)
	if not m.is_empty():
		model_root = m[0]
		size = m[1]
		add_child(model_root)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	# Raised off the ground so small bumps / kerbs don't stop the car.
	bs.size = Vector3(size.x * 0.95, maxf(size.y - 0.45, 0.6), size.z * 0.97)
	cs.shape = bs
	cs.position = Vector3(0, 0.45 + bs.size.y * 0.5, 0)
	add_child(cs)
	for sx: float in [-0.55, 0.55]:
		var l := SpotLight3D.new()
		l.light_color = Color(1.0, 0.95, 0.8)
		l.spot_range = 18.0
		l.spot_angle = 32.0
		l.light_energy = 2.2
		l.shadow_enabled = false
		l.position = Vector3(sx * size.x * 0.5, 0.75, size.z * 0.5)
		l.rotation = Vector3(deg_to_rad(-8.0), PI, 0)  # spot shines along -Z: flip to +Z
		l.visible = false
		add_child(l)
		_lights.append(l)
	_horn = AudioStreamPlayer3D.new()
	_horn.stream = _horn_stream()
	_horn.unit_size = 8.0
	add_child(_horn)
	door_spot = ActionSpot.make(self, Vector3(-size.x * 0.5 - 0.6, 0, size.z * 0.12), 1.0, _door_text, get_in,
		func() -> bool: return driver == null)
	door_spot.name = "DriverDoor"
	rotation = Vector3(0, yaw, 0)


func _door_text() -> String:
	var vs := style()
	var nm := Lang.tt(_fa_model(), model_name)
	return Lang.tt("سوار %s شو و رانندگی کن" % nm, "get in the %s and drive" % nm) if vs else ""


func _fa_model() -> String:
	return {"sedan": "سواری", "van": "ون", "delivery": "کامیونت", "tractor": "تراکتور", "taxi": "تاکسی", "suv": "شاسی‌بلند"}.get(model_name, "ماشین")


static var _horn_cache: AudioStreamWAV
static var _hint_shown: bool = false


static func _horn_stream() -> AudioStreamWAV:
	if _horn_cache:
		return _horn_cache
	var rate := 22050
	var n := int(rate * 0.45)
	var data := PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var t := float(i) / rate
		var env := minf(t / 0.02, 1.0) * minf((0.45 - t) / 0.05, 1.0)
		var v := (sin(TAU * 392.0 * t) + 0.6 * sin(TAU * 494.0 * t)) * 0.33 * env
		v = clampf(v * 1.6, -1.0, 1.0)
		data.encode_s16(i * 2, int(v * 30000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.data = data
	_horn_cache = w
	return w


func forward() -> Vector3:
	return Vector3(sin(yaw), 0.0, cos(yaw))


func get_in(who: Node3D) -> void:
	var p := who as Player
	if p == null or driver != null:
		return
	driver = p
	p.vehicle = self
	p.set_meta(&"v6b_layers", [p.collision_layer, p.collision_mask])
	p.collision_layer = 0
	p.collision_mask = 0
	var vis := p.get_node_or_null(^"Visual") as Node3D
	if vis:
		vis.visible = false
	_exit_lock = 0.5
	speed = 0.0
	GameEvents.interaction_prompt_changed.emit(Lang.tt("W/S گاز و ترمز · ماوس یا A/D فرمان · فاصله ترمزدستی · V دوربین داخل · R بوق · E پیاده شو",
		"W/S drive · mouse or A/D steer · Space handbrake · V cockpit view · R horn · E get out"))
	var cam := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	if cam:
		cam.set_zoom(maxf(cam.zoom(), 7.5))
	Sfx.play_at(&"door", global_position, -8.0, 1.3)
	if not _hint_shown:
		_hint_shown = true
		GameEvents.notification_requested.emit(Lang.tt("رانندگی فقط در خیابان‌ها - پارک کن و با E پیاده شو.", "Drive on the roads - park and press E to get out."))


func get_out() -> void:
	if driver == null:
		return
	var p := driver
	driver = null
	speed = 0.0
	p.vehicle = null
	var layers: Array = p.get_meta(&"v6b_layers", [2, 5])
	p.collision_layer = int(layers[0])
	p.collision_mask = int(layers[1])
	var vis := p.get_node_or_null(^"Visual") as Node3D
	if vis:
		vis.visible = true
		vis.rotation.y = yaw
	# Step out on the driver's side (left), or the right if that is blocked.
	var left := -Vector3(-forward().z, 0, forward().x)
	var spot := global_position + left * (size.x * 0.5 + 0.9)
	p.global_position = Vector3(spot.x, Terrain.height_at(spot.x, spot.z) + 0.1, spot.z)
	p.velocity = Vector3.ZERO
	GameEvents.interaction_prompt_changed.emit("")
	WorldMemory.park(key, global_position, yaw)
	Sfx.play_at(&"door", global_position, -8.0, 1.1)
	for l in _lights:
		l.visible = false


func honk() -> void:
	horn_count += 1
	if _horn and is_inside_tree():
		_horn.play()
	# Townspeople nearby glance at the car.
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var b := n as TownspersonBot
		if b and b.global_position.distance_to(global_position) < 12.0 and b.controller is ScheduleController:
			(b.controller as ScheduleController).glance(b, self, 1.5)


func _input_state() -> Dictionary:
	if not auto_input.is_empty():
		return auto_input
	if GameEvents.ui_open:
		return {"throttle": 0.0, "steer": 0.0, "brake": false}
	# v7b.1: keyboard, mouse wheel (mouse X) and touch sticks via ControlInput.
	return {"throttle": ControlInput.throttle(), "steer": ControlInput.steer(), "brake": ControlInput.brake()}


func _physics_process(delta: float) -> void:
	if driver == null:
		return
	var vs := style()
	var max_v := (vs.max_speed if vs else 11.0) * float(get_meta(&"top_mult", 1.0))  # v7b.1: per-car top speed (dealership / bus)
	if driver.appearance.get("job", "") == "driver":
		max_v *= 1.15  # job perk: the town driver gets a little more out of a car
	var rev_v := vs.reverse_speed if vs else 4.0
	var accel := vs.accel if vs else 5.5
	var brake := vs.brake if vs else 10.0
	var steer_max := deg_to_rad(vs.steer_deg if vs else 34.0)
	# v7b "driving" module: gears, upgrades, wear, fuel (CarSystems child).
	var sys := get_node_or_null(^"CarSystems") as CarSystems
	if sys:
		var base_v := max_v
		max_v *= sys.top_mult(base_v)
		accel *= sys.accel_mult(base_v)
	_exit_lock = maxf(_exit_lock - delta, 0.0)
	if auto_input.is_empty() and not GameEvents.ui_open and _exit_lock <= 0.0:
		if Input.is_action_just_pressed(&"interact"):
			get_out()
			return
		if Input.is_action_just_pressed(&"horn"):
			honk()
		if sys:
			sys.handle_input()
	var inp := _input_state()
	var th: float = float(inp.get("throttle", 0.0))
	if bool(inp.get("brake", false)):
		speed = move_toward(speed, 0.0, brake * 1.4 * delta)
	elif th > 0.05:
		speed = speed + accel * th * delta if speed >= 0.0 else move_toward(speed, 0.0, brake * delta)
	elif th < -0.05:
		speed = speed + accel * th * delta if speed <= 0.0 else move_toward(speed, 0.0, brake * delta)
	else:
		speed = move_toward(speed, 0.0, 2.2 * delta)  # rolling drag
	# Off the road the car is slow (grass / sand).
	var lim := max_v if VehicleKit.on_road(global_position.x, global_position.z, 1.5) or model_name == "tractor" else max_v * 0.45
	if sys and not sys.is_auto() and speed > lim:
		speed = maxf(lim, speed - brake * 0.6 * delta)  # engine braking after a downshift
		lim = speed
	speed = clampf(speed, -rev_v, lim if speed >= 0.0 else rev_v)
	steer = move_toward(steer, float(inp.get("steer", 0.0)) * steer_max, 3.0 * delta)
	steer_amount = clampf(steer / maxf(steer_max, 0.01), -1.0, 1.0)
	# Bicycle model: yaw rate = v / wheelbase * tan(steer), less at speed.
	var wheelbase := size.z * 0.62
	var grip := 1.0 / (1.0 + absf(speed) * 0.04)
	yaw = wrapf(yaw + speed / wheelbase * tan(steer) * grip * delta, -PI, PI)
	rotation = Vector3(0, yaw, 0)
	velocity = forward() * speed
	var before := global_position
	move_and_slide()
	# Report physical contact before collision braking reduces the speed.
	# A proximity-only detector can otherwise see a severe hit as a stumble.
	var impact_speed := absf(speed)
	for i in get_slide_collision_count():
		var person := get_slide_collision(i).get_collider() as Node3D
		if person is TownspersonBot or (person is Player and person != driver):
			pedestrian_hit.emit(person, impact_speed)
	if get_slide_collision_count() > 0 and impact_speed > 3.0:
		if sys:
			sys.on_crash(impact_speed)
		speed *= 0.4
	var p := global_position
	p.y = Terrain.height_at(p.x, p.z)
	global_position = p
	var step := Vector2(p.x - before.x, p.z - before.z).length()
	distance_driven += step
	if sys:
		sys.on_moved(step)
		sys.check_night(delta)
	# Carry the farmer along (hidden), camera swings behind the car.
	driver.global_position = global_position + Vector3(0, 0.4, 0)
	var vis := driver.get_node_or_null(^"Visual") as Node3D
	if vis:
		vis.rotation.y = yaw
	var cam := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	# v7b.1 bug fix: swing behind only when the player is not looking around.
	if cam and absf(speed) > 0.5 and not Input.is_action_pressed(&"camera_orbit") and ControlInput.since_look() > 1.2:
		var behind := atan2(-forward().x, -forward().z) if speed > 0.0 else atan2(forward().x, forward().z)
		cam.yaw = lerp_angle(cam.yaw, behind, 1.0 - exp(-2.2 * delta))
		cam.rotation = Vector3(0, cam.yaw, 0)
	if sys:
		sys.apply_lights(_lights)  # v7b: H switches the headlights
	else:
		var night := TimeManager.hour() >= 19 or TimeManager.hour() < 6
		for l in _lights:
			l.visible = night


## Snap the camera behind the car (after getting in / for screenshots).
func frame_camera() -> void:
	var cam := get_tree().get_first_node_in_group(&"camera_rig") as FollowCamera
	if cam:
		cam.snap_view(rad_to_deg(atan2(-forward().x, -forward().z)), -16.0, 8.0)
