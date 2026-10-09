class_name ConflictStyle
extends AssetModule
## v7a social conflict: sometimes two townspeople argue - red heated bubbles and
## sharp gestures - over an unpaid debt, a theft report or noise. Hot-tempered
## people argue more. The player can calm them (E: talk it out) or the police
## patrol arrives and settles it. Consumer: Conflicts.

@export var name_fa: String = ""
## reason -> {lines: [{en, fa}], replies: [{en, fa}], calm: {en, fa}}
@export var reasons: Dictionary = {}
## full name -> 0..1 (default 0.3)
@export var tempers: Dictionary = {}
@export var chance_per_hour: float = 0.18
## seconds before police settle it
@export var duration: float = 40.0
## seconds before the patrol is called
@export var police_after: float = 18.0
## friendship points with both for calming
@export var calm_friendship: int = 15
@export var hours: Vector2 = Vector2(9, 21)
