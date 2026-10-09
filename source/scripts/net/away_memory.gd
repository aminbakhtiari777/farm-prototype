class_name AwayMemory
extends RefCounted
## v5d: townspeople remember that the player was away (module "away_avatar").
## Set on reconnect (Net welcome back); each townsperson mentions it once the
## next time you talk to them, and the ones who visited your avatar say so.

static var away_seconds: float = 0.0
static var since_unix: float = 0.0
static var visitors: Dictionary = {}  ## npc name -> "greet" | "tea"
static var told: Dictionary = {}  ## friendship key -> true


static func remember(seconds: float, visits: Array) -> void:
	away_seconds = seconds
	since_unix = Time.get_unix_time_from_system()
	visitors.clear()
	told.clear()
	for v in visits:
		var n := str((v as Dictionary).get("npc", ""))
		if n != "":
			visitors[n] = "tea" if str(v.get("kind", "")) == "tea" or str(visitors.get(n, "")) == "tea" else "greet"


static func active() -> bool:
	return away_seconds > 0.0


## The line this townsperson says about your absence ("" = nothing / already said).
static func line_for(key: String, display_name: String) -> String:
	if not active() or told.has(key):
		return ""
	told[key] = true
	var st := Modules.style("away_avatar") as AwayAvatarStyle
	if visitors.get(display_name, "") == "tea":
		return Lang.pick({"fa": "وقتی نبودی برات چای آوردم، یادته؟", "en": "I brought you tea while you were away, remember?"})
	if visitors.has(display_name):
		return Lang.pick({"fa": "دیدمت که اونجا نشسته بودی، سلام کردم!", "en": "I saw you sitting there and said hi!"})
	return Lang.pick(st.remember_lines) if st else "Welcome back!"


static func reset() -> void:
	away_seconds = 0.0
	visitors.clear()
	told.clear()
