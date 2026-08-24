extends Node
class_name RiftDB

# The tables a run is rolled from. Deliberately the same shape as StructureDB:
# static, lazily loaded, no autoload. That matters more here than it looks --
# tools/*_test.gd are SceneTree scripts, and an autoload is not attached when one
# of those starts, so anything a harness must reach has to be reachable without
# the tree. RunManifest is testable because this class is not a singleton node.

const DATA_PATH := "res://data/rift.json"

static var _data: Dictionary = {}

static func _ensure_loaded() -> void:
	if _data.size() > 0:
		return
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		push_error("RiftDB: missing data file at %s" % DATA_PATH)
		_data = {}
		return
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_error("RiftDB: JSON parse error %s" % json.get_error_message())
		_data = {}
		return
	if typeof(json.data) != TYPE_DICTIONARY:
		push_error("RiftDB: %s is not a JSON object" % DATA_PATH)
		_data = {}
		return
	_data = json.data


# The whole table set, in the shape RunManifest.roll() expects. Passing this in
# rather than reaching for it is what lets a harness roll against a synthetic
# table -- see tools/manifest_test.gd.
static func tables() -> Dictionary:
	_ensure_loaded()
	return {
		"races": _data.get("races", []),
		"regions": _data.get("regions", []),
		"modifiers": _data.get("modifiers", [])
	}


static func races() -> Array:
	_ensure_loaded()
	return _data.get("races", [])


static func regions() -> Array:
	_ensure_loaded()
	return _data.get("regions", [])


static func modifiers() -> Array:
	_ensure_loaded()
	return _data.get("modifiers", [])


static func get_race(id: String) -> Dictionary:
	for r in races():
		if str((r as Dictionary).get("id", "")) == id:
			return r
	return {}


static func get_region(id: String) -> Dictionary:
	for r in regions():
		if str((r as Dictionary).get("id", "")) == id:
			return r
	return {}


static func get_modifier(id: String) -> Dictionary:
	for m in modifiers():
		if str((m as Dictionary).get("id", "")) == id:
			return m
	return {}


# The arrival entry a manifest rolled, looked back up. Arrivals live under the
# race because "how they reached the Rift" is a property of the culture, not a
# free-floating axis (docs/RACE_BRIEF.md says the story is the arrival text pool).
static func get_arrival(race_id: String, arrival_id: String) -> Dictionary:
	var race := get_race(race_id)
	for a in race.get("arrivals", []):
		if str((a as Dictionary).get("id", "")) == arrival_id:
			return a
	return {}
