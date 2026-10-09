# Base package + updates (Farm Town)

## Idea (like PUBG / GTA launchers, kept small)

1. **Base pack** — the platform export (`.exe` + `.pck`, Linux binary + `.pck`,
   Android APK, or the web `index.pck`). Players download this once.
2. **Update packs** — later zip/`.pck` files that only carry what changed
   (module `.tres` files and, when the perf worker ships them, split resource
   packs under `builds/packs/*.pck`).
3. **Manifest** — `builds/updates/manifest.json` lists `latest` version and each
   pack's sha256. Hosted at the URL in `config/server.cfg` `[updates] manifest_url`.

## Client behaviour (`UpdateClient`)

| Situation | Result |
| --- | --- |
| `manifest_url` empty / still a `YOUR_` placeholder | no check; keep playing |
| Web build, online not opted in | no check (Pages gate needs 0 foreign requests) |
| Network error / offline | status `offline` → keep playing installed version |
| Remote `latest` == local | `up_to_date` |
| Remote newer | `update_available` → offer; **Decline** keeps current version |
| Accept (native) | download pack → sha256 verify → `PackLoader.register_installed()` → remount on next start |

`PackLoader` (autoload, first) mounts `user://updates/*.pck` before any other
autoload so gameplay scripts see the new content. `--no-update-packs` skips this
(for debugging).

## Multiplayer compatibility

`config/server.cfg`:

```
game_version="7.1.0"
compat_prefix="7.1."
```

On hello the server compares the client's version. Same version or matching
`compat_prefix` → allowed. Otherwise `s_version_mismatch` + reject; the player
keeps playing single-player offline. The server can therefore allow compatible
older clients (same major.minor) or ask them to update.

## Building an update pack

```bash
python3 tools/make_update_pack.py --version 7.1.1 \
  --modules wages,cafe --include-packs \
  --notes "wage balance + cafe tweak" \
  --base-url https://YOUR_SERVER_HOST/updates
# → builds/updates/update_7_1_1.zip + builds/updates/manifest.json
```

`--include-packs` reuses any `builds/packs/*.pck` the **perf worker** produced
(world streaming / split assets) instead of duplicating that design.

Then rsync/copy `builds/updates/` to the VPS or CDN and set:

```
[updates]
manifest_url="https://YOUR_SERVER_HOST/updates/manifest.json"
packs_base_url="https://YOUR_SERVER_HOST/updates"
```

Module-only hotfixes can still use the existing `tools/push_module.py` live path
(see `docs/SERVER_SETUP.md` §5) without a full update pack.
