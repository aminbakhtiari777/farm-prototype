extends RefCounted
var t: Node
func _init(test: Node) -> void:
	t = test

func run() -> bool:
	var p := t.get("_player") as Player
	var town := t.get("_town") as TownBuilder
	var home := town.buildings["farmhouse"] as Building
	await t._place(Vector2(home.global_position.x, home.global_position.z), 0, 45)
	t._check(home.player_inside and home.interior_root.process_mode != Node.PROCESS_MODE_DISABLED, "household interactions run inside an active loaded home")
	var saved_economy := Economy.to_save()
	var saved_day := TimeManager.day
	var saved_hour := TimeManager.hours_float()
	var saved_weather := TimeManager.weather_id
	GameEvents.close_all_modals()
	TownGameplay.close()
	Economy.money = 10000
	t._check(GameData.item("fishing_net").get("type") == "tool" and GameData.item("spade").get("type") == "tool", "new net and digging tools are real inventory items")
	t._check(Shops.shop("fruit_shop").get("buys", []).has("mango") and Shops.shop("hypermarket").get("buys", []).has("hamour"), "fruit shop buys island fruit; hypermarket buys net catch")
	t._check(Shops.shop("tool_shop").get("sells", []).has("pickaxe"), "tool shop sells the pickaxe")
	var pantry := Economy.pantry("farmhouse")
	var initial := int(pantry.get("apple", 0))
	t._check(initial >= 7 and int(pantry.get("eggs", 0)) >= 14, "household has week-scale groceries separate from the bag")
	var apples := Economy.count("apple")
	t._check(TownGameplay.transfer_food("farmhouse", "apple", false) and int(pantry["apple"]) == initial - 1 and Economy.count("apple") == apples + 1, "take one removes exactly one from fridge and adds one to bag")
	t._check(TownGameplay.transfer_food("farmhouse", "apple", true) and int(pantry["apple"]) == initial and Economy.count("apple") == apples, "storing returns one from bag to fridge")
	t._check(TownGameplay.eat_food("apple", "farmhouse") and int(pantry["apple"]) == initial - 1, "eating consumes actual food")
	var roundtrip := Economy.to_save()
	Economy.pantries = {}
	Economy.from_save(roundtrip)
	t._check(int(Economy.pantry("farmhouse")["apple"]) == initial - 1, "groceries survive save/load without free restocking")
	var fridge: FridgeUnit
	for f in t.get_tree().get_nodes_in_group(&"fridges"):
		if (f as FridgeUnit).building == home:
			fridge = f
	t._check(fridge != null, "farmhouse has a visible openable fridge")
	fridge.open_door()
	TownGameplay.open_fridge(fridge)
	t._check(TownGameplay.panel.visible and GameEvents.ui_open and TownGameplay.rows.get_child_count() >= 4, "fridge exposes real take/store/eat controls")
	TownGameplay.close()
	fridge.close_door()
	var cabinet := home.interior_root.find_child("CabinetDoor", true, false) as BuildingDoor
	t._check(cabinet != null, "kitchen cabinet has a separate hinged panel")
	cabinet.set_open(true)
	await t._frames(45)
	t._check(cabinet.is_open and cabinet.swing_degrees() > 80, "cabinet door swings on its hinge")
	cabinet.set_open(false)
	await t._frames(45)
	t._check(absf(cabinet.swing_degrees()) < 1, "cabinet closes smoothly")
	home.door.set_locked(false)
	home.door.set_open(false, true)
	home.door.set_locked(true)
	home.door.toggle()
	t._check(home.door.locked and not home.door.is_open, "locked front door stays shut on E")
	var locked_save := Economy.to_save()
	Economy.door_locks.clear()
	Economy.from_save(locked_save)
	t._check(bool(Economy.door_locks.get("farmhouse")), "door lock persists in the save")
	home.door.set_locked(false)
	home.door.toggle()
	t._check(home.door.is_open, "unlocked door opens")
	home.door.set_open(false, true)
	var bed: InteriorItem
	var tv: InteriorItem
	for item in home.interior_root.find_children("*", "Node3D", true, false):
		if item is InteriorItem and (item as InteriorItem).kind == "bed":
			bed = item
		if item is InteriorItem and (item as InteriorItem).kind == "tv":
			tv = item
	TimeManager.reset_calendar(saved_day, 22, "sunny")
	var before_sleep := TimeManager.day
	t._check(TownGameplay.sleep_in(bed, p), "own bed accepts sleep")
	t._check(TimeManager.day == before_sleep + 1 and TimeManager.hour() == 6 and p.stamina > 90, "sleep advances to 06:00 next day and restores stamina")
	await t._frames(100)
	PowerGrid.set_power(true)
	tv.set_on(true)
	t._check(tv._news.visible and tv._news.text.contains(Lang.digits(str(TimeManager.day))), "TV shows today's real city news on its screen")
	var old_news := tv._news.text
	TimeManager.sleep_until_morning(6)
	t._check(tv._news.text != old_news, "TV news updates when the day changes")
	tv.set_on(false)
	Economy.add_item("fishing_net", 1)
	Economy.add_item("spade", 1)
	Economy.add_item("pickaxe", 1)
	TownGameplay.open_bag()
	t._check(TownGameplay.rows.get_child_count() >= 5, "bag offers usable tools and edible food")
	TownGameplay.close()
	var adult: TownspersonBot
	for resident in t.get_tree().get_nodes_in_group(&"townspeople"):
		if int(resident.resident.get("age", 0)) >= 18:
			adult = resident
			break
	var resident_position := adult.global_position
	var resident_hidden := adult.hidden_inside
	var resident_controller := adult.controller
	var injuries := int(adult.get_meta(&"injury", 0))
	var saved_friendship := Friendship.to_save()
	var saved_memory := WorldMemory.to_save()
	adult.hidden_inside = false
	adult.global_position = p.global_position + p.facing_direction() * 1.0
	t._check(TownGameplay.attack() and adult.controller is HitReactController, "nearby adult receives a visible strike reaction")
	t._check(not TownGameplay.attack(), "strike cooldown prevents repeated hits in the same frame")
	t._check(int(adult.get_meta(&"injury", 0)) == injuries + 1 and WorldMemory.reports.size() == saved_memory["reports"].size() + 1, "strike records injury and police consequences")
	adult.controller = resident_controller
	adult.global_position = resident_position
	adult.hidden_inside = resident_hidden
	adult.set_meta(&"injury", injuries)
	TownGameplay._hurt.clear()
	Friendship.from_save(saved_friendship)
	WorldMemory.from_save(saved_memory)
	var boats := t.get_tree().get_nodes_in_group(&"fishing_boats")
	var boat := boats[0] as FishingBoat
	TimeManager.reset_calendar(saved_day, 11, "sunny")
	await t._place(Vector2(boat.board_point.x, boat.board_point.z), 0, 4)
	boat.island_trip = true
	t._check(boat.board(p) and boat.engine_running and is_instance_valid(TownGameplay.island), "island voyage starts its motor and lazily builds the island")
	boat.finish_voyage()
	await t._frames(10)
	t._check(boat.state == FishingBoat.State.AT_SEA and not boat.engine_running and p.global_position.distance_to(TownGameplay.ISLAND + Vector3(0, 1.3, -12)) < 2, "arrive on island, engine stops and player lands safely")
	WorldMemory.fruit.erase("island:mango")
	var mangoes := Economy.count("mango")
	t._check(TownGameplay.pick_island_fruit("mango") and Economy.count("mango") == mangoes + 4, "island fruit goes into the real bag")
	t._check(not TownGameplay.pick_island_fruit("mango"), "picked island tree cannot give unlimited fruit before regrowing")
	var proceeds := Economy.sell("mango", 1)
	t._check(proceeds > 0 and Economy.count("mango") == mangoes + 3, "island produce can be sold and inventory decreases")
	t._check(TownGameplay.eat_food("mango") and Economy.count("mango") == mangoes + 2, "island fruit can be eaten from the bag")
	t._check(boat.helm(p) and boat.engine_running, "return trip starts the engine")
	boat.finish_voyage()
	t._check(boat.passenger == null and boat.state == FishingBoat.State.DOCKED and p.global_position.distance_to(boat.board_point) < 2, "island return docks and disembarks at town")
	boat.island_trip = false
	boat.board(p)
	boat.finish_voyage()
	var fish := Economy.count("hamour")
	t._check(TownGameplay.cast_net(), "net can be cast from boat in deep water")
	t._check(not TownGameplay.cast_net(), "net cooldown blocks overlapping casts")
	await t._frames(220)
	t._check(Economy.count("hamour") == fish + 2, "retrieving the net adds caught fish")
	boat.helm(p)
	boat.finish_voyage()
	var stick := t.get_tree().current_scene.find_child("TouchControls", true, false) as TouchControls
	stick.left.origin = Vector2(100, 100)
	stick._update_stick(stick.left, Vector2(100, 100) + Vector2(0, -stick.radius * 2))
	t._check(stick.left.origin == Vector2(100, 100) and absf(stick.left.value.x) < 0.001 and stick.left.value.y < -0.99, "overdrag preserves movement stick origin and straight direction")
	ControlInput.touch_move = Vector2.ZERO
	stick.left.value = Vector2.ZERO
	var q := AssetRegistry.load_variant("quality", "low") as QualityStyle
	t._check(q.stream_radius <= 45 and q.npc_visible_distance <= 30 and q.lamp_lights <= 1, "low preset bounds nearby world, animated people and lights")
	Economy.from_save(saved_economy)
	TimeManager.reset_calendar(saved_day, saved_hour, saved_weather)
	WorldMemory.fruit.erase("island:mango")
	TownGameplay.close()
	return true
