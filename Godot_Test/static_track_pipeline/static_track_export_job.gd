extends RefCounted
class_name StaticTrackExportJob

const DEFAULT_SOURCE_PATH := "res://static_track_pipeline/procedural_track_source.gd"
const ROUTE_PAD := 7500.0
const MAIN_JOIN_EXTENSION := 3000.0
const COLLISION_STEP := 31.25
const PRESENTATION_STEPS := {"base": 125.0, "detail": 31.25}
const CHUNK_VARIANTS := [1000.0, 2000.0]
const BOUNDS_GRID := 2000.0

var out_abs := ""
var final_abs := ""
var source_path := DEFAULT_SOURCE_PATH
var geometry_source
var source_description := {}
var source_parameters := {}
var route_polylines: Array = []
var route_info: Array = []
var terrain_context_paths: Array = []
var fixture_bounds := Rect2()
var export_mode := "fixture"
var export_profile := "diagnostic"
var estimate_only := false
var join_pairs: Array = []
var export_seed := 11
var export_length_km := 650.0
var progress_path := ""
var cancel_path := ""
var progress_parent_ready := false
var scheduler: Object
var error_message := ""
var completed_chunks := 0
var total_chunks := 0
var export_started_usec := 0

func run(config: Dictionary, p_scheduler: Object = null) -> Dictionary:
	scheduler = p_scheduler
	error_message = ""
	progress_parent_ready = false
	export_seed = int(config.get("seed", 11))
	export_length_km = float(config.get("length_km", 650.0))
	export_mode = str(config.get("mode", "fixture"))
	export_profile = str(config.get("profile", "diagnostic"))
	source_path = str(config.get("source", DEFAULT_SOURCE_PATH))
	estimate_only = bool(config.get("estimate", false))
	progress_path = str(config.get("progress_path", ""))
	cancel_path = str(config.get("cancel_path", ""))
	var requested_out := str(config.get("out", ""))
	if requested_out.is_empty(): requested_out = "res://experiments/static_track_seed11_cut1" if export_mode == "fixture" else "res://experiments/full_static_track_seed11_650km"
	final_abs = ProjectSettings.globalize_path(requested_out)
	if export_mode not in ["fixture", "full"]:
		return _finish_error("mode must be fixture or full")
	if export_profile not in ["diagnostic", "production"]:
		return _finish_error("profile must be diagnostic or production")
	if DirAccess.dir_exists_absolute(final_abs) or FileAccess.file_exists(final_abs):
		return _finish_error("Output already exists; refusing to overwrite: " + final_abs)
	var parent_dir := final_abs.get_base_dir()
	var make_parent := DirAccess.make_dir_recursive_absolute(parent_dir)
	if make_parent != OK:
		return _finish_error("Cannot create output parent (%d): %s" % [make_parent, parent_dir])
	out_abs = final_abs + ".building"
	if DirAccess.dir_exists_absolute(out_abs) or FileAccess.file_exists(out_abs):
		return _finish_error("Staging directory already exists; refusing to overwrite: " + out_abs)
	# A non-recursive mkdir reserves this exact target atomically. Two workers
	# racing to export the same trace cannot both enter the staging directory.
	var mk := DirAccess.make_dir_absolute(out_abs)
	if mk != OK:
		return _finish_error("Cannot reserve staging directory (%d): %s" % [mk, out_abs])
	var started := Time.get_ticks_usec()
	_update_progress("building_source", "Building procedural geometry source")
	var source_script: Script = load(source_path)
	if source_script == null: return _abort_error("Unable to load geometry source: " + source_path)
	geometry_source = source_script.new()
	geometry_source.build({"seed": export_seed, "length_km": export_length_km, "cut_index": 1, "mode": export_mode})
	source_description = geometry_source.source_metadata()
	source_parameters = geometry_source.generation_parameters()
	if _cancel_requested(): return _abort_cancelled()
	_update_progress("selecting_chunks", "Selecting route coverage")
	var route_data: Dictionary = geometry_source.selected_routes(MAIN_JOIN_EXTENSION)
	route_polylines = route_data.get("polylines", [])
	route_info = route_data.get("routes", [])
	join_pairs = route_data.get("join_pairs", [])
	if export_mode == "fixture" and (route_polylines.size() != 3 or str(source_description.get("cut_type", "")) != "needle"):
		return _abort_error("Expected cut_index 1 to be needle")
	if route_polylines.is_empty() or route_info.size() != route_polylines.size():
		return _abort_error("Geometry source did not provide a complete route list")
	_prepare_routes()
	var selection := _select_chunks(2000.0, ROUTE_PAD)
	if selection.is_empty(): return _abort_error("Route coverage selected no spatial cells")
	var estimate_1000 := _select_chunks(1000.0, ROUTE_PAD)
	if estimate_only:
		var estimate := {"mode": export_mode, "routes": route_info.size(), "bounds": fixture_bounds, "chunks_1000": estimate_1000.size(), "chunks_2000": selection.size(), "estimated_collision_bytes_1000": estimate_1000.size() * _chunk_bytes(1000.0, COLLISION_STEP), "estimated_collision_bytes_2000": selection.size() * _chunk_bytes(2000.0, COLLISION_STEP), "estimated_presentation_bytes_base": selection.size() * _chunk_bytes(2000.0, float(PRESENTATION_STEPS["base"])), "estimated_presentation_bytes_detail": selection.size() * _chunk_bytes(2000.0, float(PRESENTATION_STEPS["detail"]))}
		geometry_source.close(); geometry_source = null
		_remove_tree(out_abs)
		_update_progress("estimated", "Preflight complete", estimate)
		return {"status": "estimated", "exit_code": 0, "estimate": estimate}
	var planned_sets: Array[Dictionary] = []
	if export_profile == "production":
		planned_sets.append({"name": "collision/chunk_2000", "cells": selection, "size": 2000.0, "step": COLLISION_STEP})
		planned_sets.append({"name": "presentation/base", "cells": selection, "size": 2000.0, "step": float(PRESENTATION_STEPS["base"])})
	else:
		planned_sets.append({"name": "collision/chunk_1000", "cells": estimate_1000, "size": 1000.0, "step": COLLISION_STEP})
		planned_sets.append({"name": "collision/chunk_2000", "cells": selection, "size": 2000.0, "step": COLLISION_STEP})
		for level in PRESENTATION_STEPS:
			planned_sets.append({"name": "presentation/" + level, "cells": selection, "size": 2000.0, "step": float(PRESENTATION_STEPS[level])})
	total_chunks = 0
	for set_config in planned_sets: total_chunks += (set_config["cells"] as Array).size()
	completed_chunks = 0
	var export_started := Time.get_ticks_usec()
	var collision_metrics := {}
	var presentation_metrics := {}
	_update_progress("exporting_chunks", "Writing %d chunks" % total_chunks)
	for set_config in planned_sets:
		var set_name: String = set_config["name"]
		var directory := out_abs.path_join(set_name)
		var mkdir_error := DirAccess.make_dir_recursive_absolute(directory)
		if mkdir_error != OK: return _abort_error("Cannot create chunk directory (%d): %s" % [mkdir_error, directory])
		var counts: Dictionary = await _write_chunk_set(set_name, set_config["cells"], float(set_config["size"]), float(set_config["step"]), set_name)
		if bool(counts.get("cancelled", false)): return _abort_cancelled()
		if not error_message.is_empty(): return _abort_error(error_message)
		if set_name.begins_with("collision/"): collision_metrics[set_name.trim_prefix("collision/chunk_")] = counts
		else: presentation_metrics[set_name.trim_prefix("presentation/")] = counts
	if _cancel_requested(): return _abort_cancelled()
	var elapsed := float(Time.get_ticks_usec() - export_started) / 1000000.0
	var y_min := INF
	var y_max := -INF
	for metrics in collision_metrics.values() + presentation_metrics.values():
		y_min = minf(y_min, float(metrics["min_y_m"]))
		y_max = maxf(y_max, float(metrics["max_y_m"]))
	_update_progress("writing_metadata", "Writing route and generation metadata")
	var source_hashes := {
		"main.gd": _hash_file(ProjectSettings.globalize_path("res://main.gd")),
		"trackgen.gd": _hash_file(ProjectSettings.globalize_path("res://trackgen.gd")),
		"static_track_export.gd": _hash_file(ProjectSettings.globalize_path("res://static_track_pipeline/static_track_export.gd")),
		"static_track_export_job.gd": _hash_file(ProjectSettings.globalize_path("res://static_track_pipeline/static_track_export_job.gd")),
		"geometry_source_contract.gd": _hash_file(ProjectSettings.globalize_path("res://static_track_pipeline/geometry_source_contract.gd")),
		"geometry_source_provider": source_path,
		"geometry_source_provider_sha256": _hash_file(ProjectSettings.globalize_path(source_path)),
		"godot_version": Engine.get_version_info().string,
		"git_head": "d51f9a3b72399921710ab69a939acbcfdb51a19b"
	}
	var source_metadata := source_description.duplicate(true)
	source_metadata["export_mode"] = export_mode
	source_metadata["route_buffer_m"] = ROUTE_PAD
	source_metadata["main_join_extension_m"] = MAIN_JOIN_EXTENSION
	var parameters := source_parameters.duplicate(true)
	parameters["canonical_collision_step_m"] = COLLISION_STEP
	var actual_length_km := 0.0
	for route in route_info:
		if str(route.get("id", "")) == "main": actual_length_km = float(route.get("route_length_m", route.get("length_m", 0.0))) / 1000.0
	var manifest := {
		"format": "experimental PLY artifact layout; not a package schema",
		"source": source_metadata,
		"coordinate_system": {"x": "east/right, metres", "y": "up, metres", "z": "map y, metres", "units": "metres"},
		"bounds": {"min": [fixture_bounds.position.x, y_min, fixture_bounds.position.y], "max": [fixture_bounds.end.x, y_max, fixture_bounds.end.y], "x_size_m": fixture_bounds.size.x, "y_size_m": y_max - y_min, "z_size_m": fixture_bounds.size.y, "bounds_grid_m": BOUNDS_GRID},
		"route_count": route_info.size(),
		"route_ids": route_info.map(func(r: Dictionary) -> String: return str(r.get("id", ""))),
		"terrain_context_path_count": terrain_context_paths.size(),
		"collision_variants": collision_metrics,
		"presentation": presentation_metrics,
		"generation_parameters": parameters,
		"source_hashes": source_hashes,
		"elapsed_export_seconds": elapsed,
		"elapsed_total_seconds": float(Time.get_ticks_usec() - started) / 1000000.0
	}
	if export_profile == "diagnostic":
		_write_routes()
		_write_reference_samples()
		_write_visualization()
		_write_json("fixture.json", manifest)
	else:
		manifest["format"] = "static-track-userdata-v1"
		manifest["profile"] = "production"
		manifest["track_id"] = str(config.get("track_id", final_abs.get_file()))
		manifest["name"] = str(config.get("name", manifest["track_id"])).strip_edges()
		manifest["seed"] = export_seed
		manifest["requested_length_km"] = export_length_km
		manifest["actual_length_km"] = actual_length_km
		manifest["format_version"] = 1
		manifest["exporter_version"] = "static-track-export-job-1"
		manifest["created_at"] = Time.get_datetime_string_from_system(true)
		manifest["status"] = "ready"
		manifest["artifacts"] = {"collision": "collision/chunk_2000", "presentation": "presentation/base", "checksums": "artifact-hashes.json"}
		manifest["routes"] = route_info
		_write_json("track.json", manifest)
	if not error_message.is_empty(): return _abort_error(error_message)
	_update_progress("hashing", "Writing artifact checksums")
	_write_hash_manifest()
	if not error_message.is_empty(): return _abort_error(error_message)
	_update_progress("validating", "Validating generated track")
	var validation := StaticTrackRuntimeValidator.validate_directory(out_abs, export_profile == "production", export_profile == "production")
	if not bool(validation.get("ok", false)):
		return _abort_error("Runtime validation failed: " + str(validation.get("errors", [])))
	if _cancel_requested(): return _abort_cancelled()
	geometry_source.close(); geometry_source = null
	_update_progress("publishing", "Publishing complete output")
	var rename_error := DirAccess.rename_absolute(out_abs, final_abs)
	if rename_error != OK: return _abort_error("Cannot publish completed output (%d): %s" % [rename_error, final_abs])
	out_abs = ""
	validation["manifest"] = final_abs.path_join("track.json" if export_profile == "production" else "fixture.json")
	_update_progress("ready", "Track export is ready", {"published_path": final_abs, "validation": validation, "elapsed_export_seconds": elapsed})
	print("STATIC_TRACK_EXPORT_OK ", final_abs)
	print("GENERATION seed=", export_seed, " length_km=", export_length_km, " mode=", export_mode, " profile=", export_profile)
	print("BOUNDS_XZ ", fixture_bounds)
	print("COLLISION ", JSON.stringify(collision_metrics))
	print("PRESENTATION ", JSON.stringify(presentation_metrics))
	print("ELAPSED_EXPORT_SECONDS ", elapsed)
	return {"status": "ready", "exit_code": 0, "path": final_abs, "validation": validation}

func _yield_frame() -> void:
	if scheduler is SceneTree:
		await (scheduler as SceneTree).process_frame
	elif scheduler is Node:
		await (scheduler as Node).get_tree().process_frame

func _cancel_requested() -> bool:
	return not cancel_path.is_empty() and FileAccess.file_exists(cancel_path)

func _update_progress(status: String, message := "", extra: Dictionary = {}) -> void:
	if progress_path.is_empty(): return
	if not progress_parent_ready:
		var progress_parent := ProjectSettings.globalize_path(progress_path.get_base_dir())
		var dir_error := DirAccess.make_dir_recursive_absolute(progress_parent)
		if dir_error != OK:
			push_error("Cannot create progress directory (%d): %s" % [dir_error, progress_parent])
			return
		progress_parent_ready = true
	var data := {"status": status, "message": message, "worker_pid": OS.get_process_id(), "completed_chunks": completed_chunks, "total_chunks": total_chunks, "progress": float(completed_chunks) / float(maxi(total_chunks, 1)), "updated_at": Time.get_datetime_string_from_system(true)}
	for key in extra: data[key] = extra[key]
	var tmp := progress_path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null: return
	f.store_string(JSON.stringify(data, "\t") + "\n")
	f.flush()
	f.close()
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_final := ProjectSettings.globalize_path(progress_path)
	if FileAccess.file_exists(progress_path): DirAccess.remove_absolute(abs_final)
	DirAccess.rename_absolute(abs_tmp, abs_final)

func _finish_error(message: String) -> Dictionary:
	push_error(message)
	_update_progress("error", message)
	return {"status": "error", "exit_code": 2, "error": message}

func _abort_error(message: String) -> Dictionary:
	if geometry_source != null:
		geometry_source.close(); geometry_source = null
	if not out_abs.is_empty() and DirAccess.dir_exists_absolute(out_abs): _remove_tree(out_abs)
	return _finish_error(message)

func _abort_cancelled() -> Dictionary:
	if geometry_source != null:
		geometry_source.close(); geometry_source = null
	if not out_abs.is_empty() and DirAccess.dir_exists_absolute(out_abs): _remove_tree(out_abs)
	_update_progress("cancelled", "Export cancelled between chunks")
	return {"status": "cancelled", "exit_code": 130}

func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path): return
	var dir := DirAccess.open(path)
	if dir == null: return
	for name in dir.get_files(): DirAccess.remove_absolute(path.path_join(name))
	for name in dir.get_directories(): _remove_tree(path.path_join(name))
	DirAccess.remove_absolute(path)

func _prepare_routes() -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for poly in route_polylines:
		for point in poly:
			lo.x = minf(lo.x, point.x); lo.y = minf(lo.y, point.y)
			hi.x = maxf(hi.x, point.x); hi.y = maxf(hi.y, point.y)
	lo -= Vector2(ROUTE_PAD, ROUTE_PAD); hi += Vector2(ROUTE_PAD, ROUTE_PAD)
	lo = Vector2(floor(lo.x / BOUNDS_GRID) * BOUNDS_GRID, floor(lo.y / BOUNDS_GRID) * BOUNDS_GRID)
	hi = Vector2(ceil(hi.x / BOUNDS_GRID) * BOUNDS_GRID, ceil(hi.y / BOUNDS_GRID) * BOUNDS_GRID)
	fixture_bounds = Rect2(lo, hi - lo)
	terrain_context_paths.clear()
	for context_path in geometry_source.terrain_context_paths():
		var points: Array = context_path["points_xz_m"]
		var touches_context := false
		for i in range(points.size() - 1):
			var a := Vector2(points[i][0], points[i][1])
			var b := Vector2(points[i + 1][0], points[i + 1][1])
			if _segment_rect_distance(a, b, fixture_bounds) <= ROUTE_PAD:
				touches_context = true
				break
		if touches_context:
			terrain_context_paths.append(context_path)

func _select_chunks(chunk_size: float, pad: float) -> Array:
	var chosen := {}
	for poly in route_polylines:
		for i in range(poly.size() - 1):
			var a: Vector2 = poly[i]
			var b: Vector2 = poly[i + 1]
			var x0 := int(floor((minf(a.x, b.x) - pad) / chunk_size))
			var x1 := int(floor((maxf(a.x, b.x) + pad) / chunk_size))
			var z0 := int(floor((minf(a.y, b.y) - pad) / chunk_size))
			var z1 := int(floor((maxf(a.y, b.y) + pad) / chunk_size))
			for x in range(x0, x1 + 1):
				for z in range(z0, z1 + 1):
					if _segment_rect_distance(a, b, Rect2(Vector2(x, z) * chunk_size, Vector2.ONE * chunk_size)) <= pad + 0.001:
						chosen[Vector2i(x, z)] = true
	var result: Array = chosen.keys()
	result.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.x < b.x or (a.x == b.x and a.y < b.y))
	return result

func _segment_rect_distance(a: Vector2, b: Vector2, rect: Rect2) -> float:
	if _segment_intersects_rect(a, b, rect): return 0.0
	var best := minf(_point_rect_distance(a, rect), _point_rect_distance(b, rect))
	for corner in [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]:
		best = minf(best, _point_segment_distance(corner, a, b))
	return best

func _segment_intersects_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	var d := b - a
	var t0 := 0.0; var t1 := 1.0
	for pair in [[-d.x, a.x - r.position.x], [d.x, r.end.x - a.x], [-d.y, a.y - r.position.y], [d.y, r.end.y - a.y]]:
		var p: float = pair[0]; var q: float = pair[1]
		if absf(p) < 0.0000001:
			if q < 0.0: return false
		else:
			var t := q / p
			if p < 0.0: t0 = maxf(t0, t)
			else: t1 = minf(t1, t)
			if t0 > t1: return false
	return true

func _point_rect_distance(p: Vector2, r: Rect2) -> float:
	return p.distance_to(Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y)))

func _point_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.000001), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _write_chunk_set(directory: String, cells: Array, chunk_size: float, step: float, set_name: String) -> Dictionary:
	var n := int(round(chunk_size / step))
	if absf(float(n) * step - chunk_size) > 0.001:
		_fail("Chunk size must be divisible by sample step")
		return {}
	var total_vertices := 0
	var total_triangles := 0
	var total_bytes := 0
	var min_y := INF
	var max_y := -INF
	var t0 := Time.get_ticks_usec()
	for cell in cells:
		if _cancel_requested(): return {"cancelled": true}
		var origin := Vector2(cell) * chunk_size
		var path := out_abs.path_join(directory).path_join("x%+08d_z%+08d.ply" % [int(origin.x), int(origin.y)])
		var result := _write_ply(path, origin, n, step)
		if not error_message.is_empty(): return {}
		total_vertices += result["vertices"]
		total_triangles += result["triangles"]
		total_bytes += result["bytes"]
		min_y = minf(min_y, float(result["min_y_m"]))
		max_y = maxf(max_y, float(result["max_y_m"]))
		completed_chunks += 1
		_update_progress("exporting_chunks", "%s: %d / %d chunks" % [set_name, completed_chunks, total_chunks])
		await _yield_frame()
	return {"chunk_size_m": chunk_size, "sample_step_m": step, "chunk_count": cells.size(), "vertex_count_with_seams": total_vertices, "triangle_count": total_triangles, "byte_size": total_bytes, "min_y_m": min_y, "max_y_m": max_y, "write_seconds": float(Time.get_ticks_usec() - t0) / 1000000.0}

func _write_ply(path: String, origin: Vector2, n: int, step: float) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_fail("Unable to create " + path)
		return {"vertices": 0, "triangles": 0, "bytes": 0}
	var vcount := (n + 1) * (n + 1)
	var fcount := n * n * 2
	file.store_string("ply\nformat binary_little_endian 1.0\nelement vertex %d\nproperty float x\nproperty float y\nproperty float z\nproperty float nx\nproperty float ny\nproperty float nz\nelement face %d\nproperty list uchar uint vertex_indices\nend_header\n" % [vcount, fcount])
	# One-cell halo lets each seam vertex use the same area-weighted normals
	# as its neighbor, including incident triangles on both sides of the seam.
	var side := n + 3
	var heights := PackedFloat32Array(); heights.resize(side * side)
	var min_y := INF
	var max_y := -INF
	for j in range(-1, n + 2):
		for i in range(-1, n + 2):
			var sample_height: float = geometry_source.sample_height(origin.x + float(i) * step, origin.y + float(j) * step)
			heights[(j + 1) * side + i + 1] = sample_height
	var normals := PackedVector3Array(); normals.resize(vcount)
	for j in range(-1, n + 1):
		for i in range(-1, n + 1):
			var a := Vector3(origin.x + i * step, heights[(j + 1) * side + i + 1], origin.y + j * step)
			var b := Vector3(origin.x + (i + 1) * step, heights[(j + 1) * side + i + 2], origin.y + j * step)
			var c := Vector3(origin.x + i * step, heights[(j + 2) * side + i + 1], origin.y + (j + 1) * step)
			var d := Vector3(origin.x + (i + 1) * step, heights[(j + 2) * side + i + 2], origin.y + (j + 1) * step)
			var n1 := (c - a).cross(b - a)
			var n2 := (c - b).cross(d - b)
			_accumulate_normal(normals, n, i, j, n1)
			_accumulate_normal(normals, n, i, j + 1, n1)
			_accumulate_normal(normals, n, i + 1, j, n1)
			_accumulate_normal(normals, n, i + 1, j, n2)
			_accumulate_normal(normals, n, i, j + 1, n2)
			_accumulate_normal(normals, n, i + 1, j + 1, n2)
	for j in range(n + 1):
		for i in range(n + 1):
			var x := origin.x + float(i) * step
			var z := origin.y + float(j) * step
			var h := heights[(j + 1) * side + i + 1]
			min_y = minf(min_y, h)
			max_y = maxf(max_y, h)
			var norm := normals[j * (n + 1) + i].normalized()
			file.store_float(x); file.store_float(h); file.store_float(z)
			file.store_float(norm.x); file.store_float(norm.y); file.store_float(norm.z)
	for j in range(n):
		for i in range(n):
			var a := j * (n + 1) + i
			var b := a + 1
			var c := a + n + 1
			var d := c + 1
			# Upward-facing winding; each cell is represented once by its owning chunk.
			_write_face(file, a, c, b); _write_face(file, b, c, d)
	file.flush()
	var size := file.get_length()
	file.close()
	return {"vertices": vcount, "triangles": fcount, "bytes": size, "min_y_m": min_y, "max_y_m": max_y}

func _accumulate_normal(normals: PackedVector3Array, n: int, x: int, z: int, value: Vector3) -> void:
	if x >= 0 and x <= n and z >= 0 and z <= n:
		var index := z * (n + 1) + x
		normals[index] += value

func _write_face(file: FileAccess, a: int, b: int, c: int) -> void:
	file.store_8(3); file.store_32(a); file.store_32(b); file.store_32(c)

func _write_routes() -> void:
	_write_json("route-graph.json", {"routes": route_info, "terrain_context_paths": terrain_context_paths, "join_pairs": join_pairs, "export_mode": export_mode})

func _chunk_bytes(chunk_size: float, step: float) -> int:
	var n := int(round(chunk_size / step))
	return 0 if n <= 0 else 123 + (n + 1) * (n + 1) * 24 + n * n * 2 * 13

func _write_reference_samples() -> void:
	var samples: Array = []
	for ri in route_polylines.size():
		var poly: PackedVector2Array = route_polylines[ri]
		for i in range(0, poly.size(), maxi(1, int(poly.size() / 32))):
			var p := poly[i]
			samples.append({"route_index": ri, "x": p.x, "z": p.y, "height": geometry_source.sample_height(p.x, p.y)})
	if export_mode == "fixture":
		var join_points: Array = [[route_polylines[0][-1], route_polylines[1][0]], [route_polylines[1][-1], route_polylines[2][0]]]
		for pair in join_points:
			for p: Vector2 in pair:
				samples.append({"kind": "join", "x": p.x, "z": p.y, "height": geometry_source.sample_height(p.x, p.y)})
	else:
		for join in join_pairs:
			for key in ["branch_start_xz_m", "main_start_xz_m", "branch_end_xz_m", "main_end_xz_m"]:
				var p: Array = join[key]
				samples.append({"kind": "join", "route_id": join["route_id"], "x": float(p[0]), "z": float(p[1]), "height": geometry_source.sample_height(float(p[0]), float(p[1]))})
	_write_json("canonical-samples.json", {"source": str(source_description.get("height_source", "geometry source sample_height(x,z)")), "samples": samples})

func _write_visualization() -> void:
	var image := Image.create(1200, 900, false, Image.FORMAT_RGBA8)
	for py in image.get_height():
		for px in image.get_width():
			var x := fixture_bounds.position.x + (float(px) + 0.5) / image.get_width() * fixture_bounds.size.x
			var z := fixture_bounds.position.y + (float(py) + 0.5) / image.get_height() * fixture_bounds.size.y
			var h: float = geometry_source.sample_height(x, z)
			var t := clampf((h - 3000.0) / 2500.0, 0.0, 1.0)
			image.set_pixel(px, py, Color(0.12 + t * 0.25, 0.22 + t * 0.3, 0.18 + t * 0.18, 1.0))
	for pi in route_polylines.size():
		var poly: PackedVector2Array = route_polylines[pi]
		for i in range(poly.size() - 1):
			_draw_line(image, _pixel(poly[i]), _pixel(poly[i + 1]), Color(1.0, 0.85, 0.1, 1.0) if pi == 1 else Color(0.1, 0.9, 1.0, 1.0))
	for context in terrain_context_paths:
		var points: Array = context["points_xz_m"]
		for i in range(points.size() - 1):
			_draw_line(image, _pixel(Vector2(points[i][0], points[i][1])), _pixel(Vector2(points[i + 1][0], points[i + 1][1])), Color(0.9, 0.35, 0.8, 1.0))
	image.save_png(out_abs.path_join("fixture_topdown.png"))

func _pixel(p: Vector2) -> Vector2i:
	return Vector2i(int((p.x - fixture_bounds.position.x) / fixture_bounds.size.x * 1199.0), int((p.y - fixture_bounds.position.y) / fixture_bounds.size.y * 899.0))

func _draw_line(image: Image, a: Vector2i, b: Vector2i, color: Color) -> void:
	var dx := absi(b.x - a.x); var sx := 1 if a.x < b.x else -1
	var dy := -absi(b.y - a.y); var sy := 1 if a.y < b.y else -1
	var err := dx + dy; var p := a
	while true:
		if p.x >= 0 and p.y >= 0 and p.x < image.get_width() and p.y < image.get_height(): image.set_pixel(p.x, p.y, color)
		if p == b: break
		var e2 := 2 * err
		if e2 >= dy: err += dy; p.x += sx
		if e2 <= dx: err += dx; p.y += sy

func _write_hash_manifest() -> void:
	var entries: Array = []
	var root := DirAccess.open(out_abs)
	root.list_dir_begin()
	var name := root.get_next()
	while name != "":
		if root.current_is_dir():
			_collect_files(out_abs.path_join(name), name, entries)
		elif name != "artifact-hashes.json":
			entries.append(_artifact_entry(out_abs.path_join(name), name))
		name = root.get_next()
	root.list_dir_end()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return str(a["path"]) < str(b["path"]))
	_write_json("artifact-hashes.json", {"files": entries})

func _collect_files(dir_path: String, prefix: String, entries: Array) -> void:
	var dir := DirAccess.open(dir_path)
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := dir_path.path_join(name)
		if dir.current_is_dir(): _collect_files(path, prefix.path_join(name), entries)
		else: entries.append(_artifact_entry(path, prefix.path_join(name)))
		name = dir.get_next()
	dir.list_dir_end()

func _artifact_entry(path: String, relative: String) -> Dictionary:
	return {"path": relative, "byte_size": FileAccess.get_file_as_bytes(path).size(), "sha256": _hash_file(path)}

func _hash_file(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	while not file.eof_reached(): ctx.update(file.get_buffer(1024 * 1024))
	file.close()
	return ctx.finish().hex_encode()

func _write_json(name: String, value: Variant) -> void:
	var file := FileAccess.open(out_abs.path_join(name), FileAccess.WRITE)
	if file == null:
		_fail("Unable to write " + name)
		return
	file.store_string(JSON.stringify(value, "\t", false, true) + "\n")
	file.close()

func _fail(message: String) -> void:
	if error_message.is_empty(): error_message = message
	push_error(message)
