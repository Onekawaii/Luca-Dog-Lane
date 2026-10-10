extends Node

const Journal = preload("res://scripts/rpg/ExplorationJournal.gd")
const Stone = preload("res://scripts/rpg/LoreStone.gd")
var game: Node3D
var model: RefCounted
var save_path := ""
var enabled := false
var markers: Array[Node3D] = []

func configure(owner_game: Node3D) -> bool:
	game = owner_game
	var override := OS.get_environment("SPIRAL_RPG_SAVE_PATH")
	save_path = "user://rpg_journal_%s_%d_v1.json" % [game.active_map_id, game.world_seed] if override.is_empty() else override.replace("{map}", game.active_map_id).replace("{seed}", str(game.world_seed))
	if not override.is_empty() and not override.contains("{seed}"):
		save_path += "." + str(game.world_seed)
	var catalog = JSON.parse_string(FileAccess.get_file_as_string("res://data/rpg/world_stories.json"))
	var saved: Dictionary = {}
	if FileAccess.file_exists(save_path):
		var stored = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		if not stored is Dictionary or stored.get("schema_version") != 1 or int(stored.get("seed", -1)) != game.world_seed or stored.get("map_id") != game.active_map_id or not stored.get("state") is Dictionary:
			push_error("Road journal is invalid; existing progress was not overwritten")
			return false
		saved = stored.state
	model = Journal.new()
	enabled = model.configure(catalog, catalog.locations, saved)
	return enabled

func spawn_records() -> void:
	if not enabled:
		return
	for record in model.anchors:
		var marker := Stone.new()
		marker.name = "RoadRecord_" + str(record.id)
		marker.director = self
		marker.record_id = str(record.id)
		marker.record_label = str(record.title)
		var x := float(record.position[0])
		var z := float(record.position[2])
		marker.position = Vector3(x, game.call("surface_height_at", x, z), z)
		game.add_child(marker)
		markers.append(marker)

func resident(id: String) -> Dictionary:
	return model.catalog.residents.get(id, model.catalog.default_resident).duplicate(true) if enabled else {}

func converse(id: String, topic: String) -> Array:
	if not enabled:
		return ["The resident has nothing more to say."]
	var before: Dictionary = model.snapshot()
	var lines: Array = model.talk(id, topic)
	if not save_now():
		model.configure(model.catalog, model.anchors, before)
		return ["Could not record this conversation. Your previous progress is retained."]
	return lines

func open_record(id: String) -> void:
	if not enabled or model.entry(id).is_empty():
		return
	var before: Dictionary = model.snapshot()
	var text: String = model.read_record(id)
	if not save_now():
		model.configure(model.catalog, model.anchors, before)
		text = "Could not record this page. Your previous progress is retained."
	game.hud.call("show_rpg_text", str(model.entry(id).title), text + "\n\n" + model.objective(game.player.global_position), "")

func save_now() -> bool:
	if not enabled:
		return false
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"schema_version": 1, "seed": game.world_seed, "map_id": game.active_map_id, "state": model.snapshot()}, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	return error == OK and DirAccess.rename_absolute(ProjectSettings.globalize_path(save_path + ".tmp"), ProjectSettings.globalize_path(save_path)) == OK
