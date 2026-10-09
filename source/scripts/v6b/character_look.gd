class_name CharacterLook
extends RefCounted
## v6b "character_creator" module helpers: a player look is a small dictionary
## {name, body, face, hair, hair_color, beard, skin, job, top} of option ids
## (saved with the player). resolve() turns it into HumanoidModelVisual
## properties; apply() rebuilds the visual.

const KEYS := ["body", "face", "hair", "beard", "skin", "job"]


static func style() -> CharacterCreatorStyle:
	return Modules.style("character_creator") as CharacterCreatorStyle


static func options(key: String) -> Array:
	var st := style()
	if st == null:
		return []
	match key:
		"body": return st.bodies
		"face": return st.faces
		"hair": return st.hair
		"beard": return st.beards
		"skin": return st.skins
		"job": return st.jobs
	return []


static func default_look() -> Dictionary:
	var st := style()
	var d: Dictionary = st.default_look.duplicate() if st else {}
	for k in KEYS:
		if not d.has(k):
			var opts := options(k)
			d[k] = str((opts[0] as Dictionary).get("id", "")) if not opts.is_empty() else ""
	if not d.has("hair_color"):
		d["hair_color"] = 2
	return d


static func find(key: String, id: String) -> Dictionary:
	for o: Dictionary in options(key):
		if str(o.get("id", "")) == id:
			return o
	var opts := options(key)
	return opts[0] if not opts.is_empty() else {}


static func index_of(key: String, id: String) -> int:
	var opts := options(key)
	for i in opts.size():
		if str((opts[i] as Dictionary).get("id", "")) == id:
			return i
	return 0


## Next / previous option id for `key` (wraps around).
static func step(look: Dictionary, key: String, dir: int) -> String:
	var opts := options(key)
	if opts.is_empty():
		return ""
	var i := wrapi(index_of(key, str(look.get(key, ""))) + dir, 0, opts.size())
	return str((opts[i] as Dictionary).get("id", ""))


static func label(key: String, id: String) -> String:
	var o := find(key, id)
	return str(o.get("fa", "")) if Lang.is_fa() else str(o.get("en", id))


static func hair_color(look: Dictionary) -> Color:
	var st := style()
	if st == null or st.hair_colors.is_empty():
		return Color(0.32, 0.2, 0.11)
	return st.hair_colors[clampi(int(look.get("hair_color", 0)), 0, st.hair_colors.size() - 1)]


## Visual properties for a look.
static func resolve(look: Dictionary) -> Dictionary:
	var body := find("body", str(look.get("body", "")))
	var face := find("face", str(look.get("face", "")))
	var hair := find("hair", str(look.get("hair", "")))
	var beard := find("beard", str(look.get("beard", "")))
	var skin := find("skin", str(look.get("skin", "")))
	var female := str(body.get("body_type", "male")) == "female"
	var brows := str(face.get("brows", ""))
	if female and brows == "Eyebrows_Regular":
		brows = "Eyebrows_Female"
	var tint: Color = skin.get("tint", Color(1, 1, 1))
	var ftint: Color = face.get("tint", Color(1, 1, 1))
	return {"body_type": "female" if female else "male", "body_width": float(body.get("width", 1.0)),
		"body_height": float(body.get("height", 1.0)), "brows": brows, "head_scale": float(face.get("head", 1.0)),
		"hair_style": str(hair.get("style", "Hair_SimpleParted")), "hair_color": hair_color(look),
		"beard": bool(beard.get("beard", false)) and not female, "skin_tone": int(skin.get("tone", 0)),
		"skin_tint": Color(tint.r * ftint.r, tint.g * ftint.g, tint.b * ftint.b)}


## Applies a look to a humanoid visual (rebuilds it when the body changed).
static func apply(visual: HumanoidModelVisual, look: Dictionary) -> void:
	if visual == null:
		return
	var props := resolve(look)
	for k in props:
		visual.set(k, props[k])
	if look.has("top"):
		visual.top_style = str(look["top"])
	if visual.is_inside_tree():
		visual.rebuild()


static func job(look: Dictionary) -> Dictionary:
	return find("job", str(look.get("job", "")))


## Job uniform colours (shirt, pants, top shape) for the wardrobe default.
static func job_outfit(look: Dictionary) -> Dictionary:
	var j := job(look)
	return {"shirt": j.get("shirt", Color(0.66, 0.24, 0.18)), "pants": j.get("pants", Color(0.2, 0.3, 0.48)), "top": str(j.get("top", "work_shirt"))}


static func random_look(rng: RandomNumberGenerator) -> Dictionary:
	var out := {}
	for k in KEYS:
		var opts := options(k)
		if not opts.is_empty():
			out[k] = str((opts[rng.randi() % opts.size()] as Dictionary).get("id", ""))
	var st := style()
	out["hair_color"] = rng.randi() % maxi(st.hair_colors.size() if st else 1, 1)
	return out
