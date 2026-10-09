class_name GasStoveStyle
extends AssetModule
## v6b gas stove: kitchens get a gas hob; while you cook a ring of blue gas
## flames burns under the pan (flickering, with a soft light). Consumers:
## KitchenBuilder (hob), CookingStation (flame).

@export var name_fa: String = ""
@export var force_gas: bool = true
@export var flame_color: Color = Color(0.25, 0.45, 1.0)
@export var tip_color: Color = Color(1.0, 0.7, 0.3)
@export var flame_height: float = 0.1
@export var tongues: int = 14
## burners lit even when not cooking
@export var idle_burners: int = 0
