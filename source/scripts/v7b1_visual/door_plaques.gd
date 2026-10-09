class_name DoorPlaques
extends RefCounted
## v7b.1 "door_plaques" module: home roofs no longer carry the big "The X
## Family" board; a small plaque by the front door reads e.g. "خانواده آقای
## احمدی" (or "The Ahmadi Family" in English). The address plaque stays.
## The player's farmhouse is highlighted on the minimap (and any MapPanel that
## exists) in the module's home colour.

static func style() -> DoorPlaqueStyle:
	return Modules.style("door_plaques") as DoorPlaqueStyle


## True when this home should NOT put a family board on the roof.
static func hide_roof_sign(b: Building) -> bool:
	var st := style()
	return st != null and st.enabled and st.hide_home_roof_signs and b != null and b.kind == "home"


## Text for the door plaque (empty when the module is off or the house has no family).
static func text_for(b: Building) -> String:
	var st := style()
	if st == null or not st.enabled or b == null or b.kind != "home":
		return ""
	var fam := b.owner_name
	if fam == "":
		return ""
	var d := Dialogue.style()
	var sur_fa := str(d.names_fa.get(fam, fam)) if d else fam
	# Prefer "آقای" when the household has a father / husband; "خانم" for female-led homes.
	var headed_by_woman := false
	for r: Dictionary in Population.households().get(b.layout_id, []):
		var role := str(r.get("role", ""))
		if role in ["father", "husband"]:
			headed_by_woman = false
			break
		if role in ["mother", "wife", "single"] and str(r.get("gender", "")) == "female":
			headed_by_woman = true
	if Lang.is_fa():
		return (st.formula_fa_f if headed_by_woman else st.formula_fa).replace("{surname}", sur_fa)
	return st.formula_en.replace("{surname}", fam)


## Attach (or refresh) the family plaque on a Building. Called from building.gd
## after the address plaque, and again when the language changes.
static func attach(b: Building, parent: Node3D) -> void:
	if b == null:
		return
	var old := b.get_node_or_null(^"FamilyPlaque")
	if old:
		old.queue_free()
	var st := style()
	if st == null or not st.enabled:
		return
	var text := text_for(b)
	if text == "":
		return
	var holder := Node3D.new()
	holder.name = "FamilyPlaque"
	holder.add_to_group(&"family_plaques")
	holder.set_meta(&"building", b.layout_id)
	b.add_child(holder)
	# Right of the door, just under the address plaque (the lantern is on the
	# left, porch roofs / upper windows are above the door).
	var x := b.door_offset + Building.DOOR_W * 0.5 + 0.55
	var y := Building.FOUNDATION_HEIGHT + (1.75 - 0.36 if is_instance_valid(b.address_label) else 1.75)
	var z := b.size.z * 0.5 + 0.03
	var wood := StandardMaterial3D.new()
	wood.albedo_color = st.plaque_color
	wood.roughness = 0.7
	var board := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(st.plaque_w, st.plaque_h, 0.04)
	board.mesh = box
	board.position = Vector3(x, y, z)
	board.material_override = wood
	holder.add_child(board)
	var rim := StandardMaterial3D.new()
	rim.albedo_color = Color(0.75, 0.62, 0.32)
	rim.roughness = 0.45
	for sx in [-1.0, 1.0]:
		var edge := MeshInstance3D.new()
		var eb := BoxMesh.new()
		eb.size = Vector3(0.03, st.plaque_h + 0.04, 0.05)
		edge.mesh = eb
		edge.position = Vector3(x + sx * st.plaque_w * 0.5, y, z)
		edge.material_override = rim
		holder.add_child(edge)
	var lab := Label3D.new()
	Lang.setup_label3d(lab, st.font_size)
	lab.name = "FamilyPlaqueLabel"
	lab.text = text
	lab.modulate = Color(0.98, 0.94, 0.82)
	lab.outline_size = 6
	lab.pixel_size = minf(0.004, (st.plaque_w - 0.12) / maxf(float(text.length()) * st.font_size * 0.55, 1.0))
	lab.position = Vector3(x, y, z + 0.03)
	lab.add_to_group(&"family_plaques")
	lab.set_meta(&"building", b.layout_id)
	holder.add_child(lab)


## Re-label every family plaque (language switch).
static func refresh(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group(&"buildings"):
		var b := n as Building
		if b == null:
			continue
		var lab := b.find_child("FamilyPlaqueLabel", true, false) as Label3D
		if lab:
			lab.text = text_for(b)


## Colour the player's home on the minimap (and any MapPanel). Returns the
## colour, or Color.TRANSPARENT when the module is off.
static func home_color() -> Color:
	var st := style()
	if st == null or not st.enabled:
		return Color(0, 0, 0, 0)
	return st.home_marker_color


## Farmhouse layout id (the player's home).
static func player_home_id() -> String:
	return "farmhouse"
