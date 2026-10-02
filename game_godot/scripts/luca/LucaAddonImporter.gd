class_name LucaAddonImporter
extends RefCounted

const ModManagerClass = preload("res://scripts/luca/LucaModManager.gd")
const MOD_DIR := "user://mods"

func import_lucamod(source_path: String) -> Dictionary:
	var manager := ModManagerClass.new()
	var validation := manager.load_lucamod(source_path)
	if not bool(validation.get("ok", false)):
		return validation
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MOD_DIR))
	var file_name := source_path.get_file()
	var destination := MOD_DIR.path_join(file_name)
	var copy_error := DirAccess.copy_absolute(
		ProjectSettings.globalize_path(source_path),
		ProjectSettings.globalize_path(destination)
	)
	if copy_error != OK:
		return {"ok": false, "errors": ["copy failed: %s" % error_string(copy_error)]}
	return {
		"ok": true,
		"path": destination,
		"id": validation.get("id", ""),
		"modset_hash": validation.get("modset_hash", ""),
	}
