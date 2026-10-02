class_name LucaModManager
extends RefCounted

const VMClass = preload("res://scripts/luca/LucaModVM.gd")
const ALLOWED_PERMISSIONS := ["spawn", "decorate", "dialogue", "recipes"]
const DENIED_PERMISSIONS := ["filesystem", "shell", "network", "native_code", "process"]

var loaded_mods: Dictionary = {}
var modset_hash := ""
var vm = VMClass.new()

func load_lucamod(path: String) -> Dictionary:
	if not path.to_lower().ends_with(".lucamod"):
		return _error("extension must be .lucamod")
	if not FileAccess.file_exists(path):
		return _error("mod file not found")
	var zip := ZIPReader.new()
	var open_error := zip.open(path)
	if open_error != OK:
		return _error("unable to open mod archive")
	var files := zip.get_files()
	for entry in files:
		if _unsafe_path(str(entry)):
			zip.close()
			return _error("unsafe archive path: " + str(entry))
	if "manifest.json" not in files:
		zip.close()
		return _error("manifest.json missing")
	var parsed_manifest: Variant = _parse_json_bytes(zip.read_file("manifest.json"))
	if not parsed_manifest is Dictionary:
		zip.close()
		return _error("manifest.json invalid")
	var manifest: Dictionary = parsed_manifest
	var validation: Dictionary = validate_manifest(manifest)
	if not bool(validation["ok"]):
		zip.close()
		return validation
	var content: Dictionary = {}
	if "content.json" in files:
		var parsed_content: Variant = _parse_json_bytes(zip.read_file("content.json"))
		if parsed_content is Dictionary:
			content = parsed_content
	var program: Array = []
	if "program.json" in files:
		var parsed_program: Variant = _parse_json_bytes(zip.read_file("program.json"))
		if parsed_program is Array:
			program = parsed_program
	var vm_validation: Dictionary = vm.validate_program(program)
	if not bool(vm_validation["ok"]):
		zip.close()
		return {"ok": false, "errors": vm_validation["errors"]}
	zip.close()
	var mod_id := str(manifest.get("id", ""))
	loaded_mods[mod_id] = {
		"manifest": manifest.duplicate(true),
		"content": content.duplicate(true),
		"program": program.duplicate(true),
	}
	_recalculate_modset_hash()
	return {"ok": true, "id": mod_id, "modset_hash": modset_hash}

func validate_manifest(manifest: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var mod_id := str(manifest.get("id", ""))
	if mod_id.is_empty():
		errors.append("id missing")
	if str(manifest.get("version", "")).is_empty():
		errors.append("version missing")
	var permissions: Array = manifest.get("permissions", [])
	for permission in permissions:
		var value := str(permission)
		if value in DENIED_PERMISSIONS:
			errors.append("permission denied: " + value)
		elif value not in ALLOWED_PERMISSIONS:
			errors.append("unknown permission: " + value)
	return {"ok": errors.is_empty(), "errors": errors}

func scan_user_mods(directory: String = "user://mods") -> Dictionary:
	var absolute := ProjectSettings.globalize_path(directory)
	if not DirAccess.dir_exists_absolute(absolute):
		DirAccess.make_dir_recursive_absolute(absolute)
	var dir := DirAccess.open(directory)
	if dir == null:
		return _error("mod directory unavailable")
	var loaded: Array[String] = []
	var errors: Array = []
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while not file_name.is_empty():
		if not dir.current_is_dir() and file_name.to_lower().ends_with(".lucamod"):
			var result := load_lucamod(directory.path_join(file_name))
			if bool(result.get("ok", false)):
				loaded.append(str(result.get("id", file_name)))
			else:
				errors.append({"file": file_name, "errors": result.get("errors", [])})
		file_name = dir.get_next()
	dir.list_dir_end()
	loaded.sort()
	return {"ok": errors.is_empty(), "loaded": loaded, "errors": errors, "modset_hash": modset_hash}

func run_mod_program(mod_id: String, context: Dictionary = {}) -> Dictionary:
	if not loaded_mods.has(mod_id):
		return _error("mod not loaded")
	var record: Dictionary = loaded_mods[mod_id]
	return vm.run(record.get("program", []), context)

func _recalculate_modset_hash() -> void:
	var rows: Array[String] = []
	for mod_id in loaded_mods.keys():
		var record: Dictionary = loaded_mods[mod_id]
		var manifest: Dictionary = record["manifest"]
		rows.append("%s@%s" % [mod_id, str(manifest.get("version", "0"))])
	rows.sort()
	modset_hash = "|".join(rows).sha256_text()

func _unsafe_path(entry: String) -> bool:
	var normalized := entry.replace("\\", "/")
	return normalized.begins_with("/") or normalized.contains("../") or normalized.contains(":/")

func _parse_json_bytes(bytes: PackedByteArray) -> Variant:
	return JSON.parse_string(bytes.get_string_from_utf8())

func _error(message: String) -> Dictionary:
	return {"ok": false, "errors": [message]}
