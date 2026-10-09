class_name BoatStyle
extends AssetModule
## v6a boats moored at the pier: board one (E) and it sails you out to the deep
## sea; fish from the deck; take the helm (E) to sail back. A small fuel fee.
## Consumers: Boats (scripts/v6a/boats.gd).

@export var name_fa: String = ""
@export var count: int = 3
@export var hull_colors: Array = [Color(0.85, 0.85, 0.82), Color(0.2, 0.45, 0.7), Color(0.75, 0.25, 0.2)]
@export var cabin: bool = true
@export var sail_seconds: float = 6.0
@export var fuel_fee: int = 20
## Deep-sea anchor spots (x, z) - one per boat.
@export var spots: Array = [Vector2(84.0, 36.0), Vector2(92.0, 22.0), Vector2(78.0, 50.0)]
