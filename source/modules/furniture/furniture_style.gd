class_name FurnitureStyle
extends AssetModule
## Interiors, street props and vehicles (Kenney kits). Consumers:
## InteriorBuilder, Carryable, TownBuilder (applied at build time).

@export_dir var furniture_dir: String = "res://assets/third_party/kenney/furniture/"
@export_dir var food_dir: String = "res://assets/third_party/kenney/food/"
@export_dir var cars_dir: String = "res://assets/third_party/kenney/cars/"
@export var parked_cars: PackedStringArray = []  ## car model names (empty = builder default)


func asset_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for p in [furniture_dir.path_join("bedDouble.glb"), food_dir.path_join("pumpkin.glb")]:
		out.append(p)
	for c in parked_cars:
		out.append(cars_dir.path_join(c + ".glb"))
	return out
