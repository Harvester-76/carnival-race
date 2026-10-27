extends SceneTree
func _init() -> void:
	var res := {}
	for sd in [0]:
		var scr = load("res://main.gd").new()
		scr.track_seed = sd
		scr._build_track()
		res[sd] = [snappedf(scr.br_in, 100.0), snappedf(scr.br_out, 100.0), snappedf(scr.trk_len, 100.0), scr.br_pts.size()]
		scr.free()
	print("FORK ", JSON.stringify(res)); quit()
