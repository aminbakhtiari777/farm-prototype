// v6b "cloud_shadows" module: soft cloud shadows drifting over the ground.
// Global uniforms (project settings [shader_globals]) are driven by
// CloudShadows (scripts/v6b/sky/cloud_shadows.gd): strength 0 = off.
global uniform float cloud_strength;
global uniform float cloud_scale;
global uniform float cloud_cover;
global uniform vec2 cloud_offset;

float cs_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cs_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(cs_hash(i), cs_hash(i + vec2(1.0, 0.0)), u.x),
		mix(cs_hash(i + vec2(0.0, 1.0)), cs_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

// 0 = full sun, 1 = in a cloud's shadow.
float cloud_shadow(vec3 world_pos) {
	if (cloud_strength <= 0.001) {
		return 0.0;
	}
	vec2 p = world_pos.xz * cloud_scale + cloud_offset;
	float n = cs_noise(p) * 0.65 + cs_noise(p * 2.13 + vec2(5.2, 1.3)) * 0.35;
	float edge = 1.0 - cloud_cover;
	return smoothstep(edge - 0.08, edge + 0.12, n);
}
