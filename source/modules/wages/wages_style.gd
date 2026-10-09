class_name WagesStyle
extends AssetModule
## v5c jobs and wages (module "wages"): every townsperson has a wallet. Jobs
## pay a daily wage at `payday_hour`; townspeople pay for their meals (food
## from the town stock at today's price) and for the doctor when ill.
## Consumers: Market (wallets, payday, spending), PricesPanel (town summary).

## lower-case job title -> gold per working day.
@export var wages: Dictionary = {}
@export var default_wage: int = 60
@export var payday_hour: int = 17
@export var start_savings: int = 200
## Children and students without a wage get pocket money.
@export var allowance: int = 10
## Days off: day of the week (0..6, from TimeManager.day % 7) when nobody is paid.
@export var day_off: int = 6
