class_name ToolDef
extends AssetModule
## One farm tool (collection type "tool_types": every registered tool is in
## the game). A tool has its own hand prop, animation and sound, an upgrade
## tier and unlock rules. GameData turns it into a shop/inventory item;
## ToolAnimator (scripts/player/tool_animator.gd) plays it.

const KINDS := ["hoe", "watering_can", "seeds", "hands", "hammer", "axe"]
const ANIMS := ["swing", "pour", "sow", "pick", "hammer"]
const SHAPES := ["blade", "can", "pouch", "basket", "hammer", "axe"]

@export var item_id: String = ""
## What the tool is used for (the action that triggers it).
@export_enum("hoe", "watering_can", "seeds", "hands", "hammer", "axe") var kind: String = "hoe"
## Higher tier wins when the player owns several tools of a kind.
@export var tier: int = 1
@export_enum("swing", "pour", "sow", "pick", "hammer") var anim: String = "swing"
@export var sound: String = "hoe_dig"
@export_enum("blade", "can", "pouch", "basket", "hammer", "axe") var shape: String = "blade"
@export var head_color: Color = Color(0.55, 0.56, 0.6)
@export var handle_color: Color = Color(0.5, 0.34, 0.2)
## 0 = not sold (starter tool or always available).
@export var buy: int = 0
## Starter tools are always usable, even without an inventory item.
@export var starter: bool = false
## Unlock: sold from this day on, and only to owners of `requires`.
@export var unlock_day: int = 1
@export var requires: String = ""
## Effect: garden cells worked per use (hoe tills N cells, can waters NxN).
@export var reach: int = 1
@export var anim_seconds: float = 0.8


func to_items() -> Dictionary:
	var it := {"name": display_name, "type": "tool", "tool_kind": kind, "tier": tier, "description": description,
		"unlock_day": unlock_day, "requires": requires}
	if buy > 0:
		it["buy"] = buy
	return {item_id: it}


func validate() -> PackedStringArray:
	var out := PackedStringArray()
	if item_id == "":
		out.append("%s: item_id missing" % id)
	if kind not in KINDS:
		out.append("%s: unknown kind %s" % [id, kind])
	if anim not in ANIMS:
		out.append("%s: unknown anim %s" % [id, anim])
	if not Sfx.SOUNDS.has(StringName(sound)):
		out.append("%s: sound %s not registered in Sfx" % [id, sound])
	return out
