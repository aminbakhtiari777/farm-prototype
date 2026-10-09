#!/usr/bin/env python3
"""Generates the v6a module .tres files and registers them in
data/asset_modules.json:
  night_sky, real_clock, dry_trees, fishing_gear, campfire, deep_sea, boats,
  sunbathing, gym, house_music, kitchenware (collection), hypermarket, ui_text
  + new members of existing collections / types: sky/glass_blue (active),
  tool_types/axe + steel_axe, dishes/sabzi_polo_mahi + banana_smoothie,
  producers/carpenter_logs.
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v5a.py"), encoding="utf-8").read()
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v5a.py")}
exec(src.split("config_path =")[0], ns)
write_tres, psa, _val = ns["write_tres"], ns["psa"], ns["val"]


def val(v):
    if isinstance(v, str) and (v.startswith("V2(") or v.startswith("V3(")):
        return ("Vector2" if v.startswith("V2") else "Vector3") + v[2:]
    if isinstance(v, dict) and not v.get("__psa") and not v.get("__pia"):
        return "{" + ", ".join("%s: %s" % (json.dumps(k, ensure_ascii=False), val(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "[" + ", ".join(val(x) for x in v) + "]"
    return _val(v)


ns["val"] = val
config_path = os.path.join(ROOT, "data/asset_modules.json")
config = json.load(open(config_path, encoding="utf-8"))


def emit(type_, cls, script_name, variants, active, collection=False, keep_existing=False):
    script = "res://modules/%s/%s.gd" % (type_, script_name)
    reg = dict(config.get(type_, {}).get("variants", {})) if keep_existing else {}
    for vid, name, desc, fields in variants:
        path = "res://modules/%s/%s.tres" % (type_, vid)
        f = {"id": vid, "type": type_, "display_name": name, "description": desc}
        f.update(fields)
        write_tres(path, cls, script, f)
        reg[vid] = path
    entry = {"active": active, "variants": reg}
    if collection:
        entry = {"collection": True, "active": active, "variants": reg}
    config[type_] = entry


ALL_WEATHER = ["sunny", "cloudy", "rain", "storm", "heatwave", "snow"]
ALL_SEASONS = ["spring", "summer", "autumn", "winter"]

# ------------------------------------------------------------------ 1. sky + night sky + real clock
emit("sky", "SkyStyle", "sky_style", [
    ("glass_blue", "Glass-clear blue", "v6a: clear, bright, glassy blue day sky; fewer clouds on fine days.",
     {"day_zenith": (0.1, 0.36, 0.86), "day_horizon": (0.6, 0.8, 0.98), "dusk_zenith": (0.2, 0.25, 0.52),
      "dusk_horizon": (0.98, 0.56, 0.3), "night_zenith": (0.006, 0.012, 0.045), "night_horizon": (0.035, 0.06, 0.13),
      "cloud_mult": 0.55, "clarity": 1.0}),
], "glass_blue", keep_existing=True)
emit("night_sky", "NightSkyStyle", "night_sky_style", [
    ("starry", "Starry countryside", "Dense stars, the Milky Way and a bright moon with phases (8-day cycle in game time).",
     {"name_fa": "آسمان پرستاره‌ی روستا"}),
    ("town_glow", "Town glow", "Fewer, dimmer stars (light pollution), no Milky Way, a bigger moon.",
     {"name_fa": "آسمان شهری", "star_density": 0.008, "star_brightness": 1.1, "milky_way": 0.0, "moon_size": 0.055}),
], "starry")
emit("real_clock", "RealClockStyle", "real_clock_style", [
    ("optional", "Real clock (optional)", "Game time follows the device clock when switched on in Settings; the moon shows the real phase.",
     {"name_fa": "ساعت واقعی (اختیاری)"}),
    ("always", "Real clock (always)", "Game time always follows the device clock.", {"name_fa": "همیشه ساعت واقعی", "mode": "always"}),
], "optional")

# ------------------------------------------------------------------ 2. dry trees + axe + carpenter logs
WOOD_ITEMS = {
    "firewood": {"name": "Firewood", "name_fa": "هیزم", "type": "produce", "category": "wood", "sell": 12,
                 "description": "Split dry wood. Lights the beach campfire."},
    "dry_wood": {"name": "Dry Wood", "name_fa": "چوب خشک", "type": "produce", "category": "wood", "sell": 18,
                 "description": "Seasoned logs. The carpenter saws them into boards."},
}
emit("dry_trees", "DryTreeStyle", "dry_tree_style", [
    ("forest_edge", "Dry trees at the forest edge", "14 dead trees along the west and north forest edges; 3 regrow every morning.",
     {"name_fa": "درختان خشک لب جنگل", "items": WOOD_ITEMS}),
    ("sparse", "A few dry trees", "8 dead trees, tougher (4 hits), 2 regrow a day.",
     {"name_fa": "چند درخت خشک", "count": 8, "hits": 4, "regrow_per_day": 2, "items": WOOD_ITEMS}),
], "forest_edge")
emit("tool_types", "ToolDef", "tool_def", [
    ("axe", "Axe", "Fells dry trees (3 hits).", {"item_id": "axe", "kind": "axe", "tier": 1, "anim": "swing", "sound": "chop",
     "shape": "axe", "head_color": (0.55, 0.56, 0.6), "handle_color": (0.5, 0.34, 0.2), "buy": 0, "starter": True,
     "unlock_day": 1, "requires": "", "reach": 1, "anim_seconds": 0.7}),
    ("steel_axe", "Steel Axe", "Sharper: one hit less per tree.", {"item_id": "steel_axe", "kind": "axe", "tier": 2, "anim": "swing",
     "sound": "chop", "shape": "axe", "head_color": (0.78, 0.8, 0.84), "handle_color": (0.35, 0.22, 0.14), "buy": 450,
     "starter": False, "unlock_day": 1, "requires": "", "reach": 2, "anim_seconds": 0.6}),
], "hoe", collection=True, keep_existing=True)
emit("producers", "ProducerDef", "producer_def", [
    ("carpenter_logs", "Carpenter: logs to boards", "Saws the dry wood people sell into boards (2 logs -> 4 boards).",
     {"name_fa": "نجاری: چوب به تخته", "shop": "carpenter", "worker_jobs": psa("Carpenter"), "outputs": {"wood_plank": 4},
      "inputs": {"dry_wood": 2}, "items": {}, "sort_order": 1}),
], "carpenter_boards", collection=True, keep_existing=True)

# ------------------------------------------------------------------ 3. beach: rods, campfire, fish dishes
emit("fishing_gear", "FishingGearStyle", "fishing_gear_style", [
    ("carpenter_rods", "Rods at the carpenter", "The carpenter carves fishing rods: basic rod and a pro rod (faster bites, more rare fish).",
     {"name_fa": "چوب ماهیگیری از نجاری", "items": {"pro_rod": {"name": "Pro Fishing Rod", "name_fa": "چوب ماهیگیری حرفه‌ای",
      "type": "tool", "buy": 700, "description": "Bites come faster and rare fish bite more often."}}}),
    ("tool_shop_rods", "Rods at the tool shop", "Rods sold at the tool shop and the carpenter.",
     {"name_fa": "چوب ماهیگیری از ابزارفروشی", "sold_at": psa("carpenter", "tool_shop"), "items": {"pro_rod": {"name": "Pro Fishing Rod",
      "name_fa": "چوب ماهیگیری حرفه‌ای", "type": "tool", "buy": 650, "description": "Bites come faster and rare fish bite more often."}}}),
], "carpenter_rods")
emit("campfire", "CampfireStyle", "campfire_style", [
    ("beach_fire", "Beach campfire", "A stone ring on the sand: 2 firewood burn for 3 hours; 4 log seats; grill a fish.",
     {"name_fa": "آتش ساحلی"}),
    ("big_bonfire", "Big bonfire", "Takes 4 firewood, burns 6 hours, 6 seats, brighter.",
     {"name_fa": "آتش بزرگ", "firewood_cost": 4, "burn_hours": 6.0, "seats": 6, "light_energy": 4.5}),
], "beach_fire")
emit("dishes", "DishDef", "dish_def", [
    ("sabzi_polo_mahi", "Sabzi Polo ba Mahi", "Herbed rice with fish - the Nowruz classic.",
     {"name_fa": "سبزی‌پلو با ماهی", "inputs": {"category:fish": 1, "rice": 1, "herbs": 1}, "salt": 1, "spices": 1,
      "hunger": 90, "stamina": 65, "raw_color": (0.75, 0.82, 0.6), "cooked_color": (0.55, 0.7, 0.35), "sort_order": 3}),
    ("banana_smoothie", "Banana Milk (Shir Moz)", "Banana blended with cold milk - needs a blender.",
     {"name_fa": "شیر موز", "inputs": {"banana_fruit": 1, "milk": 1}, "salt": 0, "spices": 0, "requires": "blender",
      "hunger": 35, "stamina": 35, "raw_color": (0.98, 0.95, 0.75), "cooked_color": (0.97, 0.9, 0.65), "sort_order": 4}),
], "omelette", collection=True, keep_existing=True)

# ------------------------------------------------------------------ 4. boats, deep sea, sunbathing
def F(name, fa, sell, seasons, hours, weight, weather=ALL_WEATHER):
    return {"name": name, "name_fa": fa, "type": "produce", "category": "fish", "sell": sell,
            "fish": {"seasons": seasons, "water": "deep", "hours": hours, "weather": weather, "weight": weight, "rare": weight < 0.3}}
GULF = {
    "hamour": F("Hamour (Grouper)", "هامور", 320, ALL_SEASONS, [5, 21], 1.0),
    "king_mackerel": F("King Mackerel", "شیرماهی", 380, ["spring", "summer", "autumn"], [5, 19], 0.8),
    "black_pomfret": F("Black Pomfret", "حلوا سیاه", 300, ALL_SEASONS, [0, 24], 0.9),
    "silver_pomfret": F("Silver Pomfret", "حلوا سفید", 460, ["autumn", "winter"], [6, 18], 0.35),
    "lobster": F("Lobster", "لابستر", 540, ALL_SEASONS, [18, 24], 0.3),
    "swordfish": F("Swordfish", "شمشیرماهی", 680, ["summer", "autumn"], [5, 13], 0.15),
    "sailfish": F("Sailfish", "بادبان‌ماهی", 950, ["summer"], [6, 12], 0.08, ["sunny", "heatwave"]),
}
emit("deep_sea", "DeepSeaStyle", "deep_sea_style", [
    ("persian_gulf", "Persian Gulf deep water", "Hamour, king mackerel, pomfret, lobster, swordfish and the rare sailfish (20-90 x the price of a sardine).",
     {"name_fa": "آب‌های عمیق خلیج فارس", "fish": GULF}),
    ("calm_deep", "Calm deep water", "Deep water starts farther out (30 m); same fish.", {"name_fa": "آب عمیق آرام", "deep_distance": 30.0, "fish": GULF}),
], "persian_gulf")
emit("boats", "BoatStyle", "boat_style", [
    ("fishing_boats", "Fishing boats (lenj)", "Three motor boats moored at the pier; 20 G fuel per trip; 6 s to the fishing grounds.",
     {"name_fa": "قایق‌های صیادی"}),
    ("rowboats", "Rowboats", "Two open rowboats, free, slower (10 s).",
     {"name_fa": "قایق پارویی", "count": 2, "cabin": False, "sail_seconds": 10.0, "fuel_fee": 0,
      "hull_colors": [(0.3, 0.5, 0.35), (0.6, 0.4, 0.25)]}),
], "fishing_boats")
emit("sunbathing", "SunbathingStyle", "sunbathing_style", [
    ("sun_beach", "Sunbathing beach", "Six towels under striped umbrellas on the north-east sand; townspeople come on fine days 10:00-17:00.",
     {"name_fa": "ساحل آفتاب‌گیری"}),
    ("quiet_cove", "Quiet cove", "Four towels, fewer visitors.", {"name_fa": "ساحل خلوت", "towels": 4, "npc_every": 9}),
], "sun_beach")

# ------------------------------------------------------------------ 5. gym + house music
EQUIP = [
    {"id": "treadmill", "en": "run on the treadmill", "fa": "دویدن روی تردمیل", "pose": "jog", "minutes": 30, "stamina": 14, "fitness": 6.0, "pos": "V2(-0.62, -0.35)", "yaw": 0.0},
    {"id": "treadmill2", "en": "run on the treadmill", "fa": "دویدن روی تردمیل", "pose": "jog", "minutes": 30, "stamina": 14, "fitness": 6.0, "pos": "V2(-0.62, 0.15)", "yaw": 0.0},
    {"id": "dumbbells", "en": "lift dumbbells", "fa": "وزنه زدن با دمبل", "pose": "lift", "minutes": 20, "stamina": 10, "fitness": 5.0, "pos": "V2(0.62, -0.4)", "yaw": -90.0},
    {"id": "bench_press", "en": "do bench presses", "fa": "پرس سینه", "pose": "lie", "minutes": 20, "stamina": 12, "fitness": 5.5, "pos": "V2(0.55, 0.2)", "yaw": -90.0},
    {"id": "bike", "en": "ride the exercise bike", "fa": "رکاب زدن دوچرخه‌ی ثابت", "pose": "sit", "minutes": 25, "stamina": 9, "fitness": 4.5, "pos": "V2(-0.1, -0.55)", "yaw": 0.0},
    {"id": "mat", "en": "stretch on the mat", "fa": "حرکات کششی روی تشک", "pose": "ground_sit", "minutes": 15, "stamina": 3, "fitness": 2.5, "pos": "V2(0.05, 0.3)", "yaw": 180.0},
]
emit("gym", "GymStyle", "gym_style", [
    ("town_gym", "Town gym (Bashgah)", "Treadmills, dumbbells, bench press, exercise bike and mats; 10 G a session; upbeat music.",
     {"name_fa": "باشگاه ورزشی شهر", "equipment": EQUIP}),
    ("zurkhaneh_mix", "Gym + zurkhaneh beat", "Same equipment, free entry, a drum-heavy zurkhaneh-style beat.",
     {"name_fa": "باشگاه با ضرب زورخانه", "equipment": EQUIP, "fee": 0, "music": "res://assets/audio/music/zarb_loop.ogg", "accent": (0.75, 0.2, 0.2)}),
], "town_gym")
emit("house_music", "HouseMusicStyle", "house_music_style", [
    ("radios", "Radios in some homes", "The cafe, two homes and the gym play music, heard faintly (muffled) outside.",
     {"name_fa": "رادیو در خانه‌ها", "sources": {"cafe": "res://assets/audio/music/radio_loop.ogg",
      "maple4": "res://assets/audio/music/radio_loop.ogg", "harbor2": "res://assets/audio/music/zarb_loop.ogg",
      "gym": "res://assets/audio/music/gym_loop.ogg"}}),
    ("quiet_town", "Quiet town", "Only the gym plays music.", {"name_fa": "شهر آرام", "sources": {"gym": "res://assets/audio/music/gym_loop.ogg"}}),
], "radios")

# ------------------------------------------------------------------ 6. kitchenware + hypermarket
def K(vid, name, fa, price, slot, shape, color, tier=1, requires="", speed=None, bonus=0.0, unlocks=(), power=False, order=0):
    return (vid, name, "", {"name_fa": fa, "item_id": vid, "price": price, "slot": slot, "tier": tier, "requires": requires,
            "speed": speed or {}, "meal_bonus": bonus, "unlocks": psa(*unlocks), "needs_power": power, "color": color,
            "shape": shape, "sort_order": order})
KW = [
    K("plates_basic", "Plates", "بشقاب", 40, "plates", "plate", (0.95, 0.95, 0.93), bonus=3.0, order=0),
    K("plates_porcelain", "Porcelain Plates", "بشقاب چینی", 140, "plates", "plate", (0.92, 0.95, 1.0), tier=2, requires="plates_basic", bonus=8.0, order=1),
    K("pot_steel", "Steel Pot", "قابلمه‌ی استیل", 90, "pot", "pot", (0.75, 0.77, 0.8), speed={"cook": 0.8}, order=2),
    K("pan_nonstick", "Non-stick Pan", "ماهیتابه‌ی نچسب", 70, "pan", "pan", (0.18, 0.18, 0.2), speed={"cook": 0.85}, order=3),
    K("pan_cast_iron", "Cast-iron Pan", "تابه‌ی چدنی", 170, "pan", "pan", (0.1, 0.1, 0.1), tier=2, requires="pan_nonstick", speed={"cook": 0.7}, bonus=2.0, order=4),
    K("cutlery", "Forks & Spoons", "قاشق و چنگال", 35, "cutlery", "fork", (0.85, 0.86, 0.9), speed={"eat": 0.7}, bonus=2.0, order=5),
    K("glasses", "Glasses", "لیوان", 30, "glasses", "glass", (0.8, 0.92, 1.0), bonus=2.0, order=6),
    K("blender", "Blender", "مخلوط‌کن", 220, "blender", "blender", (0.85, 0.2, 0.2), speed={"prepare": 0.6}, unlocks=("banana_smoothie",), power=True, order=7),
    K("microwave", "Microwave", "مایکروویو", 360, "microwave", "microwave", (0.9, 0.9, 0.9), speed={"cook": 0.5}, power=True, order=8),
]
emit("kitchenware", "KitchenwareDef", "kitchenware_def", [(v, n, d or "Kitchenware: " + n, f) for v, n, d, f in KW], "plates_basic", collection=True)
emit("hypermarket", "HypermarketStyle", "hypermarket_style", [
    ("hyper_blue", "Hypermarket (blue)", "Kitchenware aisles + groceries; buys fish and produce.", {"name_fa": "هایپرمارکت آبی"}),
    ("hyper_green", "Hypermarket (green)", "Same shop, green branding.", {"name_fa": "هایپرمارکت سبز", "sign_color": (0.15, 0.55, 0.3)}),
], "hyper_blue")

# ------------------------------------------------------------------ 7. UI text
PHRASES = {
    "open the door": "باز کردن در", "close the door": "بستن در",
    "turn on the TV": "روشن کردن تلویزیون", "turn off the TV": "خاموش کردن تلویزیون",
    "have a snack from the fridge": "خوردن میان‌وعده از یخچال", "sleep until morning": "خوابیدن تا صبح",
    "rest on the bed": "استراحت روی تخت", "take tools (refill can / fishing rod)": "برداشتن ابزار (آبپاش / چوب ماهیگیری)",
    "build a wooden crate": "ساختن جعبه‌ی چوبی", "shop at the counter": "خرید از پیشخوان",
    "buy a coffee (10 G, +stamina)": "خریدن قهوه (۱۰ سکه، +انرژی)", "ask for a check-up (restores stamina)": "معاینه (انرژی برمی‌گردد)",
    "post a letter": "پست کردن نامه", "talk to the clerk": "صحبت با کارمند", "craft at the workbench": "ساختن با میز کار",
    "cook on the stove": "آشپزی روی اجاق", "ask the Water Office (refill your can)": "پرسیدن از اداره‌ی آب (پر کردن آبپاش)",
    "ask about the power grid": "پرسیدن درباره‌ی شبکه‌ی برق", "talk to the teacher": "صحبت با معلم",
    "listen to the lecture": "گوش دادن به درس", "look up the town directory": "دیدن فهرست اهالی شهر",
    "sit quietly for a moment": "لحظه‌ای آرام نشستن", "see the doctor (check-up)": "رفتن پیش دکتر (معاینه)",
    "fish": "ماهیگیری", "fill the watering can": "پر کردن آبپاش", "refill the watering can": "پر کردن آبپاش",
    "collect wool": "چیدن پشم", "till the soil": "شخم زدن خاک", "shop at the market": "خرید از بازار",
    "cut the power (main switch)": "قطع برق (کلید اصلی)", "restore the power (main switch)": "وصل برق (کلید اصلی)", "use": "استفاده",
    # top bar
    "Bag": "کیف", "Save": "ذخیره", "Connect": "آنلاین", "Logout": "خروج", "Inventory (I)": "کوله‌پشتی (I)",
    "Save the game (F5)": "ذخیره‌ی بازی (F5)", "Multiplayer": "چندنفره", "Back to the title screen": "بازگشت به صفحه‌ی اول",
    "Settings & menu (Esc / O)": "تنظیمات و منو (Esc / O)", "Game saved": "بازی ذخیره شد", "Save failed: ": "ذخیره نشد: ",
    "Game loaded": "بازی بارگذاری شد", "Multiplayer coming soon!": "بازی چندنفره به‌زودی! (پنل آنلاین: U)",
    "Spring": "بهار", "Summer": "تابستان", "Autumn": "پاییز", "Winter": "زمستان",
    # settings
    "Settings": "تنظیمات", "Game": "بازی", "Pause clock (P)": "توقف ساعت (P)", "Resume clock (P)": "ادامه‌ی ساعت (P)",
    "Slower ([)": "کندتر ([)", "Faster (])": "تندتر (])", "Day/Night": "شب و روز", "On": "روشن", "Off": "خاموش",
    "Season:": "فصل:", "(K = next)": "(K = فصل بعد)", "Dialogue:": "زبان:", "Voices": "صداها", "Audio & video": "صدا و تصویر",
    "Volume": "بلندی صدا", "Sound": "صدا", "Adhan": "اذان", "Bells": "ناقوس", "Shadows": "سایه‌ها", "High": "زیاد", "Low": "کم",
    "Prompts": "راهنما", "Town styles": "سبک شهر", "Houses": "خانه‌ها", "Mixed": "ترکیبی", "Yards": "حیاط‌ها",
    "Game data": "ذخیره‌ها", "Save (F5)": "ذخیره (F5)", "Load (F9)": "بارگذاری (F9)", "Save slot": "جای ذخیره",
    "browser storage": "حافظه‌ی مرورگر", "exists": "دارد", "empty": "خالی", "Controls (F1)": "کلیدها (F1)",
    "Voice / mute list (L)": "صدا / فهرست بی‌صدا (L)", "Quit game": "خروج از بازی", "Close": "بستن",
    "Real clock": "ساعت واقعی", "Sky": "آسمان", "Sound off": "صدا قطع شد", "Sound on": "صدا وصل شد",
    "Prompts on": "راهنما روشن شد", "Prompts off": "راهنما خاموش شد",
    # fishing
    "You stop fishing": "ماهیگیری را تمام کردی", "Too early - nothing on the hook": "زود کشیدی - چیزی به قلاب نیست",
    "It got away...": "ماهی در رفت...", "!  Press E now!": "!  الان E را بزن!",
    # v6a places + interior messages
    "lie down on the towel": "دراز کشیدن روی حوله",
    "A crisp apple from the fridge. +25 stamina": "یک سیب ترد از یخچال. +۲۵ انرژی",
    "You rest for a moment. +40 stamina": "کمی استراحت کردی. +۴۰ انرژی",
    "Fresh coffee! +50 stamina": "قهوه‌ی تازه! +۵۰ انرژی",
    "\"You look healthy!\" Stamina fully restored": "«سالم به نظر می‌رسی!» انرژی کامل شد",
    "A quiet, peaceful moment. +20 stamina": "لحظه‌ای آرام و دل‌نشین. +۲۰ انرژی",
    "Game time follows your computer's clock; the moon shows its real phase": "زمان بازی با ساعت کامپیوترت جلو می‌رود؛ ماه هم هلال واقعی‌اش را نشان می‌دهد",
    "Townspeople speak Persian (فارسی) or English": "اهالی فارسی یا انگلیسی حرف بزنند",
    "Pitch-varied voice blips when townspeople talk": "صدای کوتاه هنگام حرف زدن اهالی",
    "Contextual 'Press E to ...' prompts": "راهنمای «E را بزن برای ...»",
    "Rebuild every home in another house style": "ساختن دوباره‌ی خانه‌ها با سبکی دیگر",
    "Swap the front-yard fences": "عوض کردن نرده‌ی حیاط‌ها", "0 = off": "۰ = خاموش",
}
PHRASES.update({'Blacksmith': 'آهنگری', 'Cafe': 'کافه', 'Carpenter': 'نجاری', 'Church': 'کلیسا', 'Clothing': 'پوشاک', 'Electrical Supplies': 'لوازم برقی', 'Electricity Office': 'اداره\u200cی برق', 'Fruit Shop': 'میوه\u200cفروشی', 'General Store': 'بقالی', 'Gym': 'باشگاه ورزشی', 'Hospital': 'بیمارستان', 'Hypermarket': 'هایپرمارکت', 'Jeweller': 'جواهرفروشی', 'Mosque': 'مسجد', 'Municipality - City Hall': 'شهرداری', 'Police Station': 'کلانتری', 'Post Office': 'اداره\u200cی پست', 'School': 'مدرسه', 'Stonemason': 'سنگ\u200cتراشی', 'Supermarket': 'سوپرمارکت', 'Tool Shop': 'ابزارفروشی', 'University': 'دانشگاه', 'Water Office': 'اداره\u200cی آب', 'Workshop': 'کارگاه', 'Your Farmhouse': 'خانه\u200cی مزرعه\u200cی تو', 'House': 'خانه', 'Wooden post-and-rail fences': 'نرده‌ی چوبی', 'White picket fences': 'نرده‌ی سفید'})  # v6a: building names for the HUD location line
PREFIXES = {"sit on the ": "نشستن روی {x}", "pick up the ": "برداشتن {x}", "greet ": "سلام کردن به {x}", "pet the ": "نوازش کردن {x}",
            "trade at the ": "خرید و فروش در {x}", "shop at the ": "خرید از {x}"}
WORDS = {"bench": "نیمکت", "chair": "صندلی", "sofa": "مبل", "armchair": "مبل راحتی", "stool": "چهارپایه", "seat": "صندلی",
         "crate": "جعبه", "bucket": "سطل", "pumpkin": "کدو حلوایی", "log seat": "کنده‌ی نشیمن", "pew": "نیمکت کلیسا",
         "seashell": "صدف", "scallop shell": "صدف شانه‌ای", "conch": "حلزون دریایی", "wooden crate": "جعبه‌ی چوبی",
         "sunbed": "حوله‌ی ساحلی", "towel": "حوله", "desk chair": "صندلی میز", "dining chair": "صندلی ناهارخوری",
         "log": "کنده‌ی درخت", "boat bench": "نیمکت قایق", "gym": "دستگاه باشگاه", "hypermarket": "هایپرمارکت"}
emit("ui_text", "UiTextStyle", "ui_text_style", [
    ("farsi", "Persian UI text", "Persian wording for prompts, the top bar, Settings and fishing.",
     {"name_fa": "متن فارسی", "phrases": PHRASES, "prefixes": PREFIXES, "words": WORDS}),
    ("farsi_short", "Persian UI text (short)", "Same table; top-bar buttons shortened.",
     {"name_fa": "متن فارسی کوتاه", "phrases": dict(PHRASES, **{"Connect": "شبکه", "Logout": "خروج"}), "prefixes": PREFIXES, "words": WORDS}),
], "farsi")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v6a modules written")
