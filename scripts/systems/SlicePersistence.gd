extends Node

const SCHEMA_VERSION := 1
const GENERATOR_VERSION := 1
const WORLD_SEED := 130013
const DEFAULT_SAVE_PATH := "user://v013_terrain_slice.json"

var save_path := DEFAULT_SAVE_PATH
var state: Dictionary = {}

func configure(path_override := "") -> void:
	if not path_override.is_empty():
		save_path = path_override
	load_state()

func load_state() -> void:
	state = _default_state()
	if not FileAccess.file_exists(save_path):
		return

	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		push_warning("Terrain slice save could not be opened: " + save_path)
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Terrain slice save is not a JSON object; using defaults")
		return
	if int(parsed.get("schema_version", -1)) != SCHEMA_VERSION:
		push_warning("Terrain slice save schema mismatch; using defaults")
		return
	if int(parsed.get("generator_version", -1)) != GENERATOR_VERSION:
		push_warning("Terrain slice generator version mismatch; using defaults")
		return

	state = parsed
	if typeof(state.get("edits", {})) != TYPE_DICTIONARY:
		state["edits"] = {}
	if typeof(state.get("inventory", {})) != TYPE_DICTIONARY:
		state["inventory"] = {"stone": 0, "stone_brick": 0}

func set_voxel_delta(pos: Vector3i, value: int) -> void:
	var edits: Dictionary = state.get("edits", {})
	edits[_voxel_key(pos)] = value
	state["edits"] = edits
	save_now()

func get_voxel_deltas() -> Dictionary:
	return state.get("edits", {}).duplicate(true)

func set_inventory_snapshot(snapshot: Dictionary) -> void:
	state["inventory"] = snapshot.duplicate(true)
	save_now()

func get_inventory_snapshot() -> Dictionary:
	return state.get("inventory", {"stone": 0, "stone_brick": 0}).duplicate(true)

func save_now() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Terrain slice save write failed: " + save_path)
		return false
	file.store_string(JSON.stringify(state, "\t"))
	return true

func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	state = _default_state()

func _default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"generator_version": GENERATOR_VERSION,
		"world_seed": WORLD_SEED,
		"edits": {},
		"inventory": {"stone": 0, "stone_brick": 0},
	}

func _voxel_key(pos: Vector3i) -> String:
	return "%d,%d,%d" % [pos.x, pos.y, pos.z]
