class_name LivingRoomStyle
extends AssetModule
## v6b living rooms: a bigger flat LCD TV, a sofa you can push to another spot
## (remembered), a folded blanket and cushion by the window to sit on, and
## framed paintings on the walls. Consumer: InteriorV6b.

@export var name_fa: String = ""
@export var lcd_width: float = 1.45
## {colors:[c1,c2,c3], kind}
@export var paintings: Array = []
@export var blanket_colors: Array = []
## offsets (m) along the wall
@export var sofa_slots: Array = []
@export var paintings_per_home: int = 2
