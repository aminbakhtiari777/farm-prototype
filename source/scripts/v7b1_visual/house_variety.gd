class_name HouseVariety
extends RefCounted
## v7b.1 "house_variety" module: tint walls / roofs / shutters and toggle porch,
## timber and tall windows so neighbouring homes look different. Deterministic
## per building id; applied on top of the buildings / house_colors modules.

static func style() -> HouseVarietyStyle:
	return Modules.style("house_variety") as HouseVarietyStyle


static func apply(b: Building, layout: Dictionary) -> void:
	var st := style()
	if st == null or not st.enabled or b == null or b.kind != "home":
		return
	var id := str(layout.get("id", b.layout_id))
	var h := absi(hash(id + "#v7b1house"))
	if not st.wall_tints.is_empty():
		b.wall_color = (b.wall_color as Color) * (st.wall_tints[h % st.wall_tints.size()] as Color)
	if not st.roof_tints.is_empty():
		b.roof_color = (b.roof_color as Color).lerp(st.roof_tints[(h / 7) % st.roof_tints.size()] as Color, 0.8)
	if not st.shutter_palette.is_empty():
		b.shutter_color = st.shutter_palette[(h / 13) % st.shutter_palette.size()]
	# Honour the layout's own porch / timber / tall when set; otherwise roll.
	if not layout.has("porch"):
		b.has_porch = float(h % 1000) / 1000.0 < st.porch_chance
	if not layout.has("timber"):
		b.timber_frame = float((h / 3) % 1000) / 1000.0 < st.timber_chance
	if not layout.has("tall"):
		b.upper_windows = float((h / 11) % 1000) / 1000.0 < st.tall_chance
