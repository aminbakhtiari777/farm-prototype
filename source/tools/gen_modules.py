#!/usr/bin/env python3
"""Writes the asset-module .tres variants under modules/ and data/asset_modules.json.
Edit the VARIANTS table below (or hand-edit the .tres files in the editor)."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def v(x):
    if isinstance(x, bool): return "true" if x else "false"
    if isinstance(x, (int, float)): return repr(float(x)) if isinstance(x, float) else str(x)
    if isinstance(x, str): return json.dumps(x)
    if isinstance(x, tuple) and x[0] == "C": return "Color(%s, %s, %s, %s)" % (x[1][0], x[1][1], x[1][2], x[1][3] if len(x[1]) > 3 else 1.0)
    if isinstance(x, tuple) and x[0] == "V2": return "Vector2(%s, %s)" % x[1]
    if isinstance(x, tuple) and x[0] == "PSA": return "PackedStringArray(%s)" % ", ".join(json.dumps(s) for s in x[1])
    if isinstance(x, tuple) and x[0] == "PCA": return "PackedColorArray(%s)" % ", ".join("%s, %s, %s, %s" % (c[0], c[1], c[2], c[3] if len(c) > 3 else 1.0) for c in x[1])
    if isinstance(x, list): return "[" + ", ".join(v(i) for i in x) + "]"
    if isinstance(x, dict): return "{\n" + ",\n".join("%s: %s" % (json.dumps(k), v(val)) for k, val in x.items()) + "\n}"
    raise TypeError(x)

def C(r, g, b, a=1.0): return ("C", (r, g, b, a))
def PSA(*s): return ("PSA", s)
def PCA(*c): return ("PCA", c)

SCRIPTS = {"trees": ("TreeStyle", "trees/tree_style.gd"), "rocks": ("RockStyle", "rocks/rock_style.gd"),
    "plants": ("PlantStyle", "plants/plant_style.gd"), "crops": ("CropStyle", "crops/crop_style.gd"),
    "fences": ("FenceStyle", "fences/fence_style.gd"), "terrain": ("TerrainStyle", "terrain/terrain_style.gd"),
    "buildings": ("BuildingStyle", "buildings/building_style.gd"), "characters": ("CharacterStyle", "characters/character_style.gd"),
    "animals": ("AnimalStyle", "animals/animal_style.gd"), "furniture": ("FurnitureStyle", "furniture/furniture_style.gd"),
    "water": ("WaterStyle", "water/water_style.gd"), "sky": ("SkyStyle", "sky/sky_style.gd")}

Q = "res://assets/third_party/quaternius/"
LEAF = {"spring": C(1.05, 1.18, 0.85), "summer": C(0.82, 0.95, 0.72), "autumn": C(1.9, 0.95, 0.32), "winter": C(1, 1, 1)}
PINE = {"spring": C(1.0, 1.05, 0.95), "summer": C(0.9, 0.95, 0.85), "autumn": C(0.95, 0.95, 0.85), "winter": C(1.25, 1.35, 1.4)}
UBC = {"models": {"male": Q + "characters/Superhero_Male_FullBody.gltf", "female": Q + "characters/Superhero_Female_FullBody.gltf"},
    "skins": {"male": PSA(Q + "characters/T_Superhero_Male_Ligh.png", Q + "characters/T_Superhero_Male_Dark.png"),
              "female": PSA(Q + "characters/T_Superhero_Female_Light_BaseColor.png", Q + "characters/T_Superhero_Female_Dark_BaseColor.png")},
    "animation_library": Q + "animations/UAL1_Standard.glb", "hair_dir": Q + "characters/hair/"}
COVER = [["Bush_Common", 70, 0.55, 0.85, 1.6], ["Bush_Common_Flowers", 40, 0.5, 0.8, 1.6], ["Fern_1", 60, 0.12, 0.2, 1.0],
         ["Flower_3_Group", 70, 0.3, 0.45, 0.8], ["Flower_4_Group", 60, 0.28, 0.42, 0.8], ["Plant_1_Big", 25, 0.25, 0.35, 1.0]]
ROCKS = [["Rock_Medium_1", 22, 0.25, 0.6, 1.4], ["Rock_Medium_2", 22, 0.25, 0.6, 1.4], ["Rock_Medium_3", 16, 0.25, 0.55, 1.4]]
CARS = PSA("police", "ambulance", "delivery", "sedan", "van", "sedan", "sedan", "tractor")

VARIANTS = {
  "trees": {"active": "quaternius_mixed", "variants": {
    "quaternius_mixed": {"display_name": "Quaternius mixed woodland", "broadleaf": PSA(*["CommonTree_%d" % i for i in range(1, 6)]),
        "pines": PSA(*["Pine_%d" % i for i in range(1, 6)]), "edge_models": PSA("CommonTree_5", "CommonTree_3", "Pine_5", "Pine_2"),
        "dead_tree": "DeadTree_1", "pine_fraction": 0.3, "leaf_tints": LEAF, "pine_tints": PINE},
    "pine_forest": {"display_name": "Evergreen pine forest", "broadleaf": PSA("CommonTree_2"), "pines": PSA(*["Pine_%d" % i for i in range(1, 6)]),
        "edge_models": PSA("Pine_5", "Pine_2", "Pine_4"), "dead_tree": "", "pine_fraction": 0.85, "leaf_tints": LEAF, "pine_tints": PINE}}},
  "rocks": {"active": "quaternius", "variants": {
    "quaternius": {"display_name": "Quaternius grey rocks", "kinds": ROCKS},
    "mossy_boulders": {"display_name": "Mossy boulders", "kinds": [["Rock_Medium_1", 30, 0.5, 0.95, 1.8], ["Rock_Medium_3", 24, 0.45, 0.9, 1.8]], "tint": C(0.78, 0.92, 0.7)}}},
  "plants": {"active": "meadow", "variants": {
    "meadow": {"display_name": "Meadow grass + wildflowers", "ground_cover": COVER,
        "flower_colors": PCA((0.97, 0.95, 0.9), (0.98, 0.85, 0.3), (0.75, 0.6, 0.9), (0.95, 0.6, 0.65))},
    "lush": {"display_name": "Lush tall grass", "ground_cover": [["Bush_Common", 110, 0.6, 0.95, 1.6], ["Fern_1", 110, 0.14, 0.24, 1.0], ["Plant_1_Big", 50, 0.3, 0.4, 1.0]],
        "grass_height": ("V2", (0.32, 0.6)), "grass_density": 1.2, "flower_colors": PCA((1.0, 0.45, 0.35), (1.0, 0.9, 0.4))}}},
  "crops": {"active": "classic", "variants": {
    "classic": {"display_name": "Classic rounded crops"},
    "giant": {"display_name": "Giant show crops", "plant_scale": 1.35, "leaf_tint": C(0.85, 1.1, 0.8)}}},
  "fences": {"active": "rustic_wood", "variants": {
    "rustic_wood": {"display_name": "Rustic wooden posts + rails"},
    "white_picket": {"display_name": "White picket fence", "post_spacing": 1.4, "post_height": 0.95, "post_size": 0.09, "rails": 2, "color": C(2.4, 2.4, 2.3)}}},
  "terrain": {"active": "green_valley", "variants": {
    "green_valley": {"display_name": "Green valley"},
    "dry_steppe": {"display_name": "Dry steppe", "shader_overrides": {"grass_tint": C(1.25, 1.08, 0.7)}}}},
  "buildings": {"active": "village", "variants": {
    "village": {"display_name": "Village (layout colours)"},
    "coastal": {"display_name": "Coastal white + terracotta", "wall_tint": C(1.12, 1.12, 1.12),
        "roof_palette": PCA((0.72, 0.36, 0.22), (0.66, 0.32, 0.2), (0.2, 0.35, 0.55))}}},
  "characters": {"active": "quaternius_ubc", "variants": {
    "quaternius_ubc": dict(UBC, display_name="Quaternius Universal Base Characters"),
    "quaternius_ubc_tall": dict(UBC, display_name="UBC, taller build", body_scale=1.04)}},
  "animals": {"active": "white_sheep", "variants": {
    "white_sheep": {"display_name": "White sheep"},
    "black_sheep": {"display_name": "Black sheep", "wool_color": C(0.2, 0.18, 0.17), "face_color": C(0.08, 0.07, 0.07)}}},
  "furniture": {"active": "kenney", "variants": {
    "kenney": {"display_name": "Kenney furniture / food / cars", "parked_cars": CARS},
    "kenney_quiet_town": {"display_name": "Kenney, fewer cars", "parked_cars": PSA("sedan", "tractor")}}},
  "water": {"active": "atlantic", "variants": {
    "atlantic": {"display_name": "Teal sea, green pond", "sea": {"shallow_color": C(0.3, 0.72, 0.72), "deep_color": C(0.05, 0.27, 0.42)}, "pond": {"wave_height": 0.025, "shallow_color": C(0.25, 0.5, 0.4), "deep_color": C(0.08, 0.25, 0.25)}},
    "tropical": {"display_name": "Tropical turquoise", "sea": {"shallow_color": C(0.25, 0.85, 0.8), "deep_color": C(0.02, 0.35, 0.55)},
        "pond": {"wave_height": 0.025, "shallow_color": C(0.3, 0.6, 0.5), "deep_color": C(0.1, 0.3, 0.3)}}}},
  "sky": {"active": "clear", "variants": {
    "clear": {"display_name": "Clear blue"},
    "pastel": {"display_name": "Pastel", "day_zenith": C(0.45, 0.55, 0.85), "day_horizon": C(0.95, 0.85, 0.85), "dusk_horizon": C(1.0, 0.5, 0.55)}}},
}

config = {}
for t, entry in VARIANTS.items():
    cls, script = SCRIPTS[t]
    config[t] = {"active": entry["active"], "variants": {}}
    for vid, props in entry["variants"].items():
        path = "modules/%s/%s.tres" % (t, vid)
        lines = ['[gd_resource type="Resource" script_class="%s" format=3]' % cls, "",
                 '[ext_resource type="Script" path="res://modules/%s" id="1"]' % script, "", "[resource]", 'script = ExtResource("1")',
                 'id = %s' % json.dumps(vid), 'type = %s' % json.dumps(t)]
        for k, val in props.items():
            lines.append("%s = %s" % (k, v(val)))
        open(os.path.join(ROOT, path), "w").write("\n".join(lines) + "\n")
        config[t]["variants"][vid] = "res://" + path
json.dump(config, open(os.path.join(ROOT, "data/asset_modules.json"), "w"), indent=2)
print("modules:", ", ".join("%s(%d)" % (t, len(e["variants"])) for t, e in config.items()))
