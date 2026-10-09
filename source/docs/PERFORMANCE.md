# Performance (v7b.1)

Box numbers come from a software renderer (llvmpipe / SwiftShader), so absolute fps is
NOT Amin's laptop - compare before vs after only. Before = v7b as live (commit aad7a92).

## Web download (what a player downloads)

| File | v7b live | v7b.1 before diet | v7b.1 web diet |
|---|---|---|---|
| index.pck | 16.24 MB (gzip 14.80) | 15.10 MB (gzip 13.62) | **10.07 MB (gzip 8.63)** |
| index.wasm (Godot 4.7.2 stock web template) | 39.51 MB (gzip ~10.1) | same | same |
| textures inside the pck | 6.80 MiB (31) | 4.97 MiB (57) | **0.55 MiB (38)** |
| scripts (.gdc) | 1.44 MiB | 1.96 MiB | 1.58 MiB |

What the web diet does (`tools/make_webbuild.py`, web copy only - desktop/native keep the
lossless originals):
- every texture is stored as **lossy WebP** (colour q=0.80, normal maps q=0.90). This is not
  VRAM compression (that would ship ETC2+S3TC twice and grow the download); the 3D importer's
  automatic switch to VRAM compression is turned off for the web copy;
- character / hair textures capped at 512 px (were 1024: 4x less decode work and GPU memory);
- the two body glTFs used their own copies of the hair textures - now they share the
  `characters/hair/` set and the duplicates are dropped;
- dev / test-only scripts (dev tools, all `*_smoke.gd` / `*_shots.gd`, the profiler, the
  net-test driver), docs, devtmp, tools, server files and native-only icons are excluded.

Not done, and why:
- **Smaller wasm**: the 39.5 MB engine is the stock export template. Shrinking it means
  compiling a custom Godot web template with unused modules disabled (hours of build +
  emscripten toolchain); it is the next big win (expected ~-30-40%).
- **Split resource packs loaded on demand**: Godot's web loader downloads the whole pck
  before the first frame. A second lazily-fetched pck is possible (same-origin
  `load_resource_pack`), but after the diet the pck is 10 MB and most of it (characters,
  trees, animation library, UI font) is needed by the first scene anyway; the remaining
  candidates (ambience/music ~1 MB, already 22 kHz mono ~40 kbps) are too small to justify
  the extra loading step. The platform workstream's base pack + update packs
  (docs/UPDATES.md) covers later downloads.
- Audio is already 22 kHz mono ~40 kbps; re-encoding would save < 0.4 MB.

## Load time (headless Chrome, SwiftShader, localhost = no network time)

| | v7b live | v7b.1 diet |
|---|---|---|
| engine started | 0.9 s | 2.5 s |
| game scene built (FARMPERF ready) | - | 14.8 s |
| first game frame (end of the loading block) | 25.8 s | 26.4 s |
| console errors / foreign requests | 0 / 0 | 0 / 0 |

The box renders WebGL in software, so most of these seconds are CPU shader/scene work that a
real GPU does far faster; v7b.1 builds more town (traffic layer, 50 residents instead of 28,
street plants) in about the same time. On a real connection the download is now ~5 MB less
(pck gzip 14.8 -> 8.6 MB), which is the part that dominates a first visit on a slow line.

## Global lag: causes and fixes (see PROGRESS_PERF.md for the raw profiles)

1. **Shadows**: 1,625 of 3,050 draw calls and 1.9 M of 3.5 M primitives per frame (~35 % of
   the frame) at the town square. Fix: Low/Medium/High presets (Auto = Medium on the web):
   2 cheap cascades to 35 m on Medium, small props/doors/fences never cast, far tree chunks
   don't cast, visibility ranges on everything (AutoLod).
2. **Camera ~85 ms behind + judder**: the farmer moves at 60 Hz physics, the camera chased
   him in `_process` without interpolation and with a 12/s lerp. Fix: physics interpolation
   for the player / driven car / possessed resident, camera follows the interpolated
   position, follow speed 20/s (~50 ms), max physics steps per frame 3-6 (was 8: a slow PC
   spiralled). Measure with `-- --perf-profile=/tmp/x.json --perf-camera`.
3. Offline there is no network polling and no autosave; scripts, audio, animation and point
   lights were each < 3 % of the frame.

Streaming and memory: WorldStreamer (cells 32 m, wake radius 70/90/150 m per preset, 2 ms per
frame budget), lazy home interiors and City Hall furniture (InteriorStreamer), far sounds
paused and idle cached streams released (AudioBudget), far animations stopped (AnimBudget).
F7 shows the live overlay (fps, frame-time p50/p95/p99, draw calls, streaming, memory).
