extends Node
## In-game clock, calendar (seasons) and daily weather. Autoload "TimeManager".
##
## Other systems listen to the signals (crops grow on `day_started`, lights
## react to `time_changed`, visuals to `season_changed` / `weather_changed`).
## 1x speed = one in-game day per `real_minutes_per_day_at_1x` real minutes.

signal time_changed(hour: int, minute: int)  ## every in-game minute
signal hour_changed(hour: int, day: int)
signal day_started(day: int)  ## after midnight (or sleeping); weather already rolled
signal season_changed(season_index: int)
signal weather_changed(weather_id: String)
signal settings_changed  ## pause / speed / day-night toggle

const MINUTES_PER_DAY := 1440.0

## Days since the start (1-based). Season and day-of-season derive from it.
var day: int = 1
## Minutes since midnight (float, 0..1440).
var minutes: float = 480.0
var paused: bool = false
## When false the lighting is frozen at midday (the clock keeps running).
var day_night_enabled: bool = true
var speed_presets: Array = [0.5, 1.0, 2.0, 5.0, 10.0]
var speed_index: int = 1
var days_per_season: int = 7
var real_minutes_per_day: float = 12.0
var weather_id: String = "sunny"
var yesterday_weather_id: String = "sunny"

var _last_minute: int = -1
var _last_hour: int = -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cal := GameData.calendar()
	days_per_season = int(cal.get("days_per_season", 7))
	real_minutes_per_day = float(cal.get("real_minutes_per_day_at_1x", 12.0))
	speed_presets = cal.get("speed_presets", speed_presets)
	speed_index = maxi(speed_presets.find(1.0), 0)
	minutes = float(cal.get("start_hour", 8.0)) * 60.0
	weather_id = "sunny"  # day 1 is always fair
	_last_minute = int(minutes)
	_last_hour = hour()


## v6a "real_clock" module: game time follows the device clock (Settings
## "real_clock" or module mode "always"). Pause / speed do not apply then.
var real_clock: bool = false


func _process(delta: float) -> void:
	if real_clock:
		sync_real_clock()
		return
	if paused:
		return
	advance_minutes(delta * game_minutes_per_second())


## Device-clock minute of the day (local time).
static func real_minutes_now() -> float:
	var t := Time.get_time_dict_from_system()
	return float(t.get("hour", 0)) * 60.0 + float(t.get("minute", 0)) + float(t.get("second", 0)) / 60.0


## Moves the game clock forward to the device time (crossing midnight starts a
## new day; a backwards jump of less than 12 h is ignored).
func sync_real_clock(now_minutes: float = -1.0) -> void:
	var target := real_minutes_now() if now_minutes < 0.0 else now_minutes
	var diff := fposmod(target - minutes, MINUTES_PER_DAY)
	if diff > 0.0 and diff < MINUTES_PER_DAY * 0.5:
		advance_minutes(diff)


func set_real_clock(value: bool) -> void:
	real_clock = value
	if value:
		sync_real_clock()
	settings_changed.emit()


## In-game minutes per real second at the current speed.
func game_minutes_per_second() -> float:
	return MINUTES_PER_DAY / (real_minutes_per_day * 60.0) * speed()


func speed() -> float:
	return float(speed_presets[speed_index])


func advance_minutes(amount: float) -> void:
	minutes += amount
	while minutes >= MINUTES_PER_DAY:
		minutes -= MINUTES_PER_DAY
		_new_day()
	_emit_clock()


func _emit_clock() -> void:
	var m := int(minutes)
	if m != _last_minute:
		_last_minute = m
		time_changed.emit(hour(), minute())
		if hour() != _last_hour:
			_last_hour = hour()
			hour_changed.emit(_last_hour, day)


func _new_day() -> void:
	var old_season := season_index()
	day += 1
	_roll_weather()
	if season_index() != old_season:
		season_changed.emit(season_index())
	day_started.emit(day)


func _roll_weather() -> void:
	yesterday_weather_id = weather_id
	var table: Dictionary = GameData.season(season_index()).get("weather", {"sunny": 1.0})
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(day * 7919 + 17)
	var r := rng.randf() * _sum(table.values())
	for id in table:
		r -= float(table[id])
		if r <= 0.0:
			set_weather(id)
			return
	set_weather(table.keys()[0])


func _sum(values: Array) -> float:
	var s := 0.0
	for v in values:
		s += float(v)
	return s


func set_weather(id: String) -> void:
	weather_id = id
	weather_changed.emit(id)


# ------------------------------------------------------------ calendar queries
func hour() -> int:
	return int(minutes / 60.0) % 24


func minute() -> int:
	return int(minutes) % 60


func hours_float() -> float:
	return minutes / 60.0


func season_index() -> int:
	return int((day - 1) / float(days_per_season)) % 4


func season_id() -> String:
	return str(GameData.season(season_index()).get("id", "spring"))


func season_name() -> String:
	return str(GameData.season(season_index()).get("name", "Spring"))


func day_of_season() -> int:
	return (day - 1) % days_per_season + 1


func weather_name() -> String:
	return str(GameData.weather(weather_id).get("name", weather_id.capitalize()))


func clock_text() -> String:
	var h := hour()
	var suffix := "AM" if h < 12 else "PM"
	var h12 := h % 12
	if h12 == 0:
		h12 = 12
	return "%02d:%02d %s" % [h12, minute(), suffix]


func date_text() -> String:
	return "%s %d" % [season_name(), day_of_season()]


func sunrise() -> float:
	return float(GameData.season(season_index()).get("sunrise", 6.0))


func sunset() -> float:
	return float(GameData.season(season_index()).get("sunset", 18.0))


# ------------------------------------------------------------ controls
func set_paused(value: bool) -> void:
	paused = value
	settings_changed.emit()


func toggle_pause() -> void:
	set_paused(not paused)


func set_speed_index(index: int) -> void:
	speed_index = clampi(index, 0, speed_presets.size() - 1)
	settings_changed.emit()


func faster() -> void:
	set_speed_index(speed_index + 1)


func slower() -> void:
	set_speed_index(speed_index - 1)


func set_day_night_enabled(value: bool) -> void:
	day_night_enabled = value
	settings_changed.emit()


func toggle_day_night() -> void:
	set_day_night_enabled(not day_night_enabled)


## Jump to a time of day (hours, e.g. 18.5) on the current day.
func set_time_of_day(hours: float) -> void:
	minutes = clampf(hours * 60.0, 0.0, MINUTES_PER_DAY - 0.01)
	_emit_clock()


## Advance to the next morning (sleeping). Crops grow, weather re-rolls.
func sleep_until_morning(wake_hour: float = 6.0) -> void:
	var target := wake_hour * 60.0
	var amount := (MINUTES_PER_DAY - minutes) + target
	advance_minutes(amount)


## Jump to day 1 of the given season (0..3) keeping the time of day.
func set_season(index: int) -> void:
	var old := season_index()
	var year := int((day - 1) / float(days_per_season * 4))
	var target_day := year * days_per_season * 4 + posmod(index, 4) * days_per_season + 1
	if target_day <= day and posmod(index, 4) != old:
		target_day += days_per_season * 4
	if posmod(index, 4) == old:
		return
	day = target_day
	_roll_weather()
	season_changed.emit(season_index())
	day_started.emit(day)


## Jump straight to a calendar position (demo / tests). Emits the usual signals.
func reset_calendar(new_day: int, hours: float, weather: String = "") -> void:
	var old_season := season_index()
	day = maxi(new_day, 1)
	minutes = clampf(hours * 60.0, 0.0, MINUTES_PER_DAY - 0.01)
	if weather != "":
		yesterday_weather_id = weather
		set_weather(weather)
	else:
		_roll_weather()
	if season_index() != old_season:
		season_changed.emit(season_index())
	_last_minute = -1
	_emit_clock()


func next_season() -> void:
	set_season(season_index() + 1)
