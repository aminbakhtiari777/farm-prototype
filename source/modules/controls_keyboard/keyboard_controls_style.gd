class_name KeyboardControlsStyle
extends AssetModule
## v7b.1 keyboard fallback: WASD / arrows move relative to the camera, Z/C (, .)
## and PageUp/PageDown orbit, A/D steer cars, Space handbrake. The 'turn' variant
## makes A/D and the left/right arrows turn the camera + character instead of
## strafing (tank style). Consumers: ControlInput.

@export var name_fa: String = ""
## A/D + left/right arrows turn instead of strafing (on foot)
@export var ad_turns: bool = false
## turn speed for ad_turns
@export var turn_deg_per_sec: float = 120.0
