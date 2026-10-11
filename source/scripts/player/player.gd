class_name Player
extends CharacterBody3D
## Third-person farmer: camera-relative walk/sprint (stamina), jump with coyote
## time + buffering, sit on seats / the ground, pick up & place carryables with
## a placement ghost, fish from the shore / pier / pond, push-to-talk (VoiceClient),
## and interact with the nearest Interactable (E). Visuals live on the "Visual"
## child (HumanoidModelVisual).

@export_group("Movement")
@export var walk_speed: float = 2.6
@export var sprint_speed: float = 5.4
@export var acceleration: float = 16.0
@export var deceleration: float = 20.0
@export var turn_speed: float = 14.0
@export var jump_velocity: float = 5.2
@export var coyote_time: float = 0.12
@export var jump_buffer: float = 0.12

@export_group("Audio")
@export var footstep_sounds: Array[AudioStream] = []
@export var stride_length: float = 0.75

@export_group("Interaction")
@export var interaction_lock_time: float = 0.55
@export var place_reach: float = 2.2

@onready var _visual: Node3D = get_node_or_null(^"Visual")
@onready var _footstep_player: AudioStreamPlayer3D = get_node_or_null(^"Footsteps")
@onready var _breathing: AudioStreamPlayer3D = get_node_or_null(^"Breathing")

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _nearby: Array[Interactable] = []
var _current_target: Interactable = null
var _lock_timer: float = 0.0
var _interact_key_name: String = "E"
var _stride_distance: float = 0.0
var footsteps_played: int = 0

# Stamina / fatigue
var stamina: float = 100.0
var stamina_max: float = 100.0
var exhausted: bool = false
## Seconds left of the forced "catch your breath" stop after hitting 0 stamina.
var rest_timer: float = 0.0
## Below this fraction of max stamina the farmer gets slower (walk + actions).
const TIRED_FRACTION := 0.3
var _cfg: Dictionary = {}

# Jump
var _coyote: float = 0.0
var _jump_buf: float = 0.0
var _was_on_floor: bool = true
## Number of jumps performed (smoke test).
var jumps: int = 0
var _air_time: float = 0.0
## Highest point above the take-off height in the last jump (smoke test).
var max_jump_height: float = 0.0

# Sit / carry / fish
var sitting_on: Seat = null
var sitting_ground: bool = false
var carried: Carryable = null
var _ghost: MeshInstance3D
var _ghost_mat: StandardMaterial3D
var fishing: FishingMinigame
var inside_building: Building = null
var tools: ToolAnimator


func _ready() -> void:
	add_to_group(&"player")
	_cfg = GameData.data.get("stamina", {})
	stamina_max = float(_cfg.get("max", 100))
	stamina = stamina_max
	GameEvents.ui_closed.connect(func() -> void: _lock_timer = maxf(_lock_timer, 0.25))
	GameEvents.building_entered.connect(func(b: Node3D) -> void: inside_building = b as Building)
	GameEvents.building_exited.connect(func(_b: Node3D) -> void: inside_building = null)
	_interact_key_name = _find_action_key_name(&"interact")
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.albedo_color = Color(0.4, 0.85, 1.0, 0.35)
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost = MeshInstance3D.new()
	_ghost.name = "PlaceGhost"
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.visible = false
	add_child(_ghost)
	fishing = FishingMinigame.new()
	fishing.name = "Fishing"
	add_child(fishing)
	tools = ToolAnimator.new()
	tools.name = "ToolAnimator"
	add_child(tools)
	if _breathing and _breathing.stream is AudioStreamOggVorbis:
		(_breathing.stream as AudioStreamOggVorbis).loop = true
	_emit_stamina()
	# A new day (after sleeping) means a rested farmer.
	TimeManager.day_started.connect(func(_d: int) -> void:
		exhausted = false
		rest_timer = 0.0
		restore_stamina(stamina_max))


func _physics_process(delta: float) -> void:
	_lock_timer = maxf(_lock_timer - delta, 0.0)
	# v6b: while driving, the car moves the farmer (Car.drive_input).
	if vehicle != null:
		velocity = Vector3.ZERO
		return
	var was_on_floor := is_on_floor()
	_coyote = coyote_time if was_on_floor else maxf(_coyote - delta, 0.0)
	_jump_buf = maxf(_jump_buf - delta, 0.0)
	if Input.is_action_just_pressed(&"jump") and not GameEvents.ui_open and not _is_sitting() and carried == null and not fishing.active:
		_jump_buf = jump_buffer

	# Sit / stand
	if Input.is_action_just_pressed(&"sit") and not GameEvents.ui_open and not fishing.active and carried == null:
		if _is_sitting():
			stand_up()
		elif is_on_floor() and _lock_timer <= 0.0:
			sit_ground()

	# Carry pick/place (F or E with priority on carryables)
	if Input.is_action_just_pressed(&"pick_up") and not GameEvents.ui_open:
		if carried:
			_try_place()
		else:
			_try_pick_nearest()

	# Voice PTT
	if Input.is_action_just_pressed(&"push_to_talk"):
		VoiceClient.set_talking(true)
	elif Input.is_action_just_released(&"push_to_talk"):
		VoiceClient.set_talking(false)

	# Fishing takes over movement when active
	if fishing.active:
		_update_fishing(delta)
		return

	# Sitting: recover stamina, ignore movement
	if _is_sitting():
		_recover(delta, float(_cfg.get("sit_recover", 24)))
		velocity = Vector3.ZERO
		if ControlInput.move_vector().length() > 0.2:
			stand_up()
		move_and_slide()
		_drive_visual(0.0)
		return

	# --- Movement ---
	# v7b.1: keyboard + touch stick through the shared input layer (ControlInput).
	var input := ControlInput.move_vector()
	if rest_timer > 0.0:
		# Forced rest: hands on knees, catching breath, no movement.
		rest_timer = maxf(rest_timer - delta, 0.0)
		input = Vector2.ZERO
		if rest_timer <= 0.0 and _visual is HumanoidModelVisual:
			(_visual as HumanoidModelVisual).set_pose(&"")
	if _lock_timer > 0.0 or GameEvents.ui_open:
		input = Vector2.ZERO
	var direction := _camera_relative(input)
	# v7b: a tipsy farmer drifts a little (cafe module, Tipsy).
	if drift_angle != 0.0 and direction != Vector3.ZERO:
		direction = direction.rotated(Vector3.UP, drift_angle)
	var want_sprint := Input.is_action_pressed(&"sprint") and not exhausted and carried == null and stamina > 0.0
	var target_speed := sprint_speed if want_sprint and direction != Vector3.ZERO else walk_speed
	if exhausted:
		target_speed = walk_speed * 0.55
	else:
		target_speed *= tired_factor()
	if carried:
		target_speed *= 0.7
	# v5b: illness (cold / flu) and starving slow you down (Needs).
	target_speed *= Needs.player_speed_factor()

	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	if direction != Vector3.ZERO:
		horizontal = horizontal.move_toward(direction * target_speed * input.length(), acceleration * delta)
		_face_direction(direction, delta)
	else:
		horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
		# v7b.1: standing still, turning the camera (mouse / right stick) turns the farmer too.
		if ControlInput.looking() and _lock_timer <= 0.0 and not GameEvents.ui_open and rest_timer <= 0.0:
			_face_direction(_camera_relative(Vector2(0.0, -1.0)), delta)

	# Jump
	var jumped := false
	if _jump_buf > 0.0 and _coyote > 0.0 and not exhausted and stamina >= float(_cfg.get("jump_cost", 9)):
		velocity.y = jump_velocity
		_coyote = 0.0
		_jump_buf = 0.0
		# v7b.1: a jump that empties the stamina never forces the hands-on-knees rest.
		spend_stamina(float(_cfg.get("jump_cost", 9)), false)
		jumped = true
		jumps += 1
		if _visual is HumanoidModelVisual:
			(_visual as HumanoidModelVisual).set_airborne(true)

	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not jumped and was_on_floor:
		velocity.y = -0.5
	else:
		_air_time += delta
		velocity.y -= _gravity * delta
	move_and_slide()
	var on_floor_now := is_on_floor()
	# Floor state is only authoritative after move_and_slide(). Reading it before
	# movement let _was_on_floor become true on the landing frame before the
	# landing pose was cleared, leaving the legs suspended in the jump pose.
	if on_floor_now:
		if not was_on_floor and _air_time > 0.3:
			Sfx.play_at(&"land", global_position, -12.0)
		if _visual is HumanoidModelVisual:
			(_visual as HumanoidModelVisual).set_airborne(false)
		_air_time = 0.0
		velocity.y = -0.5
	elif was_on_floor and not jumped and _visual is HumanoidModelVisual and velocity.y < -2.0:
		(_visual as HumanoidModelVisual).set_airborne(true)
	_was_on_floor = on_floor_now

	# Stamina drain / recover
	var speed := horizontal.length()
	if want_sprint and speed > walk_speed * 0.6:
		spend_stamina(float(_cfg.get("sprint_drain", 16)) * delta)
	elif speed < 0.2:
		_recover(delta, float(_cfg.get("idle_recover", 8)))
	else:
		# Walking recovers slowly (even slower while exhausted).
		_recover(delta, float(_cfg.get("walk_recover", 5)) * (0.6 if exhausted else 1.0))

	_drive_visual(speed)
	_update_footsteps(speed * delta)
	_update_breathing()
	_update_ghost()
	_update_interaction_target()
	if Input.is_action_just_pressed(&"interact") and _lock_timer <= 0.0 and not GameEvents.ui_open:
		_handle_interact()


func _drive_visual(speed: float) -> void:
	if _visual is HumanoidModelVisual:
		var hv := _visual as HumanoidModelVisual
		hv.set_ground_speed(speed)
		hv.set_carrying(carried != null)
	elif _visual is CharacterVisual:
		(_visual as CharacterVisual).set_locomotion(speed / walk_speed)


func _update_breathing() -> void:
	if _breathing == null:
		return
	if exhausted and not _breathing.playing:
		_breathing.play()
	elif not exhausted and _breathing.playing:
		_breathing.stop()


# ------------------------------------------------------------------ stamina
func spend_stamina(amount: float, rest_if_empty: bool = true) -> void:
	stamina = maxf(stamina - amount, 0.0)
	if stamina <= 0.0 and not exhausted:
		exhausted = true
		if not rest_if_empty:
			_emit_stamina()
			return
		rest_timer = float(_cfg.get("forced_rest", 1.8))
		if _visual is HumanoidModelVisual and not _is_sitting() and is_on_floor():
			(_visual as HumanoidModelVisual).set_pose(&"kneel")
		GameEvents.notification_requested.emit(Lang.tt("خسته شدی! نفسی تازه کن - بنشین (X) تا زودتر جان بگیری", "You're exhausted! Catch your breath - sit (X) to recover faster"))
	_emit_stamina()


## 1.0 when rested, down to 0.75 when nearly empty (walk speed + action time).
func tired_factor() -> float:
	var f := stamina / maxf(stamina_max, 1.0)
	if f >= TIRED_FRACTION:
		return 1.0
	return lerpf(0.75, 1.0, f / TIRED_FRACTION)


func restore_stamina(amount: float) -> void:
	stamina = minf(stamina + amount, stamina_max)
	if stamina >= float(_cfg.get("exhausted_until", 30)):
		exhausted = false
	_emit_stamina()


func _recover(delta: float, rate: float) -> void:
	if stamina >= stamina_max:
		return
	restore_stamina(rate * delta * Needs.player_regen_factor())


func _emit_stamina() -> void:
	GameEvents.stamina_changed.emit(stamina, stamina_max, exhausted)


# ------------------------------------------------------------------ sit
func _is_sitting() -> bool:
	return sitting_on != null or sitting_ground


func sit_on(seat: Seat) -> void:
	if carried or fishing.active or not seat.is_free():
		return
	seat.claim(self)
	sitting_on = seat
	sitting_ground = false
	global_position = seat.global_position
	if _visual:
		_visual.rotation.y = seat.facing_yaw()
	if _visual is HumanoidModelVisual:
		(_visual as HumanoidModelVisual).set_pose(StringName(seat.get_meta(&"pose", &"sit")))
	velocity = Vector3.ZERO
	if seat.has_signal(&"used"):
		seat.emit_signal(&"used", self)


func sit_ground() -> void:
	if carried or fishing.active or not is_on_floor():
		return
	sitting_ground = true
	sitting_on = null
	if _visual is HumanoidModelVisual:
		(_visual as HumanoidModelVisual).set_pose(&"ground_sit")
	velocity = Vector3.ZERO


func stand_up() -> void:
	if sitting_on:
		sitting_on.release(self)
		sitting_on = null
	sitting_ground = false
	if _visual is HumanoidModelVisual:
		(_visual as HumanoidModelVisual).set_pose(&"")


# ------------------------------------------------------------------ carry
func pick_up(item: Carryable) -> void:
	if carried or fishing.active or _is_sitting() or item == null:
		return
	carried = item
	item.on_picked_up(self)
	var hold: Node3D = (_visual as HumanoidModelVisual).hold_point if _visual is HumanoidModelVisual else self
	if not is_instance_valid(hold):
		hold = self
	if item.get_parent():
		item.get_parent().remove_child(item)
	hold.add_child(item)
	item.position = Vector3(0, 0, 0)
	item.rotation = Vector3.ZERO
	if _visual is HumanoidModelVisual:
		(_visual as HumanoidModelVisual).play_action(&"pickup")
		(_visual as HumanoidModelVisual).set_carrying(true)
	_lock_timer = 0.4
	_setup_ghost(item.size())


func _try_pick_nearest() -> void:
	var best: Carryable = null
	var best_d := INF
	for c in get_tree().get_nodes_in_group(&"carryables"):
		var item := c as Carryable
		if item == null or item.carried_by != null:
			continue
		var d := global_position.distance_to(item.global_position)
		if d < 2.2 and d < best_d:
			best = item
			best_d = d
	if best:
		pick_up(best)


func _try_place() -> void:
	if carried == null:
		return
	var dest := _place_point()
	var hold := carried.get_parent()
	if hold:
		hold.remove_child(carried)
	get_tree().current_scene.add_child(carried)
	carried.global_position = dest
	carried.rotation.y = (_visual.rotation.y if _visual else 0.0)
	carried.on_placed()
	carried = null
	_ghost.visible = false
	if _visual is HumanoidModelVisual:
		(_visual as HumanoidModelVisual).set_carrying(false)
	_lock_timer = 0.25


func _place_point() -> Vector3:
	var yaw := _visual.rotation.y if _visual else 0.0
	var fwd := Vector3(sin(yaw), 0, cos(yaw))
	var p := global_position + fwd * place_reach
	p.y = Terrain.height_at(p.x, p.z)
	# Floors (houses, pier) are above the terrain: ray down from chest height.
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, global_position.y + 1.2, p.z), Vector3(p.x, global_position.y - 3.0, p.z), 1)
	var ex: Array[RID] = [get_rid()]
	if carried:
		ex.append(carried.get_rid())
	q.exclude = ex
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		p.y = (hit["position"] as Vector3).y
	return p


func _setup_ghost(size: Vector3) -> void:
	var box := BoxMesh.new()
	box.size = size
	_ghost.mesh = box
	_ghost.material_override = _ghost_mat


func _update_ghost() -> void:
	if carried == null:
		_ghost.visible = false
		return
	_ghost.visible = true
	var p := _place_point()
	_ghost.global_position = p + Vector3(0, carried.size().y * 0.5, 0)
	_ghost.rotation.y = _visual.rotation.y if _visual else 0.0


# ------------------------------------------------------------------ interact / fish
func _handle_interact() -> void:
	# Carrying: E also places (same as F).
	if carried:
		_try_place()
		return
	# At the pond / sea: fill the watering can first (if not full), else fish.
	if _can_refill_here() and (_current_target == null or fishing.priority_over(_current_target)):
		Economy.refill_can()
		Sfx.play_at(&"splash", global_position + facing_direction() * 2.0, -8.0)
		GameEvents.notification_requested.emit(Lang.tt("آبپاش پر شد (%s/%s)" % [Lang.digits(str(Economy.water)), Lang.digits(str(Economy.can_capacity()))], "Watering can filled (%d/%d)" % [Economy.water, Economy.can_capacity()]))
		_lock_timer = 0.5
		return
	# Prefer fishing when looking at water with a rod and no closer interactable.
	if fishing.can_start(self) and (_current_target == null or fishing.priority_over(_current_target)):
		fishing.start(self)
		return
	if _current_target:
		_interact_with(_current_target)


func _can_refill_here() -> bool:
	return Economy.water < Economy.can_capacity() and not fishing.active and carried == null and not fishing.probe_water(self).is_empty()


func _update_fishing(delta: float) -> void:
	velocity = Vector3.ZERO
	move_and_slide()
	_drive_visual(0.0)
	_recover(delta, float(_cfg.get("idle_recover", 8)))
	fishing.tick(self, delta)


# ------------------------------------------------------------------ interaction targeting
## Shows + animates the best owned tool of a kind ("hoe", "watering_can",
## "seeds", "hands", "hammer") with its sound (tool_types modules).
func play_tool(kind: String) -> void:
	if tools and carried == null and not fishing.active:
		tools.play(kind)


func register_interactable(target: Interactable) -> void:
	if target not in _nearby:
		_nearby.append(target)
		if not target.prompt_dirty.is_connected(_refresh_prompt):
			target.prompt_dirty.connect(_refresh_prompt)


func unregister_interactable(target: Interactable) -> void:
	_nearby.erase(target)
	if target.prompt_dirty.is_connected(_refresh_prompt):
		target.prompt_dirty.disconnect(_refresh_prompt)


func facing_direction() -> Vector3:
	var yaw := _visual.rotation.y if _visual else 0.0
	return Vector3(sin(yaw), 0.0, cos(yaw))


func get_current_target() -> Interactable:
	return _current_target


func _interact_with(target: Interactable) -> void:
	# Tired farmers work slower.
	_lock_timer = interaction_lock_time / (0.55 if exhausted else tired_factor())
	velocity.x = 0.0
	velocity.z = 0.0
	var to_target := target.focus_position() - global_position
	to_target.y = 0.0
	if to_target.length() > 0.01 and _visual:
		_visual.rotation.y = atan2(to_target.x, to_target.z)
	if _visual is CharacterVisual:
		(_visual as CharacterVisual).play_action(&"interact")
		(_visual as CharacterVisual).set_look_target(target.focus_position() + Vector3.UP * 0.3)
	target.interact(self)


func _update_interaction_target() -> void:
	var best: Interactable = null
	var best_score := -INF
	var facing := facing_direction()
	for target in _nearby:
		if not is_instance_valid(target) or not target.can_interact():
			continue
		var item := target.get_parent() as InteriorItem
		if item and item.building and not item.building.player_inside:
			continue
		# Skip seats while already sitting / carrying; skip carryables when fishing.
		if target.get_parent() is Seat and (_is_sitting() or carried):
			continue
		if target.has_meta(&"carryable") and (carried or fishing.active):
			continue
		var to := target.focus_position() - global_position
		var d := to.length()
		var look := facing.dot(Vector3(to.x, 0, to.z).normalized()) if d > 0.01 else 1.0
		var score := look * 2.0 - d
		if target.get_parent() is BuildingDoor and look > 0.3:
			score += 1.2
		# Prefer carryables slightly when looking at them so E picks them up first.
		if target.has_meta(&"carryable"):
			score += 0.4
		if score > best_score:
			best_score = score
			best = target
	# Contextual water prompts (refill / fish) when no better target.
	if (best == null or best_score < 0.5) and (_can_refill_here() or fishing.can_start(self)):
		var what := "fill the watering can" if _can_refill_here() else "fish"
		GameEvents.interaction_prompt_changed.emit(Lang.prompt(_interact_key_name, Lang.loc(what)))
		_current_target = null
		return
	if best != _current_target:
		_current_target = best
		_refresh_prompt()
	elif best == null:
		_refresh_prompt()
	if _visual is CharacterVisual:
		var look_p := Vector3.INF if best == null else best.focus_position() + Vector3.UP * 0.3
		(_visual as CharacterVisual).set_look_target(look_p)


func _refresh_prompt() -> void:
	if _current_target != null and is_instance_valid(_current_target) and _current_target.can_interact():
		GameEvents.interaction_prompt_changed.emit(_current_target.get_prompt(_interact_key_name))
	else:
		GameEvents.interaction_prompt_changed.emit("")


func _update_footsteps(distance: float) -> void:
	if not is_on_floor() or distance <= 0.0001 or _is_sitting():
		_stride_distance = stride_length * 0.6
		return
	_stride_distance += distance
	var stride := stride_length * (0.7 if Input.is_action_pressed(&"sprint") and not exhausted else 1.0)
	if _stride_distance >= stride:
		_stride_distance = 0.0
		if _footstep_player and not footstep_sounds.is_empty():
			_footstep_player.stream = footstep_sounds.pick_random()
			_footstep_player.pitch_scale = randf_range(0.9, 1.12)
			_footstep_player.play()
			footsteps_played += 1


func _camera_relative(input: Vector2) -> Vector3:
	if input == Vector2.ZERO:
		return Vector3.ZERO
	var cam := get_viewport().get_camera_3d()
	var forward := Vector3.FORWARD
	var right := Vector3.RIGHT
	if cam:
		forward = -cam.global_basis.z
		forward.y = 0.0
		forward = forward.normalized()
		right = cam.global_basis.x
		right.y = 0.0
		right = right.normalized()
	return (right * input.x - forward * input.y).normalized()


func _face_direction(direction: Vector3, delta: float) -> void:
	if _visual == null:
		return
	var target_yaw := atan2(direction.x, direction.z)
	_visual.rotation.y = lerp_angle(_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


func _find_action_key_name(action: StringName) -> String:
	for event in InputMap.action_get_events(action):
		if event is InputEventKey:
			var key := event as InputEventKey
			var code := key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
			return OS.get_keycode_string(code)
	return "E"


func to_save() -> Dictionary:
	var out_fit := {}
	for k in outfit:
		out_fit[k] = (outfit[k] as Color).to_html()
	return {"pos": [global_position.x, global_position.y, global_position.z],
			"yaw": _visual.rotation.y if _visual else 0.0, "stamina": stamina, "exhausted": exhausted, "outfit": out_fit,
			"look": appearance.duplicate()}


## v6b: the car the farmer is driving (null on foot).
var vehicle: Node3D = null
## v7b: walking drift in radians (tipsy after strong drinks at the cafe).
var drift_angle: float = 0.0
## v6b character creator look ({name, body, face, hair, hair_color, beard, skin, job, top}).
var appearance: Dictionary = {}


## v6b: applies a character-creator look (rebuilds the model) + the outfit.
func apply_look(new_look: Dictionary) -> void:
	appearance = new_look.duplicate()
	if _visual is HumanoidModelVisual:
		CharacterLook.apply(_visual as HumanoidModelVisual, appearance)
	apply_outfit()
	if str(appearance.get("name", "")) != "":
		Settings.set_value("player_name", str(appearance["name"]))


## v5a clothing shop: {"shirt": Color, "pants": Color} worn over the default.
var outfit: Dictionary = {}


func apply_outfit() -> void:
	var hv := _visual as HumanoidModelVisual
	if hv == null:
		return
	hv.set_outfit_colors(outfit.get("shirt", hv.shirt_color), outfit.get("pants", hv.pants_color))
	if appearance.has("top"):
		hv.set_top_style(str(appearance["top"]))


func from_save(data: Dictionary) -> void:
	var p: Array = data.get("pos", [global_position.x, global_position.y, global_position.z])
	global_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	if _visual:
		_visual.rotation.y = float(data.get("yaw", 0.0))
	stamina = float(data.get("stamina", stamina_max))
	exhausted = bool(data.get("exhausted", false))
	var saved_look: Dictionary = data.get("look", {})
	if not saved_look.is_empty() and saved_look != appearance:
		apply_look(saved_look)
	var saved_fit: Dictionary = data.get("outfit", {})
	if not saved_fit.is_empty():
		outfit.clear()
		for k in saved_fit:
			outfit[str(k)] = Color.html(str(saved_fit[k]))
		apply_outfit()
	_emit_stamina()
