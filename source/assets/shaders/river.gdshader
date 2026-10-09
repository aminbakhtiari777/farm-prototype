shader_type spatial;
render_mode blend_mix, cull_disabled, depth_draw_opaque, specular_schlick_ggx;
// Flowing river water: scrolling ripples along the ribbon UV (v = distance).

uniform vec4 water_color : source_color = vec4(0.2, 0.42, 0.5, 0.85);
uniform vec4 foam_color : source_color = vec4(0.85, 0.92, 0.95, 1.0);
uniform float speed = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 uv = vec2(UV.x * 3.0, UV.y * 0.35 - TIME * speed);
	float n = vnoise(uv * 2.0) * 0.6 + vnoise(uv * 5.3 + 7.0) * 0.4;
	float edge = smoothstep(0.38, 0.5, abs(UV.x - 0.5));
	vec3 col = mix(water_color.rgb, water_color.rgb * 1.25 + 0.05, n);
	col = mix(col, foam_color.rgb, edge * 0.35 + smoothstep(0.82, 0.95, n) * 0.25);
	ALBEDO = col;
	ROUGHNESS = 0.18 + n * 0.1;
	METALLIC = 0.0;
	SPECULAR = 0.45;
	ALPHA = mix(water_color.a, 1.0, edge * 0.3);
}
