# Building Farm Town (مزرعهٔ شهر) for every platform

Godot **4.7.2**. Project folder: this repo. Export presets live in `export_presets.cfg`
(Windows, Linux, macOS, Android, iOS). The **web** preset is still produced by
`tools/make_webbuild.py` (Compatibility renderer) and published to GitHub Pages —
**never** put Windows/Mac/Android/iOS binaries in the Pages repo.

App name / title (configurable in `config/server.cfg` `[brand]`):

| Key | Default |
| --- | --- |
| `title_fa` | مزرعهٔ شهر |
| `title_en` | Farm Town |
| `app_name` | FarmTown |

Product family: **Zamith / Zamis**.

## Prerequisites

| Platform | On this Linux box | On Amin's machine |
| --- | --- | --- |
| Windows `.exe` | Godot 4.7.2 + export templates (installed) | same |
| Linux `.x86_64` | same | same |
| macOS `.app` / `.zip` | export produces a zip; **notarization needs a Mac + Apple ID** | Mac + Xcode + Developer account |
| Android APK/AAB | JDK 21 + Android SDK (command-line tools) | Android Studio optional |
| iOS | **cannot build on Linux** — export writes an Xcode project only | Mac + Xcode + Apple Team ID |
| Web | already gated by `tools/test_gate.py` | — |

Export templates path: `~/.local/share/godot/export_templates/4.7.2.stable/`
(official `Godot_v4.7.2-stable_export_templates.tpz` from the Godot GitHub release).

## Commands (from the project root)

```bash
GODOT=~/godot/godot
mkdir -p builds/windows builds/linux builds/macos builds/android builds/ios

# Import once after pulling
$GODOT --headless --path . --import

# Windows (separate .pck next to the .exe — good for a shared base + later update packs)
$GODOT --headless --path . --export-release "Windows Desktop" builds/windows/FarmTown.exe

# Linux
$GODOT --headless --path . --export-release "Linux" builds/linux/FarmTown.x86_64

# macOS (universal zip; notarize on a Mac afterwards)
$GODOT --headless --path . --export-release "macOS" builds/macos/FarmTown.zip

# Android debug APK (Godot creates a debug keystore on first export if empty)
export ANDROID_HOME=$HOME/android-sdk
$GODOT --headless --path . --export-debug "Android" builds/android/FarmTown-debug.apk

# Android release (NEVER commit the keystore). Example:
#   export FARM_ANDROID_KEYSTORE=/secure/farmtown.keystore
#   export FARM_ANDROID_KEY_USER=farmtown
#   export FARM_ANDROID_KEY_PASS='…'   # use a secrets manager
# Fill keystore/release* in the editor (or a local override of export_presets.cfg) then:
$GODOT --headless --path . --export-release "Android" builds/android/FarmTown.apk

# iOS — only useful as an Xcode project dump; finish on a Mac:
$GODOT --headless --path . --export-release "iOS" builds/ios/FarmTown.xcodeproj
# Then on Mac: open in Xcode, set YOUR_APPLE_TEAM_ID, archive & upload.

# Web (unchanged gate path)
python3 tools/make_webbuild.py
$GODOT --headless --path /workspace/farm-prototype-v7b1-webbuild --export-release "Web" \
  /workspace/farm-prototype-v7b1-web/index.html
```

Successful native builds are also zipped under `/workspace/farm-builds/` for Amin
(Windows zip, Linux tarball, Android apk when built). `builds/` is gitignored.

## One command (recommended): `tools/make_native_build.py`

```bash
python3 tools/make_native_build.py windows linux      # release; add --debug for debug builds
python3 tools/make_native_build.py android            # debug APK (needs ~/android-sdk + JDK 21)
```

It exports from a **copy** (`/workspace/farm-prototype-v7b1-nativebuild`, own `.godot`,
ETC2/ASTC enabled for mobile) so other work in the project is never disturbed, writes
`builds/<platform>/` (gitignored) and zips to `/workspace/farm-builds/`:

| Platform | Status (v7b.1, 2026-10-08) | Output |
| --- | --- | --- |
| Windows x86_64 | **built** | `FarmTown-windows-v7b1.zip` (~52 MB): `FarmTown.exe`, `FarmTown.pck`, `FarmTown.console.exe` (log window), `start_server_windows.bat`, `README_WINDOWS.txt` |
| Linux x86_64 | **built** | `FarmTown-linux-v7b1.zip` (~42 MB) |
| Android | deferred (priority was the Windows Wi-Fi test); preset + SDK at `~/android-sdk` are ready to try | — |
| macOS | deferred; zip export works on Linux but signing/notarization needs a Mac + Apple ID | — |
| iOS | needs a Mac + Xcode + Apple Team ID (`YOUR_APPLE_TEAM_ID`) | — |

**Dedicated server from an exported build:** official export templates refuse a scene path
on the command line, so use `FarmTown.exe --headless -- --server --port=9080 --health-port=9081 --bind=0.0.0.0`
(the Boot scene switches to `Server.tscn` when it sees `--server`). That is what
`start_server_windows.bat` does. With the editor binary `res://scenes/server/Server.tscn -- --server`
still works (`tools/start_server.sh`).

Windows builds are not code-signed: SmartScreen shows "unknown publisher" → More info → Run anyway.

## Icons

| File | Use |
| --- | --- |
| `icon.svg` | Godot project icon |
| `assets/icons/icon.ico` | Windows |
| `assets/icons/icon_1024.png` | macOS (proper `.icns` can be made with `iconutil` on a Mac) |
| `assets/icons/android_*.png` | Android adaptive |
| `assets/icons/ios/icon_*.png` | iOS set |

## Signing placeholders Amin must fill

1. **Android release keystore** — create once, store privately, set the three
   `FARM_ANDROID_*` env vars (or editor fields). Never commit passwords.
2. **Apple Team ID** — replace `YOUR_APPLE_TEAM_ID` in the iOS preset; notarize
   macOS builds on a Mac.
3. **Server host** — see `docs/SERVER_SETUP.md` / `docs/MULTIPLAYER.md`.

## Boot scene / entry flow in exports
`project.godot` has `run/main_scene.farm_boot="res://scenes/boot/Boot.tscn"` and every
native preset sets `custom_features="farm_boot"`, so desktop/mobile builds open the splash
and menu instantly while the world loads on a thread. The web build does not have the tag
and keeps `Main.tscn` as its main scene (the menu is then an overlay inside Main).
