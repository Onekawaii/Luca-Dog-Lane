extends Node

signal changed(summary: String)

const RECIPE_PATH := "res://data/recipes_v013.json"

var persistence: Node
var counts: Dictionary = {"stone": 0, "stone_brick": 0}
var recipes: Dictionary = {}

func configure(store: Node) -> void:
	persistence = store
	counts = persistence.call("get_inventory_snapshot")
	counts["stone"] = int(counts.get("stone", 0))
	counts["stone_brick"] = int(counts.get("stone_brick", 0))
	_load_recipes()
	_emit_changed()

func add_item(item_id: String, amount := 1) -> void:
	counts[item_id] = int(counts.get(item_id, 0)) + amount
	_persist()

func count_item(item_id: String) -> int:
	return int(counts.get(item_id, 0))

func consume(item_id: String, amount := 1) -> bool:
	var available := count_item(item_id)
	if available < amount:
		return false
	counts[item_id] = available - amount
	_persist()
	return true

func craft(recipe_id: String) -> Dictionary:
	if not recipes.has(recipe_id):
		return {"ok": false, "message": "Unknown recipe: " + recipe_id}

	var recipe: Dictionary = recipes[recipe_id]
	var ingredients: Dictionary = recipe.get("ingredients", {})
	for item_id in ingredients:
		var needed := int(ingredients[item_id])
		if count_item(str(item_id)) < needed:
			return {
				"ok": false,
				"message": "Need %d %s" % [needed, str(item_id).replace("_", " ").to_upper()],
			}

	for item_id in ingredients:
		counts[str(item_id)] = count_item(str(item_id)) - int(ingredients[item_id])
	var outputs: Dictionary = recipe.get("outputs", {})
	for item_id in outputs:
		counts[str(item_id)] = count_item(str(item_id)) + int(outputs[item_id])
	_persist()

	return {
		"ok": true,
		"message": str(recipe.get("label", recipe_id)).to_upper() + " CRAFTED",
	}

func summary() -> String:
	return "STONE %d  //  BRICK %d" % [count_item("stone"), count_item("stone_brick")]

func snapshot() -> Dictionary:
	return counts.duplicate(true)

func _load_recipes() -> void:
	var text := FileAccess.get_file_as_string(RECIPE_PATH)
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Recipe data failed to parse: " + RECIPE_PATH)
		recipes = {}
		return
	recipes = parsed.get("recipes", {})

func _persist() -> void:
	if persistence != null:
		persistence.call("set_inventory_snapshot", counts)
	_emit_changed()

func _emit_changed() -> void:
	changed.emit(summary())
