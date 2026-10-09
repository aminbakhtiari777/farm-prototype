#!/usr/bin/env python3
"""Generates the v5b module .tres files and registers them in
data/asset_modules.json:
  fonts, dialogue, friendship, shop_hours, voices, npc_card, needs,
  illnesses (collection), ingredients (collection), dishes (collection), cooking
and adds the dome fields to the mosque variants. Re-run after editing."""
import json, os, re, importlib.util
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# Reuse the writer helpers from the v5a generator without re-running it.
src = open(os.path.join(ROOT, "tools", "gen_modules_v5a.py"), encoding="utf-8").read()
helpers = src.split("config_path =")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v5a.py")}
exec(helpers, ns)
write_tres, psa, pia, val = ns["write_tres"], ns["psa"], ns["pia"], ns["val"]

config_path = os.path.join(ROOT, "data/asset_modules.json")
config = json.load(open(config_path, encoding="utf-8"))


def register(type_, active, variants, collection=False):
    entry = {"active": active, "variants": variants}
    if collection:
        entry = {"collection": True, "active": active, "variants": variants}
    config[type_] = entry


def simple(type_, cls, script_name, variants, active):
    script = "res://modules/%s/%s.gd" % (type_, script_name)
    reg = {}
    for vid, name, desc, fields in variants:
        path = "res://modules/%s/%s.tres" % (type_, vid)
        f = {"id": vid, "type": type_, "display_name": name, "description": desc}
        f.update(fields)
        write_tres(path, cls, script, f)
        reg[vid] = path
    register(type_, active, reg)


def collection(type_, cls, script_name, items, active):
    script = "res://modules/%s/%s.gd" % (type_, script_name)
    reg = {}
    for vid, name, desc, fields in items:
        path = "res://modules/%s/%s.tres" % (type_, vid)
        f = {"id": vid, "type": type_, "display_name": name, "description": desc}
        f.update(fields)
        write_tres(path, cls, script, f)
        reg[vid] = path
    register(type_, active, reg, collection=True)


def L(fa, en):
    """A bilingual table entry."""
    return {"fa": list(fa) if isinstance(fa, (list, tuple)) else [fa], "en": list(en) if isinstance(en, (list, tuple)) else [en]}


# ------------------------------------------------------------------ fonts
simple("fonts", "FontStyle", "font_style", [
    ("vazirmatn", "Vazirmatn", "Vazirmatn Regular (OFL) - Persian/Arabic + Latin glyphs, right-to-left shaping.",
     {"regular_path": "res://assets/fonts/Vazirmatn-Regular.ttf", "bold_path": "res://assets/fonts/Vazirmatn-Bold.ttf",
      "bubble_size": 44, "bubble_outline": 12, "bold_bubbles": False}),
    ("vazirmatn_bold", "Vazirmatn Bold bubbles", "Same font, bold speech bubbles (easier to read from afar).",
     {"regular_path": "res://assets/fonts/Vazirmatn-Regular.ttf", "bold_path": "res://assets/fonts/Vazirmatn-Bold.ttf",
      "bubble_size": 48, "bubble_outline": 14, "bold_bubbles": True}),
], "vazirmatn")

# ------------------------------------------------------------------ dialogue
NAMES_FA = {
    "Mina": "مینا", "Reza": "رضا", "Ali": "علی", "Dariush": "داریوش", "Leila": "لیلا", "Sima": "سیما", "Sara": "سارا",
    "Parvin": "پروین", "Omid": "امید", "Nasrin": "نسرین", "Arman": "آرمان", "Kian": "کیان", "Shirin": "شیرین",
    "Bahram": "بهرام", "Golnar": "گلنار", "Hassan": "حسن", "Maryam": "مریم", "Navid": "نوید", "Elena": "النا",
    "Farhad": "فرهاد", "Laleh": "لاله", "Dara": "دارا", "Babak": "بابک", "Ziba": "زیبا", "Thomas": "توماس",
    "Anna": "آنا", "Yusuf": "یوسف", "Amina": "امینه",
    "Karimi": "کریمی", "Rahimi": "رحیمی", "Ahmadi": "احمدی", "Hosseini": "حسینی", "Moradi": "مرادی", "Tehrani": "تهرانی",
    "Jafari": "جعفری", "Sadeghi": "صادقی", "Rostami": "رستمی", "Nouri": "نوری", "Bell": "بل", "Haddad": "حداد",
}
JOBS_FA = {
    "Barista": "باریستا", "Postman": "نامه‌رسان", "Pupil": "دانش‌آموز", "Police officer": "مأمور پلیس", "Doctor": "پزشک",
    "Student": "دانشجو", "Shopkeeper": "مغازه‌دار", "Retired teacher": "معلم بازنشسته", "City clerk": "کارمند شهرداری",
    "Supermarket cashier": "صندوق‌دار سوپرمارکت", "Fisherman": "ماهیگیر", "Fruit seller": "میوه‌فروش", "Carpenter": "نجار",
    "Teacher": "معلم", "Blacksmith": "آهنگر", "Tailor": "خیاط", "Electrician": "برق‌کار", "Nurse": "پرستار",
    "Stonemason": "سنگ‌تراش", "Jeweller": "جواهرساز", "Water engineer": "مهندس آب", "Electricity officer": "کارمند اداره برق",
    "Priest": "کشیش", "Tool seller": "ابزارفروش", "Imam": "امام جماعت", "Professor": "استاد دانشگاه",
}
PLACES_FA = {
    "cafe": "کافه", "post": "پست", "school": "مدرسه", "police": "پلیس", "hospital": "بیمارستان", "university": "دانشگاه",
    "store": "فروشگاه", "city_hall": "شهرداری", "supermarket": "سوپرمارکت", "pier": "اسکله", "fruit_shop": "میوه‌فروشی",
    "carpenter": "نجاری", "blacksmith": "آهنگری", "clothing": "لباس‌فروشی", "electrical": "لوازم برقی", "mason": "سنگ‌تراشی",
    "jewelry": "جواهرفروشی", "water_office": "اداره آب", "power_office": "اداره برق", "church": "کلیسا", "tool_shop": "ابزارفروشی",
    "mosque": "مسجد", "workshop": "کارگاه", "home": "خانه",
}
GREET = {
    "morning": L(["سلام، صبح بخیر!", "صبح بخیر! چطوری؟ خوبی؟", "سلام، صبحت بخیر!"], ["Hello, good morning!", "Morning! How are you? All good?", "Hi, good morning!"]),
    "noon": L(["سلام، چطوری؟ خوبی؟", "روز بخیر!", "سلام! خسته نباشی!"], ["Hello, how are you? Good?", "Good day!", "Hi! Hope work's going well!"]),
    "evening": L(["عصر بخیر!", "سلام، عصرت بخیر! چطوری؟", "سلام! خسته نباشی!"], ["Good evening!", "Hi, good evening! How are you?", "Hi! Long day?"]),
    "night": L(["شب بخیر!", "سلام، دیروقته‌ها!", "شبت بخیر!"], ["Good night!", "Hi, it's getting late!", "Sleep well!"]),
}
CHAT = L(["سلام، چطوری؟ خوبی؟", "امروز بازار شلوغه!", "نون تازه گرفتی؟", "هوا چه خوبه امروز!", "بچه‌ها خوبن؟", "قیمت گوجه بالا رفته!",
          "بریم یه چایی بخوریم؟", "شنیدی کشاورز جدید اومده؟"],
         ["Hi, how are you? All good?", "The market is busy today!", "Did you get fresh bread?", "Lovely weather today!",
          "How are the kids?", "Tomatoes got pricey!", "Shall we have some tea?", "Heard about the new farmer?"])
REPLY = L(["خوبم، مرسی! تو چطوری؟", "الحمدلله، بد نیستم.", "آره، خیلی!", "ممنون، سلامت باشی.", "حتماً، بریم!", "قربونت، همه خوبن."],
          ["I'm fine, thanks! And you?", "Thank God, not bad.", "Yes, very!", "Thanks, take care.", "Sure, let's go!", "Thanks, everyone's well."])
PLAYER_GREET = L(["سلام {player} جان! چطوری؟ خوبی؟", "به‌به، {player}! خوش اومدی."], ["Hi {player}! How are you? Good?", "Oh, {player}! Welcome."])
JOB = {
    "barista": {"work": L(["قهوه تازه دم کردم، بفرما!", "یه چایی داغ می‌خوری؟"], ["Fresh coffee's ready, have some!", "Fancy a hot tea?"]),
                "off": L(["امروز کافه خیلی شلوغ بود.", "دلم برای یه استراحت تنگ شده."], ["The cafe was packed today.", "I could use a break."])},
    "postman": {"work": L(["نامه‌ای داری که پست کنم؟", "امروز کلی بسته دارم!"], ["Any letters to send?", "So many parcels today!"]),
                "off": L(["کل شهر رو پیاده رفتم!", "پاهام خسته‌ست."], ["I walked the whole town today!", "My feet are tired."])},
    "pupil": {"work": L(["سر کلاس درباره زنبورها یاد گرفتیم!", "معلم‌مون خیلی مهربونه."], ["We learned about bees in class!", "Our teacher is really kind."]),
              "off": L(["بیا بریم تا فواره مسابقه!", "می‌شه گوسفندت رو ناز کنم؟"], ["Race you to the fountain!", "Can I pet your sheep?"])},
    "police": {"work": L(["شهر امن و آرومه.", "مراقب خودت باش!"], ["All quiet and safe in town.", "Stay safe!"]),
               "off": L(["امنیت یعنی همسایه‌ها هوای هم رو داشته باشن.", "امروز یه کیف گمشده پیدا کردم."], ["Safety means neighbours looking out for each other.", "I found a lost wallet today."])},
    "doctor": {"work": L(["اگه حالت خوب نیست، بیا بیمارستان.", "آب زیاد بخور و خوب بخواب!"], ["If you feel unwell, come to the hospital.", "Drink water and sleep well!"]),
               "off": L(["سلامتی از غذای خوب و خواب کافی شروع می‌شه.", "روزی یه وعده غذای گرم یادت نره!"], ["Health starts with good food and enough sleep.", "Don't forget one warm meal a day!"])},
    "nurse": {"work": L(["استراحت بهترین داروئه.", "فشارت رو بگیرم؟"], ["Rest is the best medicine.", "Shall I check your blood pressure?"]),
              "off": L(["بعد از شیفت لب ساحل قدم می‌زنم.", "سرماخوردگی این روزها زیاده."], ["I walk on the beach after my shift.", "Lots of colds going around."])},
    "student": {"work": L(["کتابخونه دانشگاه خیلی بزرگه.", "هفته دیگه امتحان دارم..."], ["The university library is huge.", "Exams next week..."]),
                "off": L(["دارم برای امتحان می‌خونم.", "یه قهوه حسابی لازم دارم!"], ["Studying for exams.", "I need a strong coffee!"])},
    "shopkeeper": {"work": L(["هر صبح بذر تازه میاریم.", "کود، محصولت رو زودتر می‌رسونه!"], ["We restock seeds every morning.", "Fertilizer makes crops grow faster!"]),
                   "off": L(["مغازه رو بستم، دارم می‌رم خونه.", "مامانم باغ مسجد رو خیلی دوست داره."], ["Shop's closed, heading home.", "Mum loves the mosque garden."])},
    "retired": {"work": L(["نصف این شهر رو من باسواد کردم!", "عصرها کنار فواره قشنگه."], ["I taught half this town to read!", "The fountain is lovely in the evening."]),
                "off": L(["عصرها کنار فواره قشنگه.", "جوون‌ها همیشه عجله دارن!"], ["The fountain is lovely in the evening.", "Young people are always in a hurry!"])},
    "clerk": {"work": L(["شهرداری از نه تا چهار بازه.", "فهرست اهالی شهر توی شهرداریه."], ["City Hall is open nine to four.", "The town directory is at City Hall."]),
              "off": L(["امروز کلی فرم پر کردم!", "شهردار سلام رسوند."], ["So many forms today!", "The mayor says hello."])},
    "cashier": {"work": L(["مرغ و تخم‌مرغ تازه داریم!", "نمک و ادویه قفسه آخره."], ["We have fresh chicken and eggs!", "Salt and spices are on the last shelf."]),
                "off": L(["کدو حلوایی پاییز خوب فروش می‌ره.", "آرمان می‌خواد آهنگر بشه."], ["Pumpkins sell well in autumn.", "Arman wants to be a blacksmith."])},
    "fisherman": {"work": L(["ماهی‌ها امروز خوب نوک می‌زنن!", "طوفان، ماهی قرمز میاره."], ["The fish are biting today!", "Storms bring the red snapper."]),
                  "off": L(["ماهی‌هات رو به غرفه ماهی بفروش.", "دریا امروز آروم بود."], ["Sell your fish at the fish stall.", "The sea was calm today."])},
    "fruit": {"work": L(["سیب باغ خودته؟ خوب می‌خرم!", "یه سبد میوه امتحان کن."], ["Apples from your farm? I'll pay well!", "Try a fruit basket."]),
              "off": L(["کیان ماهی میاره، من میوه!", "میوه تازه یعنی سلامتی."], ["Kian brings fish, I bring fruit!", "Fresh fruit is good health."])},
    "carpenter": {"work": L(["تخته دونه‌ای بیست سکه.", "خونه پرنده سه تا تخته می‌خواد."], ["Planks are twenty a piece.", "A birdhouse needs three planks."]),
                  "off": L(["دستام بوی چوب می‌ده!", "میز مدرسه رو من ساختم."], ["My hands smell of wood!", "I built the school desks."])},
    "teacher": {"work": L(["خوندن، نوشتن و کشاورزی!", "بچه‌ها امروز خیلی شلوغ کردن."], ["Reading, writing and farming!", "The kids were lively today."]),
                "off": L(["بچه‌ها بازار رو خیلی دوست دارن.", "دارم برگه‌ها رو تصحیح می‌کنم."], ["The children love the market.", "Marking papers tonight."])},
    "blacksmith": {"work": L(["شمش آهن، شصت سکه.", "کوره امروز داغه!"], ["Iron bars, sixty gold.", "The forge is hot today!"]),
                   "off": L(["کوره زمستون‌ها گرمم نگه می‌داره.", "یه فانوس خوب سیم مسی هم می‌خواد."], ["The forge keeps me warm in winter.", "A good lantern needs copper wire too."])},
    "tailor": {"work": L(["یه پیراهن نو همه‌چیز رو عوض می‌کنه!", "نخ پشمی رو خوب می‌خرم."], ["A new shirt changes everything!", "I pay well for wool yarn."]),
               "off": L(["پیش‌بند حسن همیشه دوده‌ایه!", "دارم یه شال می‌بافم."], ["Hassan's apron is always sooty!", "I'm knitting a scarf."])},
    "electrician": {"work": L(["سیم مسی، رولی چهل سکه.", "مراقب جعبه فیوز باش!"], ["Copper wire, forty a roll.", "Mind the breaker box!"]),
                    "off": L(["اگه برق رفت، صدام کن.", "النا توی بیمارستان کار می‌کنه."], ["If the power goes, call me.", "Elena works at the hospital."])},
    "mason": {"work": L(["سنگ ساختمونی، دونه‌ای سی سکه.", "مجسمه میدون کار منه."], ["Stone blocks, thirty each.", "I carved the square's statue."]),
              "off": L(["دستام همیشه خاکیه!", "دارا می‌خواد سنگ‌تراش بشه."], ["My hands are always dusty!", "Dara wants to be a mason."])},
    "jewel": {"work": L(["صدف‌ها جواهرات قشنگی می‌شن.", "یه انگشتر هدیه قشنگیه."], ["Shells make beautiful jewellery.", "A ring makes a lovely gift."]),
              "off": L(["امروز یه گردنبند تموم کردم.", "صدف‌های ساحل رو برام بیار!"], ["I finished a necklace today.", "Bring me shells from the beach!"])},
    "water": {"work": L(["مخزن این فصل پره.", "آب پاش‌ت رو توی اداره پر می‌کنم."], ["The reservoir is full this season.", "I'll refill your can at the office."]),
              "off": L(["آب سالم یعنی شهر سالم.", "زیبا شبکه برق رو می‌گردونه."], ["Clean water, healthy town.", "Ziba runs the power grid."])},
    "electricity": {"work": L(["اگه برق رفت، بیا پیش من.", "پست برق تمام روز وزوز می‌کنه."], ["If the power's out, come see me.", "The substation hums all day."]),
                    "off": L(["بابک آب شهر رو تأمین می‌کنه.", "امشب برق‌ها روشنه!"], ["Babak keeps the water flowing.", "The lights are on tonight!"])},
    "priest": {"work": L(["آرامش با تو باشه.", "زنگ کلیسا ساعت نه، دوازده و شش می‌زنه."], ["Peace be with you.", "The bell rings at nine, noon and six."]),
               "off": L(["آنا ابزارفروشی رو می‌گردونه.", "گروه کر امشب تمرین داره."], ["Anna runs the tool shop.", "The choir practises tonight."])},
    "tool": {"work": L(["ابزار بهتر، محصول بهتر.", "آب‌پاش مسی دوبرابر آب می‌گیره."], ["Better tools, better harvests.", "The copper can holds twice the water."]),
             "off": L(["توماس گروه کر رو دوست داره.", "امروز یه بیل نو فروختم."], ["Thomas loves the choir.", "Sold a new hoe today."])},
    "imam": {"work": L(["سلام علیکم.", "در مسجد همیشه به روی تو بازه."], ["Peace be upon you.", "The mosque is always open to you."]),
             "off": L(["باغ یوسف بهترین گل‌های رز رو داره.", "انصاف و مهربانی، پایه یه شهر خوبه."], ["My garden has the best roses.", "Fairness and kindness build a good town."])},
    "professor": {"work": L(["علم خاک واقعاً جذابه.", "دانشجوها توی بازار کمک می‌کنن."], ["Soil science is fascinating.", "Our students help at the market."]),
                  "off": L(["یه کتاب خوب درباره کشاورزی دارم.", "یوسف بهترین رزها رو داره."], ["I have a good book on farming.", "Yusuf grows the best roses."])},
}
GENERIC = {"work": L(["کار امروز زیاده!", "سرم شلوغه، ولی خوشحالم دیدمت."], ["Lots of work today!", "Busy, but glad to see you."]),
           "off": L(["شهرمون روز به روز قشنگ‌تر می‌شه.", "امروز روز خوبی بود."], ["Our town gets nicer every day.", "It was a good day."])}
FAMILY = L(["{name}، {rel}م، همیشه ازت تعریف می‌کنه.", "{rel}م {name} سلام رسوند."], ["{name}, my {rel}, always speaks well of you.", "My {rel} {name} says hello."])
RELATIONS = {"mother": L("مادر", "mother"), "father": L("پدر", "father"), "son": L("پسر", "son"), "daughter": L("دختر", "daughter"),
             "husband": L("همسر", "husband"), "wife": L("همسر", "wife"),
             "brother": L("برادر", "brother"), "sister": L("خواهر", "sister")}
FRIEND = [L(["تازه به شهر اومدی؟ خوش اومدی!"], ["You're new in town? Welcome!"]),
          L(["خوشحالم دوباره می‌بینمت."], ["Nice to see you again."]),
          L(["دوست خوبم! یه روز بیا خونه‌مون چایی."], ["My good friend! Come over for tea some day."]),
          L(["تو دیگه از خودمونی!"], ["You're one of us now!"]),
          L(["تو مثل خانواده‌ی مایی."], ["You're like family to us."])]
ILL_SELF = L(["سرما خوردم... آپچی! باید برم دکتر.", "حالم خوب نیست، فکر کنم سرما خوردم."], ["I've caught a cold... achoo! I should see the doctor.", "I don't feel well, I think it's a cold."])
ILL_PLAYER = L(["رنگت پریده! برو بیمارستان پیش دکتر {doctor}.", "سرما خوردی؟ دکتر {doctor} حالت رو خوب می‌کنه."], ["You look pale! See Dr. {doctor} at the hospital.", "Caught a cold? Dr. {doctor} will fix you up."])
HUNGRY = L(["گرسنه به نظر میای! یه غذای گرم بخور.", "امروز غذا خوردی؟ روزی یه وعده لازمه."], ["You look hungry! Have a warm meal.", "Have you eaten today? One meal a day at least."])
TIRED = L(["خسته به نظر میای، امشب زود بخواب.", "یه کم استراحت کن، سلامتی مهمه."], ["You look tired, sleep early tonight.", "Rest a little - health comes first."])
CLOSED = L(["الان بسته‌ایم؛ ساعت {hour} باز می‌کنیم.", "مغازه بسته‌ست، فردا ساعت {hour} بیا."], ["We're closed now; we open at {hour}.", "Shop's closed - come back at {hour}."])
NIGHT = L(["دیروقته، دارم می‌رم خونه.", "شب بخیر، فردا می‌بینمت."], ["It's late, I'm heading home.", "Good night, see you tomorrow."])
SNEEZE = L(["آپچی!", "اَپچه!"], ["Achoo!", "Atchoo!"])

base_dialogue = {"greetings": GREET, "chat_lines": CHAT, "chat_replies": REPLY, "player_greeting": PLAYER_GREET, "job_lines": JOB,
                 "generic_lines": GENERIC, "family_lines": FAMILY, "relations": RELATIONS, "friendship_lines": FRIEND,
                 "ill_self": ILL_SELF, "ill_player": ILL_PLAYER, "hungry_player": HUNGRY, "tired_player": TIRED,
                 "closed_lines": CLOSED, "night_lines": NIGHT, "sneeze": SNEEZE, "names_fa": NAMES_FA, "jobs_fa": JOBS_FA,
                 "places_fa": PLACES_FA}
brief = dict(base_dialogue)
brief["greetings"] = {k: {"fa": v["fa"][:1], "en": v["en"][:1]} for k, v in GREET.items()}
simple("dialogue", "DialogueStyle", "dialogue_style", [
    ("warm_village", "Warm village talk", "Chatty townsfolk: greeting + a line about their job (at work / off work) + family, friendship and health.",
     dict(base_dialogue, lines_per_talk=3)),
    ("brief", "Brief", "Short greetings, one line about their job.", dict(brief, lines_per_talk=2)),
], "warm_village")

# ------------------------------------------------------------------ friendship
LEVELS = [L("غریبه", "Stranger"), L("آشنا", "Acquaintance"), L("دوست", "Friend"), L("دوست صمیمی", "Good friend"), L("مثل خانواده", "Like family")]
simple("friendship", "FriendshipStyle", "friendship_style", [
    ("daily_talks", "Daily talks", "+10 for the first talk each day (+2 for a streak); no decay.",
     {"points_per_talk": 10, "streak_bonus": 2, "max_points": 100, "decay_per_day": 0, "level_points": pia(0, 20, 45, 70, 95),
      "level_names": LEVELS, "hearts": 10}),
    ("slow_burn", "Slow burn", "+6 per daily talk, -1 for each day you don't visit.",
     {"points_per_talk": 6, "streak_bonus": 1, "max_points": 100, "decay_per_day": 1, "level_points": pia(0, 20, 45, 70, 95),
      "level_names": LEVELS, "hearts": 10}),
], "daily_talks")

# ------------------------------------------------------------------ shop hours
STD = {"store": [8, 18], "supermarket": [8, 21], "grocery": [8, 21], "cafe": [7, 20], "carpenter": [8, 17], "blacksmith": [8, 17],
       "mason": [8, 17], "fruit_shop": [8, 19], "clothing": [9, 18], "jewelry": [9, 18], "tool_shop": [8, 18], "electrical": [8, 18],
       "water_office": [8, 16], "power_office": [8, 16], "city_hall": [9, 16], "post": [8, 16], "market": [7, 19], "workshop": [0, 24]}
LATE = dict(STD, **{"store": [7, 22], "supermarket": [7, 24], "grocery": [7, 24], "cafe": [6, 23], "fruit_shop": [7, 22], "market": [6, 22]})
def hrs(d): return {k: [float(v[0]), float(v[1])] for k, v in d.items()}
simple("shop_hours", "ShopHoursStyle", "shop_hours_style", [
    ("standard", "Standard hours", "Shops 8-17/18, supermarket 8-21, cafe 7-20, offices 8-16; hospital always open.",
     {"hours": hrs(STD), "default_hours": [8.0, 18.0], "always_open": psa("hospital", "doctor", "workshop", "home")}),
    ("late_night", "Late-night town", "Longer evening hours: supermarket until midnight, cafe 6-23.",
     {"hours": hrs(LATE), "default_hours": [8.0, 20.0], "always_open": psa("hospital", "doctor", "workshop", "home")}),
], "standard")

# ------------------------------------------------------------------ voices
simple("voices", "VoiceStyle", "voice_style", [
    ("blips", "Vowel blips", "Short synthesized vowel blips (a/e/i/o/u formants); women and children higher, men lower.",
     {"samples": psa(*["res://assets/audio/voice/blip_%s.ogg" % v for v in "aeiou"]), "man_pitch": 0.82, "woman_pitch": 1.28,
      "child_pitch": 1.7, "teen_pitch": 1.12, "elder_mult": 0.92, "syllable_jitter": 0.07, "person_jitter": 0.06,
      "syllable_seconds": 0.095, "max_syllables": 12, "volume_db": -9.0, "max_distance": 22.0}),
    ("hum", "Soft hum", "Softer, rounder humming blips, slower.",
     {"samples": psa(*["res://assets/audio/voice/hum_%d.ogg" % i for i in range(3)]), "man_pitch": 0.85, "woman_pitch": 1.25,
      "child_pitch": 1.6, "teen_pitch": 1.1, "elder_mult": 0.94, "syllable_jitter": 0.05, "person_jitter": 0.05,
      "syllable_seconds": 0.13, "max_syllables": 9, "volume_db": -11.0, "max_distance": 18.0}),
], "blips")

# ------------------------------------------------------------------ npc card
simple("npc_card", "NpcCardStyle", "npc_card_style", [
    ("parchment", "Parchment card", "Warm paper card with red hearts.",
     {"show_distance": 4.0, "bg_color": (0.98, 0.94, 0.84, 0.95), "ink_color": (0.22, 0.16, 0.1), "accent_color": (0.7, 0.3, 0.2),
      "heart_color": (0.88, 0.2, 0.3), "show_family": True, "show_health": True}),
    ("dark_glass", "Dark glass card", "Dark translucent card, gold accents.",
     {"show_distance": 4.5, "bg_color": (0.08, 0.1, 0.14, 0.88), "ink_color": (0.95, 0.95, 0.92), "accent_color": (0.95, 0.75, 0.3),
      "heart_color": (1.0, 0.4, 0.5), "show_family": True, "show_health": True}),
], "parchment")

# ------------------------------------------------------------------ needs
simple("needs", "NeedsStyle", "needs_style", [
    ("balanced", "Balanced", "Hunger -4/h, fatigue +4.5/h awake; one meal a day; tired or hungry hours risk a cold.",
     {"hunger_per_hour": 4.0, "fatigue_per_hour": 4.5, "exhausted_fatigue": 6.0, "hungry_below": 30.0, "tired_above": 70.0,
      "meals_per_day": 1, "skipped_meal_fatigue": 20.0, "ill_chance_tired": 0.05, "ill_chance_hungry": 0.05, "ill_chance_base": 0.0,
      "npc_ill_chance": 0.004, "npc_meal_hours": pia(7, 13, 20), "npc_doctor_hours": 1.5, "fee_mult": 1.0, "starving_speed": 0.85}),
    ("gentle", "Gentle", "Slower hunger and fatigue, lower illness risk, cheaper doctor.",
     {"hunger_per_hour": 2.5, "fatigue_per_hour": 3.0, "exhausted_fatigue": 3.0, "hungry_below": 25.0, "tired_above": 80.0,
      "meals_per_day": 1, "skipped_meal_fatigue": 10.0, "ill_chance_tired": 0.02, "ill_chance_hungry": 0.02, "ill_chance_base": 0.0,
      "npc_ill_chance": 0.002, "npc_meal_hours": pia(8, 13, 19), "npc_doctor_hours": 1.0, "fee_mult": 0.6, "starving_speed": 0.9}),
], "balanced")

# ------------------------------------------------------------------ illnesses (collection)
collection("illnesses", "IllnessDef", "illness_def", [
    ("cold", "Cold", "A common cold from too little sleep or food: sneezing, feeling unwell, slower.",
     {"name_fa": "سرماخوردگی", "symptoms_en": "sneezing, feeling unwell", "symptoms_fa": "عطسه، بی‌حالی", "speed_mult": 0.75,
      "stamina_regen_mult": 0.6, "sneeze_min": 8.0, "sneeze_max": 20.0, "days": 3, "fee": 80, "min_fatigue": 0.0, "max_hunger": 100.0,
      "severity": 1, "tint": (0.72, 0.86, 0.72)}),
    ("flu", "Flu", "Worn out AND starving: fever, sneezing, much slower.",
     {"name_fa": "آنفولانزا", "symptoms_en": "fever, sneezing, very weak", "symptoms_fa": "تب، عطسه، ضعف شدید", "speed_mult": 0.6,
      "stamina_regen_mult": 0.4, "sneeze_min": 6.0, "sneeze_max": 14.0, "days": 5, "fee": 150, "min_fatigue": 85.0, "max_hunger": 15.0,
      "severity": 2, "tint": (0.9, 0.7, 0.6)}),
], "cold")

# ------------------------------------------------------------------ ingredients (collection)
ING = [
    ("chicken", "Chicken", "مرغ", 45, "drumstick", "main", (0.95, 0.78, 0.66), "Fresh whole chicken pieces."),
    ("eggs", "Eggs", "تخم‌مرغ", 6, "egg", "main", (0.98, 0.95, 0.88), "Farm eggs, sold singly."),
    ("onion", "Onion", "پیاز", 5, "veg", "main", (0.9, 0.8, 0.6), "Yellow onion."),
    ("tomato_fresh", "Tomato (shop)", "گوجه‌فرنگی", 8, "veg", "main", (0.9, 0.2, 0.15), "Ripe tomato from the supermarket."),
    ("herbs", "Fresh herbs", "سبزی", 12, "leaf", "main", (0.25, 0.6, 0.25), "Parsley, coriander, dill - for kuku sabzi."),
    ("rice", "Rice", "برنج", 20, "grain", "main", (0.97, 0.96, 0.92), "Long-grain rice (one portion)."),
    ("salt", "Salt", "نمک", 2, "powder", "seasoning", (0.98, 0.98, 1.0), "A pinch of salt per dish."),
    ("spices", "Spices (advieh)", "ادویه", 6, "powder", "seasoning", (0.85, 0.55, 0.15), "Turmeric, saffron and advieh mix."),
]
collection("ingredients", "IngredientDef", "ingredient_def", [
    (i, n, d, {"name_fa": fa, "price": p, "sold_at": psa("grocery", "stall:produce") if shape in ("veg", "leaf") else psa("grocery"),
               "color": c, "shape": shape, "role": role})
    for (i, n, fa, p, shape, role, c, d) in ING], "chicken")

# ------------------------------------------------------------------ dishes (collection)
collection("dishes", "DishDef", "dish_def", [
    ("omelette", "Tomato Omelette", "Persian omlet: eggs scrambled with tomato and onion.",
     {"name_fa": "املت گوجه", "inputs": {"eggs": 2, "tomato_fresh": 1, "onion": 1}, "salt": 1, "spices": 1, "hunger": 60.0,
      "stamina": 40.0, "raw_color": (0.95, 0.6, 0.35), "cooked_color": (0.92, 0.55, 0.2), "sort_order": 0}),
    ("chelo_morgh", "Chelo Morgh", "Chicken with saffron rice and onion - a full meal.",
     {"name_fa": "چلو مرغ", "inputs": {"chicken": 1, "rice": 1, "onion": 1}, "salt": 1, "spices": 1, "hunger": 100.0,
      "stamina": 70.0, "raw_color": (0.95, 0.8, 0.7), "cooked_color": (0.8, 0.5, 0.2), "sort_order": 1}),
    ("kuku_sabzi", "Kuku Sabzi", "Herb frittata: eggs and lots of fresh herbs.",
     {"name_fa": "کوکو سبزی", "inputs": {"eggs": 2, "herbs": 1}, "salt": 1, "spices": 1, "hunger": 70.0,
      "stamina": 50.0, "raw_color": (0.35, 0.6, 0.3), "cooked_color": (0.2, 0.38, 0.15), "sort_order": 2}),
], "omelette")

# ------------------------------------------------------------------ cooking
def S(i, en, fa, minutes, sound, stamina=0.0):
    return {"id": i, "en": en, "fa": fa, "minutes": float(minutes), "sound": sound, "stamina": float(stamina)}
simple("cooking", "CookingStyle", "cooking_style", [
    ("home_style", "Home style (5 steps)", "Prepare (wash + chop), add salt, add spices, cook, eat - each by hand.",
     {"steps": [S("prepare", "Wash and chop", "شستن و خرد کردن", 10, "chop", 2), S("salt", "Add salt", "نمک زدن", 1, "sprinkle"),
                S("spices", "Add spices", "ادویه زدن", 1, "sprinkle"), S("cook", "Cook", "پختن", 25, "sizzle", 1),
                S("eat", "Eat", "خوردن", 15, "eat")], "auto_season": False, "seasoned_bonus": 10.0}),
    ("quick_cook", "Quick cook (3 steps)", "Prepare, cook, eat; salt and spices go in automatically.",
     {"steps": [S("prepare", "Prepare", "آماده کردن", 8, "chop", 2), S("cook", "Cook", "پختن", 20, "sizzle", 1),
                S("eat", "Eat", "خوردن", 15, "eat")], "auto_season": True, "seasoned_bonus": 0.0}),
], "home_style")

# ------------------------------------------------------------------ mosque dome fields (v5b polish)
for vid, shape, ribs, drum, rib in [("turquoise_dome", "onion", 16, 1.4, (0.95, 0.85, 0.45)), ("sandstone", "ribbed", 20, 1.2, (0.6, 0.45, 0.22))]:
    p = os.path.join(ROOT, "modules/mosque/%s.tres" % vid)
    s = open(p, encoding="utf-8").read()
    s = re.sub(r"\n(dome_shape|dome_ribs|drum_height|rib_color) = [^\n]*", "", s)
    s = s.rstrip("\n") + "\n" + "\n".join(["dome_shape = %s" % val(shape), "dome_ribs = %d" % ribs, "drum_height = %s" % val(drum),
                                           "rib_color = %s" % val(rib)]) + "\n"
    open(p, "w", encoding="utf-8").write(s)

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v5b modules written: fonts, dialogue, friendship, shop_hours, voices, npc_card, needs, illnesses, ingredients, dishes, cooking (+ mosque dome)")
