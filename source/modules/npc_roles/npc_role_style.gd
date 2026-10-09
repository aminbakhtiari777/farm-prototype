class_name NpcRoleStyle
extends AssetModule
## v5d groundwork for a player taking over a townsperson's role (module
## "npc_roles"): the server keeps which NPC is player-controlled; clients
## swap that bot's BotController for a network controller (stub - the full
## role play is a later version).
## Consumers: NetServer (claims table), Net, RemoteAvatars.

@export var enabled: bool = true
## Jobs a player may take over ("*" = any resident).
@export var claimable_jobs: PackedStringArray = PackedStringArray(["*"])
## One NPC per player.
@export var max_per_player: int = 1
