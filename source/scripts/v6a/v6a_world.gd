class_name V6aWorld
extends Node3D
## v6a world features, each its own module node: night sky (stars + moon),
## dry trees, beach campfire, boats, sunbathing beach, house music.

var night_sky: NightSky
var dry_trees: DryTrees
var campfire: BeachCampfire
var boats: Boats
var sunbathing: SunbathingBeach
var house_music: HouseMusic


func _ready() -> void:
	night_sky = NightSky.new()
	night_sky.name = "NightSky"
	add_child(night_sky)
	dry_trees = DryTrees.new()
	dry_trees.name = "DryTrees"
	add_child(dry_trees)
	campfire = BeachCampfire.new()
	campfire.name = "BeachCampfire"
	add_child(campfire)
	boats = Boats.new()
	boats.name = "Boats"
	add_child(boats)
	sunbathing = SunbathingBeach.new()
	sunbathing.name = "SunbathingBeach"
	add_child(sunbathing)
	house_music = HouseMusic.new()
	house_music.name = "HouseMusic"
	add_child(house_music)
