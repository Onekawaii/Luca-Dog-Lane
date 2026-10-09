extends SceneTree
# Isolated runtime falsifier for the new player inventory/crafting UI.
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_verify")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _verify() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	var game := packed.instantiate()
	root.add_child(game)
	for _i in range(5):
		await process_frame
	var hud = game.get("hud")
	var slice = game.get("terrain_slice")
	_check(game.get("spiral_world") != null, "Spiral director must compile and instantiate")
	_check(hud != null and slice != null, "world HUD and terrain must boot")
	if hud == null or slice == null:
		quit(1)
		return
	var panel = hud.get("inventory_panel")
	_check(panel != null, "inventory panel exists")
	_check(not panel.visible, "inventory panel starts collapsed")
	hud.call("_toggle_inventory_menu")
	_check(panel.visible, "inventory button opens panel")
	_check(hud.get("inventory_button").visible, "inventory button is player-visible")
	var inv: Node = slice.get("inventory")
	_check(inv != null, "inventory service exists")
	_check(game.call("get_item_catalog_for_ui").has("grass_block"), "grass block in catalog")
	var before_stone: int = inv.call("count_item", "stone")
	var before_brick: int = inv.call("count_item", "stone_brick")
	inv.call("add_item", "stone", 7)
	var craft_message: String = game.call("terrain_craft_recipe", "stone_brick")
	_check(craft_message.contains("CRAFTED"), "craft succeeds")
	_check(inv.call("count_item", "stone") == before_stone + 4, "craft consumes 3 stone")
	_check(inv.call("count_item", "stone_brick") == before_brick + 1, "craft grants brick")
	inv.call("add_item", "grass_block", 2)
	_check(game.call("select_build_material", "grass_block"), "grass selectable")
	_check(slice.get("selected_place_item") == "grass_block", "selected material reaches terrain")
	_check(game.get("player").call("_current_tool_id") == "place", "selection equips place tool")
	panel.call("refresh")
	var quickbar = hud.get("quickbar")
	_check(quickbar != null and quickbar.get("buttons").size() == 9, "nine-slot assignable hotbar renders")
	_check(game.get("player").call("_current_tool_id") == "place", "material selection equips place tool")
	_check(panel.get("summary_label").text.contains("TYPES ON HAND"), "satchel counts real stock only")
	_check(hud.get("build_panel") != null and hud.get("loadout_panel") != null, "catalog and loadout are separate menus")
	_check(not game.call("select_build_material", "trail_beacon"), "unsupported placement rejected")
	hud.call("_toggle_inventory_menu")
	_check(not panel.visible, "inventory closes")
	hud.call("_toggle_map_menu")
	_check(hud.get("map_panel").visible, "map opens from gameplay HUD")
	await process_frame
	await process_frame
	var chart = hud.get("map_chart")
	_check(chart != null, "topographic chart exists")
	if chart != null:
		_check(chart.get("cached_heights").size() == 784, "topographic map samples 28x28 actual terrain")
	hud.call("_toggle_map_menu")
	if failures.is_empty():
		print("[PASS] SPIRAL INVENTORY // UI, catalog, recipe, material selection")
		quit(0)
	else:
		print("[FAIL] SPIRAL INVENTORY // %d failures" % failures.size())
		quit(1)
