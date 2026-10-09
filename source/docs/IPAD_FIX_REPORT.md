# iPad controls and streaming fixes

This release fixes iPad input detection, camera controls, deferred town work,
and the failures that blocked the v7b.1 release. The exported build uses the
Compatibility renderer and single-threaded WebAssembly.

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
- Latest strict full smoke run: **2617 checks, 0 failures, no SCRIPT ERROR**.
  The original 15 failing checks are resolved, including their dependent section
  failures. Initial 2598/15 results are superseded by this run.
- Compile validation: **764 files, 0 failures**; module manifest check passed.
- Network suite: **60 checks, 0 failures**.
- Web export: **10,572,928-byte PCK**.
- Chromium release checks passed: entry into single-player, no console errors,
  browser save persistence across reload, successful F9 load, no unexpected
  WebSocket connections or external-host requests. Screenshots were captured
  through CDP to avoid compositor waits on this software-rendered test host.

## Resolution of the original failures

| Failed checks | Cause and correction |
| --- | --- |
| Night schedules; population controller cast | City Hall owns a separate Staffing instance that kept three actors assigned. All staffing instances now honor smoke isolation and release actors between sections. Normal gameplay still runs staffing. |
| Controls categories | Include the new MouseTouch tab in the expected tab list. |
| Social chat count | Assert the explicit chat's increment before unrelated background chats occur. |
| Extra lot count | Compare constructed lots with the active module's configured lots, rather than an old hardcoded minimum of two. |
| Police settlement/report | Wait for process frames, where Conflicts runs, rather than only physics frames. |
| Restored tipsy timer | Check the restored value immediately, before gameplay decrements it. |
| Steering wheel | Isolate the car's physics input while checking visual steering, and wait for render/process updates. |
| Home roof boards | Count only family signs; explicitly verify the farmhouse keeps its fallback sign. |
| Tow truck departure | Move the test's farmer out of the safety-aware truck's path. |
| Transit boarding | Allow the documented seven-second walk-to-door fallback to complete. |
| Transit alighting | Add an alighting cooldown so the same resident is not immediately loaded again at that stop. |
| High-speed hit; accident creation; police section | Use a fresh victim outside the light-hit cooldown and prepare the shared car's gearbox/fuel/condition. Physical car contacts also report speed before collision braking. |

Two subsequently exposed fixture issues were corrected as well: directory
family names follow the selected language, and NPC-card content is checked before
the automatic proximity scanner selects a different resident.

A genuine runtime error discovered during module swaps was also fixed:
FootstepAudio validates cached actor references before casting them. The release
gate now rejects SCRIPT ERROR output even when all assertion checks pass.

## Release limitation

Physical Safari/iPad performance remains unmeasured. Automated Chromium checks
do not establish frame rates or Safari compatibility on a physical device.

The first release kept its download and exteriors eager. The subsequent streaming
and map update separates a smaller core PCK from shared world and avatar packs,
builds nearby exterior geometry at most once per town scheduler frame and releases
it when far away. Doors, collision and module-owned attachments keep their identity.
See [STREAMING_MAP_REPORT.md](STREAMING_MAP_REPORT.md) for the new release's scope
and validation. Roads, terrain and nature scattering are not fully generated per
cell; the WebAssembly engine is still required to start the game.
