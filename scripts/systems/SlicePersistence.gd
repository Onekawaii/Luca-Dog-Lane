extends Node

const SCHEMA_VERSION := 1
const GENERATOR_VERSION := 1
const DEFAULT_WORLD_SEED := 6060
const DEFAULT_SAVE_PATH := "user://v013_terrain_slice.json"

var save_path := DEFAULT_SAVE_PATH
var world_seed := DEFAULT_WORLD_SEED
var generator_version := GENERATOR_VERSION
var deferred_saves := false
var save_pending := false
var save_timer := 0.0
var state: Dictionary = {}

func configure(path_override := "", seed_override := DEFAULT_WORLD_SEED) -> void:
	world_seed = seed_override
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
	if int(parsed.get("generator_version", -1)) != generator_version:
		push_warning("Terrain slice generator version mismatch; using defaults")
		return
	if int(parsed.get("world_seed", -1)) != world_seed:
		push_warning("Terrain slice world seed mismatch; using defaults")
		return

	state = parsed
	if typeof(state.get("edits", {})) != TYPE_DICTIONARY:
		state["edits"] = {}
	if typeof(state.get("inventory", {})) != TYPE_DICTIONARY:
		state["inventory"] = {"stone": 0, "stone_brick": 0, "trail_beacon": 0}

func set_voxel_delta(pos: Vector3i, value: int) -> void:
	var edits: Dictionary = state.get("edits", {})
	edits[_voxel_key(pos)] = value
	state["edits"] = edits
	_request_save()

func get_voxel_deltas() -> Dictionary:
	return state.get("edits", {}).duplicate(true)

func set_inventory_snapshot(snapshot: Dictionary) -> void:
	state["inventory"] = snapshot.duplicate(true)
	_request_save()

func _request_save() -> void:
	if not deferred_saves:
		save_now()
		return
	if not save_pending:
		save_timer = 0.5
	save_pending = true

func _process(delta: float) -> void:
	if not save_pending:
		return
	save_timer -= delta
	if save_timer <= 0.0:
		save_now()

func _exit_tree() -> void:
	if save_pending:
		save_now()

func get_inventory_snapshot() -> Dictionary:
	return state.get(
		"inventory",
		{"stone": 0, "stone_brick": 0, "trail_beacon": 0}
	).duplicate(true)

func save_now() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_error("Terrain slice save write failed: " + save_path)
		return false
	file.store_string(JSON.stringify(state, "\t"))
	save_pending = false
	return true

func clear_save() -> void:
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	state = _default_state()

func _default_state() -> Dictionary:
	return {
		"schema_version": SCHEMA_VERSION,
		"generator_version": generator_version,
		"world_seed": world_seed,
		"edits": {},
		"inventory": {"stone": 0, "stone_brick": 0, "trail_beacon": 0},
	}

func _voxel_key(pos: Vector3i) -> String:
	return "%d,%d,%d" % [pos.x, pos.y, pos.z]
