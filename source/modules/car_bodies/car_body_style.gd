class_name CarBodyStyle
extends AssetModule
## v7b.1 self-made procedural car bodies: opaque paint (no more pink Kenney
## colormap / alpha-red fire van), see-through glass, seats, dashboard with
## gauges, a steering wheel that turns with DrivableCar.steer_amount, side
## mirrors, grille, headlights, bumpers, hood lines, Persian number plates,
## and a glass sunroof the cockpit camera can hide. Liveries for police,
## ambulance, taxi and the fire truck. Consumer: CarBody via VehicleKit.model.

@export var name_fa: String = ""
@export var enabled: bool = true
## {en, fa, color}
@export var palette: Array = []
## model -> {form, length, width, height, ...}
@export var shapes: Dictionary = {}
## police / ambulance / taxi / firetruck
@export var liveries: Dictionary = {}
@export var glass_alpha: float = 0.32
@export var seat_color: Color = Color(0.22, 0.2, 0.19)
## steering wheel rotation at full lock
@export var wheel_turn_deg: float = 140.0
@export var sunroof: bool = true
## bake static parts into one mesh
@export var merge_static: bool = true
@export var plate_frame: bool = true
