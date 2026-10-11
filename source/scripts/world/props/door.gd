class_name BuildingDoor
extends Node3D
## Hinged front door. This node is the hinge (left edge of the doorway); the
## panel swings inward (towards -Z) when opened. Press E nearby to open/close.
## Townspeople open it automatically while they pass through.

signal toggled(open: bool)

@export var width: float = 1.14
@export var height: float = 2.2
@export var panel_color: Color = Color(0.35, 0.22, 0.13)
@export var open_angle_degrees: float = 100.0

var is_open: bool = false
var locked: bool = false
var _panel: AnimatableBody3D
var _zone: Interactable
var _tween: Tween
var _auto_opened: bool = false
var _auto_timer: float = 0.0
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_panel = AnimatableBody3D.new()
	_panel.name = "Panel"
	_panel.collision_layer = 1
	_panel.collision_mask = 0
	_panel.sync_to_physics = false
	add_child(_panel)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(width, height, 0.07)
	mesh.mesh = box
	mesh.material_override = ProceduralProp.color_material(panel_color, 0.6)
	mesh.position = Vector3(width * 0.5, height * 0.5, 0)
	_panel.add_child(mesh)
	# v7b.1 perf: only the main panel casts a shadow (inset panels / knobs
	# used to add ~4 shadow casters per door = ~160 extras across town).
	# Panels / knob for detail.
	for i in (2 if width > 0.9 else 0):
		var inset := MeshInstance3D.new()
		var ib := BoxMesh.new()
		ib.size = Vector3(width * 0.62, height * 0.32, 0.09)
		inset.mesh = ib
		inset.material_override = ProceduralProp.color_material(panel_color.darkened(0.18), 0.6)
		inset.position = Vector3(width * 0.5, height * (0.3 + i * 0.42), 0)
		inset.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_panel.add_child(inset)
	var knob := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.04
	sm.height = 0.08
	knob.mesh = sm
	knob.material_override = ProceduralProp.color_material(Color(0.78, 0.63, 0.28), 0.3, false)
	knob.position = Vector3(width - 0.12, height * 0.45, 0.07)
	knob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panel.add_child(knob)
	var knob2 := knob.duplicate() as MeshInstance3D
	knob2.position.z = -0.07
	knob2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_panel.add_child(knob2)
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 0.08)
	shape.shape = bs
	shape.position = Vector3(width * 0.5, height * 0.5, 0)
	_panel.add_child(shape)

	_zone = Interactable.new()
	_zone.name = "DoorInteraction"
	_zone.collision_layer = 8
	_zone.collision_mask = 2
	_zone.action_text = "open the door"
	_zone.position = Vector3(width * 0.5, height * 0.5, 0)
	var zs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	zs.shape = sphere
	_zone.add_child(zs)
	add_child(_zone)
	_zone.interacted.connect(func(_who: Node3D) -> void: toggle())
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = load("res://assets/audio/sfx/door_creak.ogg") if ResourceLoader.exists("res://assets/audio/sfx/door_creak.ogg") else null
	_audio.volume_db = -8.0
	_audio.unit_size = 3.0
	_audio.max_distance = 25.0
	_audio.position = Vector3(width * 0.5, 1.2, 0)
	add_child(_audio)
	add_to_group(&"doors")
	var b := get_parent() as Building
	if b:
		locked = bool(Economy.door_locks.get(b.layout_id, false))
		if locked:
			_zone.set_action_text(Lang.tt("قفل است (؛: بازکردن قفل)", "locked (;: unlock)"))


func toggle() -> void:
	if locked:
		GameEvents.notification_requested.emit(Lang.tt("در قفل است؛ ابتدا قفل را باز کن.", "The door is locked; unlock it first."))
		return
	set_open(not is_open)


func set_open(value: bool, instant: bool = false) -> void:
	if value and locked:
		return
	if value == is_open:
		return
	is_open = value
	_zone.set_action_text("close the door" if value else "open the door")
	var target := deg_to_rad(open_angle_degrees) if value else 0.0  # swings inward (-Z)
	if _tween:
		_tween.kill()
	if instant:
		_panel.rotation.y = target
	else:
		_tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
		_tween.tween_property(_panel, "rotation:y", target, 0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		if _audio.stream:
			_audio.pitch_scale = randf_range(0.9, 1.1) * (1.0 if value else 1.15)
			_audio.play()
	toggled.emit(value)


## Current swing angle in degrees (0 = closed).
func swing_degrees() -> float:
	return rad_to_deg(_panel.rotation.y)


func _physics_process(delta: float) -> void:
	# Townspeople: open while someone walks through, close again afterwards.
	_auto_timer -= delta
	if _auto_timer > 0.0:
		return
	_auto_timer = 0.25
	if not (get_parent() is Building):
		return
	var viewer := get_tree().get_first_node_in_group(&"player") as Node3D
	if viewer and viewer.global_position.distance_squared_to(global_position) > 400.0:
		_auto_timer = 1.0
		return
	var someone := false
	for bot in get_tree().get_nodes_in_group(&"townspeople"):
		var n := bot as Node3D
		if n.visible and n.global_position.distance_to(global_position + global_basis.x * width * 0.5) < 2.4:
			someone = true
			break
	if someone and not is_open:
		set_open(true)
		_auto_opened = true
	elif not someone and is_open and _auto_opened:
		set_open(false)
		_auto_opened = false


func set_locked(value: bool) -> void:
	if value and is_open:
		set_open(false)
	locked = value
	var b := get_parent() as Building
	if b:
		Economy.door_locks[b.layout_id] = value
	_zone.set_action_text(Lang.tt("قفل است (؛: بازکردن قفل)", "locked (;: unlock)") if value else "open the door")
