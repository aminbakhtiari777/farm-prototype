#!/usr/bin/env python3
"""Build native exports from a COPY of the project (keeps the main .godot and
other workers untouched). Mobile needs ETC2/ASTC textures, so the copy enables
import_etc2_astc and uses the Compatibility renderer on mobile.

  python3 tools/make_native_build.py [windows linux macos android ios] [--debug]
Outputs: builds/<platform>/ in THIS project + zips in /workspace/farm-builds/.
Never copies anything to the GitHub Pages repo.
"""
from __future__ import annotations
import os, shutil, subprocess, sys, tarfile, time, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
COPY = Path(os.environ.get("FARM_NATIVE_COPY", "/workspace/farm-prototype-v7b1-nativebuild"))
OUTZ = Path(os.environ.get("FARM_BUILDS_OUT", "/workspace/farm-builds"))
GODOT = os.path.expanduser(os.environ.get("GODOT", "~/godot/godot"))
PRESETS = {
    "windows": ("Windows Desktop", "windows/FarmTown.exe"),
    "linux": ("Linux", "linux/FarmTown.x86_64"),
    "macos": ("macOS", "macos/FarmTown.zip"),
    "android": ("Android", "android/FarmTown-debug.apk"),
    "ios": ("iOS", "ios/FarmTown.xcodeproj"),
}
SKIP = {".godot", "devtmp", "builds", "__pycache__"}
WINDOWS_README = """Farm Town / مزرعهٔ شهر — Windows (v7b.1)

PLAY:   double-click FarmTown.exe  (keep FarmTown.pck in the same folder).
        Windows SmartScreen may say "unknown publisher" (the build is not code-signed):
        click "More info" -> "Run anyway".

HOME WI-FI MULTIPLAYER (one PC is the server):
  1. On the server PC double-click start_server_windows.bat and keep the black window open.
     First time: allow FarmTown in Windows Firewall ("Private networks").
  2. Check from a phone browser: http://192.168.1.57:9081/health  -> {"ok":true,...}
     (if the PC has another address, the window prints it; use ws://THAT-IP:9080 under Direct connect)
  3. Every player: FarmTown.exe -> Play -> Online -> Server: Local network ->
     Host (shows a 6-character room code) or type the code -> Join.

FarmTown.console.exe is the same game with a log window (useful for the server / bug reports).
"""


def sync() -> None:
    COPY.mkdir(parents=True, exist_ok=True)
    for name in os.listdir(COPY):
        if name != ".godot":
            p = COPY / name
            shutil.rmtree(p) if p.is_dir() and not p.is_symlink() else p.unlink()
    for name in os.listdir(ROOT):
        if name in SKIP:
            continue
        s = ROOT / name
        (shutil.copytree(s, COPY / name) if s.is_dir() else shutil.copy2(s, COPY / name))
    proj = (COPY / "project.godot").read_text()
    if "import_etc2_astc" not in proj:
        proj = proj.replace("[rendering]\n", "[rendering]\n\ntextures/vram_compression/import_etc2_astc=true\n"
                            "renderer/rendering_method.mobile=\"gl_compatibility\"\n", 1)
    assert "export/convert_text_resources_to_binary=false" in proj
    (COPY / "project.godot").write_text(proj)


def ensure_debug_keystore(env: dict) -> None:
    """Debug keystore (NOT for release): ~/.local/share/godot/keystores/debug.keystore,
    standard androiddebugkey / android credentials. Release signing only via
    FARM_ANDROID_KEYSTORE / FARM_ANDROID_KEY_USER / FARM_ANDROID_KEY_PASS (never committed)."""
    ks = Path(os.path.expanduser("~/.local/share/godot/keystores/debug.keystore"))
    if not ks.exists():
        ks.parent.mkdir(parents=True, exist_ok=True)
        keytool = os.path.join(env.get("JAVA_HOME", "/usr"), "bin", "keytool")
        subprocess.run([keytool, "-genkeypair", "-v", "-keystore", str(ks), "-storepass", "android",
                        "-alias", "androiddebugkey", "-keypass", "android", "-keyalg", "RSA",
                        "-keysize", "2048", "-validity", "10000", "-dname", "CN=Android Debug,O=Android,C=US"],
                       check=True, capture_output=True)
    env.setdefault("GODOT_ANDROID_KEYSTORE_DEBUG_PATH", str(ks))
    env.setdefault("GODOT_ANDROID_KEYSTORE_DEBUG_USER", "androiddebugkey")
    env.setdefault("GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD", "android")
    if env.get("FARM_ANDROID_KEYSTORE"):
        env.setdefault("GODOT_ANDROID_KEYSTORE_RELEASE_PATH", env["FARM_ANDROID_KEYSTORE"])
        env.setdefault("GODOT_ANDROID_KEYSTORE_RELEASE_USER", env.get("FARM_ANDROID_KEY_USER", ""))
        env.setdefault("GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD", env.get("FARM_ANDROID_KEY_PASS", ""))


def run(cmd, timeout=1800, env=None) -> int:
    print("$", " ".join(cmd), flush=True)
    r = subprocess.run(cmd, cwd=COPY, timeout=timeout, env=env, capture_output=True, text=True)
    tail = (r.stdout + r.stderr)[-2500:]
    print(tail)
    return r.returncode


def zip_dir(src: Path, dest: Path) -> None:
    with zipfile.ZipFile(dest, "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(src.rglob("*")):
            if f.is_file() and ".box-store-snap-" not in f.name:
                z.write(f, f.relative_to(src.parent))


def main() -> int:
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    debug = "--debug" in sys.argv
    plats = args or ["windows", "linux"]
    sync()
    if run([GODOT, "--headless", "--path", str(COPY), "--import"], timeout=1800) != 0:
        print("import failed"); return 1
    OUTZ.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ)
    env.setdefault("ANDROID_HOME", os.path.expanduser("~/android-sdk"))
    env.setdefault("ANDROID_SDK_ROOT", env["ANDROID_HOME"])
    if not env.get("JAVA_HOME"):
        for j in ("/usr/lib/jvm/java-21-openjdk-amd64", "/usr/lib/jvm/java-17-openjdk-amd64"):
            if os.path.isdir(j):
                env["JAVA_HOME"] = j
                break
    if "android" in plats:
        ensure_debug_keystore(env)
    results = {}
    for p in plats:
        preset, rel = PRESETS[p]
        out = ROOT / "builds" / rel
        out.parent.mkdir(parents=True, exist_ok=True)
        mode = "--export-debug" if (debug or (p == "android" and not env.get("FARM_ANDROID_KEYSTORE"))) else "--export-release"
        t0 = time.time()
        rc = run([GODOT, "--headless", "--path", str(COPY), mode, preset, str(out)], env=env)
        ok = out.exists() and (out.is_dir() or out.stat().st_size > 100_000)
        results[p] = (ok, rc, round(time.time() - t0))
        if not ok:
            continue
        if p == "windows":
            # LOCALNET: double-click home Wi-Fi server launcher next to FarmTown.exe.
            shutil.copy2(ROOT / "tools" / "start_server_windows.bat", out.parent / "start_server_windows.bat")
        if p == "windows":
            # Home Wi-Fi test kit: double-click server launcher + short how-to next to the .exe.
            bat = ROOT / "tools" / "start_server_windows.bat"
            if bat.exists():
                # cmd.exe needs CRLF for reliable goto/labels.
                txt = bat.read_text(encoding="utf-8").replace("\r\n", "\n").replace("\n", "\r\n")
                (out.parent / bat.name).write_bytes(txt.encode("utf-8"))
            (out.parent / "README_WINDOWS.txt").write_bytes(WINDOWS_README.replace("\n", "\r\n").encode("utf-8"))
        if p in ("windows", "linux"):
            zip_dir(out.parent, OUTZ / ("FarmTown-%s-v7b1.zip" % p))
        elif p == "android":
            shutil.copy2(out, OUTZ / "FarmTown-android-debug-v7b1.apk")
        elif p == "macos":
            shutil.copy2(out, OUTZ / "FarmTown-macos-v7b1.zip")
    for p, (ok, rc, secs) in results.items():
        print("BUILD %-8s %s (rc=%s, %ss)" % (p, "OK" if ok else "FAIL", rc, secs))
    return 0 if all(r[0] for r in results.values()) else 1


if __name__ == "__main__":
    sys.exit(main())
