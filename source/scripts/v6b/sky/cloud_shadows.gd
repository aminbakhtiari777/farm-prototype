class_name CloudShadows
extends Node
## v6b "cloud_shadows" module: drives the cloud-shadow shader globals
## (assets/shaders/cloud_shadow.gdshaderinc, used by the terrain and grass):
## soft patches drift with the wind, coverage follows the weather, they fade
## out at night (no sun, no shadow). Same cheap value-noise on desktop and
## web (no texture, ~10 ALU per pixel); the web uses a lighter strength.

var offset: Vector2 = Vector2.ZERO
var strength_now: float = 0.0
var cover_now: float = 0.35


func style() -> CloudShadowStyle:
	return Modules.style("cloud_shadows") as CloudShadowStyle


func _ready() -> void:
	add_to_group(&"cloud_shadows")


static func _gset(name: StringName, v: Variant) -> void:
	RenderingServer.global_shader_parameter_set(name, v)


func _process(delta: float) -> void:
	var st := style()
	if st == null:
		if strength_now != 0.0:
			strength_now = 0.0
			_gset(&"cloud_strength", 0.0)
		return
	offset += st.speed * st.scale * delta
	var h := TimeManager.hours_float()
	var day := clampf(minf(h - TimeManager.sunrise(), TimeManager.sunset() - h) / 1.2, 0.0, 1.0)
	var base := st.web_strength if OS.has_feature("web") else st.strength
	var cov := float(st.coverage.get(TimeManager.weather_id, 0.4))
	cover_now = lerpf(cover_now, cov, 1.0 - exp(-0.5 * delta))
	strength_now = base * day
	_gset(&"cloud_strength", strength_now)
	_gset(&"cloud_scale", st.scale)
	_gset(&"cloud_cover", cover_now)
	_gset(&"cloud_offset", offset)
