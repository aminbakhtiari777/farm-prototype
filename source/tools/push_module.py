#!/usr/bin/env python3
"""Publish ONE module to the game server's content folder (live update, no rebuild).

  python3 tools/push_module.py wages                       # push the project's wages module(s)
  python3 tools/push_module.py wages --file my_wages.tres --variant fair_wages
  python3 tools/push_module.py wages --active modest_wages # switch the active variant
  python3 tools/push_module.py wages --revert              # publish the built-in version again (as a new version)
  options: --content DIR (default server/content), --with-web (also web export + Chrome in the gate)

Steps (refuses on any failure, nothing is published):
  1. check: the file passes the client sanitizer, loads as an AssetModule of TYPE and validates
  2. test gate on this module: the smoke section(s) that cover TYPE, run with the new file swapped in
  3. full suite: compile check + the FULL smoke test with the new file swapped in
  4. publish: copy into <content>/modules/TYPE/, bump TYPE's version in <content>/manifest.json
The running server notices the new manifest within ~1 s and connected clients
download only this module and swap it in through the AssetRegistry.

Test-only flags (used by tools/net_test.py, never for real pushes):
  --skip-gate   skip steps 2-3 (step 1 still runs)
  --unchecked   skip step 1 too (to prove clients reject a broken module)
"""
from __future__ import annotations
import argparse, hashlib, json, os, re, shutil, subprocess, sys, time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT", shutil.which("godot") or os.path.expanduser("~/godot/godot"))
DEFAULT_CONTENT = ROOT / "server" / "content"


def log(m): print(m, flush=True)


def sha(p: Path) -> str:
    return hashlib.sha256(p.read_bytes()).hexdigest()


def smoke_sections_for(type_: str) -> list[str]:
    """Smoke-test function names that cover a module type (via test_gate.SECTIONS)."""
    sys.path.insert(0, str(ROOT / "tools"))
    import test_gate  # noqa
    titles = test_gate.SECTIONS.get(type_, "asset modules (registry + runtime swap)")
    src = (ROOT / "scripts/tools/dev_tools.gd").read_text(encoding="utf-8")
    funcs = []
    for m in re.finditer(r"^func (_smoke_\w+)\(\) -> bool:\n\tawait _section\(\"([^\"]+)\"\)", src, re.M):
        name, title = m.group(1), m.group(2)
        for part in titles.split(" + "):
            if part.strip() and title.startswith(part.strip()):
                funcs.append(name)
    return sorted(set(funcs)) or ["_smoke_modules"]


def run_godot(args, timeout=900):
    log("$ godot " + " ".join(args))
    return subprocess.run([GODOT, "--headless", "--path", str(ROOT)] + args, capture_output=True, text=True, timeout=timeout)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("type")
    ap.add_argument("--file")
    ap.add_argument("--variant")
    ap.add_argument("--active")
    ap.add_argument("--revert", action="store_true")
    ap.add_argument("--content", default=str(DEFAULT_CONTENT))
    ap.add_argument("--with-web", action="store_true")
    ap.add_argument("--skip-gate", action="store_true")
    ap.add_argument("--unchecked", action="store_true")
    ap.add_argument("--reason", default="")
    a = ap.parse_args()

    cfg = json.loads((ROOT / "data/asset_modules.json").read_text(encoding="utf-8"))
    builtin = json.loads((ROOT / "data/module_manifest.json").read_text(encoding="utf-8"))
    t = a.type
    if t not in cfg:
        log("PUSH REFUSED: unknown module type %r" % t)
        return 1
    if t in ("live_updates",):
        log("PUSH REFUSED: %s cannot be updated live (blocked type)" % t)
        return 1
    variants = cfg[t]["variants"]
    # Which files go out.
    sources: dict[str, Path] = {}
    if a.file:
        vid = a.variant or Path(a.file).stem
        sources[vid] = Path(a.file).resolve()
    elif not a.active or a.revert:
        for vid, res in variants.items():
            sources[vid] = ROOT / res.replace("res://", "")
    for vid, p in sources.items():
        if not p.exists():
            log("PUSH REFUSED: missing file %s" % p)
            return 1

    # 1. check
    if not a.unchecked:
        for vid, p in sources.items():
            r = subprocess.run([GODOT, "--headless", "--path", str(ROOT), "-s", "res://tools/check_module.gd", "--", t, str(p)],
                               capture_output=True, text=True, timeout=120)
            line = next((l for l in r.stdout.splitlines() if l.startswith("CHECK MODULE")), r.stdout[-300:])
            log("  " + line)
            if r.returncode != 0:
                log("PUSH REFUSED: %s/%s failed the module check" % (t, vid))
                return 1
    else:
        log("WARNING: --unchecked (test only): skipping the module check")

    # 2 + 3. gate with the new files swapped in
    overrides = ["--module-override=%s:%s:%s" % (t, vid, p) for vid, p in sources.items() if a.file]
    if not a.skip_gate:
        secs = smoke_sections_for(t)
        log("gate 1/2: smoke section(s) for %s: %s" % (t, ", ".join(secs)))
        r = run_godot(["--", "--smoke-test", "--smoke-only=" + ",".join(s.replace("_smoke_", "") for s in secs)] + overrides)
        summary = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("SMOKE TEST") or "[FAIL]" in l]
        for l in summary[-6:]:
            log("  " + l)
        if r.returncode != 0 or not any("SMOKE TEST PASSED" in l for l in summary):
            log("PUSH REFUSED: smoke section(s) failed")
            return 1
        log("gate 2/2: full suite (compile + full smoke%s)" % (" + web + Chrome" if a.with_web else ""))
        r = run_godot(["-s", "res://tools/compile_check.gd"], timeout=300)
        if r.returncode != 0 or "0 failed" not in r.stdout:
            log("PUSH REFUSED: compile check failed")
            return 1
        r = run_godot(["--", "--smoke-test"] + overrides, timeout=1500)
        summary = [l for l in (r.stdout + r.stderr).splitlines() if l.startswith("SMOKE TEST") or "[FAIL]" in l]
        for l in summary[-6:]:
            log("  " + l)
        if r.returncode != 0 or not any("SMOKE TEST PASSED" in l for l in summary):
            log("PUSH REFUSED: full smoke test failed")
            return 1
        if a.with_web:
            r = subprocess.run([sys.executable, "tools/test_gate.py", "--skip-smoke", "--skip-net"], cwd=ROOT)
            if r.returncode != 0:
                log("PUSH REFUSED: web gate failed")
                return 1
    else:
        log("WARNING: --skip-gate (test only): smoke + full suite NOT run")

    # 4. publish
    content = Path(a.content)
    (content / "modules" / t).mkdir(parents=True, exist_ok=True)
    man_path = content / "manifest.json"
    man = json.loads(man_path.read_text(encoding="utf-8")) if man_path.exists() else {"format": 1, "modules": {}}
    base = man["modules"].get(t) or builtin["modules"][t]
    version = max(int(base.get("version", 1)), int(builtin["modules"][t]["version"])) + 1
    files = {}
    for vid, info in builtin["modules"][t]["files"].items():
        files[vid] = dict(info)
    if not a.revert:
        for vid, info in (man["modules"].get(t, {}) or {}).get("files", {}).items():
            files[vid] = dict(info)
    for vid, p in sources.items():
        dest = content / "modules" / t / ("%s.v%d.tres" % (vid, version))
        shutil.copy2(p, dest)
        files[vid] = {"path": variants.get(vid, ""), "file": "modules/%s/%s" % (t, dest.name), "sha256": sha(dest), "bytes": dest.stat().st_size}
    active = a.active or (base.get("active") if not a.revert else builtin["modules"][t]["active"]) or cfg[t]["active"]
    if active not in files:
        log("PUSH REFUSED: active variant %r has no file" % active)
        return 1
    man["modules"][t] = {"version": version, "active": active, "collection": bool(cfg[t].get("collection", False)), "files": files}
    man["updated"] = time.strftime("%Y-%m-%d %H:%M:%S")
    tmp = man_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(man, indent=1, ensure_ascii=False), encoding="utf-8")
    os.replace(tmp, man_path)
    with open(content / "push_log.jsonl", "a", encoding="utf-8") as f:
        f.write(json.dumps({"when": man["updated"], "type": t, "version": version, "active": active,
                            "files": sorted(sources), "gate": not a.skip_gate, "reason": a.reason}, ensure_ascii=False) + "\n")
    log("PUSHED %s v%d (active %s, files %s) -> %s" % (t, version, active, ", ".join(sorted(sources)) or "-", man_path))
    return 0


if __name__ == "__main__":
    sys.exit(main())
