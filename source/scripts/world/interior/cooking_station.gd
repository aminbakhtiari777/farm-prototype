class_name CookingStation
extends Node3D
## v5b visuals for hands-on cooking on a home stove (child of the stove's
## InteriorItem). Stages follow the cooking module's actions:
##   ready   - the dish's ingredients lie on the cutting board
##   prepare - chopped pieces in the pan
##   salt    - white salt specks (+ sprinkle burst)
##   spices  - orange spice specks (+ burst)
##   cook    - burner glow, steam, food browns
##   eat     - served on a plate, pan empty
## Built from simple meshes (no assets) so it works in every kitchen style.

var stage: String = "idle"
var dish: DishDef
var _pan_pos: Vector3
var _board_pos: Vector3
var _food: MeshInstance3D
var _food_mat: StandardMaterial3D
var _board_items: Node3D
var _pan_bits: Node3D
var _specks: Node3D
var _plate: Node3D
var _burner: MeshInstance3D
var _light: OmniLight3D
var _steam: CPUParticles3D
var _burst: CPUParticles3D
var _cook_t: float = 0.0
## v6b gas_stove: blue flame ring under the pan (null on electric/wood hobs).
var gas: GasFlame


static func for_stove(stove: Node3D) -> CookingStation:
	var cs := stove.get_node_or_null(^"CookingStation") as CookingStation
	if cs == null:
		cs = CookingStation.new()
		cs.name = "CookingStation"
		var ip: Vector3 = stove.position
		var pan: Vector3 = stove.get_meta(&"pan_pos", ip + Vector3(-0.18, 0.93, -0.44))
		var board: Vector3 = stove.get_meta(&"board_pos", ip + Vector3(-1.0, 0.95, -0.55))
		cs._pan_pos = pan - ip
		cs._board_pos = board - ip
		stove.add_child(cs)
	return cs


static func _mat(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m


func _mesh(mesh: Mesh, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent else self).add_child(mi)
	return mi


func _cyl(r: float, h: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r * 0.92
	c.height = h
	c.radial_segments = 20
	c.rings = 1
	return _mesh(c, pos, mat, parent)


func _ready() -> void:
	# Pan + handle, cutting board.
	_cyl(0.15, 0.035, _pan_pos + Vector3(0, 0.02, 0), _mat(Color(0.12, 0.12, 0.13), 0.35, 0.6))
	var handle := BoxMesh.new()
	handle.size = Vector3(0.26, 0.02, 0.035)
	_mesh(handle, _pan_pos + Vector3(-0.27, 0.035, 0.0), _mat(Color(0.15, 0.1, 0.07), 0.7))
	var board := BoxMesh.new()
	board.size = Vector3(0.46, 0.025, 0.3)
	_mesh(board, _board_pos + Vector3(0, 0.0125, 0), _mat(Color(0.72, 0.52, 0.32), 0.8))
	var ring := TorusMesh.new()
	ring.inner_radius = 0.08
	ring.outer_radius = 0.13
	_burner = _mesh(ring, _pan_pos + Vector3(0, -0.005, 0), _mat(Color(1.0, 0.4, 0.1)))
	var bm := _burner.material_override as StandardMaterial3D
	bm.emission_enabled = true
	bm.emission = Color(1.0, 0.35, 0.08)
	bm.emission_energy_multiplier = 2.5
	_burner.visible = false
	_food_mat = _mat(Color(0.9, 0.8, 0.6), 0.7)
	var disc := CylinderMesh.new()
	disc.top_radius = 0.12
	disc.bottom_radius = 0.125
	disc.height = 0.02
	disc.radial_segments = 20
	_food = _mesh(disc, _pan_pos + Vector3(0, 0.045, 0), _food_mat)
	_food.visible = false
	_board_items = Node3D.new()
	add_child(_board_items)
	_pan_bits = Node3D.new()
	add_child(_pan_bits)
	_specks = Node3D.new()
	add_child(_specks)
	_plate = Node3D.new()
	_plate.visible = false
	add_child(_plate)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.55, 0.25)
	_light.omni_range = 1.6
	_light.light_energy = 0.0
	_light.position = _pan_pos + Vector3(0, 0.25, 0.1)
	_light.visible = false
	add_child(_light)
	_steam = CPUParticles3D.new()
	_steam.amount = 24
	_steam.lifetime = 1.6
	_steam.emitting = false
	_steam.position = _pan_pos + Vector3(0, 0.08, 0)
	_steam.direction = Vector3.UP
	_steam.spread = 18.0
	_steam.gravity = Vector3(0, 0.25, 0)
	_steam.initial_velocity_min = 0.12
	_steam.initial_velocity_max = 0.25
	_steam.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_steam.emission_sphere_radius = 0.08
	_steam.scale_amount_min = 0.6
	_steam.scale_amount_max = 1.4
	var sq := QuadMesh.new()
	sq.size = Vector2(0.09, 0.09)
	var sm := StandardMaterial3D.new()
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.albedo_color = Color(1, 1, 1, 0.35)
	sm.vertex_color_use_as_albedo = true
	sq.material = sm
	_steam.mesh = sq
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.55))
	grad.set_color(1, Color(1, 1, 1, 0.0))
	_steam.color_ramp = grad
	add_child(_steam)
	_burst = CPUParticles3D.new()
	_burst.amount = 30
	_burst.lifetime = 0.7
	_burst.one_shot = true
	_burst.explosiveness = 0.8
	_burst.emitting = false
	_burst.position = _pan_pos + Vector3(0, 0.35, 0)
	_burst.direction = Vector3.DOWN
	_burst.spread = 15.0
	_burst.initial_velocity_min = 0.2
	_burst.initial_velocity_max = 0.5
	_burst.gravity = Vector3(0, -3.0, 0)
	var bq := SphereMesh.new()
	bq.radius = 0.006
	bq.height = 0.012
	bq.radial_segments = 4
	bq.rings = 2
	_burst.mesh = bq
	add_child(_burst)
	set_process(false)


func _clear(n: Node3D) -> void:
	for c in n.get_children():
		c.queue_free()


## Shows the stage for `d` (dish). Stages accumulate visuals like real cooking.
func set_stage(new_stage: String, d: DishDef = null) -> void:
	if d:
		dish = d
	stage = new_stage
	match new_stage:
		"idle":
			_clear(_board_items)
			_clear(_pan_bits)
			_clear(_specks)
			_food.visible = false
			_plate.visible = false
			_heat(false)
		"ready":
			_clear(_pan_bits)
			_clear(_specks)
			_food.visible = false
			_plate.visible = false
			_heat(false)
			_show_board_ingredients()
		"prepare":
			_clear(_board_items)
			_food.visible = true
			_food_mat.albedo_color = dish.raw_color if dish else Color(0.9, 0.8, 0.6)
			_show_pan_bits()
		"salt":
			_sprinkle(Color(0.98, 0.98, 1.0), 26)
		"spices":
			_sprinkle(Color(0.9, 0.55, 0.12), 30)
		"cook":
			_heat(true)
			_cook_t = 0.0
			set_process(true)
		"eat":
			_heat(false)
			_serve()


func _heat(on: bool) -> void:
	if gas == null and get_parent() and get_parent().get_meta(&"gas", false) and Modules.style("gas_stove") != null:
		gas = GasFlame.new()
		gas.name = "GasFlame"
		gas.position = _pan_pos + Vector3(0, -0.02, 0)
		add_child(gas)
	if gas:
		gas.set_lit(on)
	_burner.visible = on and gas == null
	_light.visible = on
	_light.light_energy = (0.9 if gas else 1.3) if on else 0.0
	if gas and on:
		_light.light_color = Color(0.75, 0.7, 1.0)
	_steam.emitting = on


func _process(delta: float) -> void:
	_cook_t += delta
	var t := clampf(_cook_t / 2.5, 0.0, 1.0)
	if dish:
		_food_mat.albedo_color = dish.raw_color.lerp(dish.cooked_color, t)
		for b in _pan_bits.get_children():
			var mi := b as MeshInstance3D
			if mi and mi.material_override is StandardMaterial3D:
				var m := mi.material_override as StandardMaterial3D
				if m.has_meta(&"raw"):
					m.albedo_color = (m.get_meta(&"raw") as Color).lerp((m.get_meta(&"raw") as Color).darkened(0.35), t)
	_light.light_energy = 1.2 + 0.25 * sin(_cook_t * 14.0)
	if t >= 1.0 and stage != "cook":
		set_process(false)


func _ingredient_mesh(ing: IngredientDef, scale_f: float) -> Mesh:
	match ing.shape if ing else "veg":
		"egg":
			var s := SphereMesh.new()
			s.radius = 0.025 * scale_f
			s.height = 0.065 * scale_f
			return s
		"drumstick":
			var c := CapsuleMesh.new()
			c.radius = 0.03 * scale_f
			c.height = 0.13 * scale_f
			return c
		"leaf":
			var b := BoxMesh.new()
			b.size = Vector3(0.09, 0.012, 0.05) * scale_f
			return b
		"grain":
			var g := SphereMesh.new()
			g.radius = 0.05 * scale_f
			g.height = 0.04 * scale_f
			return g
	var v := SphereMesh.new()
	v.radius = 0.035 * scale_f
	v.height = 0.065 * scale_f
	return v


func _show_board_ingredients() -> void:
	_clear(_board_items)
	if dish == null:
		return
	var i := 0
	for k in dish.inputs:
		var ing := Cooking.ingredient(str(k))
		for n in mini(int(dish.inputs[k]), 2):
			var p := _board_pos + Vector3(-0.15 + (i % 4) * 0.1, 0.05, -0.07 + (i / 4) * 0.12 + n * 0.02)
			var mi := _mesh(_ingredient_mesh(ing, 1.0), p, _mat(ing.color if ing else Color.WHITE, 0.5), _board_items)
			if ing and ing.shape == "drumstick":
				mi.rotation = Vector3(0, 0, PI * 0.5)
			i += 1


func _show_pan_bits() -> void:
	_clear(_pan_bits)
	if dish == null:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(dish.id)
	for k in dish.inputs:
		var ing := Cooking.ingredient(str(k))
		var count := 7 if ing and ing.shape != "egg" else 0
		for n in count:
			var a := rng.randf() * TAU
			var r := rng.randf_range(0.0, 0.1)
			var b := BoxMesh.new()
			var sz := rng.randf_range(0.018, 0.03)
			b.size = Vector3(sz, sz * 0.6, sz)
			var m := _mat(ing.color, 0.6)
			m.set_meta(&"raw", ing.color)
			var mi := _mesh(b, _pan_pos + Vector3(cos(a) * r, 0.06, sin(a) * r), m, _pan_bits)
			mi.rotation.y = rng.randf() * TAU


func _sprinkle(c: Color, count: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([stage, count])
	for n in count:
		var a := rng.randf() * TAU
		var r := rng.randf_range(0.0, 0.11)
		var s := SphereMesh.new()
		s.radius = 0.0045
		s.height = 0.006
		s.radial_segments = 4
		s.rings = 2
		var m := _mat(c, 0.5)
		if c.r > 0.95 and c.g > 0.95:
			m.emission_enabled = true
			m.emission = Color(0.4, 0.4, 0.42)
		_mesh(s, _pan_pos + Vector3(cos(a) * r, 0.058, sin(a) * r), m, _specks)
	var bm := StandardMaterial3D.new()
	bm.albedo_color = c
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	(_burst.mesh as SphereMesh).material = bm
	_burst.restart()
	_burst.emitting = true


func _serve() -> void:
	_food.visible = false
	_clear(_pan_bits)
	_clear(_specks)
	_clear(_plate)
	_plate.visible = true
	var plate_pos := _board_pos + Vector3(0, 0.03, 0)
	_cyl(0.13, 0.015, plate_pos, _mat(Color(0.96, 0.96, 0.94), 0.25), _plate)
	var food := _cyl(0.09, 0.03, plate_pos + Vector3(0, 0.02, 0), _mat(dish.cooked_color if dish else Color(0.8, 0.6, 0.3), 0.7), _plate)
	food.scale = Vector3(1, 1, 1)
	if dish and dish.inputs.has("rice"):
		var rice := SphereMesh.new()
		rice.radius = 0.06
		rice.height = 0.05
		_mesh(rice, plate_pos + Vector3(0.04, 0.04, 0), _mat(Color(0.98, 0.95, 0.85), 0.8), _plate)
		var saf := SphereMesh.new()
		saf.radius = 0.025
		saf.height = 0.02
		_mesh(saf, plate_pos + Vector3(0.04, 0.07, 0), _mat(Color(0.95, 0.65, 0.1), 0.8), _plate)
	# Spoon.
	var sp := BoxMesh.new()
	sp.size = Vector3(0.12, 0.006, 0.016)
	_mesh(sp, plate_pos + Vector3(-0.02, 0.02, 0.1), _mat(Color(0.8, 0.8, 0.82), 0.3, 0.8), _plate)
