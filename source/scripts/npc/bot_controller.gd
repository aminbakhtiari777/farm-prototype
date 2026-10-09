class_name BotController
extends RefCounted
## Brain interface for a TownspersonBot. Each physics frame the bot calls
## tick() and gets back what it should do. ScheduleController (AI) is the
## default; a future network/player controller can replace it 1:1
## (bot.set_controller(...)) without touching the body/animation code.
##
## Intent keys:
##   move: Vector3     desired horizontal velocity (m/s, world space)
##   face: float       optional yaw to turn to when standing (radians)
##   pose: StringName  "", "sit", "talk", "kneel", "ground_sit"
##   seat: Seat        optional seat to occupy (pose "sit")
##   hidden: bool      inside their home at night (not rendered)
##   say: String       optional speech-bubble text (shown once)


func tick(_bot: Node3D, _delta: float) -> Dictionary:
	return {"move": Vector3.ZERO}


## Called when the player talks to this bot (E). Return the line to say.
func on_greeted(_bot: Node3D, _player: Node3D) -> String:
	return "Hello!"


## Short human-readable activity ("walking to the cafe"), used by tests/UI.
func describe() -> String:
	return "idle"
