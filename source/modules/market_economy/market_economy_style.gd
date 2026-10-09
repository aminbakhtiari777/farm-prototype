class_name MarketEconomyStyle
extends AssetModule
## v5c living economy rules (module "market_economy"): every traded good has a
## town-wide stock. Prices follow supply and demand:
##   price multiplier = clamp((target / stock) ^ elasticity, min_mult, max_mult)
## Selling adds stock (prices fall), buying / eating removes it (prices rise),
## producers restock every morning and outside trade pulls stock back toward
## the target by `recovery_per_day`. Consumers: Market autoload, Economy,
## Shops, ShopPanel, PricesPanel.

@export var elasticity: float = 0.6
@export var min_mult: float = 0.5
@export var max_mult: float = 2.5
## Fraction of the gap to the target stock closed by outside trade each day.
@export var recovery_per_day: float = 0.2
## Normal stock of a good with no producer (producers: output x buffer_days).
@export var default_target: int = 20
@export var buffer_days: float = 2.5
## Retail price of farm produce in shops = base sell price x markup.
@export var retail_markup: float = 1.6
## Units of stock added per unit the player sells.
@export var sell_impact: float = 1.0
## Price-history length (days) kept for the trends board.
@export var history_days: int = 7
## stock / target below this = shortage (red on the board).
@export var shortage_below: float = 0.25
## What townspeople buy for each meal: item id -> weight.
@export var npc_food_basket: Dictionary = {}
## Units of food one townsperson's meal takes from the stock (families share a pot).
@export var npc_meal_units: float = 0.25
## Daily exports (sold out of town): item id -> units per day. Keeps demand alive.
@export var exports: Dictionary = {}
## Persian item names for goods without their own name_fa.
@export var item_names_fa: Dictionary = {}
## Extra goods tracked even if their type is not auto-tracked.
@export var extra_tracked: PackedStringArray = PackedStringArray()
## Item types that are market goods (auto-tracked).
@export var tracked_types: PackedStringArray = PackedStringArray(["produce", "ingredient", "material", "food", "animal_product", "feed", "furniture"])
