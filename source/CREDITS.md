# Credits & licenses

All third-party art and audio assets are **CC0 1.0 (public domain)**; the Vazirmatn font (v5b) is under the **SIL Open Font License 1.1**. Licence files are kept next to the assets.

| Asset | Author / source | Licence | Used for |
| --- | --- | --- | --- |
| Universal Base Characters (free version) | **Quaternius** – <https://quaternius.com> | CC0 1.0 (`assets/third_party/quaternius/characters/LICENSE_Quaternius_UBC.txt`) | farmer + townspeople bodies, skins, hair |
| Universal Animation Library | **Quaternius** | CC0 1.0 (`.../animations/LICENSE_Quaternius_UAL.txt`) | idle / walk / run / sit / interact animations |
| Stylized Nature MegaKit (free version) | **Quaternius** | CC0 1.0 (`.../nature/LICENSE_Quaternius_Nature.txt`) | trees, pines, bushes, ferns, flowers, rocks, grass |
| Furniture Kit 2.0 | **Kenney** – <https://kenney.nl> | CC0 1.0 (`assets/third_party/kenney/furniture/LICENSE_Kenney_Furniture.txt`) | interiors (beds, sofas, TV, tables, kitchen...) |
| Food Kit 2.0 | **Kenney** | CC0 1.0 (`.../food/LICENSE_Kenney_Food.txt`) | café/shop food, carryable pumpkin/melon |
| Car Kit 3.1 | **Kenney** | CC0 1.0 (`.../cars/LICENSE_Kenney_Cars.txt`) | parked cars in town |
| "Sheep Baa" | **AntumDeluge** (recording by mikewest), OpenGameArt | CC0 1.0 | sheep bleats (+ pitched derivatives) |
| Footsteps, wind, birds, crickets, waves, breathing, UI sounds | synthesized for this project (`tools/synth_audio.py`) | CC0 1.0 (original work) | all other audio |
| Tool + switch sounds (hoe dig, water pour, seeds, harvest, hammer, breaker switch) - v4 | synthesized for this project (`tools/synth_audio_v4.py`) | CC0 1.0 (original work) | tool animations, power breaker |
| Adhan-style call + church bell - v5a | synthesized for this project (`tools/synth_audio_v5a.py`, formant voice synthesis / additive bell partials, no recordings) | CC0 1.0 (original work) | mosque / church modules |
| v5a procedural content: market stalls, fountain + mosaic shaders, mosque, church, workplaces, civic decor, kitchens, wave modifier | original work for this project | same as the project | v5a features |
| Vazirmatn font v33.003 (Regular + Bold) - v5b | **Saber Rastikerdar** and contributors – <https://github.com/rastikerdar/vazirmatn> | SIL Open Font License 1.1 (`assets/fonts/OFL_Vazirmatn.txt`) | Persian speech bubbles, NPC card, HUD text |
| Voice blips, hums, sneeze, chopping, sprinkling, sizzling, eating sounds - v5b | synthesized for this project (`tools/synth_audio_v5b.py`) | CC0 1.0 (original work) | `voices` module, needs and cooking |
| v5b procedural content: lathe onion / ribbed mosque dome with drum and finial, cooking station (pan, board, chopped food, steam, plate), NPC card, needs HUD | original work for this project | same as the project | v5b features |
| v6b procedural content: character creator + wardrobe UI, gas flame, fridge, paintings (procedural canvases), blanket, movable sofa, ambulance / police light bars, red pickup, clock tower + chime, fruit trees, lots, crates, sheep pen, holes, gym extras, cloud-shadow noise, sea-horizon blend | original work for this project | same as the project | v6b features (cars reuse the Kenney Car Kit) |
| v7b.1 visual content: procedural car bodies (paint, glass, interiors, steering wheel, plates), fire truck + synthesized siren (`FireSiren.siren_stream`, generated at runtime), hijab / glasses / moustache / cap meshes, door plaques, street plants, City Hall counter and manager desk | original work for this project | same as the project | v7b.1 visual pass (replaces the Kenney Car Kit models in town) |
| v7b.1 traffic content: road markings, traffic signs and lights, camera poles, officer parasol, impound lot, dealership, bus + shelters, lounge / disco, new-city barrier and site, street-lamp pools; procedural engine / horn / indicator / squeal / door sounds (`CarAudio`, synthesized at runtime, no recordings); lounge music reuses the v7b café DJ loop | original work for this project | same as the project | v7b.1 traffic, licence, bus and night life |
| v7b.1 audio: surface footsteps (asphalt / stone, wood, sand), door latch + door thud, town-square crowd murmur, distant traffic rumble, wind gusts, distant thunder (`assets/audio/v7b1/`, 17 files, ~130 KB) | synthesized for this project (`tools/synth_audio_v7b1.py`: filtered noise, resonant partials and envelopes; no samples or recordings) | CC0 1.0 (original work) | `sound_fx` / `ambient_sounds` modules (birds, crickets, river and waves reuse the earlier CC0 loops) |
| Procedural meshes, shaders, terrain, buildings, UI | original work for this project | same as the project | everything else |
| v4 procedural content: crop models (11 crops x 5 stages), garden soil shader, house cladding shader (wooden / stone / modern), river shader, low-poly forest belt + mountains, breaker boxes, candles / lanterns / fireplaces, tool props, minimap | original work for this project | same as the project | v4 features |

Details for audio: `assets/audio/CREDITS.md`.

Engine: **Godot Engine 4.7** (MIT licence, <https://godotengine.org/license>).
