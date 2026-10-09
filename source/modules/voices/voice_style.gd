class_name VoiceStyle
extends AssetModule
## Townspeople voices (v5b): short pitch-varied synthesized "blips" while a
## speech bubble appears (no real speech). Higher for women and children,
## lower for men. Consumers: VoiceBlips (scripts/npc/voice_blips.gd).

@export var samples: PackedStringArray = PackedStringArray()
@export var man_pitch: float = 0.82
@export var woman_pitch: float = 1.28
@export var child_pitch: float = 1.7
@export var teen_pitch: float = 1.12
## Multiplier for elders (age >= 60).
@export var elder_mult: float = 0.92
## Random pitch jitter per syllable (+-) and per person (+-).
@export var syllable_jitter: float = 0.07
@export var person_jitter: float = 0.06
@export var syllable_seconds: float = 0.095
@export var max_syllables: int = 12
@export var volume_db: float = -9.0
@export var max_distance: float = 22.0


func asset_paths() -> PackedStringArray:
	return samples
