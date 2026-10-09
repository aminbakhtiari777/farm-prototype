class_name CraftingStyle
extends AssetModule
## Farm workshop / crafting (v5a). The shed at the farm with a workbench that
## crafts the "recipes" collection (station "workbench"). Consumers:
## Building (workshop exterior), InteriorBuilder (workshop interior),
## Crafting (rules), CraftingPanel (UI).

@export var wall_color: Color = Color(0.6, 0.44, 0.3)
@export var roof_color: Color = Color(0.36, 0.3, 0.26)
@export var bench_color: Color = Color(0.62, 0.46, 0.3)
## Game minutes that pass per craft (the clock advances).
@export var craft_minutes: float = 20.0
## Stamina used per craft.
@export var stamina_cost: float = 4.0
## Extra workbench props: "tools" (pegboard), "lathe", "anvil".
@export var props: PackedStringArray = PackedStringArray(["tools"])
@export var sawdust: bool = true
