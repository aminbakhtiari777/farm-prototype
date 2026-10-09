shader_type spatial;
// Procedural wall cladding for house styles (no textures, world space):
// 0 = wooden siding (horizontal boards with shadow grooves),
// 1 = stone (staggered blocks with mortar and per-block tint),
// 2 = modern panels (large smooth panels, thin seams).

uniform vec4 base_color : source_color = vec4(0.7, 0.55, 0.38, 1.0);
uniform vec4 joint_color : source_color = vec4(0.3, 0.22, 0.15, 1.0);
uniform int pattern = 0;
uniform float scale = 1.0;
uniform float roughness_v = 0.85;

varying vec3 wpos;
varying vec3 wnrm;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 uv = abs(wnrm.x) > abs(wnrm.z) ? vec2(wpos.z, wpos.y) : vec2(wpos.x, wpos.y);
	if (abs(wnrm.y) > 0.7) { uv = wpos.xz; }
	uv /= max(scale, 0.01);
	vec3 col = base_color.rgb;
	float joint = 0.0;
	float rough = roughness_v;
	if (pattern == 0) {
		float b = uv.y / 0.2;
		float row = floor(b);
		float f = fract(b);
		joint = smoothstep(0.1, 0.0, f) + smoothstep(0.9, 1.0, f) * 0.35;
		col *= 0.9 + hash(vec2(row, 3.0)) * 0.18;
		col *= 0.96 + 0.04 * sin(uv.x * 9.0 + row * 2.3);
	} else if (pattern == 1) {
		vec2 b = uv / vec2(0.55, 0.28);
		float row = floor(b.y);
		b.x += mod(row, 2.0) * 0.5;
		vec2 cell = floor(b);
		vec2 f = fract(b);
		float m = 0.07;
		joint = 1.0 - smoothstep(0.0, m, f.x) * smoothstep(1.0, 1.0 - m * 0.6, f.x) * smoothstep(0.0, m * 1.6, f.y) * smoothstep(1.0, 1.0 - m, f.y);
		col *= 0.78 + hash(cell) * 0.36;
		rough = 0.95;
	} else {
		vec2 b = uv / vec2(1.2, 0.9);
		vec2 f = fract(b);
		float m = 0.012;
		joint = 1.0 - smoothstep(0.0, m, f.x) * smoothstep(1.0, 1.0 - m, f.x) * smoothstep(0.0, m, f.y) * smoothstep(1.0, 1.0 - m, f.y);
		col *= 0.97 + hash(floor(b)) * 0.05;
		rough = 0.55;
	}
	ALBEDO = mix(col, joint_color.rgb, clamp(joint, 0.0, 1.0));
	ROUGHNESS = rough;
}
