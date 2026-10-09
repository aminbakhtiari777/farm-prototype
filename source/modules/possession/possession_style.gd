class_name PossessionStyle
extends AssetModule
## v7a play as a townsperson (local, single player): F2 next to a resident takes
## over their body - their name, job, home and memories stay theirs. Free
## choices: dig, demolish their own house with the axe (rebuild cost), start a
## fire. Destructive acts ask for confirmation (Persian dialog) and have
## consequences (fines to the city fund, police, neighbours remember).
## Consumer: Possession.

@export var name_fa: String = ""
## gold the household pays to rebuild a demolished house
@export var rebuild_cost: int = 600
## plus damages
@export var arson_fine: int = 400
## rebuild time
@export var demolish_days: int = 3
## allowed acts: dig, demolish, fire
@export var allow: PackedStringArray = PackedStringArray()
## m to the resident
@export var max_distance: float = 3.0
