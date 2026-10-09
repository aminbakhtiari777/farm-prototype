class_name PopulationDef
extends AssetModule
## Townsfolk identities (v5a): every resident has a name, surname, age, job,
## workplace, home and family ties; families share a home. Townspeople spawns
## one TownspersonBot per resident (up to max_spawned) and builds each daily
## routine from the job. Consumers: Townspeople, PeoplePanel, NpcSocial.
##
## Resident keys: name, surname, age, gender (female/male), job, work (building
## id or spot), home (building id), family (surname key), role (e.g. "mother"),
## hair, hair_color, shirt, pants, skin, beard, lines.

@export var residents: Array = []
@export var max_spawned: int = 32
## Body scale for children (age < 13) and teens (13-17).
@export var child_scale: float = 0.72
@export var teen_scale: float = 0.9
