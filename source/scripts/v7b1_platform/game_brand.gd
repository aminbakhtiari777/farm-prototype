class_name GameBrand
extends RefCounted
## Single place for the product name / version / icon paths (Zamith / Zamis family).
## Suggested title: مزرعهٔ شهر / Farm Town (configurable in config/server.cfg [brand]).

const ICON_SVG := "res://icon.svg"
const ICON_PNG := "res://assets/icons/icon_512.png"
const VERSION_FILE := "res://data/game_version.json"

static var _cfg: ServerConfig


static func config() -> ServerConfig:
	if _cfg == null:
		_cfg = ServerConfig.load_config()
	return _cfg


static func reload() -> void:
	_cfg = ServerConfig.load_config()


static func title() -> String:
	return config().title()


static func title_fa() -> String:
	return config().title_fa


static func title_en() -> String:
	return config().title_en


static func app_name() -> String:
	return config().app_name


static func version() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--fake-version="):
			return a.trim_prefix("--fake-version=")
	var c := config()
	if FileAccess.file_exists(VERSION_FILE):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_FILE))
		if v is Dictionary and str(v.get("version", "")) != "":
			return str(v["version"])
	return c.game_version


static func build_id() -> String:
	if FileAccess.file_exists(VERSION_FILE):
		var v: Variant = JSON.parse_string(FileAccess.get_file_as_string(VERSION_FILE))
		if v is Dictionary:
			return str(v.get("build", "v7b1"))
	return "v7b1"


static func subtitle() -> String:
	return Lang.pick({
		"fa": "یک شهر کوچک برای کشاورزی، دوستی و زندگی سالم",
		"en": "A small town for farming, friendship and a healthy life",
	})
