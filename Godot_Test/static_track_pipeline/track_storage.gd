extends RefCounted
class_name TrackStorage

const ROOT := "user://tracks"
const STATIC_TRACK_ID := "track_seed11_650km"
const STATIC_TRACK_ROOT := "user://tracks/track_seed11_650km"
const EXPORT_JOB := preload("res://static_track_pipeline/static_track_export_job.gd")
const VALIDATOR := preload("res://static_track_pipeline/static_track_runtime_validator.gd")

func ensure_root() -> Error:
	return DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))

func track_root(track_id := STATIC_TRACK_ID) -> String:
	return STATIC_TRACK_ROOT if track_id == STATIC_TRACK_ID else ""

func installed_track(verify_hashes := false) -> Dictionary:
	var root := track_root()
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(root)):
		return {"ok": false, "error": "Static-трасса ещё не установлена"}
	var validation: Dictionary = VALIDATOR.validate_directory(root, verify_hashes, true)
	if not bool(validation.get("ok", false)):
		return {"ok": false, "error": "; ".join(validation.get("errors", []))}
	var manifest := _read_manifest(root)
	if str(manifest.get("track_id", "")) != STATIC_TRACK_ID or int(manifest.get("seed", -1)) != 11 or not is_equal_approx(float(manifest.get("requested_length_km", 0.0)), 650.0):
		return {"ok": false, "error": "Установленный пакет не соответствует Static seed 11 / 650 км"}
	var source: Dictionary = manifest.get("source", {})
	var route_ids: Variant = manifest.get("route_ids", [])
	if str(source.get("export_mode", "")) != "full" or int(manifest.get("route_count", 0)) != 4 or not route_ids is Array or route_ids.size() != 4:
		return {"ok": false, "error": "Установленный пакет не содержит все четыре маршрута полного экспорта"}
	return {"ok": true, "root": root, "manifest": manifest}

func install_static_track(progress_path: String, cancel_path: String, scheduler: Object) -> Dictionary:
	if bool(installed_track().get("ok", false)):
		return {"ok": false, "status": "failed", "error": "Static-трасса уже установлена и прошла проверку."}
	var config := {
		"out": STATIC_TRACK_ROOT,
		"mode": "full",
		"profile": "production",
		"seed": 11,
		"length_km": 650.0,
		"track_id": STATIC_TRACK_ID,
		"name": "Static — Seed 11, 650 км",
		"progress_path": progress_path,
		"cancel_path": cancel_path
	}
	var job = EXPORT_JOB.new()
	var result: Dictionary = await job.run(config, scheduler)
	if str(result.get("status", "")) == "ready":
		return {"ok": true, "status": "ready", "root": STATIC_TRACK_ROOT, "validation": result.get("validation", {})}
	return {"ok": false, "status": str(result.get("status", "failed")), "error": str(result.get("error", result.get("message", "Экспорт Static-трассы не завершён")))}

func _read_manifest(root: String) -> Dictionary:
	var path := root.path_join("track.json")
	if not FileAccess.file_exists(path): return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary: return {}
	return parser.data
