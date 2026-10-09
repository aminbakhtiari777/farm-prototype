class_name HouseMusicStyle
extends AssetModule
## v6a music from inside buildings: positional players with distance falloff,
## plus occlusion-ish damping (quieter + low-pass when walls are between the
## listener and the source). Consumers: HouseMusic (scripts/v6a/house_music.gd).

@export var name_fa: String = ""
## building id -> music file.
@export var sources: Dictionary = {}
@export var volume_db: float = -8.0
@export var unit_size: float = 3.0
@export var max_distance: float = 30.0
## Extra attenuation + low-pass cutoff when occluded (outside the building).
@export var occluded_db: float = -10.0
@export var occluded_cutoff_hz: float = 900.0
@export var open_cutoff_hz: float = 16000.0
## Hours when the music plays.
@export var hours: Vector2 = Vector2(9.0, 22.0)
