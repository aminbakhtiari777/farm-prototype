#!/usr/bin/env python3
"""Generates the v5d module .tres files and registers them in
data/asset_modules.json:
  netcode, chat, live_updates, save_sync, away_avatar, accounts, npc_roles
Re-run after editing the tables below, then tools/build_manifest.py."""
import json, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, "tools", "gen_modules_v5a.py"), encoding="utf-8").read()
ns = {"__file__": os.path.join(ROOT, "tools", "gen_modules_v5a.py")}
exec(src.split("config_path =")[0], ns)
write_tres, psa, _val = ns["write_tres"], ns["psa"], ns["val"]


def val(v):
    if isinstance(v, str) and v.startswith("V3("):
        return "Vector3" + v[2:]
    if isinstance(v, dict) and not v.get("__psa") and not v.get("__pia"):
        return "{" + ", ".join("%s: %s" % (json.dumps(k, ensure_ascii=False), val(x)) for k, x in v.items()) + "}"
    if isinstance(v, list):
        return "[" + ", ".join(val(x) for x in v) + "]"
    return _val(v)


ns["val"] = val
config_path = os.path.join(ROOT, "data/asset_modules.json")
config = json.load(open(config_path, encoding="utf-8"))


def emit(type_, cls, script_name, variants, active):
    script = "res://modules/%s/%s.gd" % (type_, script_name)
    reg = {}
    for vid, name, desc, fields in variants:
        path = "res://modules/%s/%s.tres" % (type_, vid)
        f = {"id": vid, "type": type_, "display_name": name, "description": desc}
        f.update(fields)
        write_tres(path, cls, script, f)
        reg[vid] = path
    config[type_] = {"active": active, "variants": reg}


emit("netcode", "NetcodeStyle", "netcode_style", [
    ("standard", "Standard (15 Hz)", "WebSocket, 15 snapshots/s, 120 ms interpolation, server-checked movement.", {"tick_hz": 15.0}),
    ("low_bandwidth", "Low bandwidth (8 Hz)", "Mobile data friendly: 8 snapshots/s and a longer interpolation delay.",
     {"tick_hz": 8.0, "interp_delay": 0.22}),
], "standard")
emit("chat", "ChatStyle", "chat_style", [
    ("friendly", "Friendly chat", "200 characters, 5 messages per 10 s, bubbles over heads.", {}),
    ("family", "Family chat", "Shorter messages, slower rate and a small word filter.",
     {"max_length": 120, "rate_count": 3, "blocked_words": psa("idiot", "stupid", "احمق")}),
], "friendly")
emit("live_updates", "LiveUpdatesStyle", "live_updates_style", [
    ("auto", "Automatic updates", "Download changed modules on connect and when the server publishes one; keep the previous version for rollback.", {}),
    ("manual_off", "Updates off", "Never download module updates (built-in modules only).", {"enabled": False}),
], "auto")
emit("save_sync", "SaveSyncStyle", "save_sync_style", [
    ("every_5s", "Sync every 5 s", "Upload the save every 5 seconds while online; newest group wins, the server wins for world state.", {}),
    ("every_30s", "Sync every 30 s", "Lighter: upload every 30 seconds.", {"upload_seconds": 30.0}),
], "every_5s")
emit("away_avatar", "AwayAvatarStyle", "away_avatar_style", [
    ("cafe_or_home", "Cafe by day, home at night", "A disconnected player's avatar walks to the cafe (08-20) or home and sits; townspeople greet it and bring tea.", {}),
    ("always_home", "Always home", "The avatar always walks home and sits on the porch.", {"cafe_from": 0.0, "cafe_to": 0.0}),
], "cafe_or_home")
emit("accounts", "AccountsStyle", "accounts_style", [
    ("guest", "Guest IDs", "Local guest ID + token (no passwords yet). Saves are keyed by guest ID.", {}),
    ("guest_small", "Guest IDs (small world)", "Same as Guest IDs but capped at 8 players.", {"max_players": 8}),
], "guest")
emit("npc_roles", "NpcRoleStyle", "npc_role_style", [
    ("stub", "NPC takeover (groundwork)", "The server tracks which townsperson a player controls; clients hand that bot to a network controller.", {}),
    ("disabled", "NPC takeover off", "Players cannot take over townspeople.", {"enabled": False}),
], "stub")

json.dump(config, open(config_path, "w", encoding="utf-8"), indent=1, ensure_ascii=False)
open(config_path, "a").write("\n")
print("v5d modules written: netcode, chat, live_updates, save_sync, away_avatar, accounts, npc_roles")
