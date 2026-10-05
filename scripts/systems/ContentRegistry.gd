class_name ContentRegistry
extends Node

const ITEMS_PATH := "res://data/items_v016.json"
const TOOLS_PATH := "res://data/tools_v016.json"
const MAPS_PATH := "res://data/maps_v016.json"
const RECIPES_PATH := "res://data/recipes_v016.json"

var items: Dictionary = {}
var tools: Dictionary = {}
var tool_order: Array[String] = []
var maps: Dictionary = {}
var recipes: Dictionary = {}
var default_map_id := "lucas_field"
var validation_errors: Array[String] = []

func _ready() -> void:
	load_catalogs()

func load_catalogs() -> bool:
	validation_errors.clear()
	var items_doc := _load_document(ITEMS_PATH)
	var tools_doc := _load_document(TOOLS_PATH)
	var maps_doc := _load_document(MAPS_PATH)
	var recipes_doc := _load_document(RECIPES_PATH)

	items = items_doc.get("items", {}) if not items_doc.is_empty() else {}
	tools = tools_doc.get("tools", {}) if not tools_doc.is_empty() else {}
	maps = maps_doc.get("maps", {}) if not maps_doc.is_empty() else {}
	recipes = recipes_doc.get("recipes", {}) if not recipes_doc.is_empty() else {}
	default_map_id = str(maps_doc.get("default_map", "lucas_field"))

	tool_order.clear()
	for value in tools_doc.get("order", []):
		tool_order.append(str(value))

	_validate_catalogs(items_doc, tools_doc, maps_doc, recipes_doc)
	if validation_errors.is_empty():
		print(
			"CONTENT_REGISTRY_READY items=", items.size(),
			" tools=", tools.size(),
			" maps=", maps.size(),
			" recipes=", recipes.size()
		)
		return true

	for issue in validation_errors:
		push_error("CONTENT_REGISTRY // " + issue)
	return false

func is_valid() -> bool:
	return validation_errors.is_empty()

func get_item(item_id: String) -> Dictionary:
	return items.get(item_id, {}).duplicate(true)

func get_tool(tool_id: String) -> Dictionary:
	return tools.get(tool_id, {}).duplicate(true)

func get_tool_ids() -> Array[String]:
	return tool_order.duplicate()

func get_map(map_id: String) -> Dictionary:
	return maps.get(map_id, {}).duplicate(true)

func get_map_ids() -> Array[String]:
	var ids: Array[String] = []
	for map_id in maps.keys():
		ids.append(str(map_id))
	ids.sort()
	return ids

func get_map_options() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for map_id in get_map_ids():
		var profile := get_map(map_id)
		result.append({
			"id": map_id,
			"label": str(profile.get("label", map_id)),
			"seed": int(profile.get("seed", 0)),
		})
	return result

func get_default_map_id() -> String:
	return default_map_id

func get_recipe(recipe_id: String) -> Dictionary:
	return recipes.get(recipe_id, {}).duplicate(true)

func _load_document(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		validation_errors.append("missing catalog: " + path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		validation_errors.append("catalog is not a JSON object: " + path)
		return {}
	return parsed

func _validate_catalogs(
	items_doc: Dictionary,
	tools_doc: Dictionary,
	maps_doc: Dictionary,
	recipes_doc: Dictionary
) -> void:
	_validate_schema(items_doc, ITEMS_PATH, 1)
	_validate_schema(tools_doc, TOOLS_PATH, 1)
	_validate_schema(maps_doc, MAPS_PATH, 1)
	_validate_schema(recipes_doc, RECIPES_PATH, 2)

	if items.is_empty():
		validation_errors.append("item catalog is empty")
	if tools.is_empty():
		validation_errors.append("tool catalog is empty")
	if maps.is_empty():
		validation_errors.append("map catalog is empty")
	if not maps.has(default_map_id):
		validation_errors.append("default map missing: " + default_map_id)

	for tool_id in tool_order:
		if not tools.has(tool_id):
			validation_errors.append("tool order references missing tool: " + tool_id)
	for tool_id in tools:
		var tool: Dictionary = tools[tool_id]
		for key in ["label", "action", "range"]:
			if not tool.has(key):
				validation_errors.append("tool %s missing %s" % [tool_id, key])

	for map_id in maps:
		var profile: Dictionary = maps[map_id]
		for key in ["label", "seed", "terrain_scale", "spawn", "sky_top", "sky_horizon", "fog_color", "fog_density"]:
			if not profile.has(key):
				validation_errors.append("map %s missing %s" % [map_id, key])
		if profile.get("spawn", []).size() != 3:
			validation_errors.append("map %s spawn must have three coordinates" % map_id)

	for recipe_id in recipes:
		var recipe: Dictionary = recipes[recipe_id]
		if not recipe.has("ingredients") or not recipe.has("outputs"):
			validation_errors.append("recipe %s missing ingredients/outputs" % recipe_id)
			continue
		for item_id in recipe.get("ingredients", {}):
			if not items.has(str(item_id)):
				validation_errors.append("recipe %s uses unknown item %s" % [recipe_id, item_id])
		for item_id in recipe.get("outputs", {}):
			if not items.has(str(item_id)):
				validation_errors.append("recipe %s outputs unknown item %s" % [recipe_id, item_id])

func _validate_schema(doc: Dictionary, path: String, expected: int) -> void:
	if doc.is_empty():
		return
	var actual := int(doc.get("schema_version", -1))
	if actual != expected:
		validation_errors.append(
			"schema mismatch %s expected=%d actual=%d" % [path, expected, actual]
		)
