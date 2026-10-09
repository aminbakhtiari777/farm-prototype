class_name NpcCardStyle
extends AssetModule
## The name + job card that pops up when you walk up to a townsperson (v5b).
## Consumers: NpcCard (scripts/ui/npc_card.gd).

@export var show_distance: float = 4.0
@export var bg_color: Color = Color(0.98, 0.94, 0.84, 0.95)
@export var ink_color: Color = Color(0.22, 0.16, 0.1)
@export var accent_color: Color = Color(0.75, 0.25, 0.3)
@export var heart_color: Color = Color(0.9, 0.2, 0.3)
@export var show_family: bool = true
@export var show_health: bool = true
