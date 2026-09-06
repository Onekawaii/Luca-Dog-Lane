class_name SaveSystem
extends RefCounted

# Persistent Save & Load System for Godot 4 Client (user:// storage).

const SAVE_DIR: String = "user://saves/"
const DEFAULT_SLOT: String = "slot_1"


func _init() -> void:
	_ensure_save_directory()


func _ensure_save_directory() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)


func _get_save_path(slot: String = DEFAULT_SLOT) -> String:
	return SAVE_DIR + slot + ".json"


func save_game(state: WorldState, slot: String = DEFAULT_SLOT) -> bool:
	_ensure_save_directory()
	var path = _get_save_path(slot)
	var save_dict = state.to_dict()
	save_dict["timestamp"] = Time.get_datetime_string_from_system(true)
	save_dict["save_version"] = 3

	var json_str = JSON.stringify(save_dict, "\t")
	var file = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("Failed to open save file for write: " + path)
		return false
	file.store_string(json_str)
	file.close()
	return true


func load_game(state: WorldState, slot: String = DEFAULT_SLOT) -> bool:
	var path = _get_save_path(slot)
	if not FileAccess.file_exists(path):
		push_warning("Save file does not exist: " + path)
		return false

	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("Failed to open save file for read: " + path)
		return false

	var json_str = file.get_as_text()
	file.close()

	var json = JSON.new()
	var err = json.parse(json_str)
	if err != OK or typeof(json.data) != TYPE_DICTIONARY:
		push_error("Corrupted save file at: " + path)
		return false

	state.from_dict(json.data)
	return true


func list_save_slots() -> Array:
	_ensure_save_directory()
	var dir = DirAccess.open(SAVE_DIR)
	var slots: Array = []
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".json"):
				slots.append(file_name.get_basename())
			file_name = dir.get_next()
	return slots


func delete_save(slot: String) -> bool:
	var path = _get_save_path(slot)
	if FileAccess.file_exists(path):
		var err = DirAccess.remove_absolute(path)
		return err == OK
	return false
