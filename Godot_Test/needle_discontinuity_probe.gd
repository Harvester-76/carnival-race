extends SceneTree

# Standalone diagnostic for the needle-branch height discontinuity.
# Does not modify main.gd or the generated track.
# Run from Godot_Test:
#   godot --headless --path . --script res://tools/needle_discontinuity_probe.gd

const MAIN_SCRIPT := preload("res://main.gd")
const TRACK_SEED := 11
const GEN_LEN_KM := 650.0

const CENTER_X := 77000.0
const CENTER_Z := -199475.0
const HALF_SIZE := 250.0
const GRID_STEP := 5.0

const PROFILE_X := 77000.0
const PROFILE_Z0 := -199750.0
const PROFILE_Z1 := -199200.0
const PROFILE_STEP := 5.0

const OUT_GRID := "user://needle_discontinuity_diagnostic.csv"
const OUT_PROFILE := "user://needle_discontinuity_profile.csv"
const OUT_META := "user://needle_discontinuity_meta.json"

var probe: Node3D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	print("NEEDLE_PROBE: initializing track")
	probe = MAIN_SCRIPT.new() as Node3D
	if probe == null:
		_fail("Could not instantiate main.gd")
		return

	probe.set("track_seed", TRACK_SEED)
	probe.set("gen_len_km", GEN_LEN_KM)

	# _build_track() also creates branches, spurs and both spatial grids.
	probe.call("_build_track")

	if probe.get("seg_grid").is_empty():
		_fail("seg_grid is empty after _build_track()")
		return

	var grid_file := FileAccess.open(OUT_GRID, FileAccess.WRITE)
	var profile_file := FileAccess.open(OUT_PROFILE, FileAccess.WRITE)
	if grid_file == null or profile_file == null:
		_fail("Could not open output CSV files")
		return

	var header := "x_m,z_m,height_m,seg_distance_m,seg_s_m,seg_path_id,seg_index,spur_distance_m,spur_s_m,spur_path_id,spur_index,spur_applied,main_height_m,spur_height_m,final_height_m,delta_x_m,delta_z_m,path_changed,segment_changed"
	grid_file.store_line(header)
	profile_file.store_line(header)

	var stats := {
		"sample_count": 0,
		"height_min_m": INF,
		"height_max_m": -INF,
		"max_abs_delta_x_m": 0.0,
		"max_abs_delta_z_m": 0.0,
		"max_delta_x_at": [],
		"max_delta_z_at": [],
		"path_switches_x": 0,
		"path_switches_z": 0,
		"segment_switches_x": 0,
		"segment_switches_z": 0,
		"missing_seg_grid_samples": 0,
		"missing_spur_grid_samples": 0,
		"spur_applied_samples": 0
	}

	var x0 := CENTER_X - HALF_SIZE
	var x1 := CENTER_X + HALF_SIZE
	var z0 := CENTER_Z - HALF_SIZE
	var z1 := CENTER_Z + HALF_SIZE

	# Cache each row so finite differences and transition flags are exact
	# for the exported 5 m lattice.
	var rows: Array = []
	for zi in range(int(z0), int(z1) + 1, int(GRID_STEP)):
		var row: Array = []
		for xi in range(int(x0), int(x1) + 1, int(GRID_STEP)):
			row.append(_sample(float(xi), float(zi)))
		rows.append(row)

	for rz in range(rows.size()):
		for rx in range(rows[rz].size()):
			var s: Dictionary = rows[rz][rx]
			var dx := 0.0
			var dz := 0.0
			if rx + 1 < rows[rz].size():
				dx = float(rows[rz][rx + 1]["height"]) - float(s["height"])
				if absf(dx) > float(stats["max_abs_delta_x_m"]):
					stats["max_abs_delta_x_m"] = absf(dx)
					stats["max_delta_x_at"] = [s["x"], s["z"]]
				if int(rows[rz][rx + 1]["seg"]["path"]) != int(s["seg"]["path"]):
					stats["path_switches_x"] += 1
				if int(rows[rz][rx + 1]["seg"]["index"]) != int(s["seg"]["index"]):
					stats["segment_switches_x"] += 1
			if rz + 1 < rows.size():
				dz = float(rows[rz + 1][rx]["height"]) - float(s["height"])
				if absf(dz) > float(stats["max_abs_delta_z_m"]):
					stats["max_abs_delta_z_m"] = absf(dz)
					stats["max_delta_z_at"] = [s["x"], s["z"]]
				if int(rows[rz + 1][rx]["seg"]["path"]) != int(s["seg"]["path"]):
					stats["path_switches_z"] += 1
				if int(rows[rz + 1][rx]["seg"]["index"]) != int(s["seg"]["index"]):
					stats["segment_switches_z"] += 1

			stats["sample_count"] += 1
			stats["height_min_m"] = minf(float(stats["height_min_m"]), float(s["height"]))
			stats["height_max_m"] = maxf(float(stats["height_max_m"]), float(s["height"]))
			if float(s["seg"]["distance"]) >= 1e8:
				stats["missing_seg_grid_samples"] += 1
			if float(s["spur"]["distance"]) >= 1e8:
				stats["missing_spur_grid_samples"] += 1
			if bool(s["spur_applied"]):
				stats["spur_applied_samples"] += 1

			var line := _csv_line(s, dx, dz, rx + 1 < rows[rz].size() and int(rows[rz][rx + 1]["seg"]["path"]) != int(s["seg"]["path"]), rx + 1 < rows[rz].size() and int(rows[rz][rx + 1]["seg"]["index"]) != int(s["seg"]["index"]))
			grid_file.store_line(line)

	# Dedicated vertical profile, including the same internal query details.
	var pz := PROFILE_Z0
	var prev: Dictionary = {}
	while pz <= PROFILE_Z1 + 0.001:
		var s2 := _sample(PROFILE_X, pz)
		var dz2 := float(s2["height"]) - float(prev["height"]) if not prev.is_empty() else 0.0
		var path_changed := not prev.is_empty() and int(s2["seg"]["path"]) != int(prev["seg"]["path"])
		var segment_changed := not prev.is_empty() and int(s2["seg"]["index"]) != int(prev["seg"]["index"])
		profile_file.store_line(_csv_line(s2, 0.0, dz2, path_changed, segment_changed))
		prev = s2
		pz += PROFILE_STEP

	grid_file.flush()
	grid_file.close()
	profile_file.flush()
	profile_file.close()

	var meta := {
		"diagnostic": "needle_discontinuity_probe",
		"track_seed": TRACK_SEED,
		"gen_len_km": GEN_LEN_KM,
		"godot_version": Engine.get_version_info(),
		"center_xz_m": [CENTER_X, CENTER_Z],
		"grid_bounds_xz_m": [x0, z0, x1, z1],
		"grid_step_m": GRID_STEP,
		"profile_x_m": PROFILE_X,
		"profile_z_bounds_m": [PROFILE_Z0, PROFILE_Z1],
		"profile_step_m": PROFILE_STEP,
		"stats": stats,
		"grid_csv": ProjectSettings.globalize_path(OUT_GRID),
		"profile_csv": ProjectSettings.globalize_path(OUT_PROFILE)
	}
	var mf := FileAccess.open(OUT_META, FileAccess.WRITE)
	if mf != null:
		mf.store_string(JSON.stringify(meta, "\t"))
		mf.flush()
		mf.close()

	print("NEEDLE_PROBE_META_BEGIN")
	print(JSON.stringify(meta))
	print("NEEDLE_PROBE_META_END")
	print("GRID: ", ProjectSettings.globalize_path(OUT_GRID))
	print("PROFILE: ", ProjectSettings.globalize_path(OUT_PROFILE))
	print("META: ", ProjectSettings.globalize_path(OUT_META))

	probe.free()
	quit(0)

func _sample(x: float, z: float) -> Dictionary:
	var seg: Dictionary = _query_with_index(x, z, probe.get("seg_grid"))
	var spur: Dictionary = _query_with_index(x, z, probe.get("spur_grid"))

	var main_h: float = probe.call("_h_at", x, z, seg["q"])
	var spur_applied := not (probe.get("spur_grid") as Dictionary).is_empty() and float(spur["q"].x) < float(probe.get("INFL"))
	var spur_h := main_h
	var final_h := main_h
	if spur_applied:
		spur_h = float(probe.call("_h_at", x, z, spur["q"]))
		final_h = minf(main_h, spur_h)

	return {
		"x": x, "z": z,
		"seg": seg, "spur": spur,
		"spur_applied": spur_applied,
		"main_height": main_h,
		"spur_height": spur_h,
		"height": final_h
	}

# Diagnostic mirror of _tq3_cls(): same candidate iteration and math,
# with the winning segment array index exposed. It does not mutate the grid.
func _query_with_index(x: float, z: float, grid: Dictionary) -> Dictionary:
	var key := Vector2i(int(floor(x / float(probe.get("GCELL")))), int(floor(z / float(probe.get("GCELL")))))
	if not grid.has(key):
		return {"q": Vector3(1e9, 0.0, 0.0), "index": -1, "distance": 1e9, "s": 0.0, "path": 0}
	var seg_a: PackedVector2Array = probe.get("seg_a")
	var seg_b: PackedVector2Array = probe.get("seg_b")
	var seg_sa: PackedFloat32Array = probe.get("seg_sa")
	var seg_sb: PackedFloat32Array = probe.get("seg_sb")
	var seg_path: PackedInt32Array = probe.get("seg_path")
	var best := 1e18
	var best_s := 0.0
	var best_path := 0
	var best_index := -1
	var pt := Vector2(x, z)
	for i in (grid[key] as PackedInt32Array):
		var a: Vector2 = seg_a[i]
		var ab: Vector2 = seg_b[i] - a
		var l2 := ab.length_squared()
		var t := clampf((pt - a).dot(ab) / l2, 0.0, 1.0) if l2 > 0.0 else 0.0
		var d2 := pt.distance_squared_to(a + ab * t)
		if d2 < best:
			best = d2
			best_s = lerpf(seg_sa[i], seg_sb[i], t)
			best_path = seg_path[i]
			best_index = i
	var distance := sqrt(best)
	var q := Vector3(distance, best_s, float(best_path))
	return {"q": q, "index": best_index, "distance": distance, "s": best_s, "path": best_path}

func _csv_line(s: Dictionary, dx: float, dz: float, path_changed: bool, segment_changed: bool) -> String:
	var a: Dictionary = s["seg"]
	var b: Dictionary = s["spur"]
	return ",".join([
		"%.3f" % s["x"], "%.3f" % s["z"], "%.6f" % s["height"],
		"%.6f" % a["distance"], "%.6f" % a["s"], str(a["path"]), str(a["index"]),
		"%.6f" % b["distance"], "%.6f" % b["s"], str(b["path"]), str(b["index"]),
		"1" if s["spur_applied"] else "0",
		"%.6f" % s["main_height"], "%.6f" % s["spur_height"], "%.6f" % s["height"],
		"%.6f" % dx, "%.6f" % dz,
		"1" if path_changed else "0", "1" if segment_changed else "0"
	])

func _fail(message: String) -> void:
	push_error("NEEDLE_PROBE: " + message)
	printerr("NEEDLE_PROBE_FAILED: " + message)
	quit(1)
