class_name TouchControlsStyle
extends AssetModule
## v7b.1 touch scheme for phones/tablets (GTA mobile style): LEFT virtual joystick
## moves (camera-relative; in a car up/down = throttle/brake), RIGHT joystick turns
## the camera / the character and steers the car. Sticks are semi-transparent,
## multi-touch safe (each finger tracked by index) and appear where the thumb lands
## (floating) in the left / right half. Buttons: interact, jump, sprint, car, play-as
## (possession) + dig / demolish / fire, brake / horn / lights, controls, menu.
## Shown automatically on touch screens. Consumers: TouchControls, ControlInput.

@export var name_fa: String = ""
## sticks appear where the thumb lands (else fixed positions)
@export var floating: bool = true
## stick radius as a fraction of the short screen side
@export var stick_radius: float = 0.11
## button diameter as a fraction of the short screen side
@export var button_size: float = 0.115
@export var deadzone: float = 0.12
## stick + button opacity
@export var opacity: float = 0.5
## camera yaw speed at full right-stick
@export var look_deg_per_sec: float = 150.0
## camera pitch speed at full right-stick
@export var pitch_deg_per_sec: float = 80.0
## in a car the left stick X steers too
@export var left_stick_steers: bool = true
## in a car the right stick X steers
@export var right_stick_steers: bool = true
## touches above this fraction of the screen height never grab a stick
@export var zone_top: float = 0.28
## phones / web: scale the 1600x900 UI to the screen (canvas_items stretch, keeps text readable on high-DPI screens)
@export var fit_ui: bool = true
