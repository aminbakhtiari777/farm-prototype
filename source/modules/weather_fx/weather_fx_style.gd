class_name WeatherFxStyle
extends AssetModule
## v7b.1 weather visuals. Snow = soft round flakes (tiny procedural radial
## gradient texture, alpha blend, billboard, size variety, drift + sway, slow
## fall); ground / grass / roofs whiten as snow_amount builds up while it snows,
## stays snow_hold_hours, then melts. Rain = thin semi-transparent streaks
## angled by the wind + small splashes; the ground darkens / gets glossy with
## wetness and dries slowly. CPUParticles3D (works the same on the web /
## Compatibility renderer) in a small box that follows the camera; counts per
## graphics preset. Consumer: WeatherFx (SeasonVisuals child).

@export var name_fa: String = ""
## false = old v4 particles (not recommended)
@export var enabled: bool = true
## flakes alive at full snowfall per quality preset
@export var snow_counts: Dictionary = {"low": 240, "medium": 480, "high": 800}
## streaks alive in a storm per quality preset
@export var rain_counts: Dictionary = {"low": 220, "medium": 420, "high": 750}
## ground splashes alive (0 = off)
@export var splash_counts: Dictionary = {"low": 0, "medium": 50, "high": 110}
## m: side of the particle box around the camera (small = dense near the eye)
@export var box_sizes: Dictionary = {"low": 12.0, "medium": 15.0, "high": 18.0}
## m: min / max flake diameter
@export var flake_size: Vector2 = Vector2(0.05, 0.13)
## m/s
@export var snow_fall_speed: float = 1.0
## side-to-side sway strength
@export var snow_sway: float = 0.45
## m above the ground where flakes start (min; camera height + 3 m)
@export var snow_height: float = 6.0
## m streak length
@export var rain_length: float = 0.9
## m streak width
@export var rain_width: float = 0.028
## streak opacity
@export var rain_alpha: float = 0.55
## m/s
@export var rain_speed: float = 14.0
## horizontal wind / fall speed in rain (storm x2)
@export var rain_wind: float = 0.18
## light winter flurries on cloudy winter days (0 = none)
@export var flurry_intensity: float = 0.3
## snow_amount gained per game hour of full snowfall
@export var accumulate_per_hour: float = 0.65
## snow_amount cap
@export var max_cover: float = 1.0
## game hours the snow stays untouched after it stops
@export var snow_hold_hours: float = 4.0
## snow_amount melted per game hour (x sun factor)
@export var melt_per_hour: Dictionary = {"winter": 0.04, "other": 0.35}
## wetness gained per game hour of rain
@export var wet_per_hour: float = 2.5
## game hours the ground stays soaked after the rain
@export var dry_hold_hours: float = 0.5
## wetness lost per game hour (x sun factor)
@export var dry_per_hour: float = 0.3
## snow overlay on roofs while snowy (1 extra draw per roof, off on Low)
@export var roof_snow: bool = true
@export var splashes: bool = true
