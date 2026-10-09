class_name ServerConfig
extends RefCounted
## Loads multiplayer / update / brand settings from config/server.cfg with
## overrides: env FARM_SERVER_HOST|PORT|TLS|HEALTH_PORT → user://server.cfg →
## in-game Settings "server_url". Placeholders never auto-connect.

const RES_PATH := "res://config/server.cfg"
const USER_PATH := "user://server.cfg"
const PLACEHOLDER_HOST := "YOUR_SERVER_HOST"

var host: String = PLACEHOLDER_HOST
var port: int = 9080
var tls: bool = false
var path: String = ""
var max_per_room: int = 6
var max_players_total: int = 24
var health_port: int = 9081
var heartbeat_sec: float = 20.0
var heartbeat_timeout_sec: float = 60.0
var game_version: String = "7.1.0"
var compat_prefix: String = "7.1."
var manifest_url: String = ""
var packs_base_url: String = ""
var title_fa: String = "مزرعهٔ شهر"
var title_en: String = "Farm Town"
var app_name: String = "FarmTown"
var android_package: String = "ir.zamith.farmtown"
var ios_bundle: String = "ir.zamith.farmtown"
var macos_bundle: String = "ir.zamith.FarmTown"
var github_url: String = "https://github.com/aminbakhtiari777"
var linkedin_url: String = "YOUR_LINKEDIN_URL"
## v7b.1 LOCALNET: which server the lobby uses — "main" ([server]) or
## "local_network" ([local_network], home Wi-Fi). Picked per device in the lobby,
## stored in user://server.cfg [client] profile. Default "main".
const PROFILE_MAIN := "main"
const PROFILE_LOCAL := "local_network"
var profile: String = PROFILE_MAIN
var label_fa: String = ""
var label_en: String = ""


static func load_config() -> ServerConfig:
	var c := ServerConfig.new()
	c._apply_file(RES_PATH)
	c._apply_file(USER_PATH)
	c._apply_env()
	return c


## Home Wi-Fi server: config/server.cfg [local_network] (user://server.cfg may
## override the same section). Shared keys (heartbeat, version, brand, room caps)
## come from load_config(). null when the section / host is missing.
static func local_network() -> ServerConfig:
	var c := load_config()
	var found := false
	for p in [RES_PATH, USER_PATH]:
		if not FileAccess.file_exists(p):
			continue
		var cfg := ConfigFile.new()
		if cfg.load(p) != OK or not cfg.has_section(PROFILE_LOCAL):
			continue
		found = true
		c.host = str(cfg.get_value(PROFILE_LOCAL, "host", c.host))
		c.port = int(cfg.get_value(PROFILE_LOCAL, "port", 9080))
		c.health_port = int(cfg.get_value(PROFILE_LOCAL, "health_port", 9081))
		c.tls = bool(cfg.get_value(PROFILE_LOCAL, "tls", false))
		c.path = str(cfg.get_value(PROFILE_LOCAL, "path", ""))
		c.label_fa = str(cfg.get_value(PROFILE_LOCAL, "label_fa", "شبکهٔ خانگی"))
		c.label_en = str(cfg.get_value(PROFILE_LOCAL, "label_en", "Local network"))
	if not found:
		return null
	c.profile = PROFILE_LOCAL
	return c


## Profile picked in the lobby ("main" unless the player chose local_network).
static func selected_profile() -> String:
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(USER_PATH) and cfg.load(USER_PATH) == OK:
		return str(cfg.get_value("client", "profile", PROFILE_MAIN))
	return PROFILE_MAIN


static func set_profile(p: String) -> int:
	var cfg := ConfigFile.new()
	cfg.load(USER_PATH)
	cfg.set_value("client", "profile", PROFILE_LOCAL if p == PROFILE_LOCAL else PROFILE_MAIN)
	return cfg.save(USER_PATH)


## Config the lobby / player counter should use: local_network() when picked,
## otherwise exactly load_config() (main behaviour unchanged).
static func load_active() -> ServerConfig:
	if selected_profile() == PROFILE_LOCAL:
		var l := local_network()
		if l != null:
			return l
	return load_config()


## "Local network (192.168.1.57:9080)" / Persian.
func display_label() -> String:
	var name_: String = (label_fa if Lang.is_fa() else label_en) if label_fa != "" else ("سرور اصلی" if Lang.is_fa() else "Main server")
	if is_placeholder():
		return name_
	return "%s (%s:%d)" % [name_, host.strip_edges(), port]


func _apply_file(p: String) -> void:
	if not FileAccess.file_exists(p):
		return
	var cfg := ConfigFile.new()
	if cfg.load(p) != OK:
		return
	host = str(cfg.get_value("server", "host", host))
	port = int(cfg.get_value("server", "port", port))
	tls = bool(cfg.get_value("server", "tls", tls))
	path = str(cfg.get_value("server", "path", path))
	max_per_room = int(cfg.get_value("server", "max_per_room", max_per_room))
	max_players_total = int(cfg.get_value("server", "max_players_total", max_players_total))
	health_port = int(cfg.get_value("server", "health_port", health_port))
	heartbeat_sec = float(cfg.get_value("server", "heartbeat_sec", heartbeat_sec))
	heartbeat_timeout_sec = float(cfg.get_value("server", "heartbeat_timeout_sec", heartbeat_timeout_sec))
	game_version = str(cfg.get_value("server", "game_version", game_version))
	compat_prefix = str(cfg.get_value("server", "compat_prefix", compat_prefix))
	manifest_url = str(cfg.get_value("updates", "manifest_url", manifest_url))
	packs_base_url = str(cfg.get_value("updates", "packs_base_url", packs_base_url))
	title_fa = str(cfg.get_value("brand", "title_fa", title_fa))
	title_en = str(cfg.get_value("brand", "title_en", title_en))
	app_name = str(cfg.get_value("brand", "app_name", app_name))
	android_package = str(cfg.get_value("brand", "android_package", android_package))
	ios_bundle = str(cfg.get_value("brand", "ios_bundle", ios_bundle))
	macos_bundle = str(cfg.get_value("brand", "macos_bundle", macos_bundle))
	github_url = str(cfg.get_value("brand", "github_url", github_url))
	linkedin_url = str(cfg.get_value("brand", "linkedin_url", linkedin_url))


func _apply_env() -> void:
	var h := OS.get_environment("FARM_SERVER_HOST")
	if h != "":
		host = h
	var p := OS.get_environment("FARM_SERVER_PORT")
	if p != "":
		port = int(p)
	var t := OS.get_environment("FARM_SERVER_TLS")
	if t != "":
		tls = t.to_lower() in ["1", "true", "yes", "on"]
	var hp := OS.get_environment("FARM_SERVER_HEALTH_PORT")
	if hp != "":
		health_port = int(hp)


func is_placeholder() -> bool:
	var h := host.strip_edges()
	return h == "" or h == PLACEHOLDER_HOST or h.begins_with("YOUR_")


## Build ws(s)://host:port/path from config (empty if placeholder).
func health_http_url() -> String:
	if is_placeholder():
		return ""
	var scheme := "https" if tls else "http"
	return "%s://%s:%d/health" % [scheme, host.strip_edges(), health_port]


func is_social_ready(url: String) -> bool:
	var u := url.strip_edges()
	return u != "" and not u.begins_with("YOUR_") and (u.begins_with("http://") or u.begins_with("https://"))


func websocket_url() -> String:
	if is_placeholder():
		return ""
	var scheme := "wss" if tls else "ws"
	var p := path.strip_edges()
	if p != "" and not p.begins_with("/"):
		p = "/" + p
	return "%s://%s:%d%s" % [scheme, host.strip_edges(), port, p]


## Prefer Settings.server_url when the player typed one; else config URL.
func resolve_client_url() -> String:
	if profile == PROFILE_LOCAL:
		return websocket_url()  # home Wi-Fi pick wins over an old typed server_url
	var typed := str(Settings.get_value("server_url")).strip_edges()
	if typed != "" and (typed.begins_with("ws://") or typed.begins_with("wss://")):
		return typed
	return websocket_url()


func title() -> String:
	return title_fa if Lang.is_fa() else title_en


func versions_compatible(client_ver: String) -> bool:
	var v := client_ver.strip_edges()
	if v == game_version:
		return true
	if compat_prefix != "" and v.begins_with(compat_prefix):
		return true
	return false


func to_dict() -> Dictionary:
	return {
		"host": host, "port": port, "tls": tls, "path": path,
		"max_per_room": max_per_room, "max_players_total": max_players_total,
		"health_port": health_port, "heartbeat_sec": heartbeat_sec,
		"heartbeat_timeout_sec": heartbeat_timeout_sec,
		"game_version": game_version, "compat_prefix": compat_prefix,
		"manifest_url": manifest_url, "packs_base_url": packs_base_url,
		"title_fa": title_fa, "title_en": title_en, "app_name": app_name,
		"placeholder": is_placeholder(), "ws_url": websocket_url(),
	}
