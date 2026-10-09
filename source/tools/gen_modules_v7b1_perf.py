#!/usr/bin/env python3
"""v7b.1 performance refresh: generates the perf module style scripts, their .tres
variants and registers them in data/asset_modules.json:
  quality      (collection) low / medium / high graphics presets - picked by the
               Settings "quality" value (auto = medium on the web, high on desktop)
  world_stream streaming (default) / stream_wide - cell grid streaming of the town
  lod_rules    balanced (default) / crisp - distance LOD / shadow-culling rules
  audio_budget capped (default) / generous - voice cap, far-sound pausing, cache release
Consumers: PerfWorld, PerfQuality, AutoLod, WorldStreamer, InteriorStreamer,
AudioBudget, AnimBudget (scripts/v7b1_perf/). Re-run, then tools/build_manifest.py."""
import json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, config_path = ns["style_script"], ns["emit"], ns["config_path"]

# ---------------------------------------------------------------- quality
style_script("quality", "quality_style", "QualityStyle",
    "v7b.1 graphics preset (Settings > Graphics: Auto / Low / Medium / High). Every\nperf system reads its numbers from the active preset, so a slow laptop can drop\nto Low (no sun shadows, 75% render scale, shorter view ranges, fewer real\nlights / voices / animated people) without touching any gameplay code.\nConsumers: PerfQuality, AutoLod, WorldStreamer, AudioBudget, AnimBudget,\nTownspersonBot (NPC LOD distances), LampLightPool.", [
    ("level", "int", "1", "0 low, 1 medium, 2 high"),
    ("sun_shadows", "int", "1", "0 off, 1 cheap (2 cascades, shadow_distance), 2 full ShadowRig cascades"),
    ("shadow_distance", "float", "35.0", "sun shadow max distance (m) for sun_shadows=1"),
    ("shadow_atlas", "int", "2048", "directional shadow map size"),
    ("shadow_min_size", "float", "0.9", "objects smaller than this (m) never cast shadows"),
    ("render_scale", "float", "1.0", "3D resolution scale (UI stays sharp)"),
    ("msaa", "int", "1", "0 off, 1 2x, 2 4x"),
    ("mesh_lod_threshold", "float", "1.0", "Godot mesh LOD threshold in pixels (higher = simpler meshes sooner)"),
    ("lod_scale", "float", "0.85", "multiplier on every auto visibility range"),
    ("tree_view_scale", "float", "0.85", "multiplier on tree / forest view distance"),
    ("grass_view_scale", "float", "0.8", "multiplier on grass / flower view distance"),
    ("stream_radius", "float", "90.0", "cells within this distance (m) are loaded (scripts + physics live)"),
    ("light_fade_distance", "float", "45.0", "point / spot lights fade out beyond this (m)"),
    ("lamp_lights", "int", "6", "real OmniLights that follow the nearest street lamps"),
    ("npc_visible_distance", "float", "55.0", "townspeople drawn within (m)"),
    ("npc_anim_distance", "float", "38.0", "townspeople animated within (m)"),
    ("npc_shadow_distance", "float", "22.0", "townspeople cast shadows within (m)"),
    ("anim_distance", "float", "45.0", "other AnimationPlayers / Trees run within (m)"),
    ("max_voices", "int", "14", "positional sounds playing at once"),
    ("audio_distance", "float", "70.0", "positional sounds pause beyond (m)"),
    ("auto_fps_floor", "float", "26.0", "Auto mode steps down a preset when the average fps stays below this"),
    ("smooth_motion", "bool", "true", "physics interpolation for the player + camera (no judder when fps != 60 Hz physics)"),
    ("max_physics_steps", "int", "4", "physics steps allowed per frame (stops the slow-laptop 'spiral' where physics eats the frame)"),
    ("camera_follow_speed", "float", "20.0", "camera catch-up speed (was 12: ~85 ms trailing lag)"),
    ("npc_far_tick", "int", "4", "townspeople beyond npc_visible_distance think every Nth physics tick (schedule-only)"),
])
COMMON = {}
emit("quality", "QualityStyle", "quality_style", [
    ("low", "Low (fastest)", "Slow laptops / phones: no sun shadows, 75% 3D resolution, short view ranges, 3 lamp lights.",
     {"name_fa": "کم (سریع‌ترین)", "level": 0, "sun_shadows": 0, "shadow_distance": 0.0, "shadow_atlas": 1024,
      "shadow_min_size": 99.0, "render_scale": 0.75, "msaa": 0, "mesh_lod_threshold": 4.0, "lod_scale": 0.6,
      "tree_view_scale": 0.65, "grass_view_scale": 0.55, "stream_radius": 70.0, "light_fade_distance": 30.0,
      "lamp_lights": 3, "npc_visible_distance": 42.0, "npc_anim_distance": 24.0, "npc_shadow_distance": 0.0,
      "anim_distance": 28.0, "max_voices": 8, "audio_distance": 50.0, "auto_fps_floor": 0.0,
      "max_physics_steps": 3, "npc_far_tick": 6}),
    ("medium", "Medium (balanced)", "Default on the web: 2 cheap shadow cascades to 35 m, small props shadow-free, 6 lamp lights.",
     {"name_fa": "متوسط (متعادل)", "level": 1}),
    ("high", "High (best looks)", "Default on desktop: full soft shadow cascades, long view ranges, 8 lamp lights, 4x MSAA.",
     {"name_fa": "زیاد (بهترین ظاهر)", "level": 2, "sun_shadows": 2, "shadow_distance": 60.0, "shadow_atlas": 4096,
      "shadow_min_size": 0.45, "render_scale": 1.0, "msaa": 2, "mesh_lod_threshold": 1.0, "lod_scale": 1.0,
      "tree_view_scale": 1.0, "grass_view_scale": 1.0, "stream_radius": 150.0, "light_fade_distance": 70.0,
      "lamp_lights": 8, "npc_visible_distance": 60.0, "npc_anim_distance": 45.0, "npc_shadow_distance": 28.0,
      "anim_distance": 60.0, "max_voices": 24, "audio_distance": 90.0, "auto_fps_floor": 22.0,
      "max_physics_steps": 6, "npc_far_tick": 3}),
], "medium", collection=True)

# ---------------------------------------------------------------- world_stream
style_script("world_stream", "world_stream_style", "WorldStreamStyle",
    "v7b.1 world streaming: the map is a grid of cells; only cells within the\npreset's stream_radius are live. Far cells are dormant (physics removed,\nscripts / animations / sounds paused, deferred builders freed) and wake up\nprogressively, a few per frame inside a time budget, as the player walks or\ndrives toward them. Gameplay keeps running on data (WorldMemory, CityState,\nTownLife, fires, traffic). Consumers: WorldStreamer, InteriorStreamer.", [
    ("enabled", "bool", "true", ""),
    ("cell_size", "float", "32.0", "cell edge (m)"),
    ("unload_margin", "float", "24.0", "hysteresis: cells unload at stream_radius + margin"),
    ("budget_ms", "float", "2.0", "max milliseconds per frame spent waking / building cells"),
    ("update_interval", "float", "0.25", "seconds between cell checks"),
    ("lookahead", "float", "1.2", "seconds of velocity added to the stream centre (build ahead while driving)"),
    ("interior_radius", "float", "22.0", "interiors wake within this distance (m) of the player / camera"),
    ("auto_units", "Array", "[]", "script file names whose nodes are streamed automatically (safe, position-bound)"),
])
# Position-bound props that never move on their own (fences stay live: the sheep need them).
AUTO_UNITS = ["market_stall.gd", "signpost.gd", "street_lamp.gd", "well.gd", "price_board.gd", "seat.gd"]
emit("world_stream", "WorldStreamStyle", "world_stream_style", [
    ("streaming", "Cell streaming (default)", "32 m cells, 2 ms per frame build budget, builds ahead while driving.",
     {"name_fa": "بارگذاری تدریجی", "auto_units": AUTO_UNITS}),
    ("stream_wide", "Wide streaming", "Bigger cells and margin: fewer wake-ups, more loaded at once (fast PCs).",
     {"name_fa": "بارگذاری گسترده", "cell_size": 48.0, "unload_margin": 40.0, "budget_ms": 3.0, "auto_units": AUTO_UNITS}),
], "streaming")

# ---------------------------------------------------------------- lod_rules
style_script("lod_rules", "lod_rules_style", "LodRulesStyle",
    "v7b.1 distance detail rules (AutoLod): every mesh / label / particle without its\nown range gets a visibility range from its size class (x preset lod_scale), small\nthings stop casting shadows, point lights fade with distance. New content from\nany module is picked up automatically (SceneTree.node_added).\nConsumers: AutoLod.", [
    ("tiny_size", "float", "0.5", "longest edge (m) below which an object is tiny"),
    ("small_size", "float", "1.6", ""),
    ("medium_size", "float", "4.5", ""),
    ("large_size", "float", "14.0", "above this: huge (no auto range: terrain, sea, mountains)"),
    ("tiny_range", "float", "28.0", "visibility range end (m) per class"),
    ("small_range", "float", "55.0", ""),
    ("medium_range", "float", "100.0", ""),
    ("large_range", "float", "190.0", ""),
    ("label_range", "float", "30.0", "Label3D signs / plaques"),
    ("margin", "float", "5.0", "hysteresis (m)"),
    ("fade", "bool", "false", "cross-fade (prettier, costs alpha blending on the web)"),
    ("scale_existing", "bool", "true", "also scale ranges a module already set (by preset lod_scale)"),
])
emit("lod_rules", "LodRulesStyle", "lod_rules_style", [
    ("balanced", "Balanced LOD (default)", "Tiny props 28 m, small 55 m, medium 100 m, large 190 m; no fades.",
     {"name_fa": "جزئیات متعادل"}),
    ("crisp", "Crisp LOD", "Longer ranges with soft fades (fast PCs).",
     {"name_fa": "جزئیات واضح", "tiny_range": 40.0, "small_range": 80.0, "medium_range": 150.0, "large_range": 260.0,
      "label_range": 40.0, "fade": True}),
], "balanced")

# ---------------------------------------------------------------- audio_budget
style_script("audio_budget", "audio_budget_style", "AudioBudgetStyle",
    "v7b.1 audio budget: positional sounds beyond the preset's audio_distance are\npaused, at most max_voices play at once (nearest win), one-shot players are\npooled and reused, and cached sound streams not played for a while are\nreleased so they can be freed. Consumers: AudioBudget, Sfx.", [
    ("enabled", "bool", "true", ""),
    ("check_interval", "float", "0.35", "seconds between checks"),
    ("release_after", "float", "90.0", "seconds unused before a cached stream is released"),
    ("pool_size", "int", "8", "pooled one-shot 3D players"),
    ("keep_2d", "bool", "true", "never touch non-positional (UI / music) players"),
])
emit("audio_budget", "AudioBudgetStyle", "audio_budget_style", [
    ("capped", "Capped voices (default)", "Far sounds pause, nearest voices win, idle streams are released.",
     {"name_fa": "صداهای محدود"}),
    ("generous", "Generous voices", "Longer cache life, bigger pool (fast PCs).",
     {"name_fa": "صداهای بیشتر", "release_after": 300.0, "pool_size": 16}),
], "capped")

# Re-read the config right before writing so a parallel generator's types survive.
cur = json.load(open(config_path, encoding="utf-8"))
for t in ("quality", "world_stream", "lod_rules", "audio_budget"):
    cur[t] = ns["config"][t]
json.dump(cur, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 perf modules written")

PHRASES = {
    "Graphics: Auto": "گرافیک: خودکار", "Graphics: Low": "گرافیک: کم", "Graphics: Medium": "گرافیک: متوسط",
    "Graphics: High": "گرافیک: زیاد", "Graphics": "گرافیک",
    "Graphics quality (Auto picks Medium on the web and steps down if the game is slow)":
        "کیفیت گرافیک (خودکار روی وب متوسط است و اگر بازی کند شود پایین می‌آید)",
    "Performance overlay (F7)": "نمایش کارایی (F7)",
    "Performance": "کارایی", "FPS": "فریم بر ثانیه", "Frame": "فریم", "Draw calls": "فراخوانی رسم",
    "Objects": "اشیا", "Triangles": "مثلث‌ها", "Nodes": "گره‌ها", "Cells loaded": "خانه‌های بارگذاری‌شده",
    "Interiors awake": "فضاهای داخلی فعال", "Sounds playing": "صداهای در حال پخش", "Animations running": "انیمیشن‌های فعال",
    "Lights": "چراغ‌ها", "Video memory": "حافظه‌ی گرافیک", "Quality": "کیفیت",
    "Graphics lowered to keep the game smooth": "برای روان ماندن بازی، گرافیک پایین آمد",
}
for fn in ("farsi.tres", "farsi_short.tres"):
    path = os.path.join(ROOT, "modules", "ui_text", fn)
    s = open(path, encoding="utf-8").read()
    m = re.search(r"^phrases = (\{.*\})$", s, re.M)
    curp = json.loads(m.group(1))
    for k, v in PHRASES.items():
        curp.setdefault(k, v)
    line = "phrases = " + json.dumps(curp, ensure_ascii=False, separators=(", ", ": "))
    s = s[:m.start()] + line + s[m.end():]
    open(path, "w", encoding="utf-8").write(s)
print("ui_text: +%d v7b1 perf phrases" % len(PHRASES))
