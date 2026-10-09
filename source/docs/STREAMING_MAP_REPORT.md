# Demand-loaded web packs, building exteriors and a compact labelled map

The previous version downloaded all content in one PCK and constructed every
building exterior during scene initialization. This update splits those costs.

## Behaviour

- The web export starts in the Boot menu. The initial core PCK is about 5.5 MB
  instead of 10.6 MB. No extra pack is requested before Play.
- Play downloads shared world, hair and animation assets before entering the
  world. Male/female body packs are requested by visible characters as needed.
  Distant NPC models wait until the player approaches; construction is spread
  across frames. The player model must finish before the browser gate passes.
- Pack filenames and disk caches are versioned by SHA-256. Downloads and caches
  are verified before mounting. Failed downloads retry; a lightweight stand-in
  remains until the character model is available.
- Buildings initialize layout data, doors, structural collision and interior
  anchors. The town scheduler constructs the nearest pending exterior, at most
  one per frame, and releases exterior geometry after 15 seconds outside the
  radius plus a 35 m margin. Entering a building ensures its exterior immediately.
- Exterior release/re-entry preserves doors, furniture and module attachments.
  Burned/demolished states are reapplied when visual geometry returns. Porch
  seats remain logical objects instead of disappearing with their meshes.
- Shop/civic furniture now uses the interior streaming path too; the farmhouse
  retains its immediately usable interior.
- The minimap is capped at 150 px, down to 96 px on short viewports. Small shaped
  Persian/English place names come from layout data rather than loaded meshes.
  Nearby labels get priority, with collision checks to avoid overlapping text.
  Markers remain visible for places whose labels do not fit.

## Validation

- Focused streaming regressions: 26 checks, zero failures.
- Focused performance/map checks: 135 checks, zero failures.
- Full gameplay smoke suite: 2,628 checks, zero failures. Focused emergency
  response checks: 59; night routines: 58; fire response/spread: 18, all passing.
- Residents arriving home to sleep now end lingering social conversations.
  The smoke fixtures isolate normal stamina from exhaustion, observe emergency
  states before treatment completes, and separate fire spread from nearby hosing.
- Export splitting verifies every original resource's MD5 and preserves the
  complete resource inventory across the core and optional packs.
- An isolated Godot project mounted the core and all optional packs, confirmed
  the core excludes character models and loaded both avatars, nature and
  animations with their imported dependencies.
- Chromium passed menu download timing, model readiness, single-player entry,
  no console errors, persistent save/reload/F9 and offline connection checks.
- Complete release gate passed: compile 765 files, gameplay 2,628 checks,
  networking 60 checks, export and Chromium. All checks had zero failures.
  Core PCK: 5,510,996 bytes, versus 10,587,640 before splitting. All 15
  exported artifacts are recorded with SHA-256 before publication.

## Boundaries

The shared world pack is a dependency of entering the world, not a network pack
per town block. Terrain, roads and nature scattering still have startup work.
The Godot WebAssembly engine (about 37.7 MB before HTTP compression/cache) must
be available to start. This change removes the monolithic content download and
eager exterior construction; it does not claim zero initial work or measured
frame rates on a physical iPad/Safari.
