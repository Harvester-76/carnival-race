extends SceneTree

const TrackGen = preload("res://trackgen.gd")

func _initialize() -> void:
    var result: Dictionary = TrackGen.generate_open(11, 650.0)
    var cuts: Array = result.get("cuts", [])
    var pts: Array = result.get("pts", [])

    print("TRACKGEN_DUMP_BEGIN")
    print("point_count=", pts.size())
    print("cut_count=", cuts.size())

    for index in cuts.size():
        var cut: Dictionary = cuts[index]
        var a: int = int(cut["a"])
        var b: int = int(cut["b"])
        var p_a: Vector2 = pts[a]
        var p_b: Vector2 = pts[b]
        print(JSON.stringify({
            "cut_index": index,
            "type": cut["type"],
            "a": a,
            "b": b,
            "start_km": [p_a.x, p_a.y],
            "end_km": [p_b.x, p_b.y],
            "cut_length_km": cut["len"],
            "main_length_km": cut["main"],
            "points_km": cut["pts"]
        }))

    print("TRACKGEN_DUMP_END")
    quit()
