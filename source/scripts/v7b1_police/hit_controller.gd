class_name HitReactController
extends BotController
## v7b.1 road_safety: takes over a townsperson who was hit by a car (non-graphic).
##   push    short knock-back away from the car
##   stumble one knee for stumble_s, then up          (light hit)
##   fall    on the ground for fall_s, knee, then up  (medium hit)
##   down    stays on the ground until release()      (hard hit: ambulance)
##   getup   knee for a moment, then stand            -> finished
## AccidentResponse hands the bot back to `original` once finished.

var original: BotController
var mode: String = "stumble"
var t: float = 0.0
var hold: float = 2.0
var push_dir: Vector3 = Vector3.ZERO
var push_t: float = 0.35
var face_yaw: float = 0.0
var finished: bool = false
var line: String = ""


func tick(_bot: Node3D, delta: float) -> Dictionary:
	t += delta
	if push_t > 0.0:
		push_t -= delta
		return {"move": push_dir * 2.2, "pose": &""}
	match mode:
		"stumble":
			if t > hold:
				_get_up()
			return {"move": Vector3.ZERO, "pose": &"kneel", "face": face_yaw}
		"fall":
			if t > hold:
				_get_up()
			return {"move": Vector3.ZERO, "pose": &"lie", "face": face_yaw}
		"down":
			return {"move": Vector3.ZERO, "pose": &"lie", "face": face_yaw}
		"getup":
			if t > 0.9:
				finished = true
				return {"move": Vector3.ZERO, "pose": &"", "face": face_yaw}
			return {"move": Vector3.ZERO, "pose": &"kneel", "face": face_yaw}
	return {"move": Vector3.ZERO}


func _get_up() -> void:
	mode = "getup"
	t = 0.0


## Hard hit: the paramedics are done.
func release() -> void:
	if mode == "down":
		_get_up()


func is_down() -> bool:
	return mode == "down" or mode == "fall"


func on_greeted(_bot: Node3D, _player: Node3D) -> String:
	return line if line != "" else Lang.tt("آخ... الان خوب می‌شم.", "Ouch... I'll be OK.")


func describe() -> String:
	return "hit:" + mode
