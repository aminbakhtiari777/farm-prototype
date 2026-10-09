class_name DrivableBus
extends DrivableCar
## v7b.1 transit: a city bus you can drive (licence rules apply). Same
## controls as a car; slower, longer, diesel engine voice (car_sounds "bus").

var spec: Dictionary = {}
var line_names: Array = ["خط ۱", "Line 1"]


func _ready() -> void:
	model_name = "bus"
	size = Vector3(float(spec.get("width", 2.5)), float(spec.get("height", 3.0)), float(spec.get("length", 9.6)))
	super._ready()
	var m := BusModel.build(spec, str(line_names[0]), str(line_names[1]))
	model_root = m[0]
	add_child(model_root)
	add_to_group(&"buses")


func door_world() -> Vector3:
	return global_transform * Vector3(-size.x * 0.5 - 0.9, 0, size.z * 0.5 - 1.1)


func _fa_model() -> String:
	return "اتوبوس"
