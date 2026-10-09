#!/usr/bin/env python3
"""v7b.1 traffic patch: generates the module style scripts (modules/<type>/<script>.gd),
their .tres variants and registers them in data/asset_modules.json:
  traffic_rules    signals / stop signs / speed limits / cameras / officer / fines / license points
  road_markings    stop lines, lane + edge lines, parking bays, school text, arrows
  traffic_signs    stop, yield, speed limit, no parking, one-way (roundabout), school zone, direction signs
  street_lighting  extra street lights, intersection / square / park / shop-front / path lights, warm pools
  driving_license  rules booklet + quiz at the police station, confiscation, impound lot
  car_dealership   a car lot by the road out of town (needs a license)
  npc_traffic      a few townsfolk cars on loops that obey lights and limits
  transit          vehicle module: city bus line (stops, schedule, fare) + a drivable bus
  car_sounds       procedural engine / horn / indicator / tyre / door sounds per car model
  cafe_lounge      classy terrace decor + an indoor cafe-lounge that becomes a disco at night
Only these types are (re)written in the JSON config (the file is re-read right
before saving, so other generators' types are kept).
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, psa, config, config_path, V2, V3 = (ns["style_script"], ns["emit"], ns["psa"], ns["config"],
                                                      ns["config_path"], ns["V2"], ns["V3"])
MY_TYPES = []


def L(en, fa):
    return {"en": en, "fa": fa}


def reg(t):
    MY_TYPES.append(t)


# ====================================================================== 1. traffic_rules
reg("traffic_rules")
style_script("traffic_rules", "traffic_rules_style", "TrafficRulesStyle",
    "v7b.1 traffic rules: signalised intersections with real cycles (green, yellow,\nall-red; actuated: a driver who waits ~5 s at red gets green soon after), STOP\nsigns (full stop for stop_hold_s), speed limits per street (signs show the same\nnumbers, the dashboard shows the current limit), red-light / speed cameras and a\ntraffic officer. Offences: camera flash + fine (city fund) + police report +\nnewspaper item; at `offences_to_confiscate` the licence is confiscated and the\ncar is towed to the impound lot. Applies to the farmer and to a possessed\ntownsperson; NPC cars obey. Consumers: TrafficSignals, TrafficRules, NpcTraffic,\nBusLine, RoadCar.traffic_gate, CarSystems dashboard.", [
    ("speed_limits", "Dictionary", "{}", "street name -> km/h"),
    ("square_limit_kmh", "float", "25.0", "roundabout around the town square"),
    ("default_limit_kmh", "float", "40.0", "anywhere else in town"),
    ("school_zone", "Vector3", "Vector3(42.0, -90.0, 22.0)", "x, z, radius (m) of the school zone"),
    ("school_limit_kmh", "float", "25.0", ""),
    ("speed_tolerance_kmh", "float", "5.0", "camera tolerance"),
    ("speeding_seconds", "float", "1.5", "over the limit this long near a camera / officer = caught"),
    ("enforcement_range", "float", "30.0", "m around a camera or the officer"),
    ("signals", "Array", "[]", "{id, pos, en, fa, camera, officer} signalised intersections"),
    ("stops", "Array", "[]", "{id, pos, approaches ['n','s','e','w'], en, fa} STOP-sign junctions"),
    ("speed_cameras", "Array", "[]", "{pos, yaw} extra speed cameras (poles)"),
    ("green_s", "float", "10.0", ""), ("yellow_s", "float", "3.0", ""), ("all_red_s", "float", "2.0", ""),
    ("min_red_wait_s", "float", "5.0", "a car waiting at red gets green after about this long (actuated)"),
    ("stop_hold_s", "float", "5.0", "full stop needed at a STOP sign"),
    ("red_light_fine", "int", "150", ""), ("stop_sign_fine", "int", "60", ""),
    ("speeding_fine", "int", "50", "0 = use the v7a city fund speeding fine"),
    ("unlicensed_fine", "int", "100", "driving without a licence (once per day)"),
    ("offences_to_confiscate", "int", "2", "2nd offence: licence confiscated + car impounded"),
    ("officer_lines", "Dictionary", "{}", "whistle, wave, caught, ok -> [{en, fa}]"),
])
SIGNALS = [
    {"id": "oak_maple", "pos": V2(0, -90), "en": "Oak Ave / Maple St", "fa": "خیابان بلوط / خیابان افرا", "camera": True, "officer": True},
    {"id": "pine_main", "pos": V2(-45, -50), "en": "Pine Ln / Main St", "fa": "کوچه‌ی کاج / خیابان اصلی", "camera": True, "officer": False},
    {"id": "harbor_main", "pos": V2(55, -50), "en": "Harbor Rd / Main St", "fa": "جاده‌ی بندر / خیابان اصلی", "camera": True, "officer": False},
]
STOPS = [{"id": "pine_maple", "pos": V2(-45, -90), "approaches": ["n", "s"], "en": "Pine Ln / Maple St", "fa": "کوچه‌ی کاج / خیابان افرا"}]
OFFICER = {
    "whistle": [L("Stop! The light is red!", "ایست! چراغ قرمز است!"), L("Wait for the green!", "صبر کن تا سبز شود!")],
    "wave": [L("Go ahead, slowly.", "برو، آرام."), L("Drive safely!", "با احتیاط برانید!")],
    "caught": [L("Licence and papers, please.", "گواهینامه و مدارک، لطفاً."), L("The camera saw everything.", "دوربین همه چیز را ثبت کرد.")],
    "ok": [L("Good driving, well done.", "رانندگی خوب، آفرین."), L("Thanks for stopping.", "ممنون که ایستادی.")],
}
LIMITS = {"Main St": 40, "Oak Ave": 40, "Maple St": 40, "Pine Ln": 30, "Harbor Rd": 50, "New City Rd": 60}
emit("traffic_rules", "TrafficRulesStyle", "traffic_rules_style", [
    ("strict_city", "Strict city rules", "3 signalised intersections (cameras, officer at Oak/Maple), STOP on Pine Ln at Maple St, limits 30-60 km/h, 2nd offence = licence + car taken.",
     {"name_fa": "قوانین سخت شهری", "speed_limits": LIMITS, "signals": SIGNALS, "stops": STOPS,
      "speed_cameras": [{"pos": V2(51.0, -22.0), "yaw": 180.0}, {"pos": V2(25.0, -95.6), "yaw": 0.0}], "officer_lines": OFFICER}),
    ("gentle_city", "Gentle rules", "Same signals; shorter stops, smaller fines, licence taken only at the 3rd offence.",
     {"name_fa": "قوانین ملایم", "speed_limits": LIMITS, "signals": SIGNALS, "stops": STOPS, "speed_cameras": [], "officer_lines": OFFICER,
      "stop_hold_s": 2.0, "min_red_wait_s": 3.0, "red_light_fine": 80, "stop_sign_fine": 30, "offences_to_confiscate": 3, "speed_tolerance_kmh": 10.0}),
], "strict_city")

# ====================================================================== 2. road_markings
reg("road_markings")
style_script("road_markings", "road_marking_style", "RoadMarkingStyle",
    "v7b.1 road markings painted over the (wider) asphalt: stop lines at signals and\nSTOP signs, solid centre lines near junctions, lane edge lines, parking bays on\nMain St, turn arrows before the signals, 'SCHOOL' / 'مدرسه' text by the school\nand give-way triangles at the roundabout. (Dashed centre lines and zebra\ncrossings come from TownBuilder.) One merged mesh. Consumer: RoadMarkings.", [
    ("paint", "Color", "Color(0.95, 0.94, 0.88)", "white paint"),
    ("center_paint", "Color", "Color(0.96, 0.78, 0.18)", "solid centre lines near junctions"),
    ("stop_line_w", "float", "0.45", ""), ("line_w", "float", "0.14", ""),
    ("edge_offset", "float", "0.35", "edge line inset from the kerb"),
    ("edge_lines", "bool", "true", ""), ("parking_bays", "bool", "true", "Main St parking strip"),
    ("bay_length", "float", "6.0", ""), ("arrows", "bool", "true", ""),
    ("school_text", "Dictionary", "{}", "{en, fa, pos, yaw}"),
    ("solid_near_junction", "float", "14.0", "m of solid centre line before a signal / stop"),
])
SCHOOL_TEXT = {"en": "SCHOOL", "fa": "مدرسه", "pos": V2(34.0, -87.8), "yaw": 90.0}
emit("road_markings", "RoadMarkingStyle", "road_marking_style", [
    ("city_white", "City markings", "Bright white lane / stop lines, yellow centre lines near junctions, parking bays, arrows, school text.",
     {"name_fa": "خط‌کشی شهری", "school_text": SCHOOL_TEXT}),
    ("faded_paint", "Faded paint", "Older, greyer paint; no arrows or parking bays.",
     {"name_fa": "رنگ کهنه", "school_text": SCHOOL_TEXT, "paint": (0.72, 0.72, 0.68), "center_paint": (0.75, 0.66, 0.3),
      "arrows": False, "parking_bays": False}),
], "city_white")

# ====================================================================== 3. traffic_signs
reg("traffic_signs")
style_script("traffic_signs", "traffic_sign_style", "TrafficSignStyle",
    "v7b.1 traffic signs on poles: STOP (ایست), give way at the roundabout,\nspeed-limit discs matching traffic_rules, no parking, one-way arrows on the\nroundabout, school zone, and Persian / English direction boards at the main\njunctions. Signs read the street names from TownLayout. Consumer: TrafficSigns.", [
    ("bilingual", "bool", "true", "English under the Persian text"),
    ("pole_h", "float", "2.4", ""), ("disc", "float", "0.62", "sign diameter (m)"),
    ("limit_every", "float", "45.0", "m between repeated speed-limit signs"),
    ("no_parking", "Array", "[]", "{pos, yaw}"),
    ("directions", "Array", "[]", "{pos, yaw, lines: [{fa, en, arrow}]} direction boards"),
])
DIRS = [
    # On the right-hand sidewalk before a junction, facing the approaching drivers.
    {"pos": V2(-5.4, -103.5), "yaw": 180.0, "lines": [{"fa": "میدان شهر", "en": "Town Square", "arrow": "up"}, {"fa": "مدرسه", "en": "School", "arrow": "left"}, {"fa": "کلیسا", "en": "Church", "arrow": "right"}]},
    {"pos": V2(-56.5, -44.4), "yaw": -90.0, "lines": [{"fa": "میدان شهر", "en": "Town Square", "arrow": "up"}, {"fa": "پلیس / کوچه‌ی کاج", "en": "Police / Pine Ln", "arrow": "left"}]},
    {"pos": V2(67.0, -55.6), "yaw": 90.0, "lines": [{"fa": "میدان شهر", "en": "Town Square", "arrow": "up"}, {"fa": "بندر و ساحل", "en": "Harbour & Beach", "arrow": "left"}]},
    {"pos": V2(43.5, -44.4), "yaw": -90.0, "lines": [{"fa": "شهر جدید (در دست ساخت)", "en": "New City (u/c)", "arrow": "up"}, {"fa": "بندر و ساحل", "en": "Harbour & Beach", "arrow": "right"}]},
    {"pos": V2(18.5, -44.4), "yaw": -90.0, "lines": [{"fa": "شهر جدید", "en": "New City", "arrow": "up"}, {"fa": "بیمارستان", "en": "Hospital", "arrow": "left"}, {"fa": "سوپرمارکت", "en": "Supermarket", "arrow": "right"}]},
]
NOPARK = [{"pos": V2(-6.0, -84.6), "yaw": 180.0}, {"pos": V2(6.2, -66.0), "yaw": 0.0}, {"pos": V2(-50.0, -55.9), "yaw": 180.0}, {"pos": V2(60.0, -44.1), "yaw": 0.0}]
emit("traffic_signs", "TrafficSignStyle", "traffic_sign_style", [
    ("bilingual", "Persian + English signs", "STOP / give way / speed limits / no parking / one-way / school zone + 4 direction boards, Persian with English.",
     {"name_fa": "تابلوهای فارسی و انگلیسی", "no_parking": NOPARK, "directions": DIRS}),
    ("persian_only", "Persian-only signs", "The same signs with Persian text only.",
     {"name_fa": "تابلوهای فقط فارسی", "no_parking": NOPARK, "directions": DIRS, "bilingual": False}),
], "bilingual")

# ====================================================================== 4. street_lighting
reg("street_lighting")
style_script("street_lighting", "street_lighting_style", "StreetLightingStyle",
    "v7b.1 a brighter town at night: extra street lights along every paved street\n(both sides), tall lights at intersections, a ring around the square, lights\nalong paths / the park / market, shop-front sconces, warm light pools on the\nground and a gentle night ambient lift. Cheap on the web: emissive lamps +\nadditive ground pools everywhere, only `pool_lights` real OmniLights follow\nthe camera. Consumer: StreetLighting (+ DayNightCycle night_lights group).", [
    ("spacing", "float", "10.0", "m between new lamps on each side"),
    ("pool_lights", "int", "10", "real lights near the camera"),
    ("light_range", "float", "11.0", ""), ("light_energy", "float", "1.15", "x DayNightCycle lamp energy"),
    ("light_color", "Color", "Color(1.0, 0.78, 0.48)", ""),
    ("ground_pools", "bool", "true", "warm additive light pool under every lamp"),
    ("pool_radius", "float", "4.2", ""), ("pool_alpha", "float", "0.32", ""),
    ("night_ambient", "float", "0.62", "minimum ambient light energy at full night"),
    ("ambient_tint", "Color", "Color(0.55, 0.5, 0.62)", "night ambient colour (warmer than moonlight)"),
    ("extra_points", "Array", "[]", "V2 extra lamp spots (paths, park, market, beach walk)"),
    ("shop_sconces", "bool", "true", "a lit sconce beside every shop / office door"),
    ("intersection_lamps", "bool", "true", ""),
])
EXTRA = [V2(-6, -22), V2(6, -22), V2(-6, -28), V2(6, -28), V2(0.8, -37.5), V2(-3, -16), V2(3, -8), V2(-1.6, 1.5), V2(-12, 3.5),
         V2(14, 2.4), V2(30, 6.2), V2(-26, 9.5), V2(-30, 18.0), V2(57, -105.5), V2(48, -117.5), V2(-12.5, -124.6), V2(-17.5, -121.6),
         V2(-36, -24), V2(-20, -21)]
emit("street_lighting", "StreetLightingStyle", "street_lighting_style", [
    ("bright_city", "Bright city nights", "Lamps every 10 m on both sides, junction + square + path lights, warm pools, lifted night ambient.",
     {"name_fa": "شب‌های روشن شهر", "extra_points": EXTRA}),
    ("soft_glow", "Soft glow", "Fewer, dimmer lamps (every 16 m), smaller pools, darker nights.",
     {"name_fa": "نور ملایم", "extra_points": EXTRA, "spacing": 16.0, "pool_lights": 6, "light_energy": 0.8, "pool_alpha": 0.2, "night_ambient": 0.45}),
], "bright_city")

# ====================================================================== 5. driving_license
reg("driving_license")
style_script("driving_license", "license_style", "LicenseStyle",
    "v7b.1 driving licence: read the Persian rules booklet and pass a short quiz at\nthe traffic desk in the police station. Buying a car needs the licence; driving\nany car without one is fined (once per day) and counts as an offence. At the\n2nd offence the licence is confiscated for `confiscation_days` and the car is\ntowed to the impound lot - it is released for a fee once you have your licence\nback (after the wait AND a passed re-test). Residents have licences unless\ntheirs was taken. Consumers: LicenseOffice, LicensePanel, TrafficRules, Impound.", [
    ("pages", "Array", "[]", "booklet pages: {title: {en, fa}, lines: [{en, fa}]}"),
    ("questions", "Array", "[]", "{q: {en, fa}, options: [{en, fa}], answer}"),
    ("quiz_count", "int", "6", "questions per test"), ("pass_mark", "int", "5", ""),
    ("test_fee", "int", "25", ""), ("confiscation_days", "int", "2", ""),
    ("impound_fee", "int", "120", ""), ("residents_licensed", "bool", "true", ""),
    ("impound_pos", "Vector2", "Vector2(-69.0, -62.0)", "impound lot (west end of Main St, south side)"),
    ("impound_yaw", "float", "0.0", ""),
])
PAGES = [
    {"title": L("1. Traffic lights", "۱. چراغ راهنمایی"), "lines": [
        L("Red: stop before the white stop line and wait. Never cross on red.", "قرمز: پشت خط ایست سفید بایست و صبر کن. هرگز با چراغ قرمز رد نشو."),
        L("At red you wait about 5 seconds or more - then the light turns green for you.", "پشت چراغ قرمز حدود ۵ ثانیه یا بیشتر صبر می‌کنی - بعد چراغ برایت سبز می‌شود."),
        L("Yellow: stop if you safely can. Green: go, but give way to people on the crossing.", "زرد: اگر می‌توانی با اطمینان بایست. سبز: برو، ولی به عابران روی خط عابر راه بده.")]},
    {"title": L("2. STOP signs", "۲. تابلوی ایست"), "lines": [
        L("At a STOP sign come to a full stop at the line for about 5 seconds.", "سر تابلوی ایست کاملاً پشت خط بایست، حدود ۵ ثانیه."),
        L("Then go when the road is clear. Rolling through is a fine.", "بعد وقتی راه خالی بود برو. رد شدن بدون توقف جریمه دارد.")]},
    {"title": L("3. Speed limits", "۳. محدودیت سرعت"), "lines": [
        L("Main St, Oak Ave, Maple St: 40 km/h. Pine Ln: 30. Harbor Rd: 50. New City Rd: 60.", "خیابان اصلی، بلوط و افرا: ۴۰ کیلومتر. کوچه‌ی کاج: ۳۰. جاده‌ی بندر: ۵۰. جاده‌ی شهر جدید: ۶۰."),
        L("Around the square and near the school: 25 km/h.", "دور میدان و کنار مدرسه: ۲۵ کیلومتر."),
        L("The round sign with the red ring shows the limit; your dashboard shows it too.", "تابلوی گرد با حلقه‌ی قرمز سرعت مجاز را نشان می‌دهد؛ داشبورد هم نشانش می‌دهد.")]},
    {"title": L("4. Cameras and the officer", "۴. دوربین‌ها و پلیس راهنمایی"), "lines": [
        L("Cameras at the main junctions photograph red-light runners and speeders.", "دوربین‌های تقاطع‌های اصلی از کسانی که چراغ قرمز را رد می‌کنند یا تند می‌روند عکس می‌گیرند."),
        L("Every fine goes to the city fund. The police file a report and the paper prints it.", "همه‌ی جریمه‌ها به صندوق شهرداری می‌رود. پلیس گزارش می‌نویسد و روزنامه چاپش می‌کند.")]},
    {"title": L("5. Licence points", "۵. نمره‌ی منفی و توقیف"), "lines": [
        L("The 2nd offence: your licence is confiscated and your car is towed to the impound lot.", "تخلف دوم: گواهینامه‌ات توقیف و ماشینت به پارکینگ توقیف برده می‌شود."),
        L("After 2 days you can retake the test; then pay the fee to get the car back.", "بعد از ۲ روز می‌توانی دوباره امتحان بدهی؛ بعد با پرداخت هزینه ماشین را پس بگیری."),
        L("Driving without a licence is also an offence.", "رانندگی بدون گواهینامه هم تخلف است.")]},
    {"title": L("6. Courtesy", "۶. ادب رانندگی"), "lines": [
        L("Drive on the right. Park only in the parking bays, never on crossings or by NO PARKING signs.", "از سمت راست برو. فقط در جای پارک بایست، نه روی خط عابر و نه کنار تابلوی توقف ممنوع."),
        L("Headlights on at night (H). Give way at the roundabout - traffic inside goes first.", "شب‌ها چراغ روشن (H). در میدان راه بده - ماشین‌های داخل میدان حق تقدم دارند."),
        L("Never drive after strong drinks.", "بعد از نوشیدنی قوی هرگز رانندگی نکن.")]},
]


def Q(en, fa, opts, ans):
    return {"q": L(en, fa), "options": [L(a, b) for a, b in opts], "answer": ans}


QUESTIONS = [
    Q("The light is red. What do you do?", "چراغ قرمز است. چه می‌کنی؟", [("Stop behind the stop line and wait", "پشت خط ایست می‌ایستم و صبر می‌کنم"), ("Go if nobody is coming", "اگر کسی نیامد رد می‌شوم"), ("Honk and go", "بوق می‌زنم و می‌روم")], 0),
    Q("At a STOP sign you must...", "سر تابلوی ایست باید...", [("Slow down a little", "کمی آهسته کنم"), ("Stop completely for about 5 seconds", "حدود ۵ ثانیه کاملاً بایستم"), ("Only stop at night", "فقط شب بایستم")], 1),
    Q("Speed limit on Main St?", "سرعت مجاز خیابان اصلی؟", [("25 km/h", "۲۵ کیلومتر"), ("40 km/h", "۴۰ کیلومتر"), ("60 km/h", "۶۰ کیلومتر")], 1),
    Q("Speed limit near the school?", "سرعت مجاز کنار مدرسه؟", [("25 km/h", "۲۵ کیلومتر"), ("50 km/h", "۵۰ کیلومتر"), ("No limit", "محدودیت ندارد")], 0),
    Q("Where do traffic fines go?", "جریمه‌های رانندگی کجا می‌رود؟", [("To the officer", "به جیب مأمور"), ("To the city fund", "به صندوق شهرداری"), ("Nowhere", "هیچ‌جا")], 1),
    Q("What happens at your 2nd offence?", "در تخلف دوم چه می‌شود؟", [("Nothing", "هیچ"), ("A warning", "یک تذکر"), ("Licence confiscated, car impounded", "گواهینامه توقیف و ماشین به پارکینگ می‌رود")], 2),
    Q("The light turns yellow and you can stop safely.", "چراغ زرد شد و می‌توانی با اطمینان بایستی.", [("Speed up", "گاز می‌دهم"), ("Stop", "می‌ایستم"), ("Flash my lights", "چراغ می‌زنم")], 1),
    Q("Entering the roundabout at the square:", "ورود به میدان شهر:", [("Traffic inside goes first", "ماشین‌های داخل میدان حق تقدم دارند"), ("I go first", "من اول می‌روم"), ("The bigger car goes first", "ماشین بزرگ‌تر اول می‌رود")], 0),
    Q("At night you drive with...", "شب با ... رانندگی می‌کنی", [("Headlights on", "چراغ روشن"), ("Lights off to save fuel", "چراغ خاموش برای صرفه‌جویی"), ("Hazard lights only", "فقط فلاشر")], 0),
    Q("After strong drinks at the cafe:", "بعد از نوشیدنی قوی در کافه:", [("I drive slowly", "آهسته رانندگی می‌کنم"), ("I don't drive", "رانندگی نمی‌کنم"), ("I drive on Pine Ln only", "فقط در کوچه‌ی کاج می‌رانم")], 1),
]
emit("driving_license", "LicenseStyle", "license_style", [
    ("standard", "Standard licence", "6-page Persian booklet, 6 of 10 questions, 5 to pass, fee 25; 2-day confiscation, impound fee 120.",
     {"name_fa": "گواهینامه‌ی معمولی", "pages": PAGES, "questions": QUESTIONS}),
    ("strict", "Strict exam", "All 10 questions, 9 to pass, fee 40, 3-day confiscation, impound fee 200.",
     {"name_fa": "امتحان سخت", "pages": PAGES, "questions": QUESTIONS, "quiz_count": 10, "pass_mark": 9, "test_fee": 40,
      "confiscation_days": 3, "impound_fee": 200}),
], "standard")

# ====================================================================== 6. car_dealership
reg("car_dealership")
style_script("car_dealership", "dealership_style", "DealershipStyle",
    "v7b.1 car dealership (the v6b 'later' note): a small lot by the road out of\ntown with a few cars and prices. Buying needs a driving licence and the money;\nthe car is yours (saved), parked at the lot and remembered where you leave it.\nConsumers: Dealership, DealershipPanel.", [
    ("pos", "Vector2", "Vector2(76.0, -63.5)", "lot centre"), ("yaw", "float", "0.0", ""),
    ("size", "Vector2", "Vector2(7.4, 11.0)", ""),
    ("name", "Dictionary", "{}", "{en, fa}"),
    ("cars", "Array", "[]", "{id, model, en, fa, price, color, top_kmh}"),
    ("requires_license", "bool", "true", ""),
])
CARS = [
    {"id": "city_sedan", "model": "sedan", "en": "City sedan", "fa": "سواری شهری", "price": 900, "color": (0.75, 0.1, 0.12), "top_kmh": 55},
    {"id": "family_van", "model": "van", "en": "Family van", "fa": "ون خانوادگی", "price": 1300, "color": (0.15, 0.3, 0.6), "top_kmh": 48},
    {"id": "work_truck", "model": "delivery", "en": "Small truck", "fa": "کامیونت", "price": 1600, "color": (0.9, 0.9, 0.88), "top_kmh": 45},
]
emit("car_dealership", "DealershipStyle", "dealership_style", [
    ("town_motors", "Town Motors", "3 cars (sedan 900, van 1300, small truck 1600); licence required.",
     {"name_fa": "نمایشگاه خودروی شهر", "name": L("Town Motors", "نمایشگاه خودروی شهر"), "cars": CARS}),
    ("budget_lot", "Budget lot", "Cheaper used cars (60%), same rules.",
     {"name_fa": "خودروهای کارکرده", "name": L("Used cars", "خودروی کارکرده"),
      "cars": [dict(c, price=int(c["price"] * 0.6), en="Used " + c["en"].lower(), fa=c["fa"] + " کارکرده") for c in CARS]}),
], "town_motors")

# ====================================================================== 7. npc_traffic
reg("npc_traffic")
style_script("npc_traffic", "npc_traffic_style", "NpcTrafficStyle",
    "v7b.1 townsfolk traffic: a few cars drive loops on the road graph (right-hand\nlane), stop at red lights and STOP signs, keep the speed limit, keep a gap to\nthe car in front and stop for people. Consumer: NpcTraffic (TrafficCar).", [
    ("cars", "Array", "[]", "{model, color, loop: [V2 waypoints]}"),
    ("gap", "float", "7.0", "m to the vehicle ahead"),
    ("active_hours", "Vector2", "Vector2(6.0, 23.5)", "cars park outside these hours"),
])
LOOP_W = [V2(-25, -50), V2(-45, -68), V2(-25, -90), V2(0, -76), V2(-6, -52)]
LOOP_E = [V2(30, -50), V2(55, -32), V2(47, -9), V2(55, -42), V2(20, -50), V2(5, -58)]
LOOP_N = [V2(0, -105), V2(0, -126), V2(0, -98), V2(30, -90), V2(58, -90), V2(15, -90), V2(0, -70), V2(-6, -52)]
emit("npc_traffic", "NpcTrafficStyle", "npc_traffic_style", [
    ("light_traffic", "Light traffic", "3 townsfolk cars on west / east / north loops.",
     {"name_fa": "ترافیک سبک", "cars": [{"model": "sedan", "color": (0.85, 0.85, 0.82), "loop": LOOP_W},
                                         {"model": "van", "color": (0.2, 0.42, 0.3), "loop": LOOP_E},
                                         {"model": "sedan", "color": (0.12, 0.18, 0.35), "loop": LOOP_N}]}),
    ("busy_traffic", "Busy traffic", "5 cars, two per loop on the west / north loops.",
     {"name_fa": "ترافیک شلوغ", "cars": [{"model": "sedan", "color": (0.85, 0.85, 0.82), "loop": LOOP_W},
                                          {"model": "sedan", "color": (0.55, 0.08, 0.1), "loop": LOOP_W[2:] + LOOP_W[:2]},
                                          {"model": "van", "color": (0.2, 0.42, 0.3), "loop": LOOP_E},
                                          {"model": "sedan", "color": (0.12, 0.18, 0.35), "loop": LOOP_N},
                                          {"model": "delivery", "color": (0.9, 0.7, 0.2), "loop": LOOP_N[4:] + LOOP_N[:4]}]}),
], "light_traffic")

# ====================================================================== 8. transit (vehicle module)
reg("transit")
style_script("transit", "transit_style", "TransitStyle",
    "v7b.1 vehicle module (first entry: the city bus). `vehicles` describes each\nvehicle type (size, colours, engine sound id, seats) so more vehicles can be\nadded as data. The bus line drives a loop with stops (shelter + Persian sign +\ntimetable), obeys lights and limits, residents get on and off, and you can\nride it (E at the door, pay the fare, E again to get off at the next stop).\nA second bus stands at the terminal on Main St for you to drive (licence\nrules apply). Consumers: Transit, BusLine, BusStop, DrivableBus, CarAudio.", [
    ("vehicles", "Dictionary", "{}", "id -> {en, fa, length, width, height, color, stripe, engine, seats, top_kmh}"),
    ("line", "Dictionary", "{}", "{id, en, fa, vehicle, route: [V2], stops: [{id, pos (road centre), side (V2 shelter), en, fa}], dwell_s, speed}"),
    ("fare", "int", "5", ""), ("interval_min", "int", "30", "timetable: a bus every N minutes"),
    ("hours", "Vector2", "Vector2(6.0, 23.0)", "service hours"),
    ("terminal", "Dictionary", "{}", "{pos, yaw, vehicle, en, fa} drivable bus parking"),
    ("residents_ride", "bool", "true", ""), ("max_riders", "int", "6", ""),
])
VEH = {"city_bus": {"en": "City bus", "fa": "اتوبوس شهری", "length": 9.6, "width": 2.5, "height": 3.0, "color": (0.1, 0.45, 0.62),
                    "stripe": (0.96, 0.82, 0.25), "engine": "bus", "seats": 22, "top_kmh": 45},
       "minibus": {"en": "Minibus", "fa": "مینی‌بوس", "length": 7.0, "width": 2.3, "height": 2.7, "color": (0.92, 0.9, 0.85),
                   "stripe": (0.2, 0.5, 0.3), "engine": "bus", "seats": 14, "top_kmh": 50}}
ROUTE = [V2(-20, -50), V2(-45, -62), V2(-45, -86), V2(-23, -90), V2(44, -90), V2(60, -90), V2(20, -90), V2(0, -80), V2(0, -70),
         V2(0, -63), V2(14, -50), V2(40.5, -50), V2(55, -40), V2(55, -35), V2(48, -12), V2(55, -42), V2(22, -50), V2(-8, -50)]
BSTOPS = [
    {"id": "police", "pos": V2(-29, -50), "side": V2(-29, -56.2), "en": "Main St / Police", "fa": "خیابان اصلی / پلیس"},
    {"id": "mosque", "pos": V2(-20, -90), "side": V2(-20, -84.2), "en": "Maple St / Mosque", "fa": "خیابان افرا / مسجد"},
    {"id": "school", "pos": V2(44, -90), "side": V2(44, -84.2), "en": "School", "fa": "مدرسه"},
    {"id": "oak", "pos": V2(0, -70), "side": V2(-5.6, -70), "en": "Oak Ave", "fa": "خیابان بلوط"},
    {"id": "hospital", "pos": V2(40.5, -50), "side": V2(40.5, -44.2), "en": "Supermarket / Hospital", "fa": "سوپرمارکت / بیمارستان"},
    {"id": "harbor", "pos": V2(55, -35), "side": V2(49.6, -35), "en": "Harbor Rd / Beach", "fa": "جاده‌ی بندر / ساحل"},
]
LINE = {"id": "line1", "en": "Line 1", "fa": "خط ۱", "vehicle": "city_bus", "route": ROUTE, "stops": BSTOPS, "dwell_s": 7.0, "speed": 8.0}
emit("transit", "TransitStyle", "transit_style", [
    ("city_bus", "City bus line 1", "Blue city bus on a 6-stop loop (Police, Mosque, School, Oak Ave, Hospital, Harbour), fare 5, every 30 min; a drivable bus at the terminal.",
     {"name_fa": "خط ۱ اتوبوس شهری", "vehicles": VEH, "line": LINE,
      "terminal": {"pos": V2(-62, -54.1), "yaw": -90.0, "vehicle": "city_bus", "en": "Bus terminal", "fa": "پایانه‌ی اتوبوس"}}),
    ("minibus", "Minibus line", "A smaller white minibus on the same loop, fare 3, every 20 min.",
     {"name_fa": "خط مینی‌بوس", "vehicles": VEH, "line": dict(LINE, vehicle="minibus", speed=8.5), "fare": 3, "interval_min": 20,
      "terminal": {"pos": V2(-62, -54.1), "yaw": -90.0, "vehicle": "minibus", "en": "Minibus terminal", "fa": "پایانه‌ی مینی‌بوس"}}),
], "city_bus")

# ====================================================================== 9. car_sounds
reg("car_sounds")
style_script("car_sounds", "car_sound_style", "CarSoundStyle",
    "v7b.1 procedural car sounds (synthesised at start, no files): an engine loop\nper car model (firing frequency, cylinders, harmonics, roughness; diesel\nknock for the bus / truck / tractor) whose pitch and volume follow RPM from\nspeed and gear; a horn per model; indicator ticks; tyre squeal on hard braking\nor sharp turns; door clunks. Consumers: CarAudio (DrivableCar + RoadCar).", [
    ("engines", "Dictionary", "{}", "model -> {hz, cyl, harm (Array), rough, diesel, idle_rpm, max_rpm, db, gears}"),
    ("horns", "Dictionary", "{}", "model -> [f1, f2] Hz"),
    ("indicator_hz", "float", "1800.0", ""), ("indicator_period", "float", "0.42", "s"),
    ("squeal_decel", "float", "7.5", "m/s2 that makes the tyres squeal"),
    ("door_pitch", "Dictionary", "{}", "model -> pitch"),
    ("npc_engines", "bool", "true", "NPC cars / bus / police have engines too (nearest few)"),
    ("max_npc_engines", "int", "4", ""),
])
ENG = {
    "sedan": {"hz": 38.0, "cyl": 4, "harm": [1.0, 0.55, 0.3, 0.12], "rough": 0.08, "diesel": False, "idle_rpm": 850, "max_rpm": 6200, "db": -10.0, "gears": 5},
    "taxi": {"hz": 36.0, "cyl": 4, "harm": [1.0, 0.5, 0.35, 0.1], "rough": 0.1, "diesel": False, "idle_rpm": 800, "max_rpm": 5800, "db": -10.0, "gears": 5},
    "suv": {"hz": 30.0, "cyl": 6, "harm": [1.0, 0.7, 0.4, 0.2], "rough": 0.07, "diesel": False, "idle_rpm": 750, "max_rpm": 5600, "db": -9.0, "gears": 5},
    "van": {"hz": 31.0, "cyl": 4, "harm": [1.0, 0.65, 0.25, 0.2], "rough": 0.14, "diesel": True, "idle_rpm": 800, "max_rpm": 4600, "db": -9.0, "gears": 5},
    "delivery": {"hz": 26.0, "cyl": 4, "harm": [1.0, 0.8, 0.5, 0.3], "rough": 0.2, "diesel": True, "idle_rpm": 700, "max_rpm": 3800, "db": -8.0, "gears": 5},
    "police": {"hz": 34.0, "cyl": 6, "harm": [1.0, 0.6, 0.45, 0.2], "rough": 0.06, "diesel": False, "idle_rpm": 800, "max_rpm": 6500, "db": -10.0, "gears": 5},
    "ambulance": {"hz": 28.0, "cyl": 4, "harm": [1.0, 0.75, 0.35, 0.25], "rough": 0.16, "diesel": True, "idle_rpm": 750, "max_rpm": 4200, "db": -9.0, "gears": 5},
    "firetruck": {"hz": 22.0, "cyl": 6, "harm": [1.0, 0.9, 0.6, 0.35], "rough": 0.24, "diesel": True, "idle_rpm": 650, "max_rpm": 3200, "db": -7.0, "gears": 6},
    "tractor": {"hz": 18.0, "cyl": 3, "harm": [1.0, 0.95, 0.7, 0.4], "rough": 0.3, "diesel": True, "idle_rpm": 600, "max_rpm": 2600, "db": -8.0, "gears": 4},
    "bus": {"hz": 20.0, "cyl": 6, "harm": [1.0, 0.85, 0.6, 0.45], "rough": 0.26, "diesel": True, "idle_rpm": 650, "max_rpm": 2800, "db": -7.0, "gears": 6},
}
HORNS = {"sedan": [392, 494], "taxi": [440, 554], "suv": [349, 440], "van": [330, 415], "delivery": [294, 370], "police": [520, 660],
         "ambulance": [494, 622], "firetruck": [220, 277], "tractor": [262, 330], "bus": [196, 247]}
DOORS = {"sedan": 1.15, "taxi": 1.2, "suv": 0.95, "van": 0.85, "delivery": 0.8, "tractor": 1.3, "bus": 0.6, "police": 1.1, "ambulance": 0.85}
ELEC = {k: dict(v, hz=v["hz"] * 3.0, harm=[1.0, 0.15, 0.05, 0.0], rough=0.01, diesel=False, db=v["db"] - 6.0) for k, v in ENG.items()}
emit("car_sounds", "CarSoundStyle", "car_sound_style", [
    ("distinct_engines", "Distinct engines", "10 engine voices (petrol 4/6-cyl, diesel van / truck / ambulance / fire truck / bus, tractor), horns, indicators, tyres, doors.",
     {"name_fa": "صدای موتور متمایز", "engines": ENG, "horns": HORNS, "door_pitch": DOORS}),
    ("quiet_electric", "Quiet electric", "Soft electric whine for every vehicle (no diesel knock), same horns.",
     {"name_fa": "برقی و بی‌صدا", "engines": ELEC, "horns": HORNS, "door_pitch": DOORS, "squeal_decel": 9.0}),
], "distinct_engines")

# ====================================================================== 10. cafe_lounge
reg("cafe_lounge")
style_script("cafe_lounge", "cafe_lounge_style", "CafeLoungeStyle",
    "v7b.1 classy cafe: the v7b terrace gets polished stone tiles, cushioned\nseats, table linen + candles, a pergola with warm pendant lights and potted\nplants; next to it an indoor cafe-lounge (walk in) that becomes a disco at\nnight: dance floor with coloured tiles + moving lights, DJ booth (the v7b DJ\npost) and a bar (the v7b bartender / menu), positional music, and a crowd of\nresidents dancing. Dress code: stylish and modest (jackets / long sleeves,\nlong trousers or skirts) - never revealing. The v7b tipsy limit and fights\nstill apply. Consumers: CafeLounge, TerraceCafe (decor).", [
    ("hall_pos", "Vector2", "Vector2(-37.0, -23.0)", "indoor lounge centre"), ("hall_yaw", "float", "90.0", "deg; door faces +z local"),
    ("hall_size", "Vector3", "Vector3(12.0, 3.8, 10.0)", ""),
    ("wall", "Color", "Color(0.2, 0.17, 0.2)", ""), ("trim", "Color", "Color(0.78, 0.62, 0.3)", "brass trim"),
    ("open_hours", "Vector2", "Vector2(16.0, 24.0)", "cafe-lounge"), ("disco_hours", "Vector2", "Vector2(20.0, 24.0)", "dance floor + DJ"),
    ("crowd", "int", "12", "people inside at disco time"),
    ("dance_colors", "Array", "[]", "Colors of the floor tiles / lights"),
    ("music", "PackedStringArray", "PackedStringArray()", ""), ("music_db", "float", "-3.0", ""),
    ("dress_tops", "PackedStringArray", "PackedStringArray()", "allowed top styles (modest)"),
    ("dress_up", "String", "\"jacket\"", "top style residents change into for the evening"),
    ("terrace_decor", "bool", "true", ""), ("disco", "bool", "true", "false = a calm jazz lounge"),
    ("name", "Dictionary", "{}", "{en, fa}"),
])
emit("cafe_lounge", "CafeLoungeStyle", "cafe_lounge_style", [
    ("classy_lounge", "Classy lounge + disco", "Stone terrace, pergola lights, plants; indoor lounge with a disco 20-24, crowd of 12, modest stylish dress code.",
     {"name_fa": "کافه لانژ و دیسکو", "name": L("Lounge Cafe", "کافه لانژ"),
      "dance_colors": [(0.95, 0.3, 0.55), (0.3, 0.55, 1.0), (1.0, 0.75, 0.25), (0.45, 0.95, 0.6), (0.7, 0.35, 1.0)],
      "music": psa("res://assets/audio/music/zarb_loop.ogg", "res://assets/audio/music/radio_loop.ogg"),
      "dress_tops": psa("jacket", "long_sleeve", "work_shirt", "polo")}),
    ("jazz_lounge", "Quiet jazz lounge", "The same rooms without the disco: warm light, soft radio music, fewer people.",
     {"name_fa": "لانژ آرام", "name": L("Lounge Cafe", "کافه لانژ"), "disco": False, "crowd": 6,
      "dance_colors": [(1.0, 0.75, 0.45)], "music": psa("res://assets/audio/music/radio_loop.ogg"), "music_db": -10.0,
      "dress_tops": psa("jacket", "long_sleeve", "work_shirt", "polo")}),
], "classy_lounge")

# ---------------------------------------------------------------- write only my types
fresh = json.load(open(config_path, encoding="utf-8"))
for t in MY_TYPES:
    fresh[t] = config[t]
json.dump(fresh, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 traffic modules written: " + ", ".join(MY_TYPES))
