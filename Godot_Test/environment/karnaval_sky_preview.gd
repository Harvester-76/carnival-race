extends Node3D

const SKY_CONTROLLER := preload("res://environment/karnaval_sky_controller.gd")

func _ready() -> void:
	var controller: KarnavalSkyController = SKY_CONTROLLER.new()
	controller.name = "KarnavalSkyController"
	add_child(controller)
	var args := OS.get_cmdline_user_args()
	var requested_preset := "variable"
	var capture_path := ""
	var simulation_time := 0.0
	var sky_view := "star"
	for arg in args:
		if arg.begins_with("sky_preset="):
			requested_preset = arg.trim_prefix("sky_preset=")
		elif arg.begins_with("sky_capture="):
			capture_path = arg.trim_prefix("sky_capture=")
		elif arg.begins_with("sky_time_offset="):
			simulation_time = float(arg.trim_prefix("sky_time_offset="))
		elif arg.begins_with("sky_view="):
			sky_view = arg.trim_prefix("sky_view=")
	match requested_preset:
		"clear": controller.set_preset(0)
		"overcast": controller.set_preset(2)
		_: controller.set_preset(1)
	controller.set_simulation_time(simulation_time)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_SKY
	environment.sky = controller.create_sky()
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	environment.ambient_light_energy = 0.9
	SKY_CONTROLLER.apply_fog_profile(environment)
	environment.glow_enabled = true
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40.0, 35.0, 0.0)
	sun.light_color = Color(1.0, 0.9, 0.75)
	sun.light_energy = 1.3
	add_child(sun)
	controller.bind_sun_light(sun)
	var camera := Camera3D.new()
	camera.current = true
	camera.far = 100000.0
	add_child(camera)
	var star_direction := sun.global_basis.z.normalized()
	var look_direction: Vector3 = Vector3.UP if sky_view == "zenith" else (Vector3.FORWARD if sky_view == "horizon" else star_direction.normalized())
	camera.look_at(look_direction, Vector3.BACK if sky_view == "zenith" else Vector3.UP)
	if not capture_path.is_empty():
		_capture_after_settle(capture_path)

func _capture_after_settle(path: String) -> void:
	await get_tree().create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save sky preview to %s (error %d)" % [path, error])
	get_tree().quit()
