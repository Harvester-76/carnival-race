extends RefCounted
## Minimal offline source contract. A future manually-authored heightfield can
## implement these same methods without depending on the procedural generator.
## The current Stage 1 exporter samples a single-valued terrain surface y(x,z).

func build(_profile: Dictionary) -> void:
	push_error("Geometry source must implement build(profile)")

func selected_routes(_main_extension_m: float) -> Dictionary:
	push_error("Geometry source must implement selected_routes(main_extension_m)")
	return {"routes": [], "polylines": []}

func terrain_context_paths() -> Array:
	return []

func sample_height(_x: float, _z: float) -> float:
	push_error("Geometry source must implement sample_height(x,z)")
	return 0.0

func source_metadata() -> Dictionary:
	return {}

func generation_parameters() -> Dictionary:
	return {}

func close() -> void:
	pass
