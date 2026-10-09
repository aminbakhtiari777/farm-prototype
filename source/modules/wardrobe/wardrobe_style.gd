class_name WardrobeStyle
extends AssetModule
## v6b home wardrobe: tops (shape) + colours for shirts and trousers. A wardrobe
## stands in the farmhouse; choices are saved with the player. Consumer: Wardrobe.

@export var name_fa: String = ""
## {id, en, fa}  (shape ids understood by HumanoidModelVisual)
@export var tops: Array = []
@export var shirt_colors: Array = []
@export var pants_colors: Array = []
@export var cabinet_color: Color = Color(0.5, 0.34, 0.2)
