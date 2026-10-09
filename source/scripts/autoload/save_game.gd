extends Node
## Save / load (autoload "SaveGame"). One slot in user://save.json. On the
## web the slot lives in the browser's localStorage (WebStorage): v3 relied on
## Godot's IndexedDB sync of user://, which did not flush saves made during
## play, so a reload lost them. v4 writes localStorage synchronously. Saved: money, inventory, selected seed, watering-can water,
## calendar (day, time, weather), crop tiles, sheep affection/wool, player
## position + stamina, and every carryable's position (incl. crates you built).

signal saved(ok: bool)
signal loaded(ok: bool)

const PATH := "user://save.json"
const WEB_KEY := "farm_prototype_save"
const VERSION := 4

var last_error: String = ""


func has_save() -> bool:
	if OS.has_feature("web"):
		return WebStorage.has_item(WEB_KEY)
	return FileAccess.file_exists(PATH)


func snapshot() -> Dictionary:
	var data := {
		"version": VERSION,
		"saved_at": Time.get_datetime_string_from_system(),
		"player_name": Settings.get_value("player_name"),
		"economy": Economy.to_save(),
		"time": {"day": TimeManager.day, "minutes": TimeManager.minutes, "weather": TimeManager.weather_id},
	}
	var tree := get_tree()
	var plot := tree.get_first_node_in_group(&"farm_plot")
	if plot and plot.has_method("to_save"):
		data["farm"] = plot.call("to_save")
	var animals: Array = []
	for a in tree.get_nodes_in_group(&"animals"):
		animals.append({"name": str(a.get("display_name")), "affection": int(a.get("affection")), "wool_ready": bool(a.get("wool_ready"))})
	data["animals"] = animals
	var player := tree.get_first_node_in_group(&"player")
	if player and player.has_method("to_save"):
		data["player"] = player.call("to_save")
	var carry: Array = []
	for c in tree.get_nodes_in_group(&"carryables"):
		if c is Carryable:
			carry.append((c as Carryable).to_save())
	data["carryables"] = carry
	# v5b: needs (hunger / fatigue / illness, townspeople too) + friendship.
	data["needs"] = Needs.to_save()
	# v5c: living economy + livestock.
	data["market"] = Market.to_save()
	data["ranch"] = Ranch.to_save()
	data["friendship"] = Friendship.to_save()
	# v6a: fitness, dry trees, campfire (Lifestyle).
	data["lifestyle"] = Lifestyle.to_save()
	# v6b: world memory (moved boxes, holes, drops, cars, fruit, NPC memories).
	data["world_memory"] = WorldMemory.to_save()
	# v7a: city fund, public works, building damage (CityState).
	data["city"] = CityState.to_save()
	# v7b: cars (fuel, wear, upgrades), newspapers, cafe, rides, camps, chat log (TownLife).
	data["town_life"] = TownLife.to_save()
	# v7b.1: resident looks (skin tone, height, hijab, glasses...) per resident.
	data["resident_looks"] = ResidentLooks.to_save()
	# v7b.1 traffic: licence, offences, impounded / bought cars, traffic news (TrafficState).
	data["traffic"] = TrafficState.to_save()
	return data


func save_game() -> bool:
	var text := JSON.stringify(snapshot())
	if OS.has_feature("web"):
		if not WebStorage.set_item(WEB_KEY, text):
			last_error = "Browser storage refused the save (private mode or full?)"
			print("SaveGame: web save FAILED")
			saved.emit(false)
			return false
		print("SaveGame: saved to browser storage (%d bytes)" % text.length())
		saved.emit(true)
		return true
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		last_error = "Could not write %s (%s)" % [PATH, error_string(FileAccess.get_open_error())]
		saved.emit(false)
		return false
	f.store_string(text)
	f.close()
	saved.emit(true)
	return true


func _read_text() -> String:
	if OS.has_feature("web"):
		return WebStorage.get_item(WEB_KEY)
	var f := FileAccess.open(PATH, FileAccess.READ)
	return f.get_as_text() if f else ""


func load_game() -> bool:
	if not has_save():
		last_error = "No save yet"
		loaded.emit(false)
		return false
	var text := _read_text()
	var parsed: Variant = JSON.parse_string(text) if text != "" else null
	if not (parsed is Dictionary):
		last_error = "Save file is damaged"
		loaded.emit(false)
		return false
	apply(parsed)
	print("SaveGame: loaded (day %d)" % TimeManager.day)
	loaded.emit(true)
	return true


func apply(data: Dictionary) -> void:
	var t: Dictionary = data.get("time", {})
	TimeManager.reset_calendar(int(t.get("day", 1)), float(t.get("minutes", 480.0)) / 60.0, str(t.get("weather", "sunny")))
	Economy.from_save(data.get("economy", {}))
	var tree := get_tree()
	var plot := tree.get_first_node_in_group(&"farm_plot")
	if plot and plot.has_method("from_save") and data.has("farm"):
		plot.call("from_save", data["farm"])
	var animals: Array = data.get("animals", [])
	for a in tree.get_nodes_in_group(&"animals"):
		for entry in animals:
			if str(entry.get("name")) == str(a.get("display_name")):
				a.set("affection", int(entry.get("affection", 0)))
				a.set("wool_ready", bool(entry.get("wool_ready", false)))
	var player := tree.get_first_node_in_group(&"player")
	if player and player.has_method("from_save") and data.has("player"):
		if player.has_method("stand_up"):
			player.call("stand_up")
		player.call("from_save", data["player"])
		var rig := tree.get_first_node_in_group(&"camera_rig")
		if rig and rig.has_method("snap"):
			rig.call("snap")
	_apply_carryables(data.get("carryables", []))
	if data.has("needs"):
		Needs.from_save(data["needs"])
	if data.has("friendship"):
		Friendship.from_save(data["friendship"])
	if data.has("market"):
		Market.from_save(data["market"])
	if data.has("ranch"):
		Ranch.from_save(data["ranch"])
	if data.has("lifestyle"):
		Lifestyle.from_save(data["lifestyle"])
	if data.has("world_memory"):
		WorldMemory.from_save(data["world_memory"])
	if data.has("city"):
		CityState.from_save(data["city"])
	if data.has("town_life"):
		TownLife.from_save(data["town_life"])
	if data.has("resident_looks"):
		ResidentLooks.from_save(data["resident_looks"])
	if data.has("traffic"):
		TrafficState.from_save(data["traffic"])
	if str(data.get("player_name", "")) != "":
		Settings.set_value("player_name", data["player_name"])


func _apply_carryables(list: Array) -> void:
	var tree := get_tree()
	var by_id: Dictionary = {}
	for c in tree.get_nodes_in_group(&"carryables"):
		var item := c as Carryable
		if item == null:
			continue
		if item.carried_by:
			continue
		if item.spawned:
			item.queue_free()  # re-created from the save below
		else:
			by_id[item.save_id] = item
	var scene := tree.current_scene
	for entry: Dictionary in list:
		var p: Array = entry.get("pos", [0, 0, 0])
		var pos := Vector3(float(p[0]), float(p[1]), float(p[2]))
		var item: Carryable = by_id.get(str(entry.get("id")), null)
		if item == null:
			if not bool(entry.get("spawned", false)):
				continue
			item = Carryable.make(str(entry.get("kind", "crate")), str(entry.get("id")))
			item.spawned = true
			scene.add_child(item)
		item.global_position = pos
		item.rotation.y = float(entry.get("yaw", 0.0))


func delete_save() -> void:
	if OS.has_feature("web"):
		WebStorage.remove_item(WEB_KEY)
		return
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH) if not OS.has_feature("web") else PATH)
