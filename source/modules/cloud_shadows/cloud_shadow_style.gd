class_name CloudShadowStyle
extends AssetModule
## v6b moving cloud shadows: soft dark patches drift over the ground (terrain +
## grass shaders, a global shader parameter - no extra draw calls), following the
## weather (more on cloudy days, none at night). Consumer: CloudShadows.

@export var name_fa: String = ""
@export var strength: float = 0.32
## noise frequency (1/m)
@export var scale: float = 0.012
## m/s
@export var speed: Vector2 = Vector2(1.6, 0.7)
## weather -> 0..1
@export var coverage: Dictionary = {}
@export var web_strength: float = 0.26
