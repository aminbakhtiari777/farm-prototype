class_name MosqueStyle
extends AssetModule
## Mosque (v5a): dome, minaret(s), arched windows, prayer hall with carpets and
## a mihrab, and a short, subtle call to prayer (adhan) played from the
## minaret. Volume: Settings "adhan_volume" (0 = off). Consumers: Building
## (MosqueBuilder exterior), InteriorBuilder (prayer hall), AdhanPlayer.

@export var wall_color: Color = Color(0.93, 0.9, 0.82)
@export var dome_color: Color = Color(0.25, 0.55, 0.62)
@export var trim_color: Color = Color(0.2, 0.42, 0.55)
@export var tile_color: Color = Color(0.15, 0.45, 0.6)
@export var minarets: int = 1
@export var minaret_height: float = 15.0
@export var carpet_color: Color = Color(0.55, 0.12, 0.14)
@export var adhan_sound: String = "res://assets/audio/sfx/adhan.ogg"
## Base level (dB) before the player's volume setting; keep it subtle.
@export var adhan_db: float = -10.0
## Hours (0-23) when the call is played.
@export var call_hours: PackedInt32Array = PackedInt32Array()
@export var max_distance: float = 85.0
## v5b dome: "onion" (bulbous, pointed) or "ribbed" (Persian pointed dome
## with ribs), on a drum with arched windows; rib count and drum height.
@export_enum("onion", "ribbed") var dome_shape: String = "onion"
@export var dome_ribs: int = 16
@export var drum_height: float = 1.4
@export var rib_color: Color = Color(0.9, 0.82, 0.45)


func asset_paths() -> PackedStringArray:
	return PackedStringArray([adhan_sound])
