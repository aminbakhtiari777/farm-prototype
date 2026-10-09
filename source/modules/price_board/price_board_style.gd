class_name PriceBoardStyle
extends AssetModule
## v5c market-prices board (module "price_board"): which goods are listed, the
## look of the board in the market and of the PricesPanel (key B).
## Consumers: PriceBoard (3D board), PricesPanel.

@export var items: PackedStringArray = PackedStringArray()
@export var title_fa: String = "تابلوی قیمت بازار"
@export var title_en: String = "Market prices"
@export var bg_color: Color = Color(0.13, 0.2, 0.16, 0.96)
@export var frame_color: Color = Color(0.45, 0.3, 0.18)
@export var ink_color: Color = Color(0.95, 0.95, 0.9)
@export var up_color: Color = Color(1.0, 0.45, 0.35)
@export var down_color: Color = Color(0.45, 0.9, 0.5)
@export var shortage_color: Color = Color(1.0, 0.3, 0.25)
## Board position in the world (x, z) and facing.
@export var position: Vector2 = Vector2(6.0, -26.0)
@export var yaw_deg: float = 0.0
## Rows written on the 3D board.
@export var board_rows: int = 8
