class_name GardenRules
extends AssetModule
## Season hook for planting (v8 replaces/extends this module with real
## season rules). The Garden and the shop ask the ACTIVE rules module:
##   can_plant(crop, season_id)            -> bool
##   growth_multiplier(crop, season, weather) -> float (per watered day)
##   withers(crop, season_id)              -> bool (crop dies at season change)
## Swap to "any_season" for a greenhouse / testing.

@export var use_seasons: bool = true


func can_plant(crop: CropDef, season_id: String) -> bool:
	if crop == null:
		return false
	return not use_seasons or season_id in crop.seasons


func growth_multiplier(crop: CropDef, season_id: String, _weather_id: String) -> float:
	if crop == null:
		return 0.0
	if use_seasons and crop.is_perennial() and season_id == "winter":
		return 0.0  # trees rest in winter
	return 1.0


func withers(crop: CropDef, season_id: String) -> bool:
	if crop == null or not use_seasons:
		return false
	if crop.is_perennial():
		return false  # fruit trees survive the winter
	return not (season_id in crop.seasons)
