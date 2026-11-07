extends RefCounted
class_name RouteMapView

const INK := Color("060A18")
const STEEL := Color("93A9D9")
const CREAM := Color("F7E6BF")
const WHITE := Color("FFFFFF")
const ORANGE := Color("FF8A1E")
const CYAN := Color("8CD9F2")
const DANGER := Color("F24033")

var main: Node
var model_id := -1
var world_points := PackedVector2Array()
var path_s := PackedFloat32Array()
var world_cuts: Array[PackedVector2Array] = []
var world_bounds := Rect2()
var geometry_cache := {}

func setup(source: Node) -> void:
	main = source
	model_id = -1
	_ensure_model()

func _ensure_model() -> void:
	if main == null or not is_instance_valid(main): return
	if model_id == main.trk_pts.size() and not world_points.is_empty(): return
	model_id = main.trk_pts.size()
	geometry_cache.clear()
	world_points.clear(); path_s.clear(); world_cuts.clear()
	var route_length := float(main.race_len)
	for i in range(0, main.trk_pts.size(), 3):
		if float(main.trk_s[i]) > route_length: break
		world_points.append(main.trk_pts[i]); path_s.append(main.trk_s[i])
	var finish: Vector2 = main._track_at(minf(route_length, float(main.trk_len) - 1.0))[0]
	world_points.append(finish); path_s.append(route_length)
	var lo := Vector2(INF, INF); var hi := Vector2(-INF, -INF)
	for point in world_points: lo = lo.min(point); hi = hi.max(point)
	world_bounds = Rect2(lo, hi - lo)
	for branch in main.branches:
		var source_points: PackedVector2Array = branch["pts"]
		var sampled := PackedVector2Array()
		for i in range(0, source_points.size(), 2): sampled.append(source_points[i])
		if not source_points.is_empty() and (sampled.is_empty() or sampled[-1] != source_points[-1]): sampled.append(source_points[-1])
		world_cuts.append(sampled)

func geometry(bounds: Rect2) -> Dictionary:
	_ensure_model()
	var cache_key := str(bounds)
	if geometry_cache.has(cache_key): return geometry_cache[cache_key]
	if world_points.size() < 2 or bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return {"pts": PackedVector2Array(), "s": PackedFloat32Array(), "cuts": [], "start": Vector2.ZERO, "finish": Vector2.ZERO}
	var k := minf(bounds.size.x / maxf(world_bounds.size.x, 1.0), bounds.size.y / maxf(world_bounds.size.y, 1.0))
	var off := bounds.position + (bounds.size - world_bounds.size * k) * 0.5
	var mapped := PackedVector2Array()
	for point in world_points: mapped.append(off + (point - world_bounds.position) * k)
	var cuts: Array[PackedVector2Array] = []
	for branch in world_cuts:
		var mapped_branch := PackedVector2Array()
		for point in branch: mapped_branch.append(off + (point - world_bounds.position) * k)
		cuts.append(mapped_branch)
	var result := {"pts": mapped, "s": path_s, "cuts": cuts, "start": mapped[0], "finish": mapped[-1], "lo": world_bounds.position, "scale": k, "offset": off}
	geometry_cache[cache_key] = result
	return result

func project(point: Vector2, map_data: Dictionary) -> Vector2:
	return Vector2(map_data["offset"]) + (point - Vector2(map_data["lo"])) * float(map_data["scale"])

func draw_backbone(target: Control, map_data: Dictionary, style := "hud") -> void:
	var points: PackedVector2Array = map_data.get("pts", PackedVector2Array())
	if points.size() < 2: return
	if style == "menu":
		target.draw_polyline(points, Color(CYAN, 0.13), 15.0, true)
		target.draw_polyline(points, Color(CYAN, 0.36), 8.0, true)
		target.draw_polyline(points, Color(CYAN, 0.92), 3.0, true)
	else:
		target.draw_polyline(points, Color(INK, 0.6), 6.0, true)

func draw_branches(target: Control, map_data: Dictionary, style := "hud") -> void:
	for branch in map_data.get("cuts", []):
		var points: PackedVector2Array = branch
		if points.size() < 2: continue
		if style == "menu": target.draw_polyline(points, Color(ORANGE, 0.16), 8.0, true)
		var color := Color(ORANGE, 0.9) if style == "menu" else ORANGE
		_draw_dashed(target, points, color, 2.8 if style == "menu" else 3.0, 5.0, 3.0)

func draw_start(target: Control, map_data: Dictionary, style := "hud") -> void:
	var point := Vector2(map_data.get("start", Vector2.ZERO))
	if style == "menu":
		target.draw_circle(point, 9.0, Color(CYAN, 0.22))
		target.draw_circle(point, 5.5, CYAN)
		target.draw_line(point + Vector2(-9, 0), point + Vector2(9, 0), WHITE, 2.0, true)
		target.draw_string(ThemeDB.fallback_font, point + Vector2(13, -4), "СТАРТ", HORIZONTAL_ALIGNMENT_LEFT, 100.0, 12, STEEL)
	else:
		target.draw_line(point + Vector2(-7, 0), point + Vector2(7, 0), WHITE, 3.0, true)

func draw_finish(target: Control, map_data: Dictionary, style := "hud") -> void:
	var point := Vector2(map_data.get("finish", Vector2.ZERO))
	if style == "menu":
		target.draw_circle(point, 10.0, Color(CYAN, 0.14))
		target.draw_circle(point, 7.0, WHITE)
		target.draw_circle(point, 5.0, ORANGE)
		var label := ThemeDB.fallback_font
		target.draw_string(label, point + Vector2(13, -4), "ФИНИШ", HORIZONTAL_ALIGNMENT_LEFT, 100.0, 12, CREAM)
	else:
		target.draw_circle(point, 8.5, WHITE)
		target.draw_circle(point, 6.5, DANGER)
		target.draw_rect(Rect2(point.x - 2.5, point.y - 2.5, 2.5, 2.5), WHITE)
		target.draw_rect(Rect2(point.x, point.y, 2.5, 2.5), WHITE)

func draw_overview(target: Control, bounds: Rect2) -> void:
	var map_data := geometry(bounds)
	draw_backbone(target, map_data, "menu")
	draw_branches(target, map_data, "menu")
	draw_start(target, map_data, "menu")
	draw_finish(target, map_data, "menu")

func _draw_dashed(target: Control, points: PackedVector2Array, color: Color, width: float, dash: float, gap: float) -> void:
	for i in range(points.size() - 1):
		var a := points[i]; var b := points[i + 1]
		var length := a.distance_to(b)
		if length < 0.01: continue
		var direction := (b - a) / length
		var distance := 0.0
		while distance < length:
			target.draw_line(a + direction * distance, a + direction * minf(distance + dash, length), color, width, true)
			distance += dash + gap
