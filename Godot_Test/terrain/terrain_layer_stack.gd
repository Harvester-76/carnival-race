extends Resource
class_name TerrainLayerStack

## Elevation where the first layer begins. Later layer starts are cumulative.
@export var base_height_m := 0.0
## Array order is bottom-to-top. Thickness controls the elevation interval of each material.
@export var layers: Array[TerrainSurfaceLayer] = []
@export var slope_tint := Color("A8805C")
@export_range(0.0, 1.0, 0.01) var slope_tint_strength := 0.48
@export_range(0.0, 1.0, 0.01) var steep_slope_darkening := 0.30
