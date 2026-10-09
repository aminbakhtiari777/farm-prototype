class_name SunbathingStyle
extends AssetModule
## v6a sunbathing beach: a separate stretch of sand with towels + umbrellas;
## lie down on a towel (E). Townspeople come on fine days. Consumers:
## SunbathingBeach, ScheduleController ("sunbathe" activity).

@export var name_fa: String = ""
@export var center: Vector2 = Vector2(63.0, -9.0)
@export var towels: int = 6
@export var towel_colors: Array = [Color(0.95, 0.4, 0.35), Color(0.3, 0.6, 0.9), Color(0.98, 0.85, 0.3), Color(0.45, 0.8, 0.55)]
@export var umbrella_colors: Array = [Color(0.95, 0.3, 0.25), Color(0.2, 0.55, 0.85), Color(1.0, 0.8, 0.2)]
@export var hours: Vector2 = Vector2(10.0, 17.0)
@export var weather: PackedStringArray = PackedStringArray(["sunny", "heatwave", "cloudy"])
## Every Nth resident with free time spends the afternoon here.
@export var npc_every: int = 5
@export var rest_mult: float = 1.5
