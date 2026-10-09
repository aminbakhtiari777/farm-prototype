class_name NightSkyStyle
extends AssetModule
## v6a night sky: stars (density / brightness / twinkle), a Milky Way band and
## the moon (size, colour, phase cycle). Consumer: NightSky
## (scripts/v6a/night_sky.gd) -> sky shader uniforms. Live-swappable.

@export var name_fa: String = ""
## 0..1 share of sky cells that hold a star.
@export var star_density: float = 0.02
@export var star_brightness: float = 1.8
@export var twinkle: float = 0.5
@export var milky_way: float = 0.45
@export var moon_size: float = 0.045
@export var moon_color: Color = Color(0.96, 0.95, 0.88)
## Game days for one full moon cycle (new -> full -> new) when the clock is game time.
@export var moon_cycle_days: float = 8.0
## Night light from the moon: energy at full moon (new moon = 25 %).
@export var moonlight_full: float = 0.3
