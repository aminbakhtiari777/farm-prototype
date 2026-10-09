class_name GasFlame
extends Node3D
## v6b "gas_stove" module: a ring of small blue gas-flame tongues with orange
## tips under the pan, flickering (vertex-colour cones, unshaded, alpha) and
## a soft blue-white light. Shown while cooking (CookingStation._heat).

var radius: float = 0.12
var _tongues: Array[MeshInstance3D] = []
var _t: float = 0.0
var _light: OmniLight3D
var lit: bool = false


func style() -> GasStoveStyle:
	return Modules.style("gas_stove") as GasStoveStyle


func _ready() -> void:
	var st := style()
	var n := st.tongues if st else 14
	var h := st.flame_height if st else 0.05
	var base_c: Color = st.flame_color if st else Color(0.25, 0.45, 1.0)
	var tip_c: Color = st.tip_color if st else Color(1.0, 0.7, 0.3)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cone := _cone_mesh(h, base_c, tip_c)
	for i in n:
		var a := TAU * float(i) / n
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(cos(a) * radius, 0.0, sin(a) * radius)
		mi.rotation = Vector3(sin(a) * 0.9, 0, -cos(a) * 0.9)   # licks out past the pan rim
		add_child(mi)
		_tongues.append(mi)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.55, 0.65, 1.0)
	_light.omni_range = 1.2
	_light.light_energy = 0.6
	_light.position = Vector3(0, 0.08, 0)
	add_child(_light)
	set_lit(false)


static func _cone_mesh(h: float, base_c: Color, tip_c: Color) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 0.018
	var seg := 6
	for i in seg:
		var a0 := TAU * float(i) / seg
		var a1 := TAU * float(i + 1) / seg
		st.set_color(Color(base_c, 0.9))
		st.add_vertex(Vector3(cos(a0) * r, 0, sin(a0) * r))
		st.set_color(Color(base_c, 0.9))
		st.add_vertex(Vector3(cos(a1) * r, 0, sin(a1) * r))
		st.set_color(Color(tip_c, 0.35))
		st.add_vertex(Vector3(0, h, 0))
	return st.commit()


func set_lit(on: bool) -> void:
	lit = on
	visible = on
	set_process(on)


func _process(delta: float) -> void:
	_t += delta
	for i in _tongues.size():
		var f := 0.75 + 0.35 * sin(_t * 23.0 + i * 1.7) + 0.15 * sin(_t * 41.0 + i * 0.6)
		_tongues[i].scale = Vector3(1.0, f, 1.0)
	_light.light_energy = 0.55 + 0.12 * sin(_t * 30.0)
