class_name SkyStyle
extends AssetModule
## Sky colours over the day. Consumer: DayNightCycle (live).

@export var day_zenith: Color = Color(0.23, 0.42, 0.74)
@export var day_horizon: Color = Color(0.70, 0.80, 0.90)
@export var dusk_zenith: Color = Color(0.22, 0.27, 0.5)
@export var dusk_horizon: Color = Color(0.98, 0.58, 0.32)
@export var night_zenith: Color = Color(0.012, 0.02, 0.06)
@export var night_horizon: Color = Color(0.05, 0.075, 0.15)
## v6a: cloud coverage x this (glassy clear skies) and 0..1 extra clarity (less haze).
@export var cloud_mult: float = 1.0
@export var clarity: float = 0.0
@export var shader_path: String = "res://assets/shaders/sky_clouds.gdshader"


func asset_paths() -> PackedStringArray:
	return PackedStringArray([shader_path])
