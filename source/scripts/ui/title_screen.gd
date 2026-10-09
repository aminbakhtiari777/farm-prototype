class_name TitleScreen
extends Control
## Title / name screen shown after "Logout" (and available as a fresh start).
## Continue = load the saved game; New game = reset everything (deletes the
## save after confirmation); the name is stored in Settings.

signal finished

var _name: LineEdit
var _continue: Button
var _confirm: bool = false
var _new_btn: Button


func _ready() -> void:
	name = "TitleScreen"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.13, 0.09, 0.88)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(420, 300)
	box.offset_left = -210
	box.offset_right = 210
	box.offset_top = -170
	box.offset_bottom = 170
	box.add_theme_constant_override(&"separation", 14)
	add_child(box)
	var t := UIKit.label(box, "Cozy Farm", 54, Color(1, 0.9, 0.6))
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := UIKit.label(box, "Farm, fish, and say hi to the neighbours", 17, Color(0.9, 0.95, 0.85))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIKit.label(box, "Your name", 15, Color(0.9, 0.9, 0.85))
	_name = LineEdit.new()
	_name.text = str(Settings.get_value("player_name"))
	_name.max_length = 20
	_name.placeholder_text = "Farmer"
	box.add_child(_name)
	_continue = UIKit.button(box, "Continue", _on_continue, "Load your saved farm", 20)
	UIKit.button(box, "Play without loading", _on_play, "Keep the current session", 18)
	_new_btn = UIKit.button(box, "New game (reset)", _on_new, "Start over - deletes the save", 16)
	var note := UIKit.label(box, "Multiplayer login coming soon - your progress is stored on this device.", 13, Color(0.75, 0.8, 0.7))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func open() -> void:
	visible = true
	_confirm = false
	_new_btn.text = "New game (reset)"
	_continue.disabled = not SaveGame.has_save()
	GameEvents.open_modal("title")
	GameEvents.interaction_prompt_changed.emit("")


func _store_name() -> void:
	var n := _name.text.strip_edges()
	Settings.set_value("player_name", n if n != "" else "Farmer")
	_name.release_focus()


func _close() -> void:
	visible = false
	GameEvents.close_modal("title")
	finished.emit()


func _on_continue() -> void:
	_store_name()
	var ok := SaveGame.load_game()
	GameEvents.notification_requested.emit("Welcome back, %s!" % Settings.get_value("player_name") if ok else SaveGame.last_error)
	_close()


func _on_play() -> void:
	_store_name()
	GameEvents.notification_requested.emit("Hello, %s!" % Settings.get_value("player_name"))
	_close()


func _on_new() -> void:
	if not _confirm:
		_confirm = true
		_new_btn.text = "Click again to confirm reset"
		return
	_store_name()
	SaveGame.delete_save()
	Economy.reset()
	# v5c: fresh market + ranch for a new game.
	Market.reset()
	Ranch.reset()
	TimeManager.reset_calendar(1, 8.0, "sunny")
	get_tree().paused = false
	_close()
	GameEvents.close_all_modals()
	get_tree().reload_current_scene()
