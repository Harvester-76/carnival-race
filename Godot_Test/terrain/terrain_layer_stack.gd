extends Resource
class_name TerrainLayerStack

## Elevation where the first stratum begins. Later strata start cumulatively.
@export var base_height_m := 0.0
## Ordered bottom-to-top geological sequence. Materials may be reused.
@export var strata: Array[TerrainStratum] = []
@export var slope_tint := Color("A8805C")
@export_range(0.0, 1.0, 0.01) var slope_tint_strength := 0.48
@export_range(0.0, 1.0, 0.01) var steep_slope_darkening := 0.30
