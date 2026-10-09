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
- Build distant street benches, bins and planters only on approach, spreading
  work across frames. Clear merged chunk references before later batches,
  register newly merged meshes with the streamer, and scan the actual
  `StreetProps_*` meshes rather than only deleted source chunks.
- Share the one-interior-per-frame budget with custom interiors too.
- Set the clock immediately when enabling real-clock mode, including backwards.
- Fix freed audio-node references in the streaming audio cache.
- Fix weather initialization: the WeatherFx node must be attached to the scene
  in the enabled branch, not the fallback branch.
- Retain the farmhouse sign when no family plaque can replace it.
- Use the supported BlendSpace1D API so the project compiles on Godot 4.6.3 too.
- Include the web export preset in the repository; remove the dependency on a
  missing `/workspace/farm-prototype-webbuild` folder and local Godot/Chrome paths.

## Validation

- Godot 4.6.3 compile check: **764 files, 0 failures**.
- Focused controls/performance smoke suite: **193 checks, 0 failures**. Covers
  mouse yaw/pitch, touch diagonals, simultaneous sticks, focus loss/resize,
  car/cockpit/possession controls, distance LOD, late cell registration,
  streaming transitions, lazy interiors, save/load and audio/animation budgets.
  Includes regressions for deferred town props: distant work stays pending;
  approaching runs it exactly once.
- A Compatibility, single-threaded web export was built successfully locally.
- Chromium touch emulation reached the game with `touch=true` and `quality=low`.
  This is not physical iPad/Safari validation. A high-resolution software-rendered
  screenshot timed out; no iPad FPS claim is made.
- Continued full smoke run: **2598 checks, 15 failures**. The real-clock,
  wood-trip and gesture checks passed this time. Remaining failures cover night
  schedules, controls-tab expectations, social-chat counting, an NPC controller
  cast to Nil, town-lot count, police/conflict reporting, save timing, wheel
  reset timing, farmhouse board expectations, tow truck departure, transit
  boarding/alighting, and the high-speed accident scenario. Several are test
  assumptions or timing interference; they are not all confirmed gameplay bugs.
- Final network rerun: **60 checks, 0 failures**. Covers room limits,
  reconnect/heartbeat, server validation, chat, live module updates (including
  rejection of unsafe modules), save sync and offline progress. The offline
  movement check now waits for its unchanged distance/frame thresholds instead
  of assuming enough simulated ticks occur within a fixed three-second sleep.

## Release limitation

The full release gate is not green, so do not deploy this source snapshot over
the live root build yet. Physical Safari/iPad performance remains unmeasured.

The current streaming system sleeps distant processing/physics, uses distance
LOD, builds street furniture on approach and creates/releases home interiors
on demand. It **does not** split the
initial PCK download or lazily construct every town exterior. Eliminating all
initial town construction still requires a dependency-aware builder change;
do not describe this patch as complete network/world asset streaming.
