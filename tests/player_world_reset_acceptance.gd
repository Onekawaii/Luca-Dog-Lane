extends SceneTree
# Uses per-seed test namespaces; must not mutate normal user:// saves.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, detail: String) -> void:
	if not condition:
		failures.append(detail)
		printerr("FAIL RESET " + detail)

func _verify() -> void:
	var original_path := "user://v020_world_voxels_6060.json"
	var original_bytes := PackedByteArray()
	var original_present := FileAccess.file_exists(original_path)
	if original_present:
		original_bytes = FileAccess.get_file_as_bytes(original_path)
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	for _frame in range(4):
		await process_frame
	var slice = game.get("terrain_slice")
	var persistence: Node = slice.get("persistence")
	var progress: Node = game.get("spiral_world")
	var test_terrain := str(persistence.get("save_path"))
	var test_spiral := str(progress.call("state_save_path"))
	_check(test_terrain.contains("repair_reset_voxels"), "test save path isolated")
	_check(test_spiral.contains("repair_reset_spiral"), "test story path isolated")
	if not failures.is_empty():
		quit(1)
		return
	persistence.call("set_inventory_snapshot", {"stone": 19, "stone_brick": 2, "grass_block": 8})
	_check(bool(persistence.call("save_now")), "seed state saved")
	progress.set("affection", 11.0)
	progress.call("_save_state")
	_check(FileAccess.file_exists(test_terrain), "voxel temp state exists")
	_check(FileAccess.file_exists(test_spiral), "story temp state exists")
	var result: String = game.call("reset_field", false)
	_check(result.begins_with("NEW FIELD"), "reset reports success")
	_check(not FileAccess.file_exists(test_terrain), "voxel temp state removed")
	_check(not FileAccess.file_exists(test_spiral), "story temp state removed")
	_check(FileAccess.file_exists(original_path) == original_present, "original save existence unchanged")
	if original_present:
		_check(FileAccess.get_file_as_bytes(original_path) == original_bytes, "original save content unchanged")
	var parent := DirAccess.open("user://")
	var voxel_backups := 0
	var story_backups := 0
	if parent != null:
		for filename in parent.get_files():
			if filename.begins_with(test_terrain.get_file() + ".pre-reset-"):
				voxel_backups += 1
			if filename.begins_with(test_spiral.get_file() + ".pre-reset-"):
				story_backups += 1
	_check(voxel_backups > 0 and story_backups > 0, "both backups written")
	game.queue_free()
	await process_frame
	await process_frame
	var new_field = load("res://scenes/Main.tscn").instantiate()
	root.add_child(new_field)
	await process_frame
	await process_frame
	var fresh_stock: Node = new_field.get("terrain_slice").get("inventory")
	_check(fresh_stock.call("count_item", "stone") == 0, "new field inventory starts empty")
	_check(new_field.get("spiral_world").get("affection") == 0.0, "new field resets Spiral progression")
	if failures.is_empty():
		print("[PASS] SPIRAL RESET // backup before clear, original save untouched")
		quit(0)
	else:
		print("[FAIL] SPIRAL RESET // %d problems" % failures.size())
		quit(1)
