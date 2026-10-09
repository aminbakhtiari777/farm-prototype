"""Writes the [input] section of project.godot (keyboard + mouse + gamepad).

Run: python3 tools/gen_input_map.py [path/to/project.godot]
Categories/labels for the in-game Controls menu live in scripts/ui/controls_menu.gd.
"""
import re, sys

K = dict(ESC=4194305, SHIFT=4194325, LEFT=4194319, UP=4194320, RIGHT=4194321, DOWN=4194322, PGUP=4194323, PGDN=4194324,
         HOME=4194317, TAB=4194306, F1=4194332, F5=4194336, F9=4194340, KP_ADD=4194437, KP_SUB=4194435)

def key(code, ctrl=False):
    if isinstance(code, str):
        code = K[code] if code in K else ord(code.upper()) if len(code) == 1 else code
    return ('Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
            '"shift_pressed":false,"ctrl_pressed":%s,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":%d,'
            '"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)' % ("true" if ctrl else "false", code))

def mouse(btn):
    return ('Object(InputEventMouseButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,'
            '"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"button_mask":0,"position":Vector2(0, 0),"global_position":Vector2(0, 0),'
            '"factor":1.0,"button_index":%d,"canceled":false,"pressed":false,"double_click":false,"script":null)' % btn)

def joy(btn):
    return 'Object(InputEventJoypadButton,"resource_local_to_scene":false,"resource_name":"","device":-1,"button_index":%d,"pressure":0.0,"pressed":true,"script":null)' % btn

def axis(a, v):
    return 'Object(InputEventJoypadMotion,"resource_local_to_scene":false,"resource_name":"","device":-1,"axis":%d,"axis_value":%s,"script":null)' % (a, "%.1f" % v)

A, B, X, Y, BACK, START, LS, RS, LB, RB, DUP, DDOWN, DLEFT, DRIGHT = 0, 1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14

ACTIONS = [
    # Movement
    ("move_forward", 0.2, [key("W"), key("UP"), axis(1, -1)]),
    ("move_back", 0.2, [key("S"), key("DOWN"), axis(1, 1)]),
    ("move_left", 0.2, [key("A"), key("LEFT"), axis(0, -1)]),
    ("move_right", 0.2, [key("D"), key("RIGHT"), axis(0, 1)]),
    ("sprint", 0.5, [key("SHIFT"), joy(LS), axis(4, 1)]),
    ("jump", 0.5, [key(32), joy(A)]),
    ("sit", 0.5, [key("X"), joy(B)]),
    # Camera
    ("camera_orbit", 0.5, [mouse(2)]),
    ("camera_left", 0.25, [key("Z"), key(44), axis(2, -1)]),
    ("camera_right", 0.25, [key("C"), key(46), axis(2, 1)]),
    ("camera_up", 0.25, [key("PGUP"), axis(3, -1)]),
    ("camera_down", 0.25, [key("PGDN"), axis(3, 1)]),
    ("zoom_in", 0.5, [mouse(4), key(61), key("KP_ADD"), joy(RB)]),
    ("zoom_out", 0.5, [mouse(5), key(45), key("KP_SUB"), joy(LB)]),
    ("camera_reset", 0.5, [key("HOME"), mouse(3), joy(RS)]),
    # Interaction & tools
    ("interact", 0.5, [key("E"), joy(X)]),
    ("pick_up", 0.5, [key("F"), joy(Y)]),
    ("cycle_seed", 0.5, [key("Q"), joy(DRIGHT)]),
    ("toggle_inventory", 0.5, [key("I"), joy(DUP)]),
    # Time & world
    ("time_pause", 0.5, [key("P")]),
    ("time_slower", 0.5, [key(91)]),
    ("time_faster", 0.5, [key(93)]),
    ("toggle_day_night", 0.5, [key("N")]),
    ("next_season", 0.5, [key("K")]),
    # Voice
    ("push_to_talk", 0.5, [key("V"), joy(DDOWN)]),
    ("voice_panel", 0.5, [key("L"), joy(DLEFT)]),
    # System
    ("menu", 0.5, [key("ESC"), joy(START)]),
    ("open_settings", 0.5, [key("O")]),
    ("open_controls", 0.5, [key("F1"), key(47), joy(BACK)]),
    ("quick_save", 0.5, [key("F5")]),
    ("quick_load", 0.5, [key("F9")]),
    ("toggle_sound", 0.5, [key("M")]),
    ("toggle_shadows", 0.5, [key("G")]),
    ("toggle_hints", 0.5, [key("H")]),
    ("toggle_minimap", 0.5, [key("TAB")]),
    ("quit", 0.5, [key("Q", ctrl=True)]),
]

def section():
    out = ["[input]", ""]
    for name, dz, events in ACTIONS:
        out.append("%s={" % name)
        out.append('"deadzone": %s,' % dz)
        out.append('"events": [' + ",\n".join(events) + "]")
        out.append("}")
    return "\n".join(out) + "\n"

if __name__ == "__main__":
    path = sys.argv[1] if len(sys.argv) > 1 else "project.godot"
    s = open(path).read()
    start = s.index("[input]")
    m = re.search(r"^\[(?!input\])[a-z_]+\]", s[start + 7:], re.M)
    end = start + 7 + m.start() if m else len(s)
    s = s[:start] + section() + "\n" + s[end:]
    open(path, "w").write(s)
    print("input map written:", len(ACTIONS), "actions")
