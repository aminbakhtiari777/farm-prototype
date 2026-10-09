class_name HerdingStyle
extends AssetModule
## v6b sheep herding: a small flock grazes in the west meadow; sheep move away
## from you, so walking behind them drives them through the gate into the pen.
## All in = the flock is penned (reward, part of the yard routine).
## Consumer: Herding.

@export var name_fa: String = ""
@export var flock: int = 5
@export var meadow: Vector2 = Vector2(-42.0, -16.0)
@export var meadow_radius: float = 9.0
## x, z, w, d
@export var pen: Rect2 = Rect2(-30.0, -12.0, 8.0, 7.0)
@export var gate_side: String = "west"
@export var flee_radius: float = 4.0
@export var flee_speed: float = 2.6
@export var reward: int = 40
