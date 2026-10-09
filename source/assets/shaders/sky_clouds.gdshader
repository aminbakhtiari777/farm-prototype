shader_type sky;
// Stylised-physical sky: gradient + sun/moon disk & halo + static fbm clouds + stars.
// Colours are driven by DayNightCycle (scripts/world/day_night_cycle.gd), which
// updates the uniforms only when they change noticeably (no TIME use), so the
// radiance map is not re-rendered every frame.
// Replace with PhysicalSkyMaterial or an HDRI (PanoramaSkyMaterial) for photoreal skies.

uniform vec3 zenith_color : source_color = vec3(0.23, 0.42, 0.74);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.80, 0.90);
uniform vec3 ground_color : source_color = vec3(0.30, 0.33, 0.28);
// v6b "sea_horizon" module: below the horizon on the sea side, paint distant
// water fading into the haze (no grey band between the far sea and the sky).
uniform vec3 sea_color : source_color = vec3(0.16, 0.36, 0.55);
uniform float sea_blend : hint_range(0.0, 1.0) = 0.0;
uniform float sea_sharpness = 40.0;
uniform vec2 sea_dir = vec2(0.7071, 0.7071);
uniform float horizon_softness : hint_range(0.05, 2.0) = 0.45;
uniform float sun_disk_size : hint_range(0.0, 0.05) = 0.012;
uniform float sun_glow : hint_range(0.0, 2.0) = 0.6;
uniform float cloud_coverage : hint_range(0.0, 1.0) = 0.5;
uniform float cloud_scale = 1.2;
uniform float cloud_brightness = 1.15;
uniform vec2 cloud_offset = vec2(3.7, 1.3);
uniform vec3 cloud_tint : source_color = vec3(1.0);
uniform float star_amount : hint_range(0.0, 1.0) = 0.0;
// v6a night sky (NightSky / "night_sky" module): star field, Milky Way, moon with phases.
uniform float star_density : hint_range(0.0, 0.2) = 0.014;
uniform float star_brightness = 1.6;
uniform float star_twinkle : hint_range(0.0, 1.0) = 0.4;
uniform float star_rot = 0.0;
uniform float milky_way : hint_range(0.0, 1.0) = 0.0;
uniform vec3 moon_dir = vec3(0.0, 0.6, -0.8);
uniform float moon_phase : hint_range(0.0, 1.0) = 0.5;
uniform float moon_size = 0.045;
uniform vec3 moon_color : source_color = vec3(0.96, 0.95, 0.88);
uniform float moon_amount : hint_range(0.0, 1.0) = 0.0;
// 0 = day (LIGHT0 is the sun), 1 = night (LIGHT0 is moonlight: no sun disk).
uniform float night_mode : hint_range(0.0, 1.0) = 0.0;
// v6a glass-clear day: less horizon haze.
uniform float clarity : hint_range(0.0, 1.0) = 0.0;

float hash(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
			mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = rot * p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float h = dir.y;

	vec3 col = mix(horizon_color, zenith_color, pow(clamp(h, 0.0, 1.0), horizon_softness * mix(1.0, 0.6, clarity)));
	if (h < 0.0) {
		col = mix(horizon_color, ground_color, clamp(-h * 5.0, 0.0, 1.0));
		if (sea_blend > 0.0) {
			float side = smoothstep(-0.3, 0.3, dot(normalize(dir.xz + vec2(0.00001)), sea_dir));
			vec3 water = mix(horizon_color, sea_color, clamp(-h * sea_sharpness, 0.0, 1.0));
			col = mix(col, water, sea_blend * side);
		}
	}

	vec3 sun_col = vec3(0.0);
	float sun_amount = 0.0;
	if (LIGHT0_ENABLED) {
		float d = dot(dir, LIGHT0_DIRECTION);
		float disk = smoothstep(cos(sun_disk_size), cos(sun_disk_size * 0.6), d);
		float halo = pow(max(d, 0.0), 64.0) * 0.5 + pow(max(d, 0.0), 6.0) * 0.12;
		sun_amount = max(d, 0.0);
		sun_col = LIGHT0_COLOR * (disk * 40.0 + halo * sun_glow) * min(LIGHT0_ENERGY, 2.0);
		sun_col *= 1.0 - night_mode;
	}

	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.12) * cloud_scale + cloud_offset;
		float base = fbm(uv);
		float detail = fbm(uv * 3.1 + 4.0);
		float density = smoothstep(1.0 - cloud_coverage, 1.0 - cloud_coverage + 0.35, base * 0.8 + detail * 0.25);
		density *= smoothstep(0.0, 0.18, h);
		// Light the clouds: brighter toward the sun, grey undersides.
		float shade = mix(0.72, 1.0, smoothstep(0.35, 0.9, detail)) ;
		vec3 cloud_col = mix(vec3(0.66, 0.70, 0.76), vec3(1.0, 0.98, 0.95), shade) * cloud_brightness * cloud_tint;
		cloud_col += vec3(1.0, 0.9, 0.75) * pow(sun_amount, 8.0) * 0.4;
		// Stars (night only), hidden behind clouds. v6a: density / brightness /
		// slow rotation over the night + a Milky Way band (night_sky module).
		if (star_amount > 0.0) {
			float cr = cos(star_rot);
			float sr = sin(star_rot);
			vec3 sd = vec3(dir.x * cr - dir.z * sr, dir.y, dir.x * sr + dir.z * cr);
			vec3 p = sd * 170.0;
			vec3 cell = floor(p);
			vec3 f = fract(p) - 0.5;
			float rnd = fract(sin(dot(cell, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
			// Small points; a few bright stars, many faint ones (magnitudes).
			float mag = 0.25 + 0.75 * pow(fract(rnd * 53.0), 3.0);
			float star = step(1.0 - star_density, rnd) * smoothstep(0.24 + 0.12 * mag, 0.0, length(f)) * mag * 1.6;
			float tw = 1.0 - star_twinkle * 0.5 + star_twinkle * 0.5 * fract(rnd * 71.0);
			vec3 tint = mix(vec3(0.75, 0.82, 1.0), vec3(1.0, 0.9, 0.75), fract(rnd * 13.0));
			float fade = star_amount * (1.0 - density) * smoothstep(0.02, 0.2, h);
			col += tint * star * tw * fade * star_brightness;
			if (milky_way > 0.0) {
				vec3 n_mw = normalize(vec3(0.35, 0.45, 0.82));
				float band = exp(-pow(dot(sd, n_mw) / 0.2, 2.0));
				float dust = fbm(sd.xz * 6.0 + sd.y * 3.0);
				float speck = step(0.93, fract(sin(dot(floor(sd * 420.0), vec3(7.13, 157.1, 113.7))) * 43758.5)) * 0.6;
				col += vec3(0.62, 0.66, 0.85) * band * (dust * 0.16 + speck * 0.35) * milky_way * fade;
			}
		}
		// Moon with phases (lit fraction from moon_phase; 0 = new, 0.5 = full).
		if (moon_amount > 0.0) {
			vec3 md = normalize(moon_dir);
			float cosang = dot(dir, md);
			float ang = acos(clamp(cosang, -1.0, 1.0));
			if (ang < moon_size * 6.0) {
				vec3 right = normalize(cross(md, vec3(0.0, 1.0, 0.0)));
				vec3 up = cross(right, md);
				vec2 uv = vec2(dot(dir - md * cosang, right), dot(dir - md * cosang, up)) / sin(moon_size);
				float r2 = dot(uv, uv);
				float glow = exp(-ang / (moon_size * 1.6)) * 0.18;
				vec3 mcol = moon_color * glow;
				if (r2 < 1.0) {
					vec3 n = vec3(uv, sqrt(1.0 - r2));
					float phi = moon_phase * 6.2831853;
					vec3 L = vec3(sin(phi), 0.0, -cos(phi));
					float lit = smoothstep(-0.06, 0.12, dot(n, L));
					float maria = 0.78 + 0.22 * smoothstep(0.35, 0.7, fbm(uv * 3.0 + 7.0));
					float limb = smoothstep(1.0, 0.85, r2);
					mcol = moon_color * (lit * maria * 2.2 + 0.035) * limb;
					col *= 1.0 - limb * 0.9;
				}
				col += mcol * moon_amount * (1.0 - density * 0.85);
			}
		}
		col = mix(col, cloud_col, density * 0.92);
		sun_col *= 1.0 - density;
	}

	COLOR = col + sun_col;
}
