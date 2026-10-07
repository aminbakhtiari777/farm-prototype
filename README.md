# Farm Prototype (Web) - v2

A small Godot 4.7 farming game prototype (Harvest Moon-style) exported for the web.
Play it at https://aminbakhtiari777.github.io/farm-prototype/ (click the game once to give it keyboard focus and enable sound).

## What's new in v2
- Farming loop: till, plant, water and harvest crops on a 4x6 plot. There are 6 crops with seasons (turnip/strawberry in spring, tomato/corn in summer, pumpkin/eggplant in autumn, nothing in winter). Rain waters your crops; sunny days speed growth; storms lower the yield.
- Economy: start with 500 G. Ship produce at the bin by the farmhouse (paid instantly), or buy seeds, fertilizer and a watering-can upgrade at the town market. Prices depend on season demand and weather. Your sheep gives wool every day once its affection is high enough.
- In-game clock with day/night: sunrise and sunset, a moon and stars, street lamps and glowing windows at night. Sleep at the farmhouse door to skip to morning.
- Seasons (7 days each) with daily weather. Grass, trees, crops and sky change with the season, with petals, falling leaves, rain or snow.
- A town past the farm gate: houses, square, well, market stalls and lamps. Uneven terrain, a farmhouse, nicer farmer/sheep/trees, and sound (CC0 sheep bleats, footsteps, ambience).

## Controls
WASD/arrows: walk. Shift: run. E/Space: interact (till/plant/water/harvest, pet, shop, ship, sleep). Q: choose seed. I: bag.
P: pause clock. [ / ]: clock speed. N: day/night on/off. K: next season. M: sound. G: shadows. H: hints. Right-drag: orbit camera. Wheel: zoom.
All toggles are also buttons in the top status bar.

Demo links: `?season=winter&hour=11`, `?hour=22&demo=town`, `?demo=shop`, `?demo=crops&season=summer`.

Multiplayer plan (design doc, not implemented yet): [docs/MULTIPLAYER_PLAN.md](docs/MULTIPLAYER_PLAN.md)
