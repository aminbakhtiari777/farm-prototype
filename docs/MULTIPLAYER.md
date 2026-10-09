# Online multiplayer — Farm Town

Offline single-player is the default. Online is **opt-in** (title → Online, or
`U` in-game). The published web build never opens a WebSocket unless the player
opts in (Chrome gate requires 0 websockets / 0 foreign requests).

## What Amin must fill in

| Where | What |
| --- | --- |
| `config/server.cfg` `[server] host` | replace `YOUR_SERVER_HOST` with the free host / VPS hostname or IP |
| `port` | WebSocket game port (default **9080**; put nginx/TLS on 443 in front if public) |
| `tls` | `true` once you have HTTPS/`wss://` |
| `health_port` | HTTP `/health` (default **9081**) for keepalives |
| Env overrides | `FARM_SERVER_HOST`, `FARM_SERVER_PORT`, `FARM_SERVER_TLS`, `FARM_SERVER_HEALTH_PORT` |
| In-game Settings / lobby | players may type `ws://IP:9080` or `wss://game.example.ir` (wins over config) |
| `user://server.cfg` | optional per-device override of the same keys |
| `config/server.cfg` `[brand] linkedin_url` | Amin's LinkedIn profile URL — the LinkedIn QR on the menu stays hidden until this is set |
| Render/Railway/Fly (single public port) | `host=<app>.onrender.com`, `port=443`, `tls=true` (the host injects `$PORT`; `tools/start_server.sh` uses it) |

Step-by-step server start (one-line script, Docker, systemd, nginx, keep-alive):
**`docs/SERVER_SETUP.md` → "v7b.1 additions"**.

Until `host` is a real address, the lobby shows a Persian/English hint and
**never auto-connects**.

## Join flow (friends, ~4 players)

1. Amin starts the headless server once on the free host (`./tools/start_server.sh`,
   Docker or systemd — see `docs/SERVER_SETUP.md`) and fills `host`/`port` in `config/server.cfg`.
2. Host player: **Play → Online → Host** → a **6-character room code** (e.g. `K7QM2X`) appears.
   Send it to friends (WhatsApp/Telegram).
3. Friends: **Play → Online** → type the code → **Join**, or pick the room in the **Server list**.
   Wrong code → "room code not found"; full room → "room full" (they stay connected and can try another).
4. Direct LAN/test: type `ws://127.0.0.1:9080` (or the LAN IP) under Direct connect.
5. Cap: **4–8 players per room** (`max_per_room`, default 6). Total process cap
   `max_players_total` (default 24).

Transport: **WebSocket** (works for web + native). Optional ENet for native-only
can be added later behind a module switch; not required for the free-host path.

Heartbeat: client ping every ~20 s (plus movement at the tick rate); the server drops peers
silent for 60 s (frees the room slot) and the dropped client reconnects automatically.
`/health` returns JSON `{ok, players, rooms, version}` for load balancers and
`tools/keepalive.sh`.

## Local network test (home Wi-Fi, no VPS needed)

For testing with phones/laptops **on the same Wi-Fi** as Amin's Windows PC
(`192.168.1.57`). Friends over the internet can't reach a `192.168.x.x` address.
Config: `config/server.cfg` → `[local_network]` (host `192.168.1.57`, port **9080**,
health **9081**, `tls=false`). The main `[server] host` stays `YOUR_SERVER_HOST`, and the
web build stays offline until a player picks a server.

**On the PC (server)**
1. Unzip the Windows build (`FarmTown-windows-v7b1.zip`). `start_server_windows.bat` sits next
   to `FarmTown.exe`. (In the project it is `tools/start_server_windows.bat`. It also finds
   `..\builds\windows\FarmTown.exe`, or a Godot 4.7.2 editor exe + `project.godot`.)
2. **Double-click `start_server_windows.bat`.** A black window opens, showing the PC's Wi-Fi
   address. Leave it open; closing it stops the server.
3. The first time, **Windows Firewall** asks about FarmTown/Godot: tick **Private networks**
   and press **Allow access**. (If the Wi-Fi is set to *Public*, set it to *Private* under
   Settings → Network & Internet → Wi-Fi → your network → Private.)
4. Check: on the phone's browser, open `http://192.168.1.57:9081/health`. It should show
   `{"ok":true,...}`. If it doesn't load, the firewall is blocking it, or the phone is on a
   different Wi-Fi or guest network.

**On each phone / laptop (same Wi-Fi)**
Play → Online → **Server: شبکهٔ خانگی / Local network (192.168.1.57:9080)** →
**Host** (creates a 6-character code) on the first device, then type the code → **Join** on
the others. The live player counter uses `http://192.168.1.57:9081/health` while Local network
is selected. The choice is saved per device in `user://server.cfg` `[client] profile`.
If the PC's address changes (router restart), type `ws://NEW-IP:9080` under Direct connect.

**Which app to use (important, web limits)**
| Client | Works with the LAN server? |
| --- | --- |
| Windows build (`FarmTown.exe`) on another PC/laptop | ✅ yes |
| Android build (`FarmTown-android-debug-v7b1.apk`) | ✅ yes |
| Pages site (https) in **Chrome** desktop/Android | ⚠️ only if Chrome asks "access devices on your local network?" and you press **Allow**. Tested with Chrome 154: without permission, blocked; with it, `ws://` opens and `/health` returns 200. Chrome still logs a "Mixed Content… deprecated" warning, so this may stop working in a future Chrome |
| Pages site in Firefox / Safari / iPhone browsers | ❌ blocked (https page → insecure `ws://` = mixed content) |
| Web build served over plain `http://192.168.1.57:PORT` | ❌ Godot's web loader refuses to start without a *Secure Context* (https or localhost) |
| iPhone app | needs a Mac + Xcode to build (not available) |

The server is the same dedicated server as `tools/start_server.sh`
(`res://scenes/server/Server.tscn -- --server --port=9080 --health-port=9081`). In an
exported build, `Boot.tscn` also hands off to the server scene when `--server` is passed.

## Free hosts (lightweight)

Amin has a **free internet server** for ~4 players — keep the process light
(no 3D world on the server; ~150–300 MB RAM).

| Host | Notes |
| --- | --- |
| **Iranian VPS (ArvanCloud / ParsPack)** | Recommended for players in Iran; see `SERVER_SETUP.md` |
| Render / Railway / Fly.io | Free tiers **sleep**; run `tools/keepalive.sh` or enable the disabled GitHub Action `.github/workflows/keepalive.yml.disabled` (rename + set `secrets.FARM_HEALTH_URL`) |
| Oracle Cloud Free | Always-on ARM/x86 VM; use the systemd unit |

Docker:

```bash
docker build -t farm-town-server -f server/Dockerfile .
docker run --rm -p 9080:9080 -p 9081:9081 \
  -e FARM_SERVER_HOST=YOUR_SERVER_HOST -v farm-data:/opt/farm/data farm-town-server
```

## Version rules

Clients send `GameBrand.version()` on hello. Server allows exact match or
`compat_prefix` (default `7.1.`). Mismatch → reject + offline play. See
`docs/UPDATES.md`.

## Tests

```bash
python3 tools/net_test.py
# covers: connect, movement, chat, modules, away/reconnect, offline sync,
#         create room + join by code, 3rd client, server list, ping/pong, /health count,
#         room full (max_per_room), unknown code, heartbeat timeout + reconnect, version mismatch
```

Real internet play waits on Amin's host address + (for `wss://`) TLS/domain.

## Entry flow (Amin-approved design, v7b.1)

```
Splash (logo rises w/ spring, pulses x2, fades, ~3 s — any key/click/tap skips)
  -> Menu (slides in from the right, buttons appear one by one, 100 ms stagger)
       [ ▶ Play   ● 3 players online ]   (green blinking dot = live /health; grey "—" = offline / placeholder)
       [ Settings ] [ About ] [ Exit ]   (Exit hidden on web and iOS)
       QR: GitHub (clickable)  ·  LinkedIn (hidden until linkedin_url is filled in config/server.cfg)
  -> Play: [ Single-player ] [ Online ]
       Online -> Lobby: Host (6-char code) | Join by code | Server list | Direct IP:port
  -> Loading screen (progress bar + rotating Persian tips) -> game
```

* Persian is the default; the "English / فارسی" button (top corner) switches everything live.
* Keyboard: Enter = default button (Play, then Single-player), Esc = back.
* Web: the menu is shown, but nothing contacts any server unless the player turns online on
  or a real host is configured. `?skipmenu=1` (or `?demo=`) jumps straight into single-player.
* Tests/tools (`--smoke-test`, `--net-test`, `--server-url=`, `--skip-title`, ...) skip the menu.
* Native exports use a small Boot scene (feature tag `farm_boot`): the menu appears instantly
  while `Main.tscn` loads on a background thread, and the loading bar shows the real progress.
  In the editor and on the web the loading bar follows the perf world-streamer (group
  `world_streamer`, `load_progress()`), otherwise a short warm-up.

### Live player counter
`GET http(s)://HOST:HEALTH_PORT/health` (also `/stats`) every 12 s ->
`{"ok":true,"players":N,"rooms":M,"version":"7.1.0"}`. Not polled while the host is
`YOUR_SERVER_HOST`, and not polled on the web unless online is enabled.

### Settings screen
Language · Quality (Low/Medium/High -> Settings `quality`, applied by the perf layer) ·
Master / Music / Adhan / Bells volume · Mouse sensitivity · Invert Y · Touch controls
(auto/on/off) · Server host / port / TLS -> saved to `user://server.cfg` (overrides
`res://config/server.cfg`; the `FARM_SERVER_*` env vars override both).

### QR codes
Generated at runtime by `scripts/v7b1_platform/qr_encoder.gd` (own encoder: byte mode,
ECC M, versions 1-10; the smoke test checks it bit-for-bit against the Python `qrcode`
library, stored in `data/qr_reference.json`). To show LinkedIn: set
`linkedin_url="https://www.linkedin.com/in/…"` in `config/server.cfg` `[brand]`.
