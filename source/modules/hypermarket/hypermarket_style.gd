class_name HypermarketStyle
extends AssetModule
## v6a hypermarket: a big store (66, -62.5) selling kitchenware (and the
## supermarket's ingredients). Consumers: Hypermarket interior, Shops.

@export var name_fa: String = ""
@export var title: String = "Hypermarket"
@export var title_fa: String = "هایپرمارکت"
@export var greeting: String = "Everything for your kitchen!"
@export var greeting_fa: String = "هر چه آشپزخانه‌ات لازم دارد!"
@export var sells: Array = ["type:kitchenware", "sold_at:grocery"]
@export var buys: Array = ["category:fish", "category:crop", "eggs", "milk"]
@export var shelf_color: Color = Color(0.85, 0.86, 0.88)
@export var sign_color: Color = Color(0.1, 0.45, 0.75)
