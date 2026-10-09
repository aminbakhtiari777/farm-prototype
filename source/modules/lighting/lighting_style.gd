class_name LightingStyle
extends AssetModule
## Night lighting (porch lamps, window glow, street lamps) and the
## candle/lantern/firelight used while the power is off.
## Consumer: NightLights (scripts/systems/night_lights.gd), live swap.

@export var bulb_color: Color = Color(1.0, 0.78, 0.48)
@export var window_color: Color = Color(1.0, 0.72, 0.38)
@export var porch_energy: float = 2.4
## Lights switch on this many hours before sunset / off after sunrise.
@export var on_before_sunset_h: float = 0.25
@export var off_after_sunrise_h: float = 0.25
@export var candle_color: Color = Color(1.0, 0.55, 0.2)
@export var candle_energy: float = 1.3
@export_range(0.0, 1.0) var flicker: float = 0.25
