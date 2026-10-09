class_name CityFundStyle
extends AssetModule
## v7a municipality fund: every fine (theft, fire, damages, speeding) goes into
## the city fund, shown at City Hall and on the market prices board. The fund
## pays the doctor subsidy and public works that change the town over days -
## new benches, streetlights, flower beds, a small park. City Hall panel (F4 /
## the notice board at City Hall) shows income, spending and projects.
## Consumer: CityFund (CityState autoload).

@export var name_fa: String = ""
@export var start_balance: int = 500
## {id, en, fa, cost, days, kind, pos: [V2...]}
@export var projects: Array = []
## share of a doctor's fee the fund pays
@export var doctor_subsidy: float = 0.3
## per visit
@export var subsidy_cap: int = 60
## small daily income from shops
@export var daily_tax: int = 40
@export var speeding_fine: int = 50
## m/s
@export var speed_limit: float = 12.0
