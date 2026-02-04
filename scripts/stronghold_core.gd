extends Building

func _ready() -> void:
    super._ready()
    var def := StructureDB.get_def("stronghold_core")
    if not def.is_empty():
        configure("stronghold_core", def, 0)
