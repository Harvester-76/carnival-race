extends SceneTree

const MAIN := preload("res://main.gd")
const SEED := 11
const LENGTH_KM := 650.0
const NEEDLE_CENTER := Vector2(77000.0, -199475.0)
const NEEDLE_HALF := 250.0
const NEEDLE_STEP := 5.0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var track := MAIN.new() as Node3D
	track.set("track_seed", SEED)
	track.set("gen_len_km", LENGTH_KM)
	track.call("_build_track")

	var missing_tiles := 0
	var route_sample_count := 0
	var lines: Array = [track.get("trk_pts")]
	for branch in track.get("branches"):
		lines.append(branch["pts"])
	for spur in track.get("spurs"):
		lines.append(spur["pts"])
	for line in lines:
		for i in range(line.size() - 1):
			var a: Vector2 = line[i]
			var b: Vector2 = line[i + 1]
			var steps := maxi(1, ceili(a.distance_to(b) / 250.0))
			for j in range(steps + 1):
				var p := a.lerp(b, float(j) / float(steps))
				var tile := Vector2i(floori(p.x / 1000.0), floori(p.y / 1000.0))
				route_sample_count += 1
				if not (track.get("track_tiles") as Dictionary).has(tile):
					missing_tiles += 1

	var max_delta := 0.0
	var max_at := Vector2.ZERO
	var prev_rows: Array = []
	var x0 := NEEDLE_CENTER.x - NEEDLE_HALF
	var z0 := NEEDLE_CENTER.y - NEEDLE_HALF
	var n := int(NEEDLE_HALF * 2.0 / NEEDLE_STEP) + 1
	for zi in n:
		var row: Array = []
		for xi in n:
			var x := x0 + float(xi) * NEEDLE_STEP
			var z := z0 + float(zi) * NEEDLE_STEP
			var h: float = track.call("height", x, z)
			row.append(h)
			if xi > 0:
				var dx := absf(h - float(row[xi - 1]))
				if dx > max_delta:
					max_delta = dx
					max_at = Vector2(x - NEEDLE_STEP, z)
				if zi > 0:
					var dz := absf(h - float(prev_rows[xi]))
					if dz > max_delta:
						max_delta = dz
						max_at = Vector2(x, z - NEEDLE_STEP)
		prev_rows = row

	# Build the real LOD0 tile containing the known branch-overlap location,
	# and verify it produces a nonempty collision shape.
	var tile_key := Vector3i(77, -200, 0)
	track.call("_gen_tile", tile_key)
	var data: Array = (track.get("chunk_data") as Dictionary)[tile_key]
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data[0]
	arrays[Mesh.ARRAY_NORMAL] = data[1]
	arrays[Mesh.ARRAY_INDEX] = data[2]
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var collision := mesh.create_trimesh_shape()
	var collision_faces := collision.get_faces().size() / 3 if collision != null else 0
	# Compare the actual LOD0 and LOD1 collision-mesh boundary at x=78 km.
	track.call("_gen_tile", Vector3i(78, -200, 1))
	var coarse_data: Array = (track.get("chunk_data") as Dictionary)[Vector3i(78, -200, 1)]
	var coarse_arrays: Array = []
	coarse_arrays.resize(Mesh.ARRAY_MAX)
	coarse_arrays[Mesh.ARRAY_VERTEX] = coarse_data[0]
	coarse_arrays[Mesh.ARRAY_INDEX] = coarse_data[2]
	var coarse_mesh := ArrayMesh.new()
	coarse_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, coarse_arrays)
	var coarse_collision := coarse_mesh.create_trimesh_shape()
	var coarse_collision_faces := coarse_collision.get_faces().size() / 3 if coarse_collision != null else 0

	var fine_vertices: PackedVector3Array = data[0]
	var coarse_vertices: PackedVector3Array = coarse_data[0]
	var fine_stride := 33
	var coarse_stride := 17
	var seam_error := 0.0
	for j in range(1, 33, 2):
		var fine_y := fine_vertices[j * fine_stride + 32].y
		var coarse_j := j / 2
		var c0 := coarse_vertices[coarse_j * coarse_stride].y
		var c1 := coarse_vertices[(coarse_j + 1) * coarse_stride].y
		seam_error = maxf(seam_error, absf(fine_y - lerpf(c0, c1, 0.5)))

	track.call("_gen_tile", Vector3i(78, -200, 2))
	var very_coarse_data: Array = (track.get("chunk_data") as Dictionary)[Vector3i(78, -200, 2)]
	var very_coarse_vertices: PackedVector3Array = very_coarse_data[0]
	var lod0_lod2_error := 0.0
	for j in range(1, 32):
		var y := fine_vertices[j * fine_stride + 32].y
		var lower := (j / 8) * 8
		var t := float(j - lower) / 8.0
		var c0 := very_coarse_vertices[(lower / 8) * 5].y
		var c1 := very_coarse_vertices[((lower / 8) + 1) * 5].y
		lod0_lod2_error = maxf(lod0_lod2_error, absf(y - lerpf(c0, c1, t)))


	var report := {
		"godot": Engine.get_version_info().string,
		"seed": SEED,
		"length_km": LENGTH_KM,
		"track_tiles_total": (track.get("track_tiles") as Dictionary).size(),
		"route_paths_checked": lines.size(),
		"route_centerline_samples_250m": route_sample_count,
		"centerline_samples_without_runtime_tile": missing_tiles,
		"needle_grid_step_m": NEEDLE_STEP,
		"needle_grid_sample_count": n * n,
		"needle_height_z_minus_20_after_m": track.call("height", 77000.0, -199460.0),
		"needle_height_z_minus_15_after_m": track.call("height", 77000.0, -199455.0),
		"needle_height_step_after_fix_m": absf(track.call("height", 77000.0, -199460.0) - track.call("height", 77000.0, -199455.0)),
		"needle_max_adjacent_height_delta_m": max_delta,
		"needle_max_delta_at_xz_m": [max_at.x, max_at.y],
		"lod0_collision_faces_at_needle_overlap": collision_faces,
		"lod1_collision_faces_at_seam": coarse_collision_faces,
		"lod0_lod1_boundary_max_vertical_gap_m": seam_error,
		"lod0_lod2_boundary_max_vertical_gap_m": lod0_lod2_error
	}
	print("ROUTE_CONTINUITY_RESULT ", JSON.stringify(report))
	track.free()
	quit(0 if missing_tiles == 0 and max_delta < 1000.0 and collision_faces > 0 and coarse_collision_faces > 0 and seam_error < 0.001 else 1)
