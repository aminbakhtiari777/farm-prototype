class_name ChurchBuilder
extends RefCounted
## v5a church exterior (steep roof, bell tower with spire and cross,
## stained-glass windows) from ChurchStyle. Called by Building.


static func decorate(b: Building, roof: Node3D, ext: Node3D) -> void:
	var st := Modules.style("church") as ChurchStyle
	if st == null:
		return
	var w := b.size.x
	var d := b.size.z
	var top := Building.FOUNDATION_HEIGHT + b.size.y
	var glass := st.glass_colors
	var stone := ProceduralProp.color_material(st.wall_color.darkened(0.08), 0.9)
	# Bell tower on the front-left corner.
	var tw := 2.4
	var th := st.tower_height
	var tx := -w * 0.5 + tw * 0.5
	var tz := d * 0.5 - tw * 0.5
	b.add_box(Vector3(tw, th, tw), Vector3(tx, Building.FOUNDATION_HEIGHT + th * 0.5, tz), stone, Vector3.ZERO, roof)
	b.add_box_collider(Vector3(tw, th, tw), Vector3(tx, Building.FOUNDATION_HEIGHT + th * 0.5, tz))
	# Spire (prism).
	var spire_h := th * 0.55
	b.add_cylinder(0.0, tw * 0.78, spire_h, Vector3(tx, Building.FOUNDATION_HEIGHT + th + spire_h * 0.5, tz),
			ProceduralProp.color_material(st.spire_color, 0.7), Vector3(0, PI * 0.25, 0), 4, roof)
	# Belfry openings + the bell.
	for side in [-1.0, 1.0]:
		b.add_box(Vector3(0.9, 1.2, 0.06), Vector3(tx, Building.FOUNDATION_HEIGHT + th - 1.0, tz + side * (tw * 0.5 + 0.01)),
				ProceduralProp.color_material(Color(0.08, 0.07, 0.06), 0.9), Vector3.ZERO, roof)
	b.add_cylinder(0.12, 0.38, 0.5, Vector3(tx, Building.FOUNDATION_HEIGHT + th - 1.0, tz + tw * 0.5 + 0.05),
			ProceduralProp.color_material(Color(0.72, 0.55, 0.25), 0.35, false), Vector3.ZERO, 10, roof)
	# Cross on the tip.
	var cy := Building.FOUNDATION_HEIGHT + th + spire_h + 0.5
	b.add_box(Vector3(0.08, 1.1, 0.08), Vector3(tx, cy, tz), ProceduralProp.color_material(Color(0.85, 0.75, 0.3), 0.4, false), Vector3.ZERO, roof)
	b.add_box(Vector3(0.7, 0.08, 0.08), Vector3(tx, cy + 0.2, tz), ProceduralProp.color_material(Color(0.85, 0.75, 0.3), 0.4, false), Vector3.ZERO, roof)
	# Stained-glass windows on the long sides.
	for side in [-1.0, 1.0]:
		for j in 3:
			var z := -d * 0.35 + j * d * 0.35
			var gcol: Color = glass[j % glass.size()]
			b.add_box(Vector3(0.08, 1.6, 0.7), Vector3(side * (w * 0.5 + 0.01), Building.FOUNDATION_HEIGHT + 1.8, z),
					ProceduralProp.emissive_material(gcol, 0.4), Vector3.ZERO, ext)
	# Rose window above the door.
	# Stone frame, three rings of stained glass and stone mullions.
	var rc := Vector3(b.door_offset, Building.FOUNDATION_HEIGHT + b.size.y * 0.72, d * 0.5 + 0.01)
	var g0: Color = glass[0] if not glass.is_empty() else Color(0.6, 0.2, 0.3)
	var g1: Color = glass[1 % glass.size()] if not glass.is_empty() else Color(0.2, 0.4, 0.85)
	var g2: Color = glass[2 % glass.size()] if not glass.is_empty() else Color(0.95, 0.8, 0.25)
	var frame_mat := ProceduralProp.color_material(Color(0.62, 0.6, 0.56), 0.9, false)
	var rot := Vector3(PI * 0.5, 0, 0)
	b.add_cylinder(0.82, 0.82, 0.06, rc, frame_mat, rot, 24, ext)
	b.add_cylinder(0.7, 0.7, 0.08, rc + Vector3(0, 0, 0.01), ProceduralProp.emissive_material(g0.darkened(0.15), 0.35), rot, 24, ext)
	b.add_cylinder(0.46, 0.46, 0.08, rc + Vector3(0, 0, 0.02), ProceduralProp.emissive_material(g1, 0.35), rot, 20, ext)
	b.add_cylinder(0.2, 0.2, 0.08, rc + Vector3(0, 0, 0.03), ProceduralProp.emissive_material(g2, 0.45), rot, 16, ext)
	for k in 4:
		b.add_box(Vector3(1.4, 0.05, 0.05), rc + Vector3(0, 0, 0.07), frame_mat, Vector3(0, 0, k * PI * 0.25), ext)
