extends SceneTree
# PC playtest regression: terrain LOD cutout and selected-material presentation.
var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://pc_visual_probe_{seed}.json")
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://pc_visual_probe_story.json")
	call_deferred("_verify")

func _check(ok: bool, title: String) -> void:
	if not ok:
		failures.append(title)
		printerr("[FAIL] " + title)
	else:
		print("[PASS] " + title)

func _verify() -> void:
	var game := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i in range(4):
		await process_frame
	var terrain: MacroTerrain = game.get("macro_terrain")
	var player = game.get("player")
	var inventory_panel = game.get("hud").get("inventory_panel")
	_check(terrain != null and terrain.get("terrain_body") == null, "smooth macro presentation disabled in voxel world")
	_check(game.get_node_or_null("MainRoadNS") == null and game.get_node_or_null("SkateFloor") == null, "ground skins never cover destructive road voxels")
	_check(game.get("terrain_slice").get("voxel_tool") != null, "all terrain visuals and collision share VoxelTool")
	game.call("select_build_material", "grass_block")
	var tool = player.get("equipped_tool")
	_check(tool.has_node("Place_grass_block"), "held place model reflects selected grass block")
	_check(not tool.has_node("Place_stone_brick"), "held place model does not lie about block type")
	_check(game.get("hud").get("equipped_label").text.contains("GRASS BLOCK"), "HUD tool label names selected grass material")
	game.call("select_build_material", "stone")
	_check(tool.has_node("Place_stone"), "held place model reflects selected stone")
	_check(not tool.has_node("Place_grass_block"), "stale grass model removed")
	inventory_panel.call("refresh")
	var found_false_hammer := false
	for row in inventory_panel.get("stock_list").get_children():
		for node in row.get_children():
			if node is Label and node.text.contains("FIELD HAMMER"):
				found_false_hammer = true
	_check(not found_false_hammer, "owned permanent tool is not shown as a zero-count resource")
	var noclip_before: bool = player.get("noclip")
	var hotkey := InputEventKey.new()
	hotkey.keycode = KEY_V
	hotkey.pressed = true
	player.call("_unhandled_input", hotkey)
	_check(bool(player.get("noclip")) != noclip_before, "V toggles PC noclip without developer UI")
	player.call("toggle_noclip")
	_check(terrain.get("terrain_body") == null, "no legacy terrain mesh can reappear after edits")
	if failures.is_empty():
		print("[ALL PC PLAYTEST PRESENTATION GATES PASSED]")
		quit(0)
	else:
		print("[PC PLAYTEST PRESENTATION FAILURES] %d" % failures.size())
		quit(1)
