class_name CharacterCreatorStyle
extends AssetModule
## v6b character creator: body shapes (incl. slim), faces, hair, beards, skin tones,
## hair colours and job presets for the player, built from the CC0 Quaternius
## parts in the project. Consumers: CharacterCreator (panel), PlayerLook, HumanoidModelVisual.

@export var name_fa: String = ""
## {id, en, fa, body_type, width, height}
@export var bodies: Array = []
## {id, en, fa, brows, head, tint}
@export var faces: Array = []
## {id, en, fa, style}
@export var hair: Array = []
## {id, en, fa, beard}
@export var beards: Array = []
## {id, en, fa, tone, tint}
@export var skins: Array = []
## Colours
@export var hair_colors: Array = []
## {id, en, fa, shirt, pants, top, perk_en, perk_fa, item, count}
@export var jobs: Array = []
## Look the player starts with
@export var default_look: Dictionary = {}
## Offer the creator the first time a new game starts
@export var open_on_new_game: bool = true
