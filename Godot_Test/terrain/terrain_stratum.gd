extends Resource
class_name TerrainStratum

## One occurrence of a rock material in the geological profile.
## The same StandardMaterial3D can be referenced by multiple strata.
@export var label := ""
@export var material: StandardMaterial3D
@export_range(0.01, 20000.0, 0.01, "or_greater", "suffix:m") var thickness_m := 700.0
@export_range(0.0, 2000.0, 0.01, "or_greater", "suffix:m") var transition_width_m := 90.0
## World-space texture scale; 0.05 means approximately one repeat per 20 meters.
@export_range(0.0001, 4.0, 0.0001, "or_greater") var texture_uv_scale := 0.05
## Height/Parallax settings belong to this stratum occurrence.
@export var height_enabled := true
@export_range(0.0, 20.0, 0.05, "or_greater", "suffix:m") var height_depth_m := 1.5
@export_range(0.0, 4.0, 0.05, "or_greater") var height_normal_strength := 1.0
@export_range(1, 8, 1) var parallax_steps := 6
