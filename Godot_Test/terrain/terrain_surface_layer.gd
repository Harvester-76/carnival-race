extends Resource
class_name TerrainSurfaceLayer

## One elevation band in the ordered terrain material stack.
@export var label := ""
@export var material: StandardMaterial3D
@export_range(0.01, 20000.0, 0.01, "or_greater", "suffix:m") var thickness_m := 700.0
@export_range(0.0, 2000.0, 0.01, "or_greater", "suffix:m") var transition_width_m := 90.0
## World-space UV scale; 0.05 means roughly twenty world meters per texture repeat.
@export_range(0.0001, 4.0, 0.0001, "or_greater") var texture_uv_scale := 0.05

## Enables Height sampling from material.heightmap_texture.
@export var height_enabled := true
## Apparent relief depth in world meters. Start low; increase gradually.
@export_range(0.0, 20.0, 0.05, "or_greater", "suffix:m") var height_depth_m := 1.5
## Strength of the normal perturbation derived from the Height map.
@export_range(0.0, 4.0, 0.05, "or_greater") var height_normal_strength := 1.0
## Number of parallax ray-march steps. Shader uses a fixed maximum of 8.
@export_range(1, 8, 1) var parallax_steps := 6
