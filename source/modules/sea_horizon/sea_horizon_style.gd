class_name SeaHorizonStyle
extends AssetModule
## v6b: blends the pale/grey band between the far sea and the sky. Below the
## horizon on the sea side the sky dome is painted as distant water fading into
## the haze instead of the grey ground colour. Consumer: DayNightCycle (sky shader).

@export var name_fa: String = ""
## 0 = classic grey band, 1 = fully blended
@export var blend: float = 1.0
## distant water (day)
@export var sea_color: Color = Color(0.16, 0.36, 0.55)
## how much of the horizon haze tints the distant water
@export var haze: float = 0.45
## how quickly the horizon haze turns to water below it
@export var sharpness: float = 40.0
## distance haze tinted toward the sky's horizon colour (far sea fades into the sky, no grey strip)
@export var fog_match: float = 0.8
