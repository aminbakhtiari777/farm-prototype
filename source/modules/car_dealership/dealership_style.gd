class_name DealershipStyle
extends AssetModule
## v7b.1 car dealership (the v6b 'later' note): a small lot by the road out of
## town with a few cars and prices. Buying needs a driving licence and the money;
## the car is yours (saved), parked at the lot and remembered where you leave it.
## Consumers: Dealership, DealershipPanel.

@export var name_fa: String = ""
## lot centre
@export var pos: Vector2 = Vector2(76.0, -63.5)
@export var yaw: float = 0.0
@export var size: Vector2 = Vector2(7.4, 11.0)
## {en, fa}
@export var name: Dictionary = {}
## {id, model, en, fa, price, color, top_kmh}
@export var cars: Array = []
@export var requires_license: bool = true
