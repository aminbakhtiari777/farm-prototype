# Audio credits & licenses

| File | Source | License |
| --- | --- | --- |
| `sfx/sheep_baa_1.ogg` | "Sheep Baa" by **AntumDeluge** (from a recording by mikewest), OpenGameArt: <https://opengameart.org/content/sheep-baa> (FLAC downloaded, converted to mono OGG) | **CC0 1.0** (public domain) |
| `sfx/sheep_baa_2.ogg` | Same recording, pitched up ~18% (younger-sounding sheep) + short fade-out. Derivative made with ffmpeg | CC0 1.0 |
| `sfx/sheep_baa_3.ogg` | Same recording, pitched down ~12% (older sheep). Derivative made with ffmpeg | CC0 1.0 |
| `sfx/footstep_grass_1..4.ogg` | Procedurally synthesized for this project (`tools/synth_audio.py`, numpy/scipy) | CC0 1.0 (original work) |
| `ambience/meadow_day_loop.ogg` | Procedurally synthesized wind + leaves + bird chirps (`tools/synth_audio.py`), seamless 23 s loop | CC0 1.0 (original work) |

In game, the sheep plays one of the three baa variants at random with a random pitch (±8%) when petted
(and occasionally on its own while idling).

Web builds: browsers block audio until the first user gesture. Clicking the game canvas (needed anyway for keyboard focus) unlocks audio.

## v4 tool + power sounds

`sfx/hoe_dig.ogg`, `sfx/water_pour.ogg`, `sfx/seeds.ogg`, `sfx/harvest.ogg`, `sfx/hammer.ogg`, `sfx/switch.ogg`:
synthesized for this project with `tools/synth_audio_v4.py` (filtered noise + envelopes). Original work, CC0 1.0.
Each tool module (`modules/tool_types/*.tres`) names its own sound id (registered in `scripts/autoload/sfx.gd`).

## v5a calls

`sfx/adhan.ogg`: a short (about 11 s plus reverb), gentle call in the style of an adhan, synthesized with
`tools/synth_audio_v5a.py`: a band-limited glottal source through vowel formant filters ("aa" / "oo"), a
Hijaz-flavoured melody with portamento, vibrato and a soft reverb. No words and no recordings; meant as a
respectful, subtle hourly cue (Settings → Adhan volume, 0 = off). Original work, CC0 1.0.

`sfx/church_bell.ogg`: three strikes of a tuned bell (additive bell partials: hum, prime, minor third, fifth,
octave and upper partials with beating) and a short reverb. Original work, CC0 1.0.

## v6a music + campfire

`music/gym_loop.ogg` (120 bpm electronic loop for the gym), `music/radio_loop.ogg` (gentle santur-like
melody over a drone, heard from home radios and the cafe), `music/zarb_loop.ogg` (tombak / zarb 6/8
groove with a bell, zurkhaneh-style) and `ambience/campfire_loop.ogg` (fire crackle): synthesized for
this project with `tools/synth_audio_v6a.py` (additive tones, noise and envelopes; no samples or
recordings). Original work, CC0 1.0.

## v7b.1 footsteps, doors, square, traffic, sky

`v7b1/step_asphalt_1..3.ogg`, `v7b1/step_wood_1..3.ogg`, `v7b1/step_sand_1..3.ogg` (surface footsteps),
`v7b1/door_latch.ogg` / `v7b1/door_close.ogg` (door opens / shuts), `v7b1/murmur_loop.ogg` (wordless
town-square crowd murmur), `v7b1/traffic_loop.ogg` (distant road rumble), `v7b1/gust_1..2.ogg` (wind
gusts) and `v7b1/thunder_1..2.ogg` (distant thunder): synthesized for this project with
`tools/synth_audio_v7b1.py` (filtered noise, resonant partials, envelopes; no samples or recordings).
Mono, 11-22 kHz, Vorbis q0; ~130 KB in total. Original work, CC0 1.0.
