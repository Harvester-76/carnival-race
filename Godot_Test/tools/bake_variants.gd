extends SceneTree
# Запекание вариаций корпусов в готовые сцены: godot --headless --path . --script res://tools/bake_variants.gd
# Разрезание сетки корпуса (ShipVariant) занимает секунды в GDScript, поэтому оно выполняется один раз здесь, а игра загружает res://ship/variants/<ключ>.scn.
# Описания вариаций берутся из main.gd (BOT_VARIANTS, FREYA_VARIANT); в запечённую сцену записан их JSON, и при расхождении игра строит корпус заново сама.
func _init() -> void:
	var cm: Dictionary = (load("res://main.gd") as GDScript).get_script_constant_map()
	var jobs := {}
	for k in cm["BOT_VARIANTS"]: jobs["bot%d" % int(k)] = (cm["BOT_VARIANTS"] as Dictionary)[k]
	for k in cm["SHIP_VARIANTS"]: jobs["ship%d" % int(k)] = (cm["SHIP_VARIANTS"] as Dictionary)[k]
	var ps: PackedScene = load("res://ship/ship.glb")
	DirAccess.make_dir_recursive_absolute("res://ship/variants")
	for key in jobs:
		var spec: Dictionary = jobs[key]
		var holder := Node3D.new(); holder.name = "V"
		var root := ps.instantiate()
		for n in root.get_children(): root.remove_child(n); n.owner = null; holder.add_child(n)
		root.free()
		ShipVariant.apply(holder, spec)
		for ch in holder.get_children():
			if ch.is_queued_for_deletion(): holder.remove_child(ch); ch.free()
		for ch in holder.get_children(): ch.owner = holder
		holder.set_meta("spec", JSON.stringify(spec))
		var pk := PackedScene.new()
		var e1 := pk.pack(holder)
		var e2 := ResourceSaver.save(pk, "res://ship/variants/%s.scn" % key)
		print("BAKE ", key, " nodes=", holder.get_child_count(), " pack=", e1, " save=", e2)
		holder.free()
	quit()
