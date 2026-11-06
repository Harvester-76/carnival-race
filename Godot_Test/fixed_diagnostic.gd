# Needle heightfield discontinuity diagnostic functions (FIXED VERSION)
const DEBUG_CENTER_X := 77000.0
const DEBUG_CENTER_Z := -199475.0
const DEBUG_AREA_SIZE := 500.0  # 500x500 m square
const DEBUG_GRID_STEP := 5.0    # 5 m step

func _dump_needle_discontinuity_diagnostic() -> void:
	# Main diagnostic area: 500x500 m around the suspected discontinuity
	var x_min := DEBUG_CENTER_X - DEBUG_AREA_SIZE/2.0
	var x_max := DEBUG_CENTER_X + DEBUG_AREA_SIZE/2.0
	var z_min := DEBUG_CENTER_Z - DEBUG_AREA_SIZE/2.0
	var z_max := DEBUG_CENTER_Z + DEBUG_AREA_SIZE/2.0

	var csv_path := "user://needle_discontinuity_diagnostic.csv"
	var profile_path := "user://needle_discontinuity_profile.csv"
	var json_path := "user://needle_discontinuity_meta.json"

	# Main diagnostic CSV
	var f := FileAccess.open(csv_path, FileAccess.WRITE)
	if f == null:
		push_error("DISCONTINUITY_DUMP: cannot open CSV: " + csv_path)
		return

	# Profile CSV (X = 77000, Z = -199750 to -199200)
	var pf := FileAccess.open(profile_path, FileAccess.WRITE)
	if pf == null:
		push_error("DISCONTINUITY_DUMP: cannot open profile CSV: " + profile_path)
		f.close()
		return

	# CSV headers
	var header := "x_m,z_m,height_m,q3_distance,q3_s,q3_path_id,distance_to_main,distance_to_spur,h_main,h_spur,seg_grid_x,seg_grid_s,seg_grid_path,spur_grid_x,spur_grid_s,spur_grid_path,dx,dz,is_near_infl,is_path_switch,is_spur_available,is_missing_result"
	f.store_line(header)
	pf.store_line(header)

	var count := 0
	var profile_count := 0
	var h_min := INF
	var h_max := -INF
	var max_jump_x := 0.0
	var max_jump_z := 0.0
	var jump_location_x := 0.0
	var jump_location_z := 0.0
	var path_switches := 0
	var missing_results := 0

	# Store previous values for comparison
	var prev_path_id := -1

	# Main grid sampling
	for z in range(int(z_min), int(z_max) + 1, int(DEBUG_GRID_STEP)):
		for x in range(int(x_min), int(x_max) + 1, int(DEBUG_GRID_STEP)):
			var h := height(float(x), float(z))

			# Get diagnostic information
			var q3_main := _tq3_cls(float(x), float(z), seg_grid)
			var q3_spur := _tq3_cls(float(x), float(z), spur_grid) if not spur_grid.is_empty() else Vector3(1e9, 0.0, 0.0)

			# Get height components
			var h_main := _h_at(float(x), float(z), q3_main)
			var h_spur := _h_at(float(x), float(z), q3_spur) if not spur_grid.is_empty() else 0.0

			# Calculate gradients
			var hx := height(float(x) + DEBUG_GRID_STEP, float(z))
			var hz := height(float(x), float(z) + DEBUG_GRID_STEP)
			var dx := (hx - h) / DEBUG_GRID_STEP
			var dz := (hz - h) / DEBUG_GRID_STEP

			# Classification flags
			var is_near_infl := q3_main.x >= INFL * 0.8
			var is_path_switch := (prev_path_id != int(q3_main.z)) and (prev_path_id != -1)
			var is_spur_available := not spur_grid.is_empty() and q3_spur.x < INFL
			var is_missing_result := false
			if h != h or h == INF or h == -INF:  # Check for NaN or infinity
				is_missing_result = true

			# Track statistics
			h_min = minf(h_min, h)
			h_max = maxf(h_max, h)
			if is_path_switch: path_switches += 1
			if is_missing_result: missing_results += 1

			# Check for jumps
			if absf(hx - h) > max_jump_x:
				max_jump_x = absf(hx - h)
				jump_location_x = float(x)
			if absf(hz - h) > max_jump_z:
				max_jump_z = absf(hz - h)
				jump_location_z = float(z)

			# Prepare CSV line
			var line := "%.1f,%.1f,%.6f,%.6f,%.6f,%.0f,%.6f,%.6f,%.6f,%.6f,%.6f,%.6f,%.0f,%.6f,%.6f,%.0f,%.6f,%.6f,%s,%s,%s,%s" % [
				float(x), float(z), h,
				q3_main.x, q3_main.y, q3_main.z,
				q3_main.x, q3_spur.x,
				h_main, h_spur,
				q3_main.x, q3_main.y, q3_main.z,
				q3_spur.x, q3_spur.y, q3_spur.z,
				dx, dz,
				str(is_near_infl).to_lower(), str(is_path_switch).to_lower(), str(is_spur_available).to_lower(), str(is_missing_result).to_lower()
			]

			f.store_line(line)
			count += 1

			# Save current values for next iteration
			prev_path_id = int(q3_main.z)

			# Special profile line for X = 77000
			if absf(float(x) - DEBUG_CENTER_X) < DEBUG_GRID_STEP/2.0:
				if float(z) >= -199750.0 and float(z) <= -199200.0:
					pf.store_line(line)
					profile_count += 1

	f.flush()
	f.close()
	pf.flush()
	pf.close()

	# Create metadata
	var meta := {
		"diagnostic": "needle_discontinuity",
		"track_seed": track_seed,
		"gen_len_km": gen_len_km,
		"godot_version": Engine.get_version_info(),
		"center_x": DEBUG_CENTER_X,
		"center_z": DEBUG_CENTER_Z,
		"area_size": DEBUG_AREA_SIZE,
		"grid_step": DEBUG_GRID_STEP,
		"sample_count": count,
		"profile_sample_count": profile_count,
		"height_min_m": h_min,
		"height_max_m": h_max,
		"max_jump_x": max_jump_x,
		"max_jump_z": max_jump_z,
		"jump_location_x": jump_location_x,
		"jump_location_z": jump_location_z,
		"path_switches": path_switches,
		"missing_results": missing_results,
		"csv_path": ProjectSettings.globalize_path(csv_path),
		"profile_path": ProjectSettings.globalize_path(profile_path)
	}

	var jf := FileAccess.open(json_path, FileAccess.WRITE)
	if jf != null:
		jf.store_string(JSON.stringify(meta, "\t"))
		jf.flush()
		jf.close()

	print("NEEDLE_DISCONTINUITY_DUMP_BEGIN")
	print(JSON.stringify(meta))
	print("CSV: ", ProjectSettings.globalize_path(csv_path))
	print("PROFILE: ", ProjectSettings.globalize_path(profile_path))
	print("META: ", ProjectSettings.globalize_path(json_path))
	print("NEEDLE_DISCONTINUITY_DUMP_END")