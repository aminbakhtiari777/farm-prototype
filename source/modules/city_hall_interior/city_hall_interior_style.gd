class_name CityHallInteriorStyle
extends AssetModule
## v7b.1: City Hall is enterable. The outdoor fund board and the market price
## strip are gone; F4 / the fund panel only open inside. Inside: a counter,
## the manager's desk, clerks at their posts and a wall board with the fund
## balance, ledger and public works. Separable so streaming/LOD can load it
## on enter. Consumer: CityHallInterior.

@export var name_fa: String = ""
@export var enabled: bool = true
@export var hide_outdoor_board: bool = true
@export var hide_price_strip: bool = true
@export var f4_only_inside: bool = true
## preferred full names for manager / clerks
@export var staff: Array = []
@export var wall_board: bool = true
