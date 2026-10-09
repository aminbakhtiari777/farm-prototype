class_name VoiceProfileStyle
extends AssetModule
## v7b distinct voices: each resident has a voice profile - pitch, speaking
## rate and tone (warm, bright, gruff, soft, lively, slow) - used by the voice
## blips, plus more varied Persian lines per tone for their small talk.
## Consumers: VoiceBlips (pitch/rate/tone), Chatter (tone lines).

@export var name_fa: String = ""
## full name -> {pitch, rate, tone}
@export var people: Dictionary = {}
## tone -> {en, fa, volume_db, jitter}
@export var tones: Dictionary = {}
## tone -> [{en, fa}]
@export var tone_lines: Dictionary = {}
