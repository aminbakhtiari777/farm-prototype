#!/usr/bin/env python3
"""v7b.1 police / road safety module (Amin: 'the police car runs people over'):
  road_safety   careful_drivers (default) / light_checks
Every AI vehicle (police, ambulance, fire truck, van, wood pickup, NPC traffic,
bus) looks ahead along its own path (nose + reaction + braking distance), brakes
and yields to pedestrians and the farmer - no time-out that drives through
people. Pedestrians wait at the kerb when a moving car is close. When any car
(player or AI) hits a person they react (stumble / fall, Persian exclamation,
get back up); a hard hit (>= hard_hit_kmh) keeps them down, the ambulance and
the police come, townspeople gather and talk, the driver is fined (TrafficRules
offence / impound). Non-graphic: nobody dies, the person recovers after the
paramedics' visit.
Consumers: RoadSafety (RoadCar.people_gate, TownspersonBot.move_filter),
AccidentResponse (scripts/v7b1_police/).
Only this type is (re)written in the JSON config (re-read right before saving).
Re-run after editing, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, config, config_path = ns["style_script"], ns["emit"], ns["config"], ns["config_path"]
MY_TYPES = ["road_safety"]


def L(en, fa):
    return {"en": en, "fa": fa}


style_script("road_safety", "road_safety_style", "RoadSafetyStyle",
    "v7b.1 road safety: AI cars brake and yield for people along their path\n"
    "(look-ahead = nose + stop margin + reaction + braking distance, curved along\n"
    "the route), pedestrians wait at the kerb for close moving cars, hit\n"
    "reactions (stumble / fall + Persian exclamation, get up), and for a hard hit\n"
    "an ambulance + police response, a talking crowd and a fine / offence for the\n"
    "driver. Non-graphic, nobody dies. Consumers: RoadSafety, AccidentResponse.", [
    ("enabled", "bool", "true", "false = the old v6b 3 m box (not recommended)"),
    ("brake_decel", "float", "6.0", "m/s2 planned braking (cars can do 9)"),
    ("reaction_s", "float", "0.35", "s of travel before braking starts"),
    ("stop_margin", "float", "1.6", "m kept between the bumper and a person"),
    ("lane_margin", "float", "0.55", "m added to half the car width for the yield corridor"),
    ("predict_s", "float", "1.2", "s: people walking towards the path count where they will be"),
    ("near_radius", "float", "90.0", "m from the camera: cars nearer check every frame"),
    ("far_interval", "float", "0.3", "s between checks for cars farther away"),
    ("step_aside_s", "float", "2.5", "a townsperson blocking a waiting car this long steps aside"),
    ("pedestrian_wait", "bool", "true", "townspeople wait at the kerb for close moving cars"),
    ("pedestrian_look", "float", "14.0", "m: moving cars this close make walkers wait"),
    ("hit_min_kmh", "float", "3.0", "slower contacts are only a bump"),
    ("hard_hit_kmh", "float", "25.0", "at / above this the person stays down: ambulance + police + crowd"),
    ("stumble_s", "float", "2.2", "s on one knee after a light hit"),
    ("fall_s", "float", "4.0", "s on the ground after a medium hit (>= fall_kmh) before getting up"),
    ("fall_kmh", "float", "14.0", ""),
    ("treat_s", "float", "6.0", "s the paramedics need on the spot"),
    ("down_max_s", "float", "90.0", "fallback: recover after this long even if no ambulance came"),
    ("crowd_radius", "float", "35.0", "m: townspeople this close come to look"),
    ("crowd_min", "int", "3", ""), ("crowd_max", "int", "6", ""),
    ("crowd_ring", "float", "2.6", "m from the person"),
    ("chat_every_s", "float", "2.8", "s between crowd lines"),
    ("crowd_stay_s", "float", "8.0", "s the crowd stays after the person is back up"),
    ("hit_fine", "int", "250", "hard hit (driver)"), ("light_hit_fine", "int", "0", "light hit (0 = warning only)"),
    ("lines", "Dictionary", "{}", "exclaim, hurt, recovered, crowd, police, paramedic, player_hit, driver_sorry -> [{en, fa}]"),
])

LINES = {
    "exclaim": [L("Hey! Watch out!", "آی! حواست کجاست؟!"), L("Ouch! Slow down!", "آخ! یواش‌تر!"),
                L("Whoa! Careful!", "وای! مواظب باش!"), L("Didn't you see me?!", "مگه منو ندیدی؟!")],
    "hurt": [L("Ow... my leg...", "آخ... پام..."), L("Help... I can't get up.", "کمک... نمی‌تونم بلند شم."),
             L("Call an ambulance...", "یکی به آمبولانس زنگ بزنه...")],
    "recovered": [L("Thank you, doctor. I'm fine now.", "ممنون آقای دکتر، الان خوبم."),
                  L("Just a bruise. Thank God.", "فقط کبود شده، خدا رو شکر."),
                  L("I'm OK. I'll be more careful.", "خوبم، دیگه بیشتر مواظبم.")],
    "crowd": [L("Oh my God! Is he alright?", "یا خدا! حالش خوبه؟"), L("Someone call 115!", "یکی به ۱۱۵ زنگ بزنه!"),
              L("He was driving too fast!", "خیلی تند می‌رفت!"), L("Don't move him, wait for the ambulance.", "تکونش ندید، صبر کنید آمبولانس بیاد."),
              L("I saw everything, the car didn't stop.", "من دیدم، ماشینه وای‌نستاد."), L("The police are coming.", "پلیس داره میاد."),
              L("Poor thing... are you OK?", "طفلکی... خوبی؟"), L("These drivers are in such a hurry!", "این راننده‌ها چقدر عجله دارن!"),
              L("Thank God it's not serious.", "خدا رو شکر چیز جدی‌ای نیست.")],
    "police": [L("Everyone step back, please.", "لطفاً همه عقب بایستید."), L("Licence and papers, please.", "گواهینامه و مدارک، لطفاً."),
               L("Hitting a pedestrian is a serious offence.", "زدن عابر پیاده تخلف سنگینی است.")],
    "paramedic": [L("Don't move, we're here. Where does it hurt?", "تکون نخور، ما اینجاییم. کجات درد می‌کنه؟"),
                  L("Nothing broken. You'll be fine.", "چیزی نشکسته. خوب می‌شی.")],
    "player_hit": [L("Ouch! A car bumped into you!", "آخ! یه ماشین بهت خورد!")],
    "driver_sorry": [L("Sorry! I didn't see you!", "ببخشید! ندیدمتون!")],
}

emit("road_safety", "RoadSafetyStyle", "road_safety_style", [
    ("careful_drivers", "Careful drivers", "AI cars brake early and yield for anyone on their path; walkers wait at the kerb; hit reactions; hard hit = ambulance + police + crowd + fine.",
     {"name_fa": "رانندگان محتاط", "lines": LINES}),
    ("light_checks", "Light checks (fast)", "Same rules with cheaper checks for slow laptops: far cars check less often, no walker prediction, smaller crowd.",
     {"name_fa": "بررسی سبک (سریع)", "lines": LINES, "near_radius": 60.0, "far_interval": 0.5, "predict_s": 0.0,
      "pedestrian_look": 10.0, "crowd_max": 4}),
], "careful_drivers")

fresh = json.load(open(config_path, encoding="utf-8"))
for t in MY_TYPES:
    fresh[t] = config[t]
json.dump(fresh, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 police modules written: " + ", ".join(MY_TYPES))
