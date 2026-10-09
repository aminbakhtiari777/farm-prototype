#!/usr/bin/env python3
"""Generates the v5c module .tres files and registers them in
data/asset_modules.json:
  market_economy, producers (collection), wages, price_board,
  livestock (collection), animal_housing (collection)
Re-run after editing the tables below."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v5a.py"), encoding="utf-8").read()
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v5a.py")}
exec(src.split("config_path =")[0], ns)
write_tres, psa, pia, _val = ns["write_tres"], ns["psa"], ns["pia"], ns["val"]


def val(v):
    """v5a writer + vector literals: "V2(x, y)" / "V3(x, y, z)" strings."""
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


def register(type_, active, variants, collection=False):
    entry = {"active": active, "variants": variants}
    if collection:
        entry = {"collection": True, "active": active, "variants": variants}
    config[type_] = entry


def emit(type_, cls, script_name, variants, active, collection=False):
    script = "res://modules/%s/%s.gd" % (type_, script_name)
    reg = {}
    for vid, name, desc, fields in variants:
        path = "res://modules/%s/%s.tres" % (type_, vid)
        f = {"id": vid, "type": type_, "display_name": name, "description": desc}
        f.update(fields)
        write_tres(path, cls, script, f)
        reg[vid] = path
    register(type_, active, reg, collection)


def F(v):
    return float(v)


# ------------------------------------------------------------------ market_economy
NAMES_FA = {
    "turnip": "شلغم", "carrot": "هویج", "potato": "سیب‌زمینی", "strawberry": "توت‌فرنگی", "tomato": "گوجه‌فرنگی", "corn": "ذرت",
    "sunflower": "آفتابگردان", "pumpkin": "کدو حلوایی", "eggplant": "بادمجان", "apple": "سیب", "banana_fruit": "موز",
    "wool": "پشم", "yarn": "نخ پشمی", "sardine": "ساردین", "mackerel": "ماهی خال‌مخالی", "sea_bass": "ماهی سی‌باس", "tuna": "تن",
    "red_snapper": "سرخو", "cod": "ماهی کاد", "squid": "ماهی مرکب", "carp": "کپور", "catfish": "گربه‌ماهی", "trout": "قزل‌آلا",
    "perch": "سوف", "seashell": "صدف", "scallop_shell": "صدف شانه‌ای", "conch": "حلزون دریایی", "wood_plank": "تخته چوبی",
    "iron_nails": "میخ آهنی", "iron_bar": "شمش آهن", "stone_block": "سنگ ساختمانی", "copper_wire": "سیم مسی", "light_bulb": "لامپ",
    "bread_loaf": "نان", "silver_ring": "انگشتر نقره", "gold_necklace": "گردنبند طلا", "birdhouse": "خانه پرنده", "planter_box": "گلدان چوبی",
    "iron_lantern": "فانوس آهنی", "stone_planter": "گلدان سنگی", "jam": "مربا", "fruit_basket": "سبد میوه", "fertilizer": "کود",
    "fishing_rod": "چوب ماهیگیری", "shirt_red": "پیراهن قرمز", "shirt_green": "پیراهن سبز", "shirt_blue": "پیراهن آبی",
    "shirt_yellow": "پیراهن زرد", "overalls_denim": "شلوار جین", "apple_sapling": "نهال سیب", "banana_sucker": "پاجوش موز",
    "turnip_seeds": "بذر شلغم", "carrot_seeds": "بذر هویج", "potato_seeds": "بذر سیب‌زمینی", "strawberry_seeds": "بذر توت‌فرنگی",
    "tomato_seeds": "بذر گوجه", "corn_seeds": "بذر ذرت", "sunflower_seeds": "بذر آفتابگردان", "pumpkin_seeds": "بذر کدو",
    "eggplant_seeds": "بذر بادمجان",
}
EXPORTS = {"wood_plank": 4.0, "iron_nails": 2.0, "iron_bar": 1.0, "wool": 2.0, "yarn": 1.0, "milk": 1.5, "eggs": 4.0, "apple": 2.0,
           "strawberry": 1.5, "banana_fruit": 1.0, "tomato": 2.0, "potato": 2.0, "sardine": 3.0, "mackerel": 1.0, "chicken": 1.0,
           "wooden_chair": 0.5, "wooden_table": 0.4, "hay": 3.0, "chicken_feed": 4.0, "rice": 2.0, "onion": 2.0, "tomato_fresh": 2.0,
           "herbs": 1.5, "bread_loaf": 4.0, "salt": 1.0, "spices": 1.0, "shears": 0.3, "milk_pail": 0.3}
BASKET = {"bread_loaf": F(3), "eggs": F(3), "rice": F(2), "chicken": F(1), "tomato_fresh": F(2), "onion": F(1), "milk": F(2),
          "apple": F(1), "sardine": F(1), "potato": F(1)}
emit("market_economy", "MarketEconomyStyle", "market_economy_style", [
    ("supply_demand", "Supply and demand", "Prices follow the town stock: sell a lot and prices fall, shortages push them up (x0.5 .. x2.5).",
     {"elasticity": 0.6, "min_mult": 0.5, "max_mult": 2.5, "recovery_per_day": 0.2, "default_target": 20, "buffer_days": 2.5,
      "retail_markup": 1.6, "sell_impact": 1.0, "history_days": 7, "shortage_below": 0.25, "npc_food_basket": BASKET,
      "npc_meal_units": 0.25, "exports": EXPORTS, "item_names_fa": NAMES_FA}),
    ("stable_prices", "Stable prices", "A calm market: prices move only a little (x0.85 .. x1.25) and recover fast.",
     {"elasticity": 0.15, "min_mult": 0.85, "max_mult": 1.25, "recovery_per_day": 0.6, "default_target": 20, "buffer_days": 3.0,
      "retail_markup": 1.5, "sell_impact": 0.5, "history_days": 7, "shortage_below": 0.15, "npc_food_basket": BASKET,
      "npc_meal_units": 0.25, "exports": EXPORTS, "item_names_fa": NAMES_FA}),
], "supply_demand")

# ------------------------------------------------------------------ producers (collection)
def item(name, fa, type_, buy=None, sell=None, desc="", **extra):
    d = {"name": name, "name_fa": fa, "type": type_, "description": desc}
    if buy is not None: d["buy"] = buy
    if sell is not None: d["sell"] = sell
    d.update(extra)
    return d

PRODUCERS = [
    ("carpenter_boards", "Carpenter: boards", "Saws logs from the forest into planks every morning.",
     {"name_fa": "نجاری: تخته", "shop": "carpenter", "worker_jobs": psa("Carpenter"), "outputs": {"wood_plank": 10}, "inputs": {}, "items": {}, "sort_order": 0}),
    ("carpenter_furniture", "Carpenter: furniture", "Turns planks into chairs and tables.",
     {"name_fa": "نجاری: مبلمان", "shop": "carpenter", "worker_jobs": psa("Carpenter"), "outputs": {"wooden_chair": 1, "wooden_table": 1},
      "inputs": {"wood_plank": 6}, "sort_order": 1,
      "items": {"wooden_chair": item("Wooden Chair", "صندلی چوبی", "furniture", buy=90, sell=55, desc="Hand-made by the carpenter."),
                "wooden_table": item("Wooden Table", "میز چوبی", "furniture", buy=220, sell=130, desc="A sturdy kitchen table.")}}),
    ("blacksmith_forge", "Blacksmith: forge", "Smelts iron bars.",
     {"name_fa": "آهنگری: کوره", "shop": "blacksmith", "worker_jobs": psa("Blacksmith"), "outputs": {"iron_bar": 3}, "inputs": {}, "items": {}, "sort_order": 2}),
    ("blacksmith_tools", "Blacksmith: tools", "Forges nails and farm tools (shears, milk pails) from iron bars.",
     {"name_fa": "آهنگری: ابزار", "shop": "blacksmith", "worker_jobs": psa("Blacksmith"), "outputs": {"iron_nails": 6, "shears": 1, "milk_pail": 1},
      "inputs": {"iron_bar": 2}, "sort_order": 3,
      "items": {"shears": item("Shears", "قیچی پشم‌چینی", "tool_item", buy=120, desc="Needed to shear sheep (blacksmith)."),
                "milk_pail": item("Milk Pail", "سطل شیر", "tool_item", buy=100, desc="Needed to milk cows (blacksmith).")}}),
    ("fruit_farms", "Orchards", "Town orchards deliver fresh fruit and vegetables to the fruit shop.",
     {"name_fa": "باغ‌ها", "shop": "fruit_shop", "worker_jobs": psa("Fruit seller"), "outputs": {"apple": 4, "strawberry": 3, "banana_fruit": 2, "tomato": 3, "potato": 3},
      "inputs": {}, "items": {}, "sort_order": 4}),
    ("poultry_farm", "Poultry farm", "Supplies the supermarket with chicken and eggs.",
     {"name_fa": "مرغداری", "shop": "grocery", "worker_jobs": psa("Supermarket cashier"), "outputs": {"chicken": 4, "eggs": 10}, "inputs": {}, "items": {}, "sort_order": 5}),
    ("dairy", "Dairy", "A small dairy - milk is often short, so farm milk sells well.",
     {"name_fa": "لبنیاتی", "shop": "grocery", "worker_jobs": psa("Supermarket cashier"), "outputs": {"milk": 3}, "inputs": {}, "items": {}, "sort_order": 6}),
    ("wholesaler", "Wholesaler", "Rice, onions, tomatoes, herbs, salt and spices for the supermarket.",
     {"name_fa": "عمده‌فروش", "shop": "grocery", "worker_jobs": psa("Supermarket cashier"),
      "outputs": {"rice": 8, "onion": 8, "tomato_fresh": 8, "herbs": 6, "salt": 10, "spices": 8}, "inputs": {}, "items": {}, "sort_order": 7}),
    ("bakery", "Bakery", "Fresh bread every morning for the bakery stall.",
     {"name_fa": "نانوایی", "shop": "stall:bakery", "worker_jobs": psa(), "outputs": {"bread_loaf": 12}, "inputs": {}, "items": {}, "sort_order": 8}),
    ("fishermen", "Fishermen", "The town's fishermen bring their morning catch to the fish stall.",
     {"name_fa": "ماهیگیران", "shop": "stall:fish", "worker_jobs": psa("Fisherman"), "outputs": {"sardine": 6, "mackerel": 2}, "inputs": {}, "items": {}, "sort_order": 9}),
    ("tailor_spinning", "Tailor: spinning", "Spins wool into yarn - buys up the wool farmers sell.",
     {"name_fa": "خیاطی: ریسندگی", "shop": "clothing", "worker_jobs": psa("Tailor"), "outputs": {"yarn": 2}, "inputs": {"wool": 2}, "sort_order": 10,
      "items": {}}),
    ("feed_mill", "Feed mill", "Chicken feed and hay for farm animals (sold at the carpenter's livestock desk).",
     {"name_fa": "کارخانه علوفه", "shop": "livestock", "worker_jobs": psa(), "outputs": {"chicken_feed": 12, "hay": 10}, "inputs": {}, "items": {}, "sort_order": 11}),
]
emit("producers", "ProducerDef", "producer_def", PRODUCERS, "carpenter_boards", collection=True)

# ------------------------------------------------------------------ wages
W = {"doctor": 140, "nurse": 90, "teacher": 80, "professor": 120, "police officer": 85, "carpenter": 75, "blacksmith": 75,
     "stonemason": 70, "tailor": 65, "jeweller": 80, "electrician": 80, "shopkeeper": 65, "supermarket cashier": 60,
     "fruit seller": 60, "fisherman": 70, "barista": 55, "postman": 60, "city clerk": 70, "water engineer": 85,
     "electricity officer": 85, "imam": 60, "priest": 60, "tool seller": 65, "retired teacher": 40, "pupil": 0, "student": 0}
emit("wages", "WagesStyle", "wages_style", [
    ("fair_wages", "Fair wages", "Every job pays a fair daily wage at 17:00 (doctors most, shop staff least); Fridays off.",
     {"wages": W, "default_wage": 60, "payday_hour": 17, "start_savings": 200, "allowance": 10, "day_off": 6}),
    ("modest_wages", "Modest wages", "Lower wages - townspeople spend more carefully.",
     {"wages": {k: int(v * 0.7) for k, v in W.items()}, "default_wage": 45, "payday_hour": 17, "start_savings": 120, "allowance": 5, "day_off": 6}),
], "fair_wages")

# ------------------------------------------------------------------ price_board
BOARD = psa("eggs", "milk", "wool", "chicken", "bread_loaf", "wood_plank", "iron_nails", "tomato", "potato", "apple", "sardine", "hay", "chicken_feed", "yarn")
emit("price_board", "PriceBoardStyle", "price_board_style", [
    ("chalkboard", "Chalkboard", "A green chalkboard on a wooden frame at the market entrance.",
     {"items": BOARD, "title_fa": "تابلوی قیمت بازار", "title_en": "Market prices", "bg_color": (0.13, 0.22, 0.17, 0.97),
      "frame_color": (0.45, 0.3, 0.18), "ink_color": (0.95, 0.95, 0.9), "up_color": (1.0, 0.5, 0.4), "down_color": (0.5, 0.95, 0.55),
      "shortage_color": (1.0, 0.35, 0.3), "position": "V2(6.6, -15.6)", "yaw_deg": -35.0, "board_rows": 8}),
    ("market_screen", "LED screen", "A dark digital price screen.",
     {"items": BOARD, "title_fa": "قیمت‌های امروز", "title_en": "Today's prices", "bg_color": (0.05, 0.06, 0.09, 0.97),
      "frame_color": (0.2, 0.2, 0.22), "ink_color": (0.9, 0.95, 1.0), "up_color": (1.0, 0.35, 0.3), "down_color": (0.3, 1.0, 0.5),
      "shortage_color": (1.0, 0.75, 0.2), "position": "V2(6.6, -15.6)", "yaw_deg": -35.0, "board_rows": 8}),
], "chalkboard")

# ------------------------------------------------------------------ livestock (collection)
FEED = {"chicken_feed": item("Chicken Feed", "دان مرغ", "feed", buy=4, sell=2, desc="One scoop feeds one chicken for a day."),
        "hay": item("Hay", "علف خشک", "feed", buy=8, sell=4, desc="One bundle feeds a cow or a sheep for a day.")}
LIVESTOCK = [
    ("chicken", "Chicken", "Lays an egg a day when fed and happy. Lives in the coop.",
     {"name_fa": "مرغ", "housing": "coop", "price": 150, "product_item": "eggs", "product_fa": "تخم‌مرغ", "product_qty": 1,
      "happy_above": 60.0, "content_above": 30.0, "tool_item": "", "feed_item": "chicken_feed", "feed_per_day": 1, "fed_gain": 12.0,
      "unfed_loss": 25.0, "pet_gain": 5.0, "start_happiness": 70.0, "adult_days": 3, "breed_every_days": 3, "breed_chance": 0.5,
      "shape": "bird", "body_color": (0.97, 0.95, 0.9), "accent_color": (0.85, 0.12, 0.1), "size": 1.0, "young_scale": 0.55,
      "walk_speed": 0.8, "names_fa": psa("زری", "خالدار", "پری", "نازی", "قشنگ", "طلایی", "مینو", "گلی"),
      "names_en": psa("Pearl", "Speckle", "Nugget", "Clucky", "Daisy", "Goldie", "Pepper", "Hazel"),
      "items": dict(FEED)}),
    ("cow", "Cow", "Gives milk every day when fed and happy (needs a milk pail). Lives in the barn.",
     {"name_fa": "گاو", "housing": "barn", "price": 900, "product_item": "milk", "product_fa": "شیر", "product_qty": 2,
      "happy_above": 60.0, "content_above": 30.0, "tool_item": "milk_pail", "feed_item": "hay", "feed_per_day": 2, "fed_gain": 12.0,
      "unfed_loss": 25.0, "pet_gain": 5.0, "start_happiness": 70.0, "adult_days": 5, "breed_every_days": 6, "breed_chance": 0.35,
      "shape": "cow", "body_color": (0.96, 0.95, 0.92), "accent_color": (0.12, 0.1, 0.09), "size": 1.0, "young_scale": 0.55,
      "walk_speed": 0.55, "names_fa": psa("مِهری", "شیرین", "خال‌خالی", "گلپر", "ماهک", "نسیم"),
      "names_en": psa("Bella", "Clover", "Buttercup", "Molly", "Rosie", "Willow"),
      "items": {"milk": item("Milk", "شیر", "animal_product", sell=30, desc="Fresh farm milk. Sell it or cook with it.", category="dairy"), "hay": FEED["hay"]}}),
    ("sheep_flock", "Sheep", "Grows wool every other day when fed and happy (needs shears). Lives in the barn.",
     {"name_fa": "گوسفند", "housing": "barn", "price": 600, "product_item": "wool", "product_fa": "پشم", "product_qty": 1, "product_every_days": 2,
      "happy_above": 60.0, "content_above": 30.0, "tool_item": "shears", "feed_item": "hay", "feed_per_day": 1, "fed_gain": 12.0,
      "unfed_loss": 25.0, "pet_gain": 5.0, "start_happiness": 70.0, "adult_days": 4, "breed_every_days": 5, "breed_chance": 0.4,
      "shape": "sheep", "body_color": (0.95, 0.94, 0.9), "accent_color": (0.2, 0.17, 0.15), "size": 1.0, "young_scale": 0.55,
      "walk_speed": 0.6, "names_fa": psa("پنبه", "ابری", "برفی", "پشمالو", "کوچولو", "سفیدک"),
      "names_en": psa("Cotton", "Cloud", "Snowy", "Fluffy", "Button", "Lamby"),
      "items": {"hay": FEED["hay"]}}),
]
emit("livestock", "LivestockDef", "livestock_def", LIVESTOCK, "chicken", collection=True)

# ------------------------------------------------------------------ animal_housing (collection)
HOUSING = [
    ("coop", "Chicken coop", "A red wooden coop with a fenced run for up to 8 chickens. 600 G + 10 planks + 4 nails, ready the next morning.",
     {"name_fa": "مرغدانی", "kinds": psa("chicken"), "capacity": 8, "cost_gold": 600, "cost_items": {"wood_plank": 10, "iron_nails": 4},
      "build_days": 1, "position": "V2(-6.0, 19.0)", "yaw_deg": 0.0, "size": "V3(3.2, 2.4, 2.6)", "paddock_offset": "V2(0.0, 4.2)",
      "paddock_size": "V2(7.0, 5.0)", "wall_color": (0.72, 0.28, 0.2), "roof_color": (0.32, 0.28, 0.26), "trim_color": (0.96, 0.94, 0.88)}),
    ("barn", "Barn", "A big barn with a pasture for up to 6 cows and sheep. 1500 G + 24 planks + 8 nails, takes 2 days.",
     {"name_fa": "طویله", "kinds": psa("cow", "sheep_flock"), "capacity": 6, "cost_gold": 1500, "cost_items": {"wood_plank": 24, "iron_nails": 8},
      "build_days": 2, "position": "V2(8.0, 19.5)", "yaw_deg": 0.0, "size": "V3(6.0, 3.6, 4.6)", "paddock_offset": "V2(0.0, 6.6)",
      "paddock_size": "V2(11.0, 8.0)", "wall_color": (0.62, 0.2, 0.16), "roof_color": (0.28, 0.27, 0.27), "trim_color": (0.97, 0.96, 0.92)}),
]
emit("animal_housing", "HousingDef", "housing_def", HOUSING, "coop", collection=True)

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v5c modules written: market_economy, producers, wages, price_board, livestock, animal_housing")
