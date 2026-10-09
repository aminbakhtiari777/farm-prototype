class_name TownspersonBot
extends CharacterBody3D
## A townsperson body: same humanoid model as the farmer with its own outfit,
## driven by a BotController (ScheduleController AI by default). The body only
## executes intents (move/face/pose/seat/hidden), so a network or player
## controller can take over later via set_controller() - no AI code needed.
## Press E near them to greet (they stop, turn and answer).

@export var display_name: String = "Townsperson"
@export var home_id: String = ""
@export var outfit: Dictionary = {}
## v5a identity from the population module (name, surname, age, job, home...).
var resident: Dictionary = {}
var body_scale_mult: float = 1.0
## Optional gesture hook (NpcGestures sets this); the body plays it.
var gesture: Node = null

var controller: BotController
var visual: HumanoidModelVisual
var zone: Interactable
var hidden_inside: bool = false
var distance_moved: float = 0.0
var _bubble: Label3D
var _bubble_timer: float = 0.0
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _seat: Seat = null
var _far: bool = false
var _far_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_pos: Vector3
var _npc_tick: int = 0
## v7b.1 police: (bot, move) -> move; wait at the kerb for close moving cars,
## step aside for a waiting car (RoadSafety.pedestrian_filter).
static var move_filter: Callable


func _ready() -> void:
	add_to_group(&"townspeople")
	collision_layer = 16
	collision_mask = 1
	floor_snap_length = 0.4
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	shape.shape = cap
	shape.position.y = 0.875
	add_child(shape)
	visual = HumanoidModelVisual.new()
	visual.name = "Visual"
	for k in outfit:
		visual.set(k, outfit[k])
	add_child(visual)
	if body_scale_mult != 1.0:
		visual.scale = Vector3.ONE * body_scale_mult
	zone = Interactable.new()
	zone.name = "TalkInteraction"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.action_text = "greet %s" % display_name
	zone.position.y = 1.0
	var zs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 1.6
	zs.shape = sp
	zone.add_child(zs)
	add_child(zone)
	zone.interacted.connect(_on_greeted)
	_bubble = Label3D.new()
	_bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bubble.font_size = 40
	_bubble.pixel_size = 0.005
	_bubble.outline_size = 10
	_bubble.position.y = 2.25 * body_scale_mult + 0.1
	_bubble.visible = false
	_bubble.no_depth_test = false
	# v5b: Persian-capable font (Vazirmatn, "fonts" module), RTL shaping.
	Lang.setup_label3d(_bubble)
	_bubble.pixel_size = 0.0045
	_bubble.width = 520.0
	_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bubble.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM  # multi-line bubbles grow upward, never over the name tag
	_bubble.modulate = Color(1, 1, 1)
	_bubble.outline_modulate = Color(0.08, 0.06, 0.05, 0.9)
	add_child(_bubble)
	var tag := Label3D.new()
	_tag = tag
	Lang.setup_label3d(tag, 32)
	tag.text = _tag_text()
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.font_size = 32
	tag.pixel_size = 0.004
	tag.outline_size = 8
	tag.modulate = Color(1, 0.95, 0.8)
	tag.position.y = 2.0 * body_scale_mult + 0.05
	tag.visibility_range_end = 14.0
	add_child(tag)
	_last_pos = global_position
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == "dialogue_language" and is_instance_valid(_tag):
			_tag.text = _tag_text())
	# v6b: smaller name tags / bubbles indoors, hidden right next to the camera.
	GameEvents.building_entered.connect(func(_b: Node3D) -> void: _cam_indoors = true)
	GameEvents.building_exited.connect(func(_b: Node3D) -> void: _cam_indoors = false)


var _tag: Label3D
var _cam_indoors := false
var _label_t := 0.0
## Current label scale (1 = outdoors at a distance), for tests.
var label_scale := 1.0
const TAG_PIXEL := 0.004
const BUBBLE_PIXEL := 0.0045


## v6b ("npc_looks" module): scale the name tag + speech bubble down indoors
## and up close, and hide them when the camera is right next to the head.
func update_labels(cam_pos: Vector3, indoors: bool) -> void:
	if _tag == null or _bubble == null:
		return
	var nl := Modules.style("npc_looks") as NpcLooksStyle
	var near := nl.tag_hide_near if nl else 0.0
	var dist := cam_pos.distance_to(global_position + Vector3.UP * 1.8)
	var s := (nl.indoor_label_scale if nl else 1.0) if indoors else 1.0
	if dist < 6.0:
		s *= lerpf(0.6, 1.0, clampf((dist - near) / maxf(6.0 - near, 0.1), 0.0, 1.0))
	var hide := dist < near
	label_scale = 0.0 if hide else s
	_tag.transparency = 1.0 if hide else 0.0
	_bubble.transparency = 1.0 if hide else 0.0
	_tag.pixel_size = TAG_PIXEL * s
	_bubble.pixel_size = BUBBLE_PIXEL * s
var _queue: Array = []  ## [[text, seconds], ...] follow-up bubble lines


func _tag_text() -> String:
	if resident.is_empty():
		return display_name
	return "%s\n%s" % [Dialogue.name_of(resident), Dialogue.job_of(resident)]


var _shadows_on: bool = true


func _set_shadows(on: bool) -> void:
	if on == _shadows_on or visual == null:
		return
	_shadows_on = on
	for mi in visual.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_controller(c: BotController) -> void:
	controller = c


func is_far_from_player() -> bool:
	return _far


func _physics_process(delta: float) -> void:
	_far_timer -= delta
	if _far_timer <= 0.0:
		_far_timer = 0.5
		var cam := get_viewport().get_camera_3d()
		var dist := INF if cam == null else cam.global_position.distance_to(global_position)
		# v7b.1 quality preset distances (was hardcoded 50 / 60 / 45 / 28).
		var q := PerfQuality.style()
		var vis_d := q.npc_visible_distance if q else 60.0
		var anim_d := q.npc_anim_distance if q else 45.0
		var sh_d := q.npc_shadow_distance if q else 28.0
		_far = dist > vis_d * 0.85
		visual.visible = not hidden_inside and dist < vis_d
		if visual.anim_tree:
			visual.anim_tree.active = visual.visible and dist < anim_d
		_set_shadows(dist < sh_d)
		_npc_tick = 0
	_label_t -= delta
	if _label_t <= 0.0:
		_label_t = 0.15
		var lcam := get_viewport().get_camera_3d()
		if lcam and visual.visible:
			update_labels(lcam.global_position, _cam_indoors)
	if controller == null:
		return
	# v7b.1: far townspeople only tick their schedule every Nth physics frame
	# (they still advance; just less often - schedule-only simulation).
	_npc_tick += 1
	var q2 := PerfQuality.style()
	var far_n := q2.npc_far_tick if q2 else 1
	if not PerfWorld.far_tick_enabled:
		far_n = 1
	if _far and far_n > 1 and (_npc_tick % far_n) != 0:
		return
	if _far and far_n > 1:
		delta *= far_n  # catch up the skipped ticks (movement + schedule)
	var intent := controller.tick(self, delta)
	var go_hide: bool = intent.get("hidden", false)
	if go_hide != hidden_inside:
		hidden_inside = go_hide
		zone.enabled = not go_hide
		visual.visible = not go_hide
		collision_layer = 0 if go_hide else 16
	if go_hide:
		return
	var seat: Seat = intent.get("seat", null)
	var pose: StringName = intent.get("pose", &"")
	if _seat != null and not is_instance_valid(_seat):
		_seat = null
	if seat != _seat:
		if _seat:
			_seat.release(self)
		_seat = seat
		if seat and seat.claim(self):
			global_position = seat.global_position
			visual.rotation.y = seat.facing_yaw()
	if _seat:
		velocity = Vector3.ZERO
		visual.set_pose(StringName(_seat.get_meta(&"pose", &"sit")))
		visual.set_ground_speed(0.0)
		return
	visual.set_pose(pose)
	var move: Vector3 = intent.get("move", Vector3.ZERO)
	# Don't walk into the farmer.
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	if player and move.length() > 0.01:
		var to_p := player.global_position - global_position
		to_p.y = 0.0
		if to_p.length() < 1.1 and to_p.normalized().dot(move.normalized()) > 0.5:
			move = Vector3.ZERO
	if move_filter.is_valid():
		move = move_filter.call(self, move)
	# v5b: ill townspeople walk slower (Needs / illnesses module).
	if move.length() > 0.01:
		move *= Needs.npc_speed_factor(self)
	velocity.x = move.x
	velocity.z = move.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= _gravity * delta
	var before := global_position
	if _far and move.length() > 0.01:
		# Off-screen: skip collisions (cheap, never gets stuck).
		global_position += Vector3(move.x, 0, move.z) * delta
		global_position.y = Terrain.height_at(global_position.x, global_position.z)
	else:
		move_and_slide()
	var moved := Vector2(global_position.x - before.x, global_position.z - before.z).length()
	distance_moved += moved
	if move.length() > 0.05:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(move.x, move.z), 1.0 - exp(-10.0 * delta))
		# Unstick: if barely moving while trying to walk, hop toward the target.
		if moved < move.length() * delta * 0.2:
			_stuck_timer += delta
			if _stuck_timer > 1.5:
				global_position += move.normalized() * 0.8
				global_position.y = Terrain.height_at(global_position.x, global_position.z) + 0.1
				_stuck_timer = 0.0
		else:
			_stuck_timer = 0.0
	elif intent.has("face"):
		visual.rotation.y = lerp_angle(visual.rotation.y, float(intent["face"]), 1.0 - exp(-8.0 * delta))
	visual.set_ground_speed(moved / maxf(delta, 0.0001) if not _far else move.length())
	if _bubble_timer > 0.0:
		_bubble_timer -= delta
		if _bubble_timer <= 0.0:
			_bubble.visible = false
			if not _queue.is_empty():
				var nx: Array = _queue.pop_front()
				say(str(nx[0]), float(nx[1]))


## Last conversation (v5b): lines shown in the NPC card's dialogue box.
var last_talk: PackedStringArray = PackedStringArray()
var last_gain: int = 0


func _on_greeted(who: Node3D) -> void:
	if controller == null:
		return
	controller.on_greeted(self, who)  # turn + face the farmer
	# v5b: job / time / family / friendship / health dialogue (Dialogue module).
	last_talk = Dialogue.talk_lines(self)
	last_gain = Friendship.talk(Friendship.key_of(self))
	var line := last_talk[0] if last_talk.size() > 0 else "..."
	_queue.clear()
	say(line, 2.6)
	for i in range(1, last_talk.size()):
		_queue.append([last_talk[i], 3.4])
	talked.emit(self)
	var gain_txt := ""
	if last_gain > 0:
		gain_txt = ("  (دوستی +%s)" % Lang.digits(str(last_gain))) if Lang.is_fa() else "  (friendship +%d)" % last_gain
	if resident.is_empty():
		GameEvents.notification_requested.emit("%s: \"%s\"%s" % [display_name, line, gain_txt])
	elif Lang.is_fa():
		var work := str(resident.get("work", ""))
		var job := Dialogue.job_of(resident) + ((" در " + Dialogue.place_of(work)) if work != "" else "")
		GameEvents.notification_requested.emit("%s (%s ساله، %s): «%s»%s" % [Dialogue.name_of(resident),
				Lang.digits(str(int(resident.get("age", 0)))), job, line, gain_txt])
	else:
		GameEvents.notification_requested.emit("%s (%d, %s): \"%s\"%s" % [Population.full_name(resident),
				int(resident.get("age", 0)), Population.job_text(resident), line, gain_txt])


signal talked(bot: TownspersonBot)


## v5a wave gesture (NpcGestures): fades a WaveModifier in and out.
var wave_modifier: WaveModifier
var _wave_left: float = 0.0
var _wave_total: float = 0.0


func start_wave(seconds: float, raise: float = 1.0, speed: float = 2.4) -> void:
	if visual == null or visual.skeleton == null:
		return
	if wave_modifier == null:
		wave_modifier = WaveModifier.new()
		wave_modifier.name = "WaveModifier"
		visual.skeleton.add_child(wave_modifier)
	wave_modifier.raise = clampf(raise, 0.2, 1.0)
	wave_modifier.speed = speed
	wave_modifier.active = true
	_wave_left = seconds
	_wave_total = seconds


func is_waving() -> bool:
	return _wave_left > 0.0


func _process(delta: float) -> void:
	if wave_modifier == null or not wave_modifier.active:
		return
	_wave_left -= delta
	var t := 1.0 - _wave_left / maxf(_wave_total, 0.01)
	wave_modifier.weight = clampf(minf(t / 0.2, _wave_left / 0.35), 0.0, 1.0)
	if _wave_left <= 0.0:
		wave_modifier.weight = 0.0
		wave_modifier.active = false


func say(text: String, seconds: float = 4.0) -> void:
	_bubble.text = text
	_bubble.visible = true
	_bubble_timer = seconds
	# v5b: pitch-varied voice blips ("voices" module).
	if not hidden_inside and is_inside_tree():
		var vb := VoiceBlips.instance(get_tree())
		if vb:
			vb.speak(self, text)


## Teleport to where the routine says this bot should be right now (start / load).
func snap_to_schedule() -> void:
	if controller is ScheduleController:
		var sc := controller as ScheduleController
		var e := sc.entry_for_hour(TimeManager.hours_float())
		var p := TownNav.spot_position(str(e["spot"]))
		if p != Vector3.INF:
			global_position = p + Vector3(randf_range(-1.0, 1.0), 0.1, randf_range(-1.0, 1.0))
		sc.current = e
		sc.arrived = true
