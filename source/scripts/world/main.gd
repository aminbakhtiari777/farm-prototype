extends Node3D
## Root of the prototype scene. Handles global keys and optional dev tools.
##
## Dev tools are NOT part of normal play; they only load when the game is
## started with user arguments after "--", e.g.
##   godot --path . -- --screenshot=/tmp/shot.png
##   godot --headless --path . -- --smoke-test


func _ready() -> void:
	# Ambience: see AmbienceManager (wind, birds by day, crickets at night,
	# positional waves at the beach). Browsers only start audio after the
	# first click/key press on the page.
	# Web demo links: index.html?season=winter&hour=22&demo=shop (see README).
	if OS.has_feature("web"):
		var query: Variant = JavaScriptBridge.eval("window.location.search", true)
		if query is String and not (query as String).is_empty():
			Demo.apply_url_params.call_deferred(get_tree(), query)
	_add_feature_modules()
	TownGameplay.attach_world(self)
	var args := OS.get_cmdline_user_args()
	for arg in args:
		if arg.begins_with("--net-test="):
			var drv: Node = load("res://scripts/tools/net_test_driver.gd").new()
			drv.name = "NetTestDriver"
			add_child(drv)
			break
		if arg.begins_with("--screenshot") or arg.begins_with("--inspect=") or arg == "--smoke-test" or arg.begins_with("--smoke-only=") \
			or arg.begins_with("--shots") or arg.begins_with("--vis-shots") or arg.begins_with("--ctl-shots") \
			or arg == "--perf" or arg.begins_with("--perf-profile") or arg.begins_with("--perf-walk"):
			var tools: Node = load("res://scripts/tools/dev_tools.gd").new()
			tools.name = "DevTools"
			add_child(tools)
			break



## v4 feature modules (each reads its style from the AssetRegistry):
## night lights + electricity, the town power post, landscape, NPC social life.
func _add_feature_modules() -> void:
	var lights := NightLights.new()
	lights.name = "NightLights"
	add_child(lights)
	var post := PowerPost.new()
	post.name = "TownPowerPost"
	post.position = Vector3(3.4, 0.0, -38.0)
	post.rotation.y = -PI * 0.5
	add_child(post)
	var land := Landscape.new()
	land.name = "Landscape"
	add_child(land)
	var social := NpcSocial.new()
	social.name = "NpcSocial"
	add_child(social)
	# v5a: hourly adhan (mosque module) and church bells (church module).
	var adhan := CallPlayer.new()
	adhan.name = "AdhanPlayer"
	adhan.kind = "mosque"
	add_child(adhan)
	var gestures := NpcGestures.new()
	gestures.name = "NpcGestures"
	add_child(gestures)
	# v5b: townspeople voice blips (voices module).
	var voices := VoiceBlips.new()
	voices.name = "VoiceBlips"
	add_child(voices)
	var bells := CallPlayer.new()
	bells.name = "BellPlayer"
	bells.kind = "church"
	add_child(bells)
	# v5d: other players / away avatars (RemoteAvatars) and the online UI (NetHud).
	# Both stay idle in single player (Net.state == "offline").
	var remotes := RemoteAvatars.new()
	add_child(remotes)
	var net_hud := NetHud.new()
	add_child(net_hud)
	# v6a: night sky, dry trees, campfire, boats, sunbathing beach, house music.
	var v6a := V6aWorld.new()
	v6a.name = "V6aWorld"
	add_child(v6a)
	# v6b: character creator / wardrobe, vehicles, interiors, square landmark,
	# fruit gardens, pushables, herding, digging, yard routine, shadows.
	var v6b := V6bWorld.new()
	v6b.name = "V6bWorld"
	add_child(v6b)
	# v7a: NPC backstories, kids at play, street arguments, playing as a
	# townsperson, fire service, power outages + quakes, city fund.
	var v7a := V7aWorld.new()
	v7a.name = "V7aWorld"
	add_child(v7a)
	# v7b: chattier town, terrace cafe (bartender + DJ), mechanic + deeper
	# driving, passengers, camping, newspaper, personalities, distinct voices.
	var v7b := V7bWorld.new()
	v7b.name = "V7bWorld"
	add_child(v7b)
	# v7b.1 perf: streaming, distance LOD, interiors on demand, audio /
	# animation budgets, graphics presets, frame pacing, F7 overlay.
	var perf := PerfWorld.new()
	add_child(perf)
	# v7b.1: GTA-style controls (mouse look / steering, touch twin sticks + buttons,
	# cockpit camera, gear indicator). Shared input: the ControlInput autoload.
	# v7b.1 traffic: lights, signs, markings, licence, dealership, bus, car sounds,
	# street lighting, cafe-lounge / disco (V7b1TrafficWorld).
	var v7b1_traffic := V7b1TrafficWorld.new()
	v7b1_traffic.name = "V7b1TrafficWorld"
	add_child(v7b1_traffic)
	var v7b1_controls := V7bControls.new()
	add_child(v7b1_controls)
	# v7b.1 platform: boot title, lobby/rooms, update client, brand (Zamith / Farm Town).
	var v7b1_platform := V7b1Platform.new()
	add_child(v7b1_platform)
	# v7b.1 visual: realistic cars, resident looks, door plaques, street plants,
	# City Hall interior with the fund, fire truck siren, families (scripts/v7b1_visual/).
	var v7b1_visual := V7b1Visual.new()
	add_child(v7b1_visual)
	# v7b.1 audio: listener on the active camera, surface footsteps, door open / close,
	# placed ambient emitters (birds, crickets, square, river, traffic), gusts, thunder.
	var v7b1_audio := V7b1AudioWorld.new()
	add_child(v7b1_audio)
	# v7b.1 police / road safety: AI cars yield to people, hit reactions,
	# ambulance + police + crowd after a hard hit (scripts/v7b1_police/).
	var v7b1_police := V7b1PoliceWorld.new()
	add_child(v7b1_police)
