extends Node3D
## Drops this node onto the terrain surface when the game starts (not in the editor).

@export var height_offset: float = 0.0


func _ready() -> void:
	if not Engine.is_editor_hint():
		global_position.y = Terrain.height_at(global_position.x, global_position.z) + height_offset
