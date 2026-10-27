extends SceneTree
func _init() -> void:
	var res := {}
	for sd in [1, 3, 6, 12]:
		var scr = load("res://main.gd").new()
		scr.track_seed = sd
		scr._build_track()
		var mp := []; for p in scr.trk_pts: mp.append([p.x, p.y])
		var bp := []; for p in scr.br_pts: bp.append([p.x, p.y])
		res[str(sd)] = {"main": mp, "br": bp, "in": scr.br_in, "out": scr.br_out}
		scr.free()
	var f := FileAccess.open("/private/tmp/fork_dump.json", FileAccess.WRITE); f.store_string(JSON.stringify(res)); f.close(); quit()
