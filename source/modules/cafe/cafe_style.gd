class_name CafeStyle
extends AssetModule
## v7b terrace cafe next to the Cafe: open in the afternoon and evening with a
## bartender and (at night) a DJ whose music is positional. Drinks menu: tea,
## coffee, juices, soft drinks and a couple of 'strong' drinks that make you
## mildly tipsy for a short time (wobbly walk, slightly blurry screen) - the
## bartender stops serving after a limit and driving tipsy is fined. Small
## fights now and then: the bartender or the police break them up; fines go to
## the city fund and the people involved remember. Posts are never empty: if
## the bartender / DJ is away, another resident fills in. Consumer: TerraceCafe.

@export var name_fa: String = ""
@export var pos: Vector2 = Vector2(-25.0, -29.0)
## deg; bar at the back (-z local)
@export var yaw: float = 90.0
## deck size
@export var size: Vector2 = Vector2(11.0, 9.0)
## open (24 = midnight)
@export var hours: Vector2 = Vector2(16.0, 24.0)
@export var dj_hours: Vector2 = Vector2(19.0, 24.0)
## {id, en, fa, price, kind (hot/juice/soft/strong), stamina, hunger, tipsy (s)}
@export var menu: Array = []
## the bartender stops serving strong drinks after this many per day
@export var max_strong: int = 2
## tipsy sway strength
@export var wobble: float = 0.35
## tipsy blur strength 0..1
@export var blur: float = 0.55
## driving while tipsy
@export var dui_fine: int = 120
## per open hour
@export var fight_chance: float = 0.18
## before the bartender steps in
@export var fight_seconds: float = 9.0
## disturbing the peace (each)
@export var fight_fine: int = 40
## role -> [preferred full names...] (bartender, dj)
@export var staff: Dictionary = {}
## DJ tracks
@export var music: PackedStringArray = PackedStringArray()
@export var music_db: float = -4.0
## m
@export var music_range: float = 30.0
## bartender_greet, refuse, dj, fight, breakup, police, standin, closed -> [{en, fa}]
@export var lines: Dictionary = {}
