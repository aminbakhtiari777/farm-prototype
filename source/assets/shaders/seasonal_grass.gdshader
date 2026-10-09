shader_type spatial;
render_mode cull_disabled;
// Grass blades (MultiMesh with per-instance colours). Season tint + frosty
// snow tips in winter. Driven by SeasonVisuals.

uniform vec3 tint : source_color = vec3(1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
// v7b.1 WeatherFx: wet blades are a little darker and shinier.
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
uniform vec3 backlight_color : source_color = vec3(0.12, 0.16, 0.05);
#include "res://assets/shaders/cloud_shadow.gdshaderinc"

varying float blade_height;

void vertex() {
	blade_height = clamp(VERTEX.y / 0.2, 0.0, 1.0);
}

void fragment() {
	vec3 c = COLOR.rgb * tint;
	float frost = snow_amount * smoothstep(0.2, 1.0, blade_height);
	ALBEDO = mix(c, vec3(0.86, 0.89, 0.94), frost);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ALBEDO *= 1.0 - cloud_strength * cloud_shadow(wp);
	float wet = wetness * (1.0 - frost);
	ALBEDO *= 1.0 - 0.22 * wet;
	ROUGHNESS = mix(0.85, 0.6, wet);
	BACKLIGHT = backlight_color * (1.0 - frost);
}
