extends RefCounted
## v7b.1 visual smoke checks, run by DevTools (sections _smoke_v7b1_visual_*):
## realistic cars (not pink, interior + steering wheel, front, plates), the
## fire truck (livery, ladder, text, positional siren, lights), resident looks,
## door plaques + house variety + home marker, post office / square kiosk gone,
## no one lying on the square, no flower balls ("ice cream") on the ground,
## street plant variety, City Hall interior with the fund (F4 inside only),
## families (kinds, jobs, school, retired, directory, name card).

var t  # DevTools (untyped: its helpers are called dynamically)


func _init(dev: Node) -> void:
	t = dev


func _tree() -> SceneTree:
	return t.get_tree()


func _vis() -> V7b1Visual:
	return _tree().current_scene.find_child("V7b1Visual", true, false) as V7b1Visual


static func is_pink(c: Color) -> bool:
	return c.r > 0.7 and c.b > 0.42 and c.g < c.r - 0.18 and c.b > c.g + 0.04


## Every surface colour of a model (material_override / surface materials).
static func colours(root: Node) -> Array:
	var out: Array = []
	for n in root.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var mats: Array = []
		if gi.material_override:
			mats.append(gi.material_override)
		if gi is MeshInstance3D:
			var mi := gi as MeshInstance3D
			if mi.mesh:
				for s in mi.mesh.get_surface_count():
					var m := mi.get_surface_override_material(s)
					if m == null:
						m = mi.mesh.surface_get_material(s)
					if m:
						mats.append(m)
		for m in mats:
			if m is StandardMaterial3D:
				out.append([(m as StandardMaterial3D).albedo_color, (m as StandardMaterial3D).albedo_texture != null, m])
	return out


func _all_cars() -> Array:
	var out: Array = []
	for n in _tree().get_nodes_in_group(&"drivable_cars"):
		out.append(n)
	for n in _tree().current_scene.find_children("*", "RoadCar", true, false):
		out.append(n)
	return out


func run_cars() -> bool:
	# 1. Every car in town: procedural body, opaque non-pink paint, no shared colormap.
	var cars := _all_cars()
	t._check(cars.size() >= 4, "cars in town: %d" % cars.size())
	var procedural := 0
	var pink: Array = []
	var textured := 0
	var paints := {}
	var plain: Array = []
	for car in cars:
		var root := car.get("model_root") as Node3D
		if root == null:
			continue
		if root.has_meta(&"procedural"):
			procedural += 1
			paints[str(root.get_meta(&"paint_name", ""))] = true
		else:
			plain.append("%s(%s)" % [car.name, car.get("model_name")])
		for c: Array in colours(root):
			if is_pink(c[0]) and float((c[0] as Color).a) > 0.5:
				pink.append("%s %s" % [car.name, c[0]])
			if c[1]:
				textured += 1
	t._check(procedural == cars.size(), "all %d cars use the car_bodies module (%d procedural) %s" % [cars.size(), procedural, plain])
	t._check(pink.is_empty(), "no pink car materials %s" % [pink.slice(0, 3)])
	t._check(textured == 0, "no Kenney colormap texture on car bodies (%d textured)" % textured)
	t._check(paints.size() >= 4, "distinct paints / liveries in town: %s" % [paints.keys()])
	# 2. A fresh run of sedans: different colours + body shapes.
	CarBody.reset_counts()
	var names := {}
	var shapes := {}
	for i in 8:
		var r := CarBody.build("sedan", -1.0)
		var h := r[0] as Node3D
		names[str(h.get_meta(&"paint_name"))] = true
		shapes[str(h.get_meta(&"kind"))] = true
		for c: Array in colours(h):
			if is_pink(c[0]):
				t._check(false, "sedan %d colour %s is not pink" % [i, c[0]])
		h.free()
	t._check(names.size() >= 5, "8 town cars -> %d colours %s" % [names.size(), names.keys()])
	t._check(shapes.size() >= 3, "body shapes vary: %s" % [shapes.keys()])
	# 3. Parts: interior, front, mirrors, tyres + rims, plates, glass.
	var r2 := CarBody.build("sedan", -1.0)
	var car_m := r2[0] as Node3D
	var parts: Dictionary = car_m.get_meta(&"parts", {})
	t._check(int(parts.get("seats", 0)) >= 3 and int(parts.get("dashboard", 0)) >= 1 and int(parts.get("gauges", 0)) >= 2 and int(parts.get("rear_view_mirror", 0)) >= 1,
		"interior: seats %d, dashboard, gauges %d, rear-view mirror" % [int(parts.get("seats", 0)), int(parts.get("gauges", 0))])
	t._check(int(parts.get("grille", 0)) >= 1 and int(parts.get("headlights", 0)) >= 2 and int(parts.get("plates", 0)) >= 2 and int(parts.get("side_mirrors", 0)) >= 2,
		"front: grille, headlights, two plates, side mirrors %s" % [parts])
	t._check(int(parts.get("wheels", 0)) >= 4 and car_m.find_children("Wheel_*", "", true, false).size() >= 4, "four tyres with rims")
	var glass := 0
	for c: Array in colours(car_m):
		var m := c[2] as StandardMaterial3D
		if m.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and m.albedo_color.a < 0.6:
			glass += 1
	t._check(glass >= 1, "see-through windows (%d glass materials)" % glass)
	var plates := car_m.find_children("*", "Label3D", true, false)
	var persian_plate := false
	for l in plates:
		if (l as Label3D).is_in_group(&"car_plates") and Lang.is_rtl_text((l as Label3D).text) or "۰۱۲۳۴۵۶۷۸۹".contains((l as Label3D).text.left(1)):
			persian_plate = true
	t._check(persian_plate, "Persian-style number plate: %s" % [(plates[0] as Label3D).text if not plates.is_empty() else "-"])
	t._check(car_m.find_children("*", "", true, false).any(func(n: Node) -> bool: return n.is_in_group(&"car_roof")), "roof in group car_roof (glass sunroof / hides in the cockpit)")
	car_m.free()
	# 4. Steering wheel turns with DrivableCar.steer_amount; front wheels too.
	var dc: DrivableCar = null
	for c in _tree().get_nodes_in_group(&"drivable_cars"):
		if (c as DrivableCar).driver == null and (c as DrivableCar).model_root and (c as DrivableCar).model_root.find_child("SteeringWheel", true, false):
			dc = c
			break
	t._check(dc != null, "a drivable car with a steering wheel")
	if dc:
		var sw := dc.model_root.find_child("SteeringWheel", true, false) as SteeringWheel
		# Stand next to the car (far cars may be put to sleep by the perf layer).
		await t._place(Vector2(dc.global_position.x + 3.5, dc.global_position.z), 0.0, 5)
		var processing := dc.is_physics_processing()
		dc.set_physics_process(false)
		dc.steer_amount = 1.0
		await _tree().process_frame
		await _tree().process_frame
		if is_equal_approx(sw.amount, 0.0):
			print("  steer probe: can_process=%s car=%s front=%d" % [sw.can_process(), sw.get(&"_car"), (sw.get(&"_front") as Array).size()])
		var rim := sw.get_node(^"Rim") as Node3D
		var left := rim.rotation.z
		var fw := dc.model_root.find_child("Wheel_FL", true, false) as Node3D
		var fwy: float = fw.rotation.y if fw else 0.0
		dc.steer_amount = -1.0
		await _tree().process_frame
		await _tree().process_frame
		var right := rim.rotation.z
		dc.steer_amount = 0.0
		await _tree().process_frame
		await _tree().process_frame
		dc.set_physics_process(processing)
		t._check(absf(left) > 1.5 and signf(left) != signf(right) and is_equal_approx(sw.amount, 0.0), "steering wheel turns left %.0f deg / right %.0f deg with steer_amount" % [rad_to_deg(left), rad_to_deg(right)])
		t._check(absf(fwy) > 0.3, "front wheels steer (%.0f deg)" % rad_to_deg(fwy))
		var eye := CarBody.CockpitEye.eye(dc.size)
		var swp := sw.position
		t._check(swp.z > eye.z and absf(swp.x - eye.x) < 0.05 and swp.y < eye.y, "steering wheel in front of the cockpit eye (%s vs %s)" % [swp, eye])
	return true


func run_fire_truck() -> bool:
	var w := t._v7a() as V7aWorld
	var fs: FireService = w.fire if w else null
	t._check(fs != null and fs.truck != null, "fire service + truck")
	if fs == null or fs.truck == null:
		return true
	var root := fs.truck.model_root
	t._check(root != null and str(root.get_meta(&"kind", "")) == "firetruck", "fire truck uses the procedural firetruck body (%s)" % [root.get_meta(&"kind", "-") if root else "-"])
	var reds := 0
	for c: Array in colours(root):
		var col: Color = c[0]
		if col.r > 0.6 and col.g < 0.2 and col.b < 0.2:
			reds += 1
		if is_pink(col):
			t._check(false, "fire truck colour %s is not pink" % col)
	t._check(reds >= 1, "fire truck is red (%d red materials)" % reds)
	var txt := ""
	for n in _tree().get_nodes_in_group(&"fire_truck_text"):
		if root.is_ancestor_of(n):
			txt = (n as Label3D).text
	t._check(txt.contains("آتش") and txt.contains("۱۲۵"), "truck text: %s" % txt)
	var parts: Dictionary = root.get_meta(&"parts", {})
	t._check(int(parts.get("ladder", 0)) >= 1 and int(parts.get("hose_reels", 0)) >= 2, "ladder + hose reels %s" % [parts])
	var siren := fs.truck.get_node_or_null(^"FireSiren") as FireSiren
	t._check(siren != null and siren.player is AudioStreamPlayer3D, "positional siren (AudioStreamPlayer3D)")
	if siren:
		t._check(siren.player.attenuation_model == AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE and siren.player.max_distance > 50.0,
			"siren fades with distance (max %.0f m)" % siren.player.max_distance)
		var wav := siren.player.stream as AudioStreamWAV
		t._check(wav != null and wav.loop_mode != AudioStreamWAV.LOOP_DISABLED and wav.data.size() > 10000, "procedural looping siren stream (%d bytes)" % (wav.data.size() if wav else 0))
		var before := siren.plays
		var target: Building = fs.flammables()[0] if not fs.flammables().is_empty() else null
		if target:
			fs.ignite(target, "test")
			await t._frames(20)
			t._check(fs.truck_state == FireService.Truck.TO_FIRE and siren.plays > before and fs.truck.flashing, "responding: siren on + lights flashing (state %d)" % fs.truck_state)
			var lit := 0
			for m in siren.lamps:
				if m.emission_enabled and m.emission_energy_multiplier > 0.5:
					lit += 1
			t._check(siren.lamps.size() >= 4, "%d flashing lamps on the truck" % siren.lamps.size())
			for id in fs.fires.keys():
				var f: Node = fs.fires[id]
				if is_instance_valid(f):
					f.queue_free()
			fs.fires.clear()
			fs.arrive_now()
			await t._frames(5)
	return true


func run_people() -> bool:
	var res := Population.residents()
	var n := ResidentLooks.distinct_count(res)
	t._check(n >= int(res.size() * 0.85), "distinct resident looks: %d / %d" % [n, res.size()])
	var tones := {}
	var hijabs := 0
	var glasses := 0
	var heights := {}
	for r: Dictionary in res:
		var o := Townspeople.outfit_for(r)
		tones[snappedf(float(o.get("v7b1_tone", 0)), 0.5)] = true
		hijabs += 1 if bool(o.get("v7b1_hijab", false)) else 0
		glasses += 1 if bool(o.get("v7b1_glasses", false)) else 0
		heights[snappedf(float(o.get("body_height", 1.0)), 0.02)] = true
	t._check(tones.size() >= 4, "%d skin tones" % tones.size())
	t._check(hijabs >= 5, "%d women wear a hijab / headscarf" % hijabs)
	t._check(glasses >= 3 and heights.size() >= 5, "%d with glasses, %d heights" % [glasses, heights.size()])
	# Deterministic + family resemblance (children's tone between / near the parents').
	var a := Townspeople.outfit_for(res[2])
	var b := Townspeople.outfit_for(res[2])
	t._check(a.hash() == b.hash(), "looks are deterministic")
	var kid := {}
	for r: Dictionary in res:
		if str(r.get("role", "")) in ["son", "daughter"] and not ResidentLooks.parents_of(r).is_empty():
			kid = r
			break
	if not kid.is_empty():
		var par := ResidentLooks.parents_of(kid)
		var lo := 99.0
		var hi := -1.0
		for p: Dictionary in par:
			lo = minf(lo, ResidentLooks.tone_value(p))
			hi = maxf(hi, ResidentLooks.tone_value(p))
		var kt := ResidentLooks.tone_value(kid)
		t._check(kt >= lo - 1.3 and kt <= hi + 1.3, "family resemblance: %s tone %.1f, parents %.1f..%.1f" % [kid.get("name"), kt, lo, hi])
	# Save round trip.
	var saved := ResidentLooks.to_save()
	t._check((saved.get("looks", {}) as Dictionary).size() == res.size(), "resident looks in the save (%d)" % (saved.get("looks", {}) as Dictionary).size())
	ResidentLooks.from_save(saved)
	t._check(Townspeople.outfit_for(res[2]).hash() == a.hash(), "saved looks load back unchanged")
	ResidentLooks.clear_saved()
	var data := SaveGame.snapshot()
	t._check(data.has("resident_looks"), "SaveGame snapshot has resident_looks")
	# Features on the bodies.
	await t._frames(40)
	var feat := 0
	var hj := 0
	for bot in V7aKit.bots(_tree()):
		var sk: Skeleton3D = bot.visual.get("skeleton") as Skeleton3D if bot.visual else null
		if sk and sk.get_node_or_null(^"V7b1Looks"):
			feat += 1
			if sk.get_node(^"V7b1Looks").find_child("Hijab", true, false):
				hj += 1
	t._check(feat >= 8 and hj >= 3, "face features on %d bodies (%d hijabs)" % [feat, hj])
	return true


func run_town() -> bool:
	var town := t._town as TownBuilder
	# Plaques instead of roof boards.
	var homes := 0
	var plaques := 0
	var roof_boards := 0
	var bad_text: Array = []
	for b: Building in town.buildings.values():
		if b.kind != "home":
			continue
		homes += 1
		if b.sign_label != null and not DoorPlaques.text_for(b).is_empty():
			roof_boards += 1
		var lab := b.find_child("FamilyPlaqueLabel", true, false) as Label3D
		if lab:
			plaques += 1
			if not lab.text.begins_with("خانواده"):
				bad_text.append(lab.text)
			# Plaque by the door: within 2.5 m of the door, at eye height.
			var dp := b.door_world_position(0.1)
			if lab.global_position.distance_to(dp) > 2.6:
				bad_text.append("%s far from door" % b.layout_id)
	t._check(roof_boards == 0, "no family boards on home roofs (%d left)" % roof_boards)
	var farmhouse := town.buildings.get("farmhouse") as Building
	t._check(farmhouse != null and farmhouse.sign_label != null,
		"farmhouse keeps its sign when it has no family plaque")
	t._check(plaques >= homes - 1 and plaques >= 15, "family plaque by the door on %d / %d homes" % [plaques, homes])
	t._check(bad_text.is_empty(), "plaques read 'خانواده آقای ...' %s" % [bad_text.slice(0, 3)])
	var ahmadi := town.buildings.get("maple3") as Building
	var al: Label3D = ahmadi.find_child("FamilyPlaqueLabel", true, false) as Label3D if ahmadi else null
	t._check(al != null and al.text == "خانواده آقای احمدی", "Ahmadi plaque: %s" % (al.text if al else "-"))
	# Houses differ.
	var looks := {}
	for b: Building in town.buildings.values():
		if b.kind == "home":
			looks["%s|%s|%s|%s" % [b.wall_color.to_html(false), b.roof_color.to_html(false), b.has_porch, b.upper_windows]] = true
	t._check(looks.size() >= int(homes * 0.8), "%d distinct house looks among %d homes" % [looks.size(), homes])
	# Addresses unchanged (street names kept).
	var addr_ok := true
	for b in TownLayout.homes():
		var a := str(b.get("address", ""))
		if a == "" or not (a.ends_with("St") or a.ends_with("Ave") or a.ends_with("Ln") or a.ends_with("Rd") or a.ends_with("Sq") or a.ends_with("Lane") or a.contains("Farm")):
			addr_ok = false
	t._check(addr_ok and TownLayout.building("maple2").get("address", "") == "2 Maple St", "house addresses + street names kept")
	# Home on the minimap.
	var hm := _tree().get_first_node_in_group(&"home_marker") as HomeMarker
	t._check(hm != null and hm.minimap != null and hm.home_world().distance_to(TownLayout.building("farmhouse").get("pos", Vector2.ZERO)) < 0.1, "player's home highlighted on the minimap")
	if hm:
		hm.queue_redraw()
		await t._frames(3)
		t._check(hm.last_pos != Vector2.ZERO, "home badge / waypoint drawn at %s (off map: %s)" % [hm.last_pos, hm.off_map])
	# Post office + square office gone.
	t._check(TownLayout.building("post").is_empty() and not town.buildings.has("post"), "post office removed from the layout")
	t._check(not TownNav.has_spot("door:post") and not TownNav.has_spot("in:post"), "no nav spots for the post office")
	var post_workers: Array = []
	for r: Dictionary in Population.residents():
		if str(r.get("work", "")) == "post":
			post_workers.append(Population.full_name(r))
	t._check(post_workers.is_empty(), "no one works at the post office %s" % [post_workers])
	var reza := Population.by_name("Reza")
	t._check(str(reza.get("work", "")) == "city_hall", "Reza (ex-postman) reassigned: %s at %s" % [reza.get("job", ""), reza.get("work", "")])
	var d := Dialogue.style()
	t._check(d == null or not d.places_fa.has("post"), "post office gone from the directory / dialogue places")
	var w := t._v7a() as V7aWorld
	var cf: CityFund = w.fund if w else null
	t._check(cf != null and (cf.board == null or cf.board.get_parent() is Building), "no fund kiosk / board on the square")
	var ns := _tree().current_scene.find_child("V7bWorld", true, false)
	var paper_text := ""
	if ns and "newspaper" in ns and ns.get("newspaper") != null:
		paper_text = JSON.stringify(ns.get("newspaper").call("compose"))
	t._check(not paper_text.contains("اداره‌ی پست") and not paper_text.contains("Post Office"), "newspaper has no post office")
	# Square: no bodies, no flower balls.
	var vis := _vis()
	var guard: SquareGuard = vis.guard if vis else null
	TimeManager.set_time_of_day(12.0)
	await t._frames(30)
	var lying := SquareGuard.lying(_tree())
	var why: Array = []
	for e: Array in lying:
		why.append("%s %s" % [(e[0] as TownspersonBot).display_name, e[1]])
	if guard:
		guard.check()
	await t._frames(3)
	t._check(SquareGuard.lying(_tree()).is_empty(), "no one lies on the square (guard fixed %s)" % [why])
	var sq := _tree().current_scene.find_child("TownSquare", true, false)
	var balls: Node3D = sq.find_child("Flowers", false, false) as Node3D if sq else null
	t._check(balls == null or not balls.visible, "square: the coloured flower balls are gone")
	t._check(_tree().get_nodes_in_group(&"square_plants").size() >= 2, "square beds replanted with low shrubs")
	# Plants: variety + clear of roads.
	var plants: StreetPlants = vis.plants if vis else null
	t._check(plants != null and plants.plant_points.size() >= 30, "street plants: %d" % (plants.plant_points.size() if plants else 0))
	if plants:
		t._check(plants.species_count() >= 6, "%d plant species" % plants.species_count())
		var bad := 0
		for q: Array in plants.plant_points:
			var p: Vector3 = q[0]
			if StreetPlants.on_asphalt(Vector2(p.x, p.z), 0.35):
				bad += 1
		t._check(bad == 0, "no plant on the asphalt / road markings (%d)" % bad)
		var mm := 0
		for c in plants.get_children():
			if c is MultiMeshInstance3D:
				mm += 1
		t._check(mm >= 4 and mm <= 12, "plants drawn as %d MultiMeshes" % mm)
	return true


func run_city_hall() -> bool:
	var vis := _vis()
	var ch: CityHallInterior = vis.city_hall if vis else null
	t._check(ch != null and ch.building != null, "City Hall interior module")
	if ch == null:
		return true
	var w := t._v7a() as V7aWorld
	var cf := w.fund
	t._check(cf.board != null and ch.fund_visible_inside(), "fund board hangs inside City Hall")
	t._check(cf.price_strip == null, "fund strip removed from the square's price board")
	t._check(ch.props == null or ch.built_count <= 1, "interior props load on enter (built %d times so far)" % ch.built_count)
	# Outside: F4 does nothing but a hint.
	var door := ch.building.door_world_position(4.0)
	await t._place(Vector2(door.x, door.z), 0.0, 10)
	t._check(not CityHallInterior.player_inside(_tree()) and not CityHallInterior.f4_allowed(_tree()), "outside City Hall: F4 blocked")
	var ev := InputEventAction.new()
	ev.action = &"city_panel"
	ev.pressed = true
	cf._unhandled_input(ev)
	await t._frames(2)
	t._check(not cf.panel.visible, "F4 outside does not open the fund panel")
	# Inside: built, staff posts, F4 works.
	var inside := ch.building.global_transform * Vector3(0, Building.FOUNDATION_HEIGHT, ch.building.size.z * 0.5 - 1.2)
	await t._place(Vector2(inside.x, inside.z), 180.0, 20)
	ch.ensure_built()
	await t._frames(5)
	t._check(CityHallInterior.player_inside(_tree()), "player walked into City Hall")
	t._check(ch.props != null and ch.props.find_child("ServiceCounter", false, false) != null and ch.props.find_child("ManagerDesk", false, false) != null,
		"counter + manager desk inside")
	t._check(ch.props.has_meta(&"streamable_interior"), "interior props are one separable node (streamable)")
	t._check(ch.staffing.posts.size() >= 3, "%d City Hall posts (manager + clerks)" % ch.staffing.posts.size())
	TimeManager.set_time_of_day(10.0)
	ch.staffing.auto = false
	ch.staffing.tick()
	await t._frames(5)
	var held: Array = []
	for role in ch.staffing.posts:
		var h := ch.staffing.holder(role)
		if h:
			held.append("%s=%s" % [role, h.display_name])
	t._check(held.size() >= 3, "manager + clerks at their posts: %s" % [held])
	var mgr := ch.staffing.holder("city_manager")
	t._check(mgr != null and mgr.display_name == "Omid", "manager is Omid Hosseini")
	ch.staffing.release_all()
	# Leave background staffing disabled for the remaining smoke sections.
	ch.staffing.auto = false
	cf._unhandled_input(ev)
	await t._frames(2)
	t._check(cf.panel.visible, "F4 inside City Hall opens the fund panel")
	cf.panel.close()
	await t._frames(2)
	ch.manager_zone.interacted.emit(t._player)
	await t._frames(2)
	t._check(cf.panel.visible, "talking to the manager opens the fund panel")
	cf.panel.close()
	t._check(cf.board_label.text.contains(Lang.digits(str(CityState.fund))), "inside board shows the fund: %s" % cf.board_label.text.left(40))
	await t._place(Vector2(door.x, door.z), 0.0, 10)
	return true


func run_families() -> bool:
	var counts := Families.kind_counts()
	t._check(int(counts.get("large_family", 0)) >= 3, "households with 4 children: %d" % int(counts.get("large_family", 0)))
	t._check(int(counts.get("newlyweds", 0)) >= 1 and int(counts.get("young_couple", 0)) >= 1, "newlyweds + young couples %s" % [counts])
	t._check(int(counts.get("elderly_couple", 0)) + int(counts.get("older_couple", 0)) >= 1 and int(counts.get("single", 0)) >= 1, "elderly couples + singles %s" % [counts])
	var no_kids := 0
	for h: String in Population.households():
		var kids := 0
		for r: Dictionary in Population.households()[h]:
			if int(r.get("age", 0)) < 18:
				kids += 1
		if kids == 0:
			no_kids += 1
	t._check(no_kids >= 4, "%d households without children" % no_kids)
	t._check(Families.adults_without_work().is_empty(), "every adult under 65 has a job %s" % [Families.adults_without_work()])
	var school_ok := true
	var bad_spots: Array = []
	for r: Dictionary in Population.residents():
		var age := int(r.get("age", 0))
		var work := str(r.get("work", ""))
		if age >= 3 and age < 18 and work != "school":
			school_ok = false
		if work != "" and not TownNav.has_spot("in:" + work) and not TownNav.has_spot(work) and not TownNav.has_spot("door:" + work):
			bad_spots.append("%s->%s" % [Population.full_name(r), work])
	t._check(school_ok, "all children go to school / kindergarten")
	t._check(bad_spots.is_empty(), "every workplace is a real place %s" % [bad_spots])
	var retired := 0
	for r: Dictionary in Population.residents():
		if int(r.get("age", 0)) >= 60 and (str(r.get("work", "")) == "" or str(r.get("job", "")).to_lower().contains("part-time")):
			retired += 1
	t._check(retired >= 2, "%d elderly retired / light work" % retired)
	var names := {}
	var dup: Array = []
	for r: Dictionary in Population.residents():
		var f := str(r.get("name", ""))
		if names.has(f):
			dup.append(f)
		names[f] = true
	t._check(dup.is_empty(), "first names unique (bots are found by name) %s" % [dup])
	var homes_ok := true
	for h: String in Population.households():
		if TownLayout.building(h).is_empty():
			homes_ok = false
	t._check(homes_ok, "every household has a real home with an address")
	# Backstories cover every resident.
	var bs := Modules.style("backstories")
	var missing: Array = []
	if bs and "people" in bs:
		for r: Dictionary in Population.residents():
			if not (bs.get("people") as Dictionary).has(Population.full_name(r)):
				missing.append(Population.full_name(r))
	t._check(missing.is_empty(), "backstory for every resident %s" % [missing.slice(0, 4)])
	# Directory (J) + name card.
	var pp := _tree().current_scene.find_child("PeoplePanel", true, false) as PeoplePanel
	t._check(pp != null, "people panel")
	if pp:
		pp.open()
		await t._frames(3)
		var txt := ""
		for l in pp.find_children("*", "Label", true, false):
			txt += (l as Label).text + "\n"
		t._check(txt.contains("پرجمعیت") and txt.contains("بازنشسته") and txt.contains("مدرسه") and txt.contains("تازه"), "J directory in Persian with household kinds, school, retired")
		pp.close()
	var reza := Population.by_name("Reza")
	var line := Families.card_line(reza)
	t._check(line.contains("پرجمعیت") and line.contains("پدر"), "name card household line: %s" % line)
	return true
