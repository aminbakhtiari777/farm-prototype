class_name YardStyle
extends AssetModule
## Fences and railings around house yards (TownBuilder) and the farm garden.

@export_enum("rail", "picket") var kind: String = "rail"
@export var wood_color: Color = Color(0.5, 0.36, 0.22)
@export var height: float = 0.95
@export var post_spacing: float = 1.6
