class_name CampaignLoader
extends RefCounted

# Data loader and indexer for Strawberry Omen campaign data in Godot 4.

var base_path: String = "res://data/strawberry_omen/"

var manifest: Dictionary = {}
var campaign: Dictionary = {}
var locations: Dictionary = {}
var items: Dictionary = {}
var npcs: Dictionary = {}
var encounters: Dictionary = {}
var conditions: Dictionary = {}
var random_tables: Dictionary = {}
var quests: Dictionary = {}
var interactions: Dictionary = {}
var character_identities: Dictionary = {}
var is_loaded: bool = false


func load_all(path: String = "") -> bool:
	if path != "":
		base_path = path
	if not base_path.ends_with("/"):
		base_path += "/"

	manifest = _load_json(base_path + "manifest.json")
	campaign = _load_json(base_path + "campaign.json")
	locations = _index_by_id(_load_json_array(base_path + "locations.json"))
	items = _index_by_id(_load_json_array(base_path + "items.json"))
	npcs = _index_by_id(_load_json_array(base_path + "npcs.json"))
	encounters = _index_by_id(_load_json_array(base_path + "encounters.json"))
	conditions = _index_by_id(_load_json_array(base_path + "conditions.json"))
	random_tables = _load_json(base_path + "random_tables.json")
	quests = _index_by_id(_load_json_array(base_path + "quests.json"))
	interactions = _load_json(base_path + "interactions.json")
	character_identities = _load_json(base_path + "character_identities.json")

	is_loaded = true
	return true


func _load_json(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		push_warning("Campaign file does not exist: " + file_path)
		return {}
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open campaign file: " + file_path)
		return {}
	var content = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		push_error("JSON parse error in " + file_path + ": " + json.get_error_message())
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data
	return {}


func _load_json_array(file_path: String) -> Array:
	if not FileAccess.file_exists(file_path):
		push_warning("Campaign array file does not exist: " + file_path)
		return []
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		push_error("Failed to open campaign array file: " + file_path)
		return []
	var content = file.get_as_text()
	var json = JSON.new()
	var err = json.parse(content)
	if err != OK:
		push_error("JSON parse error in array " + file_path + ": " + json.get_error_message())
		return []
	if typeof(json.data) == TYPE_ARRAY:
		return json.data
	return []


func _index_by_id(arr: Array) -> Dictionary:
	var dict = {}
	for item in arr:
		if typeof(item) == TYPE_DICTIONARY and item.has("id"):
			dict[item["id"]] = item
	return dict


func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {})


func get_npc(npc_id: String) -> Dictionary:
	return npcs.get(npc_id, {})


func get_location(location_id: String) -> Dictionary:
	return locations.get(location_id, {})


func get_encounter(encounter_id: String) -> Dictionary:
	return encounters.get(encounter_id, {})


func get_identity(npc_id: String) -> Dictionary:
	var chars = character_identities.get("characters", {})
	return chars.get(npc_id, {})
