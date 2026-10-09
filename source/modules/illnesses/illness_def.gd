class_name IllnessDef
extends AssetModule
## One illness state (collection "illnesses", v5b): how it slows you, how often
## you sneeze, how long it lasts and what the doctor charges. Consumers:
## Needs (player + NPCs), NeedsHud, the hospital doctor, Dialogue.

@export var name_fa: String = ""
@export var symptoms_en: String = ""
@export var symptoms_fa: String = ""
## Walking speed and stamina regeneration factors while ill.
@export var speed_mult: float = 0.75
@export var stamina_regen_mult: float = 0.6
## Seconds between sneezes (real time, random in range); 0 = none.
@export var sneeze_min: float = 9.0
@export var sneeze_max: float = 22.0
## Days until it passes on its own (if you eat and sleep).
@export var days: int = 3
## Doctor's fee in gold.
@export var fee: int = 80
## Picked when fatigue AND hunger are this bad (worst match wins).
@export var min_fatigue: float = 0.0
@export var max_hunger: float = 100.0
@export var severity: int = 1
@export var tint: Color = Color(0.7, 0.85, 0.7)
