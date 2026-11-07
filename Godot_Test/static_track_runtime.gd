extends Node3D
class_name StaticTrackRuntime

const ROOT := ""
const VALIDATOR := preload("res://static_track_pipeline/static_track_runtime_validator.gd")
const PRESENTATION_SUBDIR := "presentation/base"
const COLLISION_SUBDIR := "collision/chunk_2000"
const GROUP_SIZE_M := 16000.0
const CHUNK_SIZE_M := 2000.0
const COLLISION_RADIUS_M := 5000.0
const UNLOAD_RADIUS_M := 7000.0
const PREFETCH_SECONDS := 2.5
const MAX_LOAD_PER_TICK := 3
const UPDATE_INTERVAL := 0.15

static func _read_manifest(root: String) -> Dictionary:
	for name in ["track.json", "fixture.json"]:
		var path := root.path_join(name)
		if not FileAccess.file_exists(path): continue
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string(path)) != OK: continue
		var parsed = parser.data
		if parsed is Dictionary: return parsed
	return {}

static func has_export(root := ROOT) -> bool:
	if root.is_empty() or root.contains(".building"): return false
	return bool(VALIDATOR.validate_directory(root).get("ok", false))

static func _ply_count(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null: return 0
	dir.list_dir_begin()
	var name := dir.get_next()
	var count := 0
	while name != "":
		if not dir.current_is_dir() and name.to_lower().ends_with(".ply"): count += 1
		name = dir.get_next()
	dir.list_dir_end()
	return count

var terrain_material: Material
var ship: RigidBody3D
var track_root := ""
var presentation_dir := ""
var collision_dir := ""
var visual_regions := {}
var collision_files := {}
var collision_bodies := {}
var collision_queue: Array[Vector2i] = []
var update_elapsed := 0.0
var load_ms_total := 0.0
var load_count := 0
var missing_center := false
var missing_ahead := 0
var last_diag_ms := 0
var physics_height_delta := NAN
var physics_height_samples := 0
var draw_mesh_count := 0
var draw_call_estimate := 0
var presentation_load_ms := -1.0
var pending_since := {}
var pending_warned := {}
var missing_files_reported := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func configure(p_ship: RigidBody3D, p_material: Material) -> void:
	ship = p_ship
	terrain_material = p_material
	update_collisions(true)
	set_process(true)
	call_deferred("_log_diagnostics")
	print("STATIC runtime configured ship=", ship.name, " collision_loaded=", collision_bodies.size())

func load_presentation(p_material: Material, p_root := ROOT) -> bool:
	track_root = p_root
	presentation_dir = track_root.path_join(PRESENTATION_SUBDIR)
	collision_dir = track_root.path_join(COLLISION_SUBDIR)
	if not has_export(track_root):
		push_warning("Static track export not found or incomplete: " + ProjectSettings.globalize_path(track_root))
		return false
	terrain_material = p_material
	_scan_collision_manifest()
	_load_presentation_regions()
	return not collision_files.is_empty() and not visual_regions.is_empty()

func _process(dt: float) -> void:
	if not is_instance_valid(ship): return
	update_elapsed += dt
	if update_elapsed >= UPDATE_INTERVAL:
		update_elapsed = 0.0
		update_collisions(false)
		_log_diagnostics()

func _scan_collision_manifest() -> void:
	_emit_event("collision_manifest_scan_start", collision_dir)
	var dir := DirAccess.open(collision_dir)
	if dir == null:
		push_error("Static collision directory missing: " + collision_dir)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	var re := RegEx.new(); re.compile("^x([+-]\\d+)_z([+-]\\d+)\\.ply$")
	while name != "":
		if not dir.current_is_dir():
			var m := re.search(name)
			if m != null:
				var key := Vector2i(floori(float(m.get_string(1)) / CHUNK_SIZE_M), floori(float(m.get_string(2)) / CHUNK_SIZE_M))
				collision_files[key] = collision_dir.path_join(name)
		name = dir.get_next()
	dir.list_dir_end()
	print("STATIC collision manifest chunks=", collision_files.size())
	_emit_event("collision_manifest_scan_complete", "chunks=%d" % collision_files.size())

func _load_presentation_regions() -> void:
	var load_started := Time.get_ticks_usec()
	_emit_event("presentation_load_start", presentation_dir)
	var dir := DirAccess.open(presentation_dir)
	if dir == null:
		push_error("Static presentation directory missing: " + presentation_dir)
		return
	var grouped := {}
	var presentation_chunk_count := 0
	dir.list_dir_begin()
	var name := dir.get_next()
	var re := RegEx.new(); re.compile("^x([+-]\\d+)_z([+-]\\d+)\\.ply$")
	while name != "":
		if not dir.current_is_dir():
			var mat := re.search(name)
			if mat != null:
				presentation_chunk_count += 1
				var ox := int(mat.get_string(1)); var oz := int(mat.get_string(2))
				var group := Vector2i(floori(float(ox) / GROUP_SIZE_M), floori(float(oz) / GROUP_SIZE_M))
				if not grouped.has(group): grouped[group] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "i": PackedInt32Array()}
				var chunk := _read_ply(presentation_dir.path_join(name), false)
				if chunk.is_empty(): push_error("Could not read presentation chunk: " + name)
				else:
					var dst: Dictionary = grouped[group]
					var offset: int = (dst["v"] as PackedVector3Array).size()
					var vertices: PackedVector3Array = dst["v"]
					var normals: PackedVector3Array = dst["n"]
					var merged_indices: PackedInt32Array = dst["i"]
					vertices.append_array(chunk["v"])
					normals.append_array(chunk["n"])
					var indices: PackedInt32Array = chunk["i"]
					for idx in indices: merged_indices.append(idx + offset)
					dst["v"] = vertices
					dst["n"] = normals
					dst["i"] = merged_indices
					grouped[group] = dst
		name = dir.get_next()
	dir.list_dir_end()
	for key in grouped:
		var data: Dictionary = grouped[key]
		var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = data["v"]; arrays[Mesh.ARRAY_NORMAL] = data["n"]; arrays[Mesh.ARRAY_INDEX] = _orient_indices_for_godot(data["i"])
		var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var instance := MeshInstance3D.new(); instance.name = "StaticPresentation_%d_%d" % [key.x, key.y]; instance.mesh = mesh; instance.material_override = terrain_material
		add_child(instance); visual_regions[key] = instance
	draw_mesh_count = visual_regions.size()
	draw_call_estimate = draw_mesh_count
	presentation_load_ms = float(Time.get_ticks_usec() - load_started) / 1000.0
	print("STATIC presentation chunks=", presentation_chunk_count, " merged_regions=", draw_mesh_count, " load_ms=", presentation_load_ms)
	_emit_event("presentation_load_complete", "regions=%d;ms=%.2f" % [draw_mesh_count, presentation_load_ms])

func update_collisions(force: bool) -> void:
	if not is_instance_valid(ship): return
	var pos := Vector2(ship.global_position.x, ship.global_position.z)
	var wanted := {}
	# Radial coverage works in every direction, including while stopped or reversing.
	var radius_cells := int(ceil(COLLISION_RADIUS_M / CHUNK_SIZE_M))
	var center := Vector2i(floori(pos.x / CHUNK_SIZE_M), floori(pos.y / CHUNK_SIZE_M))
	for x in range(center.x - radius_cells, center.x + radius_cells + 1):
		for z in range(center.y - radius_cells, center.y + radius_cells + 1):
			var rect := Rect2(Vector2(x, z) * CHUNK_SIZE_M, Vector2.ONE * CHUNK_SIZE_M)
			if _point_rect_distance(pos, rect) <= COLLISION_RADIUS_M: wanted[Vector2i(x, z)] = true
	# Extra forward look-ahead; radial neighborhood above remains authoritative.
	var velocity := Vector2(ship.linear_velocity.x, ship.linear_velocity.z)
	if velocity.length() > 1.0:
		var ahead := pos + velocity.limit_length(2300.0) * PREFETCH_SECONDS
		var ac := Vector2i(floori(ahead.x / CHUNK_SIZE_M), floori(ahead.y / CHUNK_SIZE_M))
		for x in range(ac.x - 1, ac.x + 2):
			for z in range(ac.y - 1, ac.y + 2): wanted[Vector2i(x, z)] = true
	collision_queue.clear()
	for key in wanted:
		if collision_files.has(key) and not collision_bodies.has(key): collision_queue.append(key)
	collision_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _chunk_center(a).distance_squared_to(pos) < _chunk_center(b).distance_squared_to(pos))
	var wanted_set := wanted
	var now_ms := Time.get_ticks_msec()
	for key in wanted_set:
		if not collision_files.has(key):
			if not missing_files_reported.has(key):
				missing_files_reported[key] = true
				_emit_event("collision_chunk_missing", str(key))
			continue
		if collision_bodies.has(key):
			pending_since.erase(key); pending_warned.erase(key)
		elif not pending_since.has(key):
			pending_since[key] = now_ms
		elif now_ms - int(pending_since[key]) >= 500 and not pending_warned.has(key):
			pending_warned[key] = true
			_emit_event("collision_chunk_delayed", "%s;wait_ms=%d" % [str(key), now_ms - int(pending_since[key])])
	var budget := mini(9, collision_queue.size()) if force else mini(MAX_LOAD_PER_TICK, collision_queue.size())
	for i in budget: _load_collision(collision_queue[i])
	for key in collision_bodies.keys():
		if _point_rect_distance(pos, Rect2(Vector2(key) * CHUNK_SIZE_M, Vector2.ONE * CHUNK_SIZE_M)) > UNLOAD_RADIUS_M and not wanted.has(key):
			(collision_bodies[key] as Node).queue_free(); collision_bodies.erase(key)
	var center_key := Vector2i(floori(pos.x / CHUNK_SIZE_M), floori(pos.y / CHUNK_SIZE_M))
	missing_center = collision_files.has(center_key) and not collision_bodies.has(center_key)
	missing_ahead = 0
	for key in wanted:
		if collision_files.has(key) and not collision_bodies.has(key): missing_ahead += 1

func _load_collision(key: Vector2i) -> void:
	var started := Time.get_ticks_usec()
	_emit_event("collision_chunk_load_start", str(key))
	var chunk := _read_ply(collision_files[key], true)
	if chunk.is_empty():
		push_error("Static collision chunk failed: " + str(key))
		_emit_event("collision_chunk_load_failed", str(key))
		return
	var arrays: Array = []; arrays.resize(Mesh.ARRAY_MAX); arrays[Mesh.ARRAY_VERTEX] = chunk["v"]; arrays[Mesh.ARRAY_NORMAL] = chunk["n"]; arrays[Mesh.ARRAY_INDEX] = _orient_indices_for_godot(chunk["i"])
	var mesh := ArrayMesh.new(); mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var shape := mesh.create_trimesh_shape()
	shape.backface_collision = true
	var body := StaticBody3D.new(); body.name = "StaticCollision_%d_%d" % [key.x, key.y]; body.collision_layer = 1; body.collision_mask = 0
	var collision := CollisionShape3D.new(); collision.shape = shape; body.add_child(collision); add_child(body); collision_bodies[key] = body
	var elapsed := float(Time.get_ticks_usec() - started) / 1000.0; load_ms_total += elapsed; load_count += 1
	_emit_event("collision_chunk_load_complete", "%s;ms=%.2f" % [str(key), elapsed])

func record_physics_height(y: float, analytic_y: float) -> void:
	physics_height_delta = y - analytic_y
	physics_height_samples += 1

func _log_diagnostics() -> void:
	var now := Time.get_ticks_msec()
	if now - last_diag_ms < 1000: return
	last_diag_ms = now
	var p := Vector2(ship.global_position.x, ship.global_position.z)
	var analytic_y: float = get_parent().call("height", p.x, p.y)
	var h := ship.global_position.y - analytic_y
	var query := PhysicsRayQueryParameters3D.create(ship.global_position + Vector3.UP * 2000.0, ship.global_position - Vector3.UP * 10000.0, 1, [ship.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var physics_y := float(hit["position"].y) if not hit.is_empty() else NAN
	if hit.is_empty(): physics_height_delta = NAN
	else: record_physics_height(physics_y, analytic_y)
	var actual_draw_calls := int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
	var key := Vector2i(floori(p.x / CHUNK_SIZE_M), floori(p.y / CHUNK_SIZE_M))
	var process_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var physics_ms := Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var memory_mb := Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0
	var line := "STATIC_STREAM fps=%d process_ms=%.2f physics_ms=%.2f memory_static_mb=%.1f bodies=%d missing_center=%s missing_wanted=%d analytic_agl=%.2f physics_y=%.2f analytic_physics_delta=%.2f loads=%d load_avg_ms=%.2f visual_regions=%d draw_est=%d draw_calls=%d" % [Engine.get_frames_per_second(), process_ms, physics_ms, memory_mb, collision_bodies.size(), str(missing_center), missing_ahead, h, physics_y, physics_height_delta, load_count, load_ms_total / maxf(1.0, float(load_count)), draw_mesh_count, draw_call_estimate, actual_draw_calls]
	if not collision_files.has(key): line += " NO_EXPORTED_CHUNK_AT_SHIP=" + str(key)
	if missing_center or missing_ahead > 0: push_warning(line)
	else: print(line)

func _emit_event(event_name: String, detail := "") -> void:
	if get_parent() != null:
		var recorder = get_parent().get("performance_diag")
		if recorder != null: recorder.record_event(event_name, detail)

func _read_ply(path: String, _collision: bool) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {}
	file.big_endian = false
	var nv := 0; var nf := 0; var header_done := false
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("element vertex "): nv = int(line.get_slice(" ", 2))
		elif line.begins_with("element face "): nf = int(line.get_slice(" ", 2))
		elif line == "end_header": header_done = true; break
	if not header_done or nv <= 0 or nf <= 0: file.close(); return {}
	var verts := PackedVector3Array(); verts.resize(nv); var normals := PackedVector3Array(); normals.resize(nv)
	for i in nv:
		verts[i] = Vector3(file.get_float(), file.get_float(), file.get_float())
		normals[i] = Vector3(file.get_float(), file.get_float(), file.get_float())
	var indices := PackedInt32Array(); indices.resize(nf * 3)
	for i in nf:
		if file.get_8() != 3: file.close(); return {}
		indices[i * 3] = int(file.get_32()); indices[i * 3 + 1] = int(file.get_32()); indices[i * 3 + 2] = int(file.get_32())
	file.close()
	return {"v": verts, "n": normals, "i": indices}

func _orient_indices_for_godot(source: PackedInt32Array) -> PackedInt32Array:
	# PLY exporter winding has +Y cross, while Godot/Jolt treats the opposite
	# winding as the front face. Match Generated's a,b,c index convention.
	var indices := source.duplicate()
	for i in range(0, indices.size(), 3):
		var swap := indices[i + 1]
		indices[i + 1] = indices[i + 2]
		indices[i + 2] = swap
	return indices

func _point_rect_distance(p: Vector2, rect: Rect2) -> float:
	return p.distance_to(Vector2(clampf(p.x, rect.position.x, rect.end.x), clampf(p.y, rect.position.y, rect.end.y)))

func _chunk_center(key: Vector2i) -> Vector2:
	return (Vector2(key) + Vector2.ONE * 0.5) * CHUNK_SIZE_M

func _exit_tree() -> void:
	pass
