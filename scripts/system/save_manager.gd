## JSON saves in user://saves/ (wayfarer lineage). The stub persists the
## run's shape — current site + crew condition — not derived state.
class_name SaveManager
extends RefCounted

const SAVE_DIR := "user://saves"
const SAVE_VERSION := 3  # v3 adds the job contract (active_job/carrying/completed_jobs);
                         # v2 added xp/crew_level/perks/cleared_sites. Older saves load
                         # with the missing keys defaulted — fresh crew, no job.

static func _path(slot: int) -> String:
	return "%s/slot_%d.json" % [SAVE_DIR, slot]

static func has_save(slot: int = 0) -> bool:
	return FileAccess.file_exists(_path(slot))

static func save_game(slot: int, data: Dictionary) -> bool:
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)
	var file := FileAccess.open(_path(slot), FileAccess.WRITE)
	if file == null:
		return false
	data["version"] = SAVE_VERSION
	file.store_string(JSON.stringify(data, "\t"))
	return true

static func load_game(slot: int = 0) -> Dictionary:
	if not has_save(slot):
		return {}
	var file := FileAccess.open(_path(slot), FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}
