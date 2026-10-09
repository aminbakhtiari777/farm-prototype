class_name GymStyle
extends AssetModule
## v6a town gym: equipment (treadmill, weights, bench press...) that the
## player and townspeople use; workouts build fitness (more max stamina,
## faster recovery, less illness). Plays music inside. Consumers: Gym
## (interior + stations), Lifestyle (fitness), ScheduleController ("workout").

@export var name_fa: String = ""
## Equipment: {id, en, fa, pose, minutes, stamina, fitness, pos (x, z in the room, -1..1), yaw}.
@export var equipment: Array = []
@export var fee: int = 10
@export var fitness_max: float = 100.0
## Max stamina bonus at full fitness.
@export var stamina_bonus: float = 40.0
## Illness chance multiplier at full fitness.
@export var illness_mult: float = 0.5
## Fitness lost per day without a workout.
@export var decay_per_day: float = 2.0
@export var npc_every: int = 4
@export var music: String = "res://assets/audio/music/gym_loop.ogg"
@export var music_db: float = -6.0
@export var floor_color: Color = Color(0.25, 0.27, 0.3)
@export var accent: Color = Color(0.95, 0.45, 0.1)
## v6b fuller gym: extra pieces built by InteriorV6b.gym_extras (remove an
## entry to drop it): mirror_wall, kettlebells, squat_rack, rower, balls, water.
@export var extras: PackedStringArray = PackedStringArray(["mirror_wall", "kettlebells", "squat_rack", "rower", "balls", "water"])
