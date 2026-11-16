shader_type spatial;
render_mode cull_disabled;

// Configured bottom-to-top by TerrainLayerStack.
// Geometry has no UVs: all texture coordinates are derived from world position.
uniform int layer_count = 8;
uniform float base_height_m = 0.0;
uniform vec3 slope_tint : source_color = vec3(0.66, 0.50, 0.36);
uniform float slope_tint_strength = 0.48;
uniform float steep_slope_darkening = 0.30;
uniform float triplanar_sharpness = 4.0;

uniform vec4 layer_tint_0 : source_color = vec4(0.28, 0.18, 0.13, 1.0);
uniform sampler2D layer_texture_0 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_0 = false;
uniform float layer_uv_scale_0 = 0.05;
uniform float layer_roughness_0 = 0.95;
uniform float layer_metallic_0 = 0.0;
uniform float layer_thickness_0 = 700.0;
uniform float layer_transition_0 = 90.0;

uniform vec4 layer_tint_1 : source_color = vec4(0.38, 0.22, 0.15, 1.0);
uniform sampler2D layer_texture_1 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_1 = false;
uniform float layer_uv_scale_1 = 0.05;
uniform float layer_roughness_1 = 0.95;
uniform float layer_metallic_1 = 0.0;
uniform float layer_thickness_1 = 700.0;
uniform float layer_transition_1 = 90.0;

uniform vec4 layer_tint_2 : source_color = vec4(0.51, 0.28, 0.18, 1.0);
uniform sampler2D layer_texture_2 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_2 = false;
uniform float layer_uv_scale_2 = 0.05;
uniform float layer_roughness_2 = 0.95;
uniform float layer_metallic_2 = 0.0;
uniform float layer_thickness_2 = 700.0;
uniform float layer_transition_2 = 90.0;

uniform vec4 layer_tint_3 : source_color = vec4(0.64, 0.36, 0.23, 1.0);
uniform sampler2D layer_texture_3 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_3 = false;
uniform float layer_uv_scale_3 = 0.05;
uniform float layer_roughness_3 = 0.95;
uniform float layer_metallic_3 = 0.0;
uniform float layer_thickness_3 = 700.0;
uniform float layer_transition_3 = 90.0;

uniform vec4 layer_tint_4 : source_color = vec4(0.70, 0.43, 0.29, 1.0);
uniform sampler2D layer_texture_4 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_4 = false;
uniform float layer_uv_scale_4 = 0.05;
uniform float layer_roughness_4 = 0.95;
uniform float layer_metallic_4 = 0.0;
uniform float layer_thickness_4 = 700.0;
uniform float layer_transition_4 = 90.0;

uniform vec4 layer_tint_5 : source_color = vec4(0.76, 0.54, 0.37, 1.0);
uniform sampler2D layer_texture_5 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_5 = false;
uniform float layer_uv_scale_5 = 0.05;
uniform float layer_roughness_5 = 0.95;
uniform float layer_metallic_5 = 0.0;
uniform float layer_thickness_5 = 700.0;
uniform float layer_transition_5 = 90.0;

uniform vec4 layer_tint_6 : source_color = vec4(0.81, 0.66, 0.48, 1.0);
uniform sampler2D layer_texture_6 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_6 = false;
uniform float layer_uv_scale_6 = 0.05;
uniform float layer_roughness_6 = 0.95;
uniform float layer_metallic_6 = 0.0;
uniform float layer_thickness_6 = 700.0;
uniform float layer_transition_6 = 90.0;

uniform vec4 layer_tint_7 : source_color = vec4(0.86, 0.77, 0.61, 1.0);
uniform sampler2D layer_texture_7 : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool layer_has_texture_7 = false;
uniform float layer_uv_scale_7 = 0.05;
uniform float layer_roughness_7 = 0.95;
uniform float layer_metallic_7 = 0.0;
uniform float layer_thickness_7 = 700.0;
uniform float layer_transition_7 = 90.0;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Returns white when a layer has no albedo texture, so the material tint remains visible.
vec3 sample_layer_texture(int index, vec2 uv) {
	if (index == 0) { if (layer_has_texture_0) return texture(layer_texture_0, uv).rgb; return vec3(1.0); }
	if (index == 1) { if (layer_has_texture_1) return texture(layer_texture_1, uv).rgb; return vec3(1.0); }
	if (index == 2) { if (layer_has_texture_2) return texture(layer_texture_2, uv).rgb; return vec3(1.0); }
	if (index == 3) { if (layer_has_texture_3) return texture(layer_texture_3, uv).rgb; return vec3(1.0); }
	if (index == 4) { if (layer_has_texture_4) return texture(layer_texture_4, uv).rgb; return vec3(1.0); }
	if (index == 5) { if (layer_has_texture_5) return texture(layer_texture_5, uv).rgb; return vec3(1.0); }
	if (index == 6) { if (layer_has_texture_6) return texture(layer_texture_6, uv).rgb; return vec3(1.0); }
	if (layer_has_texture_7) return texture(layer_texture_7, uv).rgb;
	return vec3(1.0);
}

vec4 sample_layer(int index, vec3 p, vec3 n) {
	vec3 weights = pow(abs(n), vec3(max(triplanar_sharpness, 1.0)));
	weights /= max(weights.x + weights.y + weights.z, 0.0001);

	// Project each world-space axis onto the other two axes.
	// Sign correction keeps adjacent faces from appearing unnecessarily mirrored.
	vec2 uv_x = p.zy;
	vec2 uv_y = p.xz;
	vec2 uv_z = p.xy;
	if (n.x < 0.0) uv_x.x = -uv_x.x;
	if (n.y < 0.0) uv_y.x = -uv_y.x;
	if (n.z > 0.0) uv_z.x = -uv_z.x;

	float scale = 0.05;
	vec3 tint = vec3(1.0);
	float roughness = 0.95;

	if (index == 0) { scale = layer_uv_scale_0; tint = layer_tint_0.rgb; roughness = layer_roughness_0; }
	else if (index == 1) { scale = layer_uv_scale_1; tint = layer_tint_1.rgb; roughness = layer_roughness_1; }
	else if (index == 2) { scale = layer_uv_scale_2; tint = layer_tint_2.rgb; roughness = layer_roughness_2; }
	else if (index == 3) { scale = layer_uv_scale_3; tint = layer_tint_3.rgb; roughness = layer_roughness_3; }
	else if (index == 4) { scale = layer_uv_scale_4; tint = layer_tint_4.rgb; roughness = layer_roughness_4; }
	else if (index == 5) { scale = layer_uv_scale_5; tint = layer_tint_5.rgb; roughness = layer_roughness_5; }
	else if (index == 6) { scale = layer_uv_scale_6; tint = layer_tint_6.rgb; roughness = layer_roughness_6; }
	else { scale = layer_uv_scale_7; tint = layer_tint_7.rgb; roughness = layer_roughness_7; }

	vec3 tex_x = sample_layer_texture(index, uv_x * scale);
	vec3 tex_y = sample_layer_texture(index, uv_y * scale);
	vec3 tex_z = sample_layer_texture(index, uv_z * scale);
	vec3 albedo = tint * (tex_x * weights.x + tex_y * weights.y + tex_z * weights.z);
	return vec4(albedo, roughness);
}

float layer_thickness(int index) {
	if (index == 0) return layer_thickness_0;
	if (index == 1) return layer_thickness_1;
	if (index == 2) return layer_thickness_2;
	if (index == 3) return layer_thickness_3;
	if (index == 4) return layer_thickness_4;
	if (index == 5) return layer_thickness_5;
	if (index == 6) return layer_thickness_6;
	return layer_thickness_7;
}

float layer_transition(int index) {
	if (index == 0) return layer_transition_0;
	if (index == 1) return layer_transition_1;
	if (index == 2) return layer_transition_2;
	if (index == 3) return layer_transition_3;
	if (index == 4) return layer_transition_4;
	if (index == 5) return layer_transition_5;
	if (index == 6) return layer_transition_6;
	return layer_transition_7;
}

float layer_metallic(int index) {
	if (index == 0) return layer_metallic_0;
	if (index == 1) return layer_metallic_1;
	if (index == 2) return layer_metallic_2;
	if (index == 3) return layer_metallic_3;
	if (index == 4) return layer_metallic_4;
	if (index == 5) return layer_metallic_5;
	if (index == 6) return layer_metallic_6;
	return layer_metallic_7;
}

vec4 sample_stack(float height_m, vec3 p, vec3 n, out float metallic) {
	int count = clamp(layer_count, 1, 8);
	float cursor = base_height_m;
	for (int i = 0; i < 7; i++) {
		if (i >= count - 1) break;
		float boundary = cursor + max(layer_thickness(i), 0.01);
		float width = max(layer_transition(i), 0.0);
		if (height_m < boundary + width * 0.5) {
			float blend = width <= 0.0 ? step(boundary, height_m) : smoothstep(boundary - width * 0.5, boundary + width * 0.5, height_m);
			vec4 lower = sample_layer(i, p, n);
			vec4 upper = sample_layer(i + 1, p, n);
			metallic = mix(layer_metallic(i), layer_metallic(i + 1), blend);
			return mix(lower, upper, blend);
		}
		cursor = boundary;
	}
	metallic = layer_metallic(count - 1);
	return sample_layer(count - 1, p, n);
}

void fragment() {
	vec3 n = normalize(world_normal);
	float metallic;
	vec4 surface = sample_stack(world_position.y, world_position, n, metallic);
	float flat_surface = smoothstep(0.55, 0.95, clamp(n.y, 0.0, 1.0));
	ALBEDO = mix(surface.rgb, slope_tint, flat_surface * slope_tint_strength);
	ALBEDO *= mix(1.0 - steep_slope_darkening, 1.0, clamp(n.y, 0.0, 1.0));
	ROUGHNESS = surface.a;
	METALLIC = metallic;
}
