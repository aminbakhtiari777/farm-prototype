class_name WorldMemoryStyle
extends AssetModule
## v6b world memory: what the world remembers - moved boxes and sofas, dug
## holes, dropped items, parked car spots, picked fruit, and what townspeople
## remember about the player (helped, stole, drove past...). Saved with the game
## and synced through the v5d save system. Consumer: WorldMemory (autoload).

@export var name_fa: String = ""
## kinds kept
@export var remember: PackedStringArray = PackedStringArray()
## events per townsperson
@export var npc_memory_max: int = 12
## 0 = never forget
@export var forget_days: int = 0
@export var drop_max: int = 40
