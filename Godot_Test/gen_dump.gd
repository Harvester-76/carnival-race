extends SceneTree
func _init() -> void:
	var f := FileAccess.open("/private/tmp/gen_dump.json", FileAccess.WRITE)
	var all := {}
	for sd in range(1, 13):
		var t0 := Time.get_ticks_msec()
		var km: Array = preload("res://trackgen.gd").generate(sd)
		var arr := []
		for v in km: arr.append([v.x, v.y])
		all[str(sd)] = arr
		print("seed ", sd, " pts ", km.size(), " ms ", Time.get_ticks_msec() - t0)
	f.store_string(JSON.stringify(all)); f.close(); quit()
