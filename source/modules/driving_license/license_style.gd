class_name LicenseStyle
extends AssetModule
## v7b.1 driving licence: read the Persian rules booklet and pass a short quiz at
## the traffic desk in the police station. Buying a car needs the licence; driving
## any car without one is fined (once per day) and counts as an offence. At the
## 2nd offence the licence is confiscated for `confiscation_days` and the car is
## towed to the impound lot - it is released for a fee once you have your licence
## back (after the wait AND a passed re-test). Residents have licences unless
## theirs was taken. Consumers: LicenseOffice, LicensePanel, TrafficRules, Impound.

@export var name_fa: String = ""
## booklet pages: {title: {en, fa}, lines: [{en, fa}]}
@export var pages: Array = []
## {q: {en, fa}, options: [{en, fa}], answer}
@export var questions: Array = []
## questions per test
@export var quiz_count: int = 6
@export var pass_mark: int = 5
@export var test_fee: int = 25
@export var confiscation_days: int = 2
@export var impound_fee: int = 120
@export var residents_licensed: bool = true
## impound lot (west end of Main St, south side)
@export var impound_pos: Vector2 = Vector2(-69.0, -62.0)
@export var impound_yaw: float = 0.0
