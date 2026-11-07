extends RefCounted
class_name StaticTrackRuntimeValidator

const CHUNK_NAME := "^x([+-]\\d+)_z([+-]\\d+)\\.ply$"

static func validate_directory(root: String, verify_hashes := false, require_production := true) -> Dictionary:
	var root_abs := ProjectSettings.globalize_path(root)
	var manifest_path := ""
	for candidate in ["track.json", "fixture.json"]:
		var candidate_path := root.path_join(candidate)
		if FileAccess.file_exists(candidate_path):
			manifest_path = candidate_path
			break
	if manifest_path.is_empty(): return _error("missing track.json or fixture.json")
	var manifest_value = _parse_json(FileAccess.get_file_as_string(manifest_path))
	if not manifest_value is Dictionary: return _error("invalid manifest JSON")
	var manifest: Dictionary = manifest_value
	if require_production:
		if manifest.get("format", "") != "static-track-userdata-v1" or manifest.get("profile", "") != "production":
			return _error("manifest is not a production static-track-userdata-v1 package")
		if str(manifest.get("track_id", "")).is_empty() or str(manifest.get("name", "")).strip_edges().is_empty():
			return _error("manifest is missing track_id or name")
	var collision_value: Variant = manifest.get("collision_variants", {})
	var presentation_value: Variant = manifest.get("presentation", {})
	if not collision_value is Dictionary or not presentation_value is Dictionary: return _error("invalid collision or presentation metadata")
	var collision: Dictionary = collision_value
	var presentation: Dictionary = presentation_value
	if not collision.has("2000") or not presentation.has("base"):
		return _error("manifest must include collision/chunk_2000 and presentation/base")
	var checked_files := 0
	for set_spec in [
		{"path": "collision/chunk_2000", "metrics": collision["2000"]},
		{"path": "presentation/base", "metrics": presentation["base"]}
	]:
		var set_result := _validate_set(root, root_abs, str(set_spec["path"]), set_spec["metrics"])
		if not bool(set_result.get("ok", false)): return set_result
		checked_files += int(set_result.get("checked_files", 0))
	if verify_hashes:
		var hash_result := _validate_hashes(root)
		if not bool(hash_result.get("ok", false)): return hash_result
	return {"ok": true, "checked_files": checked_files, "manifest": manifest_path}

static func _validate_hashes(root: String) -> Dictionary:
	var path := root.path_join("artifact-hashes.json")
	if not FileAccess.file_exists(path): return _error("missing artifact-hashes.json")
	var parsed = _parse_json(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary or not parsed.get("files", []) is Array: return _error("invalid artifact-hashes.json")
	var entries: Dictionary = {}
	for item in parsed["files"]:
		if item is Dictionary: entries[str(item.get("path", ""))] = item
	if not entries.has("track.json"): return _error("checksum entry missing for track.json")
	var manifest_hash := _sha256(root.path_join("track.json"))
	if manifest_hash.is_empty() or manifest_hash != str(entries["track.json"].get("sha256", "")): return _error("checksum mismatch for track.json")
	for set_path in ["collision/chunk_2000", "presentation/base"]:
		var dir := DirAccess.open(root.path_join(set_path))
		if dir == null: return _error("missing " + set_path)
		dir.list_dir_begin(); var name := dir.get_next()
		while name != "":
			if not dir.current_is_dir() and name.ends_with(".ply"):
				var rel: String = String(set_path).path_join(name)
				if not entries.has(rel): dir.list_dir_end(); return _error("checksum entry missing for " + rel)
				var entry: Dictionary = entries[rel]
				var artifact := FileAccess.open(root.path_join(rel), FileAccess.READ)
				if artifact == null: dir.list_dir_end(); return _error("cannot open " + rel)
				var actual_size := artifact.get_length(); artifact.close()
				if actual_size != int(entry.get("byte_size", -1)): dir.list_dir_end(); return _error("size mismatch for " + rel)
				if _sha256(root.path_join(rel)) != str(entry.get("sha256", "")): dir.list_dir_end(); return _error("checksum mismatch for " + rel)
			name = dir.get_next()
		dir.list_dir_end()
	return {"ok": true}

static func _sha256(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return ""
	var ctx := HashingContext.new(); ctx.start(HashingContext.HASH_SHA256)
	while not file.eof_reached(): ctx.update(file.get_buffer(1024 * 1024))
	file.close()
	return ctx.finish().hex_encode()

static func _parse_json(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK: return null
	return parser.data

static func _validate_set(root: String, root_abs: String, relative_dir: String, metrics: Variant) -> Dictionary:
	if not metrics is Dictionary: return _error("invalid metrics for " + relative_dir)
	var expected := int(metrics.get("chunk_count", 0))
	if expected <= 0: return _error("empty chunk set " + relative_dir)
	var path := root.path_join(relative_dir)
	var dir := DirAccess.open(path)
	if dir == null: return _error("missing chunk directory " + relative_dir)
	var rx := RegEx.new()
	rx.compile(CHUNK_NAME)
	var names: Array[String] = []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not dir.current_is_dir() and rx.search(name) != null: names.append(name)
		name = dir.get_next()
	dir.list_dir_end()
	if names.size() != expected:
		return _error("chunk count mismatch %s: expected %d, found %d" % [relative_dir, expected, names.size()])
	for chunk_name in names:
		var check := _validate_ply(root_abs.path_join(relative_dir).path_join(chunk_name))
		if not bool(check.get("ok", false)): return _error(relative_dir.path_join(chunk_name) + ": " + str(check.get("error", "invalid PLY")))
	return {"ok": true, "checked_files": names.size()}

static func _validate_ply(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return {"ok": false, "error": "cannot open file"}
	if file.get_line() != "ply": file.close(); return {"ok": false, "error": "missing PLY signature"}
	var format_line := file.get_line()
	if format_line != "format binary_little_endian 1.0": file.close(); return {"ok": false, "error": "unexpected PLY format"}
	var vertices := -1
	var faces := -1
	var header_done := false
	while not file.eof_reached():
		var line := file.get_line()
		if line.begins_with("element vertex "): vertices = int(line.get_slice(" ", 2))
		elif line.begins_with("element face "): faces = int(line.get_slice(" ", 2))
		elif line == "end_header": header_done = true; break
	var payload_start := file.get_position()
	var file_length := file.get_length()
	file.close()
	if not header_done or vertices <= 0 or faces <= 0: return {"ok": false, "error": "incomplete PLY header"}
	var expected_length := payload_start + vertices * 24 + faces * 13
	if file_length != expected_length:
		return {"ok": false, "error": "payload length mismatch: expected %d, found %d" % [expected_length, file_length]}
	return {"ok": true, "vertices": vertices, "faces": faces}

static func _error(message: String) -> Dictionary:
	return {"ok": false, "errors": [message]}
