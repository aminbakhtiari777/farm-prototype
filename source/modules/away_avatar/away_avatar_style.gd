class_name AwayAvatarStyle
extends AssetModule
## v5d disconnected players (module "away_avatar"): the avatar of a player
## who drops out walks home (night) or to the cafe (day) instead of freezing;
## townspeople greet it and bring it tea. On reconnect the player gets a
## "welcome back" toast and townspeople remember the absence.
## Consumers: NetServer (walk + events), RemoteAvatars (visuals + NPC visits), Net, Dialogue memory.

## Hours (game clock) when the avatar goes to the cafe; otherwise home.
@export var cafe_from: float = 8.0
@export var cafe_to: float = 20.0
## TownNav spots used as destinations.
@export var cafe_spot: String = "door:cafe"
@export var home_spot: String = "door:farmhouse"
## Offset (m) from the spot where the avatar sits down.
@export var sit_offset: Vector3 = Vector3(1.2, 0.0, 0.8)
@export var walk_speed: float = 2.2
## Real seconds an away avatar stays in the world before it is removed.
@export var keep_seconds: float = 1800.0
## A townsperson visits the avatar every this many real seconds (greet / tea).
@export var visit_every: float = 12.0
## Every n-th visit brings tea.
@export var tea_every: int = 2
@export var greet_lines: Dictionary = {"fa": ["سلام! چرت می‌زنی؟", "سلام همسایه! خسته نباشی.", "سلام! حالت خوبه؟"], "en": ["Hello! Taking a nap?", "Hi neighbour!", "Hello! All good?"]}
@export var tea_lines: Dictionary = {"fa": ["یه چای داغ برات آوردم", "بفرما چای! تازه دمه."], "en": ["I brought you a hot tea", "Here, fresh tea!"]}
@export var welcome_lines: Dictionary = {"fa": "خوش برگشتی! {minutes} دقیقه نبودی.", "en": "Welcome back! You were away {minutes} min."}
## What townspeople say next time you talk to them after an absence.
@export var remember_lines: Dictionary = {"fa": ["کجا بودی؟ دلمون برات تنگ شده بود!", "خوش برگشتی! جات خالی بود."], "en": ["Where were you? We missed you!", "Welcome back! We kept your seat warm."]}
