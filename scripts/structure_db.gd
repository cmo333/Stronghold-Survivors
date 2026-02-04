extends Node
class_name StructureDB

const DATA_PATH := "res://data/structures.json"
static var _data: Dictionary = {}

static func _ensure_loaded() -> void:
    if _data.size() > 0:
        return
    var file := FileAccess.open(DATA_PATH, FileAccess.READ)
    if file == null:
        push_error("StructureDB: missing data file at %s" % DATA_PATH)
        _data = {}
        return
    var json := JSON.new()
    var err := json.parse(file.get_as_text())
    if err != OK:
        push_error("StructureDB: JSON parse error %s" % json.get_error_message())
        _data = {}
        return
    _data = json.data

static func get_def(id: String) -> Dictionary:
    _ensure_loaded()
    if _data.has(id):
        return _data[id]
    return {}

static func get_all_ids() -> Array:
    _ensure_loaded()
    return _data.keys()

static func get_tier(definition: Dictionary, tier: int) -> Dictionary:
    if definition.is_empty():
        return {}
    var tiers := definition.get("tiers", [])
    if tiers.is_empty():
        return {}
    var safe_tier := clamp(tier, 0, tiers.size() - 1)
    return tiers[safe_tier]
