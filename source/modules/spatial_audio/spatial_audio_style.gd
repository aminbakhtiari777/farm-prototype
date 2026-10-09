class_name SpatialAudioStyle
extends AssetModule
## v7b.1 spatial audio: an AudioListener3D copies the active camera every frame
## (follow camera, cockpit camera, possessed resident), so every AudioStreamPlayer3D
## is heard from its real position: stereo panning by direction, inverse-distance
## attenuation, a distance low-pass and a muffled low-pass while indoors. New
## emitters are capped (nearest win) on top of the perf audio_budget.
## Consumers: SpatialListener, V7b1AudioWorld.

@export var name_fa: String = ""
@export var enabled: bool = true
## 0 = listener at the camera, 1 = at the player's head (rotation always = camera)
@export var listener_pull: float = 0.3
## per-player panning (x project 3d_panning_strength)
@export var panning_strength: float = 1.6
## far sounds lose their highs (attenuation filter)
@export var distance_cutoff_hz: float = 6000.0
@export var distance_filter_db: float = -18.0
## outdoor emitters heard from inside a building
@export var indoor_cutoff_hz: float = 900.0
@export var indoor_db: float = -8.0
## ambient emitters + one-shots of this workstream playing at once (also <= quality max_voices)
@export var max_voices: int = 10
## pooled one-shot 3D players (steps / doors / gusts / thunder)
@export var pool_size: int = 6
