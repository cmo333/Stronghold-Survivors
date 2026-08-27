extends SceneTree
# Engine-side check of the meta-save recovery work (Milestone 0).
#
# That work was only ever stepped over a Python model of the filesystem. This
# runs the real autoload against real files, because the model cannot speak to
# Godot's own DirAccess.rename / FileAccess.flush semantics.
#
# Waits three frames before touching anything: a SceneTree script's
# _initialize() runs BEFORE the autoloads are attached, so /root/MetaProgression
# does not exist yet at that point. Reading it there returns null and the whole
# check reads like an engine hang.

const SAVE := "user://meta_progress.json"
const BAK := "user://meta_progress.json.bak"
const TMP := "user://meta_progress.json.tmp"

var _frames := 0

func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 3:
		return false
	_go()
	return true

func _mode() -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--mode="):
			return a.substr(7)
	return ""

func _go() -> void:
	var meta = root.get_node_or_null("MetaProgression")
	if meta == null:
		print("[SAVE-TEST] FAIL: MetaProgression autoload not found")
		quit(1)
		return
	match _mode():
		"recover":
			_t_recover(meta)
		"nobackup":
			_t_nobackup(meta)
		"writefail":
			_t_writefail(meta)
		"inspect":
			_t_inspect(meta)
		_:
			print("[SAVE-TEST] FAIL: pass --mode=recover|nobackup|writefail|inspect")
			quit(1)

func _verdict(name: String, checks: Array) -> void:
	var ok := true
	for c in checks:
		var passed: bool = bool(c[1])
		if not passed:
			ok = false
		print("[SAVE-TEST] %-46s %s" % [str(c[0]), "ok" if passed else "FAILED"])
	print("[SAVE-TEST] %s: %s" % [name, "PASS" if ok else "FAIL"])
	quit(0 if ok else 1)

# The corrupt file has a good backup beside it. The player must come back with
# their progress AND be told it happened.
func _t_recover(meta) -> void:
	var warning: String = str(meta.get_load_warning())
	var cores: int = int(meta.get_cores())
	# The backup must NOT have been clobbered by the corrupt file. _save_to_disk
	# rotates whatever sits at SAVE_PATH into the backup slot, so recovering and
	# then immediately re-saving would overwrite the good copy with the garbage
	# it was just rescued from.
	var bak_text := _read(BAK)
	var save_text := _read(SAVE)
	_verdict("recover-from-backup", [
		["cores restored from backup (want 4242)", cores == 4242],
		["player was told", warning != ""],
		["warning names the backup", warning.to_lower().contains("backup")],
		["live save is now readable JSON", _is_json_dict(save_text)],
		["live save carries the recovered cores", save_text.contains("4242")],
		["backup is NOT the corrupt bytes", not bak_text.contains("NOT JSON AT ALL")],
		["corrupt bytes are gone from the live save", not save_text.contains("NOT JSON AT ALL")],
	])

# Neither file is readable. Defaults, a different message, and the unreadable
# file must be LEFT ALONE -- it is the player's only remaining artifact.
func _t_nobackup(meta) -> void:
	var warning: String = str(meta.get_load_warning())
	var cores: int = int(meta.get_cores())
	var save_text := _read(SAVE)
	_verdict("no-usable-backup", [
		["fell back to defaults (0 cores)", cores == 0],
		["player was told", warning != ""],
		["message says progress was reset", warning.to_lower().contains("reset")],
		["unreadable file kept for support", save_text.contains("NOT JSON AT ALL")],
	])

# A purchase must be refused, not merely warned about, when the write cannot
# land. Simulated by making the temp path a directory, which FileAccess cannot
# open for writing -- and unlike a chmod, that stops root too.
func _t_writefail(meta) -> void:
	var cores_before: int = int(meta.get_cores())
	var hero := ""
	var cost := 0
	for h in meta.HERO_DEFS:
		var id := str(h.get("id", ""))
		if id == "" or meta.is_hero_unlocked(id):
			continue
		var c := int(h.get("core_cost", 0))
		if c > 0 and c <= cores_before:
			hero = id
			cost = c
			break
	if hero == "":
		print("[SAVE-TEST] FAIL: no affordable locked hero (cores=", cores_before, ")")
		quit(1)
		return

	DirAccess.make_dir_absolute(TMP)
	var blocked := DirAccess.dir_exists_absolute(TMP)
	var save_before := _read(SAVE)
	var bought: bool = bool(meta.unlock_hero(hero))
	var cores_after: int = int(meta.get_cores())
	var unlocked: bool = bool(meta.is_hero_unlocked(hero))
	var save_after := _read(SAVE)

	print("[SAVE-TEST] hero=", hero, " cost=", cost, " cores ", cores_before, " -> ", cores_after)
	_verdict("purchase-refused-when-write-fails", [
		["temp path really is unwritable", blocked],
		["purchase reported failure", not bought],
		["cores were not taken", cores_after == cores_before],
		["hero did not appear unlocked", not unlocked],
		["save on disk untouched", save_after == save_before],
	])

func _t_inspect(meta) -> void:
	print("[SAVE-TEST] cores=", meta.get_cores(), " warning=", meta.get_load_warning())
	var ids: Array = []
	for h in meta.HERO_DEFS:
		ids.append("%s(%s)" % [str(h.get("id", "")), str(h.get("core_cost", 0))])
	print("[SAVE-TEST] heroes=", ", ".join(PackedStringArray(ids)))
	quit(0)

func _read(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	var t := f.get_as_text()
	f.close()
	return t

func _is_json_dict(text: String) -> bool:
	if text.strip_edges() == "":
		return false
	var j := JSON.new()
	if j.parse(text) != OK:
		return false
	return j.data is Dictionary
