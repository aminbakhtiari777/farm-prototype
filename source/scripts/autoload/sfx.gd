extends Node
## Tiny sound-effect helper (autoload "Sfx"): Sfx.play(&"splash") for UI/2D
## sounds, Sfx.play_at(&"splash", position) for positional one-shots.

const SOUNDS := {
	&"splash": "res://assets/audio/sfx/splash.ogg",
	&"plop": "res://assets/audio/sfx/plop.ogg",
	&"reel": "res://assets/audio/sfx/reel.ogg",
	&"pickup": "res://assets/audio/sfx/pickup.ogg",
	&"door": "res://assets/audio/sfx/door_creak.ogg",
	&"land": "res://assets/audio/sfx/land.ogg",
	# v4 (tools + electricity), synthesized by tools/synth_audio_v4.py
	&"switch": "res://assets/audio/sfx/switch.ogg",
	&"hoe_dig": "res://assets/audio/sfx/hoe_dig.ogg",
	&"water_pour": "res://assets/audio/sfx/water_pour.ogg",
	&"seeds": "res://assets/audio/sfx/seeds.ogg",
	&"harvest": "res://assets/audio/sfx/harvest.ogg",
	&"hammer": "res://assets/audio/sfx/hammer.ogg",
	# v5b (sneeze + hands-on cooking), synthesized by tools/synth_audio_v5b.py
	&"sneeze": "res://assets/audio/sfx/sneeze.ogg",
	&"chop": "res://assets/audio/sfx/chop.ogg",
	&"sprinkle": "res://assets/audio/sfx/sprinkle.ogg",
	&"sizzle": "res://assets/audio/sfx/sizzle.ogg",
	&"eat": "res://assets/audio/sfx/eat.ogg",
}
var _cache: Dictionary = {}


func stream(id: StringName) -> AudioStream:
	if not _cache.has(id):
		_cache[id] = load(SOUNDS[id]) if SOUNDS.has(id) and ResourceLoader.exists(SOUNDS[id]) else null
	return _cache[id]


func play(id: StringName, volume_db: float = -6.0, pitch: float = 1.0) -> void:
	var s := stream(id)
	if s == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.bus = &"Master"
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func play_at(id: StringName, pos: Vector3, volume_db: float = -4.0, pitch: float = 1.0) -> void:
	var s := stream(id)
	var scene := get_tree().current_scene
	if s == null or scene == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch * randf_range(0.94, 1.06)
	p.unit_size = 4.0
	p.max_distance = 35.0
	scene.add_child(p)
	p.global_position = pos
	p.finished.connect(p.queue_free)
	p.play()
