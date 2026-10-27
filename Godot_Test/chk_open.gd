extends SceneTree
func _init() -> void:
	for sd in [11, 1, 21, 5, 7]:
		var g: Dictionary = preload("res://trackgen.gd").generate_open(sd, 650.0)
		var info := []
		for c in g["cuts"]: info.append([c["type"], snappedf(c["len"], 0.1), snappedf(c["main"], 0.1), (c["pts"] as Array).size()])
		print("OPEN seed ", sd, " pts ", (g["pts"] as Array).size(), " cuts ", info)
	quit()
