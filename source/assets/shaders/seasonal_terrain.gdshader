shader_type spatial;
// Terrain: vertex colour (rgb = ground colour, a = how "grassy" the spot is)
// x detail texture. Seasons tint the grassy parts and lay snow on top.
// Driven by SeasonVisuals (scripts/world/season_visuals.gd).

uniform sampler2D detail_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 uv_scale = vec2(1.2, 1.2);
uniform float normal_strength = 0.7;
uniform vec3 grass_tint : source_color = vec3(1.0);
uniform float snow_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 snow_color : source_color = vec3(0.9, 0.92, 0.96);
// v7b.1 WeatherFx: 0 dry .. 1 soaked (darker, glossier, puddles in the hollows).
uniform float wetness : hint_range(0.0, 1.0) = 0.0;
#include "res://assets/shaders/cloud_shadow.gdshaderinc"

void vertex() {
	UV = UV * uv_scale;
}

void fragment() {
	vec3 detail = texture(detail_tex, UV).rgb;
	vec3 base = COLOR.rgb * detail;
	float grass = COLOR.a;
	base = mix(base, base * grass_tint, grass);
	float n = texture(detail_tex, UV * 0.23 + vec2(0.31, 0.17)).r;
	float cover = snow_amount * (0.55 + 0.45 * grass) + (n - 0.82) * 0.9;
	float snow = snow_amount > 0.001 ? smoothstep(0.15, 0.45, cover) : 0.0;
	ALBEDO = mix(base, snow_color * (0.92 + 0.08 * n), snow);
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	ALBEDO *= 1.0 - cloud_strength * cloud_shadow(wp);
	float wet = wetness * (1.0 - snow);
	float puddle = wet * smoothstep(0.55, 0.3, n);
	ALBEDO *= 1.0 - 0.42 * wet - 0.1 * puddle;
	ROUGHNESS = mix(mix(0.95, 0.75, snow), 0.55, wet) - 0.25 * puddle;
	NORMAL_MAP = texture(normal_tex, UV).rgb;
	NORMAL_MAP_DEPTH = normal_strength * (1.0 - 0.6 * snow);
}
