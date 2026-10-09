# Farm Prototype (Web) - v7b.1

A Godot 4 farming and small-town life prototype (Harvest Moon-style), exported for the web.
Play it at https://aminbakhtiari777.github.io/farm-prototype/ (click the game once to give it keyboard focus and enable sound). Press **F1** in game for all controls.

## iPad controls and performance fixes
- Touch controls are detected on iPadOS even when Safari presents a desktop identity, and stay visible with a mouse or trackpad.
- Auto graphics starts on Low on touch devices. Distant processing sleeps, interiors load on approach, and distant benches, bins and planters are built gradually.
- Focus changes and screen rotation release held controls. Mouse and right-stick camera look support yaw and pitch.
- The initial PCK contains the core/menu. Shared world assets load after Play; avatar packs download when needed and use verified caches. Building exteriors construct one at a time near the player, and distant geometry is released.
- The minimap is smaller (up to 150 px, responsive on small screens), with Persian/English place labels that work even when building graphics are unloaded.

## What's new in v7b.1 (controls)
- GTA-style mouse look: click the game once to capture the mouse, then the mouse turns the camera (up / down / left / right) and **W A S D** walk where you are looking. **Esc** (or any panel) frees the cursor.
- Driving: the mouse steers left / right (A / D still work), **W** gas, **S** brake / reverse, **Space** handbrake. **V** or **C** switches to the cockpit view - the steering wheel turns with you, the mouse looks around inside the car and up through the roof. A gear readout shows A (automatic), 1-4, R or N.
- iPhone / iPad / Android: two virtual joysticks appear where your thumbs land - left moves (gas / brake in a car), right looks / steers - plus buttons for E / get in / out, jump, run, horn, lights, camera, menu and help.
- Playing as a townsperson (**F2** or the touch "Play as" button) uses exactly the same mouse and joystick controls, also when they drive; the touch screen adds Dig / Demolish / Fire / Return buttons.
- Space no longer locks the character's pose. Settings: mouse sensitivity, invert Y, touch controls (auto / on / off). **F1** has a new "Mouse & Touch" tab.

## What's new in v7b.1 (visual pass)
- Realistic cars: distinct paints (no more pink), side mirrors, tyres with rims, see-through windows, an interior with seats / dashboard / gauges, a steering wheel that turns, a Persian-style plate and a nice front (grille, headlights, bumper). The fire truck is a real red engine with a ladder, hose reels, "آتش‌نشانی ۱۲۵" and a siren.
- Varied faces, hair (including hijab / scarf), skin tones and body types for every resident; looks are saved with the game.
- No big family boards on home roofs - a small plaque by the door ("خانواده آقای احمدی"); houses differ more; your farmhouse is highlighted on the minimap.
- The post office and the outdoor city-fund kiosk are gone; City Hall has an interior with a counter, a manager and clerks, and the fund board hangs inside (**F4** only works there).
- Varied street and house plants; nobody lies on the square paving; the coloured flower balls are gone.
- Families differ (four kids, no kids, newlyweds, young, elderly, singles); every adult has a city job, kids go to school, the elderly are retired or do light work - shown on the name card and in the **J** directory.

## What's new in v7b.1 (traffic and night life)
- Wider streets with lane markings, zebra crossings, STOP and speed-limit signs, and Persian / English direction boards.
- Traffic lights with real cycles, a traffic officer and red-light cameras. Running a red light, rolling a STOP sign or speeding near a camera means a fine, a police report and a newspaper item; a second offence costs your licence for two days and your car goes to the impound lot.
- Get a driving licence at the police station (**F3**): read the booklet, pass the quiz. The new car dealership only sells to licensed drivers.
- Bus line 1 with shelters and timetables: ride the bus (5 G) or drive the spare one and collect fares.
- Each car model sounds different (engine, horn, indicators **8**/**9**).
- A classy café terrace and an indoor lounge that turns into a disco at night; brighter, warmer street lights; the road to the new city (under construction).

## What's new in v7b
- A chattier town: small Persian bubbles - people comment on the weather, fires, power cuts, fines, public works, your driving and horn, and chat with each other (you can overhear). Press **5** for a chat log.
- Terrace café next to the Café (afternoon to midnight): a bartender, a DJ with music you hear as you get closer, tea, coffee, juices, doogh, lemonade and two "strong" drinks that make you a little tipsy for a short while (wobbly walk, slight blur). The bartender stops after two; don't drive afterwards. Small scuffles happen - the bartender or the police break them up, with fines. If the bartender or DJ is away, another resident fills in.
- Cars need care: fuel, wear, a mechanic on Main St (repairs, fuel, upgrades), gears (**3** manual/auto, **Shift/Ctrl** shift), headlights (**H**, needed at night), a dashboard.
- Give rides: people waving at a stop (yellow beam) pay a fare when you drop them at the green beam; generous people tip.
- Camping: drive to the pine forest or the lookout hill, press **6** for a tent and a campfire, sleep under the stars.
- The daily paper at the newsstand by the square (**E** to buy, **4** to read) reports what really happened in town.
- Personalities (calm, hot-tempered, generous, stingy, cheerful, shy) shape arguments and trades - press **7** next to someone to haggle. Every resident has their own voice.
- Still offline single-player by default.

## What's new in v7a
- Townspeople have life stories: spouse, job, talents, a current worry, a past hardship and a hope - on their name card and in what they say. They remember what you did (good and bad) and bring it up.
- After school the kids come out: two bike around the square, the others play tag, chat, and sometimes ring a doorbell and run (the neighbour grumbles - and remembers).
- Street arguments over debts, missing things or noise: heated red bubbles and gestures. Press **E** on them to calm things down (friendship up) - or the police come and settle it.
- Play as a townsperson: stand next to someone and press **F2**. You keep their name, job, home and memories. **R** digs, **1** demolishes your own house with an axe, **2** starts a fire - both ask first (Persian confirmation) and have consequences: fines, police reports, people remember. **F2** again to return.
- Fire station (125) with a fire truck and three firefighters: fires grow slowly, can spread to the house next door, damage roofs and walls; the carpenter and the mason rebuild over the next days; the culprit pays fines plus damages; the ambulance stands by.
- Storms can cut the power and earthquakes shake the camera and knock things over; homes switch to candles and lanterns, and the electricity office crew drives out to fix the line.
- City fund: fines (theft, speeding, fires) and shop taxes go to the municipality fund, shown inside City Hall (counter / manager desk) and on the City Hall panel (**F4**, only inside). The fund pays for public works that appear in town over the following days (benches, streetlights, flower beds, a small park) and a doctor subsidy.
- Still offline single-player by default.

## What's new in v6b
- Make your own farmer: press **Y** (or use the farmhouse mirror) to choose a slim or regular body, face, hair, beard, skin, name and a job preset. The farmhouse wardrobe changes your clothes. Saved with the game. Townspeople have more distinct faces and hair.
- Cars: parked cars on the town roads. Walk to the driver door and press **E**; W/S drive, A/D steer, Space handbrake, **R** horn. A car dealership comes in a later version.
- An ambulance takes sick townspeople to the hospital. A police car patrols the town. A red pickup hauls wood from the dry trees to the carpenter.
- Richer homes: blue gas flames on the stove, a fridge that opens and shows what is inside, a bigger LCD TV, paintings, a blanket by the window, a sofa you can move, and each family's house in its own colour.
- The town: a clock tower on the square, family fruit gardens (ask first - picking without permission is theft and gets reported), and new lots.
- Farm life: push and stack boxes, herd sheep into the pen, dig holes (**R**), and a daily yard checklist.
- The world remembers: moved things, holes, parked cars, picked fruit and what townspeople remember about you are saved.
- Softer shadows and drifting cloud shadows; a fuller gym with a mirror wall; Persian signs, street names and controls screen; the sea now blends into the sky.
- Still offline single-player by default.

## What's new in v6a
- A real night sky: small twinkling stars and a moon with phases that rises and sets; a clear blue sky by day. Settings -> Real clock follows your device time.
- Dry trees at the forest edges: chop them with the axe for firewood, wood and boards.
- The beach: buy a fishing rod from the carpenter; sell, eat or cook your fish. Light the beach campfire with firewood and sit by it.
- Boats at the pier take you deep-sea fishing for rarer, pricier fish. A sunbathing beach with towels and umbrellas.
- A gym (treadmill, weights, bench) for you and townspeople - better stamina and health. Music from the gym and houses is heard faintly outside.
- Kitchenware at the new hypermarket (plates, pots, pans, cutlery, glasses, blender, microwave) unlocks and speeds up cooking.
- More of the interface is in Persian (English in Settings).

## What's new in v5d
- Online beta (opt-in): the game stays offline single-player unless you press **U**, enter a name and a server address and press Connect. Online you see other players with name tags and can chat (T / Enter).
- Live module updates: the server can push a new version of one module (for example wages); the game downloads only that module, swaps it in without a reinstall, keeps it for next time and can roll it back.
- If you disconnect, your farmer stays in town, walks to the cafe or home and sits; neighbours greet you and bring tea. When you come back you get a welcome-back message and townspeople remember you were away. Without a server the game keeps running and syncs later.

## What's new in v5c
- A living economy: prices follow supply and demand. Selling a lot lowers a price, shortages raise it, producers restock every morning. Townspeople earn wages, buy their food and pay the doctor (the city helps those who can't).
- A market prices board by the market (E) and a prices panel (B) with trends, stock and the town's economy.
- Workplaces produce goods: the carpenter makes planks and furniture, the blacksmith makes tools, the fruit shop sells farm produce. Sell your crops, eggs, milk and wool to shops and stalls.
- Livestock: order a coop or a barn at the carpenter's livestock desk, buy chickens, cows and sheep, feed them daily and collect eggs, milk and wool. Unfed animals get unhappy and produce less; happy pairs have young that grow up.

## What's new in v5b
- Talk to townspeople (E): a name card (job, hours, family, friendship hearts, health) and dialogue that depends on their job, family and the time of day. One talk a day builds friendship.
- Persian speech bubbles and UI text (Vazirmatn font, right-to-left), e.g. «سلام، چطوری؟ خوبی؟»; switch to English in Settings -> Dialogue. Voice blips: higher for women and children, lower for men.
- Shops and offices have working hours; the hospital is always open.
- Hunger (eat at least one meal a day) and fatigue (sleep in your bed). A cold or flu makes you sneeze and walk slower; the hospital doctor treats it for gold. Townspeople eat, sleep, get ill and visit the doctor too.
- Hands-on cooking: buy chicken, eggs and vegetables at the Supermarket, then at a stove prepare -> add salt -> add spices -> cook -> eat (counts as the day's meal).
- A new onion dome with ribs on a drum with arched windows for the mosque.

## What's new in v5a
- Workshop crafting on the farm (8 recipes) and a central market plaza with 6 stalls.
- 28 townspeople with names, ages, jobs and families who live together; press J for the town directory.
- 8 workplaces (carpenter, blacksmith, mason, fruit, clothing, jewellery, tools, electrical) with their own shops.
- Civic buildings: hospital, water office, electricity office (restores power after a cut), City Hall, police, school, university.
- An ornate town square with a fountain, mosaic, flowers, lamps and a statue.
- A mosque with a short, subtle hourly call (adhan) and a church with bells; volumes in Settings (0 = off).
- A kitchen and stove in every home: cook meals for stamina.
- Live house / yard style swaps (Settings -> Town styles) and townspeople who wave at you.

## What's new in v4
- Lights at sunset: the farmhouse porch lamp, house lanterns, window glow and street lamps switch on at sunset (driven by the game clock).
- Electricity: a main breaker on the farmhouse wall and a town power pole. Pull the lever (E) to cut or restore power; homes switch to candles, a lantern and the fireplace, and TVs go dark.
- 11 modular crops (turnip, carrot, potato, strawberry, tomato, corn, sunflower, pumpkin, eggplant, apple tree, banana plant), each with 5 growth stages (planted, growing, leaves, flowers, fruit) and a 0.5 m² or 1 m² footprint.
- A real garden: beds in rows with walkable paths, a fence with a gate, brown tilled soil, watering, sprouts, and an expansion sign (+1 bed).
- Tools with their own animation and sound (hoe, watering can, seed pouch, harvest basket, hammer), plus upgrades and unlocks (steel hoe, copper can, hammer).
- Wooden fences and railings around the town's front and back yards; wooden, stone and modern house styles with matching interiors.
- Townspeople take varied routes, chat with each other in speech bubbles and greet you.
- A denser, taller forest, mountains on the horizon, a river through the pond to the beach (you can fish there), and a minimap (Tab).
- Saving in the browser now survives a page reload (F5 save, F9 load).

## Controls (short)
- **H** headlights, **3** gearbox auto/manual, **Shift/Ctrl** gear up/down (driving); **4** newspaper, **5** chat log, **6** camp, **7** haggle.
- **F2** play as the townsperson next to you / return; **1** / **2** demolish own house / start a fire (while playing a resident, asks first); **F4** City Hall fund panel (only inside City Hall).
WASD: walk. Shift: sprint. Space: jump. X: sit. E: interact (farm, doors, talk, TV, fish, refill can, power breaker, craft, cook, shop counters). J: town directory. F: pick up/place. Q: seed. I: bag. Tab: minimap. U: online panel (opt-in). T/Enter: chat (online).
Mouse (click to capture): look / steer. Touch: left stick move, right stick look / steer. V / C (driving): cockpit view. Right-drag / Z,C: orbit camera. Wheel: zoom. P, [, ]: clock. N: day/night. K: next season. V: push-to-talk. L: voice panel. Esc: menu. F1: controls. F5/F9: save/load.

Multiplayer plan: [docs/MULTIPLAYER_PLAN.md](docs/MULTIPLAYER_PLAN.md) (foundation implemented in v5d; server setup: [docs/SERVER_SETUP.md](docs/SERVER_SETUP.md)).
