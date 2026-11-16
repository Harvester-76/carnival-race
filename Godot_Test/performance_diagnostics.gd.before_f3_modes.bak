extends Node

const SAMPLE_CAPACITY := 4096
const WINDOW_SECONDS := 10.0
const OVERLAY_INTERVAL := 0.25
const CSV_INTERVAL := 0.5

var main: Node
var overlay_layer: CanvasLayer
var overlay_label: Label
var frame_ms := PackedFloat64Array()
var frame_time_sec := PackedFloat64Array()
var sample_cursor := 0
var sample_count := 0
var overlay_elapsed := 0.0
var csv_elapsed := 0.0
var recording_started_ms := 0
var csv_file: FileAccess
var csv_path := ""
var metadata_path := ""
var csv_rows := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	frame_ms.resize(SAMPLE_CAPACITY)
	frame_time_sec.resize(SAMPLE_CAPACITY)
	overlay_layer = CanvasLayer.new()
	overlay_layer.layer = 90
	add_child(overlay_layer)
	overlay_label = Label.new()
	overlay_label.position = Vector2(18, 18)
	overlay_label.size = Vector2(1200, 410)
	overlay_label.visible = false
	overlay_label.add_theme_font_size_override("font_size", 17)
	overlay_label.add_theme_color_override("font_color", Color("E8F0FF"))
	overlay_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.96))
	overlay_label.add_theme_constant_override("outline_size", 5)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.015, 0.025, 0.055, 0.86)
	bg.set_corner_radius_all(8)
	bg.content_margin_left = 12.0
	bg.content_margin_right = 12.0
	bg.content_margin_top = 8.0
	bg.content_margin_bottom = 8.0
	overlay_label.add_theme_stylebox_override("normal", bg)
	overlay_layer.add_child(overlay_label)
	set_process(true)

func configure(p_main: Node) -> void:
	main = p_main
	_emit_event("track_load_start", "mode=%s" % _track_mode())

func announce_startup_complete() -> void:
	_emit_event("track_load_complete", "initial_ms=%.2f" % float(main.initial_track_load_ms))
	_emit_event("presentation_load_complete", "presentation_ms=%s" % _number_or_na(main.presentation_load_ms))
	_emit_event("track_generation_complete", "generation_ms=%.2f" % float(main.track_generation_ms))

func _input(event: InputEvent) -> void:
	if not event is InputEventKey: return
	var key := event as InputEventKey
	if not key.pressed or key.echo: return
	if key.physical_keycode == KEY_F3:
		overlay_label.visible = not overlay_label.visible
		if overlay_label.visible: _refresh_overlay()
		get_viewport().set_input_as_handled()
	elif key.physical_keycode == KEY_F4:
		if csv_file == null: _start_recording()
		else: _stop_recording()
		get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if dt > 0.0:
		var now := float(Time.get_ticks_usec()) / 1000000.0
		frame_ms[sample_cursor] = dt * 1000.0
		frame_time_sec[sample_cursor] = now
		sample_cursor = (sample_cursor + 1) % SAMPLE_CAPACITY
		sample_count = mini(sample_count + 1, SAMPLE_CAPACITY)
	if overlay_label.visible:
		overlay_elapsed += dt
		if overlay_elapsed >= OVERLAY_INTERVAL:
			overlay_elapsed = 0.0
			_refresh_overlay()
	if csv_file != null:
		csv_elapsed += dt
		if csv_elapsed >= CSV_INTERVAL:
			csv_elapsed = fmod(csv_elapsed, CSV_INTERVAL)
			_write_row("sample", "")

func record_event(event_name: String, detail := "") -> void:
	if csv_file == null: return
	_write_row("event", event_name + (":" + detail if detail != "" else ""))

func _emit_event(event_name: String, detail := "") -> void:
	if csv_file != null: record_event(event_name, detail)

func _start_recording() -> void:
	var dir_path := "user://performance_logs"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path)) != OK:
		push_error("Performance CSV: cannot create directory: " + ProjectSettings.globalize_path(dir_path))
		return
	var stamp := Time.get_datetime_string_from_system(false, true).replace(":", "-").replace("T", "_")
	var suffix := str(Time.get_ticks_msec() % 1000000)
	var stem := "performance_%s_%s" % [stamp, suffix]
	csv_path = dir_path.path_join(stem + ".csv")
	metadata_path = dir_path.path_join(stem + ".json")
	if FileAccess.file_exists(csv_path) or FileAccess.file_exists(metadata_path):
		push_error("Performance CSV: refusing to overwrite existing files: " + ProjectSettings.globalize_path(csv_path))
		return
	csv_file = FileAccess.open(csv_path, FileAccess.WRITE)
	if csv_file == null:
		push_error("Performance CSV: failed to open %s (error %d)" % [ProjectSettings.globalize_path(csv_path), FileAccess.get_open_error()])
		return
	csv_file.store_line("timestamp,elapsed_time,record_type,event,track_mode,fps,frame_time_ms,average_fps_10s,low_1_percent_fps,p95_frame_time_ms,p99_frame_time_ms,physics_frame_time_ms,draw_calls,render_objects,video_memory_bytes,process_memory_bytes,godot_memory_static_bytes,resource_memory_bytes,resource_count,active_collision_chunks,active_collision_bodies,loaded_collision_chunks,pending_collision_chunks,ship_x,ship_y,ship_z,ship_speed,physics_analytic_delta_m")
	csv_file.flush()
	recording_started_ms = Time.get_ticks_msec()
	csv_elapsed = 0.0
	csv_rows = 0
	var meta := _metadata()
	var mf := FileAccess.open(metadata_path, FileAccess.WRITE)
	if mf == null:
		var error := FileAccess.get_open_error()
		csv_file.close(); csv_file = null
		push_error("Performance metadata: failed to open %s (error %d)" % [ProjectSettings.globalize_path(metadata_path), error])
		return
	mf.store_string(JSON.stringify(meta, "\t") + "\n")
	mf.flush(); mf.close()
	print("Performance CSV recording: ", ProjectSettings.globalize_path(csv_path))
	print("Performance metadata: ", ProjectSettings.globalize_path(metadata_path))
	record_event("record_start", "metadata=" + ProjectSettings.globalize_path(metadata_path))
	record_event("track_load_start", "occurred_before_recording; see metadata timings")
	record_event("track_load_complete", "total_ms=%.2f" % float(main.initial_track_load_ms))
	if main.static_mode:
		record_event("presentation_load_complete", "presentation_ms=%.2f" % float(main.presentation_load_ms))
	else:
		record_event("generated_terrain_preload_complete", "preload_ms=%.2f" % float(main.generated_preload_ms))
	if main.static_runtime != null:
		record_event("collision_initial_load_complete", "chunks=%d;ms=%.2f" % [main.static_runtime.load_count, main.static_runtime.load_ms_total])

func _stop_recording() -> void:
	record_event("record_stop", "rows=%d" % csv_rows)
	csv_file.flush()
	csv_file.close()
	csv_file = null
	print("Performance CSV saved: ", ProjectSettings.globalize_path(csv_path), " rows=", csv_rows)

func _metadata() -> Dictionary:
	var renderer := str(ProjectSettings.get_setting("rendering/renderer/rendering_method", "N/A"))
	return {
		"game_version": main.APP_VERSION,
		"godot_version": Engine.get_version_info().string,
		"platform": OS.get_name(),
		"os_version": OS.get_version(),
		"track_mode": _track_mode(),
		"seed": main.track_seed,
		"length_km": main.gen_len_km,
		"start_slot_index": main.ab_slot_resolved,
		"start_slot": [main.player_start.x, main.player_start.y, main.player_start.z],
		"ship_id": main.ship_id,
		"ship_name": main.SHIP_NAMES[main.ship_id],
		"difficulty": main._lvl(),
		"camera_mode": main.cam_mode,
		"input_scheme": main.scheme,
		"physics_ticks_per_second": Engine.physics_ticks_per_second,
		"renderer": renderer,
		"viewport_size": [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y],
		"window_mode": DisplayServer.window_get_mode(),
		"graphics_settings": {
			"renderer": renderer,
			"msaa_3d": ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", null),
			"screen_space_aa": ProjectSettings.get_setting("rendering/anti_aliasing/quality/screen_space_aa", null),
			"scaling_3d_mode": ProjectSettings.get_setting("rendering/scaling_3d/mode", null),
			"vsync_mode": ProjectSettings.get_setting("display/window/vsync/vsync_mode", null)
		},
		"startup_timings_ms": {"track_generation": main.track_generation_ms, "generated_preload": main.generated_preload_ms, "presentation_load": main.presentation_load_ms, "initial_track_total": main.initial_track_load_ms, "collision_creation_total": main.static_runtime.load_ms_total if main.static_runtime != null else null}
	}

func _refresh_overlay() -> void:
	if main == null: return
	var values := _window_stats()
	var current_ms := float(values.get("current_frame_ms", 0.0))
	var physics_ms := float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0
	var draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var render_objects := int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))
	var static_memory := int(Performance.get_monitor(Performance.MEMORY_STATIC))
	var resource_count := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))
	var video_memory := int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED))
	var collision := _collision_metrics()
	var physics_delta: Variant = _physics_analytic_delta()
	var ship_active: bool = is_instance_valid(main.ship) and main.ship.is_inside_tree()
	var ship_pos: Vector3 = main.ship.global_position if ship_active else Vector3.ZERO
	var speed: float = main.ship.linear_velocity.length() if ship_active else 0.0
	var ship_text := "%.1f, %.1f, %.1f" % [ship_pos.x, ship_pos.y, ship_pos.z] if ship_active else "N/A"
	var speed_text := "%.1f m/s" % speed if ship_active else "N/A"
	var video_text := "N/A" if video_memory <= 0 else _bytes_text(video_memory)
	var elapsed := "recording %.1f s" % (float(Time.get_ticks_msec() - recording_started_ms) / 1000.0) if csv_file != null else "F4: start CSV"
	overlay_label.text = "PERFORMANCE  ·  %s\nFPS %d  |  avg 10s %s  |  1%% low %s\nFrame %.2f ms  |  P95 %s ms  |  P99 %s ms\nPhysics %.2f ms  |  draw calls %d  |  render objects %d\nCollision active %d chunks / %d bodies  |  loaded %d  |  pending %d\nMemory process N/A  |  Godot static %s  |  resources %d (resource bytes N/A)  |  VRAM %s\nStartup load %s ms  |  presentation %s ms  |  collision creation %s ms\nPhysics vs analytic %s m\nShip %s  |  speed %s\nF3: hide overlay  |  %s" % [
		_track_mode(), Engine.get_frames_per_second(), _format_stat(values.get("average_fps", null)), _format_stat(values.get("low_1_percent_fps", null)), current_ms,
		_format_stat(values.get("p95_ms", null)), _format_stat(values.get("p99_ms", null)), physics_ms, draw_calls, render_objects,
		int(collision["active_chunks"]), int(collision["active_bodies"]), int(collision["loaded"]), int(collision["pending"]), _bytes_text(static_memory), resource_count, video_text,
		_number_or_na(main.initial_track_load_ms), _number_or_na(main.presentation_load_ms), _number_or_na(collision["creation_ms"]), _format_stat(physics_delta), ship_text, speed_text, elapsed]

func _window_stats() -> Dictionary:
	var now := float(Time.get_ticks_usec()) / 1000000.0
	var values: Array[float] = []
	var sum_ms := 0.0
	for offset in sample_count:
		var idx := posmod(sample_cursor - 1 - offset, SAMPLE_CAPACITY)
		if now - frame_time_sec[idx] <= WINDOW_SECONDS:
			var value := frame_ms[idx]
			values.append(value); sum_ms += value
	if values.is_empty(): return {"current_frame_ms": 0.0}
	values.sort()
	var n := values.size()
	var p95 := values[clampi(int(ceil(float(n) * 0.95)) - 1, 0, n - 1)]
	var p99 := values[clampi(int(ceil(float(n) * 0.99)) - 1, 0, n - 1)]
	var slow_count := maxi(1, int(ceil(float(n) * 0.01)))
	var slow_sum := 0.0
	for i in range(n - slow_count, n): slow_sum += values[i]
	return {
		"current_frame_ms": frame_ms[posmod(sample_cursor - 1, SAMPLE_CAPACITY)],
		"average_fps": float(n) * 1000.0 / maxf(sum_ms, 0.0001),
		"low_1_percent_fps": float(slow_count) * 1000.0 / maxf(slow_sum, 0.0001),
		"p95_ms": p95,
		"p99_ms": p99
	}

func _collision_metrics() -> Dictionary:
	if main.static_runtime != null:
		var runtime: Node = main.static_runtime
		return {"active_chunks": runtime.collision_bodies.size(), "active_bodies": runtime.collision_bodies.size(), "loaded": runtime.collision_bodies.size(), "pending": runtime.missing_ahead, "creation_ms": runtime.load_ms_total}
	var body_count := 0
	for entry in main.chunks.values():
		if entry.size() > 1 and entry[1] != null: body_count += 1
	return {"active_chunks": body_count, "active_bodies": body_count, "loaded": body_count, "pending": main.chunk_jobs.size(), "creation_ms": null}

func _physics_analytic_delta() -> Variant:
	if main == null or main.static_runtime == null: return null
	var runtime: Node = main.static_runtime
	if runtime.physics_height_samples <= 0: return null
	var value := float(runtime.physics_height_delta)
	return value if is_finite(value) else null

func _write_row(record_type: String, event_name: String) -> void:
	if csv_file == null or main == null: return
	var metrics := _window_stats()
	var collision := _collision_metrics()
	var physics_delta: Variant = _physics_analytic_delta()
	var ship_active: bool = is_instance_valid(main.ship) and main.ship.is_inside_tree()
	var ship_pos: Vector3 = main.ship.global_position if ship_active else Vector3.ZERO
	var speed: float = main.ship.linear_velocity.length() if ship_active else 0.0
	var process_mem := "" # No portable Godot API exposes the OS process working set on macOS and Windows.
	var resource_mem := "" # Resource byte totals are not exposed by a portable engine monitor.
	var values := [
		_iso_timestamp(), _format_number(float(Time.get_ticks_msec() - recording_started_ms) / 1000.0), record_type, event_name, _track_mode(),
		str(Engine.get_frames_per_second()), _format_number(float(metrics.get("current_frame_ms", 0.0))), _format_number_or_empty(metrics.get("average_fps", null)),
		_format_number_or_empty(metrics.get("low_1_percent_fps", null)), _format_number_or_empty(metrics.get("p95_ms", null)), _format_number_or_empty(metrics.get("p99_ms", null)),
		_format_number(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)) * 1000.0), str(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))),
		str(int(Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME))), _monitor_bytes(Performance.RENDER_VIDEO_MEM_USED), process_mem,
		str(int(Performance.get_monitor(Performance.MEMORY_STATIC))), resource_mem, str(int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT))),
		str(int(collision["active_chunks"])), str(int(collision["active_bodies"])), str(int(collision["loaded"])), str(int(collision["pending"])),
		_format_number(ship_pos.x) if ship_active else "", _format_number(ship_pos.y) if ship_active else "", _format_number(ship_pos.z) if ship_active else "", _format_number(speed) if ship_active else "",
		_format_number(float(physics_delta)) if physics_delta != null else ""
	]
	var escaped := PackedStringArray()
	for value in values: escaped.append(_csv_escape(str(value)))
	csv_file.store_line(",".join(escaped)); csv_file.flush(); csv_rows += 1

func _monitor_bytes(monitor: int) -> String:
	var amount := int(Performance.get_monitor(monitor))
	return "" if amount <= 0 else str(amount)

func _track_mode() -> String:
	return "STATIC" if main != null and main.static_mode else "GENERATED"

func _csv_escape(value: String) -> String:
	if value.contains(",") or value.contains("\"") or value.contains("\n") or value.contains("\r"):
		return "\"" + value.replace("\"", "\"\"") + "\""
	return value

func _iso_timestamp() -> String:
	var d := Time.get_datetime_dict_from_system()
	return "%04d-%02d-%02dT%02d:%02d:%02d.%03d" % [d.year, d.month, d.day, d.hour, d.minute, d.second, Time.get_ticks_msec() % 1000]

func _format_number(value: float) -> String:
	return "%.3f" % value

func _format_number_or_empty(value: Variant) -> String:
	return "" if value == null else _format_number(float(value))

func _format_stat(value: Variant) -> String:
	return "N/A" if value == null else "%.2f" % float(value)

func _number_or_na(value: Variant) -> String:
	return "N/A" if value == null or float(value) < 0.0 else "%.2f" % float(value)

func _bytes_text(value: int) -> String:
	if value <= 0: return "N/A"
	return "%.1f MB" % (float(value) / 1048576.0)

func _exit_tree() -> void:
	if csv_file != null:
		record_event("record_stop", "scene_exit;rows=%d" % csv_rows)
		csv_file.flush(); csv_file.close(); csv_file = null
