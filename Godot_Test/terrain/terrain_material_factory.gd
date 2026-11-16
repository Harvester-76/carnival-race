extends RefCounted
class_name TerrainMaterialFactory

const MAX_LAYERS := 8
const TERRAIN_SHADER := preload("res://terrain/terrain_layers.gdshader")

static func create_material(stack: TerrainLayerStack) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = TERRAIN_SHADER
	if stack == null:
		push_error("TerrainLayerStack resource is missing")
		return result

	var count := mini(stack.strata.size(), MAX_LAYERS)
	if count <= 0:
		push_error("TerrainLayerStack must contain at least one stratum")
		return result
	if stack.strata.size() > MAX_LAYERS:
		push_warning("TerrainLayerStack has %d strata; shader supports only the first %d." % [stack.strata.size(), MAX_LAYERS])

	result.set_shader_parameter("layer_count", count)
	result.set_shader_parameter("base_height_m", stack.base_height_m)
	result.set_shader_parameter("slope_tint", stack.slope_tint)
	result.set_shader_parameter("slope_tint_strength", stack.slope_tint_strength)
	result.set_shader_parameter("steep_slope_darkening", stack.steep_slope_darkening)

	for i in MAX_LAYERS:
		var stratum: TerrainStratum
		if i < count:
			stratum = stack.strata[i]
		var material: StandardMaterial3D = stratum.material if stratum != null else null
		var color := material.albedo_color if material != null else Color.WHITE
		var albedo: Texture2D = material.albedo_texture if material != null else null
		var height: Texture2D = material.heightmap_texture if material != null and material.heightmap_enabled else null
		var height_on := stratum != null and stratum.height_enabled and height != null

		result.set_shader_parameter("layer_tint_%d" % i, color)
		result.set_shader_parameter("layer_has_texture_%d" % i, albedo != null)
		if albedo != null:
			result.set_shader_parameter("layer_texture_%d" % i, albedo)
		result.set_shader_parameter("layer_uv_scale_%d" % i, stratum.texture_uv_scale if stratum != null else 0.05)
		result.set_shader_parameter("layer_roughness_%d" % i, material.roughness if material != null else 0.95)
		result.set_shader_parameter("layer_metallic_%d" % i, material.metallic if material != null else 0.0)
		result.set_shader_parameter("layer_thickness_%d" % i, maxf(stratum.thickness_m, 0.01) if stratum != null else 700.0)
		result.set_shader_parameter("layer_transition_%d" % i, maxf(stratum.transition_width_m, 0.0) if stratum != null else 90.0)
		result.set_shader_parameter("layer_has_height_%d" % i, height_on)
		if height_on:
			result.set_shader_parameter("layer_height_texture_%d" % i, height)
		result.set_shader_parameter("layer_height_depth_%d" % i, stratum.height_depth_m if stratum != null else 0.0)
		result.set_shader_parameter("layer_height_normal_strength_%d" % i, stratum.height_normal_strength if stratum != null else 0.0)
		result.set_shader_parameter("layer_parallax_steps_%d" % i, stratum.parallax_steps if stratum != null else 4)
	return result
