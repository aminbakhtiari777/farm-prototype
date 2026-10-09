class_name TownLayout
extends RefCounted
## Single source of truth for the v3 map layout: roads (paved + dirt), every
## building (type sign, street address, size, colours, interior theme), street
## name signposts, the beach/sea, the pond and the hills. Terrain, road meshes,
## buildings, NPC schedules, navigation and the smoke test all read from here,
## so moving a house means editing one line.
##
## Coordinates: x = east, z = south (metres). Farm centre = (0, 0); the town
## square is at (0, -50); the beach is in the south-east corner.

## Playable area (x, z, width, depth).
const PLAY_AREA := Rect2(-80.0, -140.0, 160.0, 180.0)
const TOWN_CENTER := Vector2(0.0, -50.0)
const SQUARE_RADIUS := 10.0

## Sea: everything with (x + z) > SHORE_SUM (+ noise) is water; sand inside SAND_WIDTH.
const SHORE_SUM := 62.0
const SAND_WIDTH := 13.0
const WATER_LEVEL := -0.25
const POND_CENTER := Vector2(-34.0, 14.0)
const POND_RADIUS := 7.5
## Gentle hills inside the play area: (centre, radius, height).
const HILLS: Array = [
	[Vector2(52.0, -118.0), 26.0, 7.0],   # Lookout Hill (viewpoint + bench)
	[Vector2(-62.0, -30.0), 22.0, 4.5],   # west meadow hill (forest edge)
	[Vector2(-30.0, -128.0), 20.0, 3.5],
	[Vector2(-22.0, 30.0), 14.0, 1.8],
]
const VIEWPOINT := Vector2(52.0, -118.0)

## Farm garden (v4): front-centre of the garden (gate side) and the area it can
## grow into (max beds). Terrain flattens it; grass is not scattered on it.
const GARDEN_ORIGIN := Vector2(-8.5, -2.6)
const GARDEN_MAX_RECT := Rect2(-12.0, -12.2, 7.0, 9.9)

## River (v4 landscape): from the western mountains into the pond, and out of
## the pond south past the hill. Terrain carves the channel; Landscape draws
## the water ribbon. Points outside the play area continue into the hills.
const RIVER: Array = [Vector2(-170.0, -4.0), Vector2(-130.0, 2.0), Vector2(-100.0, 7.0), Vector2(-80.0, 11.0), Vector2(-62.0, 16.0),
	Vector2(-49.0, 17.0), Vector2(-40.5, 15.5), Vector2(-34.0, 14.0), Vector2(-33.0, 21.5), Vector2(-31.5, 30.0), Vector2(-30.0, 40.0),
	Vector2(-29.0, 60.0), Vector2(-27.0, 90.0)]
const RIVER_HALF := 2.0
const RIVER_DEPTH := 1.1

## Roads: name, kind ("paved" with sidewalks/curbs, or "dirt"), half width, points.
const ROADS: Array = [
	{"name": "Main St", "kind": "paved", "half": 4.8, "points": [Vector2(-72, -50), Vector2(-10.5, -50)]},
	{"name": "Main St", "kind": "paved", "half": 4.8, "points": [Vector2(10.5, -50), Vector2(72, -50)]},
	{"name": "Oak Ave", "kind": "paved", "half": 4.2, "points": [Vector2(0, -60.5), Vector2(0, -132)]},
	{"name": "Maple St", "kind": "paved", "half": 4.2, "points": [Vector2(-62, -90), Vector2(62, -90)]},
	{"name": "Pine Ln", "kind": "paved", "half": 3.6, "points": [Vector2(-45, -53.2), Vector2(-45, -118)]},
	{"name": "Harbor Rd", "kind": "paved", "half": 4.2, "points": [Vector2(55, -53.2), Vector2(55, -24), Vector2(46, -6), Vector2(40, 4)]},
	{"name": "Farm Rd", "kind": "dirt", "half": 1.25, "points": [Vector2(0, -13.5), Vector2(0.6, -20), Vector2(-0.8, -27), Vector2(0.4, -34), Vector2(0, -40.5)]},
	{"name": "Beach Path", "kind": "dirt", "half": 1.0, "points": [Vector2(14.5, 2), Vector2(22, 4.5), Vector2(31, 6.5), Vector2(38, 8)]},
	{"name": "Pond Path", "kind": "dirt", "half": 0.9, "points": [Vector2(-14.5, 0.5), Vector2(-20, 4.5), Vector2(-26.5, 11.5)]},
	{"name": "Lookout Trail", "kind": "dirt", "half": 0.9, "points": [Vector2(62, -90), Vector2(66, -100), Vector2(60, -110), Vector2(53, -116)]},
	{"name": "Farmhouse Path", "kind": "dirt", "half": 0.8, "points": [Vector2(-5.2, 7.0), Vector2(-3.6, 5.2), Vector2(-1.6, 3.5), Vector2(-0.3, -2.0), Vector2(0.0, -13.5)]},
	# v5a: path from Oak Ave to the university on the north hill.
	{"name": "University Walk", "kind": "dirt", "half": 1.1, "points": [Vector2(-4.8, -124.0), Vector2(-19.6, -124.0)]},
	# v7b1 (traffic): wider city streets (Main St 2 lanes + parking strip, others 2 wide lanes) and
	# the road out of town towards the future second city (continues past the map edge, see NewCityRoad).
	{"name": "New City Rd", "kind": "paved", "half": 4.2, "points": [Vector2(72, -50), Vector2(79.5, -50)]},
]

## v5a central market area ("market" module): a paved plaza on Farm Rd between
## the farm and the town square. Terrain flattens it; stalls stand on both sides.
const MARKET_RECT := Rect2(-9.0, -30.0, 18.0, 12.0)
const MARKET_CENTER := Vector2(0.0, -24.0)

## Buildings. kind: home / store / cafe / city_hall / hospital / police / supermarket
## (v5a: workshop / workplace / civic / mosque / church).
## sign = big board above the door ("" = none); address = plaque by the door.
const BUILDINGS: Array = [
	{"id": "farmhouse", "kind": "home", "sign": "Your Farmhouse", "address": "1 Farm Rd", "pos": Vector2(-9.5, 7.5), "yaw": 90.0,
		"size": Vector3(7.5, 3.0, 6.0), "roof": 2.0, "wall": Color(0.88, 0.82, 0.7), "roof_color": Color(0.5, 0.22, 0.16),
		"interior": "farmhouse", "porch": true, "sleep": true, "owner": ""},
	{"id": "store", "kind": "store", "sign": "General Store", "address": "2 Town Sq", "pos": Vector2(13.5, -36.5), "yaw": -135.0,
		"size": Vector3(8.0, 3.2, 6.5), "roof": 2.0, "wall": Color(0.93, 0.87, 0.74), "roof_color": Color(0.62, 0.3, 0.2), "interior": "store"},
	{"id": "cafe", "kind": "cafe", "sign": "Cafe", "address": "4 Town Sq", "pos": Vector2(-13.5, -36.5), "yaw": 135.0,
		"size": Vector3(7.5, 3.0, 6.5), "roof": 1.8, "wall": Color(0.92, 0.75, 0.62), "roof_color": Color(0.3, 0.42, 0.3), "interior": "cafe"},
	{"id": "city_hall", "kind": "city_hall", "sign": "Municipality - City Hall", "address": "1 Town Sq", "pos": Vector2(15.0, -65.0), "yaw": -45.0,
		"size": Vector3(10.0, 4.6, 7.5), "roof": 2.4, "wall": Color(0.95, 0.93, 0.88), "roof_color": Color(0.33, 0.35, 0.4), "interior": "office", "tall": true},
	{"id": "hospital", "kind": "hospital", "sign": "Hospital", "address": "20 Main St", "pos": Vector2(34.0, -62.0), "yaw": 0.0,
		"size": Vector3(11.0, 4.6, 8.0), "roof": 2.0, "wall": Color(0.96, 0.96, 0.95), "roof_color": Color(0.45, 0.5, 0.55), "interior": "hospital", "tall": true},
	{"id": "supermarket", "kind": "supermarket", "sign": "Supermarket", "address": "15 Main St", "pos": Vector2(34.0, -38.5), "yaw": 180.0,
		"size": Vector3(11.0, 3.4, 8.0), "roof": 1.6, "wall": Color(0.85, 0.88, 0.8), "roof_color": Color(0.25, 0.4, 0.3), "interior": "supermarket"},
	{"id": "police", "kind": "police", "sign": "Police Station", "address": "11 Main St", "pos": Vector2(-34.0, -62.0), "yaw": 0.0,
		"size": Vector3(9.0, 3.4, 7.0), "roof": 1.8, "wall": Color(0.78, 0.82, 0.9), "roof_color": Color(0.2, 0.25, 0.4), "interior": "police"},
	{"id": "maple2", "kind": "home", "sign": "", "address": "2 Maple St", "pos": Vector2(-30.0, -80.5), "yaw": 180.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 2.0, "wall": Color(0.86, 0.85, 0.7), "roof_color": Color(0.55, 0.25, 0.18), "interior": "home_a", "owner": "Mina"},
	{"id": "maple4", "kind": "home", "sign": "", "address": "4 Maple St", "pos": Vector2(18.0, -80.5), "yaw": 180.0,
		"size": Vector3(7.0, 4.4, 6.0), "roof": 2.0, "wall": Color(0.82, 0.55, 0.45), "roof_color": Color(0.3, 0.3, 0.33), "interior": "home_b", "tall": true, "owner": "Reza"},
	{"id": "maple3", "kind": "home", "sign": "", "address": "3 Maple St", "pos": Vector2(-20.0, -99.5), "yaw": 0.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.78, 0.84, 0.74), "roof_color": Color(0.42, 0.24, 0.17), "interior": "home_c", "timber": true, "owner": "Sara"},
	{"id": "maple5", "kind": "home", "sign": "", "address": "5 Maple St", "pos": Vector2(26.0, -99.5), "yaw": 0.0,
		"size": Vector3(7.5, 4.4, 6.0), "roof": 2.1, "wall": Color(0.95, 0.93, 0.88), "roof_color": Color(0.35, 0.22, 0.15), "interior": "home_d", "tall": true, "timber": true, "owner": "Dariush"},
	{"id": "oak12", "kind": "home", "sign": "", "address": "12 Oak Ave", "pos": Vector2(11.0, -118.0), "yaw": -90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.8, "wall": Color(0.92, 0.75, 0.62), "roof_color": Color(0.3, 0.42, 0.3), "interior": "home_b", "owner": "Leila"},
	{"id": "oak15", "kind": "home", "sign": "", "address": "15 Oak Ave", "pos": Vector2(-11.0, -112.0), "yaw": 90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.72, 0.8, 0.86), "roof_color": Color(0.33, 0.35, 0.4), "interior": "home_a", "owner": "Omid"},
	{"id": "pine9", "kind": "home", "sign": "", "address": "9 Pine Ln", "pos": Vector2(-55.0, -72.0), "yaw": 90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.88, 0.8, 0.62), "roof_color": Color(0.45, 0.2, 0.15), "interior": "home_c", "owner": "Nasrin"},
	{"id": "harbor2", "kind": "home", "sign": "", "address": "2 Harbor Rd", "pos": Vector2(65.0, -36.0), "yaw": -90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.8, "wall": Color(0.7, 0.84, 0.88), "roof_color": Color(0.25, 0.3, 0.45), "interior": "home_d", "owner": "Kian"},
	# ---------------------------------------------------------------- v5a
	# "module" = the registry type that styles / fills the building; "shop" =
	# the shop id its counter opens (WorkplaceStyle.shops / CivicStyle.desks).
	# Farm workshop (crafting module): workbench for recipes.
	{"id": "workshop", "kind": "workshop", "module": "crafting", "sign": "Workshop", "address": "1b Farm Rd", "pos": Vector2(9.0, 9.0), "yaw": 180.0,
		"size": Vector3(5.5, 2.8, 4.5), "roof": 1.5, "wall": Color(0.6, 0.44, 0.3), "roof_color": Color(0.36, 0.3, 0.26), "interior": "workshop", "timber": true},
	# Workplaces (workplaces module): Main St crafts row, Market Ln shops.
	{"id": "carpenter", "kind": "workplace", "module": "workplaces", "shop": "carpenter", "sign": "Carpenter", "address": "21 Main St", "pos": Vector2(-28.0, -39.0), "yaw": 180.0,
		"size": Vector3(9.0, 3.4, 7.0), "roof": 2.0, "wall": Color(0.74, 0.58, 0.4), "roof_color": Color(0.4, 0.26, 0.16), "interior": "carpenter", "timber": true},
	{"id": "blacksmith", "kind": "workplace", "module": "workplaces", "shop": "blacksmith", "sign": "Blacksmith", "address": "23 Main St", "pos": Vector2(-42.0, -39.0), "yaw": 180.0,
		"size": Vector3(8.0, 3.4, 7.0), "roof": 1.8, "wall": Color(0.5, 0.48, 0.46), "roof_color": Color(0.22, 0.22, 0.24), "interior": "blacksmith"},
	{"id": "mason", "kind": "workplace", "module": "workplaces", "shop": "mason", "sign": "Stonemason", "address": "25 Main St", "pos": Vector2(-56.0, -39.0), "yaw": 180.0,
		"size": Vector3(9.0, 3.2, 7.0), "roof": 1.8, "wall": Color(0.78, 0.74, 0.66), "roof_color": Color(0.45, 0.32, 0.24), "interior": "mason"},
	{"id": "tool_shop", "kind": "workplace", "module": "workplaces", "shop": "tool_shop", "sign": "Tool Shop", "address": "27 Main St", "pos": Vector2(-69.0, -39.5), "yaw": 180.0,
		"size": Vector3(7.0, 3.2, 6.5), "roof": 1.8, "wall": Color(0.62, 0.7, 0.62), "roof_color": Color(0.3, 0.36, 0.3), "interior": "tool_shop"},
	{"id": "electrical", "kind": "workplace", "module": "workplaces", "shop": "electrical", "sign": "Electrical Supplies", "address": "18 Main St", "pos": Vector2(-58.0, -62.0), "yaw": 0.0,
		"size": Vector3(8.0, 3.2, 7.0), "roof": 1.7, "wall": Color(0.85, 0.82, 0.6), "roof_color": Color(0.28, 0.3, 0.36), "interior": "electrical"},
	{"id": "jewelry", "kind": "workplace", "module": "workplaces", "shop": "jewelry", "sign": "Jeweller", "address": "22 Main St", "pos": Vector2(47.0, -62.5), "yaw": 0.0,
		"size": Vector3(7.0, 3.2, 6.5), "roof": 1.8, "wall": Color(0.36, 0.3, 0.42), "roof_color": Color(0.2, 0.18, 0.24), "interior": "jewelry"},
	{"id": "fruit_shop", "kind": "workplace", "module": "workplaces", "shop": "fruit_shop", "sign": "Fruit Shop", "address": "1 Market Ln", "pos": Vector2(-14.5, -24.0), "yaw": 90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.8, "wall": Color(0.95, 0.85, 0.6), "roof_color": Color(0.55, 0.3, 0.15), "interior": "fruit_shop"},
	{"id": "clothing", "kind": "workplace", "module": "workplaces", "shop": "clothing", "sign": "Clothing", "address": "2 Market Ln", "pos": Vector2(14.5, -24.0), "yaw": -90.0,
		"size": Vector3(7.0, 3.2, 6.0), "roof": 1.8, "wall": Color(0.86, 0.7, 0.78), "roof_color": Color(0.38, 0.25, 0.35), "interior": "clothing"},
	# Civic buildings (civic module). Hospital / city hall / police are above.
	{"id": "water_office", "kind": "civic", "module": "civic", "shop": "water_office", "sign": "Water Office", "address": "8 Maple St", "pos": Vector2(36.0, -80.5), "yaw": 180.0,
		"size": Vector3(8.0, 3.4, 6.5), "roof": 1.6, "wall": Color(0.72, 0.84, 0.92), "roof_color": Color(0.2, 0.36, 0.52), "interior": "water_office"},
	{"id": "power_office", "kind": "civic", "module": "civic", "shop": "power_office", "sign": "Electricity Office", "address": "10 Maple St", "pos": Vector2(52.0, -80.5), "yaw": 180.0,
		"size": Vector3(8.0, 3.4, 6.5), "roof": 1.6, "wall": Color(0.95, 0.88, 0.55), "roof_color": Color(0.3, 0.3, 0.32), "interior": "power_office"},
	{"id": "school", "kind": "civic", "module": "civic", "shop": "school", "sign": "School", "address": "9 Maple St", "pos": Vector2(42.0, -100.5), "yaw": 0.0,
		"size": Vector3(12.0, 3.6, 8.0), "roof": 2.0, "wall": Color(0.88, 0.62, 0.45), "roof_color": Color(0.42, 0.2, 0.15), "interior": "school"},
	{"id": "university", "kind": "civic", "module": "civic", "shop": "university", "sign": "University", "address": "1 University Walk", "pos": Vector2(-26.0, -124.0), "yaw": 90.0,
		"size": Vector3(16.0, 4.8, 10.0), "roof": 2.4, "wall": Color(0.86, 0.8, 0.7), "roof_color": Color(0.3, 0.34, 0.4), "interior": "university", "tall": true},
	# Places of worship (mosque / church modules).
	{"id": "mosque", "kind": "mosque", "module": "mosque", "sign": "Mosque", "address": "6 Oak Ave", "pos": Vector2(-14.0, -78.0), "yaw": 90.0,
		"size": Vector3(10.0, 4.4, 10.0), "roof": 0.0, "wall": Color(0.93, 0.9, 0.82), "roof_color": Color(0.25, 0.55, 0.62), "interior": "mosque", "roof_type": "flat"},
	{"id": "church", "kind": "church", "module": "church", "sign": "Church", "address": "13 Maple St", "pos": Vector2(-33.0, -102.0), "yaw": 0.0,
		"size": Vector3(8.0, 4.6, 12.0), "roof": 3.4, "wall": Color(0.82, 0.78, 0.7), "roof_color": Color(0.32, 0.3, 0.34), "interior": "church"},
	# v6a: town gym (gym module) and hypermarket (hypermarket module: kitchenware).
	{"id": "gym", "kind": "gym", "module": "gym", "sign": "Gym", "address": "12 Maple St", "pos": Vector2(66.0, -80.5), "yaw": 180.0,
		"size": Vector3(9.0, 3.4, 7.0), "roof": 1.6, "wall": Color(0.6, 0.66, 0.74), "roof_color": Color(0.22, 0.24, 0.3), "interior": "gym", "roof_type": "flat"},
	{"id": "hypermarket", "kind": "hypermarket", "module": "hypermarket", "shop": "hypermarket", "sign": "Hypermarket", "address": "24 Main St", "pos": Vector2(66.0, -62.5), "yaw": 0.0,
		"size": Vector3(10.0, 3.6, 8.0), "roof": 1.6, "wall": Color(0.9, 0.92, 0.95), "roof_color": Color(0.15, 0.4, 0.65), "interior": "hypermarket", "roof_type": "flat"},
	# More family homes (population module fills them).
	{"id": "maple7", "kind": "home", "sign": "", "address": "7 Maple St", "pos": Vector2(10.0, -100.5), "yaw": 0.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.9, 0.86, 0.72), "roof_color": Color(0.45, 0.25, 0.2), "interior": "home_a", "owner": "Rostami"},
	{"id": "maple1", "kind": "home", "sign": "", "address": "1 Maple St", "pos": Vector2(-56.0, -80.5), "yaw": 180.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.8, 0.86, 0.9), "roof_color": Color(0.3, 0.32, 0.4), "interior": "home_b", "owner": "Nouri"},
	{"id": "oak10", "kind": "home", "sign": "", "address": "10 Oak Ave", "pos": Vector2(11.0, -109.0), "yaw": -90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.8, "wall": Color(0.93, 0.82, 0.7), "roof_color": Color(0.5, 0.28, 0.2), "interior": "home_c", "owner": "Bell"},
	{"id": "pine14", "kind": "home", "sign": "", "address": "14 Pine Ln", "pos": Vector2(-54.5, -106.0), "yaw": 90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.84, 0.78, 0.66), "roof_color": Color(0.36, 0.24, 0.18), "interior": "home_d", "owner": "Haddad"},
	# v7b1 homes begin (families module: new households)
	# v7b1 homes end
	# v7b1 homes begin (families module: new households)
	# v7b1 homes end
	# v7b1 homes begin (families module: new households)
	{"id": "pine11", "kind": "home", "sign": "", "address": "11 Pine Ln", "pos": Vector2(-35.0, -71.0), "yaw": -90.0,
		"size": Vector3(7.5, 3.2, 6.0), "roof": 2.0, "wall": Color(0.9, 0.82, 0.7), "roof_color": Color(0.4, 0.22, 0.16), "interior": "home_a", "owner": "Bakhtiari"},
	{"id": "oak16", "kind": "home", "sign": "", "address": "16 Oak Ave", "pos": Vector2(11.0, -128.0), "yaw": -90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.82, 0.78, 0.7), "roof_color": Color(0.32, 0.34, 0.4), "interior": "home_c", "owner": "Kia", "timber": true},
	{"id": "harbor4", "kind": "home", "sign": "", "address": "4 Harbor Rd", "pos": Vector2(65.0, -21.0), "yaw": -90.0,
		"size": Vector3(7.0, 3.0, 6.0), "roof": 1.9, "wall": Color(0.92, 0.84, 0.66), "roof_color": Color(0.4, 0.25, 0.2), "interior": "home_b", "owner": "Houshyar"},
	{"id": "pine18", "kind": "home", "sign": "", "address": "18 Pine Ln", "pos": Vector2(-54.5, -118.0), "yaw": 90.0,
		"size": Vector3(6.5, 2.9, 5.5), "roof": 1.7, "wall": Color(0.78, 0.8, 0.84), "roof_color": Color(0.28, 0.3, 0.36), "interior": "home_d", "owner": "Soleimani"},
	# v7b1 homes end
]

## Street-name signposts at intersections (position, names on the two boards).
const STREET_SIGNS: Array = [
	[Vector2(5.0, -64.5), "Oak Ave", "Main St"],
	[Vector2(5.0, -85.0), "Oak Ave", "Maple St"],
	[Vector2(-40.6, -56.6), "Pine Ln", "Main St"],
	[Vector2(-40.2, -85.0), "Pine Ln", "Maple St"],
	[Vector2(59.8, -57.2), "Harbor Rd", "Main St"],
	[Vector2(3.0, -16.0), "Farm Rd", "Town ->"],
	[Vector2(42.5, 9.5), "Beach", "Harbor Rd"],
	[Vector2(58.5, -95.0), "Lookout Trail", "Maple St"],
	[Vector2(-17.5, -1.5), "Pond Path", "Farm"],
	[Vector2(-5.0, -127.0), "University", "Oak Ave"],
	[Vector2(-11.0, -16.5), "Market", "Farm Rd"],
]


## Door position (world, outside the door) and the direction it faces.
static func door_point(b: Dictionary, outside: float = 1.4) -> Vector3:
	var yaw := deg_to_rad(float(b["yaw"]))
	var size: Vector3 = b["size"]
	var forward := Vector3(sin(yaw), 0.0, cos(yaw))
	var p: Vector2 = b["pos"]
	return Vector3(p.x, 0.0, p.y) + forward * (size.z * 0.5 + outside)


static func building(id: String) -> Dictionary:
	for b in BUILDINGS:
		if b["id"] == id:
			return b
	return {}


## Building footprints (for clearing grass/trees and flattening the ground).
static func footprint(b: Dictionary, margin: float = 0.0) -> PackedVector2Array:
	var size: Vector3 = b["size"]
	var hx := size.x * 0.5 + margin
	var hz := size.z * 0.5 + margin + (1.8 if b.get("porch", false) else 0.0)
	var yaw := deg_to_rad(float(b["yaw"]))
	var c: Vector2 = b["pos"]
	var out := PackedVector2Array()
	for corner in [Vector2(-hx, -hz), Vector2(hx, -hz), Vector2(hx, hz), Vector2(-hx, hz)]:
		var v: Vector2 = corner
		out.append(c + Vector2(v.x * cos(yaw) + v.y * sin(yaw), -v.x * sin(yaw) + v.y * cos(yaw)))
	return out


## Distance (metres, negative = inside) from p to the building's rotated rectangle.
static func footprint_distance(b: Dictionary, p: Vector2, margin: float = 0.0) -> float:
	var size: Vector3 = b["size"]
	var yaw := deg_to_rad(float(b["yaw"]))
	var d := p - (b["pos"] as Vector2)
	var lx := d.x * cos(yaw) - d.y * sin(yaw)
	var lz := d.x * sin(yaw) + d.y * cos(yaw)
	var hz_front := size.z * 0.5 + margin + (1.8 if b.get("porch", false) else 0.0)
	var qx := absf(lx) - (size.x * 0.5 + margin)
	var qz := (lz - hz_front) if lz > 0.0 else (-lz - (size.z * 0.5 + margin))
	return maxf(qx, qz)


## Signed distance to the shoreline (positive = in the sea).
static func sea_distance(x: float, z: float) -> float:
	var wobble := sin(x * 0.11) * 1.6 + sin(z * 0.07 + 1.3) * 1.2
	return (x + z - SHORE_SUM) * 0.7071 + wobble


## Distance (m) from p to the river centre line.
static func river_distance(p: Vector2) -> float:
	var best := INF
	for i in RIVER.size() - 1:
		var a: Vector2 = RIVER[i]
		var b: Vector2 = RIVER[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## v5a: buildings owned by a module type ("workplaces", "civic", ...).
static func buildings_of(module_type: String) -> Array:
	var out: Array = []
	for b in BUILDINGS:
		if str(b.get("module", "")) == module_type:
			out.append(b)
	return out


static func homes() -> Array:
	var out: Array = []
	for b in BUILDINGS:
		if str(b["kind"]) == "home":
			out.append(b)
	return out
