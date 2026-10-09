extends SceneTree
# End-to-end operator controls: physical light, keyboard/touch slots, inventory UI.
var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_lantern_%d_{seed}.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_lantern_story_%d.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_LOADOUT_SAVE_PATH", "user://qa_lantern_loadout_%d.json" % Time.get_ticks_usec())
	call_deferred("_verify")

func check(truth: bool, description: String) -> void:
	if truth:
		print("[PASS] " + description)
	else:
		failures.append(description)
		printerr("[FAIL] " + description)

func _verify() -> void:
	var world = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for _i in range(9):
		await process_frame
	var player = world.get("player")
	var hud = world.get("hud")
	var quickbar = hud.get("quickbar")
	var inventory_panel = hud.get("inventory_panel")
	var inventory = world.get("terrain_slice").get("inventory")
	check(quickbar != null and quickbar.get("buttons").size() == 9, "nine assignable hotbar slots")
	check(quickbar.get("buttons")[8].text.begins_with("9 "), "slot nine uses 9 shortcut")
	check(not player.get("lantern_enabled"), "lantern defaults off, respecting darkness")
	var event := InputEventKey.new()
	event.keycode = KEY_5
	event.pressed = true
	player.call("_unhandled_input", event)
	check(player.get("hotbar_index") == 4 and world.call("get_selected_build_material") == "grass_block", "keyboard 5 selects grass hotbar")
	check(player.call("_current_tool_id") == "place", "hotbar material equips placement tool")
	event.keycode = KEY_6
	player.call("_unhandled_input", event)
	check(player.get("hotbar_index") == 5 and world.call("get_selected_build_material") == "stone_brick", "keyboard 6 selects brick without inventory controls")
	quickbar.get("buttons")[3].pressed.emit()
	check(world.call("get_selected_build_material") == "stone", "tapping slot 4 selects stone through real button")
	var light: OmniLight3D = player.get("lantern_light")
	quickbar.get("buttons")[7].pressed.emit()
	check(player.call("_current_tool_id") == "lantern" and light.visible, "tapping slot 8 lights equipped lantern")
	check(light is OmniLight3D and light.omni_range >= 14.0 and light.light_energy > 1.0, "lantern is real dynamic omni light with underground range")
	quickbar.get("buttons")[2].pressed.emit()
	check(light.visible and player.call("_current_tool_id") == "mine", "lantern stays lit when returning to mine")
	quickbar.get("buttons")[7].pressed.emit()
	check(player.call("_current_tool_id") == "lantern" and light.visible, "selecting lantern from another item does not unexpectedly turn it off")
	quickbar.get("buttons")[7].pressed.emit()
	check(not light.visible and not player.get("lantern_enabled"), "tapping selected lantern toggles off")
	event.keycode = KEY_L
	player.call("_unhandled_input", event)
	check(light.visible, "L keyboard shortcut toggles lamp directly")
	player.call("select_tool", "field_hammer")
	player.call("cycle_tool")
	check(player.call("_current_tool_id") == "lantern" and player.get("hotbar_index") == 7, "legacy Q cycle synchronizes highlighted hotbar slot")
	player.call("use_tool")
	check(not light.visible, "USE with equipped lantern toggles it off")
	inventory.call("add_item", "stone", 5)
	quickbar.call("refresh", true)
	check(quickbar.get("buttons")[3].text.contains("x5"), "hotbar displays authoritative stone count")
	hud.call("_toggle_inventory_menu")
	check(inventory_panel.visible, "satchel opens")
	var has_place_button := false
	for row in inventory_panel.get("stock_list").get_children():
		for descendant in row.get_children():
			if descendant is Button and descendant.text == "PLACE":
				has_place_button = true
	check(not has_place_button, "satchel no longer duplicates PLACE/SELECTED controls")
	check(inventory_panel.get("summary_label").text.contains("1 TYPES ON HAND"), "satchel counts stocked categories only")
	check(world.get("macro_terrain").get("terrain_body") == null, "no visual mesh hides voxel road destruction")
	check(world.get("terrain_slice").get("voxel_tool") != null, "actual voxel faces and collision are authoritative")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("[ALL LANTERN + HOTBAR + TERRAIN VISIBILITY GATES PASSED]")
		quit(0)
	else:
		printerr("[LANTERN/HOTBAR GATES FAILED] " + str(failures))
		quit(1)
