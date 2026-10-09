# Game server setup (v5d)

The farm prototype is **single-player and offline by default**. The published web
game never contacts a server unless the player opens the **Online panel (U)**,
types a server address and presses **Connect**. This guide puts the headless
game server on an Ubuntu VPS (ArvanCloud or ParsPack, see `MULTIPLAYER_PLAN.md`)
behind nginx with TLS, so browsers can connect with `wss://`.

## What you need

| Item | Recommendation |
| --- | --- |
| VPS | Ubuntu 22.04 or 24.04, **2 vCPU / 2–4 GB RAM / 40 GB disk**, public IPv4 (ArvanCloud or ParsPack, Iran region if most players are in Iran) |
| Domain | Any domain you control, e.g. `example.ir`, with an **A record** `game.example.ir → <VPS IP>` |
| Ports | 22 (SSH, key only), 80 (Let's Encrypt), 443 (wss) |
| Software | Godot 4.7.2 Linux binary (headless), nginx, certbot |

One headless server uses about 150–300 MB RAM and very little CPU for 2–30 players.

## 1. Server files

```bash
sudo adduser --system --group --home /opt/farm farm
sudo mkdir -p /opt/farm && cd /opt/farm
# Godot 4.7.2 (same version as the game)
sudo -u farm wget https://github.com/godotengine/godot/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip
sudo -u farm unzip Godot_v4.7.2-stable_linux.x86_64.zip && sudo -u farm mv Godot_v4.7.2-stable_linux.x86_64 godot
# The game project (this folder, without .godot/ and devtmp/)
sudo -u farm unzip /path/to/farm-prototype-v5d.zip -d /opt/farm/game
sudo -u farm mkdir -p /opt/farm/content /opt/farm/data
# First run imports the project (one time, ~1 minute)
sudo -u farm /opt/farm/godot --headless --path /opt/farm/game --import
```

Test it by hand:

```bash
sudo -u farm /opt/farm/godot --headless --path /opt/farm/game res://scenes/server/Server.tscn -- \
  --server --port=8910 --bind=127.0.0.1 --content=/opt/farm/content --data=/opt/farm/data
# -> "SERVER READY port=8910"
```

Arguments: `--port` (default 8910, from the `netcode` module), `--bind` (use
`127.0.0.1` so only nginx can reach it), `--content` (pushed module updates),
`--data` (accounts and player saves, back this folder up).

## 2. systemd service

`/etc/systemd/system/farm-server.service`:

```ini
[Unit]
Description=Farm prototype game server (Godot headless)
After=network-online.target
Wants=network-online.target

[Service]
User=farm
Group=farm
WorkingDirectory=/opt/farm
ExecStart=/opt/farm/godot --headless --path /opt/farm/game res://scenes/server/Server.tscn -- --server --port=8910 --bind=127.0.0.1 --content=/opt/farm/content --data=/opt/farm/data
Restart=always
RestartSec=3
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/opt/farm/content /opt/farm/data /opt/farm/.local
PrivateTmp=true
MemoryMax=1G

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now farm-server
sudo journalctl -u farm-server -f      # logs (joins, chat, module pushes, away avatars)
```

## 3. nginx + TLS (wss)

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
```

`/etc/nginx/sites-available/farm`:

```nginx
map $http_upgrade $connection_upgrade { default upgrade; '' close; }

server {
    listen 80;
    server_name game.example.ir;
    location / { return 301 https://$host$request_uri; }
}

server {
    listen 443 ssl http2;
    server_name game.example.ir;
    # certbot fills in ssl_certificate / ssl_certificate_key
    add_header Strict-Transport-Security "max-age=31536000" always;

    location / {
        proxy_pass http://127.0.0.1:8910;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection $connection_upgrade;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
        client_max_body_size 16m;
    }
}
```

```bash
sudo ln -s /etc/nginx/sites-available/farm /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d game.example.ir     # Let's Encrypt, auto-renews
```

Players then use **`wss://game.example.ir`** in the Online panel.

## 4. Firewall

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp      # better: limit to your own IP, SSH keys only
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
# 8910 stays closed: only nginx (127.0.0.1) talks to the game server.
```

Also turn off SSH password login (`PasswordAuthentication no`), enable
unattended upgrades, and copy `/opt/farm/data` to off-server storage every night.

## 5. Live module updates (no rebuild)

Every module type has a version in `data/module_manifest.json`. To change one
module for everyone (for example the wages table):

```bash
# on your machine, in the project
python3 tools/push_module.py wages --content /path/to/content
# or a new file for one variant:
python3 tools/push_module.py wages --file my_wages.tres --variant fair_wages --content /path/to/content
```

`push_module.py` first checks the file the same way clients do (sanitizer,
loads as the right module type), then runs the smoke section(s) for that module
and the full smoke suite with the new file swapped in. It refuses to publish if
anything fails. Then copy the content folder to the server (`rsync -a content/
farm@game.example.ir:/opt/farm/content/`). The server notices the new manifest
within a second, and connected players download only that module, verify its
sha256 and swap it in. Players who connect later get it on connect; updates are
kept on their device for later sessions. A broken update is rejected on the
client and the previous version stays active. `push_module.py TYPE --revert`
publishes the built-in version again as a newer version (server-side rollback),
and players can roll back the last update from the Online panel.

## 6. Saves, disconnects and the conflict rule

* While online the game uploads the save every 5 s (`save_sync` module) to
  `/opt/farm/data/saves/<guest id>.json`, keeping 3 backups.
* If a player disconnects, their avatar walks to the cafe (08:00–20:00) or home
  and sits down. Townspeople greet it and bring tea. When the player comes back
  they get a "welcome back" message, and townspeople mention the absence.
* If the server is unreachable the game keeps running locally, saves locally
  and retries with back-off (2 s up to 20 s). On reconnect each save group is
  merged: player groups (money, farm, inventory, needs, ...) keep the newest
  copy, and shared world groups (clock, market) take the server's copy.

## 7. Accounts: guest IDs only (real auth is NOT done)

Each browser or device makes a guest ID plus a random 128-bit token (kept in
localStorage on the web). The server stores a SHA-256 hash of the token and
refuses a different token for the same guest ID. This is enough for testing
with friends, but it is **not** real authentication:

* Clearing browser storage loses the guest ID, and there is no recovery.
* There are no passwords, e-mail checks or bans by account yet.
* Anyone who copies the token can play as that guest.

Before a public launch, add real accounts (e-mail magic link or username and
password hashed with argon2 or bcrypt, served by a small HTTPS endpoint on the
same server), session tokens with expiry, and rate limits on joins, as described
in `MULTIPLAYER_PLAN.md` M3.

## 8. Security notes

* Movement is server-checked: steps faster than `max_speed × tolerance` are
  clamped and the client snaps back. Teleports (loading a save, sleeping) are
  accepted at most once every 2 s and logged. Full anti-cheat (money,
  inventory) comes with server-side economy in a later version.
* Chat: 200 characters, 5 messages per 10 s, optional word filter (`chat` module).
* Module files are plain resources only: the client rejects any file with
  embedded scripts, sub-resources or paths outside `res://modules/<type>/`.
* The update system cannot update itself (`live_updates` is blocked).

## 9. Local testing (no VPS)

```bash
# server
godot --headless --path . res://scenes/server/Server.tscn -- --server --port=8910
# two desktop clients (separate user data folders)
XDG_DATA_HOME=/tmp/a godot --path . -- --server-url=ws://127.0.0.1:8910
XDG_DATA_HOME=/tmp/b godot --path . -- --server-url=ws://127.0.0.1:8910
# automated: server + two headless clients
python3 tools/net_test.py
```

In a browser served over plain `http://localhost`, `ws://127.0.0.1:8910` works.
The HTTPS GitHub Pages site needs `wss://`, so it needs the VPS and domain above.


---

## v7b.1 additions — placeholders, free hosts, rooms, keepalive

> Short version for Amin: pick **one** of A/B/C below to start the server, put the
> server's address in `config/server.cfg` (`host=`, `port=`, `tls=`), rebuild/export,
> and friends press **Play → Online → Host / Join by code**.

### 0. What Amin must fill in (everything else already works)

| File / place | Key | Put here | Example |
| --- | --- | --- | --- |
| `config/server.cfg` `[server]` | `host` | the free host's public hostname or IP (replace `YOUR_SERVER_HOST`) | `farm.example.ir` or `185.12.34.56` |
| same | `port` | the public game port players connect to | `9080` (direct VPS) · `443` (behind nginx/TLS or Render/Railway/Fly) |
| same | `tls` | `true` when the address is `https`/`wss` (nginx+certificate, or Render/Railway/Fly), else `false` | `true` |
| same | `health_port` | public port of `/health` for the live player counter | `9081` (VPS) · `443` with the nginx `location /health` below |
| same `[brand]` | `linkedin_url` | Amin's LinkedIn profile URL (the QR stays hidden until filled) | `https://www.linkedin.com/in/…` |
| same `[updates]` | `manifest_url`, `packs_base_url` | optional, only when update packs are hosted (`docs/UPDATES.md`) | `https://farm.example.ir/updates/manifest.json` |
| `server/farm-server.service` | `FARM_SERVER_HOST` | same host (only if using systemd) | |
| `.github/workflows/keepalive.yml.disabled` | secret `FARM_HEALTH_URL` | only for sleeping free tiers | `https://farm-town.onrender.com/` |

Override order for clients (highest wins): address typed in the game (Settings →
Server, or Online → Direct connect) → env `FARM_SERVER_HOST` / `FARM_SERVER_PORT` /
`FARM_SERVER_TLS` / `FARM_SERVER_HEALTH_PORT` → `user://server.cfg` (written by the
in-game Settings) → `res://config/server.cfg` (shipped in the build).
While the host is still `YOUR_SERVER_HOST` nothing connects, the player counter shows
grey "—", and the web build stays fully offline (0 websockets, 0 foreign requests).

Defaults in `config/server.cfg`:

```
[server]
host="YOUR_SERVER_HOST"   # ← Amin fills this
port=9080
tls=false
health_port=9081
max_per_room=6            # 4 friends now; 4–8 is fine on a free host
heartbeat_sec=20.0        # client ping interval
heartbeat_timeout_sec=60.0
game_version="7.1.0"
compat_prefix="7.1."
```

### A. One-line start (any free host or VPS with a shell)

```bash
# after copying the project folder and installing Godot 4.7.2 as `godot` or ~/godot/godot
./tools/start_server.sh
# → "SERVER READY port=9080" and "HEALTH READY port=9081"
# custom: FARM_SERVER_PORT=9080 FARM_SERVER_HEALTH_PORT=9081 FARM_SERVER_BIND=0.0.0.0 ./tools/start_server.sh
```

The script finds Godot (`$GODOT`, `~/godot/godot` or `godot` in PATH), honours `$PORT`
when a host injects one (Render/Railway/Fly), keeps saves in `server/data/` and live
modules in `server/content/`. Server-only flags: `--max-per-room=N`,
`--heartbeat-timeout=SEC`, `--health-port=N`, `--port=N`, `--bind=ADDR`.
Leave it running with `nohup ./tools/start_server.sh > server.log 2>&1 &`, `tmux`, or B/C.

### B. Docker (Render / Railway / Fly.io / any Docker host)

```bash
docker build -t farm-town-server -f server/Dockerfile .
docker run -d --restart=always -p 9080:9080 -p 9081:9081 -v farm-data:/opt/farm/data farm-town-server
```

`.dockerignore` keeps `.godot/`, `builds/`, `devtmp/` out of the image. The image has a
Docker `HEALTHCHECK` on `/health`. On single-port hosts (Render/Railway/Fly) the host's
`$PORT` becomes the game port, TLS is done by the host: set `host=<app>.onrender.com`,
`port=443`, `tls=true`. Their `/health` port is not public there, so the live counter
shows "—" unless you use a VPS (or nginx below).

### C. systemd (always-on VPS: ArvanCloud / ParsPack / Oracle Free)

```bash
sudo useradd -r -m -d /opt/farm farm
sudo cp -r . /opt/farm/game && sudo cp ~/godot/godot /opt/farm/godot && sudo chown -R farm: /opt/farm
sudo cp server/farm-server.service /etc/systemd/system/   # edit FARM_SERVER_HOST / BIND first
sudo systemctl daemon-reload && sudo systemctl enable --now farm-server
journalctl -u farm-server -f      # "SERVER READY"
```

`Restart=always` restarts it after crashes and reboots. `FARM_SERVER_BIND=127.0.0.1`
expects nginx in front (§3, `wss://` on 443); set `0.0.0.0` and open 9080/9081 in the
firewall for plain `ws://IP:9080` without a domain.

nginx (one domain, TLS, counter on the same port):

```nginx
location /health { proxy_pass http://127.0.0.1:9081/health; }
location /       { proxy_pass http://127.0.0.1:9080; proxy_http_version 1.1;
                   proxy_set_header Upgrade $http_upgrade; proxy_set_header Connection "upgrade";
                   proxy_read_timeout 3600s; }
```
→ `host=farm.example.ir`, `port=443`, `tls=true`, `health_port=443`.

### Keep-alive for sleeping free tiers

Three layers, all lightweight:

1. **In-game heartbeat**: every client pings every `heartbeat_sec` (20 s) and sends
   movement at the tick rate; the server drops peers silent for `heartbeat_timeout_sec`
   (60 s) so dead phones don't hold a room slot. Dropped clients reconnect by themselves.
2. **`/health`** (also `/`, `/healthz`, `/ping`, `/stats`) on `health_port` returns
   `{"ok":true,"players":N,"rooms":M,"version":"7.1.0"}` without touching game state.
3. **External pinger** so nobody-online periods don't put the host to sleep:

```bash
FARM_HEALTH_URL=http://YOUR_SERVER_HOST:9081/health ./tools/keepalive.sh
# cron: */10 * * * * FARM_HEALTH_URL=... /opt/farm/game/tools/keepalive.sh >> /tmp/keepalive.log 2>&1
# single-port hosts (Render/Railway/Fly): any HTTP answer wakes the app
FARM_HEALTH_URL=https://farm-town.onrender.com/ FARM_KEEPALIVE_ANY=1 ./tools/keepalive.sh
```
   Or rename `.github/workflows/keepalive.yml.disabled` → `keepalive.yml` and add the repo
   secret `FARM_HEALTH_URL` (GitHub pings every 10 minutes; any HTTP answer counts).
   Always-on VPS / systemd hosts don't need this.

### Rooms, joining, limits

* Players open **Play → Online**. **Host** creates a room with a 6-character code
  (letters/digits without look-alikes) and shows it big on screen; friends type it under
  **Join by code**, or tap it in the **Server list** (public rooms + `MAIN`).
* **Direct connect** (LAN / testing): type `ws://192.168.1.20:9080`.
* `max_per_room` (default 6) — a join beyond that gets "room full" and the player stays
  connected in their current room; a wrong code gets "room code not found".
* `max_players_total` (24) caps one server process.
* Version check on hello: same version or `compat_prefix` → allowed; otherwise
  "version mismatch" → that player keeps playing offline (update offered via
  `docs/UPDATES.md`).
* Positions, chat, saves (newest wins), away avatars and live module pushes work inside
  each room exactly as in v5d.

### Port note

Older docs mentioned `8910`. v7b.1 defaults to **9080** (game) + **9081** (health).
CLI `--port=` / `--health-port=` still override; nginx proxies `wss://` 443 → 9080 as above.

### Tested locally

`python3 tools/net_test.py` starts a headless server (`--max-per-room=3
--heartbeat-timeout=20`) plus up to four headless clients and checks: connect, movement
sync, server-side speed-hack correction, chat + rate limit, live module push / poisoned
module rejection, disconnect → away avatar → reconnect with save restore, host room with
code, join by code (2nd and 3rd player), positions inside the room, ping/pong, server list,
`/health` player count, room full (4th player refused, stays online), unknown code,
heartbeat timeout (frozen client dropped, then reconnects), version mismatch → offline,
server killed → offline play → automatic resync.
