extends RefCounted

# Current world identity is separate from per-seed terrain/story/loadout saves.
const GENERATION_VERSION := 2
var save_path := "user://spiral_world_index_v1.json"
var worlds: Dictionary = {}

func configure(path: String = "") -> bool:
	if not path.is_empty():
		save_path = path
	if not FileAccess.file_exists(save_path):
		return true
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if not parsed is Dictionary or parsed.get("schema_version") != 1 or not parsed.get("worlds") is Dictionary:
		push_error("World index is invalid; existing saves were not changed")
		return false
	worlds = parsed.worlds.duplicate(true)
	for map_id in worlds:
		var entry = worlds[map_id]
		if not entry is Dictionary or not entry.has("seed") or not entry.has("generation_version"):
			push_error("World index entry is invalid; generation stopped")
			return false
		var seed_value = entry.seed
		var version = entry.generation_version
		if typeof(seed_value) not in [TYPE_INT, TYPE_FLOAT] or typeof(version) not in [TYPE_INT, TYPE_FLOAT]:
			return false
		if not is_finite(float(seed_value)) or float(seed_value) != float(int(seed_value)) or int(seed_value) < 0 or int(seed_value) > 2147483646 or not is_finite(float(version)) or float(version) != float(int(version)) or int(version) not in [1, 2]:
			return false
		worlds[map_id] = {"seed": int(seed_value), "generation_version": int(version)}
	return true

func identity(map_id: String, legacy_seed: int, legacy_exists: bool) -> Dictionary:
	if worlds.has(map_id):
		return worlds[map_id].duplicate(true)
	var entry := {"seed": legacy_seed if legacy_exists else fresh_seed(), "generation_version": 1 if legacy_exists else GENERATION_VERSION}
	worlds[map_id] = entry
	if not _save():
		worlds.erase(map_id)
		return {}
	return entry.duplicate(true)

func new_world(map_id: String, previous_seed: int = -1) -> Dictionary:
	var old = worlds.get(map_id)
	var entry := {"seed": fresh_seed(previous_seed), "generation_version": GENERATION_VERSION}
	worlds[map_id] = entry
	if not _save():
		if old == null:
			worlds.erase(map_id)
		else:
			worlds[map_id] = old
		return {}
	return entry.duplicate(true)

static func fresh_seed(previous_seed: int = -1) -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var seed_value := rng.randi_range(1, 2147483646)
	return seed_value % 2147483646 + 1 if seed_value == previous_seed else seed_value

func _save() -> bool:
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"schema_version": 1, "worlds": worlds}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return false
	return DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path)) == OK
