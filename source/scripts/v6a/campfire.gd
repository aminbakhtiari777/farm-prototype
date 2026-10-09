class_name BeachCampfire
extends Node3D
## v6a "campfire" module: a stone-ring campfire on the beach by the pier.
## E: light it with firewood (from dry trees), add more, or grill a fish from
## your bag and eat it. Log seats around it; sitting by the lit fire restores
## stamina faster. Townspeople light it most evenings.

const CENTER := Vector2(41.0, 13.0)

var spot: ActionSpot
var seats: Array[Seat] = []
var _fire: Node3D
var _light: OmniLight3D
var _flames: CPUParticles3D
var _smoke: CPUParticles3D
var _audio: AudioStreamPlayer3D
var _t: float = 0.0
var _evening_day: int = -1


func _ready() -> void:
	add_to_group(&"campfire")
	Modules.on_swap("campfire", self, func(_m: AssetModule) -> void: rebuild())
	Lifestyle.campfire_changed.connect(func(_lit: bool) -> void: _sync())
	rebuild()


func style() -> CampfireStyle:
	return Modules.style("campfire") as CampfireStyle


func ground() -> Vector3:
	return Vector3(CENTER.x, Terrain.height_at(CENTER.x, CENTER.y), CENTER.y)


func rebuild() -> void:
	for c in get_children():
		c.queue_free()
	seats.clear()
	var st := style()
	if st == null:
		return
	position = ground()
	var big := st.id == "big_bonfire"
	var ring := 0.75 if not big else 1.05
	# Stones (one merged mesh) + logs.
	var stones := SurfaceTool.new()
	stones.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sph := SphereMesh.new()
	sph.radius = 0.16
	sph.height = 0.22
	sph.radial_segments = 7
	sph.rings = 4
	var n := 10 if not big else 14
	for i in n:
		var a := TAU * i / n
		stones.append_from(sph, 0, Transform3D(Basis(Vector3.UP, a).scaled(Vector3(1.0 + 0.2 * (i % 3), 0.8, 1.0)), Vector3(cos(a) * ring, 0.06, sin(a) * ring)))
	var stone_mi := MeshInstance3D.new()
	stone_mi.name = "Stones"
	stone_mi.mesh = stones.commit()
	stone_mi.material_override = ProceduralProp.color_material(Color(0.5, 0.48, 0.45), 0.95, false)
	add_child(stone_mi)
	var wood := ProceduralProp.color_material(Color(0.36, 0.24, 0.14), 0.9, false)
	var charred := ProceduralProp.color_material(Color(0.12, 0.09, 0.07), 0.95, false)
	for i in 4:
		var lg := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.07
		cy.bottom_radius = 0.08
		cy.height = 0.9 * (1.3 if big else 1.0)
		cy.radial_segments = 7
		lg.mesh = cy
		lg.material_override = charred if i % 2 == 0 else wood
		lg.rotation = Vector3(deg_to_rad(62), TAU * i / 4.0, 0)
		lg.position = Vector3(0, 0.22, 0)
		add_child(lg)
	# Fire.
	_fire = Node3D.new()
	_fire.name = "Fire"
	add_child(_fire)
	_flames = CPUParticles3D.new()
	_flames.amount = 26 if not big else 40
	_flames.lifetime = 0.8
	var q := QuadMesh.new()
	q.size = Vector2(0.32, 0.42) * (1.4 if big else 1.0)
	_flames.mesh = q
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.vertex_color_use_as_albedo = true
	fm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	fm.albedo_texture = soft_dot()
	_flames.material_override = fm
	_flames.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_flames.emission_sphere_radius = 0.22 * (1.5 if big else 1.0)
	_flames.direction = Vector3.UP
	_flames.spread = 12.0
	_flames.gravity = Vector3(0, 1.4, 0)
	_flames.initial_velocity_min = 0.4
	_flames.initial_velocity_max = 0.9
	_flames.scale_amount_min = 0.6
	_flames.scale_amount_max = 1.2
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.85, 0.4, 0.95))
	g.set_color(1, Color(0.9, 0.2, 0.05, 0.0))
	g.add_point(0.45, st.flame_color)
	_flames.color_ramp = g
	_flames.position = Vector3(0, 0.25, 0)
	_fire.add_child(_flames)
	_smoke = CPUParticles3D.new()
	_smoke.amount = 10
	_smoke.lifetime = 3.0
	var sq := QuadMesh.new()
	sq.size = Vector2(0.6, 0.6)
	_smoke.mesh = sq
	var sm := fm.duplicate() as StandardMaterial3D
	sm.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
	_smoke.material_override = sm
	_smoke.direction = Vector3.UP
	_smoke.spread = 15.0
	_smoke.gravity = Vector3(0.3, 0.5, 0)
	_smoke.initial_velocity_min = 0.5
	_smoke.initial_velocity_max = 0.8
	var g2 := Gradient.new()
	g2.set_color(0, Color(0.4, 0.38, 0.36, 0.35))
	g2.set_color(1, Color(0.6, 0.6, 0.6, 0.0))
	_smoke.color_ramp = g2
	_smoke.position = Vector3(0, 0.9, 0)
	_fire.add_child(_smoke)
	_light = OmniLight3D.new()
	_light.light_color = st.flame_color
	_light.omni_range = 8.0 if not big else 11.0
	_light.light_energy = st.light_energy
	_light.shadow_enabled = false
	_light.position = Vector3(0, 0.8, 0)
	_fire.add_child(_light)
	_audio = AudioStreamPlayer3D.new()
	var path := "res://assets/audio/ambience/campfire_loop.ogg"
	if ResourceLoader.exists(path):
		var s := load(path) as AudioStream
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_audio.stream = s
	_audio.unit_size = 2.0
	_audio.max_distance = 22.0
	_audio.volume_db = -6.0
	_fire.add_child(_audio)
	# Log seats facing the fire.
	for i in st.seats:
		var a := TAU * (i + 0.5) / st.seats + 0.4
		var seat := Seat.new()
		seat.display_name = "log"
		seat.interact_radius = 0.9
		var r := ring + 1.0
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var gx := CENTER.x + p.x
		var gz := CENTER.y + p.z
		p.y = Terrain.height_at(gx, gz) - position.y
		seat.position = p
		seat.rotation.y = atan2(-p.x, -p.z)
		seat.name = "LogSeat%d" % i
		var lg := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.19
		cy.bottom_radius = 0.2
		cy.height = 1.1
		cy.radial_segments = 9
		lg.mesh = cy
		lg.material_override = wood
		lg.rotation = Vector3(0, 0, PI * 0.5)
		lg.position = Vector3(0, 0.22, -0.12)
		seat.add_child(lg)
		add_child(seat)
		seats.append(seat)
	spot = ActionSpot.make(self, Vector3.ZERO, 1.35, _verb, use, Callable())
	spot.name = "CampfireSpot"
	_sync()


## Soft round sprite for flames / smoke (radial gradient, no texture file).
static func soft_dot() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.45, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	t.width = 32
	t.height = 32
	return t


func _verb() -> String:
	var st := style()
	var cost := st.firewood_cost if st else 2
	if not Lifestyle.campfire_lit():
		return Lang.tt("روشن کردن آتش ساحلی (%s هیزم)" % Lang.digits(str(cost)), "light the campfire (%d firewood)" % cost)
	if Kitchenware.count_input("category:fish") > 0:
		return Lang.tt("کباب کردن ماهی روی آتش و خوردن", "grill a fish on the fire and eat it")
	if Economy.count("firewood") > 0:
		return Lang.tt("هیزم انداختن (+%s ساعت)" % Lang.digits(str(int(st.burn_hours if st else 3))), "add firewood (+%d h)" % int(st.burn_hours if st else 3))
	return Lang.tt("گرم شدن کنار آتش", "warm up by the fire")


## E at the fire. Returns what happened ("lit", "grilled", "fed", "warm", "no_wood").
func use(who: Node3D) -> String:
	var st := style()
	var cost := st.firewood_cost if st else 2
	var hours := st.burn_hours if st else 3.0
	if not Lifestyle.campfire_lit():
		if Economy.count("firewood") < cost:
			GameEvents.notification_requested.emit(Lang.tt("%s هیزم لازم داری - درخت‌های خشک کنار جنگل را با تبر ببُر" % Lang.digits(str(cost)), "You need %d firewood - chop the dry trees at the forest edge" % cost))
			return "no_wood"
		Economy.remove_item("firewood", cost)
		Lifestyle.light_campfire(hours)
		Sfx.play_at(&"switch", global_position, -8.0, 0.6)
		GameEvents.notification_requested.emit(Lang.tt("آتش روشن شد. کنارش بنشین و گرم شو.", "The campfire crackles to life. Sit by it to warm up."))
		return "lit"
	if Kitchenware.count_input("category:fish") > 0:
		Kitchenware.remove_input("category:fish", 1)
		Needs.eat(st.grill_hunger if st else 45.0, true)
		if who and who.has_method("restore_stamina"):
			who.call("restore_stamina", st.grill_stamina if st else 35.0)
		Lifestyle.fish_grilled += 1
		TimeManager.advance_minutes(20.0)
		Sfx.play_at(&"sizzle", global_position, -6.0)
		GameEvents.notification_requested.emit(Lang.tt("ماهی کباب‌شده روی آتش. نوش جان!", "Fish grilled over the fire. Delicious!"))
		return "grilled"
	if Economy.count("firewood") > 0:
		Economy.remove_item("firewood", 1)
		Lifestyle.campfire_until += hours * 60.0
		Lifestyle.campfire_changed.emit(true)
		return "fed"
	if who and who.has_method("restore_stamina"):
		who.call("restore_stamina", 5.0)
	return "warm"


func _sync() -> void:
	if _fire == null:
		return
	var lit := Lifestyle.campfire_lit()
	_fire.visible = lit
	_flames.emitting = lit
	_smoke.emitting = lit
	if _audio.stream:
		if lit and not _audio.playing:
			_audio.play()
		elif not lit and _audio.playing:
			_audio.stop()
	if spot:
		spot.refresh()


func _process(delta: float) -> void:
	if _fire == null:
		return
	_t += delta
	var lit := Lifestyle.campfire_lit()
	if lit != _fire.visible:
		_sync()
	if lit:
		var st := style()
		_light.light_energy = (st.light_energy if st else 3.0) * (0.85 + 0.15 * sin(_t * 13.0) * sin(_t * 7.3))
		# Warmth: sitting by the fire restores stamina faster.
		var p := get_tree().get_first_node_in_group(&"player") as Node3D
		if p and p.get("sitting_on") in seats and p.has_method("restore_stamina"):
			p.call("restore_stamina", delta * 2.0 * ((st.warmth_mult if st else 1.6) - 1.0))
	elif Lifestyle.sim_enabled and TimeManager.hour() >= 19 and TimeManager.day != _evening_day:
		# Townspeople light it in the evening with their own firewood.
		_evening_day = TimeManager.day
		Lifestyle.light_campfire(3.0)
	if fmod(_t, 1.0) < delta and spot:
		spot.refresh()
