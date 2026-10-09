class_name PushableStyle
extends AssetModule
## v6b boxes you can push (walk into them / E) and stack (F to lift, place on
## top of another box). Their spots are remembered (WorldMemory).
## Consumer: Pushables.

@export var name_fa: String = ""
## {pos (V2), kind}
@export var boxes: Array = []
## m per push
@export var push_step: float = 0.9
@export var max_stack: int = 3
@export var color: Color = Color(0.62, 0.45, 0.26)
