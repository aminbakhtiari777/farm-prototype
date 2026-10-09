# Asset modules

Every *kind* of asset in the game (trees, rocks, terrain, buildings, characters, ...) is a **module**: a small
`Resource` that describes one *style* of that asset type. Gameplay code never hard-codes asset paths. It asks the
registry for the active style and reads its fields.

```
res://modules/
  asset_module.gd            # AssetModule base class (interface)
  <type>/<type>_style.gd     # typed style class for this asset type (fields + helpers)
  <type>/<variant>.tres      # one file per style variant
res://data/asset_modules.json   # central config: active variant + all variants per type
res://scripts/autoload/asset_registry.gd   # AssetRegistry autoload (loads/caches/swaps)
res://scripts/util/modules.gd              # Modules.style(type) / Modules.on_swap(type, owner, fn)
tools/gen_modules.py                       # regenerates the .tres variants + the JSON config
```

## Interface

`AssetModule` (all modules):

| Member | Meaning |
| --- | --- |
| `id`, `type`, `display_name`, `description` | identification |
| `get_variant(season) -> Dictionary` | per-season parameters (`{}` if the type has none) |
| `asset_paths() -> PackedStringArray` | every file the module depends on |
| `validate() -> PackedStringArray` | missing files (empty = OK) |

`AssetRegistry` (autoload, loaded first):

| Method / signal | Meaning |
| --- | --- |
| `types()`, `variants(type)`, `active_id(type)` | what is registered |
| `get_module(type)` | the active style (cached) |
| `load_variant(type, id)` | any variant |
| `set_active(type, id) -> bool` | runtime swap, emits `module_changed(type, module)` |
| `validate_all() -> Dictionary` | `{"type/id": [missing paths]}` for broken variants |

Consumers use `Modules.style("trees") as TreeStyle` (also works in the editor / without the autoload) and
`Modules.on_swap("trees", self, func(m): ...)` to restyle live.

## Registered modules

| Type | Style class | Variants (default first) | Consumers | Swap |
| --- | --- | --- | --- | --- |
| `terrain` | `TerrainStyle` (material_path, shader_overrides, colors) | `green_valley`, `dry_steppe` | `terrain.gd` | live (shader parameters) |
| `trees` | `TreeStyle` (model_dir/ext, broadleaf, pines, edge_models, dead_tree, pine_fraction, scale_range, leaf/pine tints per season, bare_in_winter) | `quaternius_mixed`, `pine_forest` | `nature_scatter.gd` | live (NatureScatter re-scatters) |
| `rocks` | `RockStyle` (kinds: model, count, min/max scale, collision radius) | `quaternius`, `mossy_boulders` | `nature_scatter.gd` ground cover | live |
| `plants` | `PlantStyle` (ground_cover kinds, grass height/width/density, flower colours) | `meadow`, `lush` | `nature_scatter.gd`, `beach_builder.gd` (beach grass) | live (nature); beach grass at build |
| `crops` | `CropStyle` (plant_scale, leaf_tint, fruit_tint) | `classic`, `giant` | `farm_plot.gd` | live (tiles refresh) |
| `fences` | `FenceStyle` (post spacing/height/size, rails, color, material_path) | `rustic_wood`, `white_picket` | `fence.gd` | live (fence rebuilds) |
| `buildings` | `BuildingStyle` (wall_tint, roof_palette, trim_color, shutter_palette) | `village`, `coastal` | `building.gd` | at build time (reload the scene) |
| `characters` | `CharacterStyle` (models per body type, skins, animation_library, hair_dir, outfit_shader, body_scale) | `quaternius_ubc`, `quaternius_ubc_tall` | `humanoid_model_visual.gd` (farmer + townspeople) | at build time (new characters / scene reload; `HumanoidModelVisual.clear_caches()`) |
| `animals` | `AnimalStyle` (scene_path, wool_color, face_color) | `white_sheep`, `black_sheep` | `sheep.gd` | live (colours) |
| `furniture` | `FurnitureStyle` (furniture/food/car dirs, parked cars) | `kenney`, `kenney_quiet_town` | `interior_builder.gd`, `carryable.gd`, `town_builder.gd` | at build time |
| `water` | `WaterStyle` (shader_path, sea params, pond params) | `atlantic`, `tropical` | `beach_builder.gd` | live (shader parameters) |
| `sky` | `SkyStyle` (day/dusk/night zenith + horizon colours) | `clear`, `pastel` | `day_night_cycle.gd` | live (next sky update) |

### v4 modules

Collection types (marked **C**) use *every* registered variant at once (each crop / tool / house style is its own
module file); `"active"` is only the default for tooling. Add a crop / tool / house style by dropping a `.tres` in its
folder and registering it under `variants` (or add a row in `tools/gen_modules_v4.py` and run it).

| Type | Style class | Variants (default first) | Consumers | Swap |
| --- | --- | --- | --- | --- |
| `crop_types` **C** | `CropDef` (seed/produce items, seasons, 4 stage lengths, yield, prices, footprint 0.5 / 1.0 m², shape root/tuber/bush/stalk/vine/tree/palm, colours, height, fruit size/count, regrow days) | turnip, carrot, potato, strawberry, tomato, corn, sunflower, pumpkin, eggplant, apple_tree, banana | `game_data.gd` (items + shop), `farm_plot.gd`, `crop_model_builder.gd` | live (GameData rebuilds) |
| `garden` | `GardenStyle` (soil dry/wet, path + edge colours, raised beds, fence height, expansion cost) | `rustic_rows`, `raised_beds` | `farm_plot.gd` | live (garden rebuilds) |
| `garden_rules` | `GardenRules` - the **season hook** (`can_plant`, `growth_multiplier`, `withers`) | `seasonal`, `any_season` | `farm_plot.gd`, `economy.gd` (shop) | live |
| `lighting` | `LightingStyle` (bulb/window colour, porch energy, on-before-sunset / off-after-sunrise, candle colour/energy, flicker) | `warm_bulbs`, `cool_led` | `night_lights.gd` (TimeManager-driven), `building.gd` | live |
| `power` | `PowerStyle` (breaker box / lever colours, fireplace, candles per home, lantern) | `breaker_panel`, `old_fuse_box` | `breaker_box.gd`, `interior_builder.gd`, `PowerGrid` autoload | live (breakers); candles at build |
| `yards` | `YardStyle` (rail / picket, wood colour, height, post spacing) | `rail_fence`, `picket` | `town_builder.gd` (front + back yards) | at build time |
| `minimap` | `MinimapStyle` (colours, size, metres shown) | `parchment`, `night` | `minimap.gd` | live |
| `npc_social` | `SocialStyle` (chat distance/chance/length, greet distance, stroll radius, lines, replies, greetings) | `chatty`, `quiet` | `npc_social.gd`, `schedule_controller.gd` | live |
| `landscape` | `LandscapeStyle` (forest rings/density/scale, far trees, mountain height/count/colour, snow line, river width/colour) | `highlands`, `lowlands` | `landscape.gd` | live (rebuilds) |
| `tool_types` **C** | `ToolDef` (item, kind, tier, animation, sound, prop shape/colours, price, starter, unlock day, requires, reach) | hoe, steel_hoe, watering_can, copper_can, seed_pouch, harvest_basket, hammer | `game_data.gd`, `economy.gd` (unlocks), `tool_animator.gd`, `farm_plot.gd` | live (GameData rebuilds) |
| `house_styles` **C** | `HouseStyle` (wooden / stone / modern: cladding pattern + colours, gable / flat roof, chimney, interior wall/floor, furniture choices) | wooden, stone, modern | `building.gd` (exterior, `house_cladding.gdshader`), `interior_builder.gd` | at build time |

## How to swap a style

* **Permanently:** change `"active"` for the type in `data/asset_modules.json`
  (e.g. `"trees": {"active": "pine_forest", ...}`), or edit `tools/gen_modules.py` and run `python3 tools/gen_modules.py`.
* **At runtime:** `AssetRegistry.set_active("trees", "pine_forest")`. Consumers marked *live* react immediately,
  *at build time* ones pick the new style up when the scene is reloaded.
* **New style:** add a `.tres` (or a dict entry in `tools/gen_modules.py`) in `modules/<type>/` and register it under
  `variants`. A completely different art pack = a new folder of models + one new variant pointing at it
  (e.g. `TreeStyle.model_dir` / `broadleaf` / `pines`).
* **New asset type:** subclass `AssetModule` in `modules/<type>/<type>_style.gd`, add variants + config entry, read it
  in the consumer through `Modules.style()`.

## Tests

The smoke test (`godot --headless --path . -- --smoke-test`, section *asset modules*) checks that all 34 types are
registered, every variant loads and all its asset paths exist (`validate_all()`), and for each type swaps to the
alternate variant (signal emitted, `Modules.style()` returns it, live consumers react: trees re-scatter, fences
re-skin, sea colours change) and back to the default.

The v4 sections (*crop modules / garden*, *tools*, *night lights / electricity*, *yards / minimap / landscape*,
*NPC social life*, *house styles*) test the new modules' behaviour; `tools/test_gate.py` maps changed modules to
these sections.

## v5a module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `crafting` | farm_shed, stone_workshop | workshop building colours, `Crafting` (craft time, stamina), `CraftingPanel` |
| `recipes` (collection) | 14 recipes: 8 workbench, 6 stove meals | `Crafting`, `GameData` (outputs become items) |
| `market` | bazaar, farmers_market | `MarketArea` (MultiMesh stalls, paving, bunting), `Shops` (stall stock, sell bonus) |
| `town_square` | ornate_fountain, classic_well | `TownSquare` (fountain/well, mosaic, flowers, lamps, statue, hedges) |
| `population` | families (28), small_town (14) | `Townspeople` (bots + job-based routines), `Population`, `PeoplePanel`, home signs |
| `workplaces` | classic_shops, modern_shops | 8 shop buildings (awnings / flat roofs), `Shops`, shop interiors, shop items |
| `civic` | classical, plain | hospital / offices / school / university decor (columns, flags, substation, water tower), desk lines |
| `mosque` | turquoise_dome, sandstone | `MosqueBuilder`, interior, `CallPlayer` (adhan sound, hours, volume) |
| `church` | stone_chapel, white_church | `ChurchBuilder`, interior, `CallPlayer` (bell sound, hours, volume) |
| `kitchen` | modern_electric, rustic_gas, wood_stove | `KitchenBuilder` (every home), `Crafting` (electric stove needs power) |
| `gestures` | friendly_wave, reserved_nod | `NpcGestures`, `WaveModifier` |

Live swaps: `population` respawns the townsfolk, `yards` rebuilds the yard fences, `house_styles`
(`HouseStyle.set_town_style()`, Settings → Town styles) rebuilds the homes in place, `mosque` / `church` re-read
the call sounds and hours, `kitchen` / `recipes` / `workplaces` / `market` / `gestures` are read on use.
Buildings that depend on layout (`market`, `town_square`, `civic` decor) are built once at start.

## v5b module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `fonts` | vazirmatn, vazirmatn_bold | `Lang` (UI font fallback, speech-bubble font, RTL shaping checks) |
| `dialogue` | warm_village, brief | `Dialogue` (greetings by time of day, job / family / friendship / health / closed / night lines, Persian names, jobs, places), `NpcSocial`, `TownspersonBot` |
| `friendship` | daily_talks, slow_burn | `Friendship` autoload (points per daily talk, streak bonus, decay, levels, hearts) |
| `shop_hours` | standard, late_night | `ShopHours` (open / closed per workplace, market stalls), `InteriorItem` counters, `MarketArea` |
| `voices` | blips, hum | `VoiceBlips` (synthesized syllables; pitch by gender and age) |
| `npc_card` | parchment, dark_glass | `NpcCard` (HUD name / job card) |
| `needs` | balanced, gentle | `Needs` autoload (hunger, fatigue, illness chances, NPC meal hours, doctor fee multiplier), `NeedsHud` |
| `illnesses` (collection) | cold, flu | `Needs` (speed / stamina effect, sneezing, fee, duration) |
| `ingredients` (collection) | chicken, eggs, onion, tomato_fresh, herbs, rice, salt, spices | `GameData` items, `Shops` (Supermarket / market stall stock), `Cooking`, `CookingStation` |
| `dishes` (collection) | omelette, chelo_morgh, kuku_sabzi | `Cooking`, `CookingPanel` |
| `cooking` | home_style (prepare, salt, spices, cook, eat), quick_cook | `Cooking` (step order, timing, sounds), `CookingPanel`, `CookingStation` |

`mosque` gained `dome_shape` (onion / ribbed), `dome_ribs`, `drum_height` and `rib_color`; swapping it rebuilds the
mosque in place. Generated by `tools/gen_modules_v5b.py`; voice / cooking sounds by `tools/synth_audio_v5b.py`.
All v5b types are read on use or hooked with `Modules.on_swap`, so every swap is live.

## v5c module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `market_economy` | supply_demand (x0.5 .. x2.5), stable_prices (x0.85 .. x1.25) | `Market` autoload (one town stock per good; price = base x (target / stock)^elasticity, clamped; daily recovery, exports, NPC food basket, Persian item names), `Economy.sell_price`, `Shops.buy_price`, `ShopPanel` |
| `producers` (collection) | carpenter_boards, carpenter_furniture, blacksmith_forge, blacksmith_tools, fruit_farms, poultry_farm, dairy, wholesaler, bakery, fishermen, tailor_spinning, feed_mill | `Market.run_production` (daily restock up to target; inputs consumed, e.g. planks -> furniture, iron bars -> tools, wool -> yarn; idle when every worker is ill), `Shops.stock` (what each workplace makes), new items (`to_items()`) |
| `wages` | fair_wages, modest_wages | `Market.pay_wages` (17:00 payday by job, 6th day off), townsfolk wallets that pay for meals (`Needs.meal_eaten`) and the doctor (`Needs.cured`; the city covers what a poor patient can't) |
| `price_board` | chalkboard, market_screen | `PriceBoard` (3D board by the market: price + trend arrows + shortage marks, E opens the panel), `PricesPanel` (B: all goods, change since yesterday, stock, 7-day sparkline, wages / meals / doctor / exports summary, producers) |
| `livestock` (collection) | chicken, cow, sheep_flock | `Ranch` autoload (price, product + tool, feed per day, happiness gain / loss, product every N days, adult age, breeding interval + chance, names), `FarmAnimal` (procedural bird / cow / sheep, young scale), `LivestockPanel` |
| `animal_housing` (collection) | coop, barn | `Ranch.order` (gold + planks + nails, build days), `RanchWorld` (staked plot -> construction site -> house + fenced paddock + trough), `LivestockPanel` |

Generated by `tools/gen_modules_v5c.py`. `market_economy`, `producers`, `wages`, `livestock` and `animal_housing` are
read on use; `price_board` and the ranch yard rebuild live with `Modules.on_swap`.

## v5d module types (online beta)

| Type | Variants (default first) | Consumer |
|---|---|---|
| `netcode` | standard (15 Hz, 120 ms interpolation), low_bandwidth (8 Hz, 220 ms) | `Net` autoload (WebSocket client, input send, reconciliation), `NetServer` (speed check: max_speed x tolerance x dt, clamp + correction), `RemoteAvatars` (interpolation delay), reconnect back-off |
| `chat` | friendly (200 chars, 5 msgs / 10 s), family (shorter, slower, word filter) | `NetServer` (rate limit, length cap, filter), `NetHud` (T / Enter, log lines + fade), `RemoteAvatar` bubbles |
| `live_updates` | auto (download + hot-swap, notify), manual_off (ignore server updates) | `ModuleManifest` (diff, size + sha256 check, `.tres` sanitiser, typed load + `validate()`, install to `user://updates`, rollback, persisted re-apply at start), `NetHud` banner + Online panel. `live_updates` itself is never updated remotely. |
| `save_sync` | every_5s, every_30s | `Net.autosave_tick` (stamps changed groups, uploads gzip JSON; offline keeps the local save), `SaveSync.merge` (player groups: newest stamp; world groups `time`, `market`: server) |
| `away_avatar` | cafe_or_home (cafe 08-20, otherwise home), always_home | `NetServer` (away avatar walks `TownNav.route` and sits; visit every N s, every 2nd brings tea), `TeaVisitController` (the real townsperson walks over), welcome-back text, `AwayMemory` lines in `Dialogue` |
| `accounts` | guest (32 players), guest_small (8 players) | `Net.guest_id` / token (Settings / localStorage), `NetServer` (token sha256 per guest ID, name length, player cap) |
| `npc_roles` | stub (claims tracked), disabled | `NetServer` claim table + `s_npc_roles`, `NetNpcController` (stub: no player control yet) |

Generated by `tools/gen_modules_v5d.py`. All seven are read on use, so a swap (Settings or a live update) applies at
once.

### Live module updates (v5d)

* `data/module_manifest.json` (written by `tools/build_manifest.py`; `--check` is a gate step) lists every module
  type with `version`, `active` variant and each file's `path`, `bytes` and `sha256`. Built-in modules are v1.
* The server reads `server/content/manifest.json` (+ `modules/<type>/<vid>.v<N>.tres`), re-reads it every second and
  pushes it to every client. A client compares versions and asks only for types whose remote version is higher.
* Install: size limit, sha256, sanitiser (text `.tres` only: no `[sub_resource]`, no nodes, no embedded code; external
  resources may only be the type's own style script under `res://modules/<type>/` or files under `res://assets/`), typed load + `validate()`. Then the
  file is written to `user://updates/<type>/<vid>.v<N>.tres` (web: localStorage `farm_mod_*`), the variant is
  re-registered and set active through `AssetRegistry`, and the installed list keeps the previous version for
  **rollback** (Online panel button, or automatic when the new file fails to load).
* Publishing: `python3 tools/push_module.py TYPE --file NEW.tres [--variant VID] [--active VID]` checks the file,
  runs the type's smoke sections and the full smoke suite with the new file swapped in (`--module-override`), and only
  then copies it into the content folder and bumps the version. `--revert` re-publishes the built-in version (as a new version number).
  Every push is appended to `server/content/push_log.jsonl`.

## v6a module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `night_sky` | starry, town_glow | `NightSky` (stars amount/size, moon phase + elevation, moonlight) + `sky_clouds.gdshader` |
| `real_clock` | optional (Settings toggle), always | `NightSky` / `TimeManager` (device local time), Settings "Real clock" |
| `dry_trees` | forest_edge, sparse | `DryTrees` (multimesh dead trees + stumps, hits, yields, regrow) + `Lifestyle` |
| `fishing_gear` | carpenter_rods, tool_shop_rods | `FishingMinigame` (rod / pro rod: wait time, rare-fish bonus), shops |
| `campfire` | beach_fire, big_bonfire | `BeachCampfire` (firewood, burn time, warmth, grilling, evening NPC fire) |
| `deep_sea` | calm_deep, persian_gulf | `FishingMinigame` deep-water catch table (beyond `deep_distance`) |
| `boats` | fishing_boats, rowboats | `Boats` / `FishingBoat` (moorings, fuel fee, voyage path, deep spots) |
| `sunbathing` | quiet_cove, sun_beach | `SunbathingBeach` (towels, umbrellas, hours, rest bonus), NPC "sunbathe" activity |
| `gym` | town_gym, zurkhaneh_mix | `Gym.workout`, `InteriorV6a.gym` stations, NPC "workout" activity, gym music |
| `house_music` | quiet_town, radios | `HouseMusic` (positional players, falloff, door occlusion low-pass, hours) |
| `kitchenware` | collection: plates, pots, pans, cutlery, glasses, blender, microwave | `Kitchenware` (step speed-ups, required tools, meal bonus), `Cooking` |
| `hypermarket` | hyper_blue, hyper_green | hypermarket building + interior shelves + shop stock |
| `ui_text` | farsi, farsi_short | `Lang.loc` / `Lang.loc_ui` (phrases, prefixes, words) |

Generated by `tools/gen_modules_v6a.py`. Smoke sections: `--smoke-only=v6a` (night sky, dry trees, beach, boats,
sunbathing, gym, kitchenware, translation, save).

## v6b module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `character_creator` | quaternius_parts, slim_start | `CharacterCreator` (Y / mirror), `CharacterLook`, `Player.apply_look` |
| `wardrobe` | home_wardrobe, festive | `WardrobePanel` (farmhouse wardrobe), `InteriorV6b.wardrobe` |
| `npc_looks` | distinct, subtle | `NpcLooks` -> `Townspeople.outfit_for`; name-tag size/hide (`TownspersonBot.update_labels`) |
| `vehicles` | town_cars, gentle_cars | `Vehicles` / `DrivableCar` (drive, horn, park memory), `VehicleKit` road graph |
| `ambulance` | city_ambulance, serious_only | `AmbulanceService` (dispatch on `Needs.fell_ill`, crew, hospital hand-over) |
| `police_patrol` | town_patrol, wide_patrol | `PolicePatrol` (duty hours, loop, responds to `WorldMemory.reports`) |
| `wood_pickup` | red_pickup, busy_pickup | `WoodPickup` (dry tree -> logs -> carpenter yard, `Market.add`) |
| `gas_stove` | blue_flame, big_flame | `GasFlame` via `CookingStation._heat` |
| `fridge` | white_fridge, steel_fridge | `FridgeUnit` (door, light, contents) in `KitchenBuilder` |
| `living_room` | modern_living, cozy_living | `InteriorV6b` (LCD TV size, paintings, blanket, `MovableSofa`) |
| `house_colors` | family_colors, whitewash | `HouseColors.wall_for` in `Building` |
| `landmark` | clock_tower, monument | `TownLandmark` (town square, hourly chime, plaque) |
| `fruit_gardens` | family_orchards, small_orchards | `FruitGardens` (permission, theft -> memory + report, regrow) |
| `town_lots` | three_lots, for_sale_only | `TownLots` (built home, construction site, for sale) |
| `pushables` | farm_boxes, heavy_boxes | `Pushables` (push, stack, remembered) |
| `herding` | west_meadow, big_flock | `Herding` (flee steering, pen, daily reward) |
| `digging` | garden_spade, treasure | `Digging` (R, finds, refill) |
| `yard_routine` | farm_day, light_day | `YardRoutine` (checklist + reward) |
| `world_memory` | remember_all, forgetful | `WorldMemory` autoload (save + v5d save sync) |
| `shadows` | soft_cascades, crisp | `ShadowRig` (desktop 4 soft cascades, web 2) |
| `cloud_shadows` | drifting, still_day | `CloudShadows` + `cloud_shadow.gdshaderinc` (global shader params) |
| `sea_horizon` | blended, classic | `DayNightCycle` -> `sky_clouds.gdshader` (`sea_blend`) |

`gym` gained `extras` (mirror wall, kettlebells, squat rack, rower, balls, water) and `ui_text` gained the controls
screen + F1 tip phrases. Generated by `tools/gen_modules_v6b.py`. Smoke sections: `--smoke-only=v6b`.

**Later:** a car dealership (buying your own car) is planned for a later version; v7 police can act on the
`WorldMemory.reports` hook (fines, visits).

## Not modular yet (v4.1+)

* Sheep *model* swap (`AnimalStyle.scene_path` is declared but the Sheep scene is not re-instanced; only colours swap).
* Live swap of characters and furniture, and of the market / town square layout (house styles and yards swap live since v5a).
* Ambient audio (footsteps, ambience) is referenced directly (tool sounds are now per tool module).
* Sky/cloud *shader* swap (only colours), weather particles, UI theme.
* Road / path materials and street furniture (lamps, signs, benches) in `town_builder.gd`.

## v7a module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `backstories` | town_stories, quiet_stories | `Backstories` (NpcCard story block, `Dialogue.talk_lines`) |
| `kids` | after_school, well_behaved | `KidsPlay` (bikes, tag, chat, ring-and-run) |
| `conflicts` | street_arguments, peaceful_town | `Conflicts` (arguments, calm by player / police) |
| `possession` | free_choice, gentle | `Possession` (F2, 1 demolish, 2 fire, `V7aConfirmDialog`) |
| `fire` | town_fire_service, dry_summer | `FireService`, `BuildingDamage` (station, truck, crew, spread, rebuild) |
| `outages` | storms_and_quakes, stable_grid | `Outages` (storm cuts, earthquakes, repair crew) |
| `city_fund` | municipal_fund, lean_budget | `CityState` autoload, `CityFund`, `CityFundPanel` (F4), `Needs` doctor subsidy |

`ui_text` gained the v7a "Town Life" controls category, rows and prompts (Persian + English). New autoload `CityState`
(fund ledger, projects, building damage, active fires; saved under `"city"`). Generated by `tools/gen_modules_v7a.py`.
Smoke sections: `--smoke-only=v7a`.

## v7b module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `chatter` | lively_town, quiet_town | `Chatter` (remarks, reactions, overheard chats, NPC trades), `ChatLogPanel` (5) |
| `cafe` | night_terrace, tea_house | `TerraceCafe`, `CafeMenuPanel`, `Tipsy`, `Staffing` posts bartender / dj |
| `mechanic` | town_garage, budget_garage | `MechanicShop`, `MechanicPanel`, `Staffing` post mechanic |
| `driving` | realistic_driving, easy_driving | `Driving` (dashboard, night edges), `CarSystems` on every `DrivableCar` |
| `passengers` | town_rides, busy_town | `Passengers` (stops, beams, fares, tips) |
| `camping` | forest_and_hill, family_camping | `Camping` (6: tent + campfire, sleep, pack) |
| `newspaper` | daily_paper, free_bulletin | `Newspaper` (newsstand, daily issue from real events), `NewspaperPanel` (4) |
| `personalities` | town_characters, easygoing_town | `Personalities` (Conflicts tempers / lines, `HagglePanel` (7), NPC trades) |
| `voice_profiles` | distinct_voices, uniform_voices | `VoiceProfiles`, `VoiceBlips` (pitch, rate, tone volume / jitter) |

New autoload `TownLife` (car fuel / condition / upgrades / gearbox, papers, café counters, tipsiness, rides, camps,
chat log, trades, daily event counts; saved under `"town_life"`). `ui_text` gained the v7b controls rows, notes and
prompts. Generated by `tools/gen_modules_v7b.py`. Smoke sections: `--smoke-only=v7b`.

**Later:** the car dealership.


## v7b.1 platform (not AssetRegistry modules)

Export / lobby / updates live under `scripts/v7b1_platform/` and `config/server.cfg`
rather than new AssetModule types. Key pieces: `ServerConfig`, `GameBrand`,
`BootTitle`, `LobbyPanel`, `UpdateClient`, `PackLoader` (autoload), `HealthHttp`,
`V7b1Platform`. See `docs/BUILDING.md`, `docs/UPDATES.md`, `docs/MULTIPLAYER.md`.


## v7b.1 visual module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `car_bodies` | realistic_cars, simple_cars | `CarBody` via `VehicleKit.model()` (every parked / road / service car), `SteeringWheel` (turns with `DrivableCar.steer_amount`) |
| `resident_looks` | varied_faces, subtle_faces | `ResidentLooks` via `Townspeople.outfit_for()` (skin tone, height / build, hijab, moustache, glasses, cap, family resemblance; saved as `"resident_looks"`) |
| `door_plaques` | family_plaques, classic_signs | `DoorPlaques` (Building hook: no roof family board, plaque by the door), `HomeMarker` (player's home on the minimap + edge waypoint) |
| `house_variety` | varied_homes, uniform_homes | `HouseVariety` (Building hook: wall / roof tints, shutters, porch, timber, tall windows per home) |
| `street_plants` | town_avenue, sparse_greens | `StreetPlants` (swappable plant set: trees, shrubs, flowers, planters as MultiMeshes; replaces the square's flower balls) |
| `fire_truck` | town_fire_truck, quiet_brigade | `FireSiren` on the FireService truck (procedural positional siren, flashing lamps) |
| `city_hall_interior` | municipal_office, simple_office | `CityHallInterior` (fund board inside, counter, manager + clerks via a private `Staffing`, F4 inside only, lazy-built props) |
| `families` | town_families, small_households | `Families` (household kinds, J directory, name-card line) + the population module's households |

Generated by `tools/gen_modules_v7b1_visual.py` (also patches population, town layout, dialogue, backstories,
wages, town lots and ui_text). Smoke sections: `--smoke-only=v7b1_visual`. Screenshots:
`-- --vis-shots=/workspace/farm-v7b1 [--only=cars,car-front,...]`.

**House addresses are permanent.** Future versions must keep every existing house id, address ("2 Maple St"),
street name and the family living there (saves, backstories, the newspaper and players refer to them). New homes
get new ids / numbers on existing streets (v7b.1 added `pine11`, `oak16`, `harbor4`, `pine18`); a removed
building (v7b.1: the post office, "3 Town Sq") leaves its address unused rather than reassigning it.


## v7b.1 traffic module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `traffic_rules` | strict_city, gentle_city | `TrafficKit` (per-road limits, school zone, square), `TrafficSignals` (cycles, cameras, officer), `TrafficRules` (enforcement + `RoadCar.traffic_gate` for AI cars), `NewCityRoad` |
| `road_markings` | city_white, faded_paint | `RoadMarkings` (stop lines, centre / lane / edge lines, zebras, arrows, give-way, bays, SCHOOL text) |
| `traffic_signs` | bilingual, persian_only | `TrafficSigns` (STOP, give-way, limits, no parking, school, one-way / roundabout, direction boards) |
| `driving_license` | standard, strict | `LicenseOffice` + `LicensePanel` (booklet, quiz, fee, pass mark), `Impound` (lot, fee, confiscation days), `TrafficState` |
| `car_dealership` | town_motors, budget_lot | `Dealership` + `DealershipPanel` (models, prices, top speed, licence requirement) |
| `npc_traffic` | light_traffic, busy_traffic | `NpcTraffic` (looping AI cars, gap, active hours) |
| `transit` | city_bus, minibus | `Transit` (line, stops, timetable, fare, NPC bus, riders), `BusModel`, `DrivableBus` (the drivable bus vehicle) |
| `car_sounds` | distinct_engines, quiet_electric | `CarAudio` (per-voice engine synth with RPM / gears, horns, indicator ticks, squeal, doors, nearby NPC engines) |
| `cafe_lounge` | classy_lounge, jazz_lounge | `CafeLounge` (terrace decor on the v7b cafe, indoor lounge + night disco, dress code, staffing posts lounge_bartender / lounge_dj) |
| `street_lighting` | bright_city, soft_glow | `StreetLighting` (extra lamps as MultiMeshes, ground pools, pooled real lights, night ambient floor) |

New autoload `TrafficState` (licence, confiscation, offences per driver, impounded cars, owned cars, traffic
news, counters; saved under `"traffic"`). Shared hooks: `RoadCar.traffic_gate` (static Callable capping an AI
car's speed), `CityFund.speed_check` (the v7a global speeding check is off; cameras / the officer catch speeding
and call `CityFund.fine_speeding`), `CarSystems.dash_text` shows the limit, `Newspaper` adds
`TrafficState.news_items()`, `DrivableCar` honours meta `top_mult` (dealership cars). Vehicles are modules too:
the bus is `BusModel.build(spec)` + `DrivableBus` (extends `DrivableCar`) with the spec in `transit.vehicles`.
Generated by `tools/gen_modules_v7b1_traffic.py` (writes only its own types). Smoke sections:
`--smoke-only=v7b1_traffic`.



## v7b.1 controls module types

| Type | Variants (default first) | Consumer |
|---|---|---|
| `controls_mouse` | desktop_mouse, desktop_mouse_gentle | `ControlInput` (autoload): click captures the mouse (pointer lock on the web, "soft" capture if the browser refuses), mouse look sensitivity / invert Y, mouse X steers cars through a virtual wheel (the gentle variant only moves the camera in a car), the farmer faces where you look |
| `controls_touch` | touch_twin_stick, touch_fixed_sticks | `TouchControls` (left stick moves / throttles, right stick looks / steers, floating or fixed sticks, stick radius, dead zone, opacity, look speed, `fit_ui` stretch for phones; buttons: E / get in / get out, jump (brake in a car), run, horn, lights, camera, play as / return + dig / demolish / fire, menu, ?) |
| `controls_keyboard` | keyboard_legacy, keyboard_turn | `ControlInput` keyboard fallback: WASD / arrows camera-relative (legacy strafes, `turn` = tank-style A/D turning), Z/C + PgUp/PgDn orbit, A/D steer cars, Space handbrake |

Every scheme feeds the same values in `ControlInput` (`move_vector()`, `take_look(dt)`, `steer()`, `throttle()`,
`brake()`), and every mover reads them from there: `Player` (also while playing as a townsperson - possession
moves through the same path, including driving), `FollowCamera`, `DrivableCar` (`steer_amount` -1..1 turns the
visual steering wheel), `CockpitCamera` (V / C or the touch camera button; mouse / right stick look around, the
roof hides when looking up; meta `driver_eye`), `FishingMinigame`. `ControlsWorld` adds the cockpit toggle, the gear
readout (A / 1-4 / R / N) and the web `?ctlprobe=1` console diagnostics (`CTL:` lines). The F1 Controls menu has a
"Mouse & Touch" tab (`ControlsHelp`). Space no longer locks the stance: the humanoid anim watchdog never leaves a
grounded character in a jump / pose clip. Settings: mouse sensitivity, invert Y, touch controls (auto / on / off).
Generated by `tools/gen_modules_v7b1_controls.py` (writes only its own types). Smoke sections:
`--smoke-only=v7b1_controls` (basics, driving, touch, possession, regress). Screenshots:
`-- --ctl-shots=/workspace/farm-v7b1 [--only=touch-ui,mouse-look,driving-steer,cockpit,possess-touch]`.

## v7b.1 police / road safety module type

| Type | Variants | Consumer / what it does |
|---|---|---|
| `road_safety` | careful_drivers, light_checks | `RoadSafety` (`RoadCar.people_gate`): every AI vehicle (police, ambulance, fire truck, outage van, wood pickup, NPC traffic, bus) looks ahead along its own route for nose + stop margin + reaction + braking distance (also where walkers will be in ~1 s) and stops `stop_margin` m before people - no time-out (the v6b check drove on through a person after 12 s blocked); a townsperson blocking a waiting car steps aside; walkers wait at the kerb for close moving cars (`TownspersonBot.move_filter`). `AccidentResponse`: any car touching a person -> light hit = knock-back, one knee / short fall, Persian exclamation, back up; hard hit (>= `hard_hit_kmh`, 25) = stays down, ambulance + paramedics and the police (officer) drive there with lights, 3-6 townspeople gather and talk (chat log), the driver is fined through `TrafficRules` (offence points -> licence + impound), paramedics treat on the spot, the person gets up. Non-graphic, nobody dies |

Generated by `tools/gen_modules_v7b1_police.py` (writes only its own type). Code: `scripts/v7b1_police/`
(`V7b1PoliceWorld` wires the hooks). Smoke: `--smoke-only=v7b1_police`.
