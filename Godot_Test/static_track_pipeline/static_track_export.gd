extends SceneTree

const ExportJob := preload("res://static_track_pipeline/static_track_export_job.gd")

var config := {"mode": "fixture", "profile": "diagnostic", "seed": 11, "length_km": 650.0}

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("out=") or arg.begins_with("--out="):
			config["out"] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("source=") or arg.begins_with("--source="):
			config["source"] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("status=") or arg.begins_with("--status="):
			config["progress_path"] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("cancel=") or arg.begins_with("--cancel="):
			config["cancel_path"] = arg.substr(arg.find("=") + 1)
		elif arg.begins_with("mode=") or arg.begins_with("--mode="):
			config["mode"] = arg.get_slice("=", 1)
		elif arg.begins_with("profile=") or arg.begins_with("--profile="):
			config["profile"] = arg.get_slice("=", 1)
		elif arg.begins_with("seed=") or arg.begins_with("--seed="):
			config["seed"] = int(arg.get_slice("=", 1))
		elif arg.begins_with("len=") or arg.begins_with("--len="):
			config["length_km"] = float(arg.get_slice("=", 1))
		elif arg == "estimate" or arg == "--estimate":
			config["estimate"] = true
	call_deferred("_run_export")

func _run_export() -> void:
	print("EXPORT_JOB_START")
	var job := ExportJob.new()
	var result: Dictionary = await job.run(config, self)
	print("EXPORT_JOB_RESULT ", JSON.stringify(result))
	quit(int(result.get("exit_code", 2)))
