extends Node
## v5b friendship with townspeople (autoload "Friendship", module
## "friendship" / FriendshipStyle). Talking to someone raises it once per game
## day (+ a small bonus for talking on consecutive days); the "slow_burn"
## variant also lowers it for days without a visit. Saved with the game.

signal changed(person: String, points: int, gained: int)

var points: Dictionary = {}  ## "Name Surname" -> int
var last_day: Dictionary = {}  ## "Name Surname" -> day of the last talk
var talks: int = 0


func _ready() -> void:
	TimeManager.day_started.connect(_on_day)


func style() -> FriendshipStyle:
	return Modules.style("friendship") as FriendshipStyle


static func key_of(bot: Node) -> String:
	var r: Dictionary = bot.get("resident") if bot and bot.get("resident") is Dictionary else {}
	if not r.is_empty():
		return Population.full_name(r)
	return str(bot.get("display_name")) if bot else ""


func get_points(key: String) -> int:
	return int(points.get(key, 0))


func level(key: String) -> int:
	var st := style()
	var p := get_points(key)
	var lv := 0
	if st:
		for i in st.level_points.size():
			if p >= st.level_points[i]:
				lv = i
	return lv


func level_name(key: String) -> String:
	var st := style()
	if st == null or st.level_names.is_empty():
		return ""
	return Lang.pick(st.level_names[clampi(level(key), 0, st.level_names.size() - 1)])


## Hearts filled (0..hearts, may be fractional).
func hearts(key: String) -> float:
	var st := style()
	if st == null:
		return 0.0
	return float(get_points(key)) / float(maxi(st.max_points, 1)) * float(st.hearts)


func talked_today(key: String) -> bool:
	return int(last_day.get(key, -1)) == TimeManager.day


## Called when the farmer talks to someone. Returns the points gained (0 if
## you already talked today).
func talk(key: String) -> int:
	var st := style()
	if st == null or key == "":
		return 0
	talks += 1
	if talked_today(key):
		return 0
	var gain := st.points_per_talk
	if int(last_day.get(key, -10)) == TimeManager.day - 1:
		gain += st.streak_bonus
	var before := get_points(key)
	points[key] = mini(before + gain, st.max_points)
	last_day[key] = TimeManager.day
	var got := get_points(key) - before
	changed.emit(key, get_points(key), got)
	return got


## v7a: friendship earned (or lost) by deeds - calming an argument, causing a fire...
func add_points(key: String, amount: int) -> int:
	var st := style()
	if st == null or key == "" or amount == 0:
		return 0
	var before := get_points(key)
	points[key] = clampi(before + amount, 0, st.max_points)
	var got := get_points(key) - before
	changed.emit(key, get_points(key), got)
	return got


func _on_day(day: int) -> void:
	var st := style()
	if st == null or st.decay_per_day <= 0:
		return
	for k in points.keys():
		if int(last_day.get(k, day)) < day - 1 and get_points(k) > 0:
			points[k] = maxi(get_points(k) - st.decay_per_day, 0)
			changed.emit(k, get_points(k), -st.decay_per_day)


func reset() -> void:
	points.clear()
	last_day.clear()
	talks = 0


func to_save() -> Dictionary:
	return {"points": points.duplicate(), "last_day": last_day.duplicate()}


func from_save(d: Dictionary) -> void:
	reset()
	var p: Dictionary = d.get("points", {})
	for k in p:
		points[str(k)] = int(p[k])
	var l: Dictionary = d.get("last_day", {})
	for k in l:
		last_day[str(k)] = int(l[k])
