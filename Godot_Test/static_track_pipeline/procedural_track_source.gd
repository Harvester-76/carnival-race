extends "res://static_track_pipeline/geometry_source_contract.gd"

const MainScript := preload("res://main.gd")
var _terrain
var _cut_index := 1
var _seed := 11
var _length_km := 650.0
var _mode := "fixture"

func build(profile: Dictionary) -> void:
	_seed = int(profile.get("seed", 11))
	_length_km = float(profile.get("length_km", 650.0))
	_cut_index = int(profile.get("cut_index", 1))
	_mode = str(profile.get("mode", "fixture"))
	_terrain = MainScript.new()
	_terrain.track_seed = _seed
	_terrain.gen_len_km = _length_km
	_terrain._build_track()
	if _mode == "fixture" and (_cut_index < 0 or _cut_index >= _terrain.branches.size()):
		push_error("Requested cut_index does not exist")

func selected_routes(main_extension_m: float) -> Dictionary:
	if _mode == "full":
		return _all_game_routes()
	if _terrain == null or _cut_index >= _terrain.branches.size(): return {"routes": [], "polylines": []}
	var branch: Dictionary = _terrain.branches[_cut_index]
	var cut_points: PackedVector2Array = branch["pts"]
	var s_in := float(branch["in"])
	var s_out := float(branch["out"])
	var before := PackedVector2Array()
	var after := PackedVector2Array()
	var before_start := maxf(0.0, s_in - main_extension_m)
	var after_end := minf(_terrain.trk_len, s_out + main_extension_m)
	for i in range(25):
		var s := before_start + (s_in - before_start) * float(i) / 24.0
		before.append(_terrain._track_at(s)[0])
	for i in range(25):
		var s := s_out + (after_end - s_out) * float(i) / 24.0
		after.append(_terrain._track_at(s)[0])
	var polylines: Array = [before, cut_points, after]
	var routes := [
		{"id": "main-before-join", "path": "main", "s_min_m": before_start, "s_max_m": s_in, "route_length_m": _polyline_length(before), "points_xz_m": _points_json(before)},
		{"id": "cut-%d-%s" % [_cut_index, str(branch["type"])], "path": "cut", "path_index": _cut_index, "type": str(branch["type"]), "s_min_m": s_in, "s_max_m": s_out, "route_length_m": _polyline_length(cut_points), "points_xz_m": _points_json(cut_points)},
		{"id": "main-after-join", "path": "main", "s_min_m": s_out, "s_max_m": after_end, "route_length_m": _polyline_length(after), "points_xz_m": _points_json(after)}
	]
	return {"routes": routes, "polylines": polylines}

func _all_game_routes() -> Dictionary:
	if _terrain == null: return {"routes": [], "polylines": [], "join_pairs": []}
	var routes: Array = []
	var polylines: Array = []
	var joins: Array = []
	var main_points: PackedVector2Array = _terrain.trk_pts
	polylines.append(main_points)
	routes.append({"id": "main", "path": "main", "s_min_m": 0.0, "s_max_m": _terrain.trk_len, "route_length_m": _polyline_length(main_points), "points_xz_m": _points_json(main_points)})
	for bi in _terrain.branches.size():
		var branch: Dictionary = _terrain.branches[bi]
		var points: PackedVector2Array = branch["pts"]
		var route_id := "branch-%d-%s" % [bi, str(branch.get("type", "unknown"))]
		polylines.append(points)
		routes.append({"id": route_id, "path": "branch", "path_index": bi, "type": str(branch.get("type", "unknown")), "s_min_m": float(branch["in"]), "s_max_m": float(branch["out"]), "route_length_m": _polyline_length(points), "points_xz_m": _points_json(points)})
		var main_start: Vector2 = _terrain._track_at(float(branch["in"]))[0]
		var main_end: Vector2 = _terrain._track_at(float(branch["out"]))[0]
		joins.append({"route_id": route_id, "branch_start_xz_m": [points[0].x, points[0].y], "branch_end_xz_m": [points[-1].x, points[-1].y], "main_start_xz_m": [main_start.x, main_start.y], "main_end_xz_m": [main_end.x, main_end.y], "main_s_start_m": float(branch["in"]), "main_s_end_m": float(branch["out"])})
	return {"routes": routes, "polylines": polylines, "join_pairs": joins}

func terrain_context_paths() -> Array:
	var result: Array = []
	if _terrain == null: return result
	for si in _terrain.spurs.size():
		var spur: Dictionary = _terrain.spurs[si]
		var points: PackedVector2Array = spur["pts"]
		result.append({"id": "spur-%d" % (1000 + si), "role": "terrain-context-only", "parent_path_index": int(spur["parent"]), "length_m": float(spur["len"]), "points_xz_m": _points_json(points)})
	return result

func sample_height(x: float, z: float) -> float:
	return _terrain.height(x, z) if _terrain != null else 0.0

func source_metadata() -> Dictionary:
	var branch: Dictionary = _terrain.branches[_cut_index] if _terrain != null and _cut_index < _terrain.branches.size() else {}
	return {"generator": "trackgen.gd.generate_open", "seed": _seed, "length_km": _length_km, "mode": _mode, "cut_index": _cut_index if _mode == "fixture" else null, "cut_type": str(branch.get("type", "unknown")) if _mode == "fixture" else "all", "control_indices": [338, 451] if _mode == "fixture" and _cut_index == 1 else [], "height_source": "main.gd height(x,z)"}

func generation_parameters() -> Dictionary:
	if _terrain == null: return {}
	return {"terrain_influence_m": _terrain.INFL, "width_scale": _terrain.WIDTH_SCALE, "plateau_y_m": _terrain.PLATEAU_Y}

func close() -> void:
	if _terrain != null:
		_terrain.free()
		_terrain = null

func _points_json(points: PackedVector2Array) -> Array:
	var result: Array = []
	for point in points: result.append([point.x, point.y])
	return result

func _polyline_length(points: PackedVector2Array) -> float:
	var length := 0.0
	for i in range(points.size() - 1): length += points[i].distance_to(points[i + 1])
	return length
