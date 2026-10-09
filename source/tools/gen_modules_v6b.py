#!/usr/bin/env python3
"""Generates the v6b module style scripts (modules/<type>/<script>.gd), the
module .tres variants and registers them in data/asset_modules.json:
  character_creator, wardrobe, npc_looks, vehicles, ambulance, police_patrol,
  wood_pickup, gas_stove, fridge, living_room, house_colors, landmark,
  fruit_gardens, town_lots, pushables, herding, digging, yard_routine,
  world_memory, shadows, cloud_shadows  (+ gym / ui_text updated in place).
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6a.py"), encoding="utf-8").read()
# Reuse the v6a helpers (write_tres, val, emit) without re-running v6a's tables.
head = src.split("ALL_WEATHER =")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6a.py")}
exec(head, ns)
write_tres, psa, val, config, config_path, emit = ns["write_tres"], ns["psa"], ns["val"], ns["config"], ns["config_path"], ns["emit"]


TO_ITEMS = """

func to_items() -> Dictionary:
	var out := {}
	for k in items:
		var it: Dictionary = (items[k] as Dictionary).duplicate()
		it["module_item"] = true
		out[k] = it
	return out
"""


def style_script(type_, script, cls, doc, fields, extra=""):
    """fields: [(name, gdtype, default_literal, comment)]"""
    lines = ["class_name %s" % cls, "extends AssetModule", "## " + doc.replace("\n", "\n## "), ""]
    lines.append('@export var name_fa: String = ""')
    for name, gdt, default, comment in fields:
        if comment:
            lines.append("## " + comment)
        lines.append("@export var %s: %s = %s" % (name, gdt, default))
    path = os.path.join(ROOT, "modules", type_, script + ".gd")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n" + extra)


def V2(x, y): return "V2(%g, %g)" % (x, y)
def V3(x, y, z): return "V3(%g, %g, %g)" % (x, y, z)

# ====================================================================== 1. character creator / wardrobe / npc looks
style_script("character_creator", "character_creator_style", "CharacterCreatorStyle",
    "v6b character creator: body shapes (incl. slim), faces, hair, beards, skin tones,\nhair colours and job presets for the player, built from the CC0 Quaternius\nparts in the project. Consumers: CharacterCreator (panel), PlayerLook, HumanoidModelVisual.", [
    ("bodies", "Array", "[]", "{id, en, fa, body_type, width, height}"),
    ("faces", "Array", "[]", "{id, en, fa, brows, head, tint}"),
    ("hair", "Array", "[]", "{id, en, fa, style}"),
    ("beards", "Array", "[]", "{id, en, fa, beard}"),
    ("skins", "Array", "[]", "{id, en, fa, tone, tint}"),
    ("hair_colors", "Array", "[]", "Colours"),
    ("jobs", "Array", "[]", "{id, en, fa, shirt, pants, top, perk_en, perk_fa, item, count}"),
    ("default_look", "Dictionary", "{}", "Look the player starts with"),
    ("open_on_new_game", "bool", "true", "Offer the creator the first time a new game starts"),
])
BODIES = [
    {"id": "regular_m", "en": "Regular (man)", "fa": "معمولی (مرد)", "body_type": "male", "width": 1.0, "height": 1.0},
    {"id": "slim_m", "en": "Slim (man)", "fa": "لاغر (مرد)", "body_type": "male", "width": 0.86, "height": 1.0},
    {"id": "tall_slim_m", "en": "Tall & slim (man)", "fa": "قدبلند و لاغر (مرد)", "body_type": "male", "width": 0.84, "height": 1.05},
    {"id": "sturdy_m", "en": "Sturdy (man)", "fa": "چهارشانه (مرد)", "body_type": "male", "width": 1.1, "height": 0.98},
    {"id": "regular_f", "en": "Regular (woman)", "fa": "معمولی (زن)", "body_type": "female", "width": 1.0, "height": 1.0},
    {"id": "slim_f", "en": "Slim (woman)", "fa": "لاغر (زن)", "body_type": "female", "width": 0.88, "height": 1.0},
    {"id": "petite_f", "en": "Petite (woman)", "fa": "ریزنقش (زن)", "body_type": "female", "width": 0.9, "height": 0.95},
]
FACES = [
    {"id": "classic", "en": "Classic", "fa": "کلاسیک", "brows": "Eyebrows_Regular", "head": 1.0, "tint": (1, 1, 1)},
    {"id": "round", "en": "Round face", "fa": "صورت گرد", "brows": "Eyebrows_Regular", "head": 1.06, "tint": (1.02, 0.98, 0.96)},
    {"id": "narrow", "en": "Narrow face", "fa": "صورت کشیده", "brows": "Eyebrows_Female", "head": 0.94, "tint": (1, 1, 1)},
    {"id": "soft", "en": "Soft features", "fa": "چهره‌ی نرم", "brows": "Eyebrows_Female", "head": 1.0, "tint": (1.03, 0.99, 0.97)},
    {"id": "bold", "en": "Bold brows", "fa": "ابروی پرپشت", "brows": "Eyebrows_Regular", "head": 1.03, "tint": (0.97, 0.95, 0.93)},
    {"id": "plain", "en": "No brows (plain)", "fa": "ساده", "brows": "", "head": 1.0, "tint": (1, 1, 1)},
]
HAIR = [{"id": "parted", "en": "Side part", "fa": "فرق کج", "style": "Hair_SimpleParted"},
        {"id": "buzzed", "en": "Buzz cut", "fa": "کوتاه ماشینی", "style": "Hair_Buzzed"},
        {"id": "long", "en": "Long", "fa": "بلند", "style": "Hair_Long"},
        {"id": "buns", "en": "Buns", "fa": "گوجه‌ای", "style": "Hair_Buns"},
        {"id": "bald", "en": "Bald", "fa": "بی‌مو", "style": ""}]
BEARDS = [{"id": "none", "en": "Clean-shaven", "fa": "بدون ریش", "beard": False},
          {"id": "full", "en": "Full beard", "fa": "ریش کامل", "beard": True}]
SKINS = [{"id": "fair", "en": "Fair", "fa": "روشن", "tone": 0, "tint": (1.04, 1.0, 0.98)},
         {"id": "light", "en": "Light", "fa": "سفید", "tone": 0, "tint": (1, 1, 1)},
         {"id": "olive", "en": "Olive", "fa": "گندمی", "tone": 0, "tint": (0.9, 0.84, 0.74)},
         {"id": "tan", "en": "Tan", "fa": "برنزه", "tone": 1, "tint": (1.12, 1.06, 1.0)},
         {"id": "brown", "en": "Brown", "fa": "سبزه", "tone": 1, "tint": (1, 1, 1)},
         {"id": "deep", "en": "Deep", "fa": "تیره", "tone": 1, "tint": (0.85, 0.82, 0.8)}]
HAIR_COLORS = [(0.08, 0.06, 0.05), (0.2, 0.13, 0.08), (0.32, 0.2, 0.11), (0.55, 0.38, 0.2), (0.78, 0.62, 0.38), (0.45, 0.2, 0.1), (0.6, 0.6, 0.62)]
JOBS = [
    {"id": "farmer", "en": "Farmer", "fa": "کشاورز", "shirt": (0.66, 0.24, 0.18), "pants": (0.2, 0.3, 0.48), "top": "work_shirt",
     "perk_en": "Starts with turnip seeds", "perk_fa": "با چند بذر شلغم شروع می‌کند", "item": "turnip_seeds", "count": 6},
    {"id": "carpenter", "en": "Carpenter", "fa": "نجار", "shirt": (0.55, 0.42, 0.25), "pants": (0.3, 0.25, 0.2), "top": "work_shirt",
     "perk_en": "Starts with wood planks", "perk_fa": "با چند تخته شروع می‌کند", "item": "wood_plank", "count": 3},
    {"id": "fisher", "en": "Fisher", "fa": "ماهیگیر", "shirt": (0.2, 0.4, 0.55), "pants": (0.22, 0.24, 0.28), "top": "jacket",
     "perk_en": "Starts with a fishing rod", "perk_fa": "با چوب ماهیگیری شروع می‌کند", "item": "fishing_rod", "count": 1},
    {"id": "doctor", "en": "Doctor", "fa": "پزشک", "shirt": (0.92, 0.94, 0.95), "pants": (0.3, 0.35, 0.45), "top": "long_sleeve",
     "perk_en": "Starts with healing herbs", "perk_fa": "با سبزی‌های دارویی شروع می‌کند", "item": "herbs", "count": 4},
    {"id": "cook", "en": "Cook", "fa": "آشپز", "shirt": (0.95, 0.93, 0.88), "pants": (0.15, 0.15, 0.17), "top": "tshirt",
     "perk_en": "Starts with rice", "perk_fa": "با کمی برنج شروع می‌کند", "item": "rice", "count": 3},
    {"id": "driver", "en": "Driver", "fa": "راننده", "shirt": (0.25, 0.28, 0.32), "pants": (0.15, 0.17, 0.2), "top": "polo",
     "perk_en": "Drives a little faster", "perk_fa": "کمی تندتر رانندگی می‌کند", "item": ""},
]
DEFAULT_LOOK = {"name": "", "body": "regular_m", "face": "classic", "hair": "parted", "hair_color": 2, "beard": "full",
                "skin": "light", "job": "farmer"}
emit("character_creator", "CharacterCreatorStyle", "character_creator_style", [
    ("quaternius_parts", "Quaternius parts", "Slim / regular / sturdy bodies, 6 faces, 5 hair styles, beards, 6 skin tones, 6 job presets (CC0 Quaternius).",
     {"name_fa": "سازنده‌ی شخصیت", "bodies": BODIES, "faces": FACES, "hair": HAIR, "beards": BEARDS, "skins": SKINS,
      "hair_colors": HAIR_COLORS, "jobs": JOBS, "default_look": DEFAULT_LOOK}),
    ("slim_start", "Slim start", "Same parts; new players start with the slim body.",
     {"name_fa": "شروع با بدن لاغر", "bodies": BODIES, "faces": FACES, "hair": HAIR, "beards": BEARDS, "skins": SKINS,
      "hair_colors": HAIR_COLORS, "jobs": JOBS, "default_look": dict(DEFAULT_LOOK, body="slim_m"), "open_on_new_game": False}),
], "quaternius_parts")

style_script("wardrobe", "wardrobe_style", "WardrobeStyle",
    "v6b home wardrobe: tops (shape) + colours for shirts and trousers. A wardrobe\nstands in the farmhouse; choices are saved with the player. Consumer: Wardrobe.", [
    ("tops", "Array", "[]", "{id, en, fa}  (shape ids understood by HumanoidModelVisual)"),
    ("shirt_colors", "Array", "[]", ""), ("pants_colors", "Array", "[]", ""),
    ("cabinet_color", "Color", "Color(0.5, 0.34, 0.2)", ""),
])
TOPS = [{"id": "work_shirt", "en": "Work shirt", "fa": "پیراهن کار"}, {"id": "tshirt", "en": "T-shirt", "fa": "تی‌شرت"},
        {"id": "polo", "en": "Polo", "fa": "پولو"}, {"id": "long_sleeve", "en": "Long sleeves", "fa": "آستین بلند"},
        {"id": "jacket", "en": "Jacket", "fa": "کاپشن"}, {"id": "tank", "en": "Tank top", "fa": "رکابی"}]
SHIRTS = [(0.66, 0.24, 0.18), (0.2, 0.4, 0.62), (0.25, 0.5, 0.3), (0.92, 0.92, 0.9), (0.15, 0.15, 0.17), (0.85, 0.65, 0.2),
          (0.5, 0.28, 0.55), (0.9, 0.5, 0.55), (0.35, 0.55, 0.6), (0.55, 0.42, 0.25)]
PANTS = [(0.2, 0.3, 0.48), (0.15, 0.15, 0.17), (0.35, 0.3, 0.22), (0.45, 0.42, 0.36), (0.25, 0.32, 0.25), (0.55, 0.5, 0.42)]
emit("wardrobe", "WardrobeStyle", "wardrobe_style", [
    ("home_wardrobe", "Home wardrobe", "6 tops x 10 shirt colours, 6 trouser colours; wooden wardrobe in the farmhouse.",
     {"name_fa": "کمد لباس خانه", "tops": TOPS, "shirt_colors": SHIRTS, "pants_colors": PANTS}),
    ("festive", "Festive wardrobe", "Brighter colours for Nowruz.",
     {"name_fa": "لباس‌های عید", "tops": TOPS, "shirt_colors": [(0.9, 0.2, 0.2), (0.1, 0.6, 0.35), (0.95, 0.8, 0.2), (0.2, 0.45, 0.85), (0.95, 0.95, 0.95)],
      "pants_colors": PANTS, "cabinet_color": (0.62, 0.42, 0.25)}),
], "home_wardrobe")

style_script("npc_looks", "npc_looks_style", "NpcLooksStyle",
    "v6b townspeople looks: every resident gets a stable, distinct face (brows, head\nsize, skin tint), hair and body width from their name. Consumer: Townspeople.outfit_for.", [
    ("enabled", "bool", "true", ""),
    ("brows", "Array", "[]", "brow meshes to pick from"),
    ("head_range", "Vector2", "Vector2(0.95, 1.05)", ""),
    ("width_range", "Vector2", "Vector2(0.88, 1.08)", ""),
    ("tint_jitter", "float", "0.06", ""),
    ("hair_women", "Array", "[]", ""), ("hair_men", "Array", "[]", ""),
    ("beard_chance", "float", "0.45", "for men over 20"),
    ("hair_colors", "Array", "[]", ""),
    ("tag_hide_near", "float", "2.4", "m - name tag + bubble hide when the camera is closer"),
    ("indoor_label_scale", "float", "0.55", "name tag + bubble size indoors (gym, shops, homes)"),
])
emit("npc_looks", "NpcLooksStyle", "npc_looks_style", [
    ("distinct", "Distinct faces", "Brows, head size, body width, skin tint and hair vary per resident (stable per name).",
     {"name_fa": "چهره‌های متفاوت", "brows": ["Eyebrows_Regular", "Eyebrows_Female", "Eyebrows_Regular"],
      "hair_women": ["Hair_Long", "Hair_Buns", "Hair_SimpleParted", "Hair_Long"], "hair_men": ["Hair_SimpleParted", "Hair_Buzzed", "Hair_Buzzed", ""],
      "hair_colors": HAIR_COLORS}),
    ("subtle", "Subtle variety", "Only brows and small size changes; hair from the population module.",
     {"name_fa": "تنوع کم", "brows": ["Eyebrows_Regular"], "head_range": V2(0.98, 1.02), "width_range": V2(0.96, 1.03), "tint_jitter": 0.02,
      "hair_women": [], "hair_men": [], "beard_chance": -1.0, "hair_colors": []}),
], "distinct")

# ====================================================================== 2. vehicles
style_script("vehicles", "vehicle_style", "VehicleStyle",
    "v6b parked cars you can get into (E) and drive on the town roads (W/S gas +\nbrake, A/D steer, Space handbrake, R horn, E get out). Replaces the static\nparked cars. Positions are remembered (WorldMemory). Consumer: Vehicles / Car.", [
    ("cars", "Array", "[]", "{model, pos (V2), yaw (deg), drivable, color_en, color_fa}"),
    ("models_dir", "String", '"res://assets/third_party/kenney/cars/"', ""),
    ("max_speed", "float", "11.0", "m/s"), ("reverse_speed", "float", "4.0", ""),
    ("accel", "float", "5.5", ""), ("brake", "float", "10.0", ""), ("steer_deg", "float", "34.0", ""),
    ("dealership_note_en", "String", '""', ""), ("dealership_note_fa", "String", '""', ""),
])
CARS = [
    {"model": "sedan", "pos": V2(-12.0, -86.65), "yaw": 90.0, "drivable": True},
    {"model": "van", "pos": V2(30.0, -93.35), "yaw": -90.0, "drivable": True},
    {"model": "sedan", "pos": V2(3.35, -112.0), "yaw": 0.0, "drivable": True},
    {"model": "sedan", "pos": V2(51.65, -30.0), "yaw": 180.0, "drivable": True},
    {"model": "delivery", "pos": V2(27.0, -46.1), "yaw": 90.0, "drivable": True},
    {"model": "tractor", "pos": V2(15.5, 11.5), "yaw": -17.0, "drivable": True},
    {"model": "sedan", "pos": V2(5.2, -16.0), "yaw": 0.0, "drivable": True},
]
NOTE_EN = "A car dealership is coming in a later version - for now the town's cars are shared."
NOTE_FA = "نمایندگی فروش خودرو در نسخه‌های بعد می‌آید - فعلاً ماشین‌های شهر مشترک‌اند."
emit("vehicles", "VehicleStyle", "vehicle_style", [
    ("town_cars", "Town cars", "7 parked cars (sedans, van, delivery truck, tractor) you can drive on the existing roads.",
     {"name_fa": "ماشین‌های شهر", "cars": CARS, "dealership_note_en": NOTE_EN, "dealership_note_fa": NOTE_FA}),
    ("gentle_cars", "Gentle cars", "Same cars, slower top speed (town 30 km/h).",
     {"name_fa": "رانندگی آرام", "cars": CARS, "max_speed": 8.3, "accel": 4.0, "dealership_note_en": NOTE_EN, "dealership_note_fa": NOTE_FA}),
], "town_cars")

style_script("ambulance", "ambulance_style", "AmbulanceStyle",
    "v6b ambulance: parked at the hospital; when a townsperson falls ill the\nambulance drives out with a two-person crew, they walk the patient in and\nbring them to the hospital (Needs). Consumer: AmbulanceService.", [
    ("model", "String", '"ambulance"', ""), ("speed", "float", "9.0", ""),
    ("crew", "int", "2", ""), ("dispatch", "Dictionary", "{}", "illness id -> chance (0..1)"),
    ("crew_shirt", "Color", "Color(0.92, 0.94, 0.95)", ""), ("crew_pants", "Color", "Color(0.2, 0.3, 0.55)", ""),
    ("siren", "bool", "true", ""), ("base", "Vector2", "Vector2(41.5, -53.9)", "parking spot"),
])
emit("ambulance", "AmbulanceStyle", "ambulance_style", [
    ("city_ambulance", "City ambulance", "Answers every flu and 40% of colds; crew of two; lights flash on the way.",
     {"name_fa": "آمبولانس شهر", "dispatch": {"flu": 1.0, "cold": 0.4, "*": 0.6}}),
    ("serious_only", "Serious cases only", "Only the flu (and worse) gets the ambulance.",
     {"name_fa": "فقط موارد جدی", "dispatch": {"flu": 1.0, "cold": 0.0, "*": 0.3}, "speed": 8.0}),
], "city_ambulance")

style_script("police_patrol", "police_patrol_style", "PolicePatrolStyle",
    "v6b police car: patrols the town loop (Main St, Oak Ave, Maple St, Pine Ln)\nwith two officers, stops for people in front of it. Hook for v7 justice\n(fruit theft reports). Consumer: PolicePatrol.", [
    ("model", "String", '"police"', ""), ("speed", "float", "6.5", ""),
    ("route", "Array", "[]", "V2 points (loop)"), ("hours", "Vector2", "Vector2(6, 23)", "on patrol between"),
    ("lights", "bool", "true", ""), ("base", "Vector2", "Vector2(-27.0, -53.9)", ""),
])
LOOP = [V2(-27.0, -51.5), V2(-45.0, -51.5), V2(-45.0, -88.5), V2(-1.5, -88.5), V2(-1.5, -61.5), V2(-12.0, -51.5)]
LOOP_WIDE = [V2(-27.0, -51.5), V2(-62.0, -51.5), V2(-62.0, -88.5), V2(53.0, -88.5), V2(53.0, -51.5), V2(12.0, -51.5), V2(1.5, -62.0),
             V2(1.5, -88.5), V2(-45.0, -88.5), V2(-45.0, -51.5)]
emit("police_patrol", "PolicePatrolStyle", "police_patrol_style", [
    ("town_patrol", "Town patrol", "One police car circles the west town blocks 06:00-23:00; lights at night.",
     {"name_fa": "گشت پلیس شهر", "route": LOOP}),
    ("wide_patrol", "Wide patrol", "A longer loop through the whole town.", {"name_fa": "گشت گسترده", "route": LOOP_WIDE, "speed": 7.5}),
], "town_patrol")

style_script("wood_pickup", "wood_pickup_style", "WoodPickupStyle",
    "v6b working pickup: a woodcutter drives to the dry trees, loads felled logs\nand brings them to the carpenter, who saws them into boards (Market stock:\ndry_wood -> wood_plank). Consumer: WoodPickup.", [
    ("trips_per_day", "int", "2", ""), ("logs_per_trip", "int", "3", ""), ("speed", "float", "7.0", ""),
    ("color", "Color", "Color(0.75, 0.2, 0.15)", ""), ("start_hours", "Array", "[]", "hours a trip starts"),
    ("yard", "Vector2", "Vector2(-28.0, -45.2)", "carpenter yard"), ("forest_stop", "Vector2", "Vector2(-70.0, -46.0)", ""),
    ("chop_seconds", "float", "4.0", ""),
])
emit("wood_pickup", "WoodPickupStyle", "wood_pickup_style", [
    ("red_pickup", "Red pickup", "Two trips a day (09:00, 14:00), 3 logs a trip.", {"name_fa": "وانت قرمز", "start_hours": [9, 14]}),
    ("busy_pickup", "Busy pickup", "Three trips a day, 4 logs, blue.", {"name_fa": "وانت پرکار", "start_hours": [8, 12, 16], "trips_per_day": 3,
     "logs_per_trip": 4, "color": (0.2, 0.35, 0.65)}),
], "red_pickup")

# ====================================================================== 3. interiors
style_script("gas_stove", "gas_stove_style", "GasStoveStyle",
    "v6b gas stove: kitchens get a gas hob; while you cook a ring of blue gas\nflames burns under the pan (flickering, with a soft light). Consumers:\nKitchenBuilder (hob), CookingStation (flame).", [
    ("force_gas", "bool", "true", ""), ("flame_color", "Color", "Color(0.25, 0.45, 1.0)", ""),
    ("tip_color", "Color", "Color(1.0, 0.7, 0.3)", ""), ("flame_height", "float", "0.1", ""),
    ("tongues", "int", "14", ""), ("idle_burners", "int", "0", "burners lit even when not cooking"),
])
emit("gas_stove", "GasStoveStyle", "gas_stove_style", [
    ("blue_flame", "Blue gas flame", "Gas hob in every kitchen; 14 blue flame tongues while cooking.", {"name_fa": "شعله‌ی آبی گاز"}),
    ("big_flame", "Big flame", "Taller flames, one burner left on low.", {"name_fa": "شعله‌ی بلند", "flame_height": 0.13, "tongues": 18, "idle_burners": 1}),
], "blue_flame")

style_script("fridge", "fridge_style", "FridgeStyle",
    "v6b openable fridge: the door swings open (E) and the shelves show what is\nstored - your groceries in the farmhouse, food in the townspeople's homes.\nConsumer: FridgeUnit (KitchenBuilder).", [
    ("body_color", "Color", "Color(0.93, 0.94, 0.95)", ""), ("inside_color", "Color", "Color(0.97, 0.98, 1.0)", ""),
    ("shelves", "int", "3", ""), ("light", "bool", "true", ""),
    ("npc_items", "Array", "[]", "ingredient ids shown in townspeople's fridges"),
])
emit("fridge", "FridgeStyle", "fridge_style", [
    ("white_fridge", "White fridge", "White two-shelf fridge with a light; shows your ingredients.",
     {"name_fa": "یخچال سفید", "npc_items": ["eggs", "milk", "tomato_fresh", "chicken", "herbs", "onion"]}),
    ("steel_fridge", "Steel fridge", "Brushed steel, four shelves.",
     {"name_fa": "یخچال استیل", "body_color": (0.7, 0.72, 0.75), "shelves": 4, "npc_items": ["eggs", "milk", "tomato_fresh", "chicken", "rice"]}),
], "white_fridge")

style_script("living_room", "living_room_style", "LivingRoomStyle",
    "v6b living rooms: a bigger flat LCD TV, a sofa you can push to another spot\n(remembered), a folded blanket and cushion by the window to sit on, and\nframed paintings on the walls. Consumer: InteriorV6b.", [
    ("lcd_width", "float", "1.45", ""), ("paintings", "Array", "[]", "{colors:[c1,c2,c3], kind}"),
    ("blanket_colors", "Array", "[]", ""), ("sofa_slots", "Array", "[]", "offsets (m) along the wall"),
    ("paintings_per_home", "int", "2", ""),
])
PAINTINGS = [{"kind": "landscape", "colors": [(0.45, 0.65, 0.9), (0.35, 0.6, 0.3), (0.95, 0.85, 0.5)]},
             {"kind": "sunset", "colors": [(0.95, 0.55, 0.25), (0.6, 0.25, 0.4), (0.15, 0.12, 0.2)]},
             {"kind": "sea", "colors": [(0.2, 0.45, 0.7), (0.9, 0.92, 0.95), (0.85, 0.75, 0.55)]},
             {"kind": "geometric", "colors": [(0.15, 0.45, 0.6), (0.9, 0.75, 0.3), (0.7, 0.2, 0.2)]},
             {"kind": "flowers", "colors": [(0.95, 0.9, 0.8), (0.85, 0.3, 0.4), (0.3, 0.55, 0.3)]}]
emit("living_room", "LivingRoomStyle", "living_room_style", [
    ("modern_living", "Modern living room", "1.45 m LCD TV, movable sofa (3 spots), blanket by the window, 2 paintings per home.",
     {"name_fa": "اتاق نشیمن مدرن", "paintings": PAINTINGS, "blanket_colors": [(0.75, 0.25, 0.2), (0.25, 0.45, 0.6), (0.85, 0.7, 0.35), (0.4, 0.55, 0.35)],
      "sofa_slots": [0.0, -0.9, 0.9]}),
    ("cozy_living", "Cozy living room", "Smaller 1.2 m TV, 3 paintings, warm blankets.",
     {"name_fa": "اتاق نشیمن دنج", "lcd_width": 1.2, "paintings": PAINTINGS, "paintings_per_home": 3,
      "blanket_colors": [(0.7, 0.2, 0.15), (0.85, 0.55, 0.2)], "sofa_slots": [0.0, -0.8, 0.8]}),
], "modern_living")

style_script("house_colors", "house_colors_style", "HouseColorsStyle",
    "v6b house colours tied to the owner: each family's house is painted in the\nfamily's colour (stable per surname); the farmhouse follows the player's\nchoice. Consumer: Building._apply_layout.", [
    ("palette", "Array", "[]", "wall colours"), ("strength", "float", "0.85", "0 = layout colour, 1 = family colour"),
    ("farmhouse_color", "Color", "Color(0.88, 0.82, 0.7)", ""),
])
emit("house_colors", "HouseColorsStyle", "house_colors_style", [
    ("family_colors", "Family colours", "12 warm Persian-town wall colours, one per family.",
     {"name_fa": "رنگ خانواده‌ها", "palette": [(0.93, 0.85, 0.7), (0.85, 0.62, 0.5), (0.72, 0.82, 0.72), (0.74, 0.82, 0.9), (0.95, 0.9, 0.62),
      (0.88, 0.72, 0.78), (0.8, 0.76, 0.66), (0.7, 0.78, 0.85), (0.92, 0.78, 0.6), (0.82, 0.88, 0.8), (0.9, 0.86, 0.8), (0.78, 0.68, 0.6)]}),
    ("whitewash", "Whitewash", "Mostly white houses with a hint of the family colour.",
     {"name_fa": "سفیدکاری", "palette": [(0.96, 0.95, 0.92), (0.95, 0.93, 0.88), (0.93, 0.94, 0.95)], "strength": 0.6}),
], "family_colors")

# ====================================================================== 4. landmark, fruit gardens, lots
style_script("landmark", "landmark_style", "LandmarkStyle",
    "v6b symbolic town-square landmark: a tall brick clock tower whose clock shows\nthe game time and chimes on the hour (or a monument). Consumer: Landmark.", [
    ("kind", "String", '"clock_tower"', "clock_tower | monument"),
    ("pos", "Vector2", "Vector2(13.5, -55.5)", ""), ("height", "float", "14.0", ""),
    ("brick", "Color", "Color(0.72, 0.42, 0.3)", ""), ("stone", "Color", "Color(0.88, 0.85, 0.78)", ""),
    ("roof", "Color", "Color(0.2, 0.45, 0.5)", ""), ("chime", "bool", "true", ""),
])
emit("landmark", "LandmarkStyle", "landmark_style", [
    ("clock_tower", "Clock tower", "14 m brick clock tower on the square's east corner; the four clock faces show game time; turquoise tiled cap.",
     {"name_fa": "برج ساعت"}),
    ("monument", "Freedom monument", "A tall white stone arch-monument with a turquoise band.",
     {"name_fa": "بنای یادبود", "kind": "monument", "height": 12.0, "brick": (0.92, 0.9, 0.85)}),
], "clock_tower")

style_script("fruit_gardens", "fruit_garden_style", "FruitGardenStyle",
    "v6b fruit gardens behind some townspeople's houses. The trees belong to the\nfamily: picking without asking is theft (a report is filed for the police -\nhook for v7 justice); asking the owner (greeting first today) makes it a gift.\nConsumer: FruitGardens.", [
    ("gardens", "Array", "[]", "{home, trees: [fruit ids], rows, cols}"),
    ("fruits", "Dictionary", "{}", "fruit id -> {en, fa, color, item}"),
    ("regrow_days", "int", "3", ""), ("theft_fine", "int", "50", "for v7 (recorded, not charged yet)"),
    ("items", "Dictionary", "{}", "fruit items (GameData)"),
], TO_ITEMS)
FRUITS = {"pomegranate": {"en": "pomegranate", "fa": "انار", "color": (0.75, 0.12, 0.15), "item": "pomegranate"},
          "orange": {"en": "orange", "fa": "پرتقال", "color": (0.98, 0.55, 0.1), "item": "orange"},
          "fig": {"en": "fig", "fa": "انجیر", "color": (0.4, 0.22, 0.35), "item": "fig"},
          "apple": {"en": "apple", "fa": "سیب", "color": (0.8, 0.15, 0.12), "item": "orchard_apple"}}
FRUIT_ITEMS = {
    "pomegranate": {"name": "Pomegranate", "name_fa": "انار", "type": "produce", "category": "fruit", "sell": 45, "description": "Ruby seeds, sweet and sour."},
    "orange": {"name": "Orange", "name_fa": "پرتقال", "type": "produce", "category": "fruit", "sell": 30, "description": "Juicy orange from a family orchard."},
    "fig": {"name": "Fig", "name_fa": "انجیر", "type": "produce", "category": "fruit", "sell": 38, "description": "Soft, sweet fig."},
    "orchard_apple": {"name": "Orchard Apple", "name_fa": "سیب باغ", "type": "produce", "category": "fruit", "sell": 28, "description": "Crisp apple from a family orchard."}}
GARDENS = [{"home": "maple3", "trees": ["pomegranate", "fig", "pomegranate", "orange"]},
           {"home": "maple5", "trees": ["orange", "orange", "apple", "pomegranate"]},
           {"home": "oak15", "trees": ["fig", "apple", "fig"]},
           {"home": "pine9", "trees": ["pomegranate", "apple", "orange", "fig"]}]
emit("fruit_gardens", "FruitGardenStyle", "fruit_garden_style", [
    ("family_orchards", "Family orchards", "4 back-yard orchards (pomegranate, orange, fig, apple); fruit regrows in 3 days.",
     {"name_fa": "باغ میوه‌ی خانواده‌ها", "gardens": GARDENS, "fruits": FRUITS, "items": FRUIT_ITEMS}),
    ("small_orchards", "Small orchards", "2 orchards, slower regrowth.",
     {"name_fa": "باغچه‌های کوچک", "gardens": GARDENS[:2], "fruits": FRUITS, "regrow_days": 5, "items": FRUIT_ITEMS}),
], "family_orchards")

style_script("town_lots", "town_lots_style", "TownLotsStyle",
    "v6b slight town expansion: a few new lots at the town edge - a newly built\nhouse, one under construction and an empty lot for sale (hook for buying\nland later). Consumer: TownLots.", [
    ("lots", "Array", "[]", "{id, pos, yaw, state (built | construction | for_sale), wall, roof, address}"),
])
LOTS = [{"id": "lot_harbor4", "pos": V2(65.0, -21.0), "yaw": -90.0, "state": "built", "wall": (0.92, 0.84, 0.66), "roof": (0.4, 0.25, 0.2), "address": "4 Harbor Rd"},
        {"id": "lot_pine20", "pos": V2(-55.5, -118.0), "yaw": 90.0, "state": "construction", "wall": (0.85, 0.85, 0.85), "roof": (0.3, 0.3, 0.33), "address": "20 Pine Ln"},
        {"id": "lot_main30", "pos": V2(-68.0, -61.5), "yaw": 0.0, "state": "for_sale", "wall": (0.9, 0.9, 0.9), "roof": (0.3, 0.3, 0.3), "address": "30 Main St"}]
emit("town_lots", "TownLotsStyle", "town_lots_style", [
    ("three_lots", "Three new lots", "A new house on Harbor Rd, one being built on Pine Ln, an empty lot for sale on Main St.",
     {"name_fa": "سه زمین تازه", "lots": LOTS}),
    ("for_sale_only", "Lots for sale", "Only empty lots for sale.", {"name_fa": "فقط زمین فروشی",
     "lots": [dict(l, state="for_sale") for l in LOTS]}),
], "three_lots")

# ====================================================================== 5. environment interaction
style_script("pushables", "pushable_style", "PushableStyle",
    "v6b boxes you can push (walk into them / E) and stack (F to lift, place on\ntop of another box). Their spots are remembered (WorldMemory).\nConsumer: Pushables.", [
    ("boxes", "Array", "[]", "{pos (V2), kind}"), ("push_step", "float", "0.9", "m per push"),
    ("max_stack", "int", "3", ""), ("color", "Color", "Color(0.62, 0.45, 0.26)", ""),
])
BOXES = [{"pos": V2(13.5, 3.5), "kind": "box"}, {"pos": V2(14.7, 3.7), "kind": "box"}, {"pos": V2(14.1, 4.9), "kind": "box"},
         {"pos": V2(15.6, 4.6), "kind": "box"}, {"pos": V2(-26.0, -45.0), "kind": "box"}, {"pos": V2(-24.5, -44.4), "kind": "box"}]
emit("pushables", "PushableStyle", "pushable_style", [
    ("farm_boxes", "Farm boxes", "4 wooden boxes in the farmyard + 2 at the carpenter's; push 0.9 m, stack up to 3.",
     {"name_fa": "جعبه‌های مزرعه", "boxes": BOXES}),
    ("heavy_boxes", "Heavy boxes", "Shorter pushes (0.5 m), stack 2.", {"name_fa": "جعبه‌های سنگین", "boxes": BOXES, "push_step": 0.5, "max_stack": 2}),
], "farm_boxes")

style_script("herding", "herding_style", "HerdingStyle",
    "v6b sheep herding: a small flock grazes in the west meadow; sheep move away\nfrom you, so walking behind them drives them through the gate into the pen.\nAll in = the flock is penned (reward, part of the yard routine).\nConsumer: Herding.", [
    ("flock", "int", "5", ""), ("meadow", "Vector2", "Vector2(-42.0, -16.0)", ""), ("meadow_radius", "float", "9.0", ""),
    ("pen", "Rect2", "Rect2(-30.0, -12.0, 8.0, 7.0)", "x, z, w, d"), ("gate_side", "String", '"west"', ""),
    ("flee_radius", "float", "4.0", ""), ("flee_speed", "float", "2.6", ""), ("reward", "int", "40", ""),
])
emit("herding", "HerdingStyle", "herding_style", [
    ("west_meadow", "West meadow flock", "5 sheep, pen with a west gate near the pond path; 40 G for penning them.", {"name_fa": "گله‌ی چمنزار غربی"}),
    ("big_flock", "Big flock", "8 sheep, faster.", {"name_fa": "گله‌ی بزرگ", "flock": 8, "flee_speed": 3.0, "reward": 70}),
], "west_meadow")

style_script("digging", "digging_style", "DiggingStyle",
    "v6b digging: with the hoe (or a shovel) dig a hole in open ground (E while\nholding Shift... or the 'dig' prompt); holes stay (WorldMemory), sometimes\nturn up stones, worms or an old coin, and fill back in after some days.\nConsumer: Digging.", [
    ("finds", "Array", "[]", "{item, chance, en, fa}"), ("refill_days", "int", "4", ""), ("max_holes", "int", "24", ""),
    ("stamina", "float", "6.0", ""), ("radius", "float", "0.35", ""),
    ("items", "Dictionary", "{}", "finds as items (GameData)"),
], TO_ITEMS)
FINDS = [{"item": "stone", "chance": 0.35, "en": "a stone", "fa": "یک سنگ"},
         {"item": "worm", "chance": 0.25, "en": "a worm (fishing bait)", "fa": "یک کرم (طعمه‌ی ماهیگیری)"},
         {"item": "old_coin", "chance": 0.05, "en": "an old coin!", "fa": "یک سکه‌ی قدیمی!"}]
DIG_ITEMS = {
    "stone": {"name": "Stone", "name_fa": "سنگ", "type": "produce", "category": "material", "sell": 3, "description": "A stone from the ground. The mason buys them."},
    "worm": {"name": "Worm", "name_fa": "کرم خاکی", "type": "produce", "category": "bait", "sell": 2, "description": "Fishing bait."},
    "old_coin": {"name": "Old Coin", "name_fa": "سکه‌ی قدیمی", "type": "produce", "category": "treasure", "sell": 250, "description": "A Qajar-era silver coin. Worth a lot to a collector."}}
emit("digging", "DiggingStyle", "digging_style", [
    ("garden_spade", "Dig holes", "Dig anywhere on open grass; finds stones, worms, rarely an old coin; holes fill in after 4 days.",
     {"name_fa": "کندن چاله", "finds": FINDS, "items": DIG_ITEMS}),
    ("treasure", "Treasure hunt", "Old coins are more common.", {"name_fa": "گنج‌یابی", "finds": [dict(f, chance=(0.15 if f["item"] == "old_coin" else f["chance"])) for f in FINDS], "items": DIG_ITEMS}),
], "garden_spade")

style_script("yard_routine", "yard_routine_style", "YardRoutineStyle",
    "v6b daily yard routine: a short checklist each day (let the sheep out in the\nmorning, stack the boxes, water the garden, pen the flock in the evening).\nShown under the clock; finishing it gives a small reward + a healthy-life\nbonus. Consumer: YardRoutine.", [
    ("tasks", "Array", "[]", "{id, en, fa, from, to}"), ("reward", "int", "30", ""), ("stamina_bonus", "float", "10.0", ""),
])
TASKS = [{"id": "water", "en": "Water the garden", "fa": "آب دادن باغچه", "from": 5, "to": 20},
         {"id": "stack", "en": "Tidy the boxes (stack 2)", "fa": "مرتب کردن جعبه‌ها (دوتا روی هم)", "from": 6, "to": 22},
         {"id": "herd", "en": "Pen the sheep", "fa": "بردن گوسفندها به آغل", "from": 6, "to": 23},
         {"id": "dig", "en": "Dig in the yard", "fa": "کندن زمین", "from": 6, "to": 22}]
emit("yard_routine", "YardRoutineStyle", "yard_routine_style", [
    ("farm_day", "Farm day", "4 small yard jobs; 30 G + 10 max stamina for the day when done.", {"name_fa": "کارهای روزانه‌ی حیاط", "tasks": TASKS}),
    ("light_day", "Light day", "Two jobs only.", {"name_fa": "روز سبک", "tasks": TASKS[:1] + TASKS[2:3], "reward": 15}),
], "farm_day")

# ====================================================================== 6. world memory
style_script("world_memory", "world_memory_style", "WorldMemoryStyle",
    "v6b world memory: what the world remembers - moved boxes and sofas, dug\nholes, dropped items, parked car spots, picked fruit, and what townspeople\nremember about the player (helped, stole, drove past...). Saved with the game\nand synced through the v5d save system. Consumer: WorldMemory (autoload).", [
    ("remember", "PackedStringArray", "PackedStringArray()", "kinds kept"),
    ("npc_memory_max", "int", "12", "events per townsperson"), ("forget_days", "int", "0", "0 = never forget"),
    ("drop_max", "int", "40", ""),
])
KINDS = ["moved", "holes", "drops", "cars", "fruit", "npc", "routine", "sofa", "herd"]
emit("world_memory", "WorldMemoryStyle", "world_memory_style", [
    ("remember_all", "Remember everything", "Nothing is forgotten: objects, holes, drops, cars, fruit and townspeople's memories.",
     {"name_fa": "همه چیز به یاد می‌ماند", "remember": psa(*KINDS)}),
    ("forgetful", "Forgetful town", "Townspeople forget after 14 days; drops vanish after 3.",
     {"name_fa": "شهر فراموشکار", "remember": psa(*KINDS), "forget_days": 14, "npc_memory_max": 6}),
], "remember_all")

# ====================================================================== 7. shadows + cloud shadows
style_script("shadows", "shadow_style", "ShadowStyle",
    "v6b realistic sun shadows. Desktop: 4 cascades, soft (PCSS angular size +\nblur), blended cascades. Web: 2 cascades, cheap. Consumer: ShadowRig.", [
    ("desktop_splits", "Vector3", "Vector3(0.06, 0.18, 0.45)", ""), ("desktop_distance", "float", "90.0", ""),
    ("desktop_angular", "float", "0.6", "degrees (soft penumbra)"), ("desktop_blur", "float", "1.8", ""),
    ("blend_splits", "bool", "true", ""), ("web_distance", "float", "45.0", ""), ("web_blur", "float", "1.2", ""),
    ("fade_start", "float", "0.85", ""),
])
emit("shadows", "ShadowStyle", "shadow_style", [
    ("soft_cascades", "Soft cascaded shadows", "Desktop: 4 blended cascades to 90 m, soft penumbra (0.6 deg); web: 2 cascades to 45 m.",
     {"name_fa": "سایه‌ی نرم آبشاری"}),
    ("crisp", "Crisp shadows", "Sharper edges, shorter range.", {"name_fa": "سایه‌ی تیز", "desktop_angular": 0.0, "desktop_blur": 1.0, "desktop_distance": 70.0}),
], "soft_cascades")

style_script("cloud_shadows", "cloud_shadow_style", "CloudShadowStyle",
    "v6b moving cloud shadows: soft dark patches drift over the ground (terrain +\ngrass shaders, a global shader parameter - no extra draw calls), following the\nweather (more on cloudy days, none at night). Consumer: CloudShadows.", [
    ("strength", "float", "0.32", ""), ("scale", "float", "0.012", "noise frequency (1/m)"),
    ("speed", "Vector2", "Vector2(1.6, 0.7)", "m/s"), ("coverage", "Dictionary", "{}", "weather -> 0..1"),
    ("web_strength", "float", "0.26", ""),
])
COV = {"sunny": 0.35, "cloudy": 0.75, "rain": 0.9, "storm": 0.95, "heatwave": 0.15, "snow": 0.8}
emit("cloud_shadows", "CloudShadowStyle", "cloud_shadow_style", [
    ("drifting", "Drifting cloud shadows", "Soft patches drift west to east; more on cloudy days.", {"name_fa": "سایه‌ی ابرهای روان", "coverage": COV}),
    ("still_day", "Few clouds", "Only a few faint patches.", {"name_fa": "ابر کم", "strength": 0.18, "coverage": {k: v * 0.5 for k, v in COV.items()}}),
], "drifting")

# ====================================================================== 8. polish: sea horizon
style_script("sea_horizon", "sea_horizon_style", "SeaHorizonStyle",
    "v6b: blends the pale/grey band between the far sea and the sky. Below the\nhorizon on the sea side the sky dome is painted as distant water fading into\nthe haze instead of the grey ground colour. Consumer: DayNightCycle (sky shader).", [
    ("blend", "float", "1.0", "0 = classic grey band, 1 = fully blended"),
    ("sea_color", "Color", "Color(0.16, 0.36, 0.55)", "distant water (day)"),
    ("haze", "float", "0.45", "how much of the horizon haze tints the distant water"),
    ("sharpness", "float", "40.0", "how quickly the horizon haze turns to water below it"),
    ("fog_match", "float", "0.8", "distance haze tinted toward the sky's horizon colour (far sea fades into the sky, no grey strip)"),
])
emit("sea_horizon", "SeaHorizonStyle", "sea_horizon_style", [
    ("blended", "Blended sea horizon", "Distant sea fades smoothly into the haze - no grey band.", {"name_fa": "افق دریای یکدست"}),
    ("classic", "Classic horizon", "The old grey ground band under the horizon.", {"name_fa": "افق قدیمی", "blend": 0.0, "fog_match": 0.0}),
], "blended")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v6b modules written")


# ---------------------------------------------------------------- ui_text (v6b polish)
# Persian for the controls screen (categories, rows, headers, notes) and the
# F1 tip line. Patched into the existing ui_text modules' phrase tables.
V6B_PHRASES = {
    "Controls": "کلیدها", "Close (Esc)": "بستن (Esc)",
    "Action": "کار", "Keyboard / mouse": "صفحه‌کلید / موس", "Gamepad": "دسته‌ی بازی",
    "Movement": "حرکت", "Camera": "دوربین", "Interaction & Tools": "تعامل و ابزار", "Time & World": "زمان و جهان",
    "Voice": "صدا", "Online (beta)": "آنلاین (آزمایشی)", "System": "سیستم", "Character & Car": "شخصیت و ماشین", "Other": "سایر",
    "Walk forward": "راه رفتن به جلو", "Walk back": "راه رفتن به عقب", "Walk left": "راه رفتن به چپ", "Walk right": "راه رفتن به راست",
    "Sprint (uses stamina)": "دویدن (انرژی مصرف می‌کند)", "Jump": "پریدن", "Sit on the ground / stand up": "نشستن روی زمین / بلند شدن",
    "Orbit (hold + drag)": "چرخاندن دوربین (نگه دار و بکش)", "Orbit left": "چرخش به چپ", "Orbit right": "چرخش به راست",
    "Tilt up": "بالا بردن نگاه", "Tilt down": "پایین آوردن نگاه", "Zoom in": "نزدیک‌نمایی", "Zoom out": "دورنمایی",
    "Reset behind farmer": "دوربین پشت کشاورز",
    "Interact: farm, talk, doors, sit on benches, TV, fish at water": "تعامل: کشاورزی، گفتگو، درها، نشستن روی نیمکت، تلویزیون، ماهیگیری",
    "Pick up / place carryable": "برداشتن / گذاشتن چیزهای قابل حمل", "Choose seed": "انتخاب بذر", "Inventory (bag)": "کوله‌پشتی",
    "Town directory (people, families, jobs)": "راهنمای شهر (مردم، خانواده‌ها، شغل‌ها)",
    "Market prices board (price trends, town economy)": "تابلوی قیمت بازار (روند قیمت‌ها، اقتصاد شهر)",
    "Pause / resume clock": "توقف / ادامه‌ی ساعت", "Slower clock": "ساعت کندتر", "Faster clock": "ساعت تندتر",
    "Day/night cycle on/off": "روشن / خاموش کردن چرخه‌ی شب و روز", "Jump to next season": "رفتن به فصل بعد", "Minimap on/off": "نقشه‌ی کوچک روشن / خاموش",
    "Push to talk (hold)": "فشار برای صحبت (نگه دار)", "Voice status & mute list": "وضعیت صدا و فهرست بی‌صدا",
    "Online panel: connect / go offline, players, module updates": "پنل آنلاین: اتصال / آفلاین، بازیکنان، به‌روزرسانی ماژول‌ها",
    "Chat (type, Enter to send)": "گفتگو (بنویس، Enter برای فرستادن)",
    "Settings menu / close panels": "منوی تنظیمات / بستن پنل‌ها", "Settings": "تنظیمات", "This controls screen": "همین صفحه‌ی کلیدها",
    "Save": "ذخیره", "Load": "بارگذاری", "Sound on/off": "صدا روشن / خاموش", "Shadow quality": "کیفیت سایه",
    "Contextual prompts on/off": "راهنمای کنار کارها روشن / خاموش", "Quit (desktop)": "خروج (نسخه‌ی دسکتاپ)",
    "Character creator (look, name, job)": "ساخت شخصیت (چهره، نام، شغل)", "Car horn (while driving)": "بوق ماشین (هنگام رانندگی)",
    "Dig a hole / fill it in (on foot)": "کندن چاله / پر کردن آن (پیاده)",
    "Tip: press F1 (or ?) to see all controls": "نکته: برای دیدن همه‌ی کلیدها F1 (یا ?) را بزن",
    "Fishing: stand at the beach, pier or pond with a fishing rod and press Interact; press it again when the bobber dips (\"!\").\nCarrying: E or F picks up crates, buckets, pumpkins...; the blue ghost shows where it will be placed.\nCrafting: buy planks / iron / stone / wire in town, craft at the farm Workshop bench; cook meals at any home stove.":
        "ماهیگیری: با چوب ماهیگیری کنار ساحل، اسکله یا برکه بایست و کلید تعامل را بزن؛ وقتی چوب‌پنبه پایین رفت (\"!\") دوباره بزن.\nحمل: E یا F جعبه، سطل، کدو و... را برمی‌دارد؛ سایه‌ی آبی جای گذاشتن را نشان می‌دهد.\nساختن: تخته، آهن، سنگ و سیم را از شهر بخر و در کارگاه مزرعه بساز؛ در هر آشپزخانه‌ای غذا بپز.",
    "Stamina drains while sprinting and jumping. At 0 you're exhausted (slow walk) until it recovers - rest by sitting (X or a bench).":
        "دویدن و پریدن انرژی می‌برد. با انرژی صفر خسته می‌شوی (آهسته راه می‌روی) تا دوباره جان بگیری - بنشین و استراحت کن (X یا نیمکت).",
    "Lights switch on at sunset. The main power switch is on the farmhouse wall (and on the pole at the town entrance): cut it and homes use candles, lanterns and the fireplace.":
        "چراغ‌ها با غروب روشن می‌شوند. کلید اصلی برق روی دیوار خانه‌ی مزرعه (و تیر ورودی شهر) است: اگر قطعش کنی، خانه‌ها با شمع، فانوس و شومینه روشن می‌مانند.",
    "Single player and offline by default. Press U, enter a server address (wss://...) and Connect to play together. If the server drops, you keep playing and your save syncs when it is back.":
        "بازی به‌طور پیش‌فرض تک‌نفره و آفلاین است. برای بازی گروهی U را بزن، نشانی سرور (wss://...) را وارد کن و وصل شو. اگر سرور قطع شود بازی ادامه دارد و ذخیره بعداً همگام می‌شود.",
    "Voice chat is client-only for now: no server is configured yet (see docs/VOICE_SETUP.md).":
        "گفتگوی صوتی فعلاً فقط سمت بازیکن است: هنوز سروری تنظیم نشده (docs/VOICE_SETUP.md را ببین).",
    "Cars: walk to a parked car's driver door and press E. W/S drive, A/D steer, Space handbrake, E get out. Change clothes at the farmhouse wardrobe; the mirror next to it opens the character creator.":
        "ماشین: کنار در راننده‌ی یک ماشین پارک‌شده برو و E بزن. W/S حرکت، A/D فرمان، فاصله ترمزدستی، E پیاده شدن. لباس‌ها را در کمد خانه‌ی مزرعه عوض کن؛ آینه‌ی کنارش ساخت شخصیت را باز می‌کند.",
}


def patch_ui_text():
    import json, re
    for fn in ("farsi.tres", "farsi_short.tres"):
        path = os.path.join(ROOT, "modules", "ui_text", fn)
        src = open(path, encoding="utf-8").read()
        m = re.search(r"^phrases = (\{.*\})$", src, re.M)
        cur = json.loads(m.group(1))
        cur.update(V6B_PHRASES)
        line = "phrases = " + json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
        src = src[:m.start()] + line + src[m.end():]
        open(path, "w", encoding="utf-8").write(src)
    print("ui_text: +%d v6b phrases" % len(V6B_PHRASES))


patch_ui_text()
