class_name SocialStyle
extends AssetModule
## How townspeople socialise: chats between NPCs (speech bubbles), greeting
## the player, random walks. Consumer: NpcSocial (scripts/npc/npc_social.gd).

@export var chat_distance: float = 3.2
## Chance that two idle NPCs who meet start a chat.
@export_range(0.0, 1.0) var chat_chance: float = 0.6
@export var chat_seconds: float = 7.0
@export var greet_distance: float = 3.5
## Radius of the random strolls in free time.
@export var wander_radius: float = 14.0
@export var lines: PackedStringArray = PackedStringArray()
@export var replies: PackedStringArray = PackedStringArray()
@export var greetings: PackedStringArray = PackedStringArray()
