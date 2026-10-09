class_name QualityStyle
extends AssetModule
## v7b.1 graphics preset (Settings > Graphics: Auto / Low / Medium / High). Every
## perf system reads its numbers from the active preset, so a slow laptop can drop
## to Low (no sun shadows, 75% render scale, shorter view ranges, fewer real
## lights / voices / animated people) without touching any gameplay code.
## Consumers: PerfQuality, AutoLod, WorldStreamer, AudioBudget, AnimBudget,
## TownspersonBot (NPC LOD distances), LampLightPool.

@export var name_fa: String = ""
## 0 low, 1 medium, 2 high
@export var level: int = 1
## 0 off, 1 cheap (2 cascades, shadow_distance), 2 full ShadowRig cascades
@export var sun_shadows: int = 1
## sun shadow max distance (m) for sun_shadows=1
@export var shadow_distance: float = 35.0
## directional shadow map size
@export var shadow_atlas: int = 2048
## objects smaller than this (m) never cast shadows
@export var shadow_min_size: float = 0.9
## 3D resolution scale (UI stays sharp)
@export var render_scale: float = 1.0
## 0 off, 1 2x, 2 4x
@export var msaa: int = 1
## Godot mesh LOD threshold in pixels (higher = simpler meshes sooner)
@export var mesh_lod_threshold: float = 1.0
## multiplier on every auto visibility range
@export var lod_scale: float = 0.85
## multiplier on tree / forest view distance
@export var tree_view_scale: float = 0.85
## multiplier on grass / flower view distance
@export var grass_view_scale: float = 0.8
## cells within this distance (m) are loaded (scripts + physics live)
@export var stream_radius: float = 90.0
## point / spot lights fade out beyond this (m)
@export var light_fade_distance: float = 45.0
## real OmniLights that follow the nearest street lamps
@export var lamp_lights: int = 6
## townspeople drawn within (m)
@export var npc_visible_distance: float = 55.0
## townspeople animated within (m)
@export var npc_anim_distance: float = 38.0
## townspeople cast shadows within (m)
@export var npc_shadow_distance: float = 22.0
## other AnimationPlayers / Trees run within (m)
@export var anim_distance: float = 45.0
## positional sounds playing at once
@export var max_voices: int = 14
## positional sounds pause beyond (m)
@export var audio_distance: float = 70.0
## Auto mode steps down a preset when the average fps stays below this
@export var auto_fps_floor: float = 26.0
## physics interpolation for the player + camera (no judder when fps != 60 Hz physics)
@export var smooth_motion: bool = true
## physics steps allowed per frame (stops the slow-laptop 'spiral' where physics eats the frame)
@export var max_physics_steps: int = 4
## camera catch-up speed (was 12: ~85 ms trailing lag)
@export var camera_follow_speed: float = 20.0
## townspeople beyond npc_visible_distance think every Nth physics tick (schedule-only)
@export var npc_far_tick: int = 4
