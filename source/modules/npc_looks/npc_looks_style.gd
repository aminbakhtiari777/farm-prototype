class_name NpcLooksStyle
extends AssetModule
## v6b townspeople looks: every resident gets a stable, distinct face (brows, head
## size, skin tint), hair and body width from their name. Consumer: Townspeople.outfit_for.

@export var name_fa: String = ""
@export var enabled: bool = true
## brow meshes to pick from
@export var brows: Array = []
@export var head_range: Vector2 = Vector2(0.95, 1.05)
@export var width_range: Vector2 = Vector2(0.88, 1.08)
@export var tint_jitter: float = 0.06
@export var hair_women: Array = []
@export var hair_men: Array = []
## for men over 20
@export var beard_chance: float = 0.45
@export var hair_colors: Array = []
## m - name tag + bubble hide when the camera is closer
@export var tag_hide_near: float = 2.4
## name tag + bubble size indoors (gym, shops, homes)
@export var indoor_label_scale: float = 0.55
