class_name ShadowStyle
extends AssetModule
## v6b realistic sun shadows. Desktop: 4 cascades, soft (PCSS angular size +
## blur), blended cascades. Web: 2 cascades, cheap. Consumer: ShadowRig.

@export var name_fa: String = ""
@export var desktop_splits: Vector3 = Vector3(0.06, 0.18, 0.45)
@export var desktop_distance: float = 90.0
## degrees (soft penumbra)
@export var desktop_angular: float = 0.6
@export var desktop_blur: float = 1.8
@export var blend_splits: bool = true
@export var web_distance: float = 45.0
@export var web_blur: float = 1.2
@export var fade_start: float = 0.85
