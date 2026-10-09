#!/usr/bin/env python3
"""Build a versioned update pack + manifest for Farm Town.

Coordinates with:
  * data/module_manifest.json (v5d live module updates)
  * the perf worker's split resource packs (if builds/packs/*.pck exist, reuse them)

Players download the base once (the exported .pck / web index.pck). Later updates
are small packs listed in an updates/manifest.json the client can fetch when
Amin hosts it (config/server.cfg [updates] manifest_url). Offline / decline =
keep playing the installed version.

Usage:
  python3 tools/make_update_pack.py --version 7.1.1 --out builds/updates \\
      [--modules wages,cafe] [--include-packs] [--notes "balance tweak"]

Never uploads anything. Copy builds/updates/ to your CDN / VPS yourself.
"""
from __future__ import annotations
import argparse, hashlib, json, os, shutil, sys, time, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--version", required=True, help="new game version, e.g. 7.1.1")
    ap.add_argument("--out", default=str(ROOT / "builds" / "updates"))
    ap.add_argument("--modules", default="", help="comma module types to bundle as .tres zip")
    ap.add_argument("--include-packs", action="store_true",
                    help="attach any builds/packs/*.pck produced by the perf worker")
    ap.add_argument("--min-client", default="7.1.0", help="oldest client this pack supports")
    ap.add_argument("--notes", default="")
    ap.add_argument("--base-url", default="", help="packs_base_url written into the manifest")
    args = ap.parse_args()
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    pack_name = "update_%s.zip" % args.version.replace(".", "_")
    pack_path = out / pack_name
    if pack_path.exists():
        pack_path.unlink()

    with zipfile.ZipFile(pack_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        # Always include module_manifest + game_version so clients can verify.
        for rel in ("data/module_manifest.json", "data/game_version.json", "config/server.cfg"):
            p = ROOT / rel
            if p.exists():
                z.write(p, rel)
        mods = [m.strip() for m in args.modules.split(",") if m.strip()]
        for t in mods:
            d = ROOT / "modules" / t
            if not d.is_dir():
                print("missing module type", t, file=sys.stderr)
                return 2
            for f in sorted(d.rglob("*")):
                if f.is_file() and not f.name.endswith(".uid"):
                    z.write(f, str(f.relative_to(ROOT)))
        if args.include_packs:
            packs = ROOT / "builds" / "packs"
            if packs.is_dir():
                for f in sorted(packs.glob("*.pck")):
                    z.write(f, "packs/" + f.name)
                    print("  + pack", f.name, f.stat().st_size)
            else:
                print("  (no builds/packs yet — perf worker may add them later)")

    entry = {
        "version": args.version,
        "min_client": args.min_client,
        "build": "v7b1",
        "game": "farm-town",
        "notes": args.notes,
        "created_unix": int(time.time()),
        "pack": {
            "file": pack_name,
            "sha256": sha256(pack_path),
            "bytes": pack_path.stat().st_size,
            "url": (args.base_url.rstrip("/") + "/" + pack_name) if args.base_url else pack_name,
        },
        "modules": mods,
        "compat_prefix": "7.1.",
    }
    # Merge into updates/manifest.json (latest first).
    man_path = out / "manifest.json"
    man = {"format": 1, "game": "farm-town", "latest": args.version, "updates": []}
    if man_path.exists():
        try:
            man = json.loads(man_path.read_text(encoding="utf-8"))
        except Exception:
            pass
    updates = [u for u in man.get("updates", []) if u.get("version") != args.version]
    updates.insert(0, entry)
    man["latest"] = args.version
    man["updates"] = updates
    if args.base_url:
        man["packs_base_url"] = args.base_url.rstrip("/")
    man_path.write_text(json.dumps(man, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("wrote", pack_path, "(%d bytes)" % pack_path.stat().st_size)
    print("wrote", man_path, "latest=", args.version)
    print("Point config/server.cfg [updates] manifest_url at this manifest once hosted.")
    return 0


if __name__ == "__main__":
    # Fix typo open mode
    sys.exit(main())
