class_name DialogueStyle
extends AssetModule
## What townspeople say (v5b), in Persian ("fa") and English ("en").
## Every text table is {"fa": [...], "en": [...]}. Consumers: Dialogue
## (scripts/npc/dialogue.gd - talk to a townsperson), NpcSocial (NPC <-> NPC
## chats + greetings in speech bubbles), NpcCard (Persian names / jobs).
##
## Placeholders: {name} (person), {player}, {rel} (relation), {place},
## {hour} (opening hour), {doctor}.

## Greetings by part of day: morning / noon / evening / night -> {fa, en}.
@export var greetings: Dictionary = {}
## NPC <-> NPC chat openers and replies.
@export var chat_lines: Dictionary = {}
@export var chat_replies: Dictionary = {}
## Greeting the farmer by name.
@export var player_greeting: Dictionary = {}
## Job keyword -> {"work": {fa, en}, "off": {fa, en}} (matched with contains()).
@export var job_lines: Dictionary = {}
## Fallback when no job keyword matches.
@export var generic_lines: Dictionary = {}
## About a family member: {fa, en} templates with {name} / {rel}.
@export var family_lines: Dictionary = {}
## Relation names: role -> {fa, en} (mother, father, son, ...).
@export var relations: Dictionary = {}
## Friendship level index -> {fa, en} (0 stranger .. 4 best friend).
@export var friendship_lines: Array = []
## Health: NPC is ill / the player looks ill / the player looks hungry or tired.
@export var ill_self: Dictionary = {}
@export var ill_player: Dictionary = {}
@export var hungry_player: Dictionary = {}
@export var tired_player: Dictionary = {}
## Shop closed (said by the shopkeeper) and late-night lines.
@export var closed_lines: Dictionary = {}
@export var night_lines: Dictionary = {}
## Sneeze sound-word.
@export var sneeze: Dictionary = {"fa": ["آپچی!"], "en": ["Achoo!"]}
## Persian names / surnames / jobs / places (English key -> Persian).
@export var names_fa: Dictionary = {}
@export var jobs_fa: Dictionary = {}
@export var places_fa: Dictionary = {}
## How many lines a talk shows (greeting + n).
@export var lines_per_talk: int = 3
