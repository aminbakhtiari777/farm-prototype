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
