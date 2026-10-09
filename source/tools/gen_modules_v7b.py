#!/usr/bin/env python3
"""Generates the v7b module style scripts (modules/<type>/<script>.gd), the
module .tres variants and registers them in data/asset_modules.json:
  chatter, cafe, mechanic, driving, passengers, camping, newspaper,
  personalities, voice_profiles   (+ ui_text phrases for the new controls)
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, psa, config, config_path, V2, V3 = (ns["style_script"], ns["emit"], ns["psa"], ns["config"],
                                                      ns["config_path"], ns["V2"], ns["V3"])


def L(en, fa):
    return {"en": en, "fa": fa}


# ====================================================================== 1. chatter
style_script("chatter", "chatter_style", "ChatterStyle",
    "v7b chattier town: townspeople make small spontaneous remarks, react to what\nhappens (fires, outages, weather, fines, public works, cafe fights, your\ndriving / horn / passengers) and have short back-and-forth chats you can\noverhear. Small unobtrusive bubbles (Persian by default) and an optional\nchat log (key 5). Consumers: Chatter, ChatLogPanel.", [
    ("remark_interval", "Vector2", "Vector2(22.0, 45.0)", "seconds between spontaneous remarks near you"),
    ("overhear_interval", "Vector2", "Vector2(35.0, 70.0)", "seconds between overheard chats"),
    ("hear_radius", "float", "18.0", "m: who can remark / be overheard"),
    ("bubble_font", "int", "34", "small chatter bubble font size"),
    ("bubble_seconds", "float", "3.6", ""),
    ("react_chance", "float", "0.85", "chance someone nearby reacts to an event"),
    ("remarks", "Dictionary", "{}", "kind -> [{en, fa}] (idle_morning, idle_evening, rain, storm, snow, heatwave, sunny, fire, outage, power_back, quake, project, project_done, fine, argument, cafe_fight, player_fast, player_horn, player_possess, passenger, newspaper, camping, night_no_lights)"),
    ("dialogues", "Array", "[]", "[{topic, lines: [{en, fa}...]}] spoken alternately by two people"),
    ("log_size", "int", "40", "lines kept in the chat log"),
    ("log_default", "bool", "false", "chat log visible at start"),
])
R = {
    "idle_morning": [L("Good morning! Fresh bread at the market today.", "صبح بخیر! امروز نان تازه در بازار هست."),
                     L("I slept well - the air was cool last night.", "دیشب خوب خوابیدم - هوا خنک بود."),
                     L("Time for a walk before work.", "قبل از کار یک پیاده‌روی بچسبد."),
                     L("Breakfast first, then the day.", "اول صبحانه، بعد کار و زندگی.")],
    "idle_evening": [L("What a long day... tea, anyone?", "چه روز درازی... کسی چای می‌خورد؟"),
                     L("The terrace cafe has music tonight.", "امشب کافه‌ی تراس موسیقی دارد."),
                     L("I'm off home, the kids are waiting.", "می‌روم خانه، بچه‌ها منتظرند."),
                     L("Look at that sunset!", "غروب را ببین!")],
    "rain": [L("Did anyone bring an umbrella?", "کسی چتر آورده؟"), L("Good rain for the gardens.", "باران خوبی برای باغچه‌هاست."),
             L("My shoes are soaked!", "کفش‌هایم خیس آب شد!")],
    "storm": [L("Hold on to your hat - what wind!", "کلاهت را محکم بگیر - چه بادی!"), L("Stay away from the power lines.", "از سیم‌های برق دور بمانید."),
              L("I hope the boats are tied up.", "امیدوارم قایق‌ها را بسته باشند.")],
    "snow": [L("Snow! The kids will be happy.", "برف! بچه‌ها خوشحال می‌شوند."), L("Careful, the street is slippery.", "مراقب باش، خیابان لیز است.")],
    "heatwave": [L("So hot - drink water, everyone!", "چه گرمایی - همه آب بخورید!"), L("I'll stay in the shade today.", "امروز زیر سایه می‌مانم.")],
    "sunny": [L("Lovely weather today.", "امروز هوا عالی است."), L("Perfect day for the beach.", "یک روز عالی برای ساحل.")],
    "fire": [L("Fire! Someone call 125!", "آتش! یکی به ۱۲۵ زنگ بزند!"), L("Is everyone out of the house?", "همه از خانه بیرون آمدند؟"),
             L("The fire truck is coming, make way!", "ماشین آتش‌نشانی دارد می‌آید، راه را باز کنید!")],
    "outage": [L("The power is out again...", "باز هم برق رفت..."), L("Good thing I have candles.", "خوب شد شمع دارم."),
               L("The electricity crew is on the way.", "گروه برق در راه است.")],
    "power_back": [L("The lights are back!", "برق آمد!"), L("Well done, electricity crew.", "دست گروه برق درد نکند.")],
    "quake": [L("Did you feel that?!", "حس کردی؟!"), L("Earthquake! Stay calm, stay outside.", "زلزله! آرام باشید، بیرون بمانید."),
              L("Everyone okay? Check on the neighbours.", "همه خوبند؟ به همسایه‌ها سر بزنید.")],
    "project": [L("The city is building something new!", "شهرداری دارد چیز تازه‌ای می‌سازد!"), L("So that's where our fines go.", "پس جریمه‌ها اینجا خرج می‌شود.")],
    "project_done": [L("The new work is finished - looks great.", "کار تازه تمام شد - خیلی قشنگ شده."), L("A nice change for the town.", "تغییر خوبی برای شهر است.")],
    "fine": [L("Someone got fined - rules are rules.", "یکی جریمه شد - قانون قانون است."), L("Fair is fair, the fund needs it.", "انصاف همین است، صندوق شهر لازمش دارد.")],
    "argument": [L("Not again, those two...", "باز این دو نفر..."), L("Someone should calm them down.", "یکی باید آرامشان کند.")],
    "cafe_fight": [L("A scuffle at the cafe!", "دعوا در کافه!"), L("That's what too many strong drinks do.", "نتیجه‌ی نوشیدنی قوی زیادی همین است.")],
    "player_fast": [L("Slow down! Children play here!", "آرام‌تر! اینجا بچه‌ها بازی می‌کنند!"), L("Hey, this isn't a race track!", "آهای، اینجا پیست مسابقه نیست!")],
    "player_horn": [L("All right, all right, I heard you!", "باشه، باشه، شنیدم!"), L("No need to honk!", "بوق زدن لازم نیست!")],
    "player_possess": [L("You seem different today...", "امروز یک جوری شده‌ای..."), L("Are you feeling all right?", "حالت خوب است؟")],
    "passenger": [L("Look, the farmer gives rides now.", "ببین، کشاورز حالا مسافر هم می‌برد."), L("Handy - a ride for a few coins.", "چه خوب - با چند سکه می‌شود سوار شد.")],
    "newspaper": [L("Did you read today's paper?", "روزنامه‌ی امروز را خواندی؟"), L("The paper says the fund is growing.", "روزنامه نوشته صندوق شهر بزرگ‌تر شده.")],
    "camping": [L("Going camping? Take warm clothes.", "به کمپ می‌روی؟ لباس گرم ببر."), L("Nights in the forest are beautiful.", "شب‌های جنگل قشنگ است.")],
    "night_no_lights": [L("Turn your lights on! I can't see you!", "چراغ‌هایت را روشن کن! نمی‌بینمت!")],
}
D = [
    {"topic": "weather", "lines": [L("Will it rain tomorrow?", "فردا باران می‌آید؟"), L("The fishermen say so.", "ماهیگیرها که این را می‌گویند."),
                                    L("Then I'll water the garden less.", "پس کمتر باغچه را آب می‌دهم.")]},
    {"topic": "fund", "lines": [L("Did you see the city fund board?", "تابلوی صندوق شهر را دیدی؟"), L("Yes, they want to build a park.", "آره، می‌خواهند پارک بسازند."),
                                 L("Good - the kids need it.", "خوب است - بچه‌ها لازمش دارند.")]},
    {"topic": "prices", "lines": [L("Tomatoes got expensive again.", "گوجه دوباره گران شد."), L("Wait for the harvest, it'll drop.", "صبر کن فصل برداشت شود، ارزان می‌شود."),
                                   L("I hope so, my wallet is crying.", "امیدوارم، جیبم دارد گریه می‌کند.")]},
    {"topic": "family", "lines": [L("How is your mother?", "مادرت چطور است؟"), L("Better, thank God. The doctor helped.", "بهتر است، خدا را شکر. دکتر کمک کرد."),
                                   L("Give her my regards.", "سلام مرا برسان.")]},
    {"topic": "cafe", "lines": [L("Coming to the terrace tonight?", "امشب می‌آیی تراس؟"), L("Only for tea - I work early.", "فقط برای چای - صبح زود کار دارم."),
                                 L("Sensible. The DJ starts at seven.", "عاقلانه است. دی‌جی ساعت هفت شروع می‌کند.")]},
    {"topic": "news", "lines": [L("Did you read about the fire?", "خبر آتش‌سوزی را خواندی؟"), L("Yes, thank God nobody was hurt.", "آره، خدا را شکر کسی آسیب ندید."),
                                 L("The firefighters were fast.", "آتش‌نشان‌ها سریع رسیدند.")]},
    {"topic": "work", "lines": [L("Busy day at work?", "سر کار شلوغ بود؟"), L("Very. But it's honest work.", "خیلی. ولی کار شرافتمندانه است."),
                                 L("That's what matters.", "مهم همین است.")]},
    {"topic": "health", "lines": [L("I've started walking every morning.", "هر صبح پیاده‌روی را شروع کرده‌ام."), L("Good for you! I go to the gym.", "آفرین! من باشگاه می‌روم."),
                                   L("Health is wealth, my father said.", "پدرم می‌گفت سلامتی بزرگ‌ترین ثروت است.")]},
]
emit("chatter", "ChatterStyle", "chatter_style", [
    ("lively_town", "Lively town", "Frequent small remarks, reactions to every event and overheard chats; chat log off by default (key 5).",
     {"name_fa": "شهر پرجنب‌وجوش", "remarks": R, "dialogues": D}),
    ("quiet_town", "Quiet town", "People mostly keep to themselves: rare remarks, reactions only to big events.",
     {"name_fa": "شهر کم‌حرف", "remarks": R, "dialogues": D, "remark_interval": V2(70, 120), "overhear_interval": V2(90, 160), "react_chance": 0.4}),
], "lively_town")

# ====================================================================== 2. cafe
style_script("cafe", "cafe_style", "CafeStyle",
    "v7b terrace cafe next to the Cafe: open in the afternoon and evening with a\nbartender and (at night) a DJ whose music is positional. Drinks menu: tea,\ncoffee, juices, soft drinks and a couple of 'strong' drinks that make you\nmildly tipsy for a short time (wobbly walk, slightly blurry screen) - the\nbartender stops serving after a limit and driving tipsy is fined. Small\nfights now and then: the bartender or the police break them up; fines go to\nthe city fund and the people involved remember. Posts are never empty: if\nthe bartender / DJ is away, another resident fills in. Consumer: TerraceCafe.", [
    ("pos", "Vector2", "Vector2(-25.0, -29.0)", ""), ("yaw", "float", "90.0", "deg; bar at the back (-z local)"),
    ("size", "Vector2", "Vector2(11.0, 9.0)", "deck size"),
    ("hours", "Vector2", "Vector2(16.0, 24.0)", "open (24 = midnight)"), ("dj_hours", "Vector2", "Vector2(19.0, 24.0)", ""),
    ("menu", "Array", "[]", "{id, en, fa, price, kind (hot/juice/soft/strong), stamina, hunger, tipsy (s)}"),
    ("max_strong", "int", "2", "the bartender stops serving strong drinks after this many per day"),
    ("wobble", "float", "0.35", "tipsy sway strength"), ("blur", "float", "0.55", "tipsy blur strength 0..1"),
    ("dui_fine", "int", "120", "driving while tipsy"),
    ("fight_chance", "float", "0.18", "per open hour"), ("fight_seconds", "float", "9.0", "before the bartender steps in"),
    ("fight_fine", "int", "40", "disturbing the peace (each)"),
    ("staff", "Dictionary", "{}", "role -> [preferred full names...] (bartender, dj)"),
    ("music", "PackedStringArray", "PackedStringArray()", "DJ tracks"), ("music_db", "float", "-4.0", ""), ("music_range", "float", "30.0", "m"),
    ("lines", "Dictionary", "{}", "bartender_greet, refuse, dj, fight, breakup, police, standin, closed -> [{en, fa}]"),
])
MENU = [
    {"id": "tea", "en": "Persian tea", "fa": "چای ایرانی", "price": 4, "kind": "hot", "stamina": 10, "hunger": 0, "tipsy": 0},
    {"id": "coffee", "en": "Coffee", "fa": "قهوه", "price": 7, "kind": "hot", "stamina": 18, "hunger": 0, "tipsy": 0},
    {"id": "orange_juice", "en": "Fresh orange juice", "fa": "آب‌پرتقال تازه", "price": 8, "kind": "juice", "stamina": 12, "hunger": 4, "tipsy": 0},
    {"id": "pomegranate_juice", "en": "Pomegranate juice", "fa": "آب‌انار", "price": 9, "kind": "juice", "stamina": 12, "hunger": 4, "tipsy": 0},
    {"id": "doogh", "en": "Mint doogh", "fa": "دوغ نعنا", "price": 5, "kind": "soft", "stamina": 8, "hunger": 3, "tipsy": 0},
    {"id": "lemonade", "en": "Lemonade", "fa": "لیموناد", "price": 6, "kind": "soft", "stamina": 8, "hunger": 0, "tipsy": 0},
    {"id": "strong_brew", "en": "Strong house brew", "fa": "نوشیدنی قوی مخصوص", "price": 14, "kind": "strong", "stamina": -5, "hunger": 0, "tipsy": 45},
    {"id": "strong_punch", "en": "Spiced strong punch", "fa": "پانچ قوی ادویه‌دار", "price": 16, "kind": "strong", "stamina": -8, "hunger": 0, "tipsy": 60},
]
STAFF = {"bartender": ["Mina Karimi", "Sima Rahimi"], "dj": ["Navid Sadeghi", "Sima Rahimi"]}
CAFE_LINES = {
    "bartender_greet": [L("Welcome! What can I get you?", "خوش آمدی! چه میل داری؟"), L("Tea is fresh, just brewed.", "چای تازه دم است.")],
    "refuse": [L("That's enough strong stuff for today - have a tea on me.", "برای امروز نوشیدنی قوی بس است - یک چای مهمان من."),
               L("No more strong drinks tonight, my friend. Water?", "امشب دیگر نوشیدنی قوی نه، دوست من. آب بیاورم؟")],
    "dj": [L("This one's for the night owls!", "این یکی برای شب‌زنده‌دارها!"), L("Requests? I've got zarb and radio hits!", "درخواستی دارید؟ ضرب و آهنگ رادیو دارم!")],
    "fight": [L("You spilled my drink!", "نوشیدنی‌ام را ریختی!"), L("Watch where you're going!", "جلوی پایت را نگاه کن!"),
              L("Say that again!", "یک بار دیگر بگو!"), L("Don't push me!", "هلم نده!")],
    "breakup": [L("Enough! Both of you, sit down or go home.", "بس است! هر دو بنشینید یا بروید خانه."),
                L("Not in my cafe! Shake hands.", "در کافه‌ی من نه! دست بدهید.")],
    "police": [L("Police! Break it up.", "پلیس! تمامش کنید.")],
    "standin": [L("I'm covering for {name} tonight.", "امشب جای {name} هستم."), L("{name} is away - I'm helping out.", "{name} نیست - من کمک می‌کنم.")],
    "closed": [L("The terrace opens at 16:00.", "تراس ساعت ۱۶ باز می‌شود.")],
}
MUSIC = psa("res://assets/audio/music/zarb_loop.ogg", "res://assets/audio/music/radio_loop.ogg")
TEA_MENU = [m for m in MENU if m["kind"] != "strong"]
emit("cafe", "CafeStyle", "cafe_style", [
    ("night_terrace", "Night terrace cafe", "Terrace open 16-24 with bartender, DJ from 19:00, teas, juices and two strong drinks (limit 2/day).",
     {"name_fa": "کافه‌ی تراس شب", "menu": MENU, "staff": STAFF, "music": MUSIC, "lines": CAFE_LINES}),
    ("tea_house", "Quiet tea house", "No strong drinks, soft music until 22:00, almost no fights.",
     {"name_fa": "چایخانه‌ی آرام", "menu": TEA_MENU, "staff": STAFF, "music": psa("res://assets/audio/music/radio_loop.ogg"), "lines": CAFE_LINES,
      "hours": V2(15, 22), "dj_hours": V2(19, 22), "fight_chance": 0.02, "music_db": -10.0}),
], "night_terrace")

# ====================================================================== 3. mechanic
style_script("mechanic", "mechanic_style", "MechanicStyle",
    "v7b mechanic shop on Main St: repairs (cars wear with bumps and crashes),\na fuel pump and simple upgrades (engine tune, sport tyres, LED headlights,\neco injector). The mechanic's post is never empty: a stand-in covers.\nConsumers: MechanicShop, MechanicPanel, CarSystems.", [
    ("pos", "Vector2", "Vector2(56.0, -61.5)", ""), ("yaw", "float", "0.0", "deg; open front faces +z (Main St)"),
    ("hours", "Vector2", "Vector2(8.0, 19.0)", ""),
    ("repair_per_pct", "float", "2.0", "gold per % of damage repaired"), ("fuel_per_pct", "float", "0.6", "gold per % of tank"),
    ("upgrades", "Array", "[]", "{id, en, fa, cost, speed, accel, fuel, lights, grip}"),
    ("staff", "PackedStringArray", "PackedStringArray()", "preferred mechanics"),
    ("lines", "Dictionary", "{}", "greet, repaired, fueled, upgraded, standin, poor -> [{en, fa}]"),
])
UPG = [
    {"id": "engine_tune", "en": "Engine tune-up (+12% top speed)", "fa": "تنظیم موتور (۱۲٪ سرعت بیشتر)", "cost": 180, "speed": 1.12, "accel": 1.05, "fuel": 1.05},
    {"id": "sport_tyres", "en": "Sport tyres (better grip and pickup)", "fa": "لاستیک اسپرت (چسبندگی و شتاب بهتر)", "cost": 140, "accel": 1.15, "grip": 1.2},
    {"id": "led_lights", "en": "LED headlights (see further at night)", "fa": "چراغ ال‌ای‌دی (دید بیشتر در شب)", "cost": 90, "lights": 1.6},
    {"id": "eco_injector", "en": "Eco injector (-30% fuel use)", "fa": "انژکتور کم‌مصرف (۳۰٪ مصرف کمتر)", "cost": 120, "fuel": 0.7},
]
MECH_LINES = {
    "greet": [L("Salam! What's wrong with your car?", "سلام! ماشینت چه مشکلی دارد؟"), L("Bring it in, let's have a look.", "بیاورش داخل، یک نگاهی بیندازیم.")],
    "repaired": [L("Good as new. Drive gently!", "مثل روز اولش شد. آرام رانندگی کن!")],
    "fueled": [L("Full tank - safe travels.", "باک پر شد - سفر به خیر.")],
    "upgraded": [L("Installed. You'll feel the difference.", "نصب شد. فرقش را حس می‌کنی.")],
    "standin": [L("The mechanic is away - I'm minding the shop.", "مکانیک نیست - من حواسم به مغازه هست.")],
    "poor": [L("Not enough money - come back later.", "پولت کافی نیست - بعداً بیا.")],
}
emit("mechanic", "MechanicStyle", "mechanic_style", [
    ("town_garage", "Town garage", "Repairs, fuel pump and four upgrades; open 8-19; a stand-in covers if the mechanic is away.",
     {"name_fa": "تعمیرگاه شهر", "upgrades": UPG, "staff": psa("Hassan Jafari", "Babak Nouri"), "lines": MECH_LINES}),
    ("budget_garage", "Budget garage", "Cheaper repairs and fuel, only two upgrades.",
     {"name_fa": "تعمیرگاه ارزان", "upgrades": UPG[1:2] + UPG[3:4], "staff": psa("Babak Nouri", "Hassan Jafari"), "lines": MECH_LINES,
      "repair_per_pct": 1.2, "fuel_per_pct": 0.4}),
], "town_garage")

# ====================================================================== 4. driving
style_script("driving", "driving_style", "DrivingStyle",
    "v7b deeper driving: gears (automatic or manual - 3 toggles, Shift / Ctrl\nshift up / down), headlights you switch with H (needed at night: the police\nfine driving without lights after dark), fuel use, wear from bumps, and a\nsmall dashboard (gear, speed, fuel, condition, lights) while driving.\nConsumers: CarSystems, DrivableCar hooks, DashboardHud.", [
    ("gear_top", "Array", "[]", "top speed fraction per gear (1..n)"),
    ("gear_accel", "Array", "[]", "acceleration factor per gear"),
    ("auto_default", "bool", "true", "automatic gearbox by default"),
    ("fuel_per_km", "float", "7.0", "% of the tank per km (0 = no fuel)"),
    ("damage_per_hit", "float", "6.0", "% condition lost per crash above 4 m/s"),
    ("low_fuel", "float", "15.0", "% warning"),
    ("night_hours", "Vector2", "Vector2(19.0, 6.0)", "lights needed from / until"),
    ("no_lights_fine", "int", "30", "driving after dark without headlights"),
    ("no_lights_grace", "float", "8.0", "seconds before the fine"),
    ("light_range", "float", "18.0", "m"), ("light_energy", "float", "2.4", ""),
    ("dark_driving", "float", "0.35", "how much darker it feels without lights (night vignette)"),
])
emit("driving", "DrivingStyle", "driving_style", [
    ("realistic_driving", "Realistic driving", "5 gears (auto/manual), fuel 7%/km, wear on crashes, headlights needed at night (30 G fine).",
     {"name_fa": "رانندگی واقع‌گرایانه", "gear_top": [0.24, 0.44, 0.64, 0.84, 1.0], "gear_accel": [1.35, 1.1, 0.9, 0.72, 0.6]}),
    ("easy_driving", "Easy driving", "Automatic only feel, very low fuel use, no wear; lights still needed at night (no fine).",
     {"name_fa": "رانندگی آسان", "gear_top": [0.4, 0.7, 1.0], "gear_accel": [1.2, 1.0, 0.85], "fuel_per_km": 1.5, "damage_per_hit": 0.0,
      "no_lights_fine": 0}),
], "realistic_driving")

# ====================================================================== 5. passengers
style_script("passengers", "passenger_style", "PassengerStyle",
    "v7b passengers: now and then a townsperson waits at a stop and waves for a\nride. Stop next to them (in a car) and they get in; drive them to their\ndestination (green ring + minimap direction) and stop: they pay the fare,\ngenerous people tip, everyone remembers a safe ride. Consumer: Passengers.", [
    ("stops", "Array", "[]", "{id, en, fa, pos (V2)}"),
    ("fare_base", "int", "8", ""), ("fare_per_100m", "float", "5.0", ""),
    ("every_hours", "float", "1.5", "game hours between new passengers"),
    ("hours", "Vector2", "Vector2(7.0, 23.0)", ""),
    ("pickup_radius", "float", "6.0", "m"), ("max_wait", "float", "240.0", "real seconds a passenger waits"),
    ("lines", "Dictionary", "{}", "hail, board, arrive, tip, slow_down, gave_up -> [{en, fa}]"),
])
STOPS = [
    {"id": "square", "en": "Town Square", "fa": "میدان شهر", "pos": V2(14.0, -44.4)},
    {"id": "hospital", "en": "Hospital", "fa": "بیمارستان", "pos": V2(30.0, -55.6)},
    {"id": "beach", "en": "Beach", "fa": "ساحل", "pos": V2(50.5, -14.0)},
    {"id": "university", "en": "University", "fa": "دانشگاه", "pos": V2(-5.0, -121.0)},
    {"id": "mosque", "en": "Maple St / Mosque", "fa": "خیابان افرا / مسجد", "pos": V2(-14.0, -85.0)},
    {"id": "garage", "en": "Mechanic", "fa": "تعمیرگاه", "pos": V2(50.0, -55.6)},
]
P_LINES = {
    "hail": [L("Taxi! Can you take me?", "آقا/خانم، می‌رسانیدم؟"), L("Over here! I need a ride.", "اینجا! باید جایی بروم.")],
    "board": [L("Thanks! To {dest}, please.", "ممنون! لطفاً تا {dest}."), L("{dest}, please - no rush.", "تا {dest} لطفاً - عجله‌ای نیست.")],
    "arrive": [L("Here we are. Thank you!", "رسیدیم. دستت درد نکند!"), L("Perfect, thanks for the ride.", "عالی، ممنون که رساندی.")],
    "tip": [L("Keep the change!", "بقیه‌اش مال خودت!")],
    "slow_down": [L("Easy, easy! Not so fast!", "یواش، یواش! این‌قدر تند نه!")],
    "gave_up": [L("Never mind, I'll walk.", "اشکالی ندارد، پیاده می‌روم.")],
}
emit("passengers", "PassengerStyle", "passenger_style", [
    ("town_rides", "Town rides", "A passenger every ~1.5 h (7-23) at 6 stops; 8 G + 5 G/100 m, generous people tip.",
     {"name_fa": "مسافرکشی شهری", "stops": STOPS, "lines": P_LINES}),
    ("busy_town", "Busy town", "Passengers every 40 minutes and better fares.",
     {"name_fa": "شهر شلوغ", "stops": STOPS, "lines": P_LINES, "every_hours": 0.7, "fare_base": 12, "fare_per_100m": 7.0}),
], "town_rides")

# ====================================================================== 6. camping
style_script("camping", "camping_style", "CampingStyle",
    "v7b camping trip: drive (or walk) to the pine forest or the lookout hill and\npress 6 to set up a tent and a campfire (needs 1 firewood, or buys a bundle).\nE at the tent sleeps till morning (fully rested); the campfire warms and\nlights the night. Camps are remembered. Consumer: Camping.", [
    ("spots", "Array", "[]", "{id, en, fa, pos (V2)}"),
    ("radius", "float", "14.0", "m: how close to a spot you must be"),
    ("tent_color", "Color", "Color(0.85, 0.45, 0.15)", ""),
    ("firewood_cost", "int", "6", "gold if you have no firewood"),
    ("rest_bonus", "float", "1.0", "fatigue removed by a night in the tent (0..1)"),
    ("lines", "Dictionary", "{}", "setup, sleep, too_far, packed -> [{en, fa}]"),
])
SPOTS = [
    {"id": "pine_forest", "en": "Pine forest camp", "fa": "کمپ جنگل کاج", "pos": V2(-64.0, -97.0)},
    {"id": "lookout_hill", "en": "Lookout hill camp", "fa": "کمپ تپه‌ی چشم‌انداز", "pos": V2(64.0, -104.0)},
]
C_LINES = {
    "setup": [L("Tent up, fire lit. Listen to the forest...", "چادر برپا شد، آتش روشن. به صدای جنگل گوش کن...")],
    "sleep": [L("You sleep under the stars and wake up fresh.", "زیر ستاره‌ها می‌خوابی و سرحال بیدار می‌شوی.")],
    "too_far": [L("Find a camp spot first (forest or lookout hill).", "اول یک جای کمپ پیدا کن (جنگل یا تپه‌ی چشم‌انداز).")],
    "packed": [L("You pack up the tent and put out the fire.", "چادر را جمع می‌کنی و آتش را خاموش می‌کنی.")],
}
emit("camping", "CampingStyle", "camping_style", [
    ("forest_and_hill", "Forest and hill camps", "Two camp spots (pine forest, lookout hill); tent + campfire; a night in the tent fully rests you.",
     {"name_fa": "کمپ جنگل و تپه", "spots": SPOTS, "lines": C_LINES}),
    ("family_camping", "Family camping", "Big blue family tent, free firewood, half rest.",
     {"name_fa": "کمپ خانوادگی", "spots": SPOTS, "lines": C_LINES, "tent_color": (0.2, 0.45, 0.8), "firewood_cost": 0, "rest_bonus": 0.6}),
], "forest_and_hill")

# ====================================================================== 7. newspaper
style_script("newspaper", "newspaper_style", "NewspaperStyle",
    "v7b local newspaper: every morning a new issue reports what really happened\nin town (WorldMemory + CityState): fires, fines, arguments, outages and\nquakes, public works, cafe fights, rides, market price movers and a weather\nline. Buy it at the newsstand by the square (E) and read it with 4.\nConsumers: Newspaper, NewspaperPanel.", [
    ("paper_en", "String", '"Town Daily"', ""), ("paper_fa", "String", '"روزنامه‌ی شهر ما"', ""),
    ("stand_pos", "Vector2", "Vector2(8.2, -43.2)", ""), ("price", "int", "3", ""),
    ("max_items", "int", "8", ""), ("archive", "int", "7", "issues kept"),
    ("templates", "Dictionary", "{}", "kind -> {en, fa} with {n} {amount} {what} {who} placeholders"),
    ("weather", "Dictionary", "{}", "weather id -> {en, fa}"),
    ("quiet", "Dictionary", "{}", "{en, fa} when nothing happened"),
])
TPL = {
    "fire": L("FIRE: {n} fire(s) - the brigade answered every call.", "آتش‌سوزی: {n} مورد آتش‌سوزی - آتش‌نشانی به همه رسید."),
    "fine": L("Justice: {what} - {amount} G to the city fund.", "عدالت: {what} - {amount} سکه به صندوق شهر."),
    "argument": L("Street arguments: {n} - {calmed} calmed by neighbours.", "دعوای خیابانی: {n} مورد - {calmed} مورد را همسایه‌ها آرام کردند."),
    "outage": L("Power cut {n} time(s); the crew restored it.", "برق {n} بار قطع شد؛ گروه برق وصلش کرد."),
    "quake": L("A mild earthquake shook the town - no injuries.", "زلزله‌ی خفیفی شهر را لرزاند - کسی آسیب ندید."),
    "project": L("Public works: {what} ({state}).", "کارهای عمومی: {what} ({state})."),
    "fund": L("City fund: {amount} G.", "صندوق شهر: {amount} سکه."),
    "cafe_fight": L("Cafe scuffle: {n} - fines for disturbing the peace.", "دعوا در کافه: {n} مورد - جریمه برای برهم زدن آرامش."),
    "rides": L("Farmer's rides: {n} passenger(s) driven safely.", "مسافرکشی کشاورز: {n} مسافر سالم رسیدند."),
    "camp": L("Outdoors: a camp was set up at {what}.", "طبیعت‌گردی: در {what} کمپ برپا شد."),
    "market": L("Market: {what}.", "بازار: {what}."),
    "report": L("Police: {n} new report(s) filed.", "پلیس: {n} گزارش تازه ثبت شد."),
    "trade": L("Trade: {n} deal(s) made in town.", "تجارت: {n} معامله در شهر انجام شد."),
}
WX = {"sunny": L("Weather: sunny and clear.", "هوا: آفتابی و صاف."), "cloudy": L("Weather: cloudy.", "هوا: ابری."),
      "rain": L("Weather: rain - good for the gardens.", "هوا: بارانی - خوب برای باغچه‌ها."), "storm": L("Weather: storm warning - stay away from power lines.", "هوا: هشدار طوفان - از سیم‌های برق دور بمانید."),
      "heatwave": L("Weather: heatwave - drink water, stay in the shade.", "هوا: موج گرما - آب بنوشید، زیر سایه بمانید."), "snow": L("Weather: snow - drive carefully.", "هوا: برفی - با احتیاط رانندگی کنید.")}
QUIET = L("A quiet day in town. Neighbours helped each other.", "یک روز آرام در شهر. همسایه‌ها به هم کمک کردند.")
emit("newspaper", "NewspaperStyle", "newspaper_style", [
    ("daily_paper", "Town Daily", "A daily paper (3 G at the newsstand) with real town events, market movers and the weather.",
     {"name_fa": "روزنامه‌ی روزانه", "templates": TPL, "weather": WX, "quiet": QUIET}),
    ("free_bulletin", "Free town bulletin", "A free one-page bulletin with fewer items.",
     {"name_fa": "خبرنامه‌ی رایگان", "templates": TPL, "weather": WX, "quiet": QUIET, "price": 0, "max_items": 4,
      "paper_en": "Town Bulletin", "paper_fa": "خبرنامه‌ی شهر"}),
], "daily_paper")

# ====================================================================== 8. personalities
style_script("personalities", "personality_style", "PersonalityStyle",
    "v7b personalities: every resident has a character - calm, hot-tempered,\ngenerous, stingy, cheerful or shy. It changes how arguments go (who\nescalates, how fast the police are needed, what they say) and how they\nhaggle when trading with you (key 7 next to someone) or with each other.\nConsumers: Personalities, Conflicts, HagglePanel, Chatter, Passengers.", [
    ("traits", "Dictionary", "{}", "id -> {en, fa, temper, haggle, generosity, patience, argue, reply, accept, refuse, counter}"),
    ("people", "Dictionary", "{}", "full name -> trait id"),
    ("default_trait", "String", '"cheerful"', ""),
])
TRAITS = {
    "calm": {"en": "calm", "fa": "آرام", "temper": 0.1, "haggle": 0.3, "generosity": 0.5, "patience": 3,
             "argue": [L("Let's talk about this calmly.", "بیا آرام درباره‌اش حرف بزنیم.")], "reply": [L("I understand, but...", "می‌فهمم، ولی...")],
             "accept": [L("That's fair. Deal.", "منصفانه است. قبول.")], "refuse": [L("Sorry, that's too much for me.", "ببخشید، این برای من زیاد است.")],
             "counter": [L("How about {price}?", "{price} چطور است؟")]},
    "hot_tempered": {"en": "hot-tempered", "fa": "تندخو", "temper": 0.85, "haggle": 0.6, "generosity": 0.3, "patience": 1,
             "argue": [L("I've had enough of this!", "دیگر خسته شدم!"), L("Don't you dare!", "جرئت داری تکرار کن!")],
             "reply": [L("You're always like this!", "تو همیشه همینی!")],
             "accept": [L("Fine. Take it.", "باشه. بگیر.")], "refuse": [L("Are you joking?! No!", "شوخی می‌کنی؟! نه!")],
             "counter": [L("{price}, and not a coin more!", "{price}، یک سکه هم بیشتر نه!")]},
    "generous": {"en": "generous", "fa": "دست‌ودل‌باز", "temper": 0.2, "haggle": 0.1, "generosity": 0.9, "patience": 3,
             "argue": [L("Forget it, it's not worth a fight.", "ولش کن، ارزش دعوا ندارد.")], "reply": [L("No hard feelings.", "دلخوری نیست.")],
             "accept": [L("Of course! And here's a little extra.", "البته! این هم کمی بیشتر.")], "refuse": [L("I really can't, sorry.", "واقعاً نمی‌توانم، ببخشید.")],
             "counter": [L("Let's say {price} - you work hard.", "بگوییم {price} - تو زحمت می‌کشی.")]},
    "stingy": {"en": "stingy", "fa": "خسیس", "temper": 0.5, "haggle": 0.9, "generosity": 0.05, "patience": 2,
             "argue": [L("Every coin counts!", "هر سکه حساب دارد!")], "reply": [L("I won't pay a coin more!", "یک سکه هم بیشتر نمی‌دهم!")],
             "accept": [L("Hmm... all right. But only this once.", "هوم... باشه. فقط همین یک بار.")], "refuse": [L("Too expensive! Robbery!", "خیلی گران است! دزدی است!")],
             "counter": [L("{price}. Take it or leave it.", "{price}. می‌خواهی بخواه، نمی‌خواهی نخواه.")]},
    "cheerful": {"en": "cheerful", "fa": "خوش‌رو", "temper": 0.25, "haggle": 0.4, "generosity": 0.6, "patience": 3,
             "argue": [L("Come on, let's not fight!", "بی‌خیال، دعوا نکنیم!")], "reply": [L("Ha, you're right, sorry!", "ها، حق با توست، ببخشید!")],
             "accept": [L("Deal! Nice doing business.", "قبول! معامله با تو خوش است.")], "refuse": [L("Ha, nice try! Too much.", "ها، تلاش خوبی بود! زیاد است.")],
             "counter": [L("Meet me at {price}?", "روی {price} توافق کنیم؟")]},
    "shy": {"en": "shy", "fa": "خجالتی", "temper": 0.15, "haggle": 0.2, "generosity": 0.5, "patience": 2,
             "argue": [L("Um... please stop.", "اِ... لطفاً بس کن.")], "reply": [L("I... I didn't mean it.", "من... منظوری نداشتم.")],
             "accept": [L("Okay... thank you.", "باشه... ممنون.")], "refuse": [L("Sorry... I can't.", "ببخشید... نمی‌توانم.")],
             "counter": [L("Maybe... {price}?", "شاید... {price}؟")]},
}
PEOPLE = {
    "Mina Karimi": "cheerful", "Reza Karimi": "hot_tempered", "Dariush Rahimi": "calm", "Leila Rahimi": "calm",
    "Sima Rahimi": "shy", "Sara Ahmadi": "stingy", "Parvin Ahmadi": "generous", "Omid Hosseini": "calm",
    "Nasrin Hosseini": "cheerful", "Kian Moradi": "hot_tempered", "Shirin Moradi": "generous", "Bahram Tehrani": "stingy",
    "Golnar Tehrani": "calm", "Hassan Jafari": "hot_tempered", "Maryam Jafari": "generous", "Navid Sadeghi": "cheerful",
    "Elena Sadeghi": "calm", "Farhad Rostami": "hot_tempered", "Laleh Rostami": "stingy", "Babak Nouri": "shy",
    "Ziba Nouri": "cheerful", "Thomas Bell": "generous", "Anna Bell": "cheerful", "Yusuf Haddad": "generous",
    "Amina Haddad": "calm", "Ali Karimi": "cheerful", "Arman Hosseini": "shy", "Dara Rostami": "cheerful",
}
EASY = {k: ("generous" if i % 2 else "calm") for i, k in enumerate(PEOPLE)}
emit("personalities", "PersonalityStyle", "personality_style", [
    ("town_characters", "Town characters", "Six characters (calm, hot-tempered, generous, stingy, cheerful, shy) shape arguments and haggling.",
     {"name_fa": "شخصیت‌های شهر", "traits": TRAITS, "people": PEOPLE}),
    ("easygoing_town", "Easygoing town", "Everyone is calm or generous: few arguments, easy deals.",
     {"name_fa": "شهر آسان‌گیر", "traits": TRAITS, "people": EASY, "default_trait": "calm"}),
], "town_characters")

# ====================================================================== 9. voice profiles
style_script("voice_profiles", "voice_profile_style", "VoiceProfileStyle",
    "v7b distinct voices: each resident has a voice profile - pitch, speaking\nrate and tone (warm, bright, gruff, soft, lively, slow) - used by the voice\nblips, plus more varied Persian lines per tone for their small talk.\nConsumers: VoiceBlips (pitch/rate/tone), Chatter (tone lines).", [
    ("people", "Dictionary", "{}", "full name -> {pitch, rate, tone}"),
    ("tones", "Dictionary", "{}", "tone -> {en, fa, volume_db, jitter}"),
    ("tone_lines", "Dictionary", "{}", "tone -> [{en, fa}]"),
])
TONES = {"warm": {"en": "warm", "fa": "گرم", "volume_db": 0.0, "jitter": 0.05}, "bright": {"en": "bright", "fa": "روشن", "volume_db": 1.0, "jitter": 0.09},
         "gruff": {"en": "gruff", "fa": "خش‌دار", "volume_db": 1.5, "jitter": 0.03}, "soft": {"en": "soft", "fa": "نرم", "volume_db": -4.0, "jitter": 0.04},
         "lively": {"en": "lively", "fa": "پرشور", "volume_db": 1.0, "jitter": 0.12}, "slow": {"en": "slow", "fa": "شمرده", "volume_db": -1.0, "jitter": 0.03}}
TONE_LINES = {
    "warm": [L("Come by for tea sometime, dear.", "یک وقت برای چای سر بزن، عزیزم."), L("How's your family? Well, I hope.", "خانواده خوبند؟ امیدوارم خوب باشند.")],
    "bright": [L("Oh! What a beautiful day!", "وای! چه روز قشنگی!"), L("Guess what I heard today!", "حدس بزن امروز چه شنیدم!")],
    "gruff": [L("Hmph. Work doesn't do itself.", "هوم. کار خودش انجام نمی‌شود."), L("Back in my day, we walked everywhere.", "زمان ما همه‌جا پیاده می‌رفتیم.")],
    "soft": [L("Oh... hello. Nice to see you.", "اوه... سلام. خوشحالم می‌بینمت."), L("It's peaceful today, isn't it?", "امروز آرام است، نه؟")],
    "lively": [L("Let's go, let's go! So much to do!", "بزن بریم! کلی کار داریم!"), L("Ha! You should've seen it!", "ها! باید می‌دیدی!")],
    "slow": [L("Patience... everything in its time.", "صبر... هر چیزی وقتی دارد."), L("As Hafez says, be kind.", "به قول حافظ، مهربان باش.")],
}
VP = {
    "Mina Karimi": (1.30, 1.15, "bright"), "Reza Karimi": (0.80, 1.1, "lively"), "Ali Karimi": (1.75, 1.25, "lively"),
    "Dariush Rahimi": (0.72, 0.9, "slow"), "Leila Rahimi": (1.18, 0.95, "warm"), "Sima Rahimi": (1.38, 1.05, "soft"),
    "Sara Ahmadi": (1.26, 1.2, "bright"), "Parvin Ahmadi": (1.08, 0.8, "warm"), "Omid Hosseini": (0.86, 1.0, "slow"),
    "Nasrin Hosseini": (1.24, 1.1, "warm"), "Arman Hosseini": (1.62, 1.1, "soft"), "Kian Moradi": (0.78, 1.05, "gruff"),
    "Shirin Moradi": (1.32, 1.05, "warm"), "Bahram Tehrani": (0.70, 0.9, "gruff"), "Golnar Tehrani": (1.12, 0.95, "slow"),
    "Hassan Jafari": (0.66, 0.85, "gruff"), "Maryam Jafari": (1.10, 0.9, "warm"), "Navid Sadeghi": (0.90, 1.2, "lively"),
    "Elena Sadeghi": (1.22, 0.95, "soft"), "Farhad Rostami": (0.68, 1.0, "gruff"), "Laleh Rostami": (1.20, 1.1, "bright"),
    "Dara Rostami": (1.85, 1.3, "lively"), "Babak Nouri": (0.84, 0.9, "soft"), "Ziba Nouri": (1.28, 1.15, "lively"),
    "Thomas Bell": (0.76, 0.85, "warm"), "Anna Bell": (1.06, 1.0, "bright"), "Yusuf Haddad": (0.74, 0.8, "slow"),
    "Amina Haddad": (1.04, 1.0, "slow"),
}
PEOPLE_V = {k: {"pitch": v[0], "rate": v[1], "tone": v[2]} for k, v in VP.items()}
UNIFORM = {k: {"pitch": 1.0, "rate": 1.0, "tone": "warm"} for k in VP}
emit("voice_profiles", "VoiceProfileStyle", "voice_profile_style", [
    ("distinct_voices", "Distinct voices", "28 personal voice profiles (pitch, rate, tone) and tone-specific Persian small talk.",
     {"name_fa": "صداهای متمایز", "people": PEOPLE_V, "tones": TONES, "tone_lines": TONE_LINES}),
    ("uniform_voices", "Classic voices", "Everyone uses the v5b voice rules (gender/age pitch) and the same warm tone.",
     {"name_fa": "صداهای کلاسیک", "people": {}, "tones": TONES, "tone_lines": {"warm": TONE_LINES["warm"]}}),
], "distinct_voices")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b modules written")


# ---------------------------------------------------------------- ui_text (v7b)
V7B_PHRASES = {
    "Cars: walk to a parked car's driver door and press E. W/S drive, A/D steer, Space handbrake, E get out. H headlights (needed at night), 3 manual/auto gearbox, Shift/Ctrl change gear. Fuel and repairs at the mechanic on Main St; pick up waving passengers (yellow beam) for coins. Change clothes at the farmhouse wardrobe; the mirror next to it opens the character creator.":
        "ماشین: کنار در راننده‌ی یک ماشین پارک‌شده برو و E بزن. W/S حرکت، A/D فرمان، فاصله ترمزدستی، E پیاده شدن. H چراغ جلو (شب لازم است)، ۳ گیربکس دستی/خودکار، Shift/Ctrl عوض کردن دنده. بنزین و تعمیر در تعمیرگاه خیابان اصلی؛ مسافرهایی را که دست تکان می‌دهند (پرتو زرد) برسان و سکه بگیر. لباس‌ها را در کمد خانه‌ی مزرعه عوض کن؛ آینه‌ی کنارش ساخت شخصیت را باز می‌کند.",
    "Stand next to a townsperson and press F2 to live their life for a while: you keep their name, job, home and memories. Destructive choices ask first and have consequences - fines go to the city fund, the police take a report, people remember. Press E on two people arguing to calm them down. The fire brigade (125) and the electricity crew answer emergencies. The terrace cafe next to the Cafe opens in the afternoon (DJ at night); buy the daily paper at the newsstand by the square.":
        "کنار یک شهروند بایست و F2 را بزن تا مدتی زندگی او را بازی کنی: نام، شغل، خانه و خاطراتش با او می‌ماند. کارهای ویرانگر اول تأیید می‌خواهند و پیامد دارند - جریمه به صندوق شهر می‌رود، پلیس گزارش می‌گیرد و مردم یادشان می‌ماند. کنار دو نفر که دعوا می‌کنند E بزن تا آرامشان کنی. آتش‌نشانی (۱۲۵) و گروه برق به حادثه‌ها می‌رسند. کافه‌ی تراس کنار کافه از بعدازظهر باز است (شب‌ها دی‌جی)؛ روزنامه‌ی روز را از دکه‌ی کنار میدان بخر.",
    "Headlights on / off (while driving)": "چراغ جلو روشن / خاموش (هنگام رانندگی)",
    "Gearbox automatic / manual (while driving)": "گیربکس خودکار / دستی (هنگام رانندگی)",
    "Shift up (manual gearbox)": "دنده بالا (گیربکس دستی)",
    "Shift down (manual gearbox)": "دنده پایین (گیربکس دستی)",
    "Set up / pack a camp (tent + campfire) at a camp spot": "برپا / جمع کردن کمپ (چادر و آتش) در جای کمپ",
    "Read the newspaper": "خواندن روزنامه",
    "Chat log on / off (what people say)": "گزارش گفتگوها روشن / خاموش (حرف‌های مردم)",
    "Haggle / trade with the townsperson next to you": "چانه‌زنی / معامله با شهروند کنارت",
    "buy today's newspaper": "خریدن روزنامه‌ی امروز",
    "order a drink": "سفارش نوشیدنی",
    "talk to the mechanic (repair, fuel, upgrades)": "صحبت با مکانیک (تعمیر، سوخت، ارتقا)",
    "fill up the car": "بنزین زدن",
    "sleep in the tent": "خوابیدن در چادر",
    "Cafe, Car & News": "کافه، ماشین و روزنامه",
}


def patch_ui_text_v7b():
    import re
    for fn in ("farsi.tres", "farsi_short.tres"):
        path = os.path.join(ROOT, "modules", "ui_text", fn)
        src = open(path, encoding="utf-8").read()
        m = re.search(r"^phrases = (\{.*\})$", src, re.M)
        cur = json.loads(m.group(1))
        cur.update(V7B_PHRASES)
        line = "phrases = " + json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
        src = src[:m.start()] + line + src[m.end():]
        open(path, "w", encoding="utf-8").write(src)
    print("ui_text: +%d v7b phrases" % len(V7B_PHRASES))


patch_ui_text_v7b()
