class_name Driving
extends Node
## v7b "driving" module manager: gives every drivable car its CarSystems
## (gears, headlights, fuel, wear) and shows the dashboard while you drive
## (gear, speed, fuel, condition, lights + key hints). At night without
## headlights the view darkens at the edges - you need the lights.

var dash: PanelContainer
var dash_label: Label
var hint_label: Label
var dark: ColorRect
var _t: float = 0.0
var last_car: DrivableCar  ## the car you drove most recently (mechanic, passengers)


func style() -> DrivingStyle:
	return Modules.style("driving") as DrivingStyle


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "DrivingUI"
	layer.layer = 5
	add_child(layer)
	dark = ColorRect.new()
	dark.name = "NightEdges"
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nvoid fragment() {\n\tvec2 d = UV - vec2(0.5);\n\tfloat v = smoothstep(0.18, 0.75, length(d * vec2(1.25, 1.0)));\n\tCOLOR = vec4(0.0, 0.0, 0.02, v * amount);\n}\n"
	var m := ShaderMaterial.new()
	m.shader = sh
	dark.material = m
	dark.visible = false
	layer.add_child(dark)
	dash = PanelContainer.new()
	dash.name = "Dashboard"
	dash.theme = V6bWorld.ui_theme()
	dash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash.add_theme_stylebox_override(&"panel", UIKit.style(Color(0.06, 0.07, 0.09, 0.78), 10, 10, true))
	dash.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	# sits above the HUD interaction prompt (-132..-90) so "E: get out" never covers it
	dash.offset_top = -200
	dash.offset_bottom = -142
	dash.offset_left = -360
	dash.offset_right = 360
	dash.grow_horizontal = Control.GROW_DIRECTION_BOTH
	dash.visible = false
	layer.add_child(dash)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dash.add_child(v)
	dash_label = UIKit.label(v, "", 17, Color(0.95, 1.0, 0.9))
	dash_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label = UIKit.label(v, "", 13, Color(0.8, 0.85, 0.9))
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	attach_all.call_deferred()


## Every drivable car gets a CarSystems child (cars respawn on module swaps).
func attach_all() -> int:
	var n := 0
	for c in get_tree().get_nodes_in_group(&"drivable_cars"):
		var car := c as DrivableCar
		if car and car.get_node_or_null(^"CarSystems") == null:
			var s := CarSystems.new()
			s.name = "CarSystems"
			car.add_child(s)
			n += 1
	return n


func driven() -> DrivableCar:
	var p := V7bKit.player(get_tree())
	return p.vehicle as DrivableCar if p and p.vehicle is DrivableCar else null


func refresh() -> void:
	var car := driven()
	if car:
		last_car = car
	var sys := car.get_node_or_null(^"CarSystems") as CarSystems if car else null
	dash.visible = sys != null and style() != null
	if not dash.visible:
		dark.visible = false
		return
	dash_label.text = sys.dash_text()
	hint_label.text = Lang.tt("H چراغ · ۳ گیربکس خودکار/دستی · Shift/Ctrl دنده · R بوق · E پیاده شو",
		"H lights · 3 auto/manual · Shift/Ctrl shift · R horn · E get out")
	var st := style()
	var need := sys.needs_lights() and not sys.lights_on
	dark.visible = need and st.dark_driving > 0.0
	(dark.material as ShaderMaterial).set_shader_parameter(&"amount", st.dark_driving * 2.2 if need else 0.0)


func _process(delta: float) -> void:
	_t -= delta
	if _t <= 0.0:
		_t = 0.2
		if style() != null:
			attach_all()
		refresh()
