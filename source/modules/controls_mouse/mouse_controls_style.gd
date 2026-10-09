class_name MouseControlsStyle
extends AssetModule
## v7b.1 desktop mouse scheme (GTA-style): click the game to capture the mouse
## (pointer lock), then the mouse turns the camera (left/right = yaw, up/down =
## pitch); WASD moves relative to the camera. In a car mouse X steers (a virtual
## wheel that re-centres), W/S throttle/brake. Esc (or any panel) releases the
## mouse. Consumers: ControlInput, FollowCamera, Player, DrivableCar.

@export var name_fa: String = ""
## camera degrees per mouse pixel (x Settings camera_sensitivity)
@export var look_deg_per_px: float = 0.16
## left click on the game captures the mouse
@export var capture_on_click: bool = true
## in a car mouse X steers (else it only orbits the camera)
@export var mouse_steer: bool = true
## wheel turn per mouse pixel (-1..1)
@export var steer_per_px: float = 0.011
## wheel re-centres per second when the mouse is still
@export var steer_return: float = 1.6
## standing still, turning the camera turns the character too
@export var face_camera_idle: bool = true
## small 'click to look around' hint
@export var show_hint: bool = true
