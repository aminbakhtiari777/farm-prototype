class_name HouseColors
extends RefCounted
## v6b "house_colors" module: every home's walls take the owning family's
## colour (a stable pick from the palette per family surname), so a house
## reads as "the Karimi house" from the street. The farmhouse uses the
## player's colour. Applied after the house style in Building._apply_layout.


static func style() -> HouseColorsStyle:
	return Modules.style("house_colors") as HouseColorsStyle


static func family_color(owner: String) -> Color:
	var st := style()
	if st == null or st.palette.is_empty() or owner == "":
		return Color(0, 0, 0, 0)
	return st.palette[absi(hash(owner)) % st.palette.size()]


## Final wall colour for a building (unchanged when the module is off or the
## building is not a home).
static func wall_for(b: Building, base: Color) -> Color:
	var st := style()
	if st == null or b == null:
		return base
	if b.layout_id == "farmhouse":
		return base.lerp(st.farmhouse_color, st.strength)
	if b.kind != "home" or b.owner_name == "":
		return base
	return base.lerp(family_color(b.owner_name), st.strength)
