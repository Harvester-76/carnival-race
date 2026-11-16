shader_type spatial;
render_mode cull_disabled;

// World-space triplanar material stack. Height is sampled from each layer's
// StandardMaterial3D.heightmap_texture and never changes mesh geometry.
uniform int layer_count = 8;
uniform float base_height_m = 0.0;
uniform vec3 slope_tint : source_color = vec3(0.66, 0.50, 0.36);
uniform float slope_tint_strength = 0.48;
uniform float steep_slope_darkening = 0.30;
uniform float triplanar_sharpness = 4.0;

uniform vec4 layer_tint_0 : source_color = vec4(1.0);
uniform sampler2D layer_texture_0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_0 = false;
uniform float layer_uv_scale_0 = 0.01;
uniform float layer_roughness_0 = 0.95;
uniform float layer_metallic_0 = 0.0;
uniform float layer_thickness_0 = 700.0;
uniform float layer_transition_0 = 90.0;
uniform sampler2D layer_height_texture_0 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_0 = false;
uniform float layer_height_depth_0 = 0.0;
uniform float layer_height_normal_strength_0 = 1.0;
uniform int layer_parallax_steps_0 = 6;
uniform vec4 layer_tint_1 : source_color = vec4(1.0);
uniform sampler2D layer_texture_1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_1 = false;
uniform float layer_uv_scale_1 = 0.01;
uniform float layer_roughness_1 = 0.95;
uniform float layer_metallic_1 = 0.0;
uniform float layer_thickness_1 = 700.0;
uniform float layer_transition_1 = 90.0;
uniform sampler2D layer_height_texture_1 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_1 = false;
uniform float layer_height_depth_1 = 0.0;
uniform float layer_height_normal_strength_1 = 1.0;
uniform int layer_parallax_steps_1 = 6;
uniform vec4 layer_tint_2 : source_color = vec4(1.0);
uniform sampler2D layer_texture_2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_2 = false;
uniform float layer_uv_scale_2 = 0.01;
uniform float layer_roughness_2 = 0.95;
uniform float layer_metallic_2 = 0.0;
uniform float layer_thickness_2 = 700.0;
uniform float layer_transition_2 = 90.0;
uniform sampler2D layer_height_texture_2 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_2 = false;
uniform float layer_height_depth_2 = 0.0;
uniform float layer_height_normal_strength_2 = 1.0;
uniform int layer_parallax_steps_2 = 6;
uniform vec4 layer_tint_3 : source_color = vec4(1.0);
uniform sampler2D layer_texture_3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_3 = false;
uniform float layer_uv_scale_3 = 0.01;
uniform float layer_roughness_3 = 0.95;
uniform float layer_metallic_3 = 0.0;
uniform float layer_thickness_3 = 700.0;
uniform float layer_transition_3 = 90.0;
uniform sampler2D layer_height_texture_3 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_3 = false;
uniform float layer_height_depth_3 = 0.0;
uniform float layer_height_normal_strength_3 = 1.0;
uniform int layer_parallax_steps_3 = 6;
uniform vec4 layer_tint_4 : source_color = vec4(1.0);
uniform sampler2D layer_texture_4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_4 = false;
uniform float layer_uv_scale_4 = 0.01;
uniform float layer_roughness_4 = 0.95;
uniform float layer_metallic_4 = 0.0;
uniform float layer_thickness_4 = 700.0;
uniform float layer_transition_4 = 90.0;
uniform sampler2D layer_height_texture_4 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_4 = false;
uniform float layer_height_depth_4 = 0.0;
uniform float layer_height_normal_strength_4 = 1.0;
uniform int layer_parallax_steps_4 = 6;
uniform vec4 layer_tint_5 : source_color = vec4(1.0);
uniform sampler2D layer_texture_5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_5 = false;
uniform float layer_uv_scale_5 = 0.01;
uniform float layer_roughness_5 = 0.95;
uniform float layer_metallic_5 = 0.0;
uniform float layer_thickness_5 = 700.0;
uniform float layer_transition_5 = 90.0;
uniform sampler2D layer_height_texture_5 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_5 = false;
uniform float layer_height_depth_5 = 0.0;
uniform float layer_height_normal_strength_5 = 1.0;
uniform int layer_parallax_steps_5 = 6;
uniform vec4 layer_tint_6 : source_color = vec4(1.0);
uniform sampler2D layer_texture_6 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_6 = false;
uniform float layer_uv_scale_6 = 0.01;
uniform float layer_roughness_6 = 0.95;
uniform float layer_metallic_6 = 0.0;
uniform float layer_thickness_6 = 700.0;
uniform float layer_transition_6 = 90.0;
uniform sampler2D layer_height_texture_6 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_6 = false;
uniform float layer_height_depth_6 = 0.0;
uniform float layer_height_normal_strength_6 = 1.0;
uniform int layer_parallax_steps_6 = 6;
uniform vec4 layer_tint_7 : source_color = vec4(1.0);
uniform sampler2D layer_texture_7 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_7 = false;
uniform float layer_uv_scale_7 = 0.01;
uniform float layer_roughness_7 = 0.95;
uniform float layer_metallic_7 = 0.0;
uniform float layer_thickness_7 = 700.0;
uniform float layer_transition_7 = 90.0;
uniform sampler2D layer_height_texture_7 : filter_linear_mipmap, repeat_enable;
uniform bool layer_has_height_7 = false;
uniform float layer_height_depth_7 = 0.0;
uniform float layer_height_normal_strength_7 = 1.0;
uniform int layer_parallax_steps_7 = 6;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

bool layer_has_height(int index) {
	if (index == 0) return layer_has_height_0;
	if (index == 1) return layer_has_height_1;
	if (index == 2) return layer_has_height_2;
	if (index == 3) return layer_has_height_3;
	if (index == 4) return layer_has_height_4;
	if (index == 5) return layer_has_height_5;
	if (index == 6) return layer_has_height_6;
	return layer_has_height_7;
}

float sample_height(int index, vec2 uv) {
	if (index == 0) { if (layer_has_height_0) return texture(layer_height_texture_0, uv).r; return 0.5; }
	if (index == 1) { if (layer_has_height_1) return texture(layer_height_texture_1, uv).r; return 0.5; }
	if (index == 2) { if (layer_has_height_2) return texture(layer_height_texture_2, uv).r; return 0.5; }
	if (index == 3) { if (layer_has_height_3) return texture(layer_height_texture_3, uv).r; return 0.5; }
	if (index == 4) { if (layer_has_height_4) return texture(layer_height_texture_4, uv).r; return 0.5; }
	if (index == 5) { if (layer_has_height_5) return texture(layer_height_texture_5, uv).r; return 0.5; }
	if (index == 6) { if (layer_has_height_6) return texture(layer_height_texture_6, uv).r; return 0.5; }
	if (index == 7) { if (layer_has_height_7) return texture(layer_height_texture_7, uv).r; return 0.5; }
	return 0.5;
}

vec3 sample_albedo(int index, vec2 uv) {
	if (index == 0) { if (layer_has_texture_0) return texture(layer_texture_0, uv).rgb; return vec3(1.0); }
	if (index == 1) { if (layer_has_texture_1) return texture(layer_texture_1, uv).rgb; return vec3(1.0); }
	if (index == 2) { if (layer_has_texture_2) return texture(layer_texture_2, uv).rgb; return vec3(1.0); }
	if (index == 3) { if (layer_has_texture_3) return texture(layer_texture_3, uv).rgb; return vec3(1.0); }
	if (index == 4) { if (layer_has_texture_4) return texture(layer_texture_4, uv).rgb; return vec3(1.0); }
	if (index == 5) { if (layer_has_texture_5) return texture(layer_texture_5, uv).rgb; return vec3(1.0); }
	if (index == 6) { if (layer_has_texture_6) return texture(layer_texture_6, uv).rgb; return vec3(1.0); }
	if (index == 7) { if (layer_has_texture_7) return texture(layer_texture_7, uv).rgb; return vec3(1.0); }
	return vec3(1.0);
}

float sample_layer_thickness(int index) {
	if (index == 0) return layer_thickness_0;
	if (index == 1) return layer_thickness_1;
	if (index == 2) return layer_thickness_2;
	if (index == 3) return layer_thickness_3;
	if (index == 4) return layer_thickness_4;
	if (index == 5) return layer_thickness_5;
	if (index == 6) return layer_thickness_6;
	return layer_thickness_7;
}

float sample_layer_transition(int index) {
	if (index == 0) return layer_transition_0;
	if (index == 1) return layer_transition_1;
	if (index == 2) return layer_transition_2;
	if (index == 3) return layer_transition_3;
	if (index == 4) return layer_transition_4;
	if (index == 5) return layer_transition_5;
	if (index == 6) return layer_transition_6;
	return layer_transition_7;
}

float sample_layer_metallic(int index) {
	if (index == 0) return layer_metallic_0;
	if (index == 1) return layer_metallic_1;
	if (index == 2) return layer_metallic_2;
	if (index == 3) return layer_metallic_3;
	if (index == 4) return layer_metallic_4;
	if (index == 5) return layer_metallic_5;
	if (index == 6) return layer_metallic_6;
	return layer_metallic_7;
}

// Parallax ray march in one planar projection. View vector points from the
// fragment toward the camera; the ray travels in the opposite direction.
vec2 parallax_uv(int index, vec2 uv, vec2 view_plane, float view_normal, float scale, float depth, int requested_steps) {
	if (!layer_has_height(index) || depth <= 0.0001) return uv;
	int steps = clamp(requested_steps, 1, 8);
	float safe_normal = max(abs(view_normal), 0.20);
	vec2 total_offset = -view_plane * (depth * scale / safe_normal);
	float step_depth = 1.0 / float(steps);
	vec2 step_uv = total_offset * step_depth;
	vec2 current_uv = uv;
	float ray_depth = 0.0;
	float sampled_height = 1.0 - sample_height(index, current_uv);
	for (int j = 0; j < 8; j++) {
		if (j >= steps || ray_depth >= sampled_height) break;
		current_uv += step_uv;
		ray_depth += step_depth;
		sampled_height = 1.0 - sample_height(index, current_uv);
	}
	return current_uv;
}

vec4 sample_layer(int index, vec3 p, vec3 n, vec3 view_world, out vec3 mapped_normal) {
	vec3 weights = pow(abs(n), vec3(max(triplanar_sharpness, 1.0)));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);

	vec2 uv_x = p.zy;
	vec2 uv_y = p.xz;
	vec2 uv_z = p.xy;
	if (n.x < 0.0) uv_x.x = -uv_x.x;
	if (n.y < 0.0) uv_y.x = -uv_y.x;
	if (n.z > 0.0) uv_z.x = -uv_z.x;

	float scale = 0.01;
	vec3 tint = vec3(1.0);
	float roughness = 0.95;
	bool height_on = false;
	float depth = 0.0;
	float normal_strength = 1.0;
	int steps = 6;
	if (index == 0) {
		scale = layer_uv_scale_0; tint = layer_tint_0.rgb; roughness = layer_roughness_0;
		height_on = layer_has_height_0; depth = layer_height_depth_0;
		normal_strength = layer_height_normal_strength_0; steps = layer_parallax_steps_0;
	}
	else if (index == 1) {
		scale = layer_uv_scale_1; tint = layer_tint_1.rgb; roughness = layer_roughness_1;
		height_on = layer_has_height_1; depth = layer_height_depth_1;
		normal_strength = layer_height_normal_strength_1; steps = layer_parallax_steps_1;
	}
	else if (index == 2) {
		scale = layer_uv_scale_2; tint = layer_tint_2.rgb; roughness = layer_roughness_2;
		height_on = layer_has_height_2; depth = layer_height_depth_2;
		normal_strength = layer_height_normal_strength_2; steps = layer_parallax_steps_2;
	}
	else if (index == 3) {
		scale = layer_uv_scale_3; tint = layer_tint_3.rgb; roughness = layer_roughness_3;
		height_on = layer_has_height_3; depth = layer_height_depth_3;
		normal_strength = layer_height_normal_strength_3; steps = layer_parallax_steps_3;
	}
	else if (index == 4) {
		scale = layer_uv_scale_4; tint = layer_tint_4.rgb; roughness = layer_roughness_4;
		height_on = layer_has_height_4; depth = layer_height_depth_4;
		normal_strength = layer_height_normal_strength_4; steps = layer_parallax_steps_4;
	}
	else if (index == 5) {
		scale = layer_uv_scale_5; tint = layer_tint_5.rgb; roughness = layer_roughness_5;
		height_on = layer_has_height_5; depth = layer_height_depth_5;
		normal_strength = layer_height_normal_strength_5; steps = layer_parallax_steps_5;
	}
	else if (index == 6) {
		scale = layer_uv_scale_6; tint = layer_tint_6.rgb; roughness = layer_roughness_6;
		height_on = layer_has_height_6; depth = layer_height_depth_6;
		normal_strength = layer_height_normal_strength_6; steps = layer_parallax_steps_6;
	}
	else if (index == 7) {
		scale = layer_uv_scale_7; tint = layer_tint_7.rgb; roughness = layer_roughness_7;
		height_on = layer_has_height_7; depth = layer_height_depth_7;
		normal_strength = layer_height_normal_strength_7; steps = layer_parallax_steps_7;
	}

	vec2 uvx = uv_x * scale;
	vec2 uvy = uv_y * scale;
	vec2 uvz = uv_z * scale;
	uvx = parallax_uv(index, uvx, view_world.zy, view_world.x, scale, depth, steps);
	uvy = parallax_uv(index, uvy, view_world.xz, view_world.y, scale, depth, steps);
	uvz = parallax_uv(index, uvz, view_world.xy, view_world.z, scale, depth, steps);

	vec3 tex_x = sample_albedo(index, uvx);
	vec3 tex_y = sample_albedo(index, uvy);
	vec3 tex_z = sample_albedo(index, uvz);
	vec3 albedo = tint * (tex_x * weights.x + tex_y * weights.y + tex_z * weights.z);

	mapped_normal = n;
	if (height_on && normal_strength > 0.0) {
		vec2 texel_x = 1.0 / vec2(textureSize(layer_height_texture_0, 0));
		if (index == 1) texel_x = 1.0 / vec2(textureSize(layer_height_texture_1, 0));
		else if (index == 2) texel_x = 1.0 / vec2(textureSize(layer_height_texture_2, 0));
		else if (index == 3) texel_x = 1.0 / vec2(textureSize(layer_height_texture_3, 0));
		else if (index == 4) texel_x = 1.0 / vec2(textureSize(layer_height_texture_4, 0));
		else if (index == 5) texel_x = 1.0 / vec2(textureSize(layer_height_texture_5, 0));
		else if (index == 6) texel_x = 1.0 / vec2(textureSize(layer_height_texture_6, 0));
		else if (index == 7) texel_x = 1.0 / vec2(textureSize(layer_height_texture_7, 0));
		float eps = max(max(texel_x.x, texel_x.y) * 2.0, 0.0005);
		float hx0 = sample_height(index, uvx - vec2(eps, 0.0));
		float hx1 = sample_height(index, uvx + vec2(eps, 0.0));
		float hy0 = sample_height(index, uvx - vec2(0.0, eps));
		float hy1 = sample_height(index, uvx + vec2(0.0, eps));
		float gx = (hx1 - hx0) / (2.0 * eps);
		float gy = (hy1 - hy0) / (2.0 * eps);
		vec3 nx = normalize(vec3(sign(n.x), -gy * normal_strength * 0.025, -gx * normal_strength * 0.025));
		float hx0y = sample_height(index, uvy - vec2(eps, 0.0));
		float hx1y = sample_height(index, uvy + vec2(eps, 0.0));
		float hy0y = sample_height(index, uvy - vec2(0.0, eps));
		float hy1y = sample_height(index, uvy + vec2(0.0, eps));
		float gyx = (hx1y - hx0y) / (2.0 * eps);
		float gyy = (hy1y - hy0y) / (2.0 * eps);
		vec3 ny = normalize(vec3(-gyx * normal_strength * 0.025, sign(n.y), -gyy * normal_strength * 0.025));
		float hx0z = sample_height(index, uvz - vec2(eps, 0.0));
		float hx1z = sample_height(index, uvz + vec2(eps, 0.0));
		float hy0z = sample_height(index, uvz - vec2(0.0, eps));
		float hy1z = sample_height(index, uvz + vec2(0.0, eps));
		float gzx = (hx1z - hx0z) / (2.0 * eps);
		float gzy = (hy1z - hy0z) / (2.0 * eps);
		vec3 nz = normalize(vec3(-gzx * normal_strength * 0.025, -gzy * normal_strength * 0.025, sign(n.z)));
		mapped_normal = normalize(nx * weights.x + ny * weights.y + nz * weights.z);
	}
	return vec4(albedo, roughness);
}

vec4 sample_stack(float height_m, vec3 p, vec3 n, vec3 view_world, out float metallic, out vec3 mapped_normal) {
	int count = clamp(layer_count, 1, 8);
	float cursor = base_height_m;
	for (int i = 0; i < 7; i++) {
		if (i >= count - 1) break;
		float boundary = cursor + max(sample_layer_thickness(i), 0.01);
		float width = max(sample_layer_transition(i), 0.0);
		if (height_m < boundary + width * 0.5) {
			float blend = width <= 0.0 ? step(boundary, height_m) : smoothstep(boundary - width * 0.5, boundary + width * 0.5, height_m);
			vec3 lower_normal; vec3 upper_normal;
			vec4 lower = sample_layer(i, p, n, view_world, lower_normal);
			vec4 upper = sample_layer(i + 1, p, n, view_world, upper_normal);
			metallic = mix(sample_layer_metallic(i), sample_layer_metallic(i + 1), blend);
			mapped_normal = normalize(mix(lower_normal, upper_normal, blend));
			return mix(lower, upper, blend);
		}
		cursor = boundary;
	}
	metallic = sample_layer_metallic(count - 1);
	return sample_layer(count - 1, p, n, view_world, mapped_normal);
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
