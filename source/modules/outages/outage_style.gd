class_name OutageStyle
extends AssetModule
## v7a power outages: a storm with strong wind can bring the lines down, and an
## occasional mild earthquake (camera shake, things fall off shelves) can too.
## Homes switch to candles and lanterns (v4 electricity) and life goes on; the
## electricity office crew drives out and fixes it after a few hours.
## Consumer: Outages.

@export var name_fa: String = ""
## per storm day
@export var storm_cut_chance: float = 0.5
## per day
@export var quake_chance: float = 0.06
@export var quake_cut_chance: float = 0.6
@export var quake_seconds: float = 6.0
## m camera shake
@export var quake_strength: float = 0.35
## game hours until the crew restores power
@export var repair_hours: float = 3.0
## tree sway during storms
@export var wind_strength: float = 1.0
## {en, fa}
@export var crew_lines: Array = []
