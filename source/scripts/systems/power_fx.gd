class_name PowerFx
extends RefCounted
## Shared materials for electric lamps and candle / lantern / fire flames.
## NightLights animates them (one material = every lamp in town at once).

static var _bulb: StandardMaterial3D
static var _flame: StandardMaterial3D


## Glass of porch / wall lanterns on houses (glows when lights are on).
static func bulb_material() -> StandardMaterial3D:
	if _bulb == null:
		_bulb = StandardMaterial3D.new()
		_bulb.albedo_color = Color(1.0, 0.92, 0.75)
		_bulb.emission_enabled = true
		_bulb.emission = Color(1.0, 0.8, 0.5)
		_bulb.emission_energy_multiplier = 0.0
	return _bulb


## Candle / lantern / fireplace flames (visible only during power cuts).
static func flame_material() -> StandardMaterial3D:
	if _flame == null:
		_flame = StandardMaterial3D.new()
		_flame.albedo_color = Color(1.0, 0.7, 0.3)
		_flame.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame.emission_enabled = true
		_flame.emission = Color(1.0, 0.55, 0.15)
		_flame.emission_energy_multiplier = 2.5
	return _flame
