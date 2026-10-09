class_name FruitGardens
extends Node3D
## v6b "fruit_gardens" module: some townspeople have a small orchard behind
## their house (pomegranate, orange, fig, apple) with a low fence. The fruit
## belongs to the family. Talk to one of them first today (or pick while one
## of them is right there) and it is a gift; otherwise picking is theft: the
## family remembers it, friendship drops and a police report is filed
## (WorldMemory.file_report - the v7 police / justice hook) with a fine.
## Picked trees regrow their fruit after a few days (saved: WorldMemory.fruit).

var trees: Array = []   ## [{key, home, fruit, pos, node, fruit_node, spot}]
var gifts: int = 0
var thefts: int = 0


func style() -> FruitGardenStyle:
	return Modules.style("fruit_gardens") as FruitGardenStyle


func _ready() -> void:
	add_to_group(&"fruit_gardens")
	_build()
	Modules.on_swap("fruit_gardens", self, func(_m: Resource) -> void: _build())
	WorldMemory.changed.connect(func(kind: String) -> void:
		if kind == "all" or kind == "fruit":
			_sync())
	TimeManager.day_started.connect(func(_d: int) -> void: _sync())


static func _mat(c: Color, rough: float = 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	return m


func _build() -> void:
	for c in get_children():
		c.queue_free()
	trees.clear()
	var st := style()
	if st == null:
		return
	var trunk_m := _mat(Color(0.38, 0.27, 0.18), 0.95)
	var leaf_m := _mat(Color(0.22, 0.45, 0.2), 0.85)
	var fence_m := _mat(Color(0.55, 0.42, 0.28), 0.9)
	for g: Dictionary in st.gardens:
		var home := str(g.get("home", ""))
		var b := TownLayout.building(home)
		if b.is_empty():
			continue
		var bp: Vector2 = b["pos"]
		var yaw := deg_to_rad(float(b["yaw"]))
		var sz: Vector3 = b["size"]
		var back := Vector2(-sin(yaw), -cos(yaw))
		var across := Vector2(cos(yaw), -sin(yaw))
		var list: Array = g.get("trees", [])
		var n := list.size()
		var center := bp + back * (sz.z * 0.5 + 3.4)
		var holder := Node3D.new()
		holder.name = "Garden_" + home
		add_child(holder)
		# Low fence around the orchard (3 sides; the house is the 4th).
		var gw := maxf(n * 2.7, sz.x)
		var gd := 5.2
		var body := StaticBody3D.new()
		holder.add_child(body)
		for seg in [[-1.0, 0.0], [1.0, 0.0], [0.0, 1.0]]:
			var sx: float = seg[0]
			var sb: float = seg[1]
			var mid: Vector2
			var length: float
			var along: Vector2
			if sb > 0.0:
				mid = bp + back * (sz.z * 0.5 + gd + 0.6)
				length = gw
				along = across
			else:
				mid = bp + back * (sz.z * 0.5 + 0.6 + gd * 0.5) + across * (gw * 0.5 * sx)
				length = gd
				along = back
			var y := Terrain.height_at(mid.x, mid.y)
			var rail := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.06, 0.08, length)
			rail.mesh = bm
			rail.material_override = fence_m
			rail.position = Vector3(mid.x, y + 0.55, mid.y)
			rail.rotation.y = atan2(along.x, along.y)
			holder.add_child(rail)
			var rail2 := rail.duplicate() as MeshInstance3D
			rail2.position.y = y + 0.25
			holder.add_child(rail2)
			var posts := int(length / 1.3) + 1
			for k in posts:
				var pp := mid + along * (-length * 0.5 + length * k / maxf(posts - 1, 1))
				var post := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.09, 0.75, 0.09)
				post.mesh = pm
				post.material_override = fence_m
				post.position = Vector3(pp.x, Terrain.height_at(pp.x, pp.y) + 0.37, pp.y)
				holder.add_child(post)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.12, 0.8, length)
			cs.shape = bs
			cs.position = Vector3(mid.x, y + 0.4, mid.y)
			cs.rotation.y = atan2(along.x, along.y)
			body.add_child(cs)
		for i in n:
			var fid := str(list[i])
			var fdef: Dictionary = st.fruits.get(fid, {})
			var p := center + across * ((i - (n - 1) * 0.5) * 2.6)
			var pos := Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
			var t := _tree(holder, pos, fdef.get("color", Color.RED), trunk_m, leaf_m, hash(home + str(i)))
			var key := "%s:%d" % [home, i]
			var rec := {"key": key, "home": home, "fruit": fid, "pos": pos, "node": t[0], "fruit_node": t[1]}
			var idx := trees.size()
			trees.append(rec)  # before the spot: ActionSpot reads its text in _ready
			rec["spot"] = ActionSpot.make(holder, pos + Vector3(0, 0, 0), 1.5,
				func() -> String: return _text(idx),
				func(who: Node3D) -> void: pick(idx, who),
				func() -> bool: return has_fruit(idx))
			var tb := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.2
			cyl.height = 2.0
			tb.shape = cyl
			tb.position = pos + Vector3(0, 1.0, 0)
			body.add_child(tb)
	_sync()


func _tree(parent: Node3D, pos: Vector3, fruit_c: Color, trunk_m: Material, leaf_m: Material, seed_v: int) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var t := Node3D.new()
	t.position = pos
	t.rotation.y = rng.randf() * TAU
	parent.add_child(t)
	var trunk := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.09
	cm.bottom_radius = 0.15
	cm.height = 1.5
	cm.radial_segments = 7
	trunk.mesh = cm
	trunk.material_override = trunk_m
	trunk.position.y = 0.75
	t.add_child(trunk)
	var s := 0.9 + rng.randf() * 0.25
	for k in 3:
		var leaf := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.8 * s
		sm.height = 1.3 * s
		sm.radial_segments = 10
		sm.rings = 6
		leaf.mesh = sm
		leaf.material_override = leaf_m
		leaf.position = Vector3((k - 1) * 0.45 * s, 1.9 + (0.25 if k == 1 else 0.0), (0.2 if k == 1 else -0.15))
		t.add_child(leaf)
	var fruit := Node3D.new()
	fruit.name = "Fruit"
	t.add_child(fruit)
	var fm := StandardMaterial3D.new()
	fm.albedo_color = fruit_c
	fm.roughness = 0.45
	var sm2 := SphereMesh.new()
	sm2.radius = 0.1
	sm2.height = 0.2
	sm2.radial_segments = 8
	sm2.rings = 4
	# Fruit sits on the outside of the leaf clusters so it reads from afar.
	for k in 12:
		var c := k % 3
		var centre := Vector3((c - 1) * 0.45 * s, 1.9 + (0.25 if c == 1 else 0.0), (0.2 if c == 1 else -0.15))
		var a := rng.randf() * TAU
		var e := rng.randf_range(-0.55, 0.35)
		var dir := Vector3(cos(a) * cos(e), sin(e), sin(a) * cos(e))
		var fmi := MeshInstance3D.new()
		fmi.mesh = sm2
		fmi.material_override = fm
		fmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		fmi.position = centre + Vector3(dir.x * 0.8 * s, dir.y * 0.65 * s, dir.z * 0.8 * s) * 0.97
		fruit.add_child(fmi)
	return [t, fruit]


func has_fruit(i: int) -> bool:
	if i < 0 or i >= trees.size():
		return false
	var m: Dictionary = WorldMemory.fruit.get(str(trees[i]["key"]), {})
	if m.is_empty():
		return true
	var st := style()
	return TimeManager.day - int(m.get("day", 0)) >= (st.regrow_days if st else 3)


func _sync() -> void:
	for i in trees.size():
		var fn := trees[i]["fruit_node"] as Node3D
		if is_instance_valid(fn):
			fn.visible = has_fruit(i)
		var sp := trees[i].get("spot") as ActionSpot
		if is_instance_valid(sp) and sp.has_method("refresh"):
			sp.refresh()


func family_of(home: String) -> Array:
	var out: Array = []
	for r in Population.residents():
		if str(r.get("home", "")) == home:
			out.append(Population.full_name(r))
	return out


func _family_bot_near(home: String, pos: Vector3, r: float) -> TownspersonBot:
	var fam := family_of(home)
	for n in get_tree().get_nodes_in_group(&"townspeople"):
		var b := n as TownspersonBot
		if b and not b.hidden_inside and Friendship.key_of(b) in fam and b.global_position.distance_to(pos) < r:
			return b
	return null


## Allowed = you talked with one of the family today, or one of them is here.
func permitted(i: int) -> bool:
	var home := str(trees[i]["home"])
	for k in family_of(home):
		if Friendship.talked_today(k):
			return true
	return _family_bot_near(home, trees[i]["pos"], 10.0) != null


func _fruit_name(i: int) -> String:
	var st := style()
	var f: Dictionary = st.fruits.get(str(trees[i]["fruit"]), {}) if st else {}
	return str(f.get("fa" if Lang.is_fa() else "en", trees[i]["fruit"]))


func _owner_text(i: int) -> String:
	var b := TownLayout.building(str(trees[i]["home"]))
	var fam := family_of(str(trees[i]["home"]))
	var sur := str(fam[0]).get_slice(" ", 1) if not fam.is_empty() else str(b.get("owner", ""))
	return sur


func _text(i: int) -> String:
	var nm := _fruit_name(i)
	if permitted(i):
		return Lang.tt("چیدن %s (با اجازه‌ی خانواده‌ی %s)" % [nm, _owner_text(i)], "pick a %s (the %s family said yes)" % [nm, _owner_text(i)])
	return Lang.tt("چیدن %s از باغ خانواده‌ی %s - بدون اجازه دزدی است!" % [nm, _owner_text(i)], "pick a %s from the %s family's garden - without asking it is theft!" % [nm, _owner_text(i)])


## Picks the fruit (3 pieces). Returns "gift", "theft" or "".
func pick(i: int, who: Node3D = null) -> String:
	if not has_fruit(i):
		return ""
	var st := style()
	var f: Dictionary = st.fruits.get(str(trees[i]["fruit"]), {})
	var item := str(f.get("item", trees[i]["fruit"]))
	var allowed := permitted(i)
	var home := str(trees[i]["home"])
	Economy.add_item(item, 3)
	GameEvents.item_collected.emit(item)
	WorldMemory.fruit[str(trees[i]["key"])] = {"day": TimeManager.day, "theft": not allowed}
	WorldMemory.changed.emit("fruit")
	var fam := family_of(home)
	if allowed:
		gifts += 1
		for k in fam:
			WorldMemory.npc_remember(k, "fruit_gift", "I gave you fruit from our garden.", "از باغمان به تو میوه دادم.")
		var bot := _family_bot_near(home, trees[i]["pos"], 12.0)
		if bot:
			bot.say(Lang.tt("نوش جان! باز هم بیا.", "Enjoy! Come again."), 3.0)
		GameEvents.notification_requested.emit(Lang.tt("۳ %s هدیه گرفتی." % _fruit_name(i), "You got 3 %s as a gift." % _fruit_name(i)))
		return "gift"
	thefts += 1
	var fine := st.theft_fine if st else 50
	for k in fam:
		WorldMemory.npc_remember(k, "fruit_theft", "Someone took fruit from our garden without asking...", "کسی بدون اجازه از باغمان میوه چید...")
		Friendship.points[k] = maxi(int(Friendship.points.get(k, 0)) - 5, 0)
		Friendship.changed.emit(k, int(Friendship.points[k]), -5)
	WorldMemory.file_report("fruit_theft", "player", home, fine)
	GameEvents.notification_requested.emit(Lang.tt(
		"این میوه مال خانواده‌ی %s بود. گزارش به پلیس رسید (جریمه‌ی احتمالی %s سکه)." % [_owner_text(i), Lang.digits(str(fine))],
		"That fruit belonged to the %s family. It was reported to the police (possible fine: %d G)." % [_owner_text(i), fine]))
	return "theft"
