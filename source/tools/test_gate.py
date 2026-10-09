#!/usr/bin/env python3
"""Automated test gate for Farm Prototype.

Runs (in order):
  1. Module-change detection vs the last published state
  2. Compile check (every .gd / module .tres)
  3. Full smoke test
  4. Web export (Compatibility, convert_text_resources_to_binary=false)
  5. Headless Chrome load of the web build (0 console errors, offline by
     default: no WebSocket is opened)
  6. v5d network test (tools/net_test.py: headless server + two clients)

Exits non-zero on any failure. Publishing (tools/publish.py) MUST go through
this and refuse to publish if it fails.

Usage:
  python3 tools/test_gate.py [--skip-web] [--skip-chrome] [--skip-smoke] [--skip-net]
                             [--web-out DIR] [--web-build DIR]
"""
from __future__ import annotations
import hashlib, json, os, re, shutil, socket, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", shutil.which("godot") or os.path.expanduser("~/godot/godot"))
STATE = Path("/workspace/farm-v7b1-gate-state.json")
PUBLISHED = Path("/tmp/farm-pages")
MODULES_DIR = ROOT / "modules"
PWVENV = Path(os.environ.get("FARM_TEST_PYTHON", sys.executable))
DEFAULT_WEB_BUILD = Path("/workspace/farm-prototype-v7b1-webbuild")
DEFAULT_WEB_OUT = Path("/workspace/farm-prototype-v7b1-web")

MODULE_TYPES = [
    "terrain", "trees", "rocks", "plants", "crops", "fences", "buildings",
    "characters", "animals", "furniture", "water", "sky",
    "crop_types", "garden", "garden_rules", "lighting", "power", "yards",
    "minimap", "npc_social", "landscape", "tool_types", "house_styles",
    # v5a
    "crafting", "recipes", "market", "town_square", "population", "workplaces", "civic",
    "mosque", "church", "kitchen", "gestures",
    # v5b
    "fonts", "dialogue", "friendship", "shop_hours", "voices", "npc_card", "needs",
    "illnesses", "ingredients", "dishes", "cooking",
    # v5c
    "market_economy", "producers", "wages", "price_board", "livestock", "animal_housing",
    # v5d
    "netcode", "chat", "live_updates", "save_sync", "away_avatar", "accounts", "npc_roles",
    # v6a
    "night_sky", "real_clock", "dry_trees", "fishing_gear", "campfire", "deep_sea", "boats", "sunbathing",
    "gym", "house_music", "kitchenware", "hypermarket", "ui_text",
    # v6b
    "character_creator", "wardrobe", "npc_looks", "vehicles", "ambulance", "police_patrol", "wood_pickup",
    "gas_stove", "fridge", "living_room", "house_colors", "landmark", "fruit_gardens", "town_lots",
    "pushables", "herding", "digging", "yard_routine", "world_memory", "shadows", "cloud_shadows", "sea_horizon",
    # v7a
    "backstories", "kids", "conflicts", "possession", "fire", "outages", "city_fund",
    # v7b
    "chatter", "cafe", "mechanic", "driving", "passengers", "camping", "newspaper", "personalities", "voice_profiles",
    # v7b.1 controls patch
    "controls_mouse", "controls_touch", "controls_keyboard",
    # v7b.1 visual pass
    "car_bodies", "resident_looks", "door_plaques", "house_variety", "street_plants", "fire_truck",
    "city_hall_interior", "families",
    # v7b.1 traffic
    "traffic_rules", "road_markings", "traffic_signs", "driving_license", "car_dealership", "npc_traffic",
    "transit", "car_sounds", "cafe_lounge", "street_lighting",
    # v7b.1 performance refresh
    "quality", "world_stream", "lod_rules", "audio_budget",
    # v7b.1 audio
    "spatial_audio", "sound_fx", "ambient_sounds",
    # v7b.1 police / road safety
    "road_safety",
]


def log(msg: str) -> None:
    print(msg, flush=True)


def run(cmd, cwd=None, timeout=None, env=None) -> subprocess.CompletedProcess:
    log("$ " + " ".join(str(c) for c in cmd))
    return subprocess.run(cmd, cwd=cwd or ROOT, capture_output=True, text=True,
                          timeout=timeout, env=env)


def sha_of(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# Feature code that consumes each module type (a change here re-tests it too).
CONSUMERS = {
    "crop_types": ["scripts/world/farm_plot.gd", "scripts/world/garden", "scripts/autoload/game_data.gd"],
    "garden": ["scripts/world/farm_plot.gd", "assets/shaders/garden_ground.gdshader"],
    "garden_rules": ["scripts/world/farm_plot.gd", "scripts/autoload/economy.gd"],
    "lighting": ["scripts/systems/night_lights.gd", "scripts/world/day_night_cycle.gd", "scripts/world/props/building.gd"],
    "power": ["scripts/autoload/power_grid.gd", "scripts/systems/power_fx.gd", "scripts/world/props/breaker_box.gd",
              "scripts/world/props/power_post.gd", "scripts/world/interior/interior_builder.gd"],
    "yards": ["scripts/world/town/town_builder.gd"],
    "minimap": ["scripts/ui/minimap.gd", "scripts/ui/hud.gd"],
    "npc_social": ["scripts/npc"],
    "landscape": ["scripts/world/landscape", "scripts/world/terrain.gd", "assets/shaders/river.gdshader"],
    "tool_types": ["scripts/player/tool_animator.gd", "scripts/player/player.gd", "assets/audio/sfx"],
    "house_styles": ["scripts/world/props/building.gd", "scripts/world/interior/interior_builder.gd",
                     "assets/shaders/house_cladding.gdshader"],
    "trees": ["scripts/world/nature_scatter.gd"],
    "terrain": ["scripts/world/terrain.gd"],
    "buildings": ["scripts/world/props/building.gd"],
    # v5a
    "crafting": ["scripts/systems/crafting.gd", "scripts/ui/crafting_panel.gd", "scripts/world/interior/interior_v5a.gd"],
    "recipes": ["scripts/systems/crafting.gd", "scripts/autoload/game_data.gd"],
    "market": ["scripts/world/town/market_area.gd", "scripts/systems/shops.gd", "scripts/ui/shop_panel.gd"],
    "town_square": ["scripts/world/town/town_square.gd", "scripts/world/town/town_builder.gd"],
    "population": ["scripts/npc", "scripts/ui/people_panel.gd"],
    "workplaces": ["scripts/systems/shops.gd", "scripts/world/props/building_decor.gd", "scripts/world/interior/interior_v5a.gd"],
    "civic": ["scripts/world/props/building_decor.gd", "scripts/world/interior/interior_v5a.gd", "scripts/world/interior/interior_item.gd"],
    "mosque": ["scripts/world/props/mosque_builder.gd", "scripts/systems/call_player.gd", "assets/audio/sfx/adhan.ogg"],
    "church": ["scripts/world/props/church_builder.gd", "scripts/systems/call_player.gd", "assets/audio/sfx/church_bell.ogg"],
    "kitchen": ["scripts/world/interior/kitchen_builder.gd", "scripts/systems/crafting.gd"],
    "gestures": ["scripts/npc/npc_gestures.gd", "scripts/npc/wave_modifier.gd"],
    # v5b
    "fonts": ["scripts/systems/lang.gd", "assets/fonts", "scripts/ui/hud.gd"],
    "dialogue": ["scripts/npc/dialogue.gd", "scripts/npc/townsperson_bot.gd", "scripts/npc/npc_social.gd"],
    "friendship": ["scripts/autoload/friendship.gd", "scripts/ui/npc_card.gd"],
    "shop_hours": ["scripts/systems/shop_hours.gd", "scripts/world/interior/interior_item.gd", "scripts/world/town/market_area.gd"],
    "voices": ["scripts/npc/voice_blips.gd", "assets/audio/voice"],
    "npc_card": ["scripts/ui/npc_card.gd"],
    "needs": ["scripts/autoload/needs.gd", "scripts/ui/needs_hud.gd", "scripts/player/player.gd"],
    "illnesses": ["scripts/autoload/needs.gd", "scripts/world/interior/interior_item.gd"],
    "ingredients": ["scripts/systems/cooking.gd", "scripts/systems/shops.gd", "scripts/autoload/game_data.gd"],
    "dishes": ["scripts/systems/cooking.gd", "scripts/ui/cooking_panel.gd"],
    "cooking": ["scripts/systems/cooking.gd", "scripts/ui/cooking_panel.gd", "scripts/world/interior/cooking_station.gd"],
    # v5c
    "market_economy": ["scripts/autoload/market.gd", "scripts/autoload/economy.gd", "scripts/systems/shops.gd", "scripts/ui/shop_panel.gd"],
    "producers": ["scripts/autoload/market.gd", "scripts/systems/shops.gd", "scripts/autoload/game_data.gd"],
    "wages": ["scripts/autoload/market.gd"],
    "price_board": ["scripts/world/town/price_board.gd", "scripts/ui/prices_panel.gd"],
    "livestock": ["scripts/autoload/ranch.gd", "scripts/world/ranch", "scripts/ui/livestock_panel.gd", "scripts/autoload/game_data.gd"],
    "animal_housing": ["scripts/autoload/ranch.gd", "scripts/world/ranch", "scripts/ui/livestock_panel.gd"],
    # v5d
    "netcode": ["scripts/net/net.gd", "scripts/net/net_server.gd", "scripts/net/net_move.gd", "scripts/net/remote_avatars.gd", "scripts/net/remote_avatar.gd"],
    "chat": ["scripts/net/net.gd", "scripts/net/net_server.gd", "scripts/ui/net_hud.gd"],
    "live_updates": ["scripts/net/module_manifest.gd", "scripts/net/net.gd", "tools/push_module.py", "data/module_manifest.json"],
    "save_sync": ["scripts/net/save_sync.gd", "scripts/net/net.gd", "scripts/autoload/save_game.gd"],
    "away_avatar": ["scripts/net/net_server.gd", "scripts/net/remote_avatars.gd", "scripts/net/remote_avatar.gd",
                    "scripts/net/tea_visit_controller.gd", "scripts/net/away_memory.gd", "scripts/npc/dialogue.gd"],
    "accounts": ["scripts/net/net.gd", "scripts/net/net_server.gd"],
    "npc_roles": ["scripts/net/net_server.gd", "scripts/net/tea_visit_controller.gd", "scripts/net/remote_avatars.gd"],
    # v6a
    "night_sky": ["scripts/v6a/night_sky.gd", "assets/shaders/sky_clouds.gdshader", "scripts/world/day_night_cycle.gd"],
    "real_clock": ["scripts/v6a/night_sky.gd", "scripts/autoload/time_manager.gd", "scripts/ui/settings_panel.gd"],
    "dry_trees": ["scripts/v6a/dry_trees.gd", "scripts/v6a/lifestyle.gd", "scripts/v6a/action_spot.gd", "scripts/player/tool_animator.gd"],
    "fishing_gear": ["scripts/player/fishing_minigame.gd", "scripts/systems/shops.gd"],
    "campfire": ["scripts/v6a/campfire.gd", "scripts/v6a/lifestyle.gd", "assets/audio/ambience/campfire_loop.ogg"],
    "deep_sea": ["scripts/player/fishing_minigame.gd", "scripts/v6a/fishing_boat.gd"],
    "boats": ["scripts/v6a/boats.gd", "scripts/v6a/fishing_boat.gd"],
    "sunbathing": ["scripts/v6a/sunbathing_beach.gd", "scripts/npc/schedule_controller.gd", "scripts/npc/townspeople.gd",
                   "scripts/visuals/humanoid_model_visual.gd"],
    "gym": ["scripts/v6a/gym.gd", "scripts/world/interior/interior_v6a.gd", "scripts/v6a/lifestyle.gd",
            "scripts/npc/schedule_controller.gd", "assets/audio/music"],
    "house_music": ["scripts/v6a/house_music.gd", "assets/audio/music"],
    "kitchenware": ["scripts/v6a/kitchenware.gd", "scripts/systems/cooking.gd", "scripts/systems/shops.gd"],
    "hypermarket": ["scripts/world/interior/interior_v6a.gd", "scripts/systems/shops.gd", "scripts/world/town/town_layout.gd"],
    "ui_text": ["scripts/systems/lang.gd", "scripts/ui/top_bar.gd", "scripts/ui/settings_panel.gd", "scripts/components/interactable.gd",
                "scripts/ui/controls_menu.gd", "scripts/v6b/sign_text.gd"],
    # v6b
    "character_creator": ["scripts/v6b/character_creator.gd", "scripts/v6b/character_look.gd", "scripts/visuals/humanoid_model_visual.gd",
                          "scripts/player/player.gd", "scripts/v6b/v6b_world.gd"],
    "wardrobe": ["scripts/v6b/wardrobe.gd", "scripts/v6b/character_look.gd", "scripts/world/interior/interior_v6b.gd"],
    "npc_looks": ["scripts/v6b/npc_looks.gd", "scripts/npc/townspeople.gd", "scripts/npc/townsperson_bot.gd",
                  "scripts/visuals/humanoid_model_visual.gd"],
    "vehicles": ["scripts/v6b/vehicles/vehicle_kit.gd", "scripts/v6b/vehicles/drivable_car.gd", "scripts/v6b/vehicles/vehicles.gd",
                 "scripts/world/town/town_builder.gd"],
    "ambulance": ["scripts/v6b/vehicles/ambulance_service.gd", "scripts/v6b/vehicles/road_car.gd", "scripts/autoload/needs.gd"],
    "police_patrol": ["scripts/v6b/vehicles/police_patrol.gd", "scripts/v6b/vehicles/road_car.gd"],
    "wood_pickup": ["scripts/v6b/vehicles/wood_pickup.gd", "scripts/v6b/vehicles/road_car.gd", "scripts/v6a/dry_trees.gd"],
    "gas_stove": ["scripts/world/interior/gas_flame.gd", "scripts/world/interior/cooking_station.gd", "scripts/world/interior/kitchen_builder.gd"],
    "fridge": ["scripts/world/interior/fridge_unit.gd", "scripts/world/interior/interior_item.gd", "scripts/world/interior/kitchen_builder.gd"],
    "living_room": ["scripts/world/interior/interior_v6b.gd", "scripts/world/interior/movable_sofa.gd", "scripts/world/interior/interior_builder.gd"],
    "house_colors": ["scripts/v6b/house_colors.gd", "scripts/world/props/building.gd"],
    "landmark": ["scripts/v6b/town/town_landmark.gd"],
    "fruit_gardens": ["scripts/v6b/town/fruit_gardens.gd", "scripts/v6b/world_memory.gd"],
    "town_lots": ["scripts/v6b/town/town_lots.gd", "scripts/world/props/building.gd"],
    "pushables": ["scripts/v6b/yard/pushables.gd"],
    "herding": ["scripts/v6b/yard/herding.gd", "scenes/animals/Sheep.tscn"],
    "digging": ["scripts/v6b/yard/digging.gd"],
    "yard_routine": ["scripts/v6b/yard/yard_routine.gd", "scripts/world/farm_plot.gd"],
    "world_memory": ["scripts/v6b/world_memory.gd", "scripts/autoload/save_game.gd", "scripts/net/save_sync.gd"],
    "shadows": ["scripts/v6b/sky/shadow_rig.gd", "scripts/ui/settings_panel.gd"],
    "cloud_shadows": ["scripts/v6b/sky/cloud_shadows.gd", "assets/shaders/cloud_shadow.gdshaderinc",
                      "assets/shaders/seasonal_terrain.gdshader", "assets/shaders/seasonal_grass.gdshader"],
    "sea_horizon": ["assets/shaders/sky_clouds.gdshader", "scripts/world/day_night_cycle.gd"],
    # v7a
    "backstories": ["scripts/v7a/backstories.gd", "scripts/npc/dialogue.gd", "scripts/ui/npc_card.gd"],
    "kids": ["scripts/v7a/kids_play.gd", "scripts/v7a/v7a_kit.gd"],
    "conflicts": ["scripts/v7a/conflicts.gd", "scripts/v7a/v7a_kit.gd", "scripts/autoload/friendship.gd"],
    "possession": ["scripts/v7a/possession.gd", "scripts/v7a/confirm_dialog.gd", "scripts/v7a/city_state.gd"],
    "fire": ["scripts/v7a/fire_service.gd", "scripts/v7a/building_damage.gd", "scripts/world/props/building.gd"],
    "outages": ["scripts/v7a/outages.gd", "scripts/autoload/power_grid.gd"],
    "city_fund": ["scripts/v7a/city_fund.gd", "scripts/v7a/city_fund_panel.gd", "scripts/v7a/city_state.gd",
                  "scripts/autoload/needs.gd", "scripts/autoload/save_game.gd"],
    # v7b
    "chatter": ["scripts/v7b/chatter.gd", "scripts/v7b/chat_log_panel.gd", "scripts/v7b/v7b_kit.gd", "scripts/v7b/town_life.gd"],
    "cafe": ["scripts/v7b/terrace_cafe.gd", "scripts/v7b/cafe_menu_panel.gd", "scripts/v7b/tipsy.gd", "scripts/v7b/staffing.gd",
             "scripts/player/player.gd"],
    "mechanic": ["scripts/v7b/mechanic_shop.gd", "scripts/v7b/mechanic_panel.gd", "scripts/v7b/staffing.gd"],
    "driving": ["scripts/v7b/driving.gd", "scripts/v7b/car_systems.gd", "scripts/v6b/vehicles/drivable_car.gd", "scripts/ui/hud.gd"],
    "passengers": ["scripts/v7b/passengers.gd"],
    "camping": ["scripts/v7b/camping.gd"],
    "newspaper": ["scripts/v7b/newspaper.gd", "scripts/v7b/newspaper_panel.gd", "scripts/v7b/town_life.gd", "scripts/autoload/save_game.gd"],
    "personalities": ["scripts/v7b/personalities.gd", "scripts/v7b/haggle_panel.gd", "scripts/v7a/conflicts.gd"],
    "voice_profiles": ["scripts/v7b/voice_profiles.gd", "scripts/npc/voice_blips.gd"],
    # v7b.1 controls patch (shared input layer: ControlInput)
    "controls_mouse": ["scripts/v7b1/control_input.gd", "scripts/camera/follow_camera.gd", "scripts/player/player.gd",
                       "scripts/v6b/vehicles/drivable_car.gd", "scripts/v7b1/cockpit_camera.gd", "scripts/v7b1/controls_world.gd"],
    "controls_touch": ["scripts/v7b1/control_input.gd", "scripts/v7b1/touch_controls.gd", "scripts/v7a/possession.gd"],
    "controls_keyboard": ["scripts/v7b1/control_input.gd", "scripts/ui/controls_menu.gd", "scripts/v7b1/controls_help.gd"],
    # v7b.1 visual pass
    "car_bodies": ["scripts/v7b1_visual/car_body.gd", "scripts/v7b1_visual/steering_wheel.gd", "scripts/v6b/vehicles/vehicle_kit.gd"],
    "resident_looks": ["scripts/v7b1_visual/resident_looks.gd", "scripts/npc/townspeople.gd", "scripts/autoload/save_game.gd"],
    "door_plaques": ["scripts/v7b1_visual/door_plaques.gd", "scripts/v7b1_visual/home_marker.gd", "scripts/world/props/building.gd"],
    "house_variety": ["scripts/v7b1_visual/house_variety.gd", "scripts/world/props/building.gd"],
    "street_plants": ["scripts/v7b1_visual/street_plants.gd", "scripts/world/town/town_builder.gd"],
    "fire_truck": ["scripts/v7b1_visual/fire_siren.gd", "scripts/v7a/fire_service.gd"],
    "city_hall_interior": ["scripts/v7b1_visual/city_hall_interior.gd", "scripts/v7a/city_fund.gd"],
    "families": ["scripts/v7b1_visual/families.gd", "scripts/ui/people_panel.gd", "scripts/ui/npc_card.gd"],
    # v7b.1 traffic
    "traffic_rules": ["scripts/v7b1_traffic/traffic_kit.gd", "scripts/v7b1_traffic/traffic_signals.gd", "scripts/v7b1_traffic/traffic_rules.gd", "scripts/v7b1_traffic/new_city_road.gd", "scripts/v6b/vehicles/road_car.gd"],
    "road_markings": ["scripts/v7b1_traffic/road_markings.gd"],
    "traffic_signs": ["scripts/v7b1_traffic/traffic_signs.gd"],
    "driving_license": ["scripts/v7b1_traffic/license_office.gd", "scripts/v7b1_traffic/license_panel.gd", "scripts/v7b1_traffic/impound.gd", "scripts/v7b1_traffic/traffic_state.gd"],
    "car_dealership": ["scripts/v7b1_traffic/dealership.gd", "scripts/v7b1_traffic/dealership_panel.gd"],
    "npc_traffic": ["scripts/v7b1_traffic/npc_traffic.gd", "scripts/v7b1_traffic/traffic_rules.gd"],
    "transit": ["scripts/v7b1_traffic/transit.gd", "scripts/v7b1_traffic/bus_model.gd", "scripts/v7b1_traffic/drivable_bus.gd"],
    "car_sounds": ["scripts/v7b1_traffic/car_audio.gd"],
    "cafe_lounge": ["scripts/v7b1_traffic/cafe_lounge.gd", "scripts/v7b/terrace_cafe.gd"],
    "street_lighting": ["scripts/v7b1_traffic/street_lighting.gd"],
    # v7b.1 performance refresh
    "quality": ["scripts/v7b1_perf/perf_quality.gd", "scripts/v7b1_perf/auto_lod.gd", "scripts/v7b1_perf/perf_world.gd", "scripts/ui/settings_panel.gd", "scripts/npc/townsperson_bot.gd"],
    "world_stream": ["scripts/v7b1_perf/world_streamer.gd", "scripts/v7b1_perf/interior_streamer.gd", "scripts/world/props/building.gd"],
    "lod_rules": ["scripts/v7b1_perf/auto_lod.gd"],
    "audio_budget": ["scripts/v7b1_perf/audio_budget.gd", "scripts/v7b1_perf/anim_budget.gd"],
    # v7b.1 audio
    "spatial_audio": ["scripts/v7b1_audio/audio_world.gd", "scripts/v7b1_audio/spatial_listener.gd"],
    "sound_fx": ["scripts/v7b1_audio/footstep_audio.gd", "scripts/v7b1_audio/door_audio.gd", "scripts/player/player.gd", "scripts/world/props/door.gd"],
    "ambient_sounds": ["scripts/v7b1_audio/ambient_emitters.gd", "scripts/audio/ambience_manager.gd", "scripts/world/beach/beach_builder.gd"],
    # v7b.1 police / road safety
    "road_safety": ["scripts/v7b1_police/road_safety.gd", "scripts/v7b1_police/accident_response.gd", "scripts/v7b1_police/hit_controller.gd",
                    "scripts/v7b1_police/police_world.gd", "scripts/v6b/vehicles/road_car.gd", "scripts/npc/townsperson_bot.gd"],
}
# Smoke-test sections that cover each module type.
SECTIONS = {
    "crop_types": "v4: crop modules / garden / season hook", "garden": "v4: crop modules / garden / season hook",
    "garden_rules": "v4: crop modules / garden / season hook", "tool_types": "v4: tools",
    "lighting": "v4: night lights / farmhouse lamp / electricity", "power": "v4: night lights / farmhouse lamp / electricity",
    "yards": "v4: yards / minimap / landscape", "minimap": "v4: yards / minimap / landscape",
    "landscape": "v4: yards / minimap / landscape", "npc_social": "v4: NPC social life",
    "house_styles": "v4: house styles + v5a: live house + yard style swap",
    # v5a
    "crafting": "v5a: workshop crafting", "recipes": "v5a: workshop crafting + kitchen",
    "market": "v5a: central market", "town_square": "v5a: ornate town square",
    "population": "v5a: townsfolk identities + families", "workplaces": "v5a: workplaces + shops",
    "civic": "v5a: civic buildings", "mosque": "v5a: mosque adhan + church bells + v5b: mosque dome polish",
    "church": "v5a: mosque adhan + church bells", "kitchen": "v5a: kitchen + stove in every home",
    "gestures": "v5a: NPC wave",
    # v5b
    "fonts": "v5b: Persian font", "dialogue": "v5b: dialogue + friendship + language",
    "friendship": "v5b: dialogue + friendship + language + NPC card", "shop_hours": "v5b: shop hours",
    "voices": "v5b: voice blips", "npc_card": "v5b: NPC card", "needs": "v5b: needs + illness + doctor",
    "illnesses": "v5b: needs + illness + doctor", "ingredients": "v5b: hands-on cooking",
    "dishes": "v5b: hands-on cooking", "cooking": "v5b: hands-on cooking",
    # v5c
    "market_economy": "v5c: living economy", "producers": "v5c: producers + workplace roles",
    "wages": "v5c: wages, meals and the doctor", "price_board": "v5c: market prices board + panel",
    "livestock": "v5c: livestock via the carpenter", "animal_housing": "v5c: livestock via the carpenter",
    # v5d (+ the network test, which always runs)
    "netcode": "v5d: multiplayer foundation", "chat": "v5d: text chat", "live_updates": "v5d: live modular updates",
    "save_sync": "v5d: save sync + offline", "away_avatar": "v5d: disconnect / reconnect",
    "accounts": "v5d: guest accounts", "npc_roles": "v5d: NPC role takeover groundwork",
    # v6a
    "night_sky": "v6a: night sky + real clock", "real_clock": "v6a: night sky + real clock",
    "dry_trees": "v6a: dry trees + axe", "fishing_gear": "v6a: fishing rod, campfire, fish dishes",
    "campfire": "v6a: fishing rod, campfire, fish dishes", "deep_sea": "v6a: boats + deep-sea fishing",
    "boats": "v6a: boats + deep-sea fishing", "sunbathing": "v6a: sunbathing beach",
    "gym": "v6a: town gym + music from houses", "house_music": "v6a: town gym + music from houses",
    "kitchenware": "v6a: kitchenware at the hypermarket", "hypermarket": "v6a: kitchenware at the hypermarket",
    "ui_text": "v6a: Persian UI + v6b: polish",
    # v6b
    "character_creator": "v6b: character creator + wardrobe + NPC looks", "wardrobe": "v6b: character creator + wardrobe + NPC looks",
    "npc_looks": "v6b: character creator + wardrobe + NPC looks", "vehicles": "v6b: drivable cars",
    "ambulance": "v6b: ambulance", "police_patrol": "v6b: police patrol", "wood_pickup": "v6b: wood pickup",
    "gas_stove": "v6b: richer interiors", "fridge": "v6b: richer interiors", "living_room": "v6b: richer interiors",
    "house_colors": "v6b: richer interiors", "landmark": "v6b: town landmark + fruit gardens + lots",
    "fruit_gardens": "v6b: town landmark + fruit gardens + lots", "town_lots": "v6b: town landmark + fruit gardens + lots",
    "pushables": "v6b: yard (boxes, herding, digging, routine)", "herding": "v6b: yard (boxes, herding, digging, routine)",
    "digging": "v6b: yard (boxes, herding, digging, routine)", "yard_routine": "v6b: yard (boxes, herding, digging, routine)",
    "world_memory": "v6b: world memory", "shadows": "v6b: shadows + cloud shadows", "cloud_shadows": "v6b: shadows + cloud shadows",
    "sea_horizon": "v6b: polish (gym, translations, horizon)",
    # v7a
    "backstories": "v7a: NPC backstories + memory", "kids": "v7a: kids play, bike, chat, ring-and-run",
    "conflicts": "v7a: social conflict (arguments)", "possession": "v7a: possess a townsperson (dig / demolish / fire)",
    "fire": "v7a: fire & emergencies", "outages": "v7a: power outages + earthquakes", "city_fund": "v7a: city fund + public works",
    # v7b
    "chatter": "v7b: chattier town (remarks, reactions, overheard chats, chat log)",
    "cafe": "v7b: terrace cafe (bartender, DJ, drinks, tipsiness, fights, stand-ins)",
    "mechanic": "v7b: mechanic (repairs, fuel, upgrades, stand-in)", "driving": "v7b: gears, headlights, fuel, wear, night driving",
    "passengers": "v7b: passengers", "camping": "v7b: camping trip", "newspaper": "v7b: daily newspaper",
    "personalities": "v7b: distinct voices + personalities", "voice_profiles": "v7b: distinct voices + personalities",
    "controls_mouse": "v7b.1 controls: mouse look / steering, cockpit camera", "controls_touch": "v7b.1 controls: touch twin sticks + buttons",
    "controls_keyboard": "v7b.1 controls: keyboard fallback + F1 Mouse & Touch tab",
    "car_bodies": "v7b.1 visual: realistic cars", "resident_looks": "v7b.1 visual: resident looks",
    "door_plaques": "v7b.1 visual: plaques, houses, home on the minimap", "house_variety": "v7b.1 visual: plaques, houses, home on the minimap",
    "street_plants": "v7b.1 visual: square, street plants", "fire_truck": "v7b.1 visual: red fire truck",
    "city_hall_interior": "v7b.1 visual: City Hall interior with the fund", "families": "v7b.1 visual: families",
    "traffic_rules": "v7b.1 traffic: signal cycles / offences", "road_markings": "v7b.1 traffic: wider roads, markings, signs",
    "traffic_signs": "v7b.1 traffic: wider roads, markings, signs", "driving_license": "v7b.1 traffic: licence booklet + quiz",
    "car_dealership": "v7b.1 traffic: car dealership", "npc_traffic": "v7b.1 traffic: NPC cars on loops obey limits",
    "transit": "v7b.1 traffic: bus stops, NPC bus, residents ride", "car_sounds": "v7b.1 traffic: per-model car sounds",
    "cafe_lounge": "v7b.1 traffic: classy terrace + lounge / night disco", "street_lighting": "v7b.1 traffic: brighter night streets",
    "quality": "v7b.1 perf: quality presets", "world_stream": "v7b.1 perf: world streaming + interiors",
    "lod_rules": "v7b.1 perf: distance LOD", "audio_budget": "v7b.1 perf: audio / animation budgets",
    "spatial_audio": "v7b.1 audio: listener follows the camera, stereo panning", "sound_fx": "v7b.1 audio: surface footsteps",
    "ambient_sounds": "v7b.1 audio: placed ambient emitters",
    "road_safety": "v7b.1 police: AI cars yield to people, hit reactions, ambulance + police + crowd",
}
PUBLISHED_MANIFEST = Path("/workspace/farm-published-manifest.json")
LAST_PUBLISHED_PROJECT = Path("/workspace/farm-prototype-v7b")  # v7b is live before v7b1


def _files_under(root: Path, rel: str) -> list:
    p = root / rel
    if p.is_file():
        return [p]
    if p.is_dir():
        return sorted(x for x in p.rglob("*") if x.is_file() and not x.name.endswith((".import", ".uid")))
    return []


def module_hashes(root: Path = ROOT) -> dict:
    out = {}
    for t in MODULE_TYPES:
        files = _files_under(root, "modules/" + t)
        for c in CONSUMERS.get(t, []):
            files += _files_under(root, c)
        out[t] = sorted({(str(f.relative_to(root)), sha_of(f)) for f in files})
        out[t] = [list(x) for x in out[t]]
    cfg = root / "data" / "asset_modules.json"
    out["_registry"] = [[str(cfg.relative_to(root)), sha_of(cfg)]] if cfg.exists() else []
    return out


def baseline() -> tuple[dict, str]:
    if PUBLISHED_MANIFEST.exists():
        m = json.loads(PUBLISHED_MANIFEST.read_text())
        return m.get("module_hashes", {}), "published manifest %s (%s)" % (PUBLISHED_MANIFEST, m.get("commit", "?")[:10])
    if LAST_PUBLISHED_PROJECT.exists():
        return module_hashes(LAST_PUBLISHED_PROJECT), "last published project %s" % LAST_PUBLISHED_PROJECT
    return {}, "(none)"


def detect_changed(prev: dict) -> list:
    cur = module_hashes()
    changed = []
    for t in MODULE_TYPES + ["_registry"]:
        if cur.get(t) != prev.get(t):
            changed.append(t)
    return changed


def step_compile() -> bool:
    log("\n=== COMPILE CHECK ===")
    r = run([GODOT, "--headless", "--path", str(ROOT), "-s", "res://tools/compile_check.gd"], timeout=180)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    ok = r.returncode == 0 and "0 failed" in r.stdout
    log("COMPILE: " + ("PASS" if ok else "FAIL"))
    return ok


SMOKE_RESULT: dict = {}


def step_smoke() -> bool:
    log("\n=== SMOKE TEST ===")
    r = run([GODOT, "--headless", "--path", str(ROOT), "--", "--smoke-test"], timeout=900)
    # Keep the last 80 lines of the smoke report.
    lines = (r.stdout + r.stderr).splitlines()
    Path("/workspace/farm-full-smoke-last.log").write_text(r.stdout + r.stderr)
    for line in lines:
        if line.startswith("-- ") or "[FAIL]" in line or line.startswith("SMOKE ") or "SCRIPT ERROR" in line or line.startswith("ERROR:"):
            log(line)
    ok = (r.returncode == 0 and any("SMOKE TEST PASSED" in l for l in lines)
          and not any("SCRIPT ERROR:" in l for l in lines))
    for l in lines:
        m = re.search(r"SMOKE TEST: (\d+) checks, (\d+) failed", l)
        if m:
            SMOKE_RESULT.update({"checks": int(m.group(1)), "failed": int(m.group(2))})
    # Known leak noise is not a failure.
    log("SMOKE: " + ("PASS" if ok else "FAIL"))
    return ok


def step_manifest() -> bool:
    log("\n=== MODULE MANIFEST ===")
    r = run([sys.executable, "tools/build_manifest.py", "--check"], timeout=60)
    sys.stdout.write(r.stdout)
    ok = r.returncode == 0
    log("MANIFEST: " + ("PASS" if ok else "FAIL (run tools/build_manifest.py)"))
    return ok


NET_RESULT: dict = {}


def step_net() -> bool:
    log("\n=== NETWORK TEST (server + 2 clients) ===")
    r = run([sys.executable, "tools/net_test.py"], timeout=900)
    out = r.stdout + r.stderr
    for line in out.splitlines():
        if line.startswith("==") or "[FAIL]" in line or line.startswith("NET TEST") or "failed:" in line:
            log(line)
    m = re.search(r"NET TEST: (\d+) checks, (\d+) failed", out)
    NET_RESULT.update({"checks": int(m.group(1)) if m else 0, "failed": int(m.group(2)) if m else -1})
    ok = r.returncode == 0 and "NET TEST PASSED" in out
    log("NET: " + ("PASS" if ok else "FAIL"))
    return ok


def step_web_export(web_build: Path, web_out: Path) -> bool:
    log("\n=== WEB EXPORT ===")
    # Sync + patch.
    r = run([sys.executable, "tools/make_webbuild.py", str(web_build), str(web_out)], timeout=120)
    sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
    if r.returncode != 0:
        log("WEB EXPORT: FAIL (make_webbuild)")
        return False
    # Confirm Compatibility + convert_text_resources_to_binary=false.
    proj = (web_build / "project.godot").read_text()
    if 'renderer/rendering_method="gl_compatibility"' not in proj:
        log("WEB EXPORT: FAIL (Compatibility renderer not set)")
        return False
    if "export/convert_text_resources_to_binary=false" not in proj:
        log("WEB EXPORT: FAIL (convert_text_resources_to_binary must stay false)")
        return False
    # Import then export.
    r = run([GODOT, "--headless", "--path", str(web_build), "--import"], timeout=600)
    if r.returncode != 0:
        log("WEB EXPORT: FAIL (import)")
        sys.stderr.write(r.stderr[-2000:])
        return False
    web_out.mkdir(parents=True, exist_ok=True)
    r = run([GODOT, "--headless", "--path", str(web_build), "--export-release", "Web",
             str(web_out / "index.html")], timeout=900)
    # Godot prints progress to stderr; success ends with "failed: 0" or exit 0 + index.pck.
    pck = web_out / "index.pck"
    ok = r.returncode == 0 and pck.exists() and pck.stat().st_size > 1_000_000
    if not ok:
        sys.stderr.write((r.stdout + r.stderr)[-3000:])
    log("WEB EXPORT: %s (index.pck %s bytes)" % ("PASS" if ok else "FAIL",
                                                 pck.stat().st_size if pck.exists() else 0))
    return ok


def step_chrome(web_out: Path, port: int = 0) -> bool:
    log("\n=== HEADLESS CHROME ===")
    if not PWVENV.exists():
        log("WEB CHROME: FAIL (no /tmp/pwvenv)")
        return False
    # Serve the build.
    if port == 0:
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            port = listener.getsockname()[1]
    srv = subprocess.Popen([sys.executable, "-u", "-m", "http.server", str(port)],
                           cwd=web_out, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    try:
        time.sleep(0.8)
        out_png = Path("/workspace/farm-v7b1-web-local.png")
        test = Path("/tmp/webtest_v7b1_gate.py")
        test.write_text('''import asyncio, time, sys, shutil
from playwright.async_api import async_playwright
URL = sys.argv[1]; OUT = sys.argv[2]; WAIT = int(sys.argv[3]) if len(sys.argv) > 3 else 22000
async def main():
    async with async_playwright() as p:
        browser = await p.chromium.launch(executable_path=shutil.which("chromium") or shutil.which("google-chrome"), headless=True, args=[
            "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist",
            "--enable-webgl", "--use-gl=angle", "--no-sandbox", "--autoplay-policy=user-gesture-required"])
        logs = []
        page = await browser.new_page(viewport={"width": 640, "height": 360})
        t0 = time.time()
        page.on("console", lambda m: logs.append((round(time.time()-t0,1), m.type, m.text)))
        page.on("pageerror", lambda e: logs.append((round(time.time()-t0,1), "pageerror", str(e))))
        sockets = []
        foreign = []
        page.on("websocket", lambda w: sockets.append(w.url))
        page.on("request", lambda r: foreign.append(r.url) if not r.url.startswith(URL.rstrip("/")) and not r.url.startswith("data:") and not r.url.startswith("blob:") else None)
        await page.goto(URL, wait_until="load")
        await page.wait_for_timeout(WAIT)
        async def enter_game():
            # v7b.1 entry flow (splash -> menu -> Play -> Single-player -> loading):
            # Enter skips the splash / presses the default button until the game logs it is in.
            await page.mouse.click(5, 5)  # focus the canvas on an empty corner
            await page.wait_for_timeout(400)
            for _ in range(8):
                if any("ENTRY: in game" in l[2] for l in logs[mark[0]:]):
                    return True
                await page.keyboard.press("Enter")
                await page.wait_for_timeout(900)
            deadline = time.time() + 90
            while time.time() < deadline and not any("ENTRY: in game" in l[2] for l in logs[mark[0]:]):
                await page.wait_for_timeout(500)
            return any("ENTRY: in game" in l[2] for l in logs[mark[0]:])
        mark = [0]
        entered1 = await enter_game()
        print("entry flow -> single-player:", entered1)
        await page.wait_for_timeout(1500)
        await page.mouse.click(320, 180)
        await page.keyboard.down("KeyW"); await page.wait_for_timeout(1200); await page.keyboard.up("KeyW")
        await page.wait_for_timeout(5000)
        await page.screenshot(path=OUT)
        errs = [l for l in logs if l[1] in ("error", "pageerror")
                and "AudioWorklet" not in l[2] and "AudioContext" not in l[2]
                and "ALSA" not in l[2]]
        print("console errors:", len(errs), "| messages:", len(logs))
        for l in errs: print("   ", l)
        for l in logs[:12]: print("    log:", l)
        # Web save must survive a page reload (v3 bug): F5, reload, F9.
        await page.mouse.click(320, 180)
        await page.wait_for_timeout(800)
        await page.keyboard.press("F5")
        await page.wait_for_timeout(2500)
        probe = "() => { try { return (localStorage.getItem('farm_prototype_save') || '').length; } catch(e){ return -1; } }"
        saved = await page.evaluate(probe)
        print("save in browser storage after F5:", saved, "bytes")
        n0 = len(logs)
        await page.reload(wait_until="load")
        await page.wait_for_timeout(WAIT)
        mark[0] = n0
        entered2 = await enter_game()
        print("entry flow after reload -> single-player:", entered2)
        await page.wait_for_timeout(1500)
        after = await page.evaluate(probe)
        print("save still there after reload:", after, "bytes")
        await page.mouse.click(320, 180)
        await page.wait_for_timeout(800)
        await page.keyboard.press("F9")
        await page.wait_for_timeout(2000)
        loaded = any("SaveGame: loaded" in l[2] for l in logs[n0:])
        print("F9 after reload loads the save:", loaded)
        errs2 = [l for l in logs[n0:] if l[1] in ("error", "pageerror")]
        print("console errors after reload:", len(errs2))
        for l in errs2: print("   ", l)
        await page.screenshot(path=OUT.replace(".png", "-reload-f9.png"))
        await browser.close()
        print("websockets opened (must be 0, offline by default):", len(sockets), sockets[:3])
        print("requests to other hosts (must be 0):", len(foreign), foreign[:3])
        ok = entered1 and entered2 and len(errs) == 0 and len(errs2) == 0 and saved > 100 and after == saved and loaded and not sockets and not foreign
        sys.exit(0 if ok else 1)
asyncio.run(main())
''')
        r = run([str(PWVENV), "-u", str(test), f"http://127.0.0.1:{port}/", str(out_png), "22000"],
                timeout=420)
        sys.stdout.write(r.stdout); sys.stderr.write(r.stderr)
        ok = r.returncode == 0
        log("CHROME: " + ("PASS" if ok else "FAIL"))
        return ok
    finally:
        srv.terminate()
        try:
            srv.wait(timeout=3)
        except Exception:
            srv.kill()


def main() -> int:
    args = sys.argv[1:]
    skip_web = "--skip-web" in args
    skip_chrome = "--skip-chrome" in args
    skip_smoke = "--skip-smoke" in args
    skip_net = "--skip-net" in args
    web_out = Path(args[args.index("--web-out") + 1]) if "--web-out" in args else DEFAULT_WEB_OUT
    web_build = Path(args[args.index("--web-build") + 1]) if "--web-build" in args else DEFAULT_WEB_BUILD

    log("TEST GATE: Farm Prototype v7b1 (v7b.1 controls patch)")
    log("project: %s" % ROOT)
    prev, where = baseline()
    changed = detect_changed(prev)
    log("baseline: " + where)
    log("modules changed since last published: %s" % (", ".join(changed) if changed else "(none)"))
    for t in changed:
        if t in SECTIONS:
            log("  re-tested by smoke section: %-14s -> %s" % (t, SECTIONS[t]))
        elif t != "_registry":
            log("  re-tested by smoke section: %-14s -> asset modules (registry + runtime swap)" % t)
    log("the FULL suite always runs (manifest + compile + smoke + network test + web export + Chrome)")

    failures = []
    if not step_compile():
        failures.append("compile")
    if not step_manifest():
        failures.append("manifest")
    if not skip_smoke and not step_smoke():
        failures.append("smoke")
    if not skip_net and not step_net():
        failures.append("net")
    if not skip_web and not step_web_export(web_build, web_out):
        failures.append("web-export")
    elif not skip_web and not skip_chrome and not step_chrome(web_out):
        failures.append("chrome")

    report = {
        "ok": not failures,
        "failures": failures,
        "changed_modules": changed,
        "module_hashes": module_hashes(),
        "web_out": str(web_out),
        "web_pck_sha256": sha_of(web_out / "index.pck") if (web_out / "index.pck").exists() else None,
        "web_pck_bytes": (web_out / "index.pck").stat().st_size if (web_out / "index.pck").exists() else 0,
        "when": time.strftime("%Y-%m-%d %H:%M:%S"),
        "smoke": SMOKE_RESULT,
        "net": NET_RESULT,
    }
    STATE.write_text(json.dumps(report, indent=2))
    log("\n=== GATE RESULT: %s ===" % ("PASS" if report["ok"] else "FAIL (" + ", ".join(failures) + ")"))
    log("state written to %s" % STATE)
    return 0 if report["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
