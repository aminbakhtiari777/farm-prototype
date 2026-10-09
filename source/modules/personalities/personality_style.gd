class_name PersonalityStyle
extends AssetModule
## v7b personalities: every resident has a character - calm, hot-tempered,
## generous, stingy, cheerful or shy. It changes how arguments go (who
## escalates, how fast the police are needed, what they say) and how they
## haggle when trading with you (key 7 next to someone) or with each other.
## Consumers: Personalities, Conflicts, HagglePanel, Chatter, Passengers.

@export var name_fa: String = ""
## id -> {en, fa, temper, haggle, generosity, patience, argue, reply, accept, refuse, counter}
@export var traits: Dictionary = {}
## full name -> trait id
@export var people: Dictionary = {}
@export var default_trait: String = "cheerful"
