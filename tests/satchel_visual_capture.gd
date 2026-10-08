extends SceneTree
func _initialize() -> void:
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_satchel_%d_{seed}.json" % Time.get_ticks_usec())
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_satchel_%d_story.json" % Time.get_ticks_usec())
	call_deferred("_run")

func _run() -> void:
	var game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i in range(30):
		await physics_frame
	var hud = game.get("hud")
	var inventory = game.get("terrain_slice").get("inventory")
	inventory.call("add_item", "stone", 7)
	inventory.call("add_item", "grass_block", 4)
	hud.call("_toggle_inventory_menu")
	for _i in range(3):
		await process_frame
	if DisplayServer.get_name() == "headless":
		quit(2)
		return
	await RenderingServer.frame_post_draw
	var err := root.get_viewport().get_texture().get_image().save_png("res://dist/verification/field-satchel-pc.png")
	print("SATCHEL_CAPTURE_RC=", err)
	quit(0 if err == OK else 1)
