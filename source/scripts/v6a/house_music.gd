class_name HouseMusic
extends Node3D
## v6a "house_music" module: music playing inside some buildings (cafe, a few
## homes, the gym). Positional AudioStreamPlayer3D with distance falloff; when
## you are outside the building the walls muffle it (quieter + low-pass), a
## bit less when the door is open. Electric: stops in a power cut.

var players: Dictionary = {}  ## building id -> AudioStreamPlayer3D
var _t: float = 0.0


func _ready() -> void:
	add_to_group(&"house_music")
	Modules.on_swap("house_music", self, func(_m: AssetModule) -> void: rebuild())
	Modules.on_swap("gym", self, func(_m: AssetModule) -> void: rebuild())
	rebuild.call_deferred()


func style() -> HouseMusicStyle:
	return Modules.style("house_music") as HouseMusicStyle


func _building(id: String) -> Building:
	for b in get_tree().get_nodes_in_group(&"buildings"):
		if (b as Building).layout_id == id:
			return b
	return null


static func _stream(path: String) -> AudioStream:
	if path == "" or not ResourceLoader.exists(path):
		return null
	var s := load(path) as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	return s


func source_path(id: String) -> String:
	var st := style()
	var path := str(st.sources.get(id, "")) if st else ""
	if id == "gym":
		var gs := Modules.style("gym") as GymStyle
		if gs and gs.music != "" and path != "":
			path = gs.music
	return path


func rebuild() -> void:
	for p in players.values():
		if is_instance_valid(p):
			(p as Node).queue_free()
	players.clear()
	var st := style()
	if st == null:
		return
	for id in st.sources:
		var b := _building(str(id))
		if b == null:
			continue
		var s := _stream(source_path(str(id)))
		if s == null:
			continue
		var ap := AudioStreamPlayer3D.new()
		ap.name = "Music_%s" % id
		ap.stream = s
		ap.unit_size = st.unit_size
		ap.max_distance = st.max_distance
		ap.volume_db = st.volume_db
		ap.attenuation_filter_db = -12.0
		ap.attenuation_filter_cutoff_hz = st.occluded_cutoff_hz
		ap.panning_strength = 0.8
		add_child(ap)
		ap.global_position = b.interior_center() + Vector3(0, 1.4, 0)
		ap.set_meta(&"building", b)
		players[str(id)] = ap
	_update(true)


func is_playing_time() -> bool:
	var st := style()
	if st == null:
		return false
	var h := TimeManager.hours_float()
	return h >= st.hours.x and h < st.hours.y and PowerGrid.power_on


## Occlusion: 0 = open (you're inside), 1 = fully muffled (outside, door shut).
func occlusion_for(id: String) -> float:
	var ap := players.get(id) as AudioStreamPlayer3D
	if ap == null:
		return 1.0
	var b := ap.get_meta(&"building") as Building
	if b == null:
		return 1.0
	var p := get_tree().get_first_node_in_group(&"player") as Node3D
	if p and b.is_point_inside(p.global_position):
		return 0.0
	if b.door and b.door.is_open:
		return 0.55
	return 1.0


func _update(force: bool = false) -> void:
	var st := style()
	if st == null:
		return
	var on := is_playing_time()
	for id in players:
		var ap := players[id] as AudioStreamPlayer3D
		if not is_instance_valid(ap):
			continue
		var occ := occlusion_for(str(id))
		var base := st.volume_db
		if str(id) == "gym":
			var gs := Modules.style("gym") as GymStyle
			if gs:
				base = gs.music_db
		var vol := base + st.occluded_db * occ
		ap.volume_db = vol if force else lerpf(ap.volume_db, vol, 0.5)
		ap.attenuation_filter_cutoff_hz = lerpf(st.open_cutoff_hz, st.occluded_cutoff_hz, occ)
		if on and not ap.playing:
			ap.play(randf() * 4.0)
		elif not on and ap.playing:
			ap.stop()


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.25:
		return
	_t = 0.0
	_update()
