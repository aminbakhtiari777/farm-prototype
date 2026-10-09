#!/usr/bin/env python3
"""Publish the farm prototype to GitHub Pages (/tmp/farm-pages).

Refuses to publish unless tools/test_gate.py has just passed (reads
/workspace/farm-v7b1-gate-state.json and re-runs the gate if --run-gate is set).

Author: aminbakhtiari777 <aminbakhtiari777@users.noreply.github.com>
Normal push only (never force). Keeps .nojekyll and docs/.
"""
from __future__ import annotations
import argparse, hashlib, json, os, shutil, subprocess, sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = Path("/workspace/farm-v7b1-gate-state.json")
PAGES = Path("/tmp/farm-pages")
DEFAULT_WEB = Path("/workspace/farm-prototype-v7b1-web")
AUTHOR_NAME = "aminbakhtiari777"
AUTHOR_EMAIL = "aminbakhtiari777@users.noreply.github.com"


def log(m): print(m, flush=True)


def sha(p: Path) -> str:
    h = hashlib.sha256()
    with open(p, "rb") as f:
        for c in iter(lambda: f.read(1 << 20), b""):
            h.update(c)
    return h.hexdigest()


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--run-gate", action="store_true", help="run tools/test_gate.py first")
    ap.add_argument("--web", default=str(DEFAULT_WEB))
    ap.add_argument("--message", default="Publish farm prototype v7b.1 (GTA-style controls patch)")
    ap.add_argument("--readme", default="", help="path to README.md to drop into the pages repo")
    args = ap.parse_args()

    if args.run_gate:
        r = subprocess.run([sys.executable, "tools/test_gate.py"], cwd=ROOT)
        if r.returncode != 0:
            log("PUBLISH REFUSED: test gate failed")
            return 1
    if not STATE.exists():
        log("PUBLISH REFUSED: no gate state at %s (run tools/test_gate.py first)" % STATE)
        return 1
    state = json.loads(STATE.read_text())
    if not state.get("ok"):
        log("PUBLISH REFUSED: last gate run failed: %s" % state.get("failures"))
        return 1
    web = Path(args.web)
    pck = web / "index.pck"
    if not pck.exists():
        log("PUBLISH REFUSED: missing %s" % pck)
        return 1
    if state.get("web_pck_sha256") and sha(pck) != state["web_pck_sha256"]:
        log("PUBLISH REFUSED: web index.pck does not match the gated build")
        return 1

    # Copy build into pages (keep .nojekyll + docs/).
    keep = {".git", ".nojekyll", "docs"}
    for name in list(PAGES.iterdir()):
        if name.name in keep:
            continue
        if name.is_dir():
            shutil.rmtree(name)
        else:
            name.unlink()
    for src in web.iterdir():
        dst = PAGES / src.name
        if src.is_dir():
            shutil.copytree(src, dst)
        else:
            shutil.copy2(src, dst)
    (PAGES / ".nojekyll").touch()
    # Add (never remove) public design docs linked from the README.
    (PAGES / "docs").mkdir(exist_ok=True)
    for doc in ("SERVER_SETUP.md", "MULTIPLAYER_PLAN.md", "MULTIPLAYER.md", "BUILDING.md", "UPDATES.md"):
        if (ROOT / "docs" / doc).exists():
            shutil.copy2(ROOT / "docs" / doc, PAGES / "docs" / doc)
    if args.readme:
        shutil.copy2(args.readme, PAGES / "README.md")
    elif (ROOT / "docs" / "PAGES_README.md").exists():
        shutil.copy2(ROOT / "docs" / "PAGES_README.md", PAGES / "README.md")

    env = os.environ.copy()
    env["GIT_AUTHOR_NAME"] = AUTHOR_NAME
    env["GIT_AUTHOR_EMAIL"] = AUTHOR_EMAIL
    env["GIT_COMMITTER_NAME"] = AUTHOR_NAME
    env["GIT_COMMITTER_EMAIL"] = AUTHOR_EMAIL
    def g(*a):
        return subprocess.run(["git", *a], cwd=PAGES, env=env, capture_output=True, text=True)

    g("add", "-A")
    st = g("status", "--porcelain")
    if not st.stdout.strip():
        log("nothing to publish (pages already matches)")
        return 0
    r = g("commit", "-m", args.message)
    log(r.stdout); log(r.stderr)
    if r.returncode != 0:
        return 1
    r = g("push", "origin", "HEAD")  # never --force
    log(r.stdout); log(r.stderr)
    if r.returncode != 0:
        log("PUBLISH: push failed")
        return 1
    h = g("rev-parse", "HEAD").stdout.strip()
    log("PUBLISHED %s" % h)
    # Remember what was published (the gate diffs module hashes against it).
    Path("/workspace/farm-published-manifest.json").write_text(json.dumps(
        {"commit": h, "module_hashes": state.get("module_hashes", {}), "web_pck_sha256": sha(pck)}, indent=2))
    log("live index.pck sha256=%s bytes=%d" % (sha(PAGES / "index.pck"), (PAGES / "index.pck").stat().st_size))
    return 0


if __name__ == "__main__":
    sys.exit(main())
