shader_type spatial;
// Procedural ground for the garden: tilled soil (clods + furrows along the
// rows), turf for untilled bed cells, packed-earth / gravel row paths.
// World-space value noise, no textures (cheap on the web renderer).
render_mode cull_back;

uniform vec4 color_a : source_color = vec4(0.40, 0.27, 0.16, 1.0);
uniform vec4 color_b : source_color = vec4(0.28, 0.18, 0.11, 1.0);
uniform float furrows = 0.0;
uniform float furrow_freq = 4.0;
uniform float speckle = 0.3;
uniform vec4 speckle_color : source_color = vec4(0.75, 0.7, 0.6, 1.0);
uniform float roughness_v = 0.95;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void fragment() {
	vec2 p = wpos.xz;
	float n = vnoise(p * 5.0) * 0.55 + vnoise(p * 15.0) * 0.3 + vnoise(p * 40.0) * 0.15;
	float f = furrows * (0.5 + 0.5 * sin(p.y * furrow_freq * 6.2831853));
	vec3 c = mix(color_a.rgb, color_b.rgb, clamp(n * 0.95 + f * 0.55 - 0.15, 0.0, 1.0));
	float sp = step(1.0 - speckle * 0.12, hash(floor(p * 34.0)));
	c = mix(c, speckle_color.rgb, sp * 0.7);
	ALBEDO = c;
	ROUGHNESS = roughness_v;
	SPECULAR = 0.2;
}
