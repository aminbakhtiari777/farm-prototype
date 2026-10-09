extends Label3D
## Billboard text that floats up and fades out, then frees itself.

@export var rise_height: float = 0.7
@export var lifetime: float = 1.4


func _ready() -> void:
	var start := position
	scale = Vector3.ONE * 0.4
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", start.y + rise_height, lifetime).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.tween_property(self, "outline_modulate:a", 0.0, lifetime * 0.5).set_delay(lifetime * 0.5)
	tween.chain().tween_callback(queue_free)
