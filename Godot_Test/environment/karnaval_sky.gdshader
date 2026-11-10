shader_type sky;

uniform sampler2D sky_base : source_color, filter_linear, repeat_enable;
uniform sampler2D clouds_far_mask : filter_linear, repeat_enable;
uniform sampler2D clouds_near_mask : filter_linear, repeat_enable;
uniform sampler2D atmosphere_noise : filter_linear, repeat_enable;
uniform sampler2D star_disc : source_color, filter_linear, repeat_disable;

group_uniforms Atmosphere;
uniform vec3 sky_tint : source_color = vec3(1.0, 0.8, 0.48);
uniform float haze_strength : hint_range(0.0, 2.0, 0.01) = 0.65;
uniform vec3 haze_color : source_color = vec3(0.95, 0.56, 0.27);
uniform vec2 atmosphere_drift_velocity = vec2(0.0007, -0.0004);

group_uniforms Clouds;
uniform float cloud_far_density : hint_range(0.0, 1.0, 0.001) = 0.36;
uniform float cloud_mid_density : hint_range(0.0, 1.0, 0.001) = 0.40;
uniform float cloud_near_density : hint_range(0.0, 1.0, 0.001) = 0.46;
uniform float cloud_detail_density : hint_range(0.0, 1.0, 0.001) = 0.34;
uniform float cloud_far_repeats : hint_range(1.0, 8.0, 1.0) = 1.0;
uniform float cloud_mid_repeats : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float cloud_near_repeats : hint_range(1.0, 8.0, 1.0) = 2.0;
uniform float cloud_detail_repeats : hint_range(1.0, 8.0, 0.1) = 3.0;
uniform float cloud_contrast : hint_range(0.2, 2.0, 0.001) = 1.0;
uniform float cloud_far_speed : hint_range(0.0, 0.1, 0.00001) = 0.002;
uniform float cloud_mid_speed : hint_range(0.0, 0.1, 0.00001) = 0.0035;
uniform float cloud_near_speed : hint_range(0.0, 0.1, 0.00001) = 0.006;
uniform float cloud_detail_speed : hint_range(0.0, 0.1, 0.00001) = 0.009;
uniform float cloud_far_depth_km : hint_range(50.0, 2000.0, 1.0) = 700.0;
uniform float cloud_mid_depth_km : hint_range(50.0, 2000.0, 1.0) = 420.0;
uniform float cloud_near_depth_km : hint_range(50.0, 2000.0, 1.0) = 220.0;
uniform float cloud_detail_depth_km : hint_range(50.0, 2000.0, 1.0) = 110.0;
uniform float wind_direction : hint_range(-3.141593, 3.141593, 0.001) = 0.0;
uniform float cloud_pole_fade_start : hint_range(0.0, 1.0, 0.001) = 0.62;
uniform float cloud_pole_fade_end : hint_range(0.0, 1.0, 0.001) = 0.88;
uniform float cloud_sky_opacity_far : hint_range(0.0, 1.0, 0.001) = 0.36;
uniform float cloud_sky_opacity_mid : hint_range(0.0, 1.0, 0.001) = 0.22;
uniform float cloud_sky_opacity_near : hint_range(0.0, 1.0, 0.001) = 0.58;
uniform float cloud_sky_opacity_detail : hint_range(0.0, 1.0, 0.001) = 0.14;
uniform float cloud_cover_opacity_far : hint_range(0.0, 1.0, 0.001) = 0.55;
uniform float cloud_cover_opacity_mid : hint_range(0.0, 1.0, 0.001) = 0.42;
uniform float cloud_cover_opacity_near : hint_range(0.0, 1.0, 0.001) = 0.72;
uniform float cloud_cover_opacity_detail : hint_range(0.0, 1.0, 0.001) = 0.32;
uniform vec2 cloud_far_offset = vec2(0.0);
uniform vec2 cloud_mid_offset = vec2(0.0);
uniform vec2 cloud_near_offset = vec2(0.0);
uniform vec2 cloud_detail_offset = vec2(0.0);
uniform vec2 atmosphere_offset = vec2(0.0);

group_uniforms Star;
uniform float star_size : hint_range(0.005, 0.2, 0.001) = 0.055;
uniform float star_intensity : hint_range(0.0, 4.0, 0.001) = 1.15;
uniform float star_halo_strength : hint_range(0.0, 3.0, 0.001) = 0.8;
uniform vec3 star_direction = vec3(0.42, 0.55, 0.72);

const float K_PI = 3.14159265359;

vec2 direction_uv(vec3 direction) {
	return vec2(atan(direction.x, direction.z) / (2.0 * K_PI) + 0.5,
		acos(clamp(direction.y, -1.0, 1.0)) / K_PI);
}

float layer_density(float sample_value, float density) {
	float threshold = 0.86 - density * 0.62;
	float softness = 0.20 / max(cloud_contrast, 0.2);
	return smoothstep(threshold, threshold + softness, sample_value);
}

vec2 cloud_uv(vec3 direction, float repeats, vec2 offset, float depth_km) {
	// Spherical latitude/longitude keeps cloud proportions stable at the horizon.
	// Integer repeats make the longitude wrap seamless; pole fading hides the
	// unavoidable longitude singularity at the zenith and nadir.
	vec2 uv = direction_uv(normalize(direction));
	// POSITION adds horizontal parallax: the four copies represent cloud fields
	// at distinct apparent distances while retaining the same vertical coverage.
	float track_axis = POSITION.z + POSITION.x * 0.37;
	float depth_parallax = track_axis / max(depth_km * 1000.0, 1.0);
	return uv * repeats + offset - vec2(depth_parallax, 0.0);
}

float cloud_cover(vec3 direction) {
	vec3 sample_direction = normalize(direction);
	vec2 far_uv = cloud_uv(sample_direction, cloud_far_repeats, cloud_far_offset, cloud_far_depth_km);
	vec2 mid_uv = cloud_uv(sample_direction, cloud_mid_repeats, cloud_mid_offset, cloud_mid_depth_km);
	vec2 near_uv = cloud_uv(sample_direction, cloud_near_repeats, cloud_near_offset, cloud_near_depth_km);
	vec2 detail_uv = cloud_uv(sample_direction, cloud_detail_repeats, cloud_detail_offset, cloud_detail_depth_km);
	float far_value = texture(clouds_far_mask, far_uv).r;
	float near_value = texture(clouds_near_mask, near_uv).r;
	float pole_fade = 1.0 - smoothstep(cloud_pole_fade_start, cloud_pole_fade_end, abs(sample_direction.y));
	float far_cover = layer_density(far_value, cloud_far_density) * cloud_cover_opacity_far * pole_fade;
	float mid_cover = layer_density(texture(clouds_near_mask, mid_uv).r, cloud_mid_density) * cloud_cover_opacity_mid * pole_fade;
	float near_cover = layer_density(near_value, cloud_near_density) * cloud_cover_opacity_near * pole_fade;
	float detail_cover = layer_density(texture(clouds_far_mask, detail_uv).r, cloud_detail_density) * cloud_cover_opacity_detail * pole_fade;
	return 1.0 - (1.0 - far_cover) * (1.0 - mid_cover) * (1.0 - near_cover) * (1.0 - detail_cover);
}

void sky() {
	vec3 view_dir = normalize(EYEDIR);
	vec2 uv = direction_uv(view_dir);
	uv.y = clamp(uv.y, 0.001, 0.999);
	float vertical_light = 0.88 + 0.22 * smoothstep(-0.18, 0.82, view_dir.y);
	vec3 base = texture(sky_base, uv).rgb * sky_tint * vertical_light;
	vec2 noise_uv = view_dir.xz * vec2(1.5, 1.0) + vec2(0.5) + atmosphere_offset;
	float noise_value = texture(atmosphere_noise, noise_uv).r;
	float horizon = pow(1.0 - abs(view_dir.y), 3.2);
	float haze = clamp(haze_strength * horizon * (0.82 + noise_value * 0.24), 0.0, 1.0);
	vec3 color = mix(base, haze_color, haze * 0.48);

	vec2 far_uv = cloud_uv(view_dir, cloud_far_repeats, cloud_far_offset, cloud_far_depth_km);
	vec2 mid_uv = cloud_uv(view_dir, cloud_mid_repeats, cloud_mid_offset, cloud_mid_depth_km);
	vec2 near_uv = cloud_uv(view_dir, cloud_near_repeats, cloud_near_offset, cloud_near_depth_km);
	vec2 detail_uv = cloud_uv(view_dir, cloud_detail_repeats, cloud_detail_offset, cloud_detail_depth_km);
	float pole_fade = 1.0 - smoothstep(cloud_pole_fade_start, cloud_pole_fade_end, abs(view_dir.y));
	float far_cover = layer_density(texture(clouds_far_mask, far_uv).r, cloud_far_density) * cloud_sky_opacity_far * pole_fade;
	float mid_cover = layer_density(texture(clouds_near_mask, mid_uv).r, cloud_mid_density) * cloud_sky_opacity_mid * pole_fade;
	float near_cover = layer_density(texture(clouds_near_mask, near_uv).r, cloud_near_density) * cloud_sky_opacity_near * pole_fade;
	float detail_cover = layer_density(texture(clouds_far_mask, detail_uv).r, cloud_detail_density) * cloud_sky_opacity_detail * pole_fade;
	float cover = 1.0 - (1.0 - far_cover) * (1.0 - mid_cover) * (1.0 - near_cover) * (1.0 - detail_cover);
	float cloud_variation = 0.88 + noise_value * 0.18;
	vec3 cloud_color = mix(haze_color, vec3(1.0, 0.68, 0.38), 0.26);
	color = mix(color, cloud_color * cloud_variation, cover);

	// The directional-light built-in points from the scene toward the light
	// source, so the visible star stays aligned with the actual scene sun.
	vec3 star_dir = normalize(star_direction);
	if (LIGHT0_ENABLED) {
		star_dir = normalize(LIGHT0_DIRECTION);
	}
	float alignment = dot(view_dir, star_dir);
	float star_angle = acos(clamp(alignment, -1.0, 1.0));
	if (star_angle < star_size * 3.5) {
		float star_clouds = cloud_cover(star_dir);
		float visibility = 1.0 - smoothstep(0.12, 0.88, star_clouds);
		float halo_edge = 1.0 - smoothstep(star_size * 2.6, star_size * 3.5, star_angle);
		float halo = exp(-star_angle / max(star_size * 0.8, 0.0001)) * star_halo_strength * halo_edge;
		color += vec3(1.0, 0.43, 0.14) * halo * visibility * 0.55;
	}
	if (alignment > cos(star_size * 1.8)) {
		vec3 reference_up = vec3(0.0, 1.0, 0.0);
		vec3 star_right = normalize(cross(reference_up, star_dir));
		vec3 star_up = normalize(cross(star_dir, star_right));
		float forward = max(alignment, 0.0001);
		vec2 projected = vec2(dot(view_dir, star_right), dot(view_dir, star_up)) / forward;
		vec2 star_uv = projected / (2.0 * tan(star_size)) + vec2(0.5);
		if (all(greaterThanEqual(star_uv, vec2(0.0))) && all(lessThanEqual(star_uv, vec2(1.0)))) {
			vec4 star = texture(star_disc, star_uv);
			float star_clouds = cloud_cover(star_dir);
			float visibility = 1.0 - smoothstep(0.12, 0.88, star_clouds);
			color += star.rgb * star.a * star_intensity * visibility;
		}
	}

	COLOR = color;
}
