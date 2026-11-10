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
	var count := mini(stack.layers.size(), MAX_LAYERS)
	if count <= 0:
		push_error("TerrainLayerStack must contain at least one layer")
		return result
	result.set_shader_parameter("layer_count", count)
	result.set_shader_parameter("base_height_m", stack.base_height_m)
	result.set_shader_parameter("slope_tint", stack.slope_tint)
	result.set_shader_parameter("slope_tint_strength", stack.slope_tint_strength)
	result.set_shader_parameter("steep_slope_darkening", stack.steep_slope_darkening)
	for i in MAX_LAYERS:
		var layer: TerrainSurfaceLayer
		if i < count: layer = stack.layers[i]
		var material: StandardMaterial3D = layer.material if layer != null else null
		var color := material.albedo_color if material != null else Color.WHITE
		var texture: Texture2D = material.albedo_texture if material != null else null
		result.set_shader_parameter("layer_tint_%d" % i, color)
		result.set_shader_parameter("layer_has_texture_%d" % i, texture != null)
		if texture != null: result.set_shader_parameter("layer_texture_%d" % i, texture)
		result.set_shader_parameter("layer_uv_scale_%d" % i, layer.texture_uv_scale if layer != null else 0.05)
		result.set_shader_parameter("layer_roughness_%d" % i, material.roughness if material != null else 0.95)
		result.set_shader_parameter("layer_metallic_%d" % i, material.metallic if material != null else 0.0)
		result.set_shader_parameter("layer_thickness_%d" % i, maxf(layer.thickness_m, 0.01) if layer != null else 700.0)
		result.set_shader_parameter("layer_transition_%d" % i, maxf(layer.transition_width_m, 0.0) if layer != null else 90.0)
	return result
