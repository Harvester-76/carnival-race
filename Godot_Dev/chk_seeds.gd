extends SceneTree
func _init() -> void:
	var bad := []
	for sd in range(1, 41):
		var km: Array = preload("res://trackgen.gd").generate(sd)
		if km.size() < 10: bad.append(sd)
	for sd in [101, 102, 103]:
		if (preload("res://trackgen.gd").generate(sd) as Array).size() < 10: bad.append(sd)
	print("BAD ", bad); quit()
