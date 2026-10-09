#!/usr/bin/env python3
"""Generates the v4 module .tres files (crop_types, garden, garden_rules,
lighting, power, yards, minimap, npc_social, landscape) and registers them in
data/asset_modules.json. Re-run after editing the tables below."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def col(c):
    return "Color(%s)" % ", ".join("%g" % v for v in (list(c) + [1.0])[:4])

def val(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, tuple): return col(v)
    if isinstance(v, (int, float)): return "%g" % v if isinstance(v, float) else str(v)
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, dict) and v.get("__psa"): return "PackedStringArray(%s)" % ", ".join(json.dumps(x, ensure_ascii=False) for x in v["items"])
    if isinstance(v, dict) and v.get("__pfa"): return "PackedFloat32Array(%s)" % ", ".join("%g" % x for x in v["items"])
    if isinstance(v, dict) and v.get("__v2"): return "Vector2(%g, %g)" % tuple(v["xy"])
    if isinstance(v, list): return "[" + ", ".join(val(x) for x in v) + "]"
    raise ValueError(v)

def psa(*items): return {"__psa": True, "items": list(items)}
def pfa(*items): return {"__pfa": True, "items": list(items)}
def v2(x, y): return {"__v2": True, "xy": [x, y]}

def write_tres(path, cls, script, fields):
    lines = ['[gd_resource type="Resource" script_class="%s" format=3]' % cls, "",
             '[ext_resource type="Script" path="%s" id="1"]' % script, "", "[resource]", 'script = ExtResource("1")']
    for k, v in fields.items():
        lines.append("%s = %s" % (k, val(v)))
    full = os.path.join(ROOT, path.replace("res://", ""))
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w").write("\n".join(lines) + "\n")

CROPS = [
    # id, name, seasons, stage_days, yield, seed price, sell, footprint, shape, leaf, flower, fruit, height, fruit_size, fruit_count, regrow, extra
    ("turnip", "Turnip", ["spring"], [1, 1, 1, 1], 1, 40, 70, 0.5, "root", (0.36, 0.6, 0.22), (0.95, 0.95, 0.7), (0.92, 0.88, 0.95), 0.28, 0.11, 1, 0, {}),
    ("carrot", "Carrot", ["spring", "autumn"], [1, 1, 1.5, 1.5], 1, 35, 55, 0.5, "root", (0.3, 0.6, 0.2), (1.0, 1.0, 0.92), (0.95, 0.5, 0.1), 0.32, 0.06, 1, 0, {}),
    ("potato", "Potato", ["spring", "autumn"], [1, 1.5, 2, 1.5], 4, 60, 45, 0.5, "tuber", (0.28, 0.5, 0.2), (0.85, 0.8, 0.95), (0.72, 0.58, 0.38), 0.45, 0.055, 4, 0, {}),
    ("strawberry", "Strawberry", ["spring"], [1, 1.5, 2, 1.5], 3, 120, 60, 0.5, "bush", (0.22, 0.48, 0.18), (1.0, 1.0, 0.95), (0.85, 0.08, 0.1), 0.3, 0.035, 6, 0, {}),
    ("tomato", "Tomato", ["summer"], [1, 1.5, 2, 1.5], 3, 90, 50, 1.0, "bush", (0.24, 0.45, 0.16), (1.0, 0.9, 0.2), (0.9, 0.18, 0.1), 0.85, 0.055, 7, 0, {}),
    ("corn", "Corn", ["summer"], [1, 2, 2, 2], 2, 110, 120, 0.5, "stalk", (0.4, 0.58, 0.2), (0.85, 0.75, 0.45), (0.98, 0.82, 0.3), 1.5, 0.06, 2, 0, {}),
    ("sunflower", "Sunflower", ["summer"], [1, 1.5, 2, 1.5], 1, 50, 110, 0.5, "stalk", (0.32, 0.52, 0.18), (1.0, 0.8, 0.1), (0.3, 0.2, 0.1), 1.7, 0.06, 1, 0, {}),
    ("pumpkin", "Pumpkin", ["autumn"], [1, 2, 2, 2], 1, 140, 300, 1.0, "vine", (0.26, 0.46, 0.18), (1.0, 0.75, 0.15), (0.95, 0.5, 0.1), 0.3, 0.24, 1, 0, {}),
    ("eggplant", "Eggplant", ["autumn"], [1, 1, 1.5, 1.5], 2, 80, 90, 1.0, "bush", (0.25, 0.42, 0.2), (0.7, 0.5, 0.9), (0.3, 0.12, 0.38), 0.65, 0.055, 5, 0, {}),
    ("apple_tree", "Apple Tree", ["spring", "summer", "autumn"], [2, 3, 3, 2], 4, 400, 45, 1.0, "tree", (0.25, 0.48, 0.18), (1.0, 0.86, 0.9), (0.85, 0.12, 0.1), 2.6, 0.06, 12, 3,
        {"seed_id": "apple_sapling", "seed_name": "Apple Sapling", "produce_id": "apple", "produce_name": "Apple"}),
    ("banana", "Banana Plant", ["summer", "autumn"], [2, 2, 3, 2], 3, 350, 60, 1.0, "palm", (0.3, 0.58, 0.22), (0.55, 0.15, 0.32), (0.95, 0.85, 0.25), 2.4, 0.03, 9, 4,
        {"seed_id": "banana_sucker", "seed_name": "Banana Sucker", "produce_id": "banana_fruit", "produce_name": "Bananas"}),
]

config_path = os.path.join(ROOT, "data/asset_modules.json")
config = json.load(open(config_path))

variants = {}
for c in CROPS:
    (cid, name, seasons, days, yld, seed, sell, fp, shape, leaf, flower, fruit, h, fs, fc, regrow, extra) = c
    path = "res://modules/crop_types/%s/%s.tres" % (cid, cid)
    fields = {"id": cid, "type": "crop_types", "display_name": name,
              "description": "%s - %s m², %s, %g days to harvest%s." % (name, fp, "/".join(seasons), sum(days), (", fruits again every %g days" % regrow) if regrow else "")}
    fields.update(extra)
    fields.update({"seasons": psa(*seasons), "stage_days": pfa(*days), "yield_amount": yld, "seed_price": seed, "sell_price": sell,
                   "footprint_m2": float(fp), "shape": shape, "leaf_color": leaf, "flower_color": flower, "fruit_color": fruit,
                   "height": float(h), "fruit_size": float(fs), "fruit_count": fc, "regrow_days": float(regrow)})
    write_tres(path, "CropDef", "res://modules/crop_types/crop_def.gd", fields)
    variants[cid] = path
config["crop_types"] = {"collection": True, "active": "turnip", "variants": variants}

# ---- garden look + layout
G = "res://modules/garden/garden_style.gd"
write_tres("res://modules/garden/rustic_rows.tres", "GardenStyle", G, {"id": "rustic_rows", "type": "garden", "display_name": "Rustic rows (dark loam, packed-earth paths)",
    "soil_dry": (0.40, 0.27, 0.16), "soil_wet": (0.24, 0.16, 0.10), "path_color": (0.62, 0.55, 0.42), "edge_color": (0.45, 0.32, 0.2),
    "raised_beds": False, "fence_height": 1.0, "expand_cost": 150})
write_tres("res://modules/garden/raised_beds.tres", "GardenStyle", G, {"id": "raised_beds", "type": "garden", "display_name": "Raised timber beds, gravel paths",
    "soil_dry": (0.36, 0.25, 0.17), "soil_wet": (0.2, 0.14, 0.1), "path_color": (0.7, 0.68, 0.62), "edge_color": (0.55, 0.4, 0.25),
    "raised_beds": True, "fence_height": 1.1, "expand_cost": 200})
config["garden"] = {"active": "rustic_rows", "variants": {"rustic_rows": "res://modules/garden/rustic_rows.tres", "raised_beds": "res://modules/garden/raised_beds.tres"}}

R = "res://modules/garden_rules/garden_rules.gd"
write_tres("res://modules/garden_rules/seasonal.tres", "GardenRules", R, {"id": "seasonal", "type": "garden_rules", "display_name": "Seasonal (crops only grow in their seasons)",
    "use_seasons": True})
write_tres("res://modules/garden_rules/any_season.tres", "GardenRules", R, {"id": "any_season", "type": "garden_rules", "display_name": "Greenhouse (no season limits)",
    "use_seasons": False})
config["garden_rules"] = {"active": "seasonal", "variants": {"seasonal": "res://modules/garden_rules/seasonal.tres", "any_season": "res://modules/garden_rules/any_season.tres"}}

L = "res://modules/lighting/lighting_style.gd"
write_tres("res://modules/lighting/warm_bulbs.tres", "LightingStyle", L, {"id": "warm_bulbs", "type": "lighting", "display_name": "Warm incandescent bulbs",
    "bulb_color": (1.0, 0.78, 0.48), "window_color": (1.0, 0.72, 0.38), "porch_energy": 2.4, "on_before_sunset_h": 0.25, "off_after_sunrise_h": 0.25,
    "candle_color": (1.0, 0.55, 0.2), "candle_energy": 1.3, "flicker": 0.25})
write_tres("res://modules/lighting/cool_led.tres", "LightingStyle", L, {"id": "cool_led", "type": "lighting", "display_name": "Cool white LEDs",
    "bulb_color": (0.85, 0.92, 1.0), "window_color": (0.85, 0.9, 1.0), "porch_energy": 2.8, "on_before_sunset_h": 0.0, "off_after_sunrise_h": 0.0,
    "candle_color": (1.0, 0.6, 0.25), "candle_energy": 1.2, "flicker": 0.2})
config["lighting"] = {"active": "warm_bulbs", "variants": {"warm_bulbs": "res://modules/lighting/warm_bulbs.tres", "cool_led": "res://modules/lighting/cool_led.tres"}}

P = "res://modules/power/power_style.gd"
write_tres("res://modules/power/breaker_panel.tres", "PowerStyle", P, {"id": "breaker_panel", "type": "power", "display_name": "Grey breaker panel",
    "box_color": (0.62, 0.64, 0.66), "lever_color": (0.85, 0.15, 0.1), "fireplace": True, "candles_per_home": 3, "lantern": True})
write_tres("res://modules/power/old_fuse_box.tres", "PowerStyle", P, {"id": "old_fuse_box", "type": "power", "display_name": "Old wooden fuse box",
    "box_color": (0.45, 0.3, 0.18), "lever_color": (0.15, 0.15, 0.15), "fireplace": True, "candles_per_home": 5, "lantern": False})
config["power"] = {"active": "breaker_panel", "variants": {"breaker_panel": "res://modules/power/breaker_panel.tres", "old_fuse_box": "res://modules/power/old_fuse_box.tres"}}

Y = "res://modules/yards/yard_style.gd"
write_tres("res://modules/yards/rail_fence.tres", "YardStyle", Y, {"id": "rail_fence", "type": "yards", "display_name": "Wooden post-and-rail fences",
    "kind": "rail", "wood_color": (0.5, 0.36, 0.22), "height": 0.95, "post_spacing": 1.6})
write_tres("res://modules/yards/picket.tres", "YardStyle", Y, {"id": "picket", "type": "yards", "display_name": "White picket fences",
    "kind": "picket", "wood_color": (0.93, 0.92, 0.88), "height": 0.9, "post_spacing": 1.6})
config["yards"] = {"active": "rail_fence", "variants": {"rail_fence": "res://modules/yards/rail_fence.tres", "picket": "res://modules/yards/picket.tres"}}

M = "res://modules/minimap/minimap_style.gd"
write_tres("res://modules/minimap/parchment.tres", "MinimapStyle", M, {"id": "parchment", "type": "minimap", "display_name": "Parchment map",
    "background": (0.86, 0.8, 0.64, 0.92), "grass": (0.55, 0.66, 0.38), "road": (0.42, 0.4, 0.38), "dirt": (0.68, 0.56, 0.4), "water": (0.35, 0.58, 0.78),
    "building": (0.62, 0.36, 0.26), "forest": (0.25, 0.42, 0.22), "player": (0.9, 0.15, 0.1), "npc": (0.15, 0.3, 0.8), "size": 220, "metres": 90.0})
write_tres("res://modules/minimap/night.tres", "MinimapStyle", M, {"id": "night", "type": "minimap", "display_name": "Dark GPS map",
    "background": (0.08, 0.1, 0.14, 0.9), "grass": (0.16, 0.24, 0.18), "road": (0.55, 0.57, 0.62), "dirt": (0.38, 0.33, 0.26), "water": (0.1, 0.25, 0.45),
    "building": (0.8, 0.62, 0.3), "forest": (0.1, 0.18, 0.12), "player": (1.0, 0.85, 0.2), "npc": (0.4, 0.8, 1.0), "size": 220, "metres": 90.0})
config["minimap"] = {"active": "parchment", "variants": {"parchment": "res://modules/minimap/parchment.tres", "night": "res://modules/minimap/night.tres"}}

S = "res://modules/npc_social/social_style.gd"
write_tres("res://modules/npc_social/chatty.tres", "SocialStyle", S, {"id": "chatty", "type": "npc_social", "display_name": "Chatty neighbours",
    "chat_distance": 3.2, "chat_chance": 0.6, "chat_seconds": 7.0, "greet_distance": 3.5, "wander_radius": 14.0,
    "lines": psa("Lovely weather today!", "Did you see the new crops at the farm?", "The café has fresh bread.", "I'm off to the market.",
                 "Have you been to the beach?", "The fish are biting at the pier.", "Busy day at work...", "Power went out again last night!",
                 "Those sunflowers are huge.", "See you at the square!"),
    "replies": psa("Ha, indeed!", "Oh really?", "Sounds good.", "Let's go together.", "Maybe tomorrow.", "Nice!"),
    "greetings": psa("Hello, farmer!", "Morning!", "Hi there!", "How's the garden?", "Evening!")})
write_tres("res://modules/npc_social/quiet.tres", "SocialStyle", S, {"id": "quiet", "type": "npc_social", "display_name": "Quiet town",
    "chat_distance": 2.5, "chat_chance": 0.2, "chat_seconds": 4.0, "greet_distance": 2.5, "wander_radius": 8.0,
    "lines": psa("Hm.", "Nice day.", "..."), "replies": psa("Mm-hm.", "Yes."), "greetings": psa("Hello.", "Hi.")})
config["npc_social"] = {"active": "chatty", "variants": {"chatty": "res://modules/npc_social/chatty.tres", "quiet": "res://modules/npc_social/quiet.tres"}}

LS = "res://modules/landscape/landscape_style.gd"
write_tres("res://modules/landscape/highlands.tres", "LandscapeStyle", LS, {"id": "highlands", "type": "landscape", "display_name": "Highlands: tall forest, snowy mountains, river",
    "forest_rings": 4, "forest_density": 1.0, "forest_scale": v2(1.5, 2.4), "far_trees": 900, "mountain_height": 70.0, "mountain_count": 16,
    "mountain_color": (0.38, 0.4, 0.42), "snow_line": 0.62, "river": True, "river_width": 4.0, "river_color": (0.3, 0.56, 0.64)})
write_tres("res://modules/landscape/lowlands.tres", "LandscapeStyle", LS, {"id": "lowlands", "type": "landscape", "display_name": "Lowlands: lighter forest, green hills",
    "forest_rings": 2, "forest_density": 0.6, "forest_scale": v2(1.1, 1.6), "far_trees": 400, "mountain_height": 30.0, "mountain_count": 10,
    "mountain_color": (0.3, 0.42, 0.25), "snow_line": 1.5, "river": True, "river_width": 3.0, "river_color": (0.32, 0.58, 0.6)})
config["landscape"] = {"active": "highlands", "variants": {"highlands": "res://modules/landscape/highlands.tres", "lowlands": "res://modules/landscape/lowlands.tres"}}

TD = "res://modules/tool_types/tool_def.gd"
TOOLS = [
    # id, name, kind, tier, anim, sound, shape, head, handle, buy, starter, unlock_day, requires, reach, secs, desc
    ("hoe", "Hoe", "hoe", 1, "swing", "hoe_dig", "blade", (0.5, 0.5, 0.52), (0.5, 0.34, 0.2), 0, False, 1, "", 1, 0.8, "Tills one garden cell (0.5 m²)."),
    ("steel_hoe", "Steel Hoe", "hoe", 2, "swing", "hoe_dig", "blade", (0.78, 0.8, 0.85), (0.35, 0.22, 0.12), 450, False, 3, "hoe", 2, 0.7, "Upgrade: tills two cells (1 m²) per swing. Sold from day 3."),
    ("watering_can", "Watering Can", "watering_can", 1, "pour", "water_pour", "can", (0.45, 0.6, 0.7), (0.35, 0.45, 0.5), 0, False, 1, "", 1, 1.0, "Waters one crop."),
    ("copper_can", "Copper Watering Can", "watering_can", 2, "pour", "water_pour", "can", (0.8, 0.45, 0.25), (0.6, 0.32, 0.18), 800, False, 1, "watering_can", 3, 1.0, "Upgrade: waters a 3x3 area at once and holds 40 L."),
    ("seed_pouch", "Seed Pouch", "seeds", 1, "sow", "seeds", "pouch", (0.75, 0.62, 0.4), (0.5, 0.38, 0.22), 0, True, 1, "", 1, 0.7, "Sows seeds (always with you)."),
    ("harvest_basket", "Harvest Basket", "hands", 1, "pick", "harvest", "basket", (0.7, 0.52, 0.28), (0.55, 0.4, 0.2), 0, True, 1, "", 1, 0.7, "Holds the harvest (always with you)."),
    ("hammer", "Hammer", "hammer", 1, "hammer", "hammer", "hammer", (0.35, 0.36, 0.38), (0.5, 0.34, 0.2), 250, False, 2, "", 1, 0.9, "Builds things: garden expansions and fences. Sold from day 2."),
]
tool_variants = {}
for (tid, name, kind, tier, anim, snd, shape, head, handle, buy, starter, uday, req, reach, secs, desc) in TOOLS:
    path = "res://modules/tool_types/%s.tres" % tid
    write_tres(path, "ToolDef", TD, {"id": tid, "type": "tool_types", "display_name": name, "description": desc,
        "item_id": tid, "kind": kind, "tier": tier, "anim": anim, "sound": "&\"%s\"" % snd if False else snd, "shape": shape,
        "head_color": head, "handle_color": handle, "buy": buy, "starter": starter, "unlock_day": uday, "requires": req,
        "reach": reach, "anim_seconds": secs})
    tool_variants[tid] = path
config["tool_types"] = {"active": "hoe", "collection": True, "variants": tool_variants}

HS = "res://modules/house_styles/house_style.gd"
HOUSES = {
    "wooden": {"display_name": "Wooden house", "kind": "wooden", "pattern": 0, "wall_color": (0.62, 0.44, 0.28), "joint_color": (0.28, 0.18, 0.1),
        "roof_color": (0.42, 0.24, 0.16), "roof_type": "gable", "trim_color": (0.9, 0.86, 0.76), "chimney": True,
        "interior_wall": (0.74, 0.58, 0.4), "interior_floor": (0.42, 0.28, 0.16), "description": "Timber siding, gable roof; cosy wooden interior."},
    "stone": {"display_name": "Stone cottage", "kind": "stone", "pattern": 1, "wall_color": (0.62, 0.6, 0.56), "joint_color": (0.36, 0.35, 0.33),
        "roof_color": (0.3, 0.32, 0.36), "roof_type": "gable", "trim_color": (0.85, 0.82, 0.76), "chimney": True,
        "interior_wall": (0.88, 0.84, 0.76), "interior_floor": (0.5, 0.48, 0.45), "description": "Stone walls, slate roof; whitewashed interior with a stone floor."},
    "modern": {"display_name": "Modern house", "kind": "modern", "pattern": 2, "wall_color": (0.9, 0.9, 0.88), "joint_color": (0.62, 0.63, 0.64),
        "roof_color": (0.22, 0.23, 0.25), "roof_type": "flat", "trim_color": (0.18, 0.19, 0.21), "chimney": False,
        "interior_wall": (0.95, 0.95, 0.94), "interior_floor": (0.7, 0.68, 0.64), "description": "Smooth panels, flat roof; bright minimalist interior."},
}
FURN = {"wooden": '{"rustic": true, "tv": "televisionVintage", "sofa": "loungeChair", "table": "table"}',
        "stone": '{"table": "tableCloth", "extra": "bookcaseClosedWide", "rug": "rugRound"}',
        "modern": '{"tv": "televisionModern", "sofa": "loungeSofa", "extra": "lampRoundFloor", "table": "tableRound", "rug": "rugRectangle"}'}
hv = {}
for hid, f in HOUSES.items():
    fields = {"id": hid, "type": "house_styles"}
    fields.update(f)
    path = "res://modules/house_styles/%s.tres" % hid
    write_tres(path, "HouseStyle", HS, fields)
    full = os.path.join(ROOT, path.replace("res://", ""))
    open(full, "a").write("furniture = %s\n" % FURN[hid])
    hv[hid] = path
config["house_styles"] = {"active": "wooden", "collection": True, "variants": hv}

json.dump(config, open(config_path, "w"), indent=2)
print("modules written:", ", ".join(k for k in config))
