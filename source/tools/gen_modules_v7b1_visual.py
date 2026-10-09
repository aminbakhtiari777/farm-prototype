#!/usr/bin/env python3
"""v7b.1 visual / realism modules:
  car_bodies, resident_looks, door_plaques, house_variety, street_plants,
  fire_truck, city_hall_interior, families
(+ patches: population families, dialogue jobs/places/names, ui_text, backstories).
Re-run after editing; then tools/build_manifest.py."""
import json, os, re, copy
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, psa, config, config_path, V2, V3 = (ns["style_script"], ns["emit"], ns["psa"], ns["config"],
                                                      ns["config_path"], ns["V2"], ns["V3"])
val = ns["val"]


def L(en, fa):
    return {"en": en, "fa": fa}


def C(r, g, b, a=1.0):
    return (r, g, b, a) if a < 1 else (r, g, b)


# ====================================================================== 1. car bodies
style_script("car_bodies", "car_body_style", "CarBodyStyle",
    "v7b.1 self-made procedural car bodies: opaque paint (no more pink Kenney\n"
    "colormap / alpha-red fire van), see-through glass, seats, dashboard with\n"
    "gauges, a steering wheel that turns with DrivableCar.steer_amount, side\n"
    "mirrors, grille, headlights, bumpers, hood lines, Persian number plates,\n"
    "and a glass sunroof the cockpit camera can hide. Liveries for police,\n"
    "ambulance, taxi and the fire truck. Consumer: CarBody via VehicleKit.model.", [
    ("enabled", "bool", "true", ""),
    ("palette", "Array", "[]", "{en, fa, color}"),
    ("shapes", "Dictionary", "{}", "model -> {form, length, width, height, ...}"),
    ("liveries", "Dictionary", "{}", "police / ambulance / taxi / firetruck"),
    ("glass_alpha", "float", "0.32", ""),
    ("seat_color", "Color", "Color(0.22, 0.2, 0.19)", ""),
    ("wheel_turn_deg", "float", "140.0", "steering wheel rotation at full lock"),
    ("sunroof", "bool", "true", ""),
    ("merge_static", "bool", "true", "bake static parts into one mesh"),
    ("plate_frame", "bool", "true", ""),
])
PALETTE = [
    {"en": "white", "fa": "سفید", "color": C(0.92, 0.92, 0.9)},
    {"en": "silver", "fa": "نقره‌ای", "color": C(0.72, 0.74, 0.76)},
    {"en": "black", "fa": "مشکی", "color": C(0.08, 0.08, 0.09)},
    {"en": "dark blue", "fa": "آبی تیره", "color": C(0.12, 0.22, 0.48)},
    {"en": "red", "fa": "قرمز", "color": C(0.72, 0.12, 0.1)},
    {"en": "beige", "fa": "بژ", "color": C(0.82, 0.74, 0.58)},
    {"en": "forest green", "fa": "سبز جنگلی", "color": C(0.18, 0.32, 0.22)},
    {"en": "pearl grey", "fa": "خاکستری مرواریدی", "color": C(0.58, 0.6, 0.62)},
    {"en": "burgundy", "fa": "زرشکی", "color": C(0.42, 0.08, 0.14)},
    {"en": "sky blue", "fa": "آبی آسمانی", "color": C(0.45, 0.62, 0.78)},
]
SHAPES = {
    "sedan": {"form": "car", "length": 4.4, "width": 1.78, "height": 1.48, "wheel_r": 0.34, "belt": 0.95,
              "hood": 1.15, "trunk": 0.9, "rake": 0.55, "rear_rake": 0.45, "rear_doors": True,
              "variants": ["sedan", "hatch", "suv", "taxi"]},
    "hatch": {"form": "car", "length": 4.0, "width": 1.72, "height": 1.5, "wheel_r": 0.33, "belt": 0.95,
              "hood": 1.0, "trunk": 0.45, "rake": 0.55, "rear_rake": 0.75, "rear_doors": True},
    "suv": {"form": "car", "length": 4.6, "width": 1.9, "height": 1.78, "wheel_r": 0.4, "belt": 1.1,
            "hood": 1.2, "trunk": 0.85, "rake": 0.45, "rear_rake": 0.35, "rear_doors": True},
    "taxi": {"form": "car", "length": 4.4, "width": 1.78, "height": 1.5, "wheel_r": 0.34, "belt": 0.95,
             "hood": 1.15, "trunk": 0.9, "rake": 0.55, "rear_rake": 0.45, "rear_doors": True, "livery": "taxi"},
    "van": {"form": "box", "length": 4.8, "width": 1.95, "height": 2.15, "wheel_r": 0.37, "belt": 1.05, "cab": 2.0},
    "delivery": {"form": "box", "length": 5.0, "width": 2.0, "height": 2.35, "wheel_r": 0.4, "belt": 1.1, "cab": 2.0},
    "police": {"form": "car", "length": 4.5, "width": 1.82, "height": 1.52, "wheel_r": 0.35, "belt": 0.98,
               "hood": 1.2, "trunk": 0.9, "rake": 0.55, "rear_rake": 0.4, "rear_doors": True, "livery": "police"},
    "ambulance": {"form": "box", "length": 5.4, "width": 2.05, "height": 2.45, "wheel_r": 0.4, "belt": 1.1, "cab": 2.1, "livery": "ambulance"},
    "firetruck": {"form": "truck", "length": 7.2, "width": 2.45, "height": 3.0, "wheel_r": 0.52, "belt": 1.45, "livery": "firetruck"},
    "pickup": {"form": "car", "length": 5.0, "width": 1.9, "height": 1.7, "wheel_r": 0.4, "belt": 1.05,
               "hood": 1.3, "trunk": 1.6, "rake": 0.4, "rear_rake": 0.15, "rear_doors": False, "bed": "pickup"},
    "tractor": {"form": "car", "length": 3.4, "width": 1.7, "height": 1.9, "wheel_r": 0.55, "belt": 1.1,
                "hood": 1.4, "trunk": 0.4, "rake": 0.3, "rear_rake": 0.2, "rear_doors": False},
}
LIVERIES = {
    "police": {"body": C(0.95, 0.95, 0.95), "stripe": C(0.1, 0.2, 0.55), "text_fa": "کلانتری", "text_en": "POLICE",
               "text_color": C(0.1, 0.2, 0.55)},
    "ambulance": {"body": C(0.96, 0.96, 0.95), "stripe": C(0.85, 0.15, 0.08), "text_fa": "اورژانس ۱۱۵", "text_en": "AMBULANCE",
                  "text_color": C(0.85, 0.1, 0.08)},
    "taxi": {"body": C(0.95, 0.82, 0.15), "stripe": C(0.05, 0.05, 0.05), "text_fa": "تاکسی", "text_en": "TAXI",
             "text_color": C(0.05, 0.05, 0.05), "roof_sign": True},
    "firetruck": {"body": C(0.78, 0.08, 0.06), "stripe": C(0.96, 0.96, 0.94), "text_fa": "آتش‌نشانی ۱۲۵", "text_en": "FIRE 125",
                  "text_color": C(1, 1, 1)},
}
emit("car_bodies", "CarBodyStyle", "car_body_style", [
    ("realistic_cars", "Realistic cars", "Opaque paint, glass, interiors and Persian plates; fire truck is a real red truck.",
     {"name_fa": "ماشین‌های واقعی", "palette": PALETTE, "shapes": SHAPES, "liveries": LIVERIES}),
    ("simple_cars", "Simple cars", "Same bodies, fewer interior details (no gauges / sunroof).",
     {"name_fa": "ماشین‌های ساده", "palette": PALETTE, "shapes": SHAPES, "liveries": LIVERIES,
      "sunroof": False, "wheel_turn_deg": 90.0}),
], "realistic_cars")

# ====================================================================== 2. resident looks
style_script("resident_looks", "resident_looks_style", "ResidentLooksStyle",
    "v7b.1 richer faces on top of v6b npc_looks: skin tones, eye/brow/nose/mouth\n"
    "tints, beard/mustache options, hijab/scarf for women, height and build, and\n"
    "a mild family resemblance (siblings share a hair colour / skin tone seed).\n"
    "Deterministic per resident, saved with the game (CharacterLook + population).\n"
    "Consumer: ResidentLooks (Townspeople.outfit_for).", [
    ("enabled", "bool", "true", ""),
    ("skin_tones", "Array", "[]", "Color list (light..deep)"),
    ("eye_colors", "Array", "[]", ""),
    ("hijab_chance", "float", "0.55", "adult women"),
    ("mustache_chance", "float", "0.35", "men over 25 without a full beard"),
    ("height_range", "Vector2", "Vector2(0.92, 1.08)", "body_height"),
    ("build_range", "Vector2", "Vector2(0.86, 1.12)", "body_width"),
    ("family_share", "float", "0.7", "chance a child inherits the parents' hair / skin"),
    ("hair_women", "Array", "[]", ""),
    ("hair_men", "Array", "[]", ""),
    ("hijab_colors", "Array", "[]", ""),
])
emit("resident_looks", "ResidentLooksStyle", "resident_looks_style", [
    ("varied_faces", "Varied faces", "Distinct faces, hijabs, heights and builds with family resemblance.",
     {"name_fa": "چهره‌های گوناگون",
      "skin_tones": [C(0.96, 0.82, 0.7), C(0.9, 0.72, 0.58), C(0.82, 0.62, 0.48), C(0.7, 0.5, 0.38), C(0.55, 0.38, 0.28)],
      "eye_colors": [C(0.25, 0.18, 0.12), C(0.35, 0.45, 0.55), C(0.25, 0.4, 0.3), C(0.55, 0.4, 0.25)],
      "hair_women": ["Hair_Long", "Hair_Buns", "Hair_SimpleParted"],
      "hair_men": ["Hair_Buzzed", "Hair_SimpleParted", "Hair_Long"],
      "hijab_colors": [C(0.1, 0.1, 0.12), C(0.15, 0.2, 0.45), C(0.55, 0.15, 0.15), C(0.85, 0.85, 0.85), C(0.2, 0.4, 0.3), C(0.55, 0.4, 0.2)]}),
    ("subtle_faces", "Subtle faces", "Milder differences between residents.",
     {"name_fa": "چهره‌های نزدیک", "hijab_chance": 0.35, "mustache_chance": 0.2,
      "height_range": V2(0.96, 1.04), "build_range": V2(0.92, 1.06),
      "skin_tones": [C(0.92, 0.76, 0.62), C(0.85, 0.68, 0.52), C(0.75, 0.55, 0.42)],
      "eye_colors": [C(0.25, 0.18, 0.12), C(0.35, 0.45, 0.55)],
      "hair_women": ["Hair_Long", "Hair_Buns"], "hair_men": ["Hair_Buzzed", "Hair_SimpleParted"],
      "hijab_colors": [C(0.1, 0.1, 0.12), C(0.15, 0.2, 0.45), C(0.85, 0.85, 0.85)]}),
], "varied_faces")

# ====================================================================== 3. door plaques
style_script("door_plaques", "door_plaque_style", "DoorPlaqueStyle",
    "v7b.1: homes no longer get a big roof sign ('The X Family'). Instead a small\n"
    "brass / wood plaque by the front door shows 'خانواده آقای فلان' (or 'خانم'\n"
    "for a woman-led home). Business signs stay. The player's own house is\n"
    "highlighted on the minimap. Consumer: DoorPlaques (Building + Minimap).", [
    ("enabled", "bool", "true", ""),
    ("hide_home_roof_signs", "bool", "true", ""),
    ("plaque_color", "Color", "Color(0.42, 0.32, 0.18)", "brass"),
    ("plaque_w", "float", "1.05", "m"),
    ("plaque_h", "float", "0.28", "m"),
    ("font_size", "int", "36", ""),
    ("formula_fa", "String", '"خانواده آقای {surname}"', "{surname} / {title}"),
    ("formula_fa_f", "String", '"خانواده خانم {surname}"', "woman-led home"),
    ("formula_en", "String", '"The {surname} Family"', ""),
    ("home_marker_color", "Color", "Color(0.15, 0.75, 0.35)", "minimap"),
    ("home_pulse", "bool", "true", ""),
])
emit("door_plaques", "DoorPlaqueStyle", "door_plaque_style", [
    ("family_plaques", "Family plaques", "Small door plaques, no roof banners on homes; farmhouse highlighted on the map.",
     {"name_fa": "پلاک‌های خانوادگی"}),
    ("classic_signs", "Classic roof signs", "Keep the big roof family banners (v6b behaviour).",
     {"name_fa": "تابلوهای قدیمی", "enabled": False, "hide_home_roof_signs": False}),
], "family_plaques")

# ====================================================================== 4. house variety
style_script("house_variety", "house_variety_style", "HouseVarietyStyle",
    "v7b.1: homes differ more - roof shape, wall tint, shutter colour, porch,\n"
    "window count and a small front planter - deterministic per home id.\n"
    "Consumer: HouseVariety (Building._apply_layout).", [
    ("enabled", "bool", "true", ""),
    ("wall_tints", "Array", "[]", ""),
    ("roof_tints", "Array", "[]", ""),
    ("shutter_palette", "Array", "[]", ""),
    ("porch_chance", "float", "0.55", ""),
    ("timber_chance", "float", "0.35", ""),
    ("tall_chance", "float", "0.3", ""),
])
emit("house_variety", "HouseVarietyStyle", "house_variety_style", [
    ("varied_homes", "Varied homes", "Each house gets its own shape, roof and colours.",
     {"name_fa": "خانه‌های گوناگون",
      "wall_tints": [C(0.95, 0.9, 0.8), C(0.86, 0.78, 0.65), C(0.78, 0.84, 0.8), C(0.9, 0.82, 0.78),
                     C(0.82, 0.86, 0.9), C(0.92, 0.88, 0.72), C(0.88, 0.8, 0.7)],
      "roof_tints": [C(0.45, 0.22, 0.16), C(0.3, 0.32, 0.36), C(0.35, 0.42, 0.3), C(0.55, 0.28, 0.18),
                     C(0.25, 0.3, 0.45), C(0.4, 0.25, 0.2)],
      "shutter_palette": [C(0.2, 0.35, 0.55), C(0.55, 0.25, 0.2), C(0.25, 0.45, 0.3), C(0.85, 0.85, 0.82), C(0.4, 0.3, 0.2)]}),
    ("uniform_homes", "Uniform homes", "Milder differences.",
     {"name_fa": "خانه‌های یکدست", "porch_chance": 0.3, "timber_chance": 0.15, "tall_chance": 0.15,
      "wall_tints": [C(0.9, 0.86, 0.78), C(0.86, 0.82, 0.74)],
      "roof_tints": [C(0.4, 0.25, 0.18), C(0.32, 0.34, 0.38)],
      "shutter_palette": [C(0.25, 0.4, 0.55), C(0.55, 0.3, 0.22)]}),
], "varied_homes")

# ====================================================================== 5. street plants
style_script("street_plants", "street_plants_style", "StreetPlantsStyle",
    "v7b.1 varied street trees, bushes, flowers and planters along sidewalks and\n"
    "beside houses (deterministic per spot). MultiMesh where possible. Placed\n"
    "outside the asphalt + sidewalk band so they don't collide with traffic\n"
    "paint / lights. Consumer: StreetPlants.", [
    ("enabled", "bool", "true", ""),
    ("road_margin", "float", "0.4", "m beyond (half + sidewalk)"),
    ("sidewalk", "float", "1.8", "m (matches TownBuilder.SIDEWALK_W)"),
    ("tree_spacing", "float", "9.5", "m along a road"),
    ("species", "Array", "[]", "{id, kind (tree/bush/flowers/planter), color, size}"),
    ("clear_old_flowers", "bool", "true", "replace the pink ball 'ice cream' flower beds in the square"),
])
SPECIES = [
    {"id": "plane", "kind": "tree", "color": C(0.22, 0.48, 0.22), "size": 1.15, "trunk": C(0.4, 0.28, 0.16)},
    {"id": "cypress", "kind": "tree", "color": C(0.18, 0.38, 0.22), "size": 1.35, "trunk": C(0.35, 0.25, 0.15), "shape": "cone"},
    {"id": "olive", "kind": "tree", "color": C(0.4, 0.48, 0.28), "size": 0.95, "trunk": C(0.45, 0.35, 0.22)},
    {"id": "jacaranda", "kind": "tree", "color": C(0.45, 0.35, 0.7), "size": 1.05, "trunk": C(0.4, 0.28, 0.16)},
    {"id": "boxwood", "kind": "bush", "color": C(0.2, 0.42, 0.22), "size": 0.55},
    {"id": "lavender", "kind": "bush", "color": C(0.55, 0.4, 0.7), "size": 0.45},
    {"id": "rose", "kind": "flowers", "color": C(0.85, 0.2, 0.3), "size": 0.35},
    {"id": "marigold", "kind": "flowers", "color": C(0.95, 0.7, 0.15), "size": 0.32},
    {"id": "planter_stone", "kind": "planter", "color": C(0.7, 0.66, 0.58), "size": 0.7, "plant": C(0.25, 0.5, 0.25)},
    {"id": "planter_clay", "kind": "planter", "color": C(0.7, 0.4, 0.25), "size": 0.55, "plant": C(0.9, 0.3, 0.4)},
]
emit("street_plants", "StreetPlantsStyle", "street_plants_style", [
    ("town_avenue", "Town avenue", "Plane, cypress, olive and jacaranda trees; boxwood, lavender, roses and planters.",
     {"name_fa": "خیابان‌های سبز", "species": SPECIES}),
    ("sparse_greens", "Sparse greens", "Fewer plants, mostly bushes and planters.",
     {"name_fa": "سبزه‌ی کم", "species": SPECIES, "tree_spacing": 16.0}),
], "town_avenue")

# ====================================================================== 6. fire truck
style_script("fire_truck", "fire_truck_style", "FireTruckStyle",
    "v7b.1 real red fire truck (cab, ladder, hose reels, light bar, 'آتش‌نشانی\n"
    "۱۲۵') plus a positional siren that sounds around town while responding.\n"
    "Consumer: FireSiren (FireService).", [
    ("enabled", "bool", "true", ""),
    ("siren_enabled", "bool", "true", ""),
    ("siren_kind", "String", '"wail"', "wail / hi_lo"),
    ("siren_period", "float", "2.4", "s per loop"),
    ("unit_size", "float", "14.0", "AudioStreamPlayer3D unit_size"),
    ("max_distance", "float", "170.0", "m"),
    ("volume_db", "float", "-2.0", ""),
    ("light_colors", "Array", "[]", ""),
])
emit("fire_truck", "FireTruckStyle", "fire_truck_style", [
    ("town_fire_truck", "Town fire truck", "Red fire truck with ladder, hose reels and a positional siren.",
     {"name_fa": "ماشین آتش‌نشانی شهر", "light_colors": [C(1.0, 0.08, 0.05), C(1.0, 0.95, 0.9)]}),
    ("quiet_brigade", "Quiet brigade", "Same truck, siren off (lights still flash).",
     {"name_fa": "آتش‌نشانی بی‌صدا", "siren_enabled": False,
      "light_colors": [C(1.0, 0.08, 0.05), C(1.0, 0.95, 0.9)]}),
], "town_fire_truck")

# ====================================================================== 7. city hall interior
style_script("city_hall_interior", "city_hall_interior_style", "CityHallInteriorStyle",
    "v7b.1: City Hall is enterable. The outdoor fund board and the market price\n"
    "strip are gone; F4 / the fund panel only open inside. Inside: a counter,\n"
    "the manager's desk, clerks at their posts and a wall board with the fund\n"
    "balance, ledger and public works. Separable so streaming/LOD can load it\n"
    "on enter. Consumer: CityHallInterior.", [
    ("enabled", "bool", "true", ""),
    ("hide_outdoor_board", "bool", "true", ""),
    ("hide_price_strip", "bool", "true", ""),
    ("f4_only_inside", "bool", "true", ""),
    ("staff", "Array", "[]", "preferred full names for manager / clerks"),
    ("wall_board", "bool", "true", ""),
])
emit("city_hall_interior", "CityHallInteriorStyle", "city_hall_interior_style", [
    ("municipal_office", "Municipal office", "Desk, counter, manager + clerks; fund board on the wall; F4 only inside.",
     {"name_fa": "اداره‌ی شهرداری", "staff": ["Omid Hosseini", "Reza Karimi", "Ramin Soleimani"]}),
    ("simple_office", "Simple office", "Smaller interior, no wall board (talk to the manager).",
     {"name_fa": "اداره‌ی ساده", "wall_board": False, "staff": ["Omid Hosseini"]}),
], "municipal_office")

# ====================================================================== 8. families
style_script("families", "families_style", "FamiliesStyle",
    "v7b.1 richer households: some with 4 kids, some with none, newlyweds, young\n"
    "couples, elderly couples and a few singles. Every adult has a city job\n"
    "(kids at school, elderly retired or light work). Shown on the name card\n"
    "and the J directory. Deterministic, saved with the game. Consumer:\n"
    "Families (patches Population.residents).", [
    ("enabled", "bool", "true", ""),
    ("households", "Array", "[]", "[{id, home, kind, members:[{name,surname,age,gender,job,work,role,...}]}]"),
    ("directory_kinds", "bool", "true", "show 'newlyweds' / '4 children' in the J directory"),
])
# Households are applied by patching population/families.tres below (so
# Townspeople, backstories and schedules keep working). The module mainly
# carries the typology metadata for the directory + tests.
HOUSE_META = [
    {"id": "Karimi", "home": "maple2", "kind": "large_family", "kind_fa": "خانواده‌ی پرجمعیت (۴ فرزند)", "kind_en": "large family (4 children)"},
    {"id": "Rahimi", "home": "maple4", "kind": "family", "kind_fa": "خانواده", "kind_en": "family"},
    {"id": "Ahmadi", "home": "maple3", "kind": "newlyweds", "kind_fa": "تازه‌عروس و داماد (با مادر)", "kind_en": "newlyweds (with her mother)"},
    {"id": "Hosseini", "home": "maple5", "kind": "large_family", "kind_fa": "خانواده‌ی پرجمعیت (۴ فرزند)", "kind_en": "large family (4 children)"},
    {"id": "Moradi", "home": "oak12", "kind": "young_couple", "kind_fa": "زوج جوان", "kind_en": "young couple"},
    {"id": "Tehrani", "home": "oak15", "kind": "grown_kids", "kind_fa": "زوج میانسال (فرزندان بزرگ شده‌اند)", "kind_en": "couple, children grown up"},
    {"id": "Jafari", "home": "pine9", "kind": "grown_kids", "kind_fa": "زوج میانسال (فرزندان بزرگ شده‌اند)", "kind_en": "couple, children grown up"},
    {"id": "Sadeghi", "home": "harbor2", "kind": "young_couple", "kind_fa": "زوج جوان", "kind_en": "young couple"},
    {"id": "Rostami", "home": "maple7", "kind": "large_family", "kind_fa": "خانواده‌ی پرجمعیت (۴ فرزند)", "kind_en": "large family (4 children)"},
    {"id": "Nouri", "home": "maple1", "kind": "couple_no_kids", "kind_fa": "زوج بدون فرزند", "kind_en": "couple without children"},
    {"id": "Bell", "home": "oak10", "kind": "older_couple", "kind_fa": "زوج مسن", "kind_en": "older couple"},
    {"id": "Haddad", "home": "pine14", "kind": "older_couple", "kind_fa": "زوج مسن", "kind_en": "older couple"},
    {"id": "Bakhtiari", "home": "pine11", "kind": "large_family", "kind_fa": "خانواده‌ی پرجمعیت (۴ فرزند)", "kind_en": "large family (4 children)"},
    {"id": "Kia", "home": "oak16", "kind": "elderly_couple", "kind_fa": "زوج سالمند", "kind_en": "elderly couple"},
    {"id": "Houshyar", "home": "harbor4", "kind": "young_family", "kind_fa": "خانواده‌ی جوان", "kind_en": "young family"},
    {"id": "Soleimani", "home": "pine18", "kind": "single", "kind_fa": "مجرد", "kind_en": "single"},
]
emit("families", "FamiliesStyle", "families_style", [
    ("town_families", "Town families", "Mixed households: large families, newlyweds, elderly, singles.",
     {"name_fa": "خانواده‌های شهر", "households": HOUSE_META}),
    ("small_households", "Small households", "Mostly couples and singles (no 4-kid homes).",
     {"name_fa": "خانوارهای کوچک", "households": [h for h in HOUSE_META if h["kind"] not in ("large_family",)]}),
], "town_families")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 visual modules written")


# ====================================================================== population patch
DARK = (0.1, 0.07, 0.05); BROWN = (0.35, 0.2, 0.1); AUBURN = (0.5, 0.25, 0.1); GREY = (0.55, 0.55, 0.55); BLOND = (0.75, 0.6, 0.35)

def R(name, surname, age, gender, job, work, home, role, hair, hair_color, shirt, pants, skin=0, beard=False, top="work_shirt", lines=None):
    return {"name": name, "surname": surname, "age": age, "gender": gender, "job": job, "work": work, "home": home,
            "family": surname, "role": role, "hair": hair, "hair_color": hair_color, "shirt": shirt, "pants": pants,
            "skin": skin, "beard": beard, "top": top, "lines": lines or []}

RES = [
    # maple2 - Karimi: large family (4 kids). Reza was the postman -> city mail clerk.
    R("Mina", "Karimi", 34, "female", "Barista", "cafe", "maple2", "mother", "Hair_Long", DARK, (0.78, 0.3, 0.32), (0.2, 0.2, 0.26), 0, top="tshirt",
      lines=["The coffee is fresh today.", "Four children keep us busy!", "I love this town square."]),
    R("Reza", "Karimi", 37, "male", "City mail clerk", "city_hall", "maple2", "father", "Hair_Buzzed", DARK, (0.25, 0.32, 0.5), (0.15, 0.15, 0.17), 1, True, "jacket",
      lines=["Letters now go through City Hall.", "Mina makes the best coffee in town.", "Four kids - never a dull day!"]),
    R("Ali", "Karimi", 9, "male", "Pupil", "school", "maple2", "son", "Hair_SimpleParted", DARK, (0.95, 0.6, 0.2), (0.25, 0.3, 0.5), 1, top="tshirt",
      lines=["We learned about bees today!", "Can I pet your sheep?", "School's out soon!"]),
    R("Setareh", "Karimi", 7, "female", "Pupil", "school", "maple2", "daughter", "Hair_Buns", DARK, (0.9, 0.45, 0.55), (0.3, 0.25, 0.4), 0, top="tshirt",
      lines=["I drew a horse!", "Ali is too fast on his bike.", "Mum's coffee smells nice."]),
    R("Nima", "Karimi", 5, "male", "Pupil", "school", "maple2", "son", "Hair_Buzzed", DARK, (0.3, 0.55, 0.7), (0.2, 0.25, 0.35), 1, top="tshirt",
      lines=["I can count to twenty!", "Where is the ice cream?", "I want a red balloon."]),
    R("Donya", "Karimi", 4, "female", "Kindergarten", "school", "maple2", "daughter", "Hair_Buns", DARK, (0.95, 0.7, 0.5), (0.5, 0.35, 0.45), 0, top="tshirt",
      lines=["Mama!", "Ba!", "Sheep!"]),
    # maple4 - Rahimi
    R("Dariush", "Rahimi", 45, "male", "Police officer", "police", "maple4", "father", "Hair_SimpleParted", GREY, (0.15, 0.2, 0.35), (0.12, 0.14, 0.2), 0, top="jacket",
      lines=["All quiet in town.", "Walk safe!", "Keep an eye on your sheep!"]),
    R("Leila", "Rahimi", 42, "female", "Doctor", "hospital", "maple4", "mother", "Hair_SimpleParted", DARK, (0.92, 0.92, 0.95), (0.5, 0.65, 0.75), 1, top="jacket",
      lines=["Remember to rest when you're tired.", "Drink water, farmer!", "Sima studies medicine, like me."]),
    R("Sima", "Rahimi", 19, "female", "Student", "university", "maple4", "daughter", "Hair_Buns", DARK, (0.4, 0.6, 0.8), (0.25, 0.25, 0.3), 1, top="tshirt",
      lines=["Exams next week...", "The university library is huge.", "Dad worries too much."]),
    # maple3 - Ahmadi: newlyweds Sara + Hamid; Parvin (elderly mother) lives with them.
    R("Sara", "Ahmadi", 29, "female", "Shopkeeper", "store", "maple3", "wife", "Hair_Buns", AUBURN, (0.35, 0.55, 0.4), (0.3, 0.25, 0.2), 0,
      lines=["We restock seeds every morning.", "Hamid and I just got married.", "Mum loves the mosque garden."]),
    R("Hamid", "Ahmadi", 31, "male", "Tool repairer", "tool_shop", "maple3", "husband", "Hair_Buzzed", BROWN, (0.3, 0.35, 0.4), (0.15, 0.15, 0.18), 1, True, "jacket",
      lines=["Bring me your broken tools.", "Sara runs a fine shop.", "Anna keeps me busy at the tool shop."]),
    R("Parvin", "Ahmadi", 66, "female", "Retired teacher", "", "maple3", "mother", "Hair_Buns", GREY, (0.5, 0.35, 0.5), (0.3, 0.3, 0.32), 0, top="jacket",
      lines=["I taught half this town to read.", "The fountain is lovely in the evening.", "Have you met my Sara?"]),
    # maple5 - Hosseini: large family (4 kids)
    R("Omid", "Hosseini", 40, "male", "City Hall manager", "city_hall", "maple5", "father", "Hair_SimpleParted", BROWN, (0.4, 0.45, 0.55), (0.2, 0.22, 0.28), 0, top="jacket",
      lines=["The city fund is growing.", "Four children keep us busy!", "Come by City Hall anytime."]),
    R("Nasrin", "Hosseini", 38, "female", "Supermarket cashier", "supermarket", "maple5", "mother", "Hair_Long", DARK, (0.7, 0.35, 0.4), (0.2, 0.2, 0.25), 0,
      lines=["Specials on tomatoes today.", "Arman helps with the little ones.", "Come by for groceries!"]),
    R("Arman", "Hosseini", 12, "male", "Pupil", "school", "maple5", "son", "Hair_SimpleParted", BROWN, (0.25, 0.45, 0.65), (0.2, 0.25, 0.35), 0, top="tshirt",
      lines=["Football after school!", "I look after my little sisters.", "Dad works at City Hall."]),
    R("Niloofar", "Hosseini", 10, "female", "Pupil", "school", "maple5", "daughter", "Hair_Long", DARK, (0.85, 0.5, 0.6), (0.3, 0.25, 0.4), 0, top="tshirt",
      lines=["I love reading.", "Niloofar means lotus.", "Mum works at the supermarket."]),
    R("Kasra", "Hosseini", 6, "male", "Pupil", "school", "maple5", "son", "Hair_Buzzed", BROWN, (0.4, 0.6, 0.35), (0.25, 0.3, 0.4), 0, top="tshirt",
      lines=["I can ride a bike!", "Where is the park?", "Yas took my toy."]),
    R("Yas", "Hosseini", 4, "female", "Kindergarten", "school", "maple5", "daughter", "Hair_Buns", DARK, (0.95, 0.75, 0.55), (0.55, 0.4, 0.5), 0, top="tshirt",
      lines=["Baba!", "Park!", "Flower!"]),
    # oak12 - Moradi: young couple, no kids
    R("Kian", "Moradi", 31, "male", "Fisherman", "pier", "oak12", "husband", "Hair_Buzzed", DARK, (0.2, 0.4, 0.55), (0.15, 0.2, 0.3), 1, True, "tshirt",
      lines=["The catch was good today.", "Shirin and I just moved here.", "Come fishing sometime!"]),
    R("Shirin", "Moradi", 30, "female", "Fruit seller", "fruit_shop", "oak12", "wife", "Hair_Long", AUBURN, (0.9, 0.55, 0.35), (0.3, 0.25, 0.2), 0,
      lines=["Fresh peaches!", "Kian brings the morning catch.", "We're saving for a baby."]),
    # oak15 - Tehrani: elderly couple
    R("Bahram", "Tehrani", 52, "male", "Carpenter", "carpenter", "oak15", "husband", "Hair_Buzzed", GREY, (0.55, 0.4, 0.25), (0.3, 0.25, 0.2), 0, True, "jacket",
      lines=["Wood tells you how to cut it.", "Our son studies in Tehran now.", "Come by the workshop."]),
    R("Golnar", "Tehrani", 49, "female", "Teacher", "school", "oak15", "wife", "Hair_Buns", GREY, (0.45, 0.35, 0.55), (0.3, 0.3, 0.35), 0, top="jacket",
      lines=["The children are learning so fast.", "Bahram still smells of sawdust.", "Tea after class?"]),
    # pine9 - Jafari: elderly couple
    R("Hassan", "Jafari", 58, "male", "Blacksmith", "blacksmith", "pine9", "husband", "Hair_Buzzed", GREY, (0.35, 0.3, 0.3), (0.2, 0.2, 0.22), 1, True, "jacket",
      lines=["The forge is hot today.", "Maryam sews by the window.", "A good hammer lasts a lifetime."]),
    R("Maryam", "Jafari", 54, "female", "Tailor", "clothing", "pine9", "wife", "Hair_Buns", GREY, (0.55, 0.4, 0.5), (0.3, 0.28, 0.32), 0, top="jacket",
      lines=["I can mend that for you.", "Hassan still swings a hammer.", "New fabric arrived!"]),
    # harbor2 - Sadeghi: young family (1 baby)
    R("Navid", "Sadeghi", 35, "male", "Electrician", "electrical", "harbor2", "father", "Hair_SimpleParted", BROWN, (0.85, 0.75, 0.3), (0.2, 0.2, 0.25), 0, top="jacket",
      lines=["Power's steady today.", "Elena and I want kids one day.", "Call me if the lights flicker."]),
    R("Elena", "Sadeghi", 33, "female", "Nurse", "hospital", "harbor2", "mother", "Hair_Long", BLOND, (0.9, 0.9, 0.95), (0.4, 0.5, 0.65), 0,
      lines=["Health first!", "We just painted the house.", "Leila is a wonderful doctor."]),
    # maple7 - Rostami: large family (4 kids)
    R("Farhad", "Rostami", 44, "male", "Stonemason", "mason", "maple7", "father", "Hair_Buzzed", DARK, (0.55, 0.5, 0.45), (0.25, 0.25, 0.28), 1, True, "jacket",
      lines=["Stone lasts forever.", "Four children - chaos and joy.", "Need a wall rebuilt?"]),
    R("Laleh", "Rostami", 41, "female", "Jeweller", "jewelry", "maple7", "mother", "Hair_Long", DARK, (0.35, 0.25, 0.4), (0.2, 0.15, 0.25), 0, top="jacket",
      lines=["A new ring design today.", "Dara helps with the little ones.", "Come see the shop."]),
    R("Dara", "Rostami", 7, "male", "Pupil", "school", "maple7", "son", "Hair_SimpleParted", DARK, (0.3, 0.5, 0.55), (0.2, 0.25, 0.35), 0, top="tshirt",
      lines=["I found a shiny stone!", "My sisters fight over dolls.", "Dad cuts stone."]),
    R("Roya", "Rostami", 9, "female", "Pupil", "school", "maple7", "daughter", "Hair_Long", DARK, (0.85, 0.4, 0.5), (0.3, 0.25, 0.4), 0, top="tshirt",
      lines=["I like drawing flowers.", "School was fun!", "Mum makes sparkly things."]),
    R("Pouya", "Rostami", 5, "male", "Pupil", "school", "maple7", "son", "Hair_Buzzed", DARK, (0.4, 0.6, 0.4), (0.25, 0.3, 0.35), 0, top="tshirt",
      lines=["Zoom zoom!", "Can we go to the park?", "Dara is the boss."]),
    R("Hana", "Rostami", 4, "female", "Kindergarten", "school", "maple7", "daughter", "Hair_Buns", DARK, (0.95, 0.7, 0.6), (0.55, 0.4, 0.5), 0, top="tshirt",
      lines=["Mama!", "Ball!", "No!"]),
    # maple1 - Nouri: couple, no kids
    R("Babak", "Nouri", 39, "male", "Water engineer", "water_office", "maple1", "husband", "Hair_SimpleParted", BROWN, (0.4, 0.6, 0.75), (0.2, 0.25, 0.35), 0, top="jacket",
      lines=["The water tower is full.", "Ziba and I like the quiet.", "Report a leak anytime."]),
    R("Ziba", "Nouri", 36, "female", "Electricity officer", "power_office", "maple1", "wife", "Hair_Buns", DARK, (0.9, 0.75, 0.3), (0.25, 0.25, 0.3), 0, top="jacket",
      lines=["Keep the lights on!", "We're saving for a trip.", "Babak checks the pipes."]),
    # oak10 - Bell: elderly couple
    R("Thomas", "Bell", 61, "male", "Priest", "church", "oak10", "husband", "Hair_Buzzed", GREY, (0.85, 0.85, 0.9), (0.2, 0.2, 0.25), 0, True, "jacket",
      lines=["Peace be with you.", "Anna sings in the choir.", "The bell tower needs oil."]),
    R("Anna", "Bell", 57, "female", "Tool seller", "tool_shop", "oak10", "wife", "Hair_Buns", GREY, (0.55, 0.45, 0.35), (0.3, 0.28, 0.3), 0, top="jacket",
      lines=["A good hoe lasts years.", "Thomas still writes sermons.", "Come by for seeds too."]),
    # pine14 - Haddad: elderly couple
    R("Yusuf", "Haddad", 59, "male", "Imam", "mosque", "pine14", "husband", "Hair_Buzzed", GREY, (0.3, 0.35, 0.3), (0.2, 0.2, 0.22), 1, True, "jacket",
      lines=["Welcome to the mosque.", "Amina teaches at the university.", "Friday prayer is at noon."]),
    R("Amina", "Haddad", 52, "female", "Professor", "university", "pine14", "wife", "Hair_Buns", GREY, (0.45, 0.4, 0.55), (0.25, 0.25, 0.3), 0, top="jacket",
      lines=["Knowledge is light.", "Yusuf keeps the community together.", "My students ask about the farm."]),
    # maple8 - Bakhtiari: large family (4 kids) - NEW home
    R("Kamran", "Bakhtiari", 42, "male", "Hypermarket manager", "hypermarket", "pine11", "father", "Hair_SimpleParted", DARK, (0.2, 0.35, 0.55), (0.15, 0.15, 0.2), 1, True, "jacket",
      lines=["Everything under one roof.", "Four kids and a busy shop.", "Come by the hypermarket."]),
    R("Nasim", "Bakhtiari", 39, "female", "Gym coach", "gym", "pine11", "mother", "Hair_Long", DARK, (0.3, 0.55, 0.5), (0.2, 0.2, 0.25), 0, top="tshirt",
      lines=["Stretch before you lift!", "The children keep me fit.", "Kamran brings home the groceries."]),
    R("Arash", "Bakhtiari", 13, "male", "Pupil", "school", "pine11", "son", "Hair_SimpleParted", DARK, (0.35, 0.5, 0.7), (0.2, 0.25, 0.35), 0, top="tshirt",
      lines=["I run track at school.", "My sisters are loud.", "Dad works at the hypermarket."]),
    R("Baran", "Bakhtiari", 10, "female", "Pupil", "school", "pine11", "daughter", "Hair_Long", DARK, (0.8, 0.4, 0.55), (0.3, 0.25, 0.4), 0, top="tshirt",
      lines=["Baran means rain.", "I like the gym's mirror wall.", "Mum is the coach."]),
    R("Kourosh", "Bakhtiari", 7, "male", "Pupil", "school", "pine11", "son", "Hair_Buzzed", DARK, (0.4, 0.65, 0.4), (0.25, 0.3, 0.35), 0, top="tshirt",
      lines=["I can jump high!", "My name means sun!", "Football!"]),
    R("Yasmin", "Bakhtiari", 4, "female", "Kindergarten", "school", "pine11", "daughter", "Hair_Buns", DARK, (0.95, 0.7, 0.55), (0.55, 0.4, 0.5), 0, top="tshirt",
      lines=["Mama!", "Jump!", "Flower!"]),
    # oak16 - Kia: elderly couple - NEW home
    R("Hooshang", "Kia", 70, "male", "Retired farmer", "", "oak16", "husband", "Hair_Buzzed", GREY, (0.5, 0.45, 0.35), (0.3, 0.28, 0.25), 1, True, "jacket",
      lines=["I worked this land for forty years.", "Mahin makes the best jam.", "Sit, have some tea."]),
    R("Mahin", "Kia", 67, "female", "Part-time librarian", "school", "oak16", "wife", "Hair_Buns", GREY, (0.55, 0.4, 0.45), (0.3, 0.3, 0.32), 0, top="jacket",
      lines=["Books keep the mind young.", "Hooshang still wakes at dawn.", "Borrow a story anytime."]),
    # harbor4 - Houshyar: young family - uses the built town lot
    R("Pouria", "Houshyar", 32, "male", "Boat captain", "pier", "harbor4", "father", "Hair_Buzzed", BROWN, (0.2, 0.4, 0.55), (0.15, 0.2, 0.3), 1, True, "tshirt",
      lines=["The sea was calm today.", "Little Ava loves the boats.", "Need a ride to deep water?"]),
    R("Elham", "Houshyar", 30, "female", "Cafe cook", "cafe", "harbor4", "mother", "Hair_Long", BROWN, (0.85, 0.45, 0.35), (0.25, 0.25, 0.3), 0,
      lines=["Soup of the day is ready.", "Ava helped stir!", "Pouria brings fresh fish."]),
    R("Ava", "Houshyar", 5, "female", "Pupil", "school", "harbor4", "daughter", "Hair_Buns", BROWN, (0.9, 0.55, 0.45), (0.35, 0.3, 0.4), 0, top="tshirt",
      lines=["I saw a dolphin!", "School is fun.", "Mum's soup is yummy."]),
    # pine18 - Soleimani: single - NEW home
    R("Ramin", "Soleimani", 28, "male", "City Hall press officer", "city_hall", "pine18", "single", "Hair_SimpleParted", DARK, (0.25, 0.25, 0.3), (0.15, 0.15, 0.18), 0, top="jacket",
      lines=["Have you read today's paper?", "I live alone - quiet suits me.", "I write the City Hall notices."]),
]

# Patch families.tres + small_town.tres
def write_population(path, residents, max_spawned, display, desc):
    lines = ['[gd_resource type="Resource" script_class="PopulationDef" format=3]', "",
             '[ext_resource type="Script" path="res://modules/population/population_def.gd" id="1"]', "",
             "[resource]", 'script = ExtResource("1")',
             'id = "%s"' % os.path.basename(path).replace(".tres", ""),
             'type = "population"',
             'display_name = "%s"' % display,
             'description = "%s"' % desc,
             "residents = %s" % val(residents),
             "max_spawned = %d" % max_spawned,
             "child_scale = 0.72",
             "teen_scale = 0.9", ""]
    open(os.path.join(ROOT, path), "w", encoding="utf-8").write("\n".join(lines))

write_population("modules/population/families.tres", RES, 60,
                 "Families of the town",
                 "v7b.1: mixed households (large families, newlyweds, elderly, singles). Reza moved from the post office to City Hall; new Bakhtiari, Kia, Houshyar and Soleimani homes.")
write_population("modules/population/small_town.tres", RES[:14], 14,
                 "Small town", "Half the families (smoke / low-end).")
print("population: %d residents" % len(RES))


# ====================================================================== town_layout: remove post, add homes
lay = open(os.path.join(ROOT, "scripts/world/town/town_layout.gd"), encoding="utf-8").read()
# Drop the post office building (idempotent).
lay2 = re.sub(
    r'\t\{"id": "post", "kind": "post", "sign": "Post Office", "address": "3 Town Sq", "pos": Vector2\(-14\.5, -64\.5\), "yaw": 45\.0,\n'
    r'\t\t"size": Vector3\(7\.5, 3\.0, 6\.5\), "roof": 1\.9, "wall": Color\(0\.72, 0\.8, 0\.86\), "roof_color": Color\(0\.35, 0\.22, 0\.15\), "interior": "post"\},\n',
    "", lay, count=1)
assert '"id": "post"' not in lay2
lay2 = re.sub(r'\t# v7b1 homes begin\n.*?\t# v7b1 homes end\n', '', lay2, flags=re.S)
lay2 = re.sub(r'\t\{"id": "(maple8|oak16|harbor4|pine18|pine11)".*?\},\n(?=\t[\{#]|\]|## )', '', lay2, flags=re.S)
new_homes = '''\t# v7b1 homes begin (families module: new households)
\t{"id": "pine11", "kind": "home", "sign": "", "address": "11 Pine Ln", "pos": Vector2(-35.0, -71.0), "yaw": -90.0,
\t\t"size": Vector3(7.5, 3.2, 6.0), "roof": 2.0, "wall": Color(0.9, 0.82, 0.7), "roof_color": Color(0.4, 0.22, 0.16), "interior": "home_a", "owner": "Bakhtiari"},
\t{"id": "oak16", "kind": "home", "sign": "", "address": "16 Oak Ave", "pos": Vector2(11.0, -128.0), "yaw": -90.0,
\t\t"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.82, 0.78, 0.7), "roof_color": Color(0.32, 0.34, 0.4), "interior": "home_c", "owner": "Kia", "timber": true},
\t{"id": "harbor4", "kind": "home", "sign": "", "address": "4 Harbor Rd", "pos": Vector2(65.0, -21.0), "yaw": -90.0,
\t\t"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.92, 0.84, 0.66), "roof_color": Color(0.4, 0.25, 0.2), "interior": "home_b", "owner": "Houshyar"},
\t{"id": "pine18", "kind": "home", "sign": "", "address": "18 Pine Ln", "pos": Vector2(-54.5, -118.0), "yaw": 90.0,
\t\t"size": Vector3(6.5, 2.9, 5.5), "roof": 1.7, "wall": Color(0.78, 0.8, 0.84), "roof_color": Color(0.28, 0.3, 0.36), "interior": "home_d", "owner": "Soleimani"},
\t# v7b1 homes end
'''
marker = "]\n\n## Street-name signposts at intersections"
assert marker in lay2, "buildings end marker"
lay2 = lay2.replace(marker, new_homes + marker, 1)
open(os.path.join(ROOT, "scripts/world/town/town_layout.gd"), "w", encoding="utf-8").write(lay2)
print("town_layout: post removed, 4 homes added")

# Drop the built harbor lot (now a real home) and the pine construction that
# sits on pine18; keep the for-sale Main St lot.
for fn in ("modules/town_lots/three_lots.tres", "modules/town_lots/for_sale_only.tres"):
    p = os.path.join(ROOT, fn)
    if not os.path.exists(p):
        continue
    s = open(p, encoding="utf-8").read()
    s = re.sub(r'\{"id": "lot_harbor4"[^}]*\},?\s*', "", s)
    s = re.sub(r'\{"id": "lot_pine20"[^}]*\},?\s*', "", s)
    s = s.replace("lots = [, ", "lots = [").replace(", ]", "]").replace("[, {", "[{")
    open(p, "w", encoding="utf-8").write(s)
print("town_lots: harbor4 + pine20 cleared (now real homes)")


# ====================================================================== dialogue / ui_text / backstories patches
def patch_dict_line(path, key, updates):
    src = open(path, encoding="utf-8").read()
    m = re.search(r"^%s = (\{.*\})$" % key, src, re.M)
    assert m, key
    cur = json.loads(m.group(1).replace("Color(", "[").replace(")", "]") if False else m.group(1))
    # Godot Color(...) is not JSON - only patch plain string dicts here.
    cur = json.loads(re.sub(r'Color\([^)]*\)', 'null', m.group(1)) if "Color(" in m.group(1) else m.group(1))
    cur.update(updates)
    line = "%s = %s" % (key, json.dumps(cur, ensure_ascii=False, separators=(", ", ": ")))
    open(path, "w", encoding="utf-8").write(src[:m.start()] + line + src[m.end():])


JOBS_FA = {
    "City mail clerk": "کارمند پست شهرداری", "Mechanic": "مکانیک", "Kindergarten": "مهدکودک", "City Hall manager": "مدیر شهرداری", "Tool repairer": "تعمیرکار ابزار", "City Hall press officer": "روابط عمومی شهرداری",
    "Hypermarket manager": "مدیر هایپرمارکت", "Gym coach": "مربی باشگاه", "Retired farmer": "کشاورز بازنشسته",
    "Part-time librarian": "کتابدار پاره‌وقت", "Boat captain": "ناخدا", "Cafe cook": "آشپز کافه",
    "Journalist": "خبرنگار",
}
PLACES_FA = {"newspaper": "دکه روزنامه", "mechanic": "تعمیرگاه", "gym": "باشگاه", "hypermarket": "هایپرمارکت"}
NAMES_FA = {
    "Setareh": "ستاره", "Nima": "نیما", "Donya": "دنیا", "Hamid": "حمید", "Niloofar": "نیلوفر", "Kasra": "کسری",
    "Yas": "یاس", "Roya": "رویا", "Pouya": "پویا", "Hana": "هانا", "Raha": "رها", "Kamran": "کامران",
    "Nasim": "نسیم", "Arash": "آرش", "Baran": "باران", "Yasmin": "یاسمین", "Hooshang": "هوشنگ", "Mahin": "مهین",
    "Pouria": "پوریا", "Setareh": "ستاره", "Kourosh": "کوروش", "Elham": "الهام", "Ava": "آوا", "Ramin": "رامین",
    "Bakhtiari": "بختیاری", "Kia": "کیا", "Houshyar": "هوشیار", "Soleimani": "سلیمانی",
}
for fn in ("modules/dialogue/warm_village.tres", "modules/dialogue/brief.tres"):
    p = os.path.join(ROOT, fn)
    src = open(p, encoding="utf-8").read()
    for key, updates in (("jobs_fa", JOBS_FA), ("places_fa", PLACES_FA), ("names_fa", NAMES_FA)):
        m = re.search(r"^%s = (\{.*\})$" % key, src, re.M)
        cur = json.loads(m.group(1))
        cur.update(updates)
        if key == "places_fa" and "post" in cur:
            del cur["post"]
        line = "%s = %s" % (key, json.dumps(cur, ensure_ascii=False, separators=(", ", ": ")))
        src = src[:m.start()] + line + src[m.end():]
    # Reza's mail work now happens at City Hall: same work lines for the new job.
    m = re.search(r"^job_lines = (\{.*\})$", src, re.M)
    if m:
        jl = json.loads(m.group(1))
        if "postman" in jl:
            jl["city mail clerk"] = jl["postman"]
        line = "job_lines = %s" % json.dumps(jl, ensure_ascii=False, separators=(", ", ": "))
        src = src[:m.start()] + line + src[m.end():]
    open(p, "w", encoding="utf-8").write(src)
print("dialogue: jobs/places/names updated, post place removed")

# Wages for the new jobs (lower-case job names, like the existing table).
NEW_WAGES = {"city mail clerk": 60, "city hall manager": 90, "city hall press officer": 70, "tool repairer": 65,
             "hypermarket manager": 85, "gym coach": 60, "boat captain": 75, "cafe cook": 55, "part-time librarian": 35}
for fn in ("modules/wages/fair_wages.tres", "modules/wages/modest_wages.tres"):
    p = os.path.join(ROOT, fn)
    src = open(p, encoding="utf-8").read()
    m = re.search(r"^wages = (\{.*\})$", src, re.M)
    cur = json.loads(m.group(1))
    scale = 1.0 if "fair" in fn else 0.8
    for k, v in NEW_WAGES.items():
        cur.setdefault(k, int(round(v * scale)))
    line = "wages = %s" % json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
    src = src[:m.start()] + line + src[m.end():]
    open(p, "w", encoding="utf-8").write(src)
print("wages: new jobs added")

# Backstories for new people + Reza's new job problem.
NEW_STORIES = {
    "Reza Karimi": {"talents_en": "knows every street by heart, fixes bicycles", "talents_fa": "همه‌ی کوچه‌ها را از بر است، دوچرخه تعمیر می‌کند",
                    "problem_en": "his knee still hurts from the old delivery rounds", "problem_fa": "از مسیرهای قدیمی پست، زانویش هنوز درد می‌کند",
                    "past_en": "he grew up without a father and worked since he was fourteen", "past_fa": "بی‌پدر بزرگ شد و از چهارده‌سالگی کار کرد",
                    "hope_en": "that all four children finish school with good marks", "hope_fa": "هر چهار فرزند مدرسه را با نمره‌ی خوب تمام کنند"},
    "Setareh Karimi": {"talents_en": "draws horses, kind to her little sister", "talents_fa": "اسب نقاشی می‌کند، با خواهر کوچکش مهربان است",
                    "problem_en": "sharing toys with Nima", "problem_fa": "تقسیم اسباب‌بازی با نیما",
                    "past_en": "she once rode Ali's bike and fell", "past_fa": "یک بار دوچرخه‌ی علی را راند و افتاد",
                    "hope_en": "a pony", "hope_fa": "یک اسب کوچک"},
    "Nima Karimi": {"talents_en": "counting, climbing", "talents_fa": "شمارش، بالا رفتن", "problem_en": "bedtime", "problem_fa": "وقت خواب",
                    "past_en": "he painted the wall with jam", "past_fa": "دیوار را با مربا رنگ کرد", "hope_en": "a red balloon every day", "hope_fa": "هر روز یک بادکنک قرمز"},
    "Donya Karimi": {"talents_en": "smiling", "talents_fa": "لبخند", "problem_en": "words are hard", "problem_fa": "حرف زدن سخت است",
                     "past_en": "she took her first steps in the square", "past_fa": "اولین قدم‌هایش را در میدان برداشت", "hope_en": "more hugs", "hope_fa": "بغل بیشتر"},
    "Hamid Ahmadi": {"talents_en": "engines, fair prices", "talents_fa": "موتور، قیمت منصفانه", "problem_en": "greasy hands at dinner", "problem_fa": "دست‌های چرب سر شام",
                     "past_en": "he apprenticed under an uncle in the city", "past_fa": "نزد عمویش در شهر شاگردی کرد", "hope_en": "a family of his own with Sara", "hope_fa": "با سارا خانواده‌ی خودش"},
    "Niloofar Hosseini": {"talents_en": "reading, caring for siblings", "talents_fa": "خواندن، مراقبت از خواهر و برادر", "problem_en": "maths", "problem_fa": "ریاضی",
                          "past_en": "she planted a lotus in the garden", "past_fa": "در باغچه نیلوفر کاشت", "hope_en": "to be a doctor like Leila", "hope_fa": "مثل لیلا دکتر شود"},
    "Kasra Hosseini": {"talents_en": "football, laughing loud", "talents_fa": "فوتبال، بلند خندیدن", "problem_en": "sitting still", "problem_fa": "آرام نشستن",
                       "past_en": "he scored in the school yard", "past_fa": "در حیاط مدرسه گل زد", "hope_en": "a real football", "hope_fa": "یک توپ فوتبال واقعی"},
    "Yas Hosseini": {"talents_en": "picking flowers", "talents_fa": "چیدن گل", "problem_en": "naps", "problem_fa": "چرت زدن",
                     "past_en": "she was named after jasmine", "past_fa": "اسمش از یاس گرفته شده", "hope_en": "more park time", "hope_fa": "پارک بیشتر"},
    "Roya Rostami": {"talents_en": "drawing flowers", "talents_fa": "نقاشی گل", "problem_en": "sharing crayons", "problem_fa": "تقسیم مدادر رنگی",
                     "past_en": "mum let her polish a ring", "past_fa": "مادر گذاشت یک انگشتر را برق بیندازد", "hope_en": "her own jewellery box", "hope_fa": "جعبه جواهر خودش"},
    "Pouya Rostami": {"talents_en": "running, making engine noises", "talents_fa": "دویدن، صدای موتور درآوردن", "problem_en": "listening", "problem_fa": "گوش کردن",
                      "past_en": "he raced Dara down Maple St", "past_fa": "با دارا در خیابان افرا مسابقه داد", "hope_en": "a toy car", "hope_fa": "یک ماشین اسباب‌بازی"},
    "Hana Rostami": {"talents_en": "clapping", "talents_fa": "دست زدن", "problem_en": "everything", "problem_fa": "همه چیز",
                     "past_en": "she said 'mama' first", "past_fa": "اول 'ماما' گفت", "hope_en": "the red ball", "hope_fa": "توپ قرمز"},
    "Kamran Bakhtiari": {"talents_en": "organising shelves, remembering stock", "talents_fa": "چیدن قفسه، یاد موجودی", "problem_en": "long hours", "problem_fa": "ساعت‌های طولانی",
                         "past_en": "he started as a stock boy", "past_fa": "از انبارداری شروع کرد", "hope_en": "the hypermarket stays the town's pride", "hope_fa": "هایپرمارکت افتخار شهر بماند"},
    "Nasim Bakhtiari": {"talents_en": "coaching, stretching", "talents_fa": "مربی‌گری، نرمش", "problem_en": "sore knees", "problem_fa": "زانو درد",
                        "past_en": "she ran track at university", "past_fa": "در دانشگاه دو و میدانی کار می‌کرد", "hope_en": "a healthy town", "hope_fa": "شهری سالم"},
    "Arash Bakhtiari": {"talents_en": "running, looking after siblings", "talents_fa": "دویدن، مراقبت از خواهر و برادر", "problem_en": "homework", "problem_fa": "تکلیف",
                        "past_en": "he won a school race", "past_fa": "مسابقه‌ی مدرسه را برد", "hope_en": "to coach like mum", "hope_fa": "مثل مادر مربی شود"},
    "Baran Bakhtiari": {"talents_en": "dancing in the rain", "talents_fa": "رقص در باران", "problem_en": "wet shoes", "problem_fa": "کفش خیس",
                        "past_en": "she was born on a rainy day", "past_fa": "در یک روز بارانی به دنیا آمد", "hope_en": "a yellow umbrella", "hope_fa": "یک چتر زرد"},
    "Kourosh Bakhtiari": {"talents_en": "jumping, football", "talents_fa": "پریدن، فوتبال", "problem_en": "being the middle child", "problem_fa": "بچه‌ی وسط بودن",
                       "past_en": "he scored with his left foot", "past_fa": "با پای چپ گل زد", "hope_en": "a real football", "hope_fa": "یک توپ فوتبال واقعی"},
    "Yasmin Bakhtiari": {"talents_en": "hugging", "talents_fa": "بغل کردن", "problem_en": "bedtime", "problem_fa": "وقت خواب",
                         "past_en": "she smells like jasmine tea", "past_fa": "بوی چای یاس می‌دهد", "hope_en": "more stories", "hope_fa": "قصه‌ی بیشتر"},
    "Hooshang Kia": {"talents_en": "weather-reading, tea", "talents_fa": "شناخت هوا، چای", "problem_en": "stiff back", "problem_fa": "کمر خشک",
                     "past_en": "forty years on this land", "past_fa": "چهل سال روی این زمین", "hope_en": "the young keep farming", "hope_fa": "جوان‌ها کشاورزی را ادامه دهند"},
    "Mahin Kia": {"talents_en": "jam, remembering every book", "talents_fa": "مربا، به‌یاد آوردن هر کتاب", "problem_en": "small print", "problem_fa": "خط ریز",
                  "past_en": "she taught herself to read", "past_fa": "خودش خواندن یاد گرفت", "hope_en": "a full library shelf", "hope_fa": "یک قفسه‌ی پر کتاب"},
    "Pouria Houshyar": {"talents_en": "reading the sea, knots", "talents_fa": "خواندن دریا، گره", "problem_en": "fog", "problem_fa": "مه",
                        "past_en": "he sailed with his father as a boy", "past_fa": "در بچگی با پدرش کشتی راند", "hope_en": "Ava loves the water safely", "hope_fa": "آوا با خیال راحت آب را دوست داشته باشد"},
    "Elham Houshyar": {"talents_en": "soups, calming Ava", "talents_fa": "سوپ، آرام کردن آوا", "problem_en": "burnt toast", "problem_fa": "نان سوخته",
                       "past_en": "she cooked for a cafe in the city", "past_fa": "در شهر برای یک کافه آشپزی می‌کرد", "hope_en": "a family table full of laughter", "hope_fa": "سفره‌ای پر از خنده"},
    "Ava Houshyar": {"talents_en": "spotting dolphins", "talents_fa": "دیدن دلفین", "problem_en": "salty hair", "problem_fa": "موی شور",
                     "past_en": "her first word was 'boat'", "past_fa": "اولین کلمه‌اش 'قایق' بود", "hope_en": "to captain like dad", "hope_fa": "مثل بابا ناخدا شود"},
    "Ramin Soleimani": {"talents_en": "listening, short clear sentences", "talents_fa": "گوش دادن، جمله‌های کوتاه و روشن", "problem_en": "quiet evenings", "problem_fa": "عصرهای خلوت",
                        "past_en": "he wrote for a city paper before moving here", "past_fa": "قبل از آمدن به اینجا برای یک روزنامه‌ی شهری می‌نوشت",
                        "hope_en": "the town paper tells the truth kindly", "hope_fa": "روزنامه‌ی شهر راست را مهربان بگوید"},
}
for fn in ("modules/backstories/town_stories.tres", "modules/backstories/quiet_stories.tres"):
    p = os.path.join(ROOT, fn)
    src = open(p, encoding="utf-8").read()
    m = re.search(r"^people = (\{.*\})$", src, re.M)
    cur = json.loads(m.group(1))
    cur.update(NEW_STORIES)
    line = "people = " + json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
    open(p, "w", encoding="utf-8").write(src[:m.start()] + line + src[m.end():])
print("backstories: +%d people, Reza updated" % len(NEW_STORIES))

# ui_text phrases
PHRASES = {
    "read the city fund board": "خواندن تابلوی صندوق شهر",  # kept for old saves; board is indoors now
    "talk to the city manager": "صحبت با مدیر شهرداری",
    "look at the fund board": "نگاه به تابلوی صندوق",
    "The post office has closed; mail is handled at City Hall.": "اداره‌ی پست بسته شده؛ نامه‌ها در شهرداری انجام می‌شود.",
}
for fn in ("farsi.tres", "farsi_short.tres"):
    path = os.path.join(ROOT, "modules", "ui_text", fn)
    src = open(path, encoding="utf-8").read()
    m = re.search(r"^phrases = (\{.*\})$", src, re.M)
    cur = json.loads(m.group(1))
    cur.update(PHRASES)
    line = "phrases = " + json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
    open(path, "w", encoding="utf-8").write(src[:m.start()] + line + src[m.end():])
print("ui_text: +%d phrases" % len(PHRASES))
print("DONE gen_modules_v7b1_visual")
