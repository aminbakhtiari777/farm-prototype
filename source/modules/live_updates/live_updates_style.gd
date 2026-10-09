class_name LiveUpdatesStyle
extends AssetModule
## v5d live modular updates (module "live_updates"): the server publishes a
## manifest with a version per module type; clients download only changed
## modules, verify (sha256 + sanitizer + load + validate) and swap them in
## through the AssetRegistry - no rebuild. Updates persist in user:// (and
## browser storage on the web) with a rollback to the previous version.
## Consumers: ModuleManifest, Net, NetHud.

@export var enabled: bool = true
## Module types that may be updated live ("*" = all registered types).
@export var allowed_types: PackedStringArray = PackedStringArray(["*"])
## Types that never update live (the update system itself, for safety).
@export var blocked_types: PackedStringArray = PackedStringArray(["live_updates"])
## Largest module file accepted (bytes).
@export var max_file_bytes: int = 262144
## Keep the previous version on disk so a failing update can roll back.
@export var keep_previous: bool = true
## Show a toast / the update list (U panel) when modules change.
@export var notify: bool = true
