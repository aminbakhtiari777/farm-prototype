#!/usr/bin/env python3
"""Generates the v5a module .tres files (crafting, recipes, market, town_square,
population, workplaces, civic, mosque, church, kitchen, gestures) and registers
them in data/asset_modules.json. Re-run after editing the tables below."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def col(c):
    return "Color(%s)" % ", ".join("%g" % v for v in (list(c) + [1.0])[:4])


class C(tuple):
    """A colour literal (tuples are colours, lists are arrays)."""


def val(v):
    if isinstance(v, bool): return "true" if v else "false"
    if isinstance(v, tuple): return col(v)
    if isinstance(v, int): return str(v)
    if isinstance(v, float): return "%g" % v
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, dict) and v.get("__psa"): return "PackedStringArray(%s)" % ", ".join(json.dumps(x, ensure_ascii=False) for x in v["items"])
    if isinstance(v, dict) and v.get("__pia"): return "PackedInt32Array(%s)" % ", ".join(str(x) for x in v["items"])
    if isinstance(v, dict): return "{" + ", ".join("%s: %s" % (json.dumps(k, ensure_ascii=False), val(x)) for k, x in v.items()) + "}"
    if isinstance(v, list): return "[" + ", ".join(val(x) for x in v) + "]"
    raise ValueError(v)


def psa(*items): return {"__psa": True, "items": list(items)}
def pia(*items): return {"__pia": True, "items": list(items)}


def write_tres(path, cls, script, fields):
    lines = ['[gd_resource type="Resource" script_class="%s" format=3]' % cls, "",
             '[ext_resource type="Script" path="%s" id="1"]' % script, "", "[resource]", 'script = ExtResource("1")']
    for k, v in fields.items():
        lines.append("%s = %s" % (k, val(v)))
    full = os.path.join(ROOT, path.replace("res://", ""))
    os.makedirs(os.path.dirname(full), exist_ok=True)
    open(full, "w", encoding="utf-8").write("\n".join(lines) + "\n")


config_path = os.path.join(ROOT, "data/asset_modules.json")
config = json.load(open(config_path))


def register(type_, active, variants, collection=False):
    entry = {"active": active, "variants": variants}
    if collection:
        entry = {"collection": True, "active": active, "variants": variants}
    config[type_] = entry


def simple(type_, cls, variants, active):
    script = "res://modules/%s/%s.gd" % (type_, {"crafting": "crafting_style", "market": "market_style", "town_square": "square_style",
        "population": "population_def", "workplaces": "workplace_style", "civic": "civic_style", "mosque": "mosque_style",
        "church": "church_style", "kitchen": "kitchen_style", "gestures": "gesture_style"}[type_])
    reg = {}
    for vid, name, desc, fields in variants:
        path = "res://modules/%s/%s.tres" % (type_, vid)
        f = {"id": vid, "type": type_, "display_name": name, "description": desc}
        f.update(fields)
        write_tres(path, cls, script, f)
        reg[vid] = path
    register(type_, active, reg)


# ------------------------------------------------------------------ crafting
simple("crafting", "CraftingStyle", [
    ("farm_shed", "Timber farm shed", "Timber-framed shed with a long workbench and a tool pegboard.",
     {"wall_color": (0.6, 0.44, 0.3), "roof_color": (0.36, 0.3, 0.26), "bench_color": (0.62, 0.46, 0.3), "craft_minutes": 20.0,
      "stamina_cost": 4.0, "props": psa("tools", "lathe"), "sawdust": True}),
    ("stone_workshop", "Stone workshop", "Stone-walled workshop with an anvil corner; crafting is a bit slower.",
     {"wall_color": (0.6, 0.58, 0.54), "roof_color": (0.26, 0.28, 0.32), "bench_color": (0.48, 0.36, 0.26), "craft_minutes": 30.0,
      "stamina_cost": 3.0, "props": psa("tools", "anvil"), "sawdust": False}),
], "farm_shed")

# ------------------------------------------------------------------ recipes (collection)
RECIPES = [
    # id, name, station, inputs, output_id, output_name, count, sell, category, stamina, desc
    ("birdhouse", "Birdhouse", "workbench", {"wood_plank": 3}, "birdhouse", "Birdhouse", 1, 140, "crafted", 0.0, "A cosy birdhouse. Sells well at the carpenter and the craft stall."),
    ("planter_box", "Planter Box", "workbench", {"wood_plank": 4, "iron_nails": 1}, "planter_box", "Planter Box", 1, 210, "crafted", 0.0, "Sturdy wooden planter."),
    ("iron_lantern", "Iron Lantern", "workbench", {"iron_bar": 1, "copper_wire": 1}, "iron_lantern", "Iron Lantern", 1, 230, "crafted", 0.0, "Hand-made lantern with a copper-wired bulb."),
    ("stone_planter", "Stone Planter", "workbench", {"stone_block": 3}, "stone_planter", "Stone Planter", 1, 170, "crafted", 0.0, "Carved stone planter."),
    ("shell_fertilizer", "Shell Fertilizer", "workbench", {"seashell": 2}, "fertilizer", "Fertilizer", 2, 0, "crafted", 0.0, "Crushed shells make good fertilizer."),
    ("wool_yarn", "Wool Yarn", "workbench", {"wool": 1}, "yarn", "Wool Yarn", 2, 70, "crafted", 0.0, "Spun from your sheep's wool. The clothing shop pays extra."),
    ("strawberry_jam", "Strawberry Jam", "workbench", {"strawberry": 3}, "jam", "Strawberry Jam", 1, 260, "crafted", 0.0, "Sweet preserves in a jar."),
    ("fruit_basket", "Fruit Basket", "workbench", {"apple": 2, "banana_fruit": 2, "wood_plank": 1}, "fruit_basket", "Fruit Basket", 1, 330, "crafted", 0.0, "A gift basket for the fruit shop."),
    # stove (kitchen module) - meals are eaten right away
    ("mint_tea", "Mint Tea", "stove", {}, "", "", 1, 0, "meal", 15.0, "A warm cup of tea (no ingredients needed)."),
    ("vegetable_soup", "Vegetable Soup", "stove", {"carrot": 1, "potato": 1}, "", "", 1, 0, "meal", 60.0, "Hearty soup."),
    ("grilled_fish", "Grilled Fish", "stove", {"sardine": 1}, "", "", 1, 0, "meal", 45.0, "Fresh from the sea."),
    ("tomato_stew", "Tomato Stew", "stove", {"tomato": 2}, "", "", 1, 0, "meal", 50.0, "Simple and filling."),
    ("pumpkin_soup", "Pumpkin Soup", "stove", {"pumpkin": 1}, "", "", 1, 0, "meal", 100.0, "Restores all your energy."),
    ("baked_apple", "Baked Apple", "stove", {"apple": 2}, "", "", 1, 0, "meal", 40.0, "With a pinch of cinnamon."),
]
reg = {}
for i, (rid, name, station, inputs, out, out_name, count, sell, cat, stamina, desc) in enumerate(RECIPES):
    path = "res://modules/recipes/%s.tres" % rid
    write_tres(path, "RecipeDef", "res://modules/recipes/recipe_def.gd", {
        "id": rid, "type": "recipes", "display_name": name, "description": desc, "station": station, "inputs": inputs,
        "output_id": out, "output_name": out_name, "output_count": count, "output_sell": sell, "output_category": cat,
        "stamina": stamina, "sort_order": i})
    reg[rid] = path
register("recipes", "birdhouse", reg, collection=True)

# ------------------------------------------------------------------ market
STALLS = [
    {"id": "seeds", "title": "Seed & Tool Stall", "legacy": True},
    {"id": "produce", "title": "Produce Stall", "sells": [], "buys": ["category:crop", "category:fruit"], "greeting": "Fresh from the fields!"},
    {"id": "fish", "title": "Fish Stall", "sells": [], "buys": ["category:fish"], "greeting": "Caught this morning!"},
    {"id": "crafts", "title": "Craft Stall", "sells": [], "buys": ["category:crafted"], "greeting": "Hand-made goods fetch a good price here."},
    {"id": "bakery", "title": "Bakery Stall", "sells": ["bread_loaf"], "buys": [], "greeting": "Warm bread, just baked."},
    {"id": "flowers", "title": "Flower Stall", "sells": ["sunflower_seeds"], "buys": ["sunflower"], "greeting": "Flowers brighten any home."},
]
simple("market", "MarketStyle", [
    ("bazaar", "Striped bazaar", "Six stalls with striped canopies and bunting on a sandstone plaza; +10% when selling to stalls.",
     {"paving_color": (0.68, 0.6, 0.5), "paving_alt": (0.58, 0.5, 0.42), "wood_color": (0.5, 0.35, 0.22),
      "awning_colors": [(0.85, 0.25, 0.22), (0.25, 0.45, 0.7), (0.95, 0.7, 0.2), (0.3, 0.6, 0.35), (0.6, 0.3, 0.6), (0.9, 0.45, 0.2)],
      "striped": True, "sell_bonus": 1.1, "stalls": STALLS, "bunting": True}),
    ("farmers_market", "Farmers' market", "Plain wooden booths with green canvas on grey cobbles; +5% when selling to stalls.",
     {"paving_color": (0.55, 0.55, 0.53), "paving_alt": (0.48, 0.48, 0.47), "wood_color": (0.42, 0.3, 0.2),
      "awning_colors": [(0.3, 0.5, 0.32), (0.36, 0.56, 0.36)], "striped": False, "sell_bonus": 1.05, "stalls": STALLS, "bunting": False}),
], "bazaar")

# ------------------------------------------------------------------ town square
simple("town_square", "SquareStyle", [
    ("ornate_fountain", "Ornate fountain square", "Three-tier fountain, star-rosette mosaic, flower beds, eight ornamental lamps and a statue.",
     {"centerpiece": "fountain", "fountain_tiers": 3, "stone_color": (0.86, 0.82, 0.74), "mosaic_a": (0.8, 0.72, 0.58),
      "mosaic_b": (0.36, 0.5, 0.62), "mosaic_c": (0.72, 0.36, 0.26), "pattern": 1,
      "flower_colors": [(0.9, 0.25, 0.35), (0.98, 0.8, 0.2), (0.6, 0.35, 0.85)], "ornate_lamps": 4, "statue": True, "hedges": True}),
    ("classic_well", "Classic well square", "The v3 square: stone well in the middle, ring mosaic, four lamps.",
     {"centerpiece": "well", "fountain_tiers": 1, "stone_color": (0.7, 0.68, 0.64), "mosaic_a": (0.66, 0.6, 0.52),
      "mosaic_b": (0.56, 0.52, 0.46), "mosaic_c": (0.5, 0.42, 0.36), "pattern": 2,
      "flower_colors": [(0.95, 0.95, 0.9)], "ornate_lamps": 4, "statue": False, "hedges": False}),
], "ornate_fountain")

# ------------------------------------------------------------------ population
def R(name, surname, age, gender, job, work, home, role, hair, hair_color, shirt, pants, skin=0, beard=False, top="work_shirt", lines=None):
    return {"name": name, "surname": surname, "age": age, "gender": gender, "job": job, "work": work, "home": home,
            "family": surname, "role": role, "hair": hair, "hair_color": hair_color, "shirt": shirt, "pants": pants,
            "skin": skin, "beard": beard, "top": top, "lines": lines or []}

DARK = (0.1, 0.07, 0.05); BROWN = (0.35, 0.2, 0.1); AUBURN = (0.5, 0.25, 0.1); GREY = (0.55, 0.55, 0.55); BLOND = (0.75, 0.6, 0.35)
RES = [
    # maple2 - Karimi
    R("Mina", "Karimi", 34, "female", "Barista", "cafe", "maple2", "mother", "Hair_Long", DARK, (0.78, 0.3, 0.32), (0.2, 0.2, 0.26), 0, top="tshirt",
      lines=["The coffee is fresh today.", "Ali keeps asking about your sheep!", "I love this town square."]),
    R("Reza", "Karimi", 37, "male", "Postman", "post", "maple2", "father", "Hair_Buzzed", DARK, (0.25, 0.32, 0.5), (0.15, 0.15, 0.17), 1, True, "jacket",
      lines=["Any letters to send?", "Mina makes the best coffee in town.", "Parcels, parcels everywhere!"]),
    R("Ali", "Karimi", 9, "male", "Pupil", "school", "maple2", "son", "Hair_SimpleParted", DARK, (0.95, 0.6, 0.2), (0.25, 0.3, 0.5), 1, top="tshirt",
      lines=["We learned about bees today!", "Can I pet your sheep?", "School's out soon!"]),
    # maple4 - Rahimi
    R("Dariush", "Rahimi", 45, "male", "Police officer", "police", "maple4", "father", "Hair_SimpleParted", GREY, (0.15, 0.2, 0.35), (0.12, 0.14, 0.2), 0, top="jacket",
      lines=["All quiet in town.", "Walk safe!", "Keep an eye on your sheep!"]),
    R("Leila", "Rahimi", 42, "female", "Doctor", "hospital", "maple4", "mother", "Hair_SimpleParted", DARK, (0.92, 0.92, 0.95), (0.5, 0.65, 0.75), 1, top="jacket",
      lines=["Remember to rest when you're tired.", "Drink water, farmer!", "Sima studies medicine, like me."]),
    R("Sima", "Rahimi", 19, "female", "Student", "university", "maple4", "daughter", "Hair_Buns", DARK, (0.4, 0.6, 0.8), (0.25, 0.25, 0.3), 1, top="tshirt",
      lines=["Exams next week...", "The university library is huge.", "Dad worries too much."]),
    # maple3 - Ahmadi
    R("Sara", "Ahmadi", 29, "female", "Shopkeeper", "store", "maple3", "daughter", "Hair_Buns", AUBURN, (0.35, 0.55, 0.4), (0.3, 0.25, 0.2), 0,
      lines=["We restock seeds every morning.", "Fertilizer makes crops grow faster!", "Mum loves the mosque garden."]),
    R("Parvin", "Ahmadi", 66, "female", "Retired teacher", "", "maple3", "mother", "Hair_Buns", GREY, (0.5, 0.35, 0.5), (0.3, 0.3, 0.32), 0, top="jacket",
      lines=["I taught half this town to read.", "The fountain is lovely in the evening.", "Have you met my Sara?"]),
    # maple5 - Hosseini
    R("Omid", "Hosseini", 40, "male", "City clerk", "city_hall", "maple5", "father", "Hair_SimpleParted", BROWN, (0.85, 0.82, 0.7), (0.32, 0.28, 0.22), 0,
      lines=["City Hall is open nine to four.", "The town directory is at City Hall.", "The mayor says hello."]),
    R("Nasrin", "Hosseini", 38, "female", "Supermarket cashier", "supermarket", "maple5", "mother", "Hair_Long", AUBURN, (0.85, 0.6, 0.2), (0.25, 0.3, 0.45), 0,
      lines=["Fresh produce at the supermarket!", "Pumpkins sell well in autumn.", "Arman wants to be a blacksmith."]),
    R("Arman", "Hosseini", 12, "male", "Pupil", "school", "maple5", "son", "Hair_Buzzed", BROWN, (0.3, 0.6, 0.3), (0.25, 0.25, 0.3), 0, top="tshirt",
      lines=["Mr Jafari let me hold the hammer!", "Race you to the fountain!", "I like the fish stall."]),
    # oak12 - Moradi
    R("Kian", "Moradi", 31, "male", "Fisherman", "pier", "oak12", "husband", "Hair_Buzzed", AUBURN, (0.2, 0.45, 0.55), (0.35, 0.3, 0.22), 1, True, "tshirt",
      lines=["Mackerel are biting in summer.", "Storms bring the red snapper in.", "Sell your fish at the fish stall."]),
    R("Shirin", "Moradi", 30, "female", "Fruit seller", "fruit_shop", "oak12", "wife", "Hair_Long", BROWN, (0.9, 0.5, 0.4), (0.3, 0.28, 0.25), 1,
      lines=["Apples from your farm? I'll pay well!", "Kian brings the fish, I bring the fruit.", "Try a fruit basket."]),
    # oak15 - Tehrani
    R("Bahram", "Tehrani", 52, "male", "Carpenter", "carpenter", "oak15", "husband", "Hair_SimpleParted", GREY, (0.6, 0.45, 0.3), (0.3, 0.25, 0.2), 0, True,
      lines=["Planks are twenty a piece.", "A birdhouse needs three planks.", "Golnar teaches at the school."]),
    R("Golnar", "Tehrani", 49, "female", "Teacher", "school", "oak15", "wife", "Hair_Buns", BROWN, (0.4, 0.3, 0.55), (0.25, 0.25, 0.3), 0, top="jacket",
      lines=["Reading, writing and farming!", "The children love the market.", "Bahram built our school desks."]),
    # pine9 - Jafari
    R("Hassan", "Jafari", 58, "male", "Blacksmith", "blacksmith", "pine9", "husband", "Hair_Buzzed", GREY, (0.3, 0.28, 0.26), (0.2, 0.18, 0.16), 1, True,
      lines=["Iron bars, sixty gold.", "A good lantern needs copper wire too.", "The forge keeps me warm."]),
    R("Maryam", "Jafari", 54, "female", "Tailor", "clothing", "pine9", "wife", "Hair_Long", DARK, (0.7, 0.3, 0.45), (0.25, 0.2, 0.25), 1,
      lines=["A new shirt changes everything!", "I pay well for wool yarn.", "Hassan's apron is always sooty."]),
    # harbor2 - Sadeghi
    R("Navid", "Sadeghi", 35, "male", "Electrician", "electrical", "harbor2", "husband", "Hair_SimpleParted", DARK, (0.95, 0.8, 0.2), (0.2, 0.22, 0.3), 1,
      lines=["Copper wire, forty a roll.", "Mind the breaker box!", "Elena works at the hospital."]),
    R("Elena", "Sadeghi", 33, "female", "Nurse", "hospital", "harbor2", "wife", "Hair_Buns", BLOND, (0.6, 0.8, 0.85), (0.6, 0.8, 0.85), 0,
      lines=["Rest is the best medicine.", "The beach is lovely after a shift.", "Navid fixes everything."]),
    # maple7 - Rostami
    R("Farhad", "Rostami", 44, "male", "Stonemason", "mason", "maple7", "father", "Hair_Buzzed", BROWN, (0.6, 0.6, 0.58), (0.35, 0.33, 0.3), 0, True,
      lines=["Stone blocks, thirty each.", "I carved the fountain statue.", "Dara wants to be a mason."]),
    R("Laleh", "Rostami", 41, "female", "Jeweller", "jewelry", "maple7", "mother", "Hair_Long", AUBURN, (0.3, 0.25, 0.45), (0.2, 0.2, 0.25), 0, top="jacket",
      lines=["Shells make beautiful jewellery.", "A ring makes a lovely gift.", "Farhad's hands are always dusty."]),
    R("Dara", "Rostami", 7, "male", "Pupil", "school", "maple7", "son", "Hair_SimpleParted", BROWN, (0.85, 0.3, 0.3), (0.25, 0.3, 0.45), 0, top="tshirt",
      lines=["I found a shell at the beach!", "Is that your farm?", "Dad made the fountain!"]),
    # maple1 - Nouri
    R("Babak", "Nouri", 39, "male", "Water engineer", "water_office", "maple1", "husband", "Hair_SimpleParted", DARK, (0.3, 0.5, 0.7), (0.2, 0.22, 0.3), 1,
      lines=["The reservoir is full this season.", "Your can? I'll refill it at the office.", "Ziba runs the power grid."]),
    R("Ziba", "Nouri", 36, "female", "Electricity officer", "power_office", "maple1", "wife", "Hair_Long", DARK, (0.95, 0.85, 0.4), (0.25, 0.25, 0.3), 1, top="jacket",
      lines=["If the power's out, come see me.", "The substation hums all day.", "Babak keeps the water flowing."]),
    # oak10 - Bell
    R("Thomas", "Bell", 61, "male", "Priest", "church", "oak10", "husband", "Hair_SimpleParted", GREY, (0.12, 0.12, 0.14), (0.12, 0.12, 0.14), 0, top="jacket",
      lines=["Peace be with you.", "The bell rings at nine, noon and six.", "Anna runs the tool shop."]),
    R("Anna", "Bell", 57, "female", "Tool seller", "tool_shop", "oak10", "wife", "Hair_Buns", GREY, (0.4, 0.55, 0.4), (0.3, 0.28, 0.25), 0,
      lines=["Better tools, better harvests.", "The copper can holds twice the water.", "Thomas loves the choir."]),
    # pine14 - Haddad
    R("Yusuf", "Haddad", 59, "male", "Imam", "mosque", "pine14", "husband", "Hair_SimpleParted", GREY, (0.92, 0.9, 0.85), (0.85, 0.83, 0.78), 1, True, "jacket",
      lines=["Peace be upon you.", "You are always welcome at the mosque.", "Amina teaches at the university."]),
    R("Amina", "Haddad", 52, "female", "Professor", "university", "pine14", "wife", "Hair_Buns", DARK, (0.25, 0.4, 0.45), (0.2, 0.2, 0.24), 1, top="jacket",
      lines=["Soil science is fascinating.", "Our students help at the market.", "Yusuf's garden has the best roses."]),
]
SMALL = [r for r in RES if r["home"] in ("maple2", "maple4", "maple3", "maple5", "oak12", "oak15", "pine9", "harbor2")][:14]
simple("population", "PopulationDef", [
    ("families", "Families of Greenvale", "28 residents in 12 family homes: names, ages, jobs, workplaces and family ties.",
     {"residents": RES, "max_spawned": 28, "child_scale": 0.72, "teen_scale": 0.9}),
    ("small_town", "Small town", "14 residents (first eight homes) - lighter on low-end devices.",
     {"residents": SMALL, "max_spawned": 14, "child_scale": 0.72, "teen_scale": 0.9}),
], "families")

# ------------------------------------------------------------------ workplaces
ITEMS = {
    "wood_plank": {"name": "Wood Plank", "type": "material", "buy": 20, "description": "Crafting material (carpenter)."},
    "iron_nails": {"name": "Iron Nails", "type": "material", "buy": 15, "description": "Crafting material (blacksmith)."},
    "iron_bar": {"name": "Iron Bar", "type": "material", "buy": 60, "description": "Crafting material (blacksmith)."},
    "stone_block": {"name": "Stone Block", "type": "material", "buy": 30, "description": "Crafting material (stonemason)."},
    "copper_wire": {"name": "Copper Wire", "type": "material", "buy": 40, "description": "Crafting material (electrical shop)."},
    "light_bulb": {"name": "Light Bulb", "type": "material", "buy": 25, "description": "Spare bulb. Keeps the farmhouse lights bright."},
    "bread_loaf": {"name": "Bread Loaf", "type": "food", "buy": 15, "stamina": 20, "description": "Eaten right away: +20 stamina."},
    "silver_ring": {"name": "Silver Ring", "type": "gift", "buy": 300, "description": "A gift: greet a townsperson while carrying it."},
    "gold_necklace": {"name": "Gold Necklace", "type": "gift", "buy": 900, "description": "A precious gift."},
    "shirt_red": {"name": "Red Shirt", "type": "outfit", "buy": 80, "shirt": (0.75, 0.2, 0.2), "description": "Changes your shirt colour."},
    "shirt_green": {"name": "Green Shirt", "type": "outfit", "buy": 80, "shirt": (0.25, 0.55, 0.3), "description": "Changes your shirt colour."},
    "shirt_blue": {"name": "Blue Shirt", "type": "outfit", "buy": 80, "shirt": (0.25, 0.4, 0.75), "description": "Changes your shirt colour."},
    "shirt_yellow": {"name": "Yellow Shirt", "type": "outfit", "buy": 80, "shirt": (0.95, 0.78, 0.25), "description": "Changes your shirt colour."},
    "overalls_denim": {"name": "Denim Trousers", "type": "outfit", "buy": 120, "pants": (0.2, 0.3, 0.5), "description": "Changes your trousers."},
}
SHOPS = {
    "carpenter": {"title": "Carpenter", "greeting": "Planks, cut to size!", "sells": ["wood_plank"], "buys": ["birdhouse", "planter_box"], "buy_mult": 1.15},
    "blacksmith": {"title": "Blacksmith", "greeting": "Iron and nails, hot from the forge.", "sells": ["iron_bar", "iron_nails"], "buys": ["iron_lantern"], "buy_mult": 1.15},
    "mason": {"title": "Stonemason", "greeting": "Good stone lasts forever.", "sells": ["stone_block"], "buys": ["stone_planter"], "buy_mult": 1.15},
    "fruit_shop": {"title": "Fruit Shop", "greeting": "Fruit trees and fresh fruit!", "sells": ["apple_sapling", "banana_sucker", "strawberry_seeds"],
                   "buys": ["apple", "banana_fruit", "strawberry", "jam", "fruit_basket"], "buy_mult": 1.2},
    "clothing": {"title": "Clothing Shop", "greeting": "Something new to wear?", "sells": ["shirt_red", "shirt_green", "shirt_blue", "shirt_yellow", "overalls_denim"],
                 "buys": ["wool", "yarn"], "buy_mult": 1.2},
    "jewelry": {"title": "Jeweller", "greeting": "Pearls, rings and necklaces.", "sells": ["silver_ring", "gold_necklace"],
                "buys": ["seashell", "scallop_shell", "conch"], "buy_mult": 1.25},
    "tool_shop": {"title": "Tool Shop", "greeting": "The right tool for every job.", "sells": ["type:tool", "fertilizer"], "buys": [], "buy_mult": 1.0},
    "electrical": {"title": "Electrical Supplies", "greeting": "Wires, bulbs and switches.", "sells": ["copper_wire", "light_bulb"], "buys": ["iron_lantern"], "buy_mult": 1.1},
}
simple("workplaces", "WorkplaceStyle", [
    ("classic_shops", "Classic shopfronts", "Gabled workshops and shops with striped awnings over the windows.",
     {"shops": SHOPS, "items": ITEMS, "awnings": True, "awning_colors": [(0.8, 0.3, 0.25), (0.25, 0.5, 0.35), (0.3, 0.4, 0.7), (0.85, 0.65, 0.2)],
      "wall_tint": (1, 1, 1), "flat_roofs": False}),
    ("modern_shops", "Modern shopfronts", "Flat roofs, plain fronts, cooler colours. Same shops and stock.",
     {"shops": SHOPS, "items": ITEMS, "awnings": False, "awning_colors": [(0.3, 0.3, 0.32)], "wall_tint": (0.92, 0.95, 1.0), "flat_roofs": True}),
], "classic_shops")

# ------------------------------------------------------------------ civic
DESKS = {
    "water_office": {"title": "Water Office", "lines": ["The reservoir is full.", "Clean water for every home."]},
    "power_office": {"title": "Electricity Office", "lines": ["The grid is humming.", "Report outages here."]},
    "school": {"title": "School", "lines": ["Class is in session!", "Two plus two is four."]},
    "university": {"title": "University", "lines": ["Today's lecture: soil chemistry.", "Did you know? Rain waters every crop for free."]},
}
simple("civic", "CivicStyle", [
    ("classical", "Classical civic", "Columned porticos, flags, a substation yard by the Electricity Office and a water tower by the Water Office.",
     {"desks": DESKS, "columns": True, "column_color": (0.95, 0.93, 0.88), "flag_color": (0.2, 0.55, 0.3), "wall_tint": (1, 1, 1),
      "substation": True, "water_tower": True}),
    ("plain", "Plain civic", "No porticos or towers - simple municipal buildings.",
     {"desks": DESKS, "columns": False, "column_color": (0.8, 0.8, 0.8), "flag_color": (0.25, 0.35, 0.65), "wall_tint": (0.95, 0.95, 0.95),
      "substation": False, "water_tower": False}),
], "classical")

# ------------------------------------------------------------------ mosque / church
simple("mosque", "MosqueStyle", [
    ("turquoise_dome", "Turquoise dome", "White walls, turquoise dome and tilework, one minaret; a short, quiet call every hour.",
     {"wall_color": (0.93, 0.9, 0.82), "dome_color": (0.22, 0.56, 0.62), "trim_color": (0.18, 0.42, 0.55), "tile_color": (0.15, 0.45, 0.6),
      "minarets": 1, "minaret_height": 15.0, "carpet_color": (0.55, 0.12, 0.14), "adhan_sound": "res://assets/audio/sfx/adhan.ogg",
      "adhan_db": -10.0, "call_hours": pia(*range(24)), "max_distance": 85.0}),
    ("sandstone", "Sandstone, two minarets", "Sandstone walls, golden dome, two minarets; the call only at the five prayer times.",
     {"wall_color": (0.86, 0.74, 0.55), "dome_color": (0.82, 0.66, 0.3), "trim_color": (0.5, 0.36, 0.2), "tile_color": (0.6, 0.45, 0.25),
      "minarets": 2, "minaret_height": 13.0, "carpet_color": (0.2, 0.35, 0.3), "adhan_sound": "res://assets/audio/sfx/adhan.ogg",
      "adhan_db": -12.0, "call_hours": pia(5, 13, 16, 19, 21), "max_distance": 75.0}),
], "turquoise_dome")
simple("church", "ChurchStyle", [
    ("stone_chapel", "Stone chapel", "Grey stone, slate roof, bell tower with spire; bells at 9, 12 and 18.",
     {"wall_color": (0.72, 0.7, 0.66), "roof_color": (0.3, 0.3, 0.34), "spire_color": (0.28, 0.3, 0.34), "tower_height": 11.0,
      "glass_colors": [(0.8, 0.2, 0.25), (0.2, 0.4, 0.85), (0.95, 0.8, 0.25)], "pew_color": (0.42, 0.28, 0.16),
      "bell_sound": "res://assets/audio/sfx/church_bell.ogg", "bell_db": -12.0, "bell_hours": pia(9, 12, 18), "max_distance": 90.0}),
    ("white_church", "White country church", "Whitewashed walls, red roof, slimmer spire; bell on Sunday-style hours 10 and 17.",
     {"wall_color": (0.95, 0.94, 0.9), "roof_color": (0.6, 0.22, 0.18), "spire_color": (0.55, 0.2, 0.16), "tower_height": 12.5,
      "glass_colors": [(0.3, 0.6, 0.9), (0.95, 0.85, 0.4)], "pew_color": (0.55, 0.4, 0.25),
      "bell_sound": "res://assets/audio/sfx/church_bell.ogg", "bell_db": -12.0, "bell_hours": pia(10, 17), "max_distance": 80.0}),
], "stone_chapel")

# ------------------------------------------------------------------ kitchen
simple("kitchen", "KitchenStyle", [
    ("modern_electric", "Modern electric kitchen", "White cabinets, dark worktop, electric hob + hood. Needs power to cook.",
     {"stove": "electric", "cabinet_color": (0.9, 0.9, 0.86), "counter_color": (0.28, 0.28, 0.3), "stove_color": (0.92, 0.92, 0.92),
      "hood": True, "upper_cabinets": True, "sink": True, "pots": True}),
    ("rustic_gas", "Rustic gas kitchen", "Wooden cabinets, butcher-block worktop and a gas range - works during power cuts.",
     {"stove": "gas", "cabinet_color": (0.55, 0.4, 0.26), "counter_color": (0.66, 0.5, 0.32), "stove_color": (0.2, 0.2, 0.22),
      "hood": False, "upper_cabinets": True, "sink": True, "pots": True}),
    ("wood_stove", "Wood-fired kitchen", "Cast-iron wood stove with a flue pipe and open shelves.",
     {"stove": "wood", "cabinet_color": (0.62, 0.5, 0.36), "counter_color": (0.5, 0.42, 0.34), "stove_color": (0.12, 0.12, 0.13),
      "hood": False, "upper_cabinets": False, "sink": True, "pots": True}),
], "modern_electric")

# ------------------------------------------------------------------ gestures
simple("gestures", "GestureStyle", [
    ("friendly_wave", "Friendly wave", "Townspeople often wave when the farmer passes within 7 m.",
     {"wave_distance": 7.0, "wave_chance": 0.75, "wave_seconds": 1.8, "cooldown": 30.0, "arm_raise": 2.3, "wave_speed": 2.4}),
    ("reserved_nod", "Reserved", "Rare, small waves from closer up.",
     {"wave_distance": 4.0, "wave_chance": 0.3, "wave_seconds": 1.2, "cooldown": 60.0, "arm_raise": 1.7, "wave_speed": 1.8}),
], "friendly_wave")

json.dump(config, open(config_path, "w"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v5a modules written:", ", ".join(["crafting", "recipes", "market", "town_square", "population", "workplaces", "civic", "mosque", "church", "kitchen", "gestures"]))
