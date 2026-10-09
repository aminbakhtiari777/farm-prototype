class_name Tipsy
extends Node
## v7b tipsiness after strong drinks (cafe module): for a short time the
## farmer's walk drifts and the camera sways, and the screen gets a little
## blurry. It wears off (TownLife.tipsy seconds). Driving while tipsy is
## fined once per episode (justice) and the car drifts a little.

var overlay: ColorRect
var dui_fines: int = 0
var _fined: bool = false
var _t: float = 0.0
var _was: bool = false


func style() -> CafeStyle:
	return Modules.style("cafe") as CafeStyle


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TipsyLayer"
	layer.layer = 4
	add_child(layer)
	overlay = ColorRect.new()
	overlay.name = "TipsyBlur"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = """shader_type canvas_item;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;
uniform float amount = 0.0;
uniform float t = 0.0;
void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE * (2.0 + 4.0 * amount);
	vec2 sway = vec2(sin(t * 1.3), cos(t * 1.7)) * px * 2.0 * amount;
	vec4 c = texture(screen_tex, SCREEN_UV) * 0.36;
	c += texture(screen_tex, SCREEN_UV + vec2(px.x, 0.0) + sway) * 0.16;
	c += texture(screen_tex, SCREEN_UV - vec2(px.x, 0.0) + sway) * 0.16;
	c += texture(screen_tex, SCREEN_UV + vec2(0.0, px.y) - sway) * 0.16;
	c += texture(screen_tex, SCREEN_UV - vec2(0.0, px.y) - sway) * 0.16;
	vec2 d = UV - vec2(0.5);
	float vig = smoothstep(0.35, 0.8, length(d)) * 0.25 * amount;
	COLOR = vec4(mix(c.rgb, vec3(0.0), vig), 1.0);
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	overlay.material = m
	overlay.visible = false
	layer.add_child(overlay)


func strength() -> float:
	return clampf(TownLife.tipsy / 60.0, 0.0, 1.0)


func is_tipsy() -> bool:
	return TownLife.tipsy > 0.0


func _process(delta: float) -> void:
	var p := V7bKit.player(get_tree())
	var st := style()
	if TownLife.tipsy <= 0.0 or st == null:
		if _was:
			_was = false
			_fined = false
			overlay.visible = false
			if p:
				p.drift_angle = 0.0
			var c0 := get_viewport().get_camera_3d()
			if c0:
				c0.v_offset = 0.0
			GameEvents.notification_requested.emit(Lang.tt("سرگیجه برطرف شد.", "The tipsiness has worn off."))
		return
	_was = true
	TownLife.tipsy = maxf(TownLife.tipsy - delta, 0.0)
	_t += delta
	var s := strength()
	if p:
		p.drift_angle = (sin(_t * 1.3) + 0.45 * sin(_t * 2.9)) * st.wobble * s
		var car := p.vehicle as DrivableCar
		if car:
			if absf(car.speed) > 1.0:
				car.yaw = wrapf(car.yaw + sin(_t * 1.1) * 0.25 * s * delta, -PI, PI)
			if absf(car.speed) > 2.0 and not _fined:
				_fined = true
				dui_fines += 1
				TownLife.cafe["dui"] = int(TownLife.cafe.get("dui", 0)) + 1
				CityState.add_fine("dui", st.dui_fine, "Driving after strong drinks", "رانندگی بعد از نوشیدنی قوی")
				WorldMemory.file_report("dui", "player", "", st.dui_fine)
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.v_offset = sin(_t * 0.9) * 0.08 * s
	overlay.visible = st.blur > 0.0
	var mat := overlay.material as ShaderMaterial
	mat.set_shader_parameter(&"amount", st.blur * s)
	mat.set_shader_parameter(&"t", _t)
