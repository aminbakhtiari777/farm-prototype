class_name FontStyle
extends AssetModule
## UI / speech-bubble font (v5b). Must cover Persian/Arabic glyphs: speech
## bubbles, the NPC card, dialogue and toasts can be in Persian (right-to-left,
## shaped by the TextServer). Consumers: Lang (fallback chain for the HUD
## theme + Label3D bubbles + name tags).

@export var regular_path: String = "res://assets/fonts/Vazirmatn-Regular.ttf"
@export var bold_path: String = "res://assets/fonts/Vazirmatn-Bold.ttf"
## Speech bubble size (Label3D font_size) and outline.
@export var bubble_size: int = 44
@export var bubble_outline: int = 12
## Use the bold face for bubbles.
@export var bold_bubbles: bool = false
@export var license: String = "SIL Open Font License 1.1"


func asset_paths() -> PackedStringArray:
	return PackedStringArray([regular_path, bold_path])
