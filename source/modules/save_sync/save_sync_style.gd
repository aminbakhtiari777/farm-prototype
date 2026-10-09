class_name SaveSyncStyle
extends AssetModule
## v5d save sync (module "save_sync"): while online the save uploads every
## `upload_seconds`; offline play keeps saving locally and syncs on return.
## Conflict rule: each field group carries a timestamp; player groups keep the
## newest copy ("latest_per_group"), shared world groups take the server's.
## Consumers: SaveSync, Net, NetServer.

@export var upload_seconds: float = 5.0
## Groups owned by the player (newest timestamp wins).
@export var player_groups: PackedStringArray = PackedStringArray(["economy", "player", "farm", "animals", "carryables", "needs", "friendship", "ranch", "player_name"])
## Shared world state (the server's copy wins while it has one).
@export var world_groups: PackedStringArray = PackedStringArray(["time", "market"])
## "latest_per_group" or "server_wins" (everything from the server).
@export var player_rule: String = "latest_per_group"
## Server keeps this many old saves per player (backup ring).
@export var server_backups: int = 3
