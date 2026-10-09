class_name FamiliesStyle
extends AssetModule
## v7b.1 richer households: some with 4 kids, some with none, newlyweds, young
## couples, elderly couples and a few singles. Every adult has a city job
## (kids at school, elderly retired or light work). Shown on the name card
## and the J directory. Deterministic, saved with the game. Consumer:
## Families (patches Population.residents).

@export var name_fa: String = ""
@export var enabled: bool = true
## [{id, home, kind, members:[{name,surname,age,gender,job,work,role,...}]}]
@export var households: Array = []
## show 'newlyweds' / '4 children' in the J directory
@export var directory_kinds: bool = true
