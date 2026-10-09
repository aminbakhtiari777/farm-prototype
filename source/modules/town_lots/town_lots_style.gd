class_name TownLotsStyle
extends AssetModule
## v6b slight town expansion: a few new lots at the town edge - a newly built
## house, one under construction and an empty lot for sale (hook for buying
## land later). Consumer: TownLots.

@export var name_fa: String = ""
## {id, pos, yaw, state (built | construction | for_sale), wall, roof, address}
@export var lots: Array = []
