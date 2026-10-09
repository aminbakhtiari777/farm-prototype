class_name AmbienceManager
extends Node
## Layered ambience (non-positional):
##   wind  - always, louder in rain / storm / snow,
##   birds - daytime, not in rain or storm, sparse in winter,
##   crickets - night, spring to autumn only.
## Everything is muffled while the player is inside a building.
## Positional sounds (waves, pond) live in BeachBuilder.

const LAYERS := {
	"wind": "res://assets/audio/ambience/wind_gusts_loop.ogg",
	"birds": "res://assets/audio/ambience/birds_day_loop.ogg",
	"crickets": "res://assets/audio/ambience/crickets_night_loop.ogg",
}
const BASE_DB := {"wind": -15.0, "birds": -13.0, "crickets": -14.0}

var players: Dictionary = {}
var target: Dictionary = {}
## v7b.1 audio: per-layer multiplier on the 2D beds (AmbientEmitters turns the
## birds / crickets beds down because placed 3D emitters now carry them).
var bed_scale: Dictionary = {"wind": 1.0, "birds": 1.0, "crickets": 1.0}
var _indoors: bool = false
var _timer: float = 0.0


func _ready() -> void:
	add_to_group(&"ambience")
	for key: String in LAYERS:
		var stream := load(LAYERS[key]) as AudioStreamOggVorbis
		if stream:
			stream.loop = true
		var p := AudioStreamPlayer.new()
		p.name = key.capitalize()
		p.stream = stream
		p.volume_db = -60.0
		p.autoplay = true
		add_child(p)
		players[key] = p
		target[key] = 0.0
	GameEvents.building_entered.connect(func(_b: Node3D) -> void: _indoors = true)
	GameEvents.building_exited.connect(func(_b: Node3D) -> void: _indoors = false)


func levels() -> Dictionary:
	return target.duplicate()


func _process(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		_timer = 0.5
		_update_targets()
	for key: String in players:
		var p := players[key] as AudioStreamPlayer
		var cur := db_to_linear(p.volume_db) if p.volume_db > -59.0 else 0.0
		var want: float = float(target[key]) * float(bed_scale.get(key, 1.0))
		cur = move_toward(cur, want, delta * 0.25)
		p.volume_db = linear_to_db(maxf(cur, 0.001))
		if not p.playing and want > 0.0:
			p.play()


func _update_targets() -> void:
	var daylight := 1.0
	var dn := get_tree().get_first_node_in_group(&"day_night")
	if dn:
		daylight = float(dn.get("daylight"))
	var w := TimeManager.weather_id
	var season := TimeManager.season_id()
	var wind := 0.55
	match w:
		"storm":
			wind = 1.0
		"rain", "snow":
			wind = 0.8
		"cloudy":
			wind = 0.65
		"heatwave":
			wind = 0.35
	var birds := daylight * (0.0 if w in ["rain", "storm"] else 1.0) * (0.3 if season == "winter" else 1.0)
	var crickets := (1.0 - daylight) * (0.0 if season == "winter" or w in ["storm", "snow"] else 1.0) * (0.55 if w == "rain" else 1.0)
	var indoor := 0.3 if _indoors else 1.0
	target["wind"] = wind * indoor * db_to_linear(BASE_DB["wind"])
	target["birds"] = birds * indoor * db_to_linear(BASE_DB["birds"])
	target["crickets"] = crickets * indoor * db_to_linear(BASE_DB["crickets"])
