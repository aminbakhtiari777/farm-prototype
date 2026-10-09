class_name LodRulesStyle
extends AssetModule
## v7b.1 distance detail rules (AutoLod): every mesh / label / particle without its
## own range gets a visibility range from its size class (x preset lod_scale), small
## things stop casting shadows, point lights fade with distance. New content from
## any module is picked up automatically (SceneTree.node_added).
## Consumers: AutoLod.

@export var name_fa: String = ""
## longest edge (m) below which an object is tiny
@export var tiny_size: float = 0.5
@export var small_size: float = 1.6
@export var medium_size: float = 4.5
## above this: huge (no auto range: terrain, sea, mountains)
@export var large_size: float = 14.0
## visibility range end (m) per class
@export var tiny_range: float = 28.0
@export var small_range: float = 55.0
@export var medium_range: float = 100.0
@export var large_range: float = 190.0
## Label3D signs / plaques
@export var label_range: float = 30.0
## hysteresis (m)
@export var margin: float = 5.0
## cross-fade (prettier, costs alpha blending on the web)
@export var fade: bool = false
## also scale ranges a module already set (by preset lod_scale)
@export var scale_existing: bool = true
