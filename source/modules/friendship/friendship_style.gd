class_name FriendshipStyle
extends AssetModule
## Friendship with townspeople (v5b): talking to someone raises it once per
## day; days without a visit can slowly lower it. Consumers: Friendship
## autoload, NpcCard (hearts), Dialogue (friendlier lines).

## Points for the first talk of the day with a person.
@export var points_per_talk: int = 10
## Extra points when you talk on consecutive days.
@export var streak_bonus: int = 2
@export var max_points: int = 100
## Points lost per day without talking (once you are acquainted).
@export var decay_per_day: int = 0
## Level thresholds (points) and names (fa / en), lowest first.
@export var level_points: PackedInt32Array = PackedInt32Array([0, 20, 45, 70, 95])
@export var level_names: Array = []
## Hearts shown on the card (max_points / hearts per heart).
@export var hearts: int = 10
