class_name ResidentLooksStyle
extends AssetModule
## v7b.1 richer faces on top of v6b npc_looks: skin tones, eye/brow/nose/mouth
## tints, beard/mustache options, hijab/scarf for women, height and build, and
## a mild family resemblance (siblings share a hair colour / skin tone seed).
## Deterministic per resident, saved with the game (CharacterLook + population).
## Consumer: ResidentLooks (Townspeople.outfit_for).

@export var name_fa: String = ""
@export var enabled: bool = true
## Color list (light..deep)
@export var skin_tones: Array = []
@export var eye_colors: Array = []
## adult women
@export var hijab_chance: float = 0.55
## men over 25 without a full beard
@export var mustache_chance: float = 0.35
## body_height
@export var height_range: Vector2 = Vector2(0.92, 1.08)
## body_width
@export var build_range: Vector2 = Vector2(0.84, 1.3)
## chance a child inherits the parents' hair / skin
@export var family_share: float = 0.7
@export var hair_women: Array = []
@export var hair_men: Array = []
@export var hijab_colors: Array = []
