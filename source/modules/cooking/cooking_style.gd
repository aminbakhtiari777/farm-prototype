class_name CookingStyle
extends AssetModule
## Hands-on cooking actions at the home kitchen (v5b). `steps` is the ordered
## list of actions; each is {id, en, fa, minutes, sound, stamina}. Known ids:
## prepare (wash + chop: uses the main ingredients), salt, spices, cook, eat.
## Consumers: Cooking, CookingPanel, CookingStation.

@export var steps: Array = []
## Seasoning added automatically when the style has no salt / spices step.
@export var auto_season: bool = false
## Taste bonus (extra hunger) when seasoned by hand.
@export var seasoned_bonus: float = 10.0
