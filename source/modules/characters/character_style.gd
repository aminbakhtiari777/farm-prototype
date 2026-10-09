class_name CharacterStyle
extends AssetModule
## Humanoid characters (player + townspeople): rigged models, skins,
## animation library, hair and the outfit shader. Consumer:
## HumanoidModelVisual (applied when a character is created).

@export var models: Dictionary = {}  ## body type -> .gltf path
@export var skins: Dictionary = {}  ## body type -> [light, dark] texture paths
@export var animation_library: String = ""
@export_dir var hair_dir: String = ""
@export var outfit_shader: String = "res://assets/shaders/humanoid_outfit.gdshader"
@export var body_scale: float = 0.96


func asset_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for k in models:
		out.append(str(models[k]))
	for k in skins:
		for p in skins[k]:
			out.append(str(p))
	out.append(animation_library)
	out.append(outfit_shader)
	return out
