extends Resource
class_name TerrainSurfaceLayer

## One elevation band in the ordered terrain material stack.
@export var label := ""
@export var material: StandardMaterial3D
@export_range(0.01, 20000.0, 0.01, "or_greater", "suffix:m") var thickness_m := 700.0
@export_range(0.0, 2000.0, 0.01, "or_greater", "suffix:m") var transition_width_m := 90.0
## World-space UV scale; 0.05 means roughly twenty world meters per texture repeat.
@export_range(0.0001, 4.0, 0.0001, "or_greater") var texture_uv_scale := 0.05
