class_name CallPlayer
extends Node3D
## v5a hourly calls: the adhan from the mosque's minaret ("mosque" module,
## MosqueStyle.call_hours / adhan_sound / adhan_db) and the church bells
## ("church" module, ChurchStyle.bell_hours / bell_sound / bell_db). One
## positional AudioStreamPlayer3D, deliberately quiet, with a max distance so
## it is only heard in town. Volume settings "adhan_volume" / "bell_volume"
## (0 = off) scale it. Swapping the module re-reads the style.

@export_enum("mosque", "church") var kind: String = "mosque"

var player: AudioStreamPlayer3D
var plays: int = 0
var last_hour: int = -1


func _ready() -> void:
	player = AudioStreamPlayer3D.new()
	player.name = "Audio"
	player.bus = &"Master"
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.unit_size = 14.0
	add_child(player)
	_place()
	_apply_style()
	TimeManager.hour_changed.connect(_on_hour)
	Settings.changed.connect(func(k: String, _v: Variant) -> void:
		if k == setting_key():
			_apply_volume())
	Modules.on_swap(kind, self, func(_m: Resource) -> void: _apply_style())


func setting_key() -> String:
	return "adhan_volume" if kind == "mosque" else "bell_volume"


func style() -> AssetModule:
	return Modules.style(kind)


## Hours of the day this call plays at.
func hours() -> Array:
	var st := style()
	if st is MosqueStyle:
		return (st as MosqueStyle).call_hours
	if st is ChurchStyle:
		return (st as ChurchStyle).bell_hours
	return []


func base_db() -> float:
	var st := style()
	if st is MosqueStyle:
		return (st as MosqueStyle).adhan_db
	if st is ChurchStyle:
		return (st as ChurchStyle).bell_db
	return -12.0


func _place() -> void:
	var list := TownLayout.buildings_of(kind)
	if list.is_empty():
		return
	var b: Dictionary = list[0]
	var p: Vector2 = b["pos"]
	var h := Terrain.height_at(p.x, p.y)
	position = Vector3(p.x, h + (b["size"] as Vector3).y + 6.0, p.y)


func _apply_style() -> void:
	var st := style()
	var path := ""
	var dist := 85.0
	if st is MosqueStyle:
		path = (st as MosqueStyle).adhan_sound
		dist = (st as MosqueStyle).max_distance
	elif st is ChurchStyle:
		path = (st as ChurchStyle).bell_sound
		dist = (st as ChurchStyle).max_distance
	player.stream = load(path) as AudioStream if path != "" and ResourceLoader.exists(path) else null
	player.max_distance = dist
	_apply_volume()


func volume() -> float:
	return clampf(float(Settings.get_value(setting_key())), 0.0, 1.0)


func _apply_volume() -> void:
	var v := volume()
	player.volume_db = base_db() + (linear_to_db(v) if v > 0.001 else -80.0)


func _on_hour(hour: int, _day: int) -> void:
	if hour in hours():
		play_now(hour)


## Plays the call (if the volume setting isn't 0). Returns true if it started.
func play_now(hour: int = -1) -> bool:
	if player.stream == null or volume() <= 0.001:
		return false
	_apply_volume()
	player.play()
	plays += 1
	last_hour = hour
	return true
