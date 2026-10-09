#!/usr/bin/env python3
"""Builds data/module_manifest.json: one version number per module type plus
the sha256 of every variant file. Existing version numbers are kept; a type
whose files changed since the last manifest is bumped (+1).

  python3 tools/build_manifest.py            # update data/module_manifest.json
  python3 tools/build_manifest.py --check    # exit 1 if the manifest is stale
"""
import hashlib, json, os, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.join(ROOT, "data", "asset_modules.json")
OUT = os.path.join(ROOT, "data", "module_manifest.json")


def sha(path):
    return hashlib.sha256(open(path, "rb").read()).hexdigest()


def build(prev):
    cfg = json.load(open(CFG, encoding="utf-8"))
    mods = {}
    for t, entry in cfg.items():
        files = {}
        for vid, res in entry.get("variants", {}).items():
            p = os.path.join(ROOT, res.replace("res://", ""))
            files[vid] = {"path": res, "sha256": sha(p), "bytes": os.path.getsize(p)}
        old = prev.get("modules", {}).get(t, {})
        ver = int(old.get("version", 1))
        if old and old.get("files") != files:
            ver += 1
        mods[t] = {"version": ver, "active": entry.get("active", ""), "collection": bool(entry.get("collection", False)), "files": files}
    return {"format": 1, "game": "farm-prototype", "build": "v7b1", "modules": mods}


prev = json.load(open(OUT, encoding="utf-8")) if os.path.exists(OUT) else {}
man = build(prev)
if "--check" in sys.argv:
    ok = prev.get("modules") == man["modules"]
    print("manifest up to date" if ok else "manifest STALE: run tools/build_manifest.py")
    sys.exit(0 if ok else 1)
json.dump(man, open(OUT, "w", encoding="utf-8"), indent=1, ensure_ascii=False, sort_keys=True)
print("wrote %s (%d module types)" % (OUT, len(man["modules"])))
