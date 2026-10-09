class_name CarSystems
extends Node
## v7b "driving" module, one per DrivableCar (child "CarSystems"):
##  - gearbox: automatic or manual (3 toggles; Shift / Ctrl shift up / down).
##    Each gear has a top speed and pull; too high a gear at low speed lugs.
##  - headlights: H switches them; after dark you need them - driving without
##    lights at night gets a police fine (city fund) after a short grace.
##  - fuel: used per km (eco injector upgrade uses less); empty = crawl.
##  - condition: crashes wear the car (smoke under 35%); the mechanic repairs.
## State per car lives in TownLife.cars (saved). DrivableCar calls the hooks.

var car: DrivableCar
var gear: int = 1
var lights_on: bool = false
var dark_t: float = 0.0
var fined_day: int = -1
var shifts: int = 0
var crashes: int = 0
var _warned_fuel: bool = false
var _smoke: CPUParticles3D


func style() -> DrivingStyle:
	return Modules.style("driving") as DrivingStyle


func state() -> Dictionary:
	return TownLife.car(car.key) if car else {}


func gears() -> int:
	var st := style()
	return st.gear_top.size() if st and not st.gear_top.is_empty() else 1


func is_auto() -> bool:
	return bool(state().get("auto", true))


func set_auto(v: bool) -> void:
	state()["auto"] = v
	TownLife.changed.emit("cars")


func fuel() -> float:
	return float(state().get("fuel", 100.0))


func condition() -> float:
	return float(state().get("condition", 100.0))


func needs_lights() -> bool:
	var st := style()
	if st == null:
		return false
	return Staffing.open_at(Vector2(st.night_hours.x, st.night_hours.y + 24.0 if st.night_hours.y < st.night_hours.x else st.night_hours.y), TimeManager.hours_float())


## Top speed multiplier for DrivableCar (gear, upgrades, wear, fuel).
func top_mult(max_v: float) -> float:
	var st := style()
	var m := TownLife.car_mult(car.key, "speed")
	if st and not st.gear_top.is_empty():
		if is_auto():
			gear = auto_gear(max_v)
		m *= float(st.gear_top[clampi(gear - 1, 0, st.gear_top.size() - 1)]) if not is_auto() else 1.0
	if condition() < 35.0:
		m *= 0.75
	if st and st.fuel_per_km > 0.0 and fuel() <= 0.0:
		m *= 0.12
	return m


## Pull multiplier for DrivableCar (gear, lugging, upgrades).
func accel_mult(max_v: float) -> float:
	var st := style()
	var m := TownLife.car_mult(car.key, "accel")
	if st and not st.gear_accel.is_empty():
		var g := clampi(gear - 1, 0, st.gear_accel.size() - 1)
		m *= float(st.gear_accel[g])
		if not is_auto() and g >= 2 and absf(car.speed) < max_v * float(st.gear_top[g - 2]) * 0.5:
			m *= 0.35  # lugging: too high a gear for this speed
	return m


func auto_gear(max_v: float) -> int:
	var st := style()
	if st == null or st.gear_top.is_empty():
		return 1
	var v := absf(car.speed)
	for i in st.gear_top.size():
		if v < float(st.gear_top[i]) * max_v * 0.92:
			return i + 1
	return st.gear_top.size()


func shift(d: int) -> void:
	if is_auto():
		return
	var ng := clampi(gear + d, 1, gears())
	if ng != gear:
		gear = ng
		shifts += 1
		Sfx.play_at(&"switch", car.global_position, -14.0, 0.8 + gear * 0.08)


func toggle_lights() -> void:
	lights_on = not lights_on
	GameEvents.notification_requested.emit(Lang.tt("چراغ‌ها روشن شد." if lights_on else "چراغ‌ها خاموش شد.", "Headlights on." if lights_on else "Headlights off."))


func toggle_gearbox() -> void:
	set_auto(not is_auto())
	if not is_auto():
		gear = clampi(auto_gear(11.0), 1, gears())
	GameEvents.notification_requested.emit(Lang.tt("گیربکس: %s" % ("خودکار" if is_auto() else "دستی (Shift بالا، Ctrl پایین)"),
		"Gearbox: %s" % ("automatic" if is_auto() else "manual (Shift up, Ctrl down)")))


## Keys while driving (called from DrivableCar._physics_process).
func handle_input() -> void:
	if GameEvents.ui_open:
		return
	if Input.is_action_just_pressed(&"headlights"):
		toggle_lights()
	if Input.is_action_just_pressed(&"gear_mode"):
		toggle_gearbox()
	if Input.is_action_just_pressed(&"gear_up"):
		shift(1)
	if Input.is_action_just_pressed(&"gear_down"):
		shift(-1)


## Distance driven this frame: fuel use.
func on_moved(dist: float) -> void:
	var st := style()
	if st == null or st.fuel_per_km <= 0.0 or dist <= 0.0:
		return
	var s := state()
	var before := float(s.get("fuel", 100.0))
	var f := maxf(before - st.fuel_per_km * TownLife.car_mult(car.key, "fuel") * dist / 1000.0, 0.0)
	s["fuel"] = f
	if f <= st.low_fuel and not _warned_fuel:
		_warned_fuel = true
		GameEvents.notification_requested.emit(Lang.tt("بنزین کم است - به تعمیرگاه خیابان اصلی برو.", "Low fuel - head to the Main St mechanic."))
	if f <= 0.0 and before > 0.0:
		GameEvents.notification_requested.emit(Lang.tt("بنزین تمام شد! ماشین به زور حرکت می‌کند.", "Out of fuel! The car barely crawls."))
	if f > st.low_fuel:
		_warned_fuel = false


## A crash at `speed` m/s: wear.
func on_crash(speed: float) -> void:
	var st := style()
	if st == null or st.damage_per_hit <= 0.0 or absf(speed) < 4.0:
		return
	crashes += 1
	var s := state()
	s["condition"] = maxf(float(s.get("condition", 100.0)) - st.damage_per_hit * absf(speed) / 8.0, 0.0)
	Sfx.play_at(&"land", car.global_position, -6.0, 0.8)
	_update_smoke()
	if float(s["condition"]) < 35.0:
		GameEvents.notification_requested.emit(Lang.tt("ماشین آسیب دیده - تعمیرش کن.", "The car is damaged - get it repaired."))


func _update_smoke() -> void:
	var bad := condition() < 35.0
	if bad and _smoke == null:
		_smoke = V7aKit.particles("smoke", 10, Vector3(0.3, 0.1, 0.3))
		_smoke.name = "EngineSmoke"
		_smoke.scale_amount_min = 0.4
		_smoke.scale_amount_max = 0.9
		_smoke.position = Vector3(0, 1.0, car.size.z * 0.4)
		car.add_child(_smoke)
	if _smoke:
		_smoke.emitting = bad


## Headlights: range / energy from the module and the LED upgrade.
func apply_lights(lights: Array) -> void:
	var st := style()
	var mult := TownLife.car_mult(car.key, "lights")
	for l in lights:
		var sl := l as SpotLight3D
		sl.visible = lights_on and car.driver != null
		if st:
			sl.spot_range = st.light_range * mult
			sl.light_energy = st.light_energy * (1.0 + (mult - 1.0) * 0.5)


## Night without lights: grace, then a fine (once per night).
func check_night(delta: float) -> void:
	var st := style()
	if st == null or car.driver == null:
		return
	if needs_lights() and not lights_on and absf(car.speed) > 3.0:
		dark_t += delta
		if dark_t > st.no_lights_grace and fined_day != TimeManager.day:
			fined_day = TimeManager.day
			if st.no_lights_fine > 0:
				CityState.add_fine("no_lights", st.no_lights_fine, "Driving at night without headlights", "رانندگی در شب بدون چراغ")
				WorldMemory.file_report("no_lights", "player", "", st.no_lights_fine)
			else:
				GameEvents.notification_requested.emit(Lang.tt("شب است - چراغ‌ها را با H روشن کن.", "It's dark - switch your headlights on with H."))
	else:
		dark_t = 0.0


func _ready() -> void:
	car = get_parent() as DrivableCar
	_update_smoke.call_deferred()


## Dashboard text (Persian / English).
func dash_text() -> String:
	var st := style()
	var kmh := int(round(absf(car.speed) * 3.6))
	var g := "R" if car.speed < -0.3 else str(gear)
	var fa := Lang.is_fa()
	var parts: PackedStringArray = []
	parts.append(Lang.tt("دنده %s (%s)" % [Lang.digits(g), "خودکار" if is_auto() else "دستی"], "Gear %s (%s)" % [g, "auto" if is_auto() else "manual"]))
	parts.append(Lang.tt("%s کیلومتر بر ساعت" % Lang.digits(str(kmh)), "%d km/h" % kmh))
	# v7b.1 traffic: the speed limit of this street.
	var lim_txt := TrafficKit.dash_limit_text(car)
	if lim_txt != "":
		parts.append(lim_txt)
	if st and st.fuel_per_km > 0.0:
		parts.append(Lang.tt("بنزین %s٪" % Lang.digits(str(int(fuel()))), "Fuel %d%%" % int(fuel())))
	parts.append(Lang.tt("سلامت %s٪" % Lang.digits(str(int(condition()))), "Condition %d%%" % int(condition())))
	parts.append(Lang.tt("چراغ: %s" % ("روشن" if lights_on else "خاموش"), "Lights: %s" % ("on" if lights_on else "off")))
	return ("  ·  " if not fa else "  ·  ").join(parts)
