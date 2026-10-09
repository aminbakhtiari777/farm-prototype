# iPad controls and streaming fixes

The live root build is still v7b. This change prepares the newer source for
testing; it does not replace the live game's HTML/PCK/WASM files.

## Changes

- Detect touch hardware using `navigator.maxTouchPoints`, including iPadOS
  with a desktop browser identity. Cache detection instead of calling JavaScript
  repeatedly from NPC quality checks.
- Keep the touch controls visible when a real mouse/trackpad is used on a touch
  device; right-drag remains available for the camera.
- Release touch sticks and held actions on application focus loss and viewport
  resizing. Preserve independent finger tracking and diagonal camera-relative
  movement.
- Avoid processing right-drag twice while the shared input layer owns mouse look,
  and ignore emulated mouse motion and camera input behind modal panels.
- Start Auto graphics on Low for touch web/mobile hardware (explicit quality
  choices still apply).
- Put late-added content in distant sleeping cells to sleep immediately, discard
  stale cell work, and avoid duplicate pending cell requests. Use the configured
  per-frame budget for the initial sleep pass instead of a 999 ms drain.
- Fix freed audio-node references in the streaming audio cache.
- Fix weather initialization: the WeatherFx node must be attached to the scene
  in the enabled branch, not the fallback branch.
- Retain the farmhouse sign when no family plaque can replace it.
- Use the supported BlendSpace1D API so the project compiles on Godot 4.6.3 too.
- Include the web export preset in the repository; remove the dependency on a
  missing `/workspace/farm-prototype-webbuild` folder and local Godot/Chrome paths.

## Validation

- Godot 4.6.3 compile check: **764 files, 0 failures**.
- Focused controls/performance smoke suite: **191 checks, 0 failures**. Covers
  mouse yaw/pitch, touch diagonals, simultaneous sticks, focus loss/resize,
  car/cockpit/possession controls, distance LOD, late cell registration,
  streaming transitions, lazy interiors, save/load and audio/animation budgets.
- A Compatibility, single-threaded web export was built successfully locally.
- Chromium touch emulation reached the game with `touch=true` and `quality=low`.
  This is not physical iPad/Safari validation. A high-resolution software-rendered
  screenshot timed out; no iPad FPS claim is made.
- An earlier broad smoke run, before the final touch-test event synchronization,
  had **2590 checks, 23 failures**. The subsequent focused suite resolves the
  focus/resize/diagonal failures in that run. Other failures need investigation:
  NPC schedule/controller assumptions, controls tab expectations, real clock,
  wood pickup, town lots, save timing, steering-wheel fixtures, farmhouse sign
  expectations, transit boarding and road-safety/accident scenarios. Some are
  outdated test assumptions; they are not all confirmed gameplay defects.

## Release limitation

The full release gate is not green, so do not deploy this source snapshot over
the live root build yet. Test on physical Safari/iPad before releasing it.

The current streaming system sleeps distant processing/physics, uses distance
LOD and creates/releases home interiors on demand. It **does not** split the
initial PCK download or lazily construct every town exterior. Eliminating all
initial town construction requires a separate dependency-aware builder change;
do not describe this patch as complete network/world asset streaming.
