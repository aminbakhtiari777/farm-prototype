#!/usr/bin/env python3
"""v7b.1 controls patch: generates the control-scheme module style scripts,
their .tres variants and registers them in data/asset_modules.json:
  controls_mouse     desktop_mouse (default) / desktop_mouse_gentle
  controls_touch     touch_twin_stick (default) / touch_fixed_sticks
  controls_keyboard  keyboard_legacy (default) / keyboard_turn
All three schemes run side by side and feed the shared ControlInput autoload
(move_vector, look, steer, throttle). Swap a variant to change how a scheme
feels. (+ ui_text phrases for the new settings row.)
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v6b.py"), encoding="utf-8").read()
head = src.split("# ====================================================================== 1.")[0]
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v6b.py")}
exec(head, ns)
style_script, emit, config, config_path = ns["style_script"], ns["emit"], ns["config"], ns["config_path"]

# ---------------------------------------------------------------- controls_mouse
style_script("controls_mouse", "mouse_controls_style", "MouseControlsStyle",
    "v7b.1 desktop mouse scheme (GTA-style): click the game to capture the mouse\n(pointer lock), then the mouse turns the camera (left/right = yaw, up/down =\npitch); WASD moves relative to the camera. In a car mouse X steers (a virtual\nwheel that re-centres), W/S throttle/brake. Esc (or any panel) releases the\nmouse. Consumers: ControlInput, FollowCamera, Player, DrivableCar.", [
    ("look_deg_per_px", "float", "0.16", "camera degrees per mouse pixel (x Settings camera_sensitivity)"),
    ("capture_on_click", "bool", "true", "left click on the game captures the mouse"),
    ("mouse_steer", "bool", "true", "in a car mouse X steers (else it only orbits the camera)"),
    ("steer_per_px", "float", "0.011", "wheel turn per mouse pixel (-1..1)"),
    ("steer_return", "float", "1.6", "wheel re-centres per second when the mouse is still"),
    ("face_camera_idle", "bool", "true", "standing still, turning the camera turns the character too"),
    ("show_hint", "bool", "true", "small 'click to look around' hint"),
])
emit("controls_mouse", "MouseControlsStyle", "mouse_controls_style", [
    ("desktop_mouse", "Mouse look + mouse steering", "Pointer-lock mouse look, mouse X steers cars, the farmer faces where you look.",
     {"name_fa": "نگاه و فرمان با ماوس"}),
    ("desktop_mouse_gentle", "Gentle mouse (camera only)", "Slower mouse look; in a car the mouse only moves the camera (A/D steer).",
     {"name_fa": "ماوس آرام (فقط دوربین)", "look_deg_per_px": 0.09, "mouse_steer": False, "face_camera_idle": False}),
], "desktop_mouse")

# ---------------------------------------------------------------- controls_touch
style_script("controls_touch", "touch_controls_style", "TouchControlsStyle",
    "v7b.1 touch scheme for phones/tablets (GTA mobile style): LEFT virtual joystick\nmoves (camera-relative; in a car up/down = throttle/brake), RIGHT joystick turns\nthe camera / the character and steers the car. Sticks are semi-transparent,\nmulti-touch safe (each finger tracked by index) and appear where the thumb lands\n(floating) in the left / right half. Buttons: interact, jump, sprint, car, play-as\n(possession) + dig / demolish / fire, brake / horn / lights, controls, menu.\nShown automatically on touch screens. Consumers: TouchControls, ControlInput.", [
    ("floating", "bool", "true", "sticks appear where the thumb lands (else fixed positions)"),
    ("stick_radius", "float", "0.11", "stick radius as a fraction of the short screen side"),
    ("button_size", "float", "0.115", "button diameter as a fraction of the short screen side"),
    ("deadzone", "float", "0.12", ""),
    ("opacity", "float", "0.5", "stick + button opacity"),
    ("look_deg_per_sec", "float", "150.0", "camera yaw speed at full right-stick"),
    ("pitch_deg_per_sec", "float", "80.0", "camera pitch speed at full right-stick"),
    ("left_stick_steers", "bool", "true", "in a car the left stick X steers too"),
    ("right_stick_steers", "bool", "true", "in a car the right stick X steers"),
    ("zone_top", "float", "0.28", "touches above this fraction of the screen height never grab a stick"),
    ("fit_ui", "bool", "true", "phones / web: scale the 1600x900 UI to the screen (canvas_items stretch, keeps text readable on high-DPI screens)"),
])
emit("controls_touch", "TouchControlsStyle", "touch_controls_style", [
    ("touch_twin_stick", "Twin sticks (floating)", "Left stick moves, right stick looks / steers; sticks follow your thumbs.",
     {"name_fa": "دو دسته‌ی شناور"}),
    ("touch_fixed_sticks", "Twin sticks (fixed, large)", "Sticks stay at fixed spots, bigger and a little more opaque.",
     {"name_fa": "دو دسته‌ی ثابت و بزرگ", "floating": False, "stick_radius": 0.13, "button_size": 0.13, "opacity": 0.62,
      "look_deg_per_sec": 120.0}),
], "touch_twin_stick")

# ---------------------------------------------------------------- controls_keyboard
style_script("controls_keyboard", "keyboard_controls_style", "KeyboardControlsStyle",
    "v7b.1 keyboard fallback: WASD / arrows move relative to the camera, Z/C (, .)\nand PageUp/PageDown orbit, A/D steer cars, Space handbrake. The 'turn' variant\nmakes A/D and the left/right arrows turn the camera + character instead of\nstrafing (tank style). Consumers: ControlInput.", [
    ("ad_turns", "bool", "false", "A/D + left/right arrows turn instead of strafing (on foot)"),
    ("turn_deg_per_sec", "float", "120.0", "turn speed for ad_turns"),
])
emit("controls_keyboard", "KeyboardControlsStyle", "keyboard_controls_style", [
    ("keyboard_legacy", "Classic keyboard", "WASD / arrows camera-relative, A/D strafe, Z/C orbit, A/D steer cars.",
     {"name_fa": "صفحه‌کلید کلاسیک"}),
    ("keyboard_turn", "Keyboard turning", "A/D and the left/right arrows turn the camera and the farmer (tank style).",
     {"name_fa": "چرخش با صفحه‌کلید", "ad_turns": True}),
], "keyboard_legacy")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v7b1 control modules written")

# ---------------------------------------------------------------- ui_text (v7b.1 settings row)
PHRASES = {
    "Controls:": "کنترل‌ها:",
    "Mouse look": "حساسیت ماوس",
    "Invert Y: On": "معکوس عمودی: روشن",
    "Invert Y: Off": "معکوس عمودی: خاموش",
    "Touch controls: Auto": "کنترل لمسی: خودکار",
    "Touch controls: On": "کنترل لمسی: روشن",
    "Touch controls: Off": "کنترل لمسی: خاموش",
    "Mouse steers cars: On": "فرمان ماشین با ماوس: روشن",
    "Mouse steers cars: Off": "فرمان ماشین با ماوس: خاموش",
    "Show the touch joysticks and buttons (Auto = on touch screens)": "نمایش دسته‌ها و دکمه‌های لمسی (خودکار = روی صفحه‌ی لمسی)",
    "Mouse & Touch": "ماوس و لمس",
    "Cockpit / chase camera (while driving)": "دوربین داخل / پشت ماشین (هنگام رانندگی)",
    "Driver license / traffic fines": "گواهینامه / جریمه‌های رانندگی",
}
for fn in ("farsi.tres", "farsi_short.tres"):
    path = os.path.join(ROOT, "modules", "ui_text", fn)
    s = open(path, encoding="utf-8").read()
    m = re.search(r"^phrases = (\{.*\})$", s, re.M)
    cur = json.loads(m.group(1))
    for k, v in PHRASES.items():
        cur.setdefault(k, v)  # never override an existing translation
    cur["Controls"] = cur.get("Controls", "کلیدها")
    line = "phrases = " + json.dumps(cur, ensure_ascii=False, separators=(", ", ": "))
    s = s[:m.start()] + line + s[m.end():]
    open(path, "w", encoding="utf-8").write(s)
print("ui_text: +%d v7b1 phrases" % len(PHRASES))
