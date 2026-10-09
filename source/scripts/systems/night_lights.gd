class_name NightLights
extends Node
## Feature module "night lights" (+ electricity effects). Driven by
## TimeManager: lamps switch on around sunset and off after sunrise (offsets
## from the active "lighting" module). Controls:
##   - porch / wall lanterns on every house (+ the farmhouse porch light),
##   - window glow (Building materials), street lamps ("night_lights" group),
##   - power cuts (PowerGrid): electric lights go dark, homes show candles,
##     lanterns and firelight ("candle_lights" / "candle_flames" groups).
## The farmhouse porch light is a real OmniLight3D; other houses share a small
## pool of lights that follows the camera (cheap on the web).

## 0 = lights off (day), 1 = full night lighting.
var amount: float = 0.0
var _pool: Array[OmniLight3D] = []
var _pool_timer: float = 0.0
var _t: float = 0.0
## World positions of house wall lanterns (filled by Building).
static var porch_positions: PackedVector3Array = PackedVector3Array()

const POOL_SIZE := 5
const FADE_H := 0.5


func _ready() -> void:
	add_to_group(&"night_lights_controller")
	for i in POOL_SIZE:
		var l := OmniLight3D.new()
		l.name = "PorchPool%d" % i
		l.omni_range = 7.0
		l.omni_attenuation = 1.3
		l.shadow_enabled = false
		l.visible = false
		add_child(l)
		_pool.append(l)
	PowerGrid.power_changed.connect(func(_on: bool) -> void: apply())
	Modules.on_swap("lighting", self, func(_m: AssetModule) -> void: apply())
	apply()


func style() -> LightingStyle:
	return Modules.style("lighting") as LightingStyle


## Lights-on amount for an hour of the day (pure function of TimeManager).
func amount_at(hour: float) -> float:
	if not TimeManager.day_night_enabled:
		return 0.0
	var st := style()
	var on_h := TimeManager.sunset() - (st.on_before_sunset_h if st else 0.25)
	var off_h := TimeManager.sunrise() + (st.off_after_sunrise_h if st else 0.25)
	# Evening ramp-up and morning ramp-down (FADE_H hours each).
	var evening := clampf((hour - on_h) / FADE_H, 0.0, 1.0)
	var morning := clampf((off_h - hour) / FADE_H, 0.0, 1.0)
	return maxf(evening, morning)


func lights_on() -> bool:
	return amount > 0.5


func _process(delta: float) -> void:
	_t += delta
	apply()
	_pool_timer -= delta
	if _pool_timer <= 0.0:
		_pool_timer = 0.4
		_update_pool()


func apply() -> void:
	var hour := TimeManager.hours_float()
	amount = amount_at(hour)
	var st := style()
	var powered := PowerGrid.power_on
	var flick := 1.0 + (sin(_t * 13.0) * 0.5 + sin(_t * 7.3 + 1.0) * 0.5) * (st.flicker if st else 0.25)
	var electric := amount if powered else 0.0
	var candles := 0.0 if powered else maxf(amount, 0.0)
	# Windows: warm electric glow, or dim flickering candle light in a power cut.
	var wcol := (st.window_color if st else Color(1.0, 0.72, 0.38)) if powered else (st.candle_color if st else Color(1.0, 0.55, 0.2))
	Building.set_night_glow(amount, electric * 2.2 + candles * 0.9 * flick, wcol)
	# Porch / wall lanterns on houses.
	var bulb := PowerFx.bulb_material()
	bulb.emission = st.bulb_color if st else Color(1.0, 0.8, 0.5)
	bulb.emission_energy_multiplier = electric * 3.0
	# Street lamps (same grid).
	StreetLamp.lantern_material().emission_energy_multiplier = lerpf(0.3, 3.5, electric)
	var tree := get_tree()
	for node in tree.get_nodes_in_group(&"night_lights"):
		var light := node as Light3D
		if light:
			light.visible = electric > 0.02
			light.light_energy = 2.2 * electric
	var porch_e := (st.porch_energy if st else 2.4) * electric
	for node in tree.get_nodes_in_group(&"porch_lights"):
		var light := node as Light3D
		if light:
			light.visible = electric > 0.02
			light.light_energy = porch_e
			light.light_color = st.bulb_color if st else Color(1.0, 0.78, 0.48)
	for l in _pool:
		l.light_color = st.bulb_color if st else Color(1.0, 0.78, 0.48)
		l.light_energy = porch_e * 0.8
		l.visible = electric > 0.02 and l.has_meta(&"used")
	# Candles / lanterns / fireplaces: lit during power cuts (evenings, or
	# whenever someone is inside).
	var inside := false
	for b in tree.get_nodes_in_group(&"buildings"):
		if (b as Building).player_inside:
			inside = true
			break
	var candle_on := not powered and (candles > 0.02 or inside)
	var ce := (st.candle_energy if st else 1.3) * flick * maxf(candles, 0.6 if inside else 0.0)
	for node in tree.get_nodes_in_group(&"candle_lights"):
		var light := node as Light3D
		if light:
			light.visible = candle_on
			light.light_energy = ce
			light.light_color = st.candle_color if st else Color(1.0, 0.55, 0.2)
	for node in tree.get_nodes_in_group(&"candle_flames"):
		(node as Node3D).visible = candle_on
	PowerFx.flame_material().emission_energy_multiplier = 2.0 + flick
	# DayNightCycle exposes `night_lights` (tests, water shader): keep it in sync.
	for dn in tree.get_nodes_in_group(&"day_night"):
		dn.set(&"night_lights", amount)


func _update_pool() -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null or porch_positions.is_empty():
		return
	var origin := cam.global_position
	var order: Array = []
	for i in porch_positions.size():
		var d := porch_positions[i].distance_squared_to(origin)
		if d < 60.0 * 60.0:
			order.append([d, i])
	order.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	for k in _pool.size():
		if k < order.size():
			_pool[k].global_position = porch_positions[order[k][1]] + Vector3(0, 0, 0)
			_pool[k].set_meta(&"used", true)
		else:
			_pool[k].remove_meta(&"used")
