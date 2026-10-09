class_name MarketStyle
extends AssetModule
## Central market area (v5a): a paved plaza on Farm Rd with stalls built from
## ONE shared stall mesh drawn through MultiMeshInstance3D (a handful of draw
## calls for every stall). Each stall is a small shop (see `stalls`).
## Consumers: MarketArea (scripts/world/town/market_area.gd), ShopPanel.

@export var paving_color: Color = Color(0.66, 0.6, 0.52)
@export var paving_alt: Color = Color(0.56, 0.5, 0.44)
@export var wood_color: Color = Color(0.5, 0.35, 0.22)
## One canopy colour per stall (cycled).
@export var awning_colors: Array = [Color(0.85, 0.25, 0.22), Color(0.25, 0.45, 0.7)]
@export var striped: bool = true
## Price bonus when selling to a market stall (1.1 = +10%).
@export var sell_bonus: float = 1.1
## Stalls: {id, title, sells: [item ids or "type:x"], buys: ["category:x" / "type:x" / id], legacy (old seed shop)}
@export var stalls: Array = []
@export var bunting: bool = true
