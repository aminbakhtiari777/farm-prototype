class_name ShopHoursStyle
extends AssetModule
## Opening hours of shops, stalls and offices (v5b). Counters refuse service
## while closed and the NPC card shows "Open" / "Closed - opens 08:00".
## Consumers: ShopHours (InteriorItem counters, MarketStall, NpcCard, Dialogue).

## building / shop id -> [open_hour, close_hour] (24 h; close < open = past midnight).
@export var hours: Dictionary = {}
## Used for any shop id not listed.
@export var default_hours: Array = [8.0, 18.0]
## Ids that never close (hospital emergency desk, ...).
@export var always_open: PackedStringArray = PackedStringArray()
