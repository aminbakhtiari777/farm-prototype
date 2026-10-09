class_name ChatStyle
extends AssetModule
## v5d text chat (module "chat"): server-relayed, rate-limited.
## Consumers: NetServer (limits), NetHud (chat box + log), RemoteAvatars (bubbles).

@export var max_length: int = 200
## At most `rate_count` messages per `rate_window` seconds per player.
@export var rate_count: int = 5
@export var rate_window: float = 10.0
## Lines kept in the on-screen log and seconds a line stays fully visible.
@export var log_lines: int = 8
@export var line_seconds: float = 12.0
## Speech bubble over the sender's head (s, 0 = off).
@export var bubble_seconds: float = 6.0
## Simple word filter (lower-case substrings replaced with ***).
@export var blocked_words: PackedStringArray = PackedStringArray()
