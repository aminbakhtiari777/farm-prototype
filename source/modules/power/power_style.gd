class_name PowerStyle
extends AssetModule
## Electricity: look of the breaker boxes and what homes use when the power
## is cut (candles, lantern, fireplace). Consumers: PowerGrid autoload,
## BreakerBox, InteriorBuilder (candle props).

@export var box_color: Color = Color(0.62, 0.64, 0.66)
@export var lever_color: Color = Color(0.85, 0.15, 0.1)
@export var fireplace: bool = true
@export var candles_per_home: int = 3
@export var lantern: bool = true
