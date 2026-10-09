#!/usr/bin/env python3
"""v7b.1 weather visuals module (Amin: 'white square pixels falling from the sky'):
  weather_fx   soft_weather (default) / light_weather
Soft round snowflakes (procedural radial-gradient texture, alpha-blended
billboards), thin wind-angled rain streaks + splashes, snow cover that builds
up while it snows, stays a while and melts, wet ground while it rains that
dries slowly. Particle counts per graphics preset (low / medium / high).
Consumer: WeatherFx (scripts/v7b1_weather/weather_fx.gd) via SeasonVisuals.
Re-run after editing, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, config, config_path, V2 = ns["style_script"], ns["emit"], ns["config"], ns["config_path"], ns["V2"]

style_script("weather_fx", "weather_fx_style", "WeatherFxStyle",
    "v7b.1 weather visuals. Snow = soft round flakes (tiny procedural radial\n"
    "gradient texture, alpha blend, billboard, size variety, drift + sway, slow\n"
    "fall); ground / grass / roofs whiten as snow_amount builds up while it snows,\n"
    "stays snow_hold_hours, then melts. Rain = thin semi-transparent streaks\n"
    "angled by the wind + small splashes; the ground darkens / gets glossy with\n"
    "wetness and dries slowly. CPUParticles3D (works the same on the web /\n"
    "Compatibility renderer) in a small box that follows the camera; counts per\n"
    "graphics preset. Consumer: WeatherFx (SeasonVisuals child).", [
    ("enabled", "bool", "true", "false = old v4 particles (not recommended)"),
    ("snow_counts", "Dictionary", '{"low": 240, "medium": 480, "high": 800}', "flakes alive at full snowfall per quality preset"),
    ("rain_counts", "Dictionary", '{"low": 220, "medium": 420, "high": 750}', "streaks alive in a storm per quality preset"),
    ("splash_counts", "Dictionary", '{"low": 0, "medium": 50, "high": 110}', "ground splashes alive (0 = off)"),
    ("box_sizes", "Dictionary", '{"low": 12.0, "medium": 15.0, "high": 18.0}', "m: side of the particle box around the camera (small = dense near the eye)"),
    ("flake_size", "Vector2", "Vector2(0.05, 0.13)", "m: min / max flake diameter"),
    ("snow_fall_speed", "float", "1.0", "m/s"),
    ("snow_sway", "float", "0.45", "side-to-side sway strength"),
    ("snow_height", "float", "6.0", "m above the ground where flakes start (min; camera height + 3 m)"),
    ("rain_length", "float", "0.9", "m streak length"),
    ("rain_width", "float", "0.028", "m streak width"),
    ("rain_alpha", "float", "0.55", "streak opacity"),
    ("rain_speed", "float", "14.0", "m/s"),
    ("rain_wind", "float", "0.18", "horizontal wind / fall speed in rain (storm x2)"),
    ("flurry_intensity", "float", "0.3", "light winter flurries on cloudy winter days (0 = none)"),
    ("accumulate_per_hour", "float", "0.65", "snow_amount gained per game hour of full snowfall"),
    ("max_cover", "float", "1.0", "snow_amount cap"),
    ("snow_hold_hours", "float", "4.0", "game hours the snow stays untouched after it stops"),
    ("melt_per_hour", "Dictionary", '{"winter": 0.04, "other": 0.35}', "snow_amount melted per game hour (x sun factor)"),
    ("wet_per_hour", "float", "2.5", "wetness gained per game hour of rain"),
    ("dry_hold_hours", "float", "0.5", "game hours the ground stays soaked after the rain"),
    ("dry_per_hour", "float", "0.3", "wetness lost per game hour (x sun factor)"),
    ("roof_snow", "bool", "true", "snow overlay on roofs while snowy (1 extra draw per roof, off on Low)"),
    ("splashes", "bool", "true", ""),
])
emit("weather_fx", "WeatherFxStyle", "weather_fx_style", [
    ("soft_weather", "Soft realistic weather", "Round soft snowflakes that settle and melt, visible wind-angled rain that wets the ground.",
     {"name_fa": "آب‌وهوای نرم و واقعی"}),
    ("light_weather", "Light weather (fast)", "Same look with fewer flakes / drops, no splashes, no roof overlay - for slow laptops and phones.",
     {"name_fa": "آب‌وهوای سبک (سریع)", "roof_snow": False,
      "snow_counts": {"low": 160, "medium": 280, "high": 450},
      "rain_counts": {"low": 140, "medium": 240, "high": 400},
      "splash_counts": {"low": 0, "medium": 0, "high": 0}, "splashes": False,
      "box_sizes": {"low": 10.0, "medium": 12.0, "high": 15.0}}),
], "soft_weather")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 weather module written")
