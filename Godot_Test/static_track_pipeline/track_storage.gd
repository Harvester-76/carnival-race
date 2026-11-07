extends RefCounted
class_name TrackStorage

const ROOT := "user://tracks"
const VALIDATOR := preload("res://static_track_pipeline/static_track_runtime_validator.gd")

func ensure_root() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))

func next_track_id() -> String:
	ensure_root()
	var index := 1
	while DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ROOT.path_join("track_%04d" % index))) or DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(ROOT.path_join("track_%04d.building" % index))) or FileAccess.file_exists(ROOT.path_join(".jobs/track_%04d.json" % index)) or FileAccess.file_exists(ROOT.path_join(".jobs/track_%04d.cancel" % index)):
		index += 1
	return "track_%04d" % index

func track_root(track_id: String) -> String:
	if not _valid_id(track_id): return ""
	return ROOT.path_join(track_id)

func list_tracks() -> Array[Dictionary]:
	ensure_root()
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(ROOT)
	if dir == null: return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and _valid_id(name):
			var root := ROOT.path_join(name)
			var check: Dictionary = VALIDATOR.validate_directory(root)
			if bool(check.get("ok", false)):
				var manifest := _read_manifest(root)
				if str(manifest.get("track_id", name)) == name:
					result.append(_metadata(name, manifest, "Готова"))
		name = dir.get_next()
	dir.list_dir_end()
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.get("created_at", "")) > String(b.get("created_at", "")))
	return result

func get_track(track_id: String, verify_hashes := false) -> Dictionary:
	var root := track_root(track_id)
	if root.is_empty(): return {"ok": false, "error": "Некорректный ID трассы"}
	var validation: Dictionary = VALIDATOR.validate_directory(root, verify_hashes)
	if not bool(validation.get("ok", false)): return {"ok": false, "error": "; ".join(validation.get("errors", []))}
	var manifest := _read_manifest(root)
	if str(manifest.get("track_id", "")) != track_id: return {"ok": false, "error": "ID в manifest не совпадает"}
	return {"ok": true, "root": root, "metadata": _metadata(track_id, manifest, "Готова"), "manifest": manifest}

func register_track(track_id: String) -> Dictionary:
	# Published manifest is the registration record; never create a ready marker
	# outside the atomically published track directory.
	var track := get_track(track_id, false)
	if not bool(track.get("ok", false)): return track
	return {"ok": true, "track": track["metadata"], "root": track["root"]}

func remove_track(track_id: String, active_track_id: String) -> Dictionary:
	if track_id == active_track_id: return {"ok": false, "error": "Трасса используется текущим заездом"}
	var root := track_root(track_id)
	if root.is_empty(): return {"ok": false, "error": "Некорректный ID трассы"}
	var abs_root := ProjectSettings.globalize_path(root).simplify_path()
	var abs_base := ProjectSettings.globalize_path(ROOT).simplify_path()
	if not abs_root.begins_with(abs_base + "/") or abs_root.get_base_dir() != abs_base:
		return {"ok": false, "error": "Путь трассы выходит за каталог user://tracks"}
	var checked := get_track(track_id)
	if not bool(checked.get("ok", false)): return {"ok": false, "error": "Удалять можно только корректную готовую трассу: " + str(checked.get("error", ""))}
	var err := _remove_tree(abs_root)
	return {"ok": err == OK, "error": "Не удалось удалить каталог (%d)" % err if err != OK else ""}

func incomplete_builds() -> Array[Dictionary]:
	ensure_root()
	var result: Array[Dictionary] = []
	var dir := DirAccess.open(ROOT)
	if dir == null: return result
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if dir.current_is_dir() and name.ends_with(".building"):
			var track_id := name.trim_suffix(".building")
			var status_path := ROOT.path_join(".jobs").path_join(track_id + ".json")
			var progress: Variant = _parse_json(FileAccess.get_file_as_string(status_path)) if FileAccess.file_exists(status_path) else {}
			var pid := int(progress.get("worker_pid", -1)) if progress is Dictionary else -1
			var running := pid > 0 and OS.is_process_running(pid)
			result.append({"path": ROOT.path_join(name), "track_id": track_id, "status": "running" if running else "needs_review", "worker_pid": pid})
		name = dir.get_next()
	dir.list_dir_end()
	return result

func has_live_worker() -> bool:
	var jobs := DirAccess.open(ROOT.path_join(".jobs"))
	if jobs == null: return false
	jobs.list_dir_begin(); var name := jobs.get_next()
	while name != "":
		if not jobs.current_is_dir() and name.ends_with(".json"):
			var path := ROOT.path_join(".jobs").path_join(name)
			var value: Variant = _parse_json(FileAccess.get_file_as_string(path))
			if value is Dictionary and int(value.get("worker_pid", -1)) > 0 and OS.is_process_running(int(value["worker_pid"])):
				jobs.list_dir_end(); return true
		name = jobs.get_next()
	jobs.list_dir_end()
	return false

func remove_abandoned_build(track_id: String) -> Dictionary:
	if not _valid_id(track_id): return {"ok": false, "error": "Некорректный ID сборки"}
	var status_path := ROOT.path_join(".jobs").path_join(track_id + ".json")
	if not FileAccess.file_exists(status_path): return {"ok": false, "error": "Не найден статус worker; безопасность удаления не подтверждена"}
	var progress: Variant = _parse_json(FileAccess.get_file_as_string(status_path))
	if not progress is Dictionary or int(progress.get("worker_pid", -1)) <= 0:
		return {"ok": false, "error": "В статусе нет проверяемого PID worker"}
	if OS.is_process_running(int(progress["worker_pid"])): return {"ok": false, "error": "Worker ещё выполняется"}
	var root_abs := ProjectSettings.globalize_path(ROOT).simplify_path()
	var target := ProjectSettings.globalize_path(ROOT.path_join(track_id + ".building")).simplify_path()
	if target.get_base_dir() != root_abs or not target.begins_with(root_abs + "/"):
		return {"ok": false, "error": "Путь staging выходит за user://tracks"}
	if not DirAccess.dir_exists_absolute(target): return {"ok": false, "error": "Staging-каталог уже отсутствует"}
	var err := _remove_tree(target)
	if err != OK: return {"ok": false, "error": "Не удалось удалить staging (%d)" % err}
	var status_abs := ProjectSettings.globalize_path(status_path)
	var cancel_abs := ProjectSettings.globalize_path(ROOT.path_join(".jobs").path_join(track_id + ".cancel"))
	if FileAccess.file_exists(status_abs): DirAccess.remove_absolute(status_abs)
	if FileAccess.file_exists(cancel_abs): DirAccess.remove_absolute(cancel_abs)
	return {"ok": true}

func _read_manifest(root: String) -> Dictionary:
	var path := root.path_join("track.json")
	if not FileAccess.file_exists(path): return {}
	var parsed = _parse_json(FileAccess.get_file_as_string(path))
	return parsed if parsed is Dictionary else {}

func _parse_json(text: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(text) != OK: return null
	return parser.data

func _metadata(track_id: String, m: Dictionary, state: String) -> Dictionary:
	var generation: Variant = m.get("generation_parameters", {})
	if not generation is Dictionary: generation = {}
	return {"track_id": track_id, "name": str(m.get("name", track_id)), "seed": int(m.get("seed", generation.get("seed", 0))), "requested_length_km": float(m.get("requested_length_km", generation.get("length_km", 0.0))), "actual_length_km": float(m.get("actual_length_km", 0.0)), "created_at": str(m.get("created_at", "")), "status": state, "root": track_root(track_id)}

func _valid_id(value: String) -> bool:
	return value.is_valid_identifier() and value.begins_with("track_") and value.length() <= 32

func _remove_tree(abs_path: String) -> Error:
	var dir := DirAccess.open(abs_path)
	if dir == null: return DirAccess.get_open_error()
	for file in dir.get_files():
		var err := DirAccess.remove_absolute(abs_path.path_join(file))
		if err != OK: return err
	for child in dir.get_directories():
		var err := _remove_tree(abs_path.path_join(child))
		if err != OK: return err
	return DirAccess.remove_absolute(abs_path)
