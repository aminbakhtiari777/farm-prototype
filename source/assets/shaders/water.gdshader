shader_type spatial;
// Stylised animated water for the sea and the pond (works in the
// Compatibility renderer: no depth/screen textures). Vertex COLOR.r = shore
// foam amount, COLOR.g = depth 0..1 (both baked per vertex from the terrain).
render_mode cull_back, depth_draw_opaque, specular_schlick_ggx;

uniform vec3 shallow_color : source_color = vec3(0.3, 0.72, 0.72);
uniform vec3 deep_color : source_color = vec3(0.05, 0.27, 0.42);
uniform vec3 foam_color : source_color = vec3(0.95, 0.97, 0.97);
uniform float wave_height = 0.12;
uniform float wave_speed = 1.0;
uniform float alpha_shallow = 0.55;
uniform float night = 0.0;

varying float v_foam;
varying float v_depth;
varying vec3 v_world;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wave_speed;
	float h = sin(dot(w.xz, vec2(0.21, 0.17)) + t * 1.3) * 0.6 + sin(dot(w.xz, vec2(-0.13, 0.27)) + t * 0.9) * 0.4;
	VERTEX.y += h * wave_height * (0.3 + COLOR.g);
	v_foam = COLOR.r;
	v_depth = COLOR.g;
	v_world = w;
	// Approximate normal from the analytic waves.
	float dx = cos(dot(w.xz, vec2(0.21, 0.17)) + t * 1.3) * 0.21 * 0.6 - cos(dot(w.xz, vec2(-0.13, 0.27)) + t * 0.9) * 0.13 * 0.4;
	float dz = cos(dot(w.xz, vec2(0.21, 0.17)) + t * 1.3) * 0.17 * 0.6 + cos(dot(w.xz, vec2(-0.13, 0.27)) + t * 0.9) * 0.27 * 0.4;
	NORMAL = normalize(vec3(-dx * wave_height * 3.0, 1.0, -dz * wave_height * 3.0));
}

void fragment() {
	float t = TIME * wave_speed;
	vec2 p = v_world.xz;
	float ripple = noise(p * 0.9 + vec2(t * 0.35, t * 0.2)) * 0.5 + noise(p * 2.3 - vec2(t * 0.25, -t * 0.4)) * 0.5;
	vec3 col = mix(shallow_color, deep_color, smoothstep(0.0, 1.0, v_depth));
	col += (ripple - 0.5) * 0.06;
	// Shore foam: animated bands that roll toward the beach.
	float band = sin(v_foam * 14.0 - t * 2.2 + ripple * 3.0) * 0.5 + 0.5;
	float foam = smoothstep(0.55, 0.95, v_foam) * 0.9 + smoothstep(0.7, 0.95, band) * smoothstep(0.25, 0.8, v_foam) * 0.7;
	foam *= smoothstep(0.35, 0.6, ripple + v_foam * 0.4);
	col = mix(col, foam_color, clamp(foam, 0.0, 1.0));
	ALBEDO = col * mix(1.0, 0.35, night);
	ROUGHNESS = 0.08 + foam * 0.6;
	METALLIC = 0.0;
	SPECULAR = 0.6;
	NORMAL_MAP = vec3(0.5 + (ripple - 0.5) * 0.35, 0.5 + (noise(p * 1.7 + t * 0.3) - 0.5) * 0.35, 1.0);
	ALPHA = clamp(mix(alpha_shallow, 0.97, smoothstep(0.0, 0.5, v_depth)) + foam, 0.0, 1.0);
}
