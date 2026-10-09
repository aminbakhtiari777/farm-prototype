class_name VoiceProfiles
extends RefCounted
## v7b "voice_profiles" module: each resident's voice (pitch, speaking rate,
## tone). VoiceBlips asks for the profile; Chatter uses the tone lines for
## varied Persian small talk. Without the module the v5b rules apply.


static func style() -> VoiceProfileStyle:
	return Modules.style("voice_profiles") as VoiceProfileStyle


static func of(r: Dictionary) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	return st.people.get(Population.full_name(r), {})


static func tone(r: Dictionary) -> String:
	var p := of(r)
	return str(p.get("tone", "warm")) if not p.is_empty() else "warm"


static func tone_info(r: Dictionary) -> Dictionary:
	var st := style()
	return st.tones.get(tone(r), {}) if st else {}


static func tone_name(r: Dictionary) -> String:
	var t := tone_info(r)
	return Lang.tt(str(t.get("fa", "")), str(t.get("en", ""))) if not t.is_empty() else ""


static func small_talk(r: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var st := style()
	if st == null:
		return {}
	var list: Array = st.tone_lines.get(tone(r), [])
	if list.is_empty():
		return {}
	var i := rng.randi() % list.size() if rng else randi() % list.size()
	return list[i]
