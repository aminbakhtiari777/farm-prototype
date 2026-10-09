class_name GestureStyle
extends AssetModule
## NPC gestures (v5a): townspeople wave at the farmer when they pass nearby
## (procedural arm animation on the shared skeleton - no extra assets).
## Consumers: NpcGestures (scripts/npc/npc_gestures.gd), WaveModifier.

@export var wave_distance: float = 7.0
@export var wave_chance: float = 0.7
@export var wave_seconds: float = 1.8
@export var cooldown: float = 30.0
## Arm raise (radians) and wave speed (Hz).
@export var arm_raise: float = 2.3
@export var wave_speed: float = 2.4
