class_name AmbulanceStyle
extends AssetModule
## v6b ambulance: parked at the hospital; when a townsperson falls ill the
## ambulance drives out with a two-person crew, they walk the patient in and
## bring them to the hospital (Needs). Consumer: AmbulanceService.

@export var name_fa: String = ""
@export var model: String = "ambulance"
@export var speed: float = 9.0
@export var crew: int = 2
## illness id -> chance (0..1)
@export var dispatch: Dictionary = {}
@export var crew_shirt: Color = Color(0.92, 0.94, 0.95)
@export var crew_pants: Color = Color(0.2, 0.3, 0.55)
@export var siren: bool = true
## parking spot
@export var base: Vector2 = Vector2(41.5, -53.9)
