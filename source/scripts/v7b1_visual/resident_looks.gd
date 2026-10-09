class_name ResidentLooks
extends RefCounted
## v7b.1 "resident_looks" module: on top of the v6b npc_looks module, every
## resident gets a skin tone from the module palette (children inherit a blend
## of their parents' tones and hair colour = family resemblance), a height and
## build, and face features: hijab / headscarf (hair hidden), moustache,
## glasses, an old man's flat cap. Everything is derived from the resident's
## name (deterministic on every client) and written into the save game
## ("resident_looks"); a saved look wins over the derived one, so a later
## module tweak never changes the face of someone you already know.
## The features are small procedural meshes on the "Head" bone, modelled in
## body space like the Quaternius hair (see attach_features).

static var _saved: Dictionary = {}   ## full name -> compact look (from the save)

## Head centre / radius / face-front z in body space per body type (metres,
## before the model's body_scale), measured from the Quaternius bodies:
## male Head bone 1.60, eyes 1.684-1.714 (z 0.081), brows z 0.094, crown 1.81;
## female Head bone 1.55, eyes 1.64-1.673 (z 0.075), brows z 0.092, crown 1.767.
const HEAD := {
	"male": {"c": Vector3(0.0, 1.695, -0.01), "r": 0.1, "front": 0.095},
	"female": {"c": Vector3(0.0, 1.652, -0.012), "r": 0.095, "front": 0.09},
}


static func style() -> ResidentLooksStyle:
	return Modules.style("resident_looks") as ResidentLooksStyle


static func _rand(key: String, salt: String) -> float:
	return float(absi(hash(key + "#v7b1#" + salt)) % 10000) / 10000.0


static func key_of(r: Dictionary) -> String:
	return "%s %s" % [str(r.get("name", "")), str(r.get("surname", ""))]


static func _is_child(r: Dictionary) -> bool:
	return str(r.get("role", "")) in ["son", "daughter"] and int(r.get("age", 30)) < 30


## Parents of a child in the same household ([] for adults).
static func parents_of(r: Dictionary) -> Array:
	if not _is_child(r):
		return []
	var out: Array = []
	for o: Dictionary in Population.residents():
		if str(o.get("family", "")) == str(r.get("family", "")) and str(o.get("home", "")) == str(r.get("home", "")) \
				and str(o.get("role", "")) in ["father", "mother", "husband", "wife"]:
			out.append(o)
	return out


## Skin tone as a 0..n-1 float index into the palette (children: a blend of parents).
static func tone_value(r: Dictionary) -> float:
	var st := style()
	var n := st.skin_tones.size() if st else 5
	var key := key_of(r)
	var par := parents_of(r)
	if par.size() >= 1 and st:
		var a := tone_value(par[0])
		var b := tone_value(par[par.size() - 1])
		var mix := lerpf(a, b, _rand(key, "mix"))
		# Family share: how much of the parents' tone the child keeps.
		var own := float(int(_rand(key, "tone") * n) % n)
		return clampf(lerpf(own, mix, st.family_share), 0.0, float(n - 1))
	# Adults: most townspeople in the middle of the palette, a few lighter / darker.
	var u := _rand(key, "tone")
	var i := 1.0 if u < 0.32 else (2.0 if u < 0.62 else (0.0 if u < 0.78 else (3.0 if u < 0.92 else 4.0)))
	return minf(i, float(n - 1))


static func tone_color(v: float) -> Color:
	var st := style()
	if st == null or st.skin_tones.is_empty():
		return Color(0.9, 0.72, 0.58)
	var lo := int(floor(v))
	var hi := mini(lo + 1, st.skin_tones.size() - 1)
	return (st.skin_tones[lo] as Color).lerp(st.skin_tones[hi] as Color, v - float(lo))


## Palette colour -> multiplier for the skin texture (the textures are mid tones).
static func tint_for(c: Color) -> Color:
	return Color(clampf(c.r / 0.86, 0.5, 1.12), clampf(c.g / 0.68, 0.45, 1.16), clampf(c.b / 0.54, 0.4, 1.2))


## The derived (deterministic) look of a resident.
static func derive(r: Dictionary) -> Dictionary:
	var st := style()
	var key := key_of(r)
	var age := int(r.get("age", 30))
	var female := str(r.get("gender", "")) == "female"
	var look := {"tone": snappedf(tone_value(r), 0.01)}
	if age >= 18:
		look["h"] = snappedf(lerpf(st.height_range.x, st.height_range.y, _rand(key, "height")) * (0.97 if female else 1.0) * (0.98 if age >= 65 else 1.0), 0.001)
		look["w"] = snappedf(lerpf(st.build_range.x, st.build_range.y, _rand(key, "build")) * (1.04 if age >= 50 else 1.0), 0.001)
	else:
		look["h"] = 1.0
		look["w"] = 1.0
	var chance := st.hijab_chance + (0.25 if age >= 55 else 0.0)
	look["hijab"] = female and age >= 14 and _rand(key, "hijab") < chance
	if look["hijab"] and not st.hijab_colors.is_empty():
		look["hc"] = int(_rand(key, "hijab_col") * st.hijab_colors.size()) % st.hijab_colors.size()
	look["moustache"] = not female and age >= 18 and not bool(r.get("beard", false)) and _rand(key, "moustache") < st.mustache_chance
	look["glasses"] = age >= 10 and _rand(key, "glasses") < (0.45 if age >= 45 else 0.12)
	look["cap"] = not female and age >= 60 and _rand(key, "cap") < 0.6
	# Hair colour: children take the darker parent's hair.
	var par := parents_of(r)
	if not par.is_empty():
		var pr: Dictionary = par[0]
		var po := NpcLooks.apply(pr, Townspeople.outfit_for_base(pr))
		var pc: Color = po.get("hair_color", pr.get("hair_color", Color(0.1, 0.07, 0.05)))
		look["hair"] = [snappedf(pc.r, 0.01), snappedf(pc.g, 0.01), snappedf(pc.b, 0.01)]
	return look


static func look_of(r: Dictionary) -> Dictionary:
	var k := key_of(r)
	if _saved.has(k) and _saved[k] is Dictionary:
		return _saved[k]
	return derive(r)


## Hook from Townspeople.outfit_for: adds the look to the outfit dictionary.
## Keys HumanoidModelVisual knows (skin_tint, skin_tone, body_height, body_width,
## hair_style, hair_color) are applied by the bot; the v7b1_* keys are read by
## attach_features.
static func apply(r: Dictionary, outfit: Dictionary) -> Dictionary:
	var st := style()
	if st == null or not st.enabled:
		return outfit
	var out := outfit.duplicate()
	var look := look_of(r)
	var tone := float(look.get("tone", 1.0))
	out["skin_tone"] = 1 if tone >= 2.5 else 0
	var base := tone_color(tone)
	# The "dark" skin texture is already darker: lift the tint so it isn't doubled.
	var tint := tint_for(base)
	if tone >= 2.5:
		tint = tint.lerp(Color(1, 1, 1), 0.45)
	out["skin_tint"] = tint
	out["body_height"] = float(look.get("h", 1.0))
	out["body_width"] = float(out.get("body_width", 1.0)) * float(look.get("w", 1.0))
	if look.has("hair") and look["hair"] is Array and (look["hair"] as Array).size() == 3:
		var a: Array = look["hair"]
		out["hair_color"] = Color(float(a[0]), float(a[1]), float(a[2]))
	if bool(look.get("hijab", false)):
		out["hair_style"] = ""
		out["v7b1_hijab"] = true
		out["v7b1_hijab_color"] = st.hijab_colors[int(look.get("hc", 0)) % st.hijab_colors.size()] if not st.hijab_colors.is_empty() else Color(0.12, 0.12, 0.14)
	out["v7b1_moustache"] = bool(look.get("moustache", false))
	out["v7b1_glasses"] = bool(look.get("glasses", false))
	out["v7b1_cap"] = bool(look.get("cap", false))
	if bool(look.get("cap", false)):
		out["hair_style"] = ""
	out["v7b1_tone"] = tone
	return out


## Distinct looks among residents (tone, height, build, hijab, glasses, ...).
static func distinct_count(residents: Array) -> int:
	var seen := {}
	for r: Dictionary in residents:
		var o := apply(r, NpcLooks.apply(r, Townspeople.outfit_for_base(r)))
		seen["%.1f|%.2f|%.2f|%s|%s|%s|%s|%s|%s" % [float(o.get("v7b1_tone", 0)), float(o.get("body_height", 1)), float(o.get("body_width", 1)),
			o.get("hair_style", ""), o.get("v7b1_hijab", false), o.get("v7b1_glasses", false), o.get("v7b1_moustache", false),
			o.get("beard", false), o.get("brows", "")]] = true
	return seen.size()


# ------------------------------------------------------------------ save game
static func to_save() -> Dictionary:
	var looks := {}
	for r: Dictionary in Population.residents():
		looks[key_of(r)] = look_of(r)
	return {"v": 1, "looks": looks}


static func from_save(d: Variant) -> void:
	if not d is Dictionary:
		return
	var looks: Variant = (d as Dictionary).get("looks", {})
	if looks is Dictionary:
		_saved = (looks as Dictionary).duplicate(true)


static func clear_saved() -> void:
	_saved.clear()


# ------------------------------------------------------------------ face features
static func _mat(c: Color, both_sides: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.85
	if both_sides:
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


## Adds hijab / moustache / glasses / cap meshes to a built humanoid (bot.visual).
## Returns the holder node (or null when there is nothing to add).
static func attach_features(visual: Node3D, outfit: Dictionary) -> Node3D:
	if visual == null or not is_instance_valid(visual):
		return null
	var skel := visual.get("skeleton") as Skeleton3D
	if skel == null:
		return null
	var old := skel.get_node_or_null(^"V7b1Looks")
	if old:
		old.free()
	var want := bool(outfit.get("v7b1_hijab", false)) or bool(outfit.get("v7b1_moustache", false)) \
			or bool(outfit.get("v7b1_glasses", false)) or bool(outfit.get("v7b1_cap", false))
	if not want:
		return null
	var head := skel.find_bone("Head")
	if head < 0:
		return null
	var attach := BoneAttachment3D.new()
	attach.name = "V7b1Looks"
	attach.bone_name = "Head"
	skel.add_child(attach)
	var body := Node3D.new()
	body.name = "BodySpace"
	body.transform = skel.get_bone_global_rest(head).affine_inverse()
	attach.add_child(body)
	var bt := str(visual.get("body_type"))
	var h: Dictionary = HEAD.get(bt, HEAD["male"])
	var c: Vector3 = h["c"]
	var r := float(h["r"])
	var front := float(h["front"])
	if bool(outfit.get("v7b1_hijab", false)):
		var hm := MeshInstance3D.new()
		hm.name = "Hijab"
		hm.mesh = hijab_mesh(r)
		hm.position = c
		hm.material_override = _mat(outfit.get("v7b1_hijab_color", Color(0.12, 0.12, 0.14)), true)
		body.add_child(hm)
	if bool(outfit.get("v7b1_moustache", false)):
		var mm := MeshInstance3D.new()
		mm.name = "Moustache"
		var bx := BoxMesh.new()
		bx.size = Vector3(r * 0.62, r * 0.12, r * 0.14)
		mm.mesh = bx
		mm.position = Vector3(0, c.y - r * 0.62, c.z + front + 0.004)
		mm.material_override = _mat(outfit.get("hair_color", Color(0.1, 0.07, 0.05)))
		body.add_child(mm)
	if bool(outfit.get("v7b1_glasses", false)):
		var g := Node3D.new()
		g.name = "Glasses"
		body.add_child(g)
		var fm := _mat(Color(0.08, 0.08, 0.09))
		var gy := c.y + r * 0.05
		var gz := c.z + front + 0.012
		for sx in [-1.0, 1.0]:
			var rim := MeshInstance3D.new()
			var t := TorusMesh.new()
			t.inner_radius = r * 0.21
			t.outer_radius = r * 0.27
			t.rings = 12
			t.ring_segments = 6
			rim.mesh = t
			rim.rotation.x = PI * 0.5
			rim.position = Vector3(sx * r * 0.33, gy, gz)
			rim.material_override = fm
			g.add_child(rim)
			var arm := MeshInstance3D.new()
			var ab := BoxMesh.new()
			ab.size = Vector3(0.006, 0.006, front * 1.05)
			arm.mesh = ab
			arm.position = Vector3(sx * r * 0.62, gy, gz - front * 0.5)
			arm.material_override = fm
			g.add_child(arm)
		var bridge := MeshInstance3D.new()
		var bb := BoxMesh.new()
		bb.size = Vector3(r * 0.14, 0.006, 0.006)
		bridge.mesh = bb
		bridge.position = Vector3(0, gy + 0.004, gz)
		bridge.material_override = fm
		g.add_child(bridge)
	if bool(outfit.get("v7b1_cap", false)):
		var cap := MeshInstance3D.new()
		cap.name = "Cap"
		var sm := SphereMesh.new()
		sm.radius = r * 1.06
		sm.height = r * 1.0
		sm.is_hemisphere = true
		cap.mesh = sm
		cap.position = Vector3(0, c.y + r * 0.42, c.z)
		cap.material_override = _mat(Color(0.3, 0.27, 0.22))
		body.add_child(cap)
		var brim := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(r * 1.5, r * 0.08, r * 0.6)
		brim.mesh = bm
		brim.position = Vector3(0, c.y + r * 0.45, c.z + front + r * 0.12)
		brim.rotation.x = 0.18
		brim.material_override = cap.material_override
		body.add_child(brim)
	return attach


static var _hijab_cache: Dictionary = {}


## Headscarf: a sphere around the head with the face left open, and a drape
## over the neck and shoulders. Centred on the head centre (+Z = face).
static func hijab_mesh(r: float) -> ArrayMesh:
	var k := snappedf(r, 0.001)
	if _hijab_cache.has(k):
		return _hijab_cache[k]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R := r * 1.22
	var rings := 14
	var segs := 20
	var pts: Array = []
	for i in rings + 1:
		var row: Array = []
		var phi := PI * float(i) / float(rings)   # 0 top .. PI bottom
		for j in segs + 1:
			var th := TAU * float(j) / float(segs)
			var d := Vector3(sin(phi) * sin(th), cos(phi), sin(phi) * cos(th))
			row.append(Vector3(d.x * R, d.y * R * 1.12 + r * 0.06, d.z * R * 1.05 - r * 0.08))
		pts.append(row)
	for i in rings:
		for j in segs:
			var a: Vector3 = pts[i][j]
			var b: Vector3 = pts[i][j + 1]
			var c2: Vector3 = pts[i + 1][j + 1]
			var d2: Vector3 = pts[i + 1][j]
			var mid := (a + b + c2 + d2) * 0.25
			var dir := Vector3(mid.x, (mid.y - r * 0.06) / 1.12, (mid.z + r * 0.08) / 1.05).normalized()
			# Face opening: front, between the forehead and the chin.
			if dir.z > 0.42 and dir.y < 0.5 and dir.y > -0.8:
				continue
			# Bottom cap closed by the drape.
			if dir.y < -0.86:
				continue
			for v in [a, b, c2, a, c2, d2]:
				st.set_normal((v as Vector3).normalized())
				st.add_vertex(v)
	# Drape: a truncated cone from under the chin to the shoulders.
	var top_y := -R * 0.62
	var bot_y := -R * 2.35
	for j in segs:
		var t0 := TAU * float(j) / float(segs)
		var t1 := TAU * float(j + 1) / float(segs)
		var p00 := Vector3(sin(t0) * R * 0.78, top_y, cos(t0) * R * 0.74 - r * 0.1)
		var p01 := Vector3(sin(t1) * R * 0.78, top_y, cos(t1) * R * 0.74 - r * 0.1)
		var p10 := Vector3(sin(t0) * R * 1.55, bot_y, cos(t0) * R * 1.15 - r * 0.15)
		var p11 := Vector3(sin(t1) * R * 1.55, bot_y, cos(t1) * R * 1.15 - r * 0.15)
		var n := Vector3(sin(t0), 0.4, cos(t0)).normalized()
		for v in [p00, p01, p11, p00, p11, p10]:
			st.set_normal(n)
			st.add_vertex(v)
	var m := st.commit()
	_hijab_cache[k] = m
	return m
