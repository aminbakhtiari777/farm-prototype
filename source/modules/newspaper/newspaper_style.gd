class_name NewspaperStyle
extends AssetModule
## v7b local newspaper: every morning a new issue reports what really happened
## in town (WorldMemory + CityState): fires, fines, arguments, outages and
## quakes, public works, cafe fights, rides, market price movers and a weather
## line. Buy it at the newsstand by the square (E) and read it with 4.
## Consumers: Newspaper, NewspaperPanel.

@export var name_fa: String = ""
@export var paper_en: String = "Town Daily"
@export var paper_fa: String = "روزنامه‌ی شهر ما"
@export var stand_pos: Vector2 = Vector2(8.2, -43.2)
@export var price: int = 3
@export var max_items: int = 8
## issues kept
@export var archive: int = 7
## kind -> {en, fa} with {n} {amount} {what} {who} placeholders
@export var templates: Dictionary = {}
## weather id -> {en, fa}
@export var weather: Dictionary = {}
## {en, fa} when nothing happened
@export var quiet: Dictionary = {}
