class_name NpcLooks
extends RefCounted
## v6b "npc_looks" module: gives every townsperson a stable, distinct face and
## build (eyebrows, head size, body width, a skin-tint shade, hair style and
## colour, beard) derived from their name, on top of the population module's
## outfit. Same name -> same look every time (and on every client).


static func style() -> NpcLooksStyle:
	return Modules.style("npc_looks") as NpcLooksStyle


static func _rand(seed_text: String, salt: String) -> float:
	return float(absi(hash(seed_text + "#" + salt)) % 10000) / 10000.0


static func apply(r: Dictionary, outfit: Dictionary) -> Dictionary:
	var st := style()
	if st == null or not st.enabled:
		return outfit
	var key := str(r.get("name", "")) + str(r.get("surname", ""))
	var out := outfit.duplicate()
	var female := str(outfit.get("body_type", "male")) == "female"
	var age := int(r.get("age", 30))
	if not st.brows.is_empty():
		out["brows"] = "Eyebrows_Female" if female else str(st.brows[int(_rand(key, "brow") * st.brows.size()) % st.brows.size()])
	out["head_scale"] = lerpf(st.head_range.x, st.head_range.y, _rand(key, "head"))
	out["body_width"] = lerpf(st.width_range.x, st.width_range.y, _rand(key, "width")) if age >= 16 else 1.0
	var j := (_rand(key, "tint") - 0.5) * 2.0 * st.tint_jitter
	out["skin_tint"] = Color(1.0 + j, 1.0 + j * 0.9, 1.0 + j * 0.8)
	var pool: Array = st.hair_women if female else st.hair_men
	if not pool.is_empty() and _rand(key, "keep") > 0.35:
		out["hair_style"] = str(pool[int(_rand(key, "hair") * pool.size()) % pool.size()])
	if not female and age < 60 and str(out.get("hair_style", "")) == "":
		out["hair_style"] = "Hair_Buzzed"
	if not st.hair_colors.is_empty() and _rand(key, "hc") > 0.4:
		var c: Color = st.hair_colors[int(_rand(key, "hcol") * st.hair_colors.size()) % st.hair_colors.size()]
		if age >= 55:
			c = c.lerp(Color(0.62, 0.62, 0.64), 0.6)
		out["hair_color"] = c
	if not female and age > 20 and st.beard_chance >= 0.0:
		out["beard"] = _rand(key, "beard") < st.beard_chance
	return out


## Number of distinct (brows, head, width, hair) combinations among residents.
static func distinct_count(residents: Array) -> int:
	var seen := {}
	for r: Dictionary in residents:
		var o := apply(r, Townspeople.outfit_for_base(r))
		seen["%s|%.2f|%.2f|%s|%s" % [o.get("brows", ""), float(o.get("head_scale", 1.0)), float(o.get("body_width", 1.0)), o.get("hair_style", ""), o.get("beard", false)]] = true
	return seen.size()
