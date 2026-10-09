shader_type spatial;
// Outfit painter for the CC0 Quaternius base body: one draw call per body.
// UV2 holds the bind-pose position of each vertex (x = height / body height,
// y = |x| / body height), so clothing borders are crisp per-pixel lines
// (shirt hem, belt, cuffs, boot tops) and every character can wear different
// colours with no extra textures. Works in Forward+ and Compatibility.

uniform sampler2D skin_albedo : source_color, filter_linear_mipmap;
uniform sampler2D skin_normal : hint_normal, filter_linear_mipmap;
uniform sampler2D skin_roughness : hint_roughness_r, filter_linear_mipmap;
uniform sampler2D fabric_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D fabric_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 skin_tint : source_color = vec4(1.0);
uniform vec4 shirt_color : source_color = vec4(0.36, 0.45, 0.58, 1.0);
uniform vec4 pants_color : source_color = vec4(0.17, 0.24, 0.38, 1.0);
uniform vec4 boots_color : source_color = vec4(0.25, 0.16, 0.1, 1.0);
uniform vec4 belt_color : source_color = vec4(0.18, 0.12, 0.08, 1.0);
uniform float sleeve_end = 0.32;   // |x|/h where the sleeve ends (T-pose arms)
uniform float collar = 0.825;      // y/h of the neckline
uniform float neck_radius = 0.047; // |x|/h of the neck
uniform float belt_low = 0.535;
uniform float belt_high = 0.566;
uniform float boots_top = 0.115;
uniform float head_start = 0.88;
uniform float pants_check = 0.0;   // 1 = subtle twill stripes (jeans/overalls)

varying vec2 bind_pos;

void vertex() {
	bind_pos = UV2;
}

// 0 skin, 1 shirt, 2 pants, 3 boots, 4 belt
int region(vec2 p) {
	float y = p.x;
	float ax = p.y;
	if (ax > 0.13 && y > 0.66) {
		return ax < sleeve_end ? 1 : 0;
	}
	if (y < boots_top) return 3;
	if (y < belt_low) return 2;
	if (y < belt_high) return 4;
	if (y > head_start) return 0;
	if (y > collar && ax < neck_radius) return 0;
	return 1;
}

void fragment() {
	int r = region(bind_pos);
	vec2 fuv = UV * 38.0;
	float n = texture(fabric_noise, fuv).r;
	if (r == 0) {
		ALBEDO = texture(skin_albedo, UV).rgb * skin_tint.rgb;
		NORMAL_MAP = texture(skin_normal, UV).rgb;
		NORMAL_MAP_DEPTH = 0.7;
		ROUGHNESS = texture(skin_roughness, UV).r * 0.9 + 0.08;
		SSS_STRENGTH = 0.0;
	} else {
		vec3 c = r == 1 ? shirt_color.rgb : (r == 2 ? pants_color.rgb : (r == 3 ? boots_color.rgb : belt_color.rgb));
		float weave = mix(0.88, 1.08, n);
		if (r == 2 && pants_check > 0.5) {
			weave *= 0.94 + 0.06 * sin((UV.x + UV.y) * 900.0);
		}
		// Seams: darken a thin band at every clothing border.
		float e = 0.004;
		bool seam = region(bind_pos + vec2(e, 0.0)) != r || region(bind_pos - vec2(e, 0.0)) != r
				|| region(bind_pos + vec2(0.0, e)) != r || region(bind_pos - vec2(0.0, e)) != r;
		ALBEDO = c * weave * (seam ? 0.72 : 1.0);
		NORMAL_MAP = texture(fabric_normal, UV * 22.0).rgb;
		NORMAL_MAP_DEPTH = 0.5;
		ROUGHNESS = r == 3 ? 0.42 : (r == 4 ? 0.5 : 0.88);
		SPECULAR = r == 3 ? 0.45 : 0.3;
	}
	// Soft rim to read well against the bright sky.
	RIM = 0.12;
	RIM_TINT = 0.5;
}
