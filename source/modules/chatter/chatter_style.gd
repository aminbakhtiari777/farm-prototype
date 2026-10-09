class_name ChatterStyle
extends AssetModule
## v7b chattier town: townspeople make small spontaneous remarks, react to what
## happens (fires, outages, weather, fines, public works, cafe fights, your
## driving / horn / passengers) and have short back-and-forth chats you can
## overhear. Small unobtrusive bubbles (Persian by default) and an optional
## chat log (key 5). Consumers: Chatter, ChatLogPanel.

@export var name_fa: String = ""
## seconds between spontaneous remarks near you
@export var remark_interval: Vector2 = Vector2(22.0, 45.0)
## seconds between overheard chats
@export var overhear_interval: Vector2 = Vector2(35.0, 70.0)
## m: who can remark / be overheard
@export var hear_radius: float = 18.0
## small chatter bubble font size
@export var bubble_font: int = 34
@export var bubble_seconds: float = 3.6
## chance someone nearby reacts to an event
@export var react_chance: float = 0.85
## kind -> [{en, fa}] (idle_morning, idle_evening, rain, storm, snow, heatwave, sunny, fire, outage, power_back, quake, project, project_done, fine, argument, cafe_fight, player_fast, player_horn, player_possess, passenger, newspaper, camping, night_no_lights)
@export var remarks: Dictionary = {}
## [{topic, lines: [{en, fa}...]}] spoken alternately by two people
@export var dialogues: Array = []
## lines kept in the chat log
@export var log_size: int = 40
## chat log visible at start
@export var log_default: bool = false
