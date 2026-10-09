extends Node
## Player-facing settings (autoload "Settings"), stored in user://settings.cfg
## (IndexedDB on the web): master volume, mute, shadow quality, contextual
## prompts, the one-time "Press F1 for controls" tip, the player's name and
## the voice mute list.

signal changed(key: String, value: Variant)

const PATH := "user://settings.cfg"
const WEB_KEY := "farm_prototype_settings"
const DEFAULTS := {
	"volume": 0.8,
	"muted": false,
	"shadows": true,
	"prompts": true,
	"tip_shown": false,
	"player_name": "",
	"voice_muted": [],
	"camera_invert_y": false,
	"camera_sensitivity": 1.0,
	# v5a: subtle hourly calls (0 = off).
	"adhan_volume": 0.5,
	"bell_volume": 0.5,
	# v5b: dialogue language ("fa" Persian / "en" English) and NPC voice blips.
	"dialogue_language": "fa",
	"npc_voices": true,
	# v5d: online play is opt-in (Online panel, U). Off = single player, no network at all.
	"online_enabled": false,
	"server_url": "",
	"pending_update": {},
	"guest_id": "",
	"guest_token": "",
	# v6a: game time follows the device clock ("real_clock" module).
	"real_clock": false,
	# v7b.1 perf: graphics preset (quality module): auto / low / medium / high.
	"quality": "auto",
	# v7b.1: touch joysticks + buttons ("auto" = on touch screens, "on", "off").
	"touch_controls": "auto",
	"music_volume": 0.7,
}

var values: Dictionary = DEFAULTS.duplicate(true)


func _ready() -> void:
	var cfg := ConfigFile.new()
	var ok := false
	if OS.has_feature("web") and WebStorage.has_item(WEB_KEY):
		ok = cfg.parse(WebStorage.get_item(WEB_KEY)) == OK
	if not ok:
		ok = cfg.load(PATH) == OK
	if ok:
		for k in DEFAULTS:
			values[k] = cfg.get_value("settings", k, DEFAULTS[k])
	_apply_audio()


func get_value(key: String) -> Variant:
	return values.get(key, DEFAULTS.get(key))


func set_value(key: String, value: Variant) -> void:
	values[key] = value
	if key == "volume" or key == "muted":
		_apply_audio()
	save()
	changed.emit(key, value)
	GameEvents.setting_changed.emit(key, value)


func save() -> void:
	var cfg := ConfigFile.new()
	for k in values:
		cfg.set_value("settings", k, values[k])
	cfg.save(PATH)
	if OS.has_feature("web"):
		WebStorage.set_item(WEB_KEY, cfg.encode_to_text())


func _apply_audio() -> void:
	var bus := AudioServer.get_bus_index(&"Master")
	var v: float = values["volume"]
	AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(v, 0.0001)))
	AudioServer.set_bus_mute(bus, bool(values["muted"]) or v <= 0.001)
