class_name KitchenStyle
extends AssetModule
## Kitchen + stove in every home (v5a): counter run with sink, stove (electric
## / gas / wood), range hood, upper cabinets and pots. The stove cooks the
## "stove" recipes (meals restore stamina). An electric stove needs power (v4
## electricity module); gas and wood stoves always work.
## Consumers: KitchenBuilder (scripts/world/interior/kitchen_builder.gd),
## InteriorItem ("stove"), Crafting.

@export_enum("electric", "gas", "wood") var stove: String = "electric"
@export var cabinet_color: Color = Color(0.86, 0.86, 0.82)
@export var counter_color: Color = Color(0.3, 0.3, 0.32)
@export var stove_color: Color = Color(0.9, 0.9, 0.9)
@export var hood: bool = true
@export var upper_cabinets: bool = true
@export var sink: bool = true
@export var pots: bool = true


func needs_power() -> bool:
	return stove == "electric"
