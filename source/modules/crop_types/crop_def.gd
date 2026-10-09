class_name CropDef
extends AssetModule
## One crop = one module: res://modules/crop_types/<id>/<id>.tres (+ an
## optional custom builder script in the same folder). The garden, the shop,
## the economy and GameData all read crops from these modules, so adding a
## crop = adding one folder + one line in data/asset_modules.json
## ("crop_types" collection). See docs/MODULES.md.
##
## Growth stages (index): 0 planted, 1 growing (sprout), 2 leaves,
## 3 flowers, 4 fruit (harvestable). `stage_days[i]` = days from stage i to
## stage i+1 (4 numbers), so total days to harvest = sum(stage_days).

const STAGES: PackedStringArray = ["planted", "growing", "leaves", "flowers", "fruit"]
## Area (m²) the garden reserves per footprint cell (1.0 m bed width x 0.5 m).
const CELL_AREA := 0.5

## Inventory ids: seed item (bought, planted) and produce item (harvested, sold).
@export var seed_id: String = ""
@export var seed_name: String = ""
@export var produce_id: String = ""
@export var produce_name: String = ""
@export var seasons: PackedStringArray = PackedStringArray(["spring"])
@export var stage_days: PackedFloat32Array = PackedFloat32Array([1.0, 1.0, 1.0, 1.0])
@export var yield_amount: int = 1
@export var seed_price: int = 50
@export var sell_price: int = 60
## Ground the crop occupies: 0.5 m² for small plants, 1 m² for bushes / trees.
@export var footprint_m2: float = 0.5
@export_enum("root", "tuber", "bush", "stalk", "vine", "tree", "palm") var shape: String = "bush"
@export var leaf_color: Color = Color(0.3, 0.5, 0.2)
@export var flower_color: Color = Color(1.0, 0.95, 0.6)
@export var fruit_color: Color = Color(0.9, 0.2, 0.1)
@export var height: float = 0.4
@export var fruit_size: float = 0.06
@export var fruit_count: int = 5
## > 0: perennial (fruit trees). After a harvest it drops back to the
## flowers stage and fruits again after this many days.
@export var regrow_days: float = 0.0
## Optional custom builder (static func build(crop, stage, progress, dead, scale) -> Node3D).
@export var builder: Script


func total_days() -> float:
	var t := 0.0
	for d in stage_days:
		t += d
	return maxf(t, 0.01)


## Stage index (0..4) for a growth value in days.
func stage_at(growth: float) -> int:
	var acc := 0.0
	for i in stage_days.size():
		acc += stage_days[i]
		if growth < acc - 0.001:
			return i
	return STAGES.size() - 1


## 0..1 progress inside the current stage (used for smooth growth).
func stage_progress(growth: float) -> float:
	var acc := 0.0
	for i in stage_days.size():
		if growth < acc + stage_days[i] - 0.001:
			return clampf((growth - acc) / maxf(stage_days[i], 0.01), 0.0, 1.0)
		acc += stage_days[i]
	return 1.0


## Growth value at the start of a stage.
func growth_for_stage(stage: int) -> float:
	var acc := 0.0
	for i in mini(stage, stage_days.size()):
		acc += stage_days[i]
	return acc


## Garden cells (1.0 x 0.5 m each) the crop needs: 1 for 0.5 m², 2 for 1 m².
func cells() -> int:
	return maxi(1, int(ceil(footprint_m2 / CELL_AREA - 0.01)))


func is_perennial() -> bool:
	return regrow_days > 0.0


func build_model(stage: int, progress: float, dead: bool, plant_scale: float = 1.0) -> Node3D:
	if builder != null and builder.has_method(&"build"):
		return builder.call(&"build", self, stage, progress, dead, plant_scale) as Node3D
	return CropModelBuilder.build(self, stage, progress, dead, plant_scale)


func seed_item_id() -> String:
	return seed_id if seed_id != "" else id + "_seeds"


func produce_item_id() -> String:
	return produce_id if produce_id != "" else id


## Shop / inventory entries for this crop (merged into GameData.items()).
func to_items() -> Dictionary:
	return {
		seed_item_id(): {"name": seed_name if seed_name != "" else display_name + " Seeds", "type": "seed", "crop": id, "buy": seed_price},
		produce_item_id(): {"name": produce_name if produce_name != "" else display_name, "type": "produce", "sell": sell_price, "crop_of": id},
	}


## Legacy dictionary view (GameData.crop(id) / Economy use this).
func to_game_data() -> Dictionary:
	return {
		"name": display_name, "seasons": Array(seasons), "days": total_days(), "yield": yield_amount,
		"shape": shape, "footprint": footprint_m2, "cells": cells(), "perennial": is_perennial(),
		"leaf": [leaf_color.r, leaf_color.g, leaf_color.b], "fruit": [fruit_color.r, fruit_color.g, fruit_color.b],
		"fruit_size": fruit_size, "height": height,
	}


func validate() -> PackedStringArray:
	var bad := PackedStringArray()
	if id == "" or display_name == "":
		bad.append("(crop %s: missing id/name)" % resource_path)
	if stage_days.size() != 4:
		bad.append("(crop %s: stage_days needs 4 values)" % id)
	return bad
