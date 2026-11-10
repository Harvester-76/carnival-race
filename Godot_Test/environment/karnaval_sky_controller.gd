extends Node
class_name KarnavalSkyController

enum Preset { CLEAR, VARIABLE, OVERCAST }

const DEFAULT_SKY_MATERIAL := preload("res://environment/materials/karnaval_planet_sky.tres")

## Replace this resource to use another ShaderMaterial with the same shader interface.
@export var sky_material_template: ShaderMaterial = DEFAULT_SKY_MATERIAL

var _material: ShaderMaterial
var _elapsed := 0.0

func create_sky() -> Sky:
	_material = sky_material_template.duplicate(true) as ShaderMaterial
	var sky := Sky.new()
	sky.sky_material = _material
	return sky

func set_preset(preset: Preset) -> void:
	match preset:
		Preset.CLEAR:
			_set_parameter("cloud_far_density", 0.15)
			_set_parameter("cloud_near_density", 0.20)
			_set_parameter("cloud_contrast", 0.82)
			_set_parameter("star_intensity", 2.1)
		Preset.VARIABLE:
			_set_parameter("cloud_far_density", 0.36)
			_set_parameter("cloud_near_density", 0.46)
			_set_parameter("cloud_contrast", 1.0)
			_set_parameter("star_intensity", 1.15)
		Preset.OVERCAST:
			_set_parameter("cloud_far_density", 0.88)
			_set_parameter("cloud_near_density", 0.94)
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
	var near_direction := Vector2(cos(wind - 0.73), sin(wind - 0.73))
	var far_speed := float(_material.get_shader_parameter("cloud_far_speed"))
	var near_speed := float(_material.get_shader_parameter("cloud_near_speed"))
	var atmosphere_drift: Vector2 = _material.get_shader_parameter("atmosphere_drift_velocity")
	_material.set_shader_parameter("cloud_far_offset", far_direction * far_speed * _elapsed)
	_material.set_shader_parameter("cloud_near_offset", near_direction * near_speed * _elapsed)
	_material.set_shader_parameter("atmosphere_offset", atmosphere_drift * _elapsed)

func _set_parameter(parameter_name: StringName, value: Variant) -> void:
	if _material != null:
		_material.set_shader_parameter(parameter_name, value)
