#!/usr/bin/env python3
"""Generates the v7a module style scripts (modules/<type>/<script>.gd), the
module .tres variants and registers them in data/asset_modules.json:
  backstories, kids, conflicts, possession, fire, outages, city_fund
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
# Reuse the v6b helpers (style_script, emit...) without re-running v6b's tables.
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, psa, config, config_path, V2, V3 = (ns["style_script"], ns["emit"], ns["psa"], ns["config"],
                                                      ns["config_path"], ns["V2"], ns["V3"])

# ====================================================================== 1. backstories
style_script("backstories", "backstory_style", "BackstoryStyle",
    "v7a townspeople backstories: every resident has talents, a current problem\nand a past hardship (kept gentle), plus how they speak about their spouse /\nfamily and their job. With WorldMemory (what they remember about you) this\nshapes their dialogue and the backstory part of the NPC card.\nConsumers: Backstories, Dialogue.talk_lines, NpcCard.", [
    ("people", "Dictionary", "{}", "full name -> {talents_en, talents_fa, problem_en, problem_fa, past_en, past_fa, hope_en, hope_fa}"),
    ("memory_lines", "int", "1", "remembered events mentioned per talk"),
    ("story_chance", "float", "0.5", "chance a talk mentions their problem / past / hope"),
    ("show_on_card", "bool", "true", ""),
])
P = {}
def bs(full, ten, tfa, pen, pfa, aen, afa, hen, hfa):
    P[full] = {"talents_en": ten, "talents_fa": tfa, "problem_en": pen, "problem_fa": pfa,
               "past_en": aen, "past_fa": afa, "hope_en": hen, "hope_fa": hfa}
bs("Mina Karimi", "latte art, remembering every regular's order", "طراحی روی قهوه، یادش می‌ماند هر مشتری چه می‌خورد",
   "the cafe's old espresso machine keeps breaking", "دستگاه قهوه‌ی قدیمی کافه مدام خراب می‌شود",
   "she lost her first cafe to a flood years ago and started again here", "سال‌ها پیش کافه‌ی اولش را سیل برد و اینجا از نو شروع کرد",
   "to open a small bakery corner", "یک گوشه‌ی کوچک نانوایی راه بیندازد")
bs("Reza Karimi", "knows every street by heart, fixes bicycles", "همه‌ی کوچه‌ها را از بر است، دوچرخه تعمیر می‌کند",
   "his knee hurts on the long delivery rounds", "در مسیرهای طولانی پست، زانویش درد می‌گیرد",
   "he grew up without a father and worked since he was fourteen", "بی‌پدر بزرگ شد و از چهارده‌سالگی کار کرد",
   "that Ali finishes school with good marks", "علی مدرسه را با نمره‌ی خوب تمام کند")
bs("Ali Karimi", "fast on his bike, draws animals", "با دوچرخه تند می‌رود، حیوان نقاشی می‌کند",
   "maths homework", "تکلیف ریاضی", "he once got lost at the beach and was found by Kian", "یک بار در ساحل گم شد و کیان پیدایش کرد",
   "a sheep of his own", "یک گوسفند مال خودش")
bs("Dariush Rahimi", "calm in a crisis, good at settling quarrels", "در بحران آرام است، دعواها را خوب فیصله می‌دهد",
   "too few officers for a growing town", "برای شهری که بزرگ می‌شود، پلیس کم است",
   "he was injured stopping a robbery when he was young", "در جوانی موقع جلوگیری از یک دزدی زخمی شد",
   "a town where nobody needs to lock their door", "شهری که هیچ‌کس لازم نباشد درش را قفل کند")
bs("Leila Rahimi", "steady hands, explains things simply", "دست‌های مطمئن، ساده توضیح می‌دهد",
   "the hospital needs more medicine than the budget allows", "بیمارستان بیشتر از بودجه‌اش دارو لازم دارد",
   "she studied by candlelight in a village without power", "در روستایی بی‌برق زیر نور شمع درس خواند",
   "a free clinic day every week", "هر هفته یک روز درمان رایگان")
bs("Sima Rahimi", "chemistry, plays the setar", "شیمی، سه‌تار می‌زند", "exam stress", "استرس امتحان",
   "she failed her first entrance exam and tried again", "بار اول در کنکور قبول نشد و دوباره تلاش کرد",
   "to become a surgeon like her mother hoped", "جراح شود، همان‌طور که مادرش امید دارد")
bs("Sara Ahmadi", "bookkeeping, haggling with suppliers", "حسابداری، چانه‌زدن با فروشنده‌ها",
   "a customer still owes her money from last month", "یک مشتری هنوز پول ماه پیش را بدهکار است",
   "she took over the shop when her father fell ill", "وقتی پدرش بیمار شد مغازه را به دست گرفت",
   "to pay off the shop loan this year", "امسال وام مغازه را تسویه کند")
bs("Parvin Ahmadi", "storytelling, Persian poetry", "قصه‌گویی، شعر فارسی", "lonely evenings since she retired", "از وقتی بازنشسته شده، عصرها تنهاست",
   "she was widowed young and raised Sara alone", "جوان بیوه شد و سارا را تنها بزرگ کرد",
   "to teach the town's children to read Hafez", "به بچه‌های شهر حافظ‌خوانی یاد بدهد")
bs("Omid Hosseini", "patient with paperwork, good with numbers", "حوصله‌ی کاغذبازی دارد، با عدد خوب است",
   "people blame City Hall for everything", "مردم همه چیز را تقصیر شهرداری می‌دانند",
   "his family's house burned down when he was a boy", "در بچگی خانه‌ی خانواده‌اش آتش گرفت",
   "a proper fire station and a park for the kids", "یک ایستگاه آتش‌نشانی درست و یک پارک برای بچه‌ها")
bs("Nasrin Hosseini", "quick at the till, remembers prices", "با صندوق سریع است، قیمت‌ها یادش می‌ماند",
   "long shifts leave little time for Arman", "شیفت‌های طولانی وقت کمی برای آرمان می‌گذارد",
   "she moved here alone from the south with one suitcase", "با یک چمدان تنها از جنوب به اینجا آمد",
   "a family trip to the Caspian", "یک سفر خانوادگی به شمال")
bs("Arman Hosseini", "football, building kites", "فوتبال، ساختن بادبادک", "the older boys tease him", "پسرهای بزرگ‌تر اذیتش می‌کنند",
   "he broke his arm falling from a tree last year", "پارسال از درخت افتاد و دستش شکست", "a real football pitch", "یک زمین فوتبال واقعی")
bs("Kian Moradi", "reads the sea and the weather", "دریا و هوا را می‌خواند", "fewer fish near the shore every year", "هر سال ماهی کمتری نزدیک ساحل است",
   "a storm once wrecked his father's boat", "یک بار طوفان قایق پدرش را شکست", "a bigger boat with Shirin", "با شیرین یک قایق بزرگ‌تر بخرند")
bs("Shirin Moradi", "arranging fruit beautifully, making jam", "چیدن زیبای میوه، مربا پختن", "the fruit spoils fast in summer", "میوه در تابستان زود خراب می‌شود",
   "her family's orchard dried up in a drought", "باغ خانواده‌اش در خشکسالی خشک شد", "to sell her jam at the market", "مربایش را در بازار بفروشد")
bs("Bahram Tehrani", "joinery, carving, rebuilding roofs", "نجاری، کنده‌کاری، بازسازی سقف", "his apprentice left for the city", "شاگردش به شهر رفت",
   "he rebuilt half the village after the old earthquake", "بعد از زلزله‌ی قدیمی نصف روستا را دوباره ساخت", "to train a young carpenter", "یک نجار جوان تربیت کند")
bs("Golnar Tehrani", "teaching, calligraphy", "معلمی، خوشنویسی", "too many children in one classroom", "بچه‌های زیادی در یک کلاس",
   "she and Bahram lost everything in the earthquake and started over", "با بهرام در زلزله همه چیز را از دست دادند و از نو شروع کردند",
   "a small library in the square", "یک کتابخانه‌ی کوچک در میدان")
bs("Hassan Jafari", "forging, sharpening anything", "آهنگری، تیز کردن هر چیزی", "his lungs are tired from the forge smoke", "ریه‌هایش از دود کوره خسته است",
   "his workshop caught fire once from a stray spark", "یک بار جرقه‌ای کارگاهش را آتش زد", "to retire and grow pomegranates", "بازنشسته شود و انار بکارد")
bs("Maryam Jafari", "embroidery, mending", "گلدوزی، وصله‌کاری", "her eyesight is weakening", "چشم‌هایش ضعیف می‌شود",
   "she sewed for others to keep the family going in hard years", "در سال‌های سخت برای دیگران دوخت تا خانواده سر پا بماند",
   "to teach girls in town to sew", "به دخترهای شهر خیاطی یاد بدهد")
bs("Navid Sadeghi", "wiring, fixing radios", "سیم‌کشی، تعمیر رادیو", "storms keep knocking out the lines", "طوفان‌ها مدام خط برق را قطع می‌کنند",
   "he got a bad shock as an apprentice and is careful ever since", "در شاگردی برق شدیدی گرفت و از آن به بعد خیلی محتاط است",
   "underground cables for the whole town", "کابل زیرزمینی برای کل شهر")
bs("Elena Sadeghi", "calm bedside manner, speaks three languages", "آرامش کنار بیمار، سه زبان بلد است", "night shifts", "شیفت شب",
   "she came here as a volunteer after a disaster and stayed for Navid", "بعد از یک حادثه به‌عنوان داوطلب آمد و به خاطر نوید ماند",
   "to train the town in first aid", "به مردم شهر کمک‌های اولیه یاد بدهد")
bs("Farhad Rostami", "stone walls, strong as an ox", "دیوار سنگی، زورش مثل گاو است", "his back after lifting stones all day", "کمرش بعد از یک روز سنگ بلند کردن",
   "he lost his savings to a dishonest partner", "پس‌اندازش را به یک شریک نادرست باخت", "to build a stone bridge over the river", "یک پل سنگی روی رودخانه بسازد")
bs("Laleh Rostami", "a fine eye for gems, drawing designs", "چشم دقیق برای سنگ‌های قیمتی، طراحی", "Farhad's old partner still owes them money", "شریک قدیمی فرهاد هنوز به آن‌ها بدهکار است",
   "she sold her own jewellery to keep the house", "جواهرات خودش را فروخت تا خانه را نگه دارد", "her own designs in a big city shop", "طرح‌هایش در یک مغازه‌ی بزرگ شهر")
bs("Dara Rostami", "climbing, hide-and-seek", "بالا رفتن، قایم‌باشک", "he is scared of the dark", "از تاریکی می‌ترسد",
   "he was in hospital with a high fever as a baby", "نوزاد بود که با تب شدید در بیمارستان بستری شد", "a red bicycle", "یک دوچرخه‌ی قرمز")
bs("Babak Nouri", "pipes, pumps, clean water", "لوله، پمپ، آب سالم", "old pipes leak under Maple St", "لوله‌های قدیمی زیر خیابان افرا نشت دارند",
   "he worked through a drought bringing water by truck", "در یک خشکسالی با تانکر آب می‌رساند", "a water tower for the town", "یک برج آب برای شهر")
bs("Ziba Nouri", "running the grid, quick decisions", "اداره‌ی شبکه‌ی برق، تصمیم‌های سریع", "not enough budget for spare transformers", "بودجه برای ترانس یدکی کافی نیست",
   "she kept a hospital lit with a generator through a long blackout", "در یک خاموشی طولانی بیمارستان را با ژنراتور روشن نگه داشت",
   "solar panels on City Hall", "پنل خورشیدی روی شهرداری")
bs("Thomas Bell", "listening, singing", "گوش دادن، آواز", "the church roof leaks", "سقف کلیسا چکه می‌کند",
   "he came from far away and learned Persian slowly", "از راه دور آمد و فارسی را آرام آرام یاد گرفت", "neighbours of every faith sharing a meal", "همسایه‌ها از هر دینی سر یک سفره")
bs("Anna Bell", "knows every tool, gardening", "همه‌ی ابزارها را می‌شناسد، باغبانی", "sales are slow this season", "فروش این فصل کساد است",
   "she nursed Thomas through a long illness", "در یک بیماری طولانی از توماس پرستاری کرد", "a community garden", "یک باغچه‌ی همگانی")
bs("Yusuf Haddad", "calm advice, beautiful recitation", "نصیحت آرام، قرائت زیبا", "young people are busy and visit less", "جوان‌ها گرفتارند و کمتر سر می‌زنند",
   "he lost his brother young and found peace in faith", "برادرش را جوان از دست داد و در ایمان آرامش یافت", "that neighbours help each other", "همسایه‌ها به هم کمک کنند")
bs("Amina Haddad", "history, debate", "تاریخ، مناظره", "the university needs more books", "دانشگاه کتاب بیشتری لازم دارد",
   "she was the first woman in her family to go to university", "اولین زن خانواده‌اش بود که دانشگاه رفت", "a scholarship for the town's girls", "یک بورسیه برای دخترهای شهر")
emit("backstories", "BackstoryStyle", "backstory_style", [
    ("town_stories", "Town life stories", "28 residents with talents, a current problem, a past hardship and a hope; memories of you come up in talks.",
     {"name_fa": "داستان زندگی مردم شهر", "people": P}),
    ("quiet_stories", "Private townsfolk", "Same stories, but people rarely share them (only on the card).",
     {"name_fa": "مردم کم‌حرف", "people": P, "story_chance": 0.1, "memory_lines": 1}),
], "town_stories")

# ====================================================================== 2. kids
style_script("kids", "kids_style", "KidsStyle",
    "v7a children's free time: after school the town's kids ride bikes round the\nsquare and streets, play tag, chat, and sometimes ring a doorbell and run off\n(the owner comes out and grumbles). Consumer: KidsPlay.", [
    ("play_hours", "Vector2", "Vector2(14.5, 19.0)", "outside after school (weekends from 10)"),
    ("bike_loop", "Array", "[]", "V2 points round the square"),
    ("bike_speed", "float", "4.2", "m/s"), ("bike_colors", "Array", "[]", ""),
    ("mischief_chance", "float", "0.25", "chance per hour of ring-and-run"),
    ("chat_lines", "Array", "[]", "{en, fa}"), ("mischief_lines", "Array", "[]", "{en, fa} said by the grumbling owner"),
    ("kid_lines", "Array", "[]", "{en, fa} giggles while running off"),
    ("max_age", "int", "13", "who counts as a kid"),
])
LOOP = [V2(0, -38.5), V2(11.5, -45), V2(13, -50), V2(11.5, -55.5), V2(0, -61.5), V2(-11.5, -55.5), V2(-13, -50), V2(-11.5, -45)]
KID_CHAT = [{"en": "Race you to the fountain!", "fa": "تا فواره مسابقه!"}, {"en": "My bike is faster!", "fa": "دوچرخه‌ی من تندتره!"},
            {"en": "Tag, you're it!", "fa": "گرفتمت، تو گرگی!"}, {"en": "Let's play hide-and-seek!", "fa": "بیا قایم‌باشک بازی کنیم!"},
            {"en": "Did you see the fire truck?", "fa": "ماشین آتش‌نشانی رو دیدی؟"}]
OWNER = [{"en": "Who rang the bell?! Kids again...", "fa": "کی زنگ زد؟! باز این بچه‌ها..."},
         {"en": "I'll tell your parents!", "fa": "به پدر و مادرت می‌گم!"}]
GIGGLE = [{"en": "Run!", "fa": "فرار کن!"}, {"en": "Hee hee!", "fa": "هی هی!"}]
emit("kids", "KidsStyle", "kids_style", [
    ("after_school", "After-school play", "Kids bike round the square 14:30-19:00, play tag and chat; ~25%/h ring-and-run mischief.",
     {"name_fa": "بازی بعد از مدرسه", "bike_loop": LOOP, "bike_colors": [(0.85, 0.15, 0.12), (0.15, 0.4, 0.8), (0.2, 0.65, 0.3), (0.95, 0.75, 0.15)],
      "chat_lines": KID_CHAT, "mischief_lines": OWNER, "kid_lines": GIGGLE}),
    ("well_behaved", "Well-behaved kids", "Bikes and games, no doorbell pranks.",
     {"name_fa": "بچه‌های مؤدب", "bike_loop": LOOP, "bike_colors": [(0.85, 0.15, 0.12), (0.15, 0.4, 0.8), (0.2, 0.65, 0.3)],
      "chat_lines": KID_CHAT, "mischief_lines": OWNER, "kid_lines": GIGGLE, "mischief_chance": 0.0, "bike_speed": 3.5}),
], "after_school")

# ====================================================================== 3. conflicts
style_script("conflicts", "conflict_style", "ConflictStyle",
    "v7a social conflict: sometimes two townspeople argue - red heated bubbles and\nsharp gestures - over an unpaid debt, a theft report or noise. Hot-tempered\npeople argue more. The player can calm them (E: talk it out) or the police\npatrol arrives and settles it. Consumer: Conflicts.", [
    ("reasons", "Dictionary", "{}", "reason -> {lines: [{en, fa}], replies: [{en, fa}], calm: {en, fa}}"),
    ("tempers", "Dictionary", "{}", "full name -> 0..1 (default 0.3)"),
    ("chance_per_hour", "float", "0.18", ""), ("duration", "float", "40.0", "seconds before police settle it"),
    ("police_after", "float", "18.0", "seconds before the patrol is called"),
    ("calm_friendship", "int", "15", "friendship points with both for calming"),
    ("hours", "Vector2", "Vector2(9, 21)", ""),
])
REASONS = {
    "debt": {"lines": [{"en": "You still owe me 200 gold!", "fa": "هنوز دویست سکه به من بدهکاری!"}, {"en": "A month! You promised a week!", "fa": "یک ماه! قول داده بودی یک هفته!"}],
             "replies": [{"en": "I'll pay, I said I'll pay!", "fa": "می‌دم، گفتم که می‌دم!"}, {"en": "Times are hard, be patient!", "fa": "اوضاع سخته، صبر کن!"}],
             "calm": {"en": "They agree on paying in three parts.", "fa": "قرار شد بدهی در سه قسط پرداخت شود."}},
    "theft": {"lines": [{"en": "Someone took fruit from my garden - was it you?!", "fa": "یکی از باغم میوه چیده - تو بودی؟!"}, {"en": "I saw you near my fence!", "fa": "دیدمت کنار حصار من!"}],
              "replies": [{"en": "How dare you accuse me!", "fa": "چطور جرئت می‌کنی به من تهمت بزنی!"}, {"en": "I was at work all day!", "fa": "من تمام روز سر کار بودم!"}],
              "calm": {"en": "They agree to let the police check the report.", "fa": "قرار شد پلیس گزارش را بررسی کند."}},
    "noise": {"lines": [{"en": "Your music kept us up all night!", "fa": "صدای موسیقیت تمام شب نگذاشت بخوابیم!"}, {"en": "Hammering at six in the morning?!", "fa": "ساعت شش صبح چکش‌کاری؟!"}],
              "replies": [{"en": "It's my house, I'll do what I like!", "fa": "خونه‌ی خودمه، هر کاری بخوام می‌کنم!"}, {"en": "It was only one evening!", "fa": "فقط یک شب بود!"}],
              "calm": {"en": "Quiet hours after 22:00 - they shake hands.", "fa": "بعد از ساعت ده شب سکوت - دست دادند."}},
}
TEMPERS = {"Farhad Rostami": 0.8, "Hassan Jafari": 0.7, "Sara Ahmadi": 0.6, "Kian Moradi": 0.55, "Reza Karimi": 0.5,
           "Bahram Tehrani": 0.45, "Laleh Rostami": 0.5, "Yusuf Haddad": 0.05, "Thomas Bell": 0.05, "Leila Rahimi": 0.15, "Dariush Rahimi": 0.1}
emit("conflicts", "ConflictStyle", "conflict_style", [
    ("street_arguments", "Street arguments", "Debts, theft reports and noise cause occasional arguments; calm them or the police step in.",
     {"name_fa": "دعواهای خیابانی", "reasons": REASONS, "tempers": TEMPERS}),
    ("peaceful_town", "Peaceful town", "Arguments are rare and short.",
     {"name_fa": "شهر آرام", "reasons": REASONS, "tempers": {}, "chance_per_hour": 0.05, "duration": 25.0, "police_after": 12.0}),
], "street_arguments")

# ====================================================================== 4. possession
style_script("possession", "possession_style", "PossessionStyle",
    "v7a play as a townsperson (local, single player): F2 next to a resident takes\nover their body - their name, job, home and memories stay theirs. Free\nchoices: dig, demolish their own house with the axe (rebuild cost), start a\nfire. Destructive acts ask for confirmation (Persian dialog) and have\nconsequences (fines to the city fund, police, neighbours remember).\nConsumer: Possession.", [
    ("rebuild_cost", "int", "600", "gold the household pays to rebuild a demolished house"),
    ("arson_fine", "int", "400", "plus damages"), ("demolish_days", "int", "3", "rebuild time"),
    ("allow", "PackedStringArray", "PackedStringArray()", "allowed acts: dig, demolish, fire"),
    ("max_distance", "float", "3.0", "m to the resident"),
])
emit("possession", "PossessionStyle", "possession_style", [
    ("free_choice", "Free choice", "Dig, demolish your own house (600 G rebuild) or start a fire (400 G fine + damages).",
     {"name_fa": "انتخاب آزاد", "allow": psa("dig", "demolish", "fire")}),
    ("gentle", "Gentle roles", "Only digging - no destructive acts.", {"name_fa": "نقش‌های آرام", "allow": psa("dig")}),
], "free_choice")

# ====================================================================== 5. fire
style_script("fire", "fire_style", "FireStyle",
    "v7a fire + emergencies: a fire station with a red fire truck and a crew of\nthree. A fire grows on a building, spreads slowly to nearby flammable things\n(houses, trees, wood piles), and damages what it burns. The truck drives out\nwith lights, the crew hoses it down. Burned buildings are rebuilt over days by\nthe carpenter and the mason. Whoever caused it pays a fine + damages (city\nfund, police report, the ambulance checks the residents). Consumer: FireService.", [
    ("station_pos", "Vector2", "Vector2(46.5, -39.5)", ""), ("station_yaw", "float", "180.0", ""),
    ("truck_base", "Vector2", "Vector2(46.5, -46.1)", ""), ("truck_speed", "float", "10.0", ""), ("crew", "int", "3", ""),
    ("grow_seconds", "float", "25.0", "until fully ablaze"), ("spread_radius", "float", "11.0", "m"),
    ("spread_seconds", "float", "45.0", "a full fire ignites a neighbour after this"),
    ("extinguish_seconds", "float", "12.0", "hosing time"), ("damage_per_second", "float", "0.012", "0..1 per second at full fire"),
    ("rebuild_days", "int", "2", ""), ("fine", "int", "300", "fine for causing a fire"),
    ("damage_cost", "int", "800", "damages at 100% burned"),
    ("truck_color", "Color", "Color(0.82, 0.08, 0.06)", ""),
])
emit("fire", "FireStyle", "fire_style", [
    ("town_fire_service", "Town fire service", "Fire station on Main St, 3 firefighters, fire spreads slowly (11 m), rebuilt in 2 days.",
     {"name_fa": "آتش‌نشانی شهر"}),
    ("dry_summer", "Dry summer", "Fires spread faster and further; rebuilding takes 3 days.",
     {"name_fa": "تابستان خشک", "spread_radius": 15.0, "spread_seconds": 25.0, "grow_seconds": 15.0, "rebuild_days": 3}),
], "town_fire_service")

# ====================================================================== 6. outages
style_script("outages", "outage_style", "OutageStyle",
    "v7a power outages: a storm with strong wind can bring the lines down, and an\noccasional mild earthquake (camera shake, things fall off shelves) can too.\nHomes switch to candles and lanterns (v4 electricity) and life goes on; the\nelectricity office crew drives out and fixes it after a few hours.\nConsumer: Outages.", [
    ("storm_cut_chance", "float", "0.5", "per storm day"), ("quake_chance", "float", "0.06", "per day"),
    ("quake_cut_chance", "float", "0.6", ""), ("quake_seconds", "float", "6.0", ""), ("quake_strength", "float", "0.35", "m camera shake"),
    ("repair_hours", "float", "3.0", "game hours until the crew restores power"),
    ("wind_strength", "float", "1.0", "tree sway during storms"),
    ("crew_lines", "Array", "[]", "{en, fa}"),
])
CREW = [{"en": "Line down on Maple St - on our way!", "fa": "خط خیابان افرا قطع شده - داریم می‌رسیم!"},
        {"en": "Power will be back soon, stay safe.", "fa": "برق به‌زودی وصل می‌شود، مراقب باشید."}]
emit("outages", "OutageStyle", "outage_style", [
    ("storms_and_quakes", "Storms and mild quakes", "Storms cut power half the time; ~6%/day mild quake; crew fixes it in 3 h.",
     {"name_fa": "طوفان و زلزله‌ی خفیف", "crew_lines": CREW}),
    ("stable_grid", "Stable grid", "Underground lines: storms rarely cut power, quakes very rare, fixed in 1.5 h.",
     {"name_fa": "شبکه‌ی پایدار", "storm_cut_chance": 0.1, "quake_chance": 0.02, "repair_hours": 1.5, "crew_lines": CREW}),
], "storms_and_quakes")

# ====================================================================== 7. city fund
style_script("city_fund", "city_fund_style", "CityFundStyle",
    "v7a municipality fund: every fine (theft, fire, damages, speeding) goes into\nthe city fund, shown at City Hall and on the market prices board. The fund\npays the doctor subsidy and public works that change the town over days -\nnew benches, streetlights, flower beds, a small park. City Hall panel (F4 /\nthe notice board at City Hall) shows income, spending and projects.\nConsumer: CityFund (CityState autoload).", [
    ("start_balance", "int", "500", ""), ("projects", "Array", "[]", "{id, en, fa, cost, days, kind, pos: [V2...]}"),
    ("doctor_subsidy", "float", "0.3", "share of a doctor's fee the fund pays"),
    ("subsidy_cap", "int", "60", "per visit"), ("daily_tax", "int", "40", "small daily income from shops"),
    ("speeding_fine", "int", "50", ""), ("speed_limit", "float", "12.0", "m/s"),
])
PROJECTS = [
    {"id": "benches", "en": "Park benches on Main St", "fa": "نیمکت‌های خیابان اصلی", "cost": 300, "days": 1, "kind": "bench",
     "pos": [V2(-20, -44.3), V2(-36, -44.3), V2(22, -44.3), V2(40, -55.7)]},
    {"id": "streetlights", "en": "New streetlights on Maple St", "fa": "چراغ‌های تازه‌ی خیابان افرا", "cost": 450, "days": 1, "kind": "streetlight",
     "pos": [V2(-30, -84.9), V2(-10, -84.9), V2(10, -84.9), V2(30, -84.9)]},
    {"id": "flowerbeds", "en": "Flower beds by City Hall", "fa": "باغچه‌های گل کنار شهرداری", "cost": 250, "days": 1, "kind": "flowerbed",
     "pos": [V2(7, -57.5), V2(22, -57.5), V2(-7.5, -57.8)]},
    {"id": "small_park", "en": "A small park with trees and a slide", "fa": "یک پارک کوچک با درخت و سرسره", "cost": 900, "days": 2, "kind": "park",
     "pos": [V2(5.5, -36.0)]},
]
emit("city_fund", "CityFundStyle", "city_fund_style", [
    ("municipal_fund", "Municipal fund", "Fines + a small shop tax fund benches, streetlights, flower beds and a small park; 30% doctor subsidy.",
     {"name_fa": "صندوق شهرداری", "projects": PROJECTS}),
    ("lean_budget", "Lean budget", "No shop tax, 15% doctor subsidy; projects cost more.",
     {"name_fa": "بودجه‌ی محدود", "projects": [dict(p, cost=int(p["cost"] * 1.4)) for p in PROJECTS], "doctor_subsidy": 0.15, "daily_tax": 0, "start_balance": 200}),
], "municipal_fund")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7a modules written")


# ---------------------------------------------------------------- ui_text (v7a)
# Persian for the new controls category / rows / note and prompts.
V7A_PHRASES = {
    "Town Life": "زندگی شهری",
    "Play as the townsperson next to you / return (F2)": "بازی در نقش شهروند کنارت / بازگشت (F2)",
    "While playing a resident: demolish your own house (asks first)": "در نقش یک شهروند: خراب کردن خانه‌ی خودت (اول می‌پرسد)",
    "While playing a resident: start a fire (asks first)": "در نقش یک شهروند: آتش روشن کردن (اول می‌پرسد)",
    "City Hall panel: city fund, fines, public works": "پنل شهرداری: صندوق شهر، جریمه‌ها، کارهای عمومی",
    "read the city fund board": "خواندن تابلوی صندوق شهر",
    "Stand next to a townsperson and press F2 to live their life for a while: you keep their name, job, home and memories. Destructive choices ask first and have consequences - fines go to the city fund, the police take a report, people remember. Press E on two people arguing to calm them down. The fire brigade (125) and the electricity crew answer emergencies.":
        "کنار یک شهروند بایست و F2 را بزن تا مدتی زندگی او را بازی کنی: نام، شغل، خانه و خاطراتش با او می‌ماند. کارهای ویرانگر اول تأیید می‌خواهند و پیامد دارند - جریمه به صندوق شهر می‌رود، پلیس گزارش می‌گیرد و مردم یادشان می‌ماند. کنار دو نفر که دعوا می‌کنند E بزن تا آرامشان کنی. آتش‌نشانی (۱۲۵) و گروه برق به حادثه‌ها می‌رسند.",
}


def patch_ui_text_v7a():
    import json, re
    for fn in ("farsi.tres", "farsi_short.tres"):
        path = os.path.join(ROOT, "modules", "ui_text", fn)
        src = open(path, encoding="utf-8").read()
        m = re.search(r"^phrases = (\{.*\})$", src, re.M)
        cur = json.loads(m.group(1))
        cur.update(V7A_PHRASES)
        line = "phrases = " + json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
        src = src[:m.start()] + line + src[m.end():]
        open(path, "w", encoding="utf-8").write(src)
    print("ui_text: +%d v7a phrases" % len(V7A_PHRASES))


patch_ui_text_v7a()
