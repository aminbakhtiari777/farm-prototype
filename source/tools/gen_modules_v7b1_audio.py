#!/usr/bin/env python3
"""v7b.1 audio workstream: generates the audio module style scripts, their .tres
variants and registers them in data/asset_modules.json:
  spatial_audio   listener on the active camera (follow / cockpit / possessed resident),
                  stereo panning, distance + indoor low-pass, voice cap
  sound_fx        surface-aware footsteps (player + nearby residents), door open / close
  ambient_sounds  placed emitters: birds in trees, crickets in fields, square murmur,
                  river, distant traffic, sea waves (BeachBuilder) + wind gusts / thunder
Consumers: V7b1AudioWorld, SpatialListener, FootstepAudio, DoorAudio, AmbientEmitters
(scripts/v7b1_audio/). Only these types are (re)written in the JSON config (the file
is re-read right before saving). Re-run, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, psa, config, config_path = ns["style_script"], ns["emit"], ns["psa"], ns["config"], ns["config_path"]
MY_TYPES = ["spatial_audio", "sound_fx", "ambient_sounds"]
A = "res://assets/audio/v7b1/"

# ---------------------------------------------------------------- spatial_audio
style_script("spatial_audio", "spatial_audio_style", "SpatialAudioStyle",
    "v7b.1 spatial audio: an AudioListener3D copies the active camera every frame\n(follow camera, cockpit camera, possessed resident), so every AudioStreamPlayer3D\nis heard from its real position: stereo panning by direction, inverse-distance\nattenuation, a distance low-pass and a muffled low-pass while indoors. New\nemitters are capped (nearest win) on top of the perf audio_budget.\nConsumers: SpatialListener, V7b1AudioWorld.", [
    ("enabled", "bool", "true", ""),
    ("listener_pull", "float", "0.3", "0 = listener at the camera, 1 = at the player's head (rotation always = camera)"),
    ("panning_strength", "float", "1.6", "per-player panning (x project 3d_panning_strength)"),
    ("distance_cutoff_hz", "float", "6000.0", "far sounds lose their highs (attenuation filter)"),
    ("distance_filter_db", "float", "-18.0", ""),
    ("indoor_cutoff_hz", "float", "900.0", "outdoor emitters heard from inside a building"),
    ("indoor_db", "float", "-8.0", ""),
    ("max_voices", "int", "10", "ambient emitters + one-shots of this workstream playing at once (also <= quality max_voices)"),
    ("pool_size", "int", "6", "pooled one-shot 3D players (steps / doors / gusts / thunder)"),
])
emit("spatial_audio", "SpatialAudioStyle", "spatial_audio_style", [
    ("camera_listener", "Camera listener (default)", "Listener on the camera (pulled 30% toward the player), strong stereo panning, muffled indoors, 10 voices.",
     {"name_fa": "شنونده روی دوربین"}),
    ("light", "Light (slow laptops)", "Same listener, 6 voices, smaller pool, gentler panning.",
     {"name_fa": "سبک (لپ‌تاپ ضعیف)", "panning_strength": 1.2, "max_voices": 6, "pool_size": 4}),
], "camera_listener")

# ---------------------------------------------------------------- sound_fx
style_script("sound_fx", "sound_fx_style", "SoundFxStyle",
    "v7b.1 sound effects: footsteps that follow the walk / run stride and change\nwith the surface (grass, asphalt / plaza, wood floors indoors / pier, sand at the\nbeach); residents near the listener get quieter footsteps (the possessed one is\nfull volume); every BuildingDoor plays a latch on open and a wooden thud on close\n(the creak stays on open). Consumers: FootstepAudio, DoorAudio.", [
    ("footsteps", "bool", "true", ""),
    ("surfaces", "Dictionary", "{}", "surface -> {streams: [paths], db, pitch}"),
    ("run_db", "float", "3.0", "louder steps while running"),
    ("npc_footsteps", "bool", "true", ""),
    ("npc_radius", "float", "11.0", "residents within (m) of the listener have footsteps"),
    ("npc_max", "int", "3", "nearest residents with footsteps"),
    ("npc_db", "float", "-17.0", ""),
    ("npc_stride", "float", "0.75", "m per step"),
    ("doors", "bool", "true", ""),
    ("door_open", "String", "\"\"", "latch played with the creak when a door opens"),
    ("door_close", "String", "\"\"", "thud played when it shuts (replaces the creak)"),
    ("door_db", "float", "-5.0", ""),
    ("door_range", "float", "32.0", "doors further than this from the listener stay silent"),
])
SURF = {
    "grass": {"streams": ["res://assets/audio/sfx/footstep_grass_%d.ogg" % i for i in (1, 2, 3, 4)], "db": -9.0, "pitch": 1.0},
    "asphalt": {"streams": [A + "step_asphalt_%d.ogg" % i for i in (1, 2, 3)], "db": -11.0, "pitch": 1.0},
    "stone": {"streams": [A + "step_asphalt_%d.ogg" % i for i in (1, 2, 3)], "db": -10.0, "pitch": 1.15},
    "wood": {"streams": [A + "step_wood_%d.ogg" % i for i in (1, 2, 3)], "db": -9.0, "pitch": 1.0},
    "sand": {"streams": [A + "step_sand_%d.ogg" % i for i in (1, 2, 3)], "db": -8.0, "pitch": 1.0},
}
emit("sound_fx", "SoundFxStyle", "sound_fx_style", [
    ("rich_fx", "Rich footsteps + doors (default)", "Five surfaces, nearby residents' steps, latch / thud on every door.",
     {"name_fa": "صدای قدم و در", "surfaces": SURF, "door_open": A + "door_latch.ogg", "door_close": A + "door_close.ogg"}),
    ("subtle_fx", "Subtle", "Quieter steps, no residents' steps (lightest).",
     {"name_fa": "ملایم", "surfaces": {k: dict(v, db=v["db"] - 5.0) for k, v in SURF.items()}, "npc_footsteps": False,
      "door_open": A + "door_latch.ogg", "door_close": A + "door_close.ogg", "door_db": -9.0}),
], "rich_fx")

# ---------------------------------------------------------------- ambient_sounds
style_script("ambient_sounds", "ambient_sounds_style", "AmbientSoundsStyle",
    "v7b.1 ambient beds from placed 3D emitters (not 2D): birds in trees by day,\ncrickets in the fields at night, a crowd murmur around the town square by day,\nthe river, distant traffic along the main streets, sea waves along the shore\n(BeachBuilder's emitters). Only the nearest few of each kind play; the rest are\nstopped (no mixing cost). Wind gusts blow past from a random direction overhead\n(sky / clouds); distant thunder only in rain / storms. The old 2D beds are\nturned down to a faint base. Consumers: AmbientEmitters, AmbienceManager (bed_scale).", [
    ("kinds", "Dictionary", "{}", "kind -> {stream, count, active, db, unit, range, when}"),
    ("gusts", "PackedStringArray", "PackedStringArray()", ""),
    ("gust_interval", "Vector2", "Vector2(8.0, 20.0)", "s between gusts (shorter in rain / storm)"),
    ("gust_db", "float", "-9.0", ""),
    ("thunder", "PackedStringArray", "PackedStringArray()", ""),
    ("thunder_interval", "Vector2", "Vector2(12.0, 35.0)", "s between rumbles in a storm (x3 in rain)"),
    ("thunder_db", "float", "-2.0", ""),
    ("bed_2d_scale", "float", "0.3", "old non-positional bird / cricket beds kept at this level"),
    ("update_interval", "float", "0.5", "s between nearest-emitter checks"),
])
KINDS = {
    "birds": {"stream": "res://assets/audio/ambience/birds_day_loop.ogg", "count": 12, "active": 3, "db": -6.0, "unit": 6.0, "range": 38.0, "when": "day"},
    "crickets": {"stream": "res://assets/audio/ambience/crickets_night_loop.ogg", "count": 10, "active": 3, "db": -7.0, "unit": 5.0, "range": 32.0, "when": "night"},
    "murmur": {"stream": A + "murmur_loop.ogg", "count": 4, "active": 2, "db": -8.0, "unit": 6.0, "range": 40.0, "when": "town"},
    "river": {"stream": "res://assets/audio/ambience/pond_loop.ogg", "count": 6, "active": 2, "db": -6.0, "unit": 5.0, "range": 30.0, "when": "always"},
    "traffic": {"stream": A + "traffic_loop.ogg", "count": 6, "active": 2, "db": -12.0, "unit": 12.0, "range": 75.0, "when": "traffic"},
}
GUSTS = psa(A + "gust_1.ogg", A + "gust_2.ogg")
THUNDER = psa(A + "thunder_1.ogg", A + "thunder_2.ogg")
emit("ambient_sounds", "AmbientSoundsStyle", "ambient_sounds_style", [
    ("lively", "Lively world (default)", "Birds in 12 trees, crickets in 10 fields, square murmur, river, distant traffic, gusts, storm thunder.",
     {"name_fa": "دنیای زنده", "kinds": KINDS, "gusts": GUSTS, "thunder": THUNDER}),
    ("calm", "Calm (lightest)", "Fewer emitters (1 of each kind plays), rarer gusts, no traffic bed.",
     {"name_fa": "آرام", "kinds": {k: dict(v, count=max(3, v["count"] // 2), active=1) for k, v in KINDS.items() if k != "traffic"},
      "gusts": GUSTS, "thunder": THUNDER, "gust_interval": "V2(16, 40)", "bed_2d_scale": 0.5}),
], "lively")

fresh = json.load(open(config_path, encoding="utf-8"))
for t in MY_TYPES:
    fresh[t] = config[t]
json.dump(fresh, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 audio modules written: " + ", ".join(MY_TYPES))
