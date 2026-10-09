class_name KidsStyle
extends AssetModule
## v7a children's free time: after school the town's kids ride bikes round the
## square and streets, play tag, chat, and sometimes ring a doorbell and run off
## (the owner comes out and grumbles). Consumer: KidsPlay.

@export var name_fa: String = ""
## outside after school (weekends from 10)
@export var play_hours: Vector2 = Vector2(14.5, 19.0)
## V2 points round the square
@export var bike_loop: Array = []
## m/s
@export var bike_speed: float = 4.2
@export var bike_colors: Array = []
## chance per hour of ring-and-run
@export var mischief_chance: float = 0.25
## {en, fa}
@export var chat_lines: Array = []
## {en, fa} said by the grumbling owner
@export var mischief_lines: Array = []
## {en, fa} giggles while running off
@export var kid_lines: Array = []
## who counts as a kid
@export var max_age: int = 13
