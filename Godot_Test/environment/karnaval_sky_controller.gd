extends Node
class_name KarnavalSkyController

enum Preset { CLEAR, VARIABLE, OVERCAST }

const DEFAULT_SKY_MATERIAL := preload("res://environment/materials/karnaval_planet_sky.tres")
const FOG_PROFILE := preload("res://environment/materials/karnaval_fog_profile.tres")

static func apply_fog_profile(environment: Environment) -> void:
	var profile := FOG_PROFILE as Environment
	environment.fog_enabled = profile.fog_enabled
	environment.fog_light_color = profile.fog_light_color
	environment.fog_density = profile.fog_density
	environment.fog_sky_affect = profile.fog_sky_affect

## Replace this resource to use another ShaderMaterial with the same shader interface.
@export var sky_material_template: ShaderMaterial = DEFAULT_SKY_MATERIAL
@export_range(0.0, 1.0, 0.01) var clouded_sun_min_energy_scale := 0.24
@export_range(0.1, 8.0, 0.1) var sun_energy_response := 2.4

var _material: ShaderMaterial
var _elapsed := 0.0
var _sun_light: DirectionalLight3D
var _sun_base_energy := 1.0
var _far_mask_image: Image
var _near_mask_image: Image
var _ring_cloud_image: Image
var _sun_visibility := 1.0

func create_sky() -> Sky:
	_material = sky_material_template.duplicate(true) as ShaderMaterial
	_far_mask_image = _get_mask_image("clouds_far_mask")
	_near_mask_image = _get_mask_image("clouds_near_mask")
	_ring_cloud_image = _get_mask_image("cloud_ring_texture")
	var sky := Sky.new()
	sky.sky_material = _material
	return sky

func bind_sun_light(light: DirectionalLight3D) -> void:
	_sun_light = light
	if _sun_light != null:
		_sun_base_energy = _sun_light.light_energy

func get_sun_visibility() -> float:
	return _sun_visibility

func set_preset(preset: Preset) -> void:
	match preset:
		Preset.CLEAR:
			_set_parameter("cloud_far_density", 0.15)
			_set_parameter("cloud_mid_density", 0.18)
			_set_parameter("cloud_near_density", 0.20)
			_set_parameter("cloud_detail_density", 0.16)
			_set_parameter("cloud_ring_opacity", 0.40)
			_set_parameter("cloud_contrast", 0.82)
			_set_parameter("star_intensity", 2.1)
		Preset.VARIABLE:
			_set_parameter("cloud_far_density", 0.36)
			_set_parameter("cloud_mid_density", 0.40)
			_set_parameter("cloud_near_density", 0.46)
			_set_parameter("cloud_detail_density", 0.34)
			_set_parameter("cloud_ring_opacity", 0.66)
			_set_parameter("cloud_contrast", 1.0)
			_set_parameter("star_intensity", 1.15)
		Preset.OVERCAST:
			_set_parameter("cloud_far_density", 0.88)
			_set_parameter("cloud_mid_density", 0.91)
			_set_parameter("cloud_near_density", 0.94)
			_set_parameter("cloud_detail_density", 0.89)
			_set_parameter("cloud_ring_opacity", 0.82)
			_set_parameter("cloud_contrast", 1.12)
			_set_parameter("star_intensity", 1.45)

func set_simulation_time(seconds: float) -> void:
	"""Set the deterministic starting time used for repeatable sky captures."""
	_elapsed = maxf(seconds, 0.0)

func _process(delta: float) -> void:
	if _material == null:
		return
	_elapsed += delta
	var wind := float(_material.get_shader_parameter("wind_direction"))
	var far_direction := Vector2(cos(wind), sin(wind))
	var mid_direction := Vector2(cos(wind - 0.28), sin(wind - 0.28))
	var near_direction := Vector2(cos(wind - 0.73), sin(wind - 0.73))
	var detail_direction := Vector2(cos(wind - 1.12), sin(wind - 1.12))
	var far_speed := float(_material.get_shader_parameter("cloud_far_speed"))
	var mid_speed := float(_material.get_shader_parameter("cloud_mid_speed"))
	var near_speed := float(_material.get_shader_parameter("cloud_near_speed"))
	var detail_speed := float(_material.get_shader_parameter("cloud_detail_speed"))
	var atmosphere_drift: Vector2 = _material.get_shader_parameter("atmosphere_drift_velocity")
	_material.set_shader_parameter("cloud_far_offset", far_direction * far_speed * _elapsed)
	_material.set_shader_parameter("cloud_mid_offset", mid_direction * mid_speed * _elapsed)
	_material.set_shader_parameter("cloud_near_offset", near_direction * near_speed * _elapsed)
	_material.set_shader_parameter("cloud_detail_offset", detail_direction * detail_speed * _elapsed)
	var ring_rotation_speed := float(_material.get_shader_parameter("cloud_ring_rotation_speed"))
	_material.set_shader_parameter("cloud_ring_longitude_offset", fposmod(ring_rotation_speed * _elapsed, 1.0))
	_material.set_shader_parameter("atmosphere_offset", atmosphere_drift * _elapsed)
	_update_sun_energy(delta)

func _update_sun_energy(delta: float) -> void:
	if _material == null or _sun_light == null or _far_mask_image == null or _near_mask_image == null:
		return
	var sun_direction := _sun_light.global_basis.z.normalized()
	var camera := get_viewport().get_camera_3d()
	var camera_position := camera.global_position if camera != null else Vector3.ZERO
	var track_axis := camera_position.z + camera_position.x * 0.37
	var far_cover := _sample_layer_cover(_far_mask_image, sun_direction, "far", track_axis)
	var mid_cover := _sample_layer_cover(_near_mask_image, sun_direction, "mid", track_axis)
	var near_cover := _sample_layer_cover(_near_mask_image, sun_direction, "near", track_axis)
	var detail_cover := _sample_layer_cover(_far_mask_image, sun_direction, "detail", track_axis)
	var ring_cover := _sample_ring_cover(sun_direction, track_axis)
	var total_cover := 1.0 - (1.0 - far_cover) * (1.0 - mid_cover) * (1.0 - near_cover) * (1.0 - detail_cover) * (1.0 - ring_cover)
	_sun_visibility = 1.0 - _smoothstep(0.12, 0.88, total_cover)
	var target_scale := lerpf(clouded_sun_min_energy_scale, 1.0, _sun_visibility)
	var target_energy := _sun_base_energy * target_scale
	var response := 1.0 - exp(-sun_energy_response * delta)
	_sun_light.light_energy = lerpf(_sun_light.light_energy, target_energy, response)

func _sample_layer_cover(image: Image, direction: Vector3, layer: String, track_axis: float) -> float:
	var repeat_count := float(_material.get_shader_parameter("cloud_%s_repeats" % layer))
	var offset: Vector2 = _material.get_shader_parameter("cloud_%s_offset" % layer)
	var depth_km := float(_material.get_shader_parameter("cloud_%s_depth_km" % layer))
	var density := float(_material.get_shader_parameter("cloud_%s_density" % layer))
	var opacity := float(_material.get_shader_parameter("cloud_cover_opacity_%s" % layer))
	var uv := _direction_uv(direction) * repeat_count + offset - Vector2(track_axis / maxf(depth_km * 1000.0, 1.0), 0.0)
	var pole_fade := 1.0 - _smoothstep(
		float(_material.get_shader_parameter("cloud_pole_fade_start")),
		float(_material.get_shader_parameter("cloud_pole_fade_end")),
		absf(direction.y)
	)
	return _layer_density(_sample_red_bilinear(image, uv), density) * opacity * pole_fade

func _sample_ring_cover(direction: Vector3, _track_axis: float) -> float:
	if _ring_cloud_image == null:
		return 0.0
	var vertical_zoom := float(_material.get_shader_parameter("cloud_ring_vertical_zoom"))
	var uv := _direction_uv(direction)
	uv.x = fposmod(uv.x + float(_material.get_shader_parameter("cloud_ring_longitude_offset")), 1.0)
	uv.y = clampf(0.5 + (uv.y - 0.5) * vertical_zoom, 0.0, 1.0)
	var texture_alpha := _sample_alpha_bilinear(_ring_cloud_image, uv)
	var seam_distance := minf(fposmod(uv.x, 1.0), 1.0 - fposmod(uv.x, 1.0))
	var seam_weight := 1.0 - _smoothstep(0.0, 0.045, seam_distance)
	var edge_average := 0.5 * (
		_sample_alpha_bilinear(_ring_cloud_image, Vector2(0.97, uv.y)) +
		_sample_alpha_bilinear(_ring_cloud_image, Vector2(0.03, uv.y))
	)
	texture_alpha = lerpf(texture_alpha, edge_average, seam_weight)
	var opacity := float(_material.get_shader_parameter("cloud_cover_opacity_ring"))
	var band := _smoothstep(-0.18, -0.03, direction.y) * (1.0 - _smoothstep(
		float(_material.get_shader_parameter("cloud_ring_top_elevation")),
		float(_material.get_shader_parameter("cloud_ring_top_elevation")) + float(_material.get_shader_parameter("cloud_ring_fade")),
		direction.y
	))
	return texture_alpha * opacity * band

func _sample_alpha_bilinear(image: Image, uv: Vector2) -> float:
	var width := image.get_width()
	var height := image.get_height()
	var px := fposmod(uv.x, 1.0) * width - 0.5
	var py := clampf(uv.y, 0.0, 1.0) * (height - 1)
	var x0 := floori(px)
	var y0 := floori(py)
	var fx := px - float(x0)
	var fy := py - float(y0)
	var x1 := posmod(x0 + 1, width)
	var y1 := mini(y0 + 1, height - 1)
	x0 = posmod(x0, width)
	var top := lerpf(image.get_pixel(x0, y0).a, image.get_pixel(x1, y0).a, fx)
	var bottom := lerpf(image.get_pixel(x0, y1).a, image.get_pixel(x1, y1).a, fx)
	return lerpf(top, bottom, fy)

func _direction_uv(direction: Vector3) -> Vector2:
	var normalized_direction := direction.normalized()
	return Vector2(
		atan2(normalized_direction.x, normalized_direction.z) / TAU + 0.5,
		acos(clampf(normalized_direction.y, -1.0, 1.0)) / PI
	)

func _sample_red_bilinear(image: Image, uv: Vector2) -> float:
	var width := image.get_width()
	var height := image.get_height()
	var px := fposmod(uv.x, 1.0) * width - 0.5
	var py := fposmod(uv.y, 1.0) * height - 0.5
	var x0 := floori(px)
	var y0 := floori(py)
	var fx := px - float(x0)
	var fy := py - float(y0)
	var x1 := posmod(x0 + 1, width)
	var y1 := posmod(y0 + 1, height)
	x0 = posmod(x0, width)
	y0 = posmod(y0, height)
	var top := lerpf(image.get_pixel(x0, y0).r, image.get_pixel(x1, y0).r, fx)
	var bottom := lerpf(image.get_pixel(x0, y1).r, image.get_pixel(x1, y1).r, fx)
	return lerpf(top, bottom, fy)

func _layer_density(sample_value: float, density: float) -> float:
	var threshold := 0.86 - density * 0.62
	var softness := 0.20 / maxf(float(_material.get_shader_parameter("cloud_contrast")), 0.2)
	return _smoothstep(threshold, threshold + softness, sample_value)

func _smoothstep(edge0: float, edge1: float, value: float) -> float:
	var t := clampf((value - edge0) / maxf(edge1 - edge0, 0.000001), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)

func _get_mask_image(parameter_name: StringName) -> Image:
	var texture := sky_material_template.get_shader_parameter(parameter_name) as Texture2D
	return texture.get_image() if texture != null else null

func _set_parameter(parameter_name: StringName, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(parameter_name, value)
