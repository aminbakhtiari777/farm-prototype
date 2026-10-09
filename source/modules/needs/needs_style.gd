class_name NeedsStyle
extends AssetModule
## Healthy-life needs (v5b) for the farmer AND every townsperson: hunger (eat
## at least one meal a day), fatigue (sleep) and the illness risk when both are
## neglected. Consumers: Needs autoload, NeedsHud, Player (speed), the doctor.

## Hunger 100 = full, 0 = starving. Points lost per game hour.
@export var hunger_per_hour: float = 4.0
## Fatigue 0 = rested, 100 = worn out. Points gained per awake game hour.
@export var fatigue_per_hour: float = 4.5
## Extra fatigue when stamina hits zero (exhausted).
@export var exhausted_fatigue: float = 6.0
## Below this hunger you are "hungry"; above this fatigue you are "tired".
@export var hungry_below: float = 30.0
@export var tired_above: float = 70.0
## Meals needed per day; skipping them adds fatigue + illness risk.
@export var meals_per_day: int = 1
@export var skipped_meal_fatigue: float = 20.0
## Illness chance per game hour when tired / hungry / both (0..1).
@export var ill_chance_tired: float = 0.05
@export var ill_chance_hungry: float = 0.05
@export var ill_chance_base: float = 0.0
## Townspeople: base chance per hour, meal hours, doctor visit length.
@export var npc_ill_chance: float = 0.004
@export var npc_meal_hours: PackedInt32Array = PackedInt32Array([7, 13, 20])
@export var npc_doctor_hours: float = 1.5
## Doctor fee multiplier (fees are per illness).
@export var fee_mult: float = 1.0
## Hunger at 0: walking speed factor.
@export var starving_speed: float = 0.85
