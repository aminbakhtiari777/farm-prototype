class_name WorldStreamStyle
extends AssetModule
## v7b.1 world streaming: the map is a grid of cells; only cells within the
## preset's stream_radius are live. Far cells are dormant (physics removed,
## scripts / animations / sounds paused, deferred builders freed) and wake up
## progressively, a few per frame inside a time budget, as the player walks or
## drives toward them. Gameplay keeps running on data (WorldMemory, CityState,
## TownLife, fires, traffic). Consumers: WorldStreamer, InteriorStreamer.

@export var name_fa: String = ""
@export var enabled: bool = true
## cell edge (m)
@export var cell_size: float = 32.0
## hysteresis: cells unload at stream_radius + margin
@export var unload_margin: float = 24.0
## max milliseconds per frame spent waking / building cells
@export var budget_ms: float = 2.0
## seconds between cell checks
@export var update_interval: float = 0.25
## seconds of velocity added to the stream centre (build ahead while driving)
@export var lookahead: float = 1.2
## interiors wake within this distance (m) of the player / camera
@export var interior_radius: float = 22.0
## script file names whose nodes are streamed automatically (safe, position-bound)
@export var auto_units: Array = []
