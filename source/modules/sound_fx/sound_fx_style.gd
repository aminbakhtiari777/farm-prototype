class_name SoundFxStyle
extends AssetModule
## v7b.1 sound effects: footsteps that follow the walk / run stride and change
## with the surface (grass, asphalt / plaza, wood floors indoors / pier, sand at the
## beach); residents near the listener get quieter footsteps (the possessed one is
## full volume); every BuildingDoor plays a latch on open and a wooden thud on close
## (the creak stays on open). Consumers: FootstepAudio, DoorAudio.

@export var name_fa: String = ""
@export var footsteps: bool = true
## surface -> {streams: [paths], db, pitch}
@export var surfaces: Dictionary = {}
## louder steps while running
@export var run_db: float = 3.0
@export var npc_footsteps: bool = true
## residents within (m) of the listener have footsteps
@export var npc_radius: float = 11.0
## nearest residents with footsteps
@export var npc_max: int = 3
@export var npc_db: float = -17.0
## m per step
@export var npc_stride: float = 0.75
@export var doors: bool = true
## latch played with the creak when a door opens
@export var door_open: String = ""
## thud played when it shuts (replaces the creak)
@export var door_close: String = ""
@export var door_db: float = -5.0
## doors further than this from the listener stay silent
@export var door_range: float = 32.0
