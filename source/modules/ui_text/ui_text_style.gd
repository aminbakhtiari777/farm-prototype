class_name UiTextStyle
extends AssetModule
## v6a UI translation table (English -> Persian) used by Lang.loc() / Lang.t()
## for prompts, the top bar and Settings. Swap to change wording.

@export var name_fa: String = ""
## exact English phrase -> Persian.
@export var phrases: Dictionary = {}
## "prefix " -> Persian template with {x} for the rest ("sit on the " -> "نشستن روی {x}").
@export var prefixes: Dictionary = {}
## English word -> Persian word for {x} substitutions (bench -> نیمکت).
@export var words: Dictionary = {}
