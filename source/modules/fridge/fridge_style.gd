class_name FridgeStyle
extends AssetModule
## v6b openable fridge: the door swings open (E) and the shelves show what is
## stored - your groceries in the farmhouse, food in the townspeople's homes.
## Consumer: FridgeUnit (KitchenBuilder).

@export var name_fa: String = ""
@export var body_color: Color = Color(0.93, 0.94, 0.95)
@export var inside_color: Color = Color(0.97, 0.98, 1.0)
@export var shelves: int = 3
@export var light: bool = true
## ingredient ids shown in townspeople's fridges
@export var npc_items: Array = []
