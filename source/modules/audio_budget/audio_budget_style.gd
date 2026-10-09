class_name AudioBudgetStyle
extends AssetModule
## v7b.1 audio budget: positional sounds beyond the preset's audio_distance are
## paused, at most max_voices play at once (nearest win), one-shot players are
## pooled and reused, and cached sound streams not played for a while are
## released so they can be freed. Consumers: AudioBudget, Sfx.

@export var name_fa: String = ""
@export var enabled: bool = true
## seconds between checks
@export var check_interval: float = 0.35
## seconds unused before a cached stream is released
@export var release_after: float = 90.0
## pooled one-shot 3D players
@export var pool_size: int = 8
## never touch non-positional (UI / music) players
@export var keep_2d: bool = true
