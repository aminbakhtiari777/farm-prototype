class_name ActionSpot
extends Node3D
## v6a generic interaction point: an Interactable zone whose prompt and action
## come from callables (dry trees, campfire, boats, gym equipment, towels,
## the hypermarket counter). `text_fn() -> String` is the verb (already in the
## current language), `use_fn(who: Node3D)` runs on E, `can_fn() -> bool`
## (optional) enables it.

var zone: Interactable
var text_fn: Callable
var use_fn: Callable
var can_fn: Callable
var radius: float = 1.3
var zone_height: float = 0.8


static func make(parent: Node, pos: Vector3, r: float, text: Callable, use: Callable, can: Callable = Callable()) -> ActionSpot:
	var s := ActionSpot.new()
	s.radius = r
	s.text_fn = text
	s.use_fn = use
	s.can_fn = can
	s.position = pos
	parent.add_child(s)
	return s


func _ready() -> void:
	zone = Interactable.new()
	zone.name = "Zone"
	zone.collision_layer = 8
	zone.collision_mask = 2
	zone.position = Vector3(0, zone_height, 0)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	zone.add_child(shape)
	add_child(zone)
	zone.action_text = _text()
	zone.interacted.connect(func(who: Node3D) -> void:
		if use_fn.is_valid():
			use_fn.call(who)
		refresh())
	GameEvents.setting_changed.connect(func(_k: String, _v: Variant) -> void: refresh())
	refresh()


func _text() -> String:
	return str(text_fn.call()) if text_fn.is_valid() else "use"


## Re-reads the verb and the enabled state (call after the state changed).
func refresh() -> void:
	if zone == null:
		return
	zone.set_action_text(_text())
	zone.enabled = can_fn.call() if can_fn.is_valid() else true


## Smoke tests / bots: use it directly.
func use(who: Node3D) -> void:
	zone.interact(who)
