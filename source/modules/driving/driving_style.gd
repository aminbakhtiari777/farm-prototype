class_name DrivingStyle
extends AssetModule
## v7b deeper driving: gears (automatic or manual - 3 toggles, Shift / Ctrl
## shift up / down), headlights you switch with H (needed at night: the police
## fine driving without lights after dark), fuel use, wear from bumps, and a
## small dashboard (gear, speed, fuel, condition, lights) while driving.
## Consumers: CarSystems, DrivableCar hooks, DashboardHud.

@export var name_fa: String = ""
## top speed fraction per gear (1..n)
@export var gear_top: Array = []
## acceleration factor per gear
@export var gear_accel: Array = []
## automatic gearbox by default
@export var auto_default: bool = true
## % of the tank per km (0 = no fuel)
@export var fuel_per_km: float = 7.0
## % condition lost per crash above 4 m/s
@export var damage_per_hit: float = 6.0
## % warning
@export var low_fuel: float = 15.0
## lights needed from / until
@export var night_hours: Vector2 = Vector2(19.0, 6.0)
## driving after dark without headlights
@export var no_lights_fine: int = 30
## seconds before the fine
@export var no_lights_grace: float = 8.0
## m
@export var light_range: float = 18.0
@export var light_energy: float = 2.4
## how much darker it feels without lights (night vignette)
@export var dark_driving: float = 0.35
