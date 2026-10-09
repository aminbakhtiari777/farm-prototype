class_name BackstoryStyle
extends AssetModule
## v7a townspeople backstories: every resident has talents, a current problem
## and a past hardship (kept gentle), plus how they speak about their spouse /
## family and their job. With WorldMemory (what they remember about you) this
## shapes their dialogue and the backstory part of the NPC card.
## Consumers: Backstories, Dialogue.talk_lines, NpcCard.

@export var name_fa: String = ""
## full name -> {talents_en, talents_fa, problem_en, problem_fa, past_en, past_fa, hope_en, hope_fa}
@export var people: Dictionary = {}
## remembered events mentioned per talk
@export var memory_lines: int = 1
## chance a talk mentions their problem / past / hope
@export var story_chance: float = 0.5
@export var show_on_card: bool = true
