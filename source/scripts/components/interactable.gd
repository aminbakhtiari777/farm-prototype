class_name Interactable
extends Area3D
## Reusable interaction zone. Drop it (with a CollisionShape3D child) into any
## scene - animal, crop, door, shipping bin - and connect to `interacted`.
##
## It registers itself with any body that enters and implements
## `register_interactable(Interactable)` / `unregister_interactable(Interactable)`
## (the Player does). The player then decides which one is closest and shows
## the prompt.

signal interacted(interactor: Node3D)

## Verb shown in the prompt: "Press E to <action_text>".
@export var action_text: String = "interact"
@export var enabled: bool = true:
	set(value):
		enabled = value
		if is_node_ready():
			prompt_dirty.emit()

## Optional node whose position is used for "closest target" checks and look-at
## (e.g. the highlighted tile of a crop plot). Defaults to this area's origin.
var focus_node: Node3D = null

## Emitted when the prompt text or availability changes, so the player can refresh the HUD.
signal prompt_dirty


func _ready() -> void:
	monitoring = true
	monitorable = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func focus_position() -> Vector3:
	if focus_node != null and is_instance_valid(focus_node):
		return focus_node.global_position
	return global_position


## Changes the verb and refreshes the HUD prompt if it differs.
func set_action_text(text: String) -> void:
	if text != action_text:
		action_text = text
		prompt_dirty.emit()


func can_interact() -> bool:
	return enabled


func get_prompt(key_name: String) -> String:
	# v6a: English verbs are translated through the ui_text module (Lang.loc).
	# A node may carry its own Persian text in meta "text_fa".
	if has_meta(&"text_fa") and Lang.is_fa():
		return Lang.prompt(key_name, str(get_meta(&"text_fa")))
	return Lang.prompt(key_name, Lang.loc(action_text))


func interact(interactor: Node3D) -> void:
	if can_interact():
		interacted.emit(interactor)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("register_interactable"):
		body.call("register_interactable", self)


func _on_body_exited(body: Node3D) -> void:
	if body.has_method("unregister_interactable"):
		body.call("unregister_interactable", self)
