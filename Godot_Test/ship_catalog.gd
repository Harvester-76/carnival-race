extends RefCounted
## Loads ship definitions from one directory per ship. JSON profiles override base defaults.

const SHIPS_ROOT := "res://ships"
const BASE_PATH := "res://ships/base/ship.json"

static func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("[SHIP_CATALOG] Missing profile: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("[SHIP_CATALOG] Invalid JSON profile: %s" % path)
		return {}
	return parsed

static func _merge(base: Dictionary, overrides: Dictionary) -> Dictionary:
	var result := base.duplicate(true)
	for key in overrides:
		if typeof(overrides[key]) == TYPE_DICTIONARY and typeof(result.get(key, null)) == TYPE_DICTIONARY:
			result[key] = _merge(result[key], overrides[key])
		else:
			result[key] = overrides[key]
	return result

static func load_base() -> Dictionary:
	return _read_json(BASE_PATH)

static func load_ships() -> Array[Dictionary]:
	var base := _read_json(BASE_PATH)
	if base.is_empty():
		return []
	var entries: Array[Dictionary] = []
	var dir := DirAccess.open(SHIPS_ROOT)
	if dir == null:
		push_error("[SHIP_CATALOG] Cannot open %s" % SHIPS_ROOT)
		return []
	dir.list_dir_begin()
	var item := dir.get_next()
	while item != "":
		if dir.current_is_dir() and item != "base" and not item.begins_with("."):
			var path := "%s/%s/ship.json" % [SHIPS_ROOT, item]
			var specific := _read_json(path)
			if not specific.is_empty():
				var ship_base := base                                       # по умолчанию общая база ships/base/ship.json
				var base_rel := String(specific.get("base_profile", ""))
				if base_rel != "":
					var base_path := (path.get_base_dir() + "/" + base_rel).simplify_path()
					ship_base = _read_json(base_path)
					if ship_base.is_empty():
						push_error("[SHIP_CATALOG] Cannot load base_profile %s for %s" % [base_path, path])
						item = dir.get_next()
						continue
				var merged := _merge(ship_base, specific)
				merged["_directory"] = "%s/%s" % [SHIPS_ROOT, item]
				if String(merged.get("id", "")) == "" or String(merged.get("name", "")) == "":
					push_error("[SHIP_CATALOG] Profile requires id and name: %s" % path)
				elif not ResourceLoader.exists(String(merged.get("model", ""))):
					push_error("[SHIP_CATALOG] Missing model for %s: %s" % [merged["id"], merged.get("model", "")])
				else:
					var textures: Dictionary = merged.get("textures", {})
					var missing_texture := ""
					for texture_key in ["albedo", "roughness", "metallic", "decal"]:
						var texture_path := String(textures.get(texture_key, ""))
						if texture_path != "" and not ResourceLoader.exists(texture_path):
							missing_texture = texture_path
							break
					if missing_texture != "":
						push_error("[SHIP_CATALOG] Missing texture for %s: %s" % [merged["id"], missing_texture])
					else:
						entries.append(merged)
		item = dir.get_next()
	dir.list_dir_end()
	entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ao := int(a.get("order", 9999))
		var bo := int(b.get("order", 9999))
		return ao < bo if ao != bo else String(a["id"]) < String(b["id"]))
	return entries
