extends RefCounted
class_name TerrainMaterialFactory

const TERRAIN_SHADER := preload("res://terrain/terrain_layers.gdshader")
const FALLBACK_TEXTURE_SIZE := Vector2i(1024, 1024)
const MAX_TEXTURE_DIMENSION := 2048

static func create_material(stack: TerrainLayerStack) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = TERRAIN_SHADER

	if stack == null:
		push_error("TerrainLayerStack resource is missing")
		return result

	var count := stack.strata.size()
	if count <= 0:
		push_error("TerrainLayerStack must contain at least one stratum")
		return result

	var albedo_sources: Array[Texture2D] = []
	var height_sources: Array[Texture2D] = []
	var params_image := Image.create_empty(4, count, false, Image.FORMAT_RGBAF)

	var albedo_size := Vector2i.ZERO
	var height_size := Vector2i.ZERO

	for i in count:
		var stratum: TerrainStratum = stack.strata[i]
		var material: StandardMaterial3D = stratum.material if stratum != null else null
		var albedo: Texture2D = material.albedo_texture if material != null else null
		var height: Texture2D = material.heightmap_texture if material != null and material.heightmap_enabled else null
		var height_on := stratum != null and stratum.height_enabled and height != null

		albedo_sources.append(albedo)
		height_sources.append(height if height_on else null)

		if albedo != null:
			var size := Vector2i(albedo.get_width(), albedo.get_height())
			albedo_size.x = maxi(albedo_size.x, size.x)
			albedo_size.y = maxi(albedo_size.y, size.y)
		if height_on:
			var size := Vector2i(height.get_width(), height.get_height())
			height_size.x = maxi(height_size.x, size.x)
			height_size.y = maxi(height_size.y, size.y)

		var tint := material.albedo_color if material != null else Color.WHITE
		var uv_scale := stratum.texture_uv_scale if stratum != null else 0.05
		var roughness := material.roughness if material != null else 0.95
		var metallic := material.metallic if material != null else 0.0
		var thickness := maxf(stratum.thickness_m, 0.01) if stratum != null else 700.0
		var transition := maxf(stratum.transition_width_m, 0.0) if stratum != null else 90.0
		var depth := stratum.height_depth_m if height_on else 0.0
		var normal_strength := stratum.height_normal_strength if height_on else 0.0
		var steps := stratum.parallax_steps if stratum != null else 6

		params_image.set_pixel(0, i, tint)
		params_image.set_pixel(1, i, Color(uv_scale, roughness, metallic, thickness))
		params_image.set_pixel(2, i, Color(transition, depth, normal_strength, float(steps)))
		params_image.set_pixel(3, i, Color(1.0 if albedo != null else 0.0, 1.0 if height_on else 0.0, 0.0, 0.0))

	albedo_size = _normalized_size(albedo_size)
	height_size = _normalized_size(height_size)

	var albedo_images: Array[Image] = []
	var height_images: Array[Image] = []
	for i in count:
		albedo_images.append(_prepare_layer_image(albedo_sources[i], albedo_size, Color.WHITE))
		height_images.append(_prepare_layer_image(height_sources[i], height_size, Color(0.5, 0.5, 0.5, 1.0)))

	var albedo_array := Texture2DArray.new()
	var albedo_error := albedo_array.create_from_images(albedo_images)
	if albedo_error != OK:
		push_error("Could not create terrain albedo Texture2DArray. Error: %s" % albedo_error)
		return result

	var height_array := Texture2DArray.new()
	var height_error := height_array.create_from_images(height_images)
	if height_error != OK:
		push_error("Could not create terrain height Texture2DArray. Error: %s" % height_error)
		return result

	var params_texture := ImageTexture.create_from_image(params_image)
	result.set_shader_parameter("layer_count", count)
	result.set_shader_parameter("base_height_m", stack.base_height_m)
	result.set_shader_parameter("slope_tint", stack.slope_tint)
	result.set_shader_parameter("slope_tint_strength", stack.slope_tint_strength)
	result.set_shader_parameter("steep_slope_darkening", stack.steep_slope_darkening)
	result.set_shader_parameter("layer_albedo_array", albedo_array)
	result.set_shader_parameter("layer_height_array", height_array)
	result.set_shader_parameter("layer_params", params_texture)
	return result


static func _normalized_size(source_size: Vector2i) -> Vector2i:
	if source_size == Vector2i.ZERO:
		return FALLBACK_TEXTURE_SIZE
	var largest := maxi(source_size.x, source_size.y)
	if largest > MAX_TEXTURE_DIMENSION:
		var factor := float(MAX_TEXTURE_DIMENSION) / float(largest)
		return Vector2i(maxi(1, roundi(source_size.x * factor)), maxi(1, roundi(source_size.y * factor)))
	return source_size


static func _create_fallback_image(target_size: Vector2i, fallback: Color) -> Image:
	var image := Image.create_empty(target_size.x, target_size.y, false, Image.FORMAT_RGBA8)
	image.fill(fallback)
	var mip_error := image.generate_mipmaps()
	if mip_error != OK:
		push_error("Could not generate mipmaps for fallback terrain image. Error: %s" % mip_error)
	return image


static func _prepare_layer_image(source: Texture2D, target_size: Vector2i, fallback: Color) -> Image:
	var image: Image = source.get_image() if source != null else null

	if image == null or image.is_empty():
		return _create_fallback_image(target_size, fallback)

	image = image.duplicate()

	# Imported textures may be stored in VRAM-compressed formats (BC/ETC/ASTC).
	# Decompress before convert(), resize(), or generate_mipmaps().
	if image.is_compressed():
		var decompress_error := image.decompress()
		if decompress_error != OK:
			push_error(
				"Could not decompress terrain texture '%s'. Error: %s. Using fallback color."
				% [source.resource_path, decompress_error]
			)
			return _create_fallback_image(target_size, fallback)

	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)

	if image.get_width() != target_size.x or image.get_height() != target_size.y:
		image.resize(target_size.x, target_size.y, Image.INTERPOLATE_LANCZOS)

	# Texture2DArray requires every layer to have identical mipmap usage.
	# Normalize all source images to the same state, then generate mipmaps.
	if image.has_mipmaps():
		image.clear_mipmaps()

	var mip_error := image.generate_mipmaps()
	if mip_error != OK:
		push_error(
			"Could not generate mipmaps for terrain texture '%s'. Error: %s. Using fallback color."
			% [source.resource_path, mip_error]
		)
		return _create_fallback_image(target_size, fallback)

	return image
