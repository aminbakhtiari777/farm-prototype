class_name StreetLightingStyle
extends AssetModule
## v7b.1 a brighter town at night: extra street lights along every paved street
## (both sides), tall lights at intersections, a ring around the square, lights
## along paths / the park / market, shop-front sconces, warm light pools on the
## ground and a gentle night ambient lift. Cheap on the web: emissive lamps +
## additive ground pools everywhere, only `pool_lights` real OmniLights follow
## the camera. Consumer: StreetLighting (+ DayNightCycle night_lights group).

@export var name_fa: String = ""
## m between new lamps on each side
@export var spacing: float = 10.0
## real lights near the camera
@export var pool_lights: int = 10
@export var light_range: float = 11.0
## x DayNightCycle lamp energy
@export var light_energy: float = 1.15
@export var light_color: Color = Color(1.0, 0.78, 0.48)
## warm additive light pool under every lamp
@export var ground_pools: bool = true
@export var pool_radius: float = 4.2
@export var pool_alpha: float = 0.32
## minimum ambient light energy at full night
@export var night_ambient: float = 0.62
## night ambient colour (warmer than moonlight)
@export var ambient_tint: Color = Color(0.55, 0.5, 0.62)
## V2 extra lamp spots (paths, park, market, beach walk)
@export var extra_points: Array = []
## a lit sconce beside every shop / office door
@export var shop_sconces: bool = true
@export var intersection_lamps: bool = true
