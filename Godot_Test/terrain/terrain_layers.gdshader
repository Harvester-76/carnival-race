shader_type spatial;
render_mode cull_disabled;

// Runtime-sized geological stack.
// Albedo and height maps are stored in Texture2DArray resources.
// Per-stratum parameters are packed into a 4xN RGBAF texture:
// x0=tint, x1=(uv_scale, roughness, metallic, thickness),
// x2=(transition, height_depth, normal_strength, parallax_steps),
// x3=(has_albedo, has_height, reserved, reserved).

uniform int layer_count = 1;
uniform float base_height_m = 0.0;
uniform vec3 slope_tint : source_color = vec3(0.66, 0.50, 0.36);
uniform float slope_tint_strength = 0.48;
uniform float steep_slope_darkening = 0.30;
uniform float triplanar_sharpness = 4.0;

uniform sampler2DArray layer_albedo_array : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2DArray layer_height_array : filter_linear_mipmap, repeat_enable;
uniform sampler2D layer_params : filter_nearest;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec4 layer_param(int layer, int column) {
	return texelFetch(layer_params, ivec2(column, layer), 0);
}

vec4 layer_info(int layer) {
	return layer_param(layer, 1);
}

vec4 layer_height_info(int layer) {
	return layer_param(layer, 2);
}

bool has_layer_albedo(int layer) {
	return layer_param(layer, 3).r > 0.5;
}

bool has_layer_height(int layer) {
	return layer_param(layer, 3).g > 0.5;
}

float sample_height(int layer, vec2 uv) {
	if (!has_layer_height(layer)) {
		return 0.5;
	}
	return texture(layer_height_array, vec3(uv, float(layer))).r;
}

vec3 sample_albedo(int layer, vec2 uv) {
	if (!has_layer_albedo(layer)) {
		return vec3(1.0);
	}
	return texture(layer_albedo_array, vec3(uv, float(layer))).rgb;
}

float sample_layer_thickness(int layer) {
	return max(layer_info(layer).a, 0.01);
}

float sample_layer_transition(int layer) {
	return max(layer_height_info(layer).r, 0.0);
}

float sample_layer_metallic(int layer) {
	return layer_info(layer).b;
}

// Parallax ray march in one planar projection. The ray travels away from the camera.
vec2 parallax_uv(int layer, vec2 uv, vec2 view_plane, float view_normal, float scale, float depth, int requested_steps) {
	if (!has_layer_height(layer) || depth <= 0.0001) {
		return uv;
	}
	int steps = clamp(requested_steps, 1, 8);
	float safe_normal = max(abs(view_normal), 0.20);
	vec2 total_offset = -view_plane * (depth * scale / safe_normal);
	vec2 step_uv = total_offset / float(steps);
	vec2 current_uv = uv;
	float ray_depth = 0.0;
	float sampled_height = 1.0 - sample_height(layer, current_uv);
	for (int j = 0; j < 8; j++) {
		if (j >= steps || ray_depth >= sampled_height) {
			break;
		}
		current_uv += step_uv;
		ray_depth += 1.0 / float(steps);
		sampled_height = 1.0 - sample_height(layer, current_uv);
	}
	return current_uv;
}

vec4 sample_layer(int layer, vec3 p, vec3 n, vec3 view_world, out vec3 mapped_normal) {
	vec3 weights = pow(abs(n), vec3(max(triplanar_sharpness, 1.0)));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);

	vec2 uv_x = p.zy;
	vec2 uv_y = p.xz;
	vec2 uv_z = p.xy;
	if (n.x < 0.0) uv_x.x = -uv_x.x;
	if (n.y < 0.0) uv_y.x = -uv_y.x;
	if (n.z > 0.0) uv_z.x = -uv_z.x;

	vec4 tint = layer_param(layer, 0);
	vec4 info = layer_info(layer);
	vec4 height_info = layer_height_info(layer);
	float scale = max(info.r, 0.000001);
	float roughness = info.g;
	float depth = height_info.g;
	float normal_strength = height_info.b;
	int steps = int(round(height_info.a));
	bool height_on = has_layer_height(layer);

	vec2 uvx = parallax_uv(layer, uv_x * scale, view_world.zy, view_world.x, scale, depth, steps);
	vec2 uvy = parallax_uv(layer, uv_y * scale, view_world.xz, view_world.y, scale, depth, steps);
	vec2 uvz = parallax_uv(layer, uv_z * scale, view_world.xy, view_world.z, scale, depth, steps);

	vec3 tex_x = sample_albedo(layer, uvx);
	vec3 tex_y = sample_albedo(layer, uvy);
	vec3 tex_z = sample_albedo(layer, uvz);
	vec3 albedo = tint.rgb * (tex_x * weights.x + tex_y * weights.y + tex_z * weights.z);

	mapped_normal = n;
	if (height_on && normal_strength > 0.0) {
		vec2 texel_size = 1.0 / vec2(textureSize(layer_height_array, 0).xy);
		float eps = max(max(texel_size.x, texel_size.y) * 2.0, 0.0005);

		float hx0 = sample_height(layer, uvx - vec2(eps, 0.0));
		float hx1 = sample_height(layer, uvx + vec2(eps, 0.0));
		float hy0 = sample_height(layer, uvx - vec2(0.0, eps));
		float hy1 = sample_height(layer, uvx + vec2(0.0, eps));
		float gx = (hx1 - hx0) / (2.0 * eps);
		float gy = (hy1 - hy0) / (2.0 * eps);
		vec3 nx = normalize(vec3(sign(n.x), -gy * normal_strength * 0.025, -gx * normal_strength * 0.025));

		float hx0y = sample_height(layer, uvy - vec2(eps, 0.0));
		float hx1y = sample_height(layer, uvy + vec2(eps, 0.0));
		float hy0y = sample_height(layer, uvy - vec2(0.0, eps));
		float hy1y = sample_height(layer, uvy + vec2(0.0, eps));
		float gyx = (hx1y - hx0y) / (2.0 * eps);
		float gyy = (hy1y - hy0y) / (2.0 * eps);
		vec3 ny = normalize(vec3(-gyx * normal_strength * 0.025, sign(n.y), -gyy * normal_strength * 0.025));

		float hx0z = sample_height(layer, uvz - vec2(eps, 0.0));
		float hx1z = sample_height(layer, uvz + vec2(eps, 0.0));
		float hy0z = sample_height(layer, uvz - vec2(0.0, eps));
		float hy1z = sample_height(layer, uvz + vec2(0.0, eps));
		float gzx = (hx1z - hx0z) / (2.0 * eps);
		float gzy = (hy1z - hy0z) / (2.0 * eps);
		vec3 nz = normalize(vec3(-gzx * normal_strength * 0.025, -gzy * normal_strength * 0.025, sign(n.z)));

		mapped_normal = normalize(nx * weights.x + ny * weights.y + nz * weights.z);
	}
	return vec4(albedo, roughness);
}

vec4 sample_stack(float height_m, vec3 p, vec3 n, vec3 view_world, out float metallic, out vec3 mapped_normal) {
	int count = max(layer_count, 1);
	float cursor = base_height_m;

	for (int i = 0; i < layer_count - 1; i++) {
		if (i >= count - 1) {
			break;
		}
		float boundary = cursor + sample_layer_thickness(i);
		float width = sample_layer_transition(i);
		if (height_m < boundary + width * 0.5) {
			float blend = width <= 0.0
				? step(boundary, height_m)
				: smoothstep(boundary - width * 0.5, boundary + width * 0.5, height_m);
			vec3 lower_normal;
			vec3 upper_normal;
			vec4 lower = sample_layer(i, p, n, view_world, lower_normal);
			vec4 upper = sample_layer(i + 1, p, n, view_world, upper_normal);
			metallic = mix(sample_layer_metallic(i), sample_layer_metallic(i + 1), blend);
			mapped_normal = normalize(mix(lower_normal, upper_normal, blend));
			return mix(lower, upper, blend);
		}
		cursor = boundary;
	}
	int last_layer = count - 1;
	metallic = sample_layer_metallic(last_layer);
	return sample_layer(last_layer, p, n, view_world, mapped_normal);
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 view_world = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	float metallic;
	vec3 mapped_normal;
	vec4 surface = sample_stack(world_position.y, world_position, n, view_world, metallic, mapped_normal);

	float flat_surface = smoothstep(0.55, 0.95, clamp(mapped_normal.y, 0.0, 1.0));
	ALBEDO = mix(surface.rgb, slope_tint, flat_surface * slope_tint_strength);
	ALBEDO *= mix(1.0 - steep_slope_darkening, 1.0, clamp(mapped_normal.y, 0.0, 1.0));
	NORMAL = normalize((VIEW_MATRIX * vec4(mapped_normal, 0.0)).xyz);
	ROUGHNESS = surface.a;
	METALLIC = metallic;
}
