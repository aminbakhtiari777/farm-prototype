class_name MechanicStyle
extends AssetModule
## v7b mechanic shop on Main St: repairs (cars wear with bumps and crashes),
## a fuel pump and simple upgrades (engine tune, sport tyres, LED headlights,
## eco injector). The mechanic's post is never empty: a stand-in covers.
## Consumers: MechanicShop, MechanicPanel, CarSystems.

@export var name_fa: String = ""
@export var pos: Vector2 = Vector2(56.0, -61.5)
## deg; open front faces +z (Main St)
@export var yaw: float = 0.0
@export var hours: Vector2 = Vector2(8.0, 19.0)
## gold per % of damage repaired
@export var repair_per_pct: float = 2.0
## gold per % of tank
@export var fuel_per_pct: float = 0.6
## {id, en, fa, cost, speed, accel, fuel, lights, grip}
@export var upgrades: Array = []
## preferred mechanics
@export var staff: PackedStringArray = PackedStringArray()
## greet, repaired, fueled, upgraded, standin, poor -> [{en, fa}]
@export var lines: Dictionary = {}
