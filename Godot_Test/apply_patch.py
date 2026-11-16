#!/usr/bin/env python3
from pathlib import Path
import sys

target = Path("performance_diagnostics.gd")
if not target.exists():
    print("ОШИБКА: запусти скрипт из Godot_Test, рядом с performance_diagnostics.gd.")
    sys.exit(1)

source = target.read_text(encoding="utf-8")
original = source

def replace_once(old, new, name):
    global source
    count = source.count(old)
    if count != 1:
        print(f"ОШИБКА: блок '{name}' найден {count} раз вместо 1. Файл не изменён.")
        sys.exit(2)
    source = source.replace(old, new, 1)

replace_once(
"""const CSV_INTERVAL := 0.5

var main: Node""",
"""const CSV_INTERVAL := 0.5

const OVERLAY_HIDDEN := 0
const OVERLAY_COMPACT := 1
const OVERLAY_FULL := 2

var overlay_mode := OVERLAY_HIDDEN
var main: Node""",
"константы режимов")

replace_once(
"""	overlay_label = Label.new()
	overlay_label.position = Vector2(18, 18)
	overlay_label.size = Vector2(1200, 410)
	overlay_label.visible = false
	overlay_label.add_theme_font_size_override("font_size", 17)
	overlay_label.add_theme_color_override("font_color", Color("E8F0FF"))
	overlay_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.96))
	overlay_label.add_theme_constant_override("outline_size", 5)""",
"""	overlay_label = RichTextLabel.new()
	overlay_label.position = Vector2(18, 18)
	overlay_label.size = Vector2(520, 62)
	overlay_label.visible = false
	overlay_label.bbcode_enabled = true
	overlay_label.fit_content = true
	overlay_label.scroll_active = false
	overlay_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	overlay_label.add_theme_font_size_override("normal_font_size", 17)
	overlay_label.add_theme_color_override("default_color", Color("E8F0FF"))
	overlay_label.add_theme_color_override("font_outline_color", Color(0.01, 0.02, 0.04, 0.96))
	overlay_label.add_theme_constant_override("outline_size", 4)""",
"создание RichTextLabel")

replace_once(
"""	if key.physical_keycode == KEY_F3:
		overlay_label.visible = not overlay_label.visible
		if overlay_label.visible: _refresh_overlay()
		get_viewport().set_input_as_handled()""",
"""	if key.physical_keycode == KEY_F3:
		overlay_mode = (overlay_mode + 1) % 3
		overlay_label.visible = overlay_mode != OVERLAY_HIDDEN
		if overlay_label.visible:
			_refresh_overlay()
		get_viewport().set_input_as_handled()""",
"переключение F3")

start = source.index("func _refresh_overlay() -> void:")
end = source.index("\nfunc _window_stats() -> Dictionary:", start)

new_func = r"""func _refresh_overlay() -> void:
	if main == null or overlay_mode == OVERLAY_HIDDEN: return
	var values := _window_stats()
	var current_fps := Engine.get_frames_per_second()
	var average_fps: Variant = values.get("average_fps", null)
	var low_fps: Variant = values.get("low_1_percent_fps", null)

	if overlay_mode == OVERLAY_COMPACT:
		overlay_label.size = Vector2(520, 62)
		overlay_label.add_theme_font_size_override("normal_font_size", 17)
		overlay_label.text = "FPS %s   |   avg 10s %s   |   1%% low %s\n[color=#AAB8CC]F3: полный отчёт[/color]" % [
			_fps_markup(float(current_fps)), _fps_markup(average_fps), _fps_markup(low_fps)
		]
		return

	overlay_label.size = Vector2(1200, 410)
	overlay_label.add_theme_font_size_override("normal_font_size", 17)
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
	overlay_label.text = "PERFORMANCE  ·  %s\nFPS %s  |  avg 10s %s  |  1%% low %s\nFrame %.2f ms  |  P95 %s ms  |  P99 %s ms\nPhysics %.2f ms  |  draw calls %d  |  render objects %d\nCollision active %d chunks / %d bodies  |  loaded %d  |  pending %d\nMemory process N/A  |  Godot static %s  |  resources %d (resource bytes N/A)  |  VRAM %s\nStartup load %s ms  |  presentation %s ms  |  collision creation %s ms\nPhysics vs analytic %s m\nShip %s  |  speed %s\nF3: compact / full / hide  |  %s" % [
		_track_mode(), _fps_markup(float(current_fps)), _fps_markup(average_fps), _fps_markup(low_fps), current_ms,
		_format_stat(values.get("p95_ms", null)), _format_stat(values.get("p99_ms", null)), physics_ms, draw_calls, render_objects,
		int(collision["active_chunks"]), int(collision["active_bodies"]), int(collision["loaded"]), int(collision["pending"]), _bytes_text(static_memory), resource_count, video_text,
		_number_or_na(main.initial_track_load_ms), _number_or_na(main.presentation_load_ms), _number_or_na(collision["creation_ms"]), _format_stat(physics_delta), ship_text, speed_text, elapsed]

func _fps_markup(value: Variant) -> String:
	if value == null:
		return "[color=#AAB8CC]N/A[/color]"
	var fps := float(value)
	var color := "#FF6268" if fps < 40.0 else ("#FFD166" if fps < 60.0 else ("#69B7FF" if fps <= 100.0 else "#55E58A"))
	return "[color=%s]%.1f[/color]" % [color, fps]
"""
source = source[:start] + new_func + source[end:]

backup = target.with_name("performance_diagnostics.gd.before_f3_modes.bak")
if backup.exists():
    print(f"ОШИБКА: резервная копия уже существует: {backup}. Файл не изменён.")
    sys.exit(3)
backup.write_text(original, encoding="utf-8")
target.write_text(source, encoding="utf-8")
print("Готово. Резервная копия:", backup)
print("F3: компактно -> подробно -> скрыто. F4/CSV не изменены.")
