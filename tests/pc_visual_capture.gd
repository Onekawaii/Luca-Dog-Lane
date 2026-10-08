extends SceneTree
# Non-headless visual receipt for screenshot review of the near/far terrain bridge.
func _initialize() -> void:
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://pc_visual_camera_{seed}.json")
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://pc_visual_camera_story.json")
	call_deferred("_run")

func _run() -> void:
	var game = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	for _i in range(125):
		await physics_frame
	var player = game.get("player")
	player.set_physics_process(false)
	var x := -340.0
	var z := -350.0
	player.global_position = Vector3(x, float(game.call("_surface_height", x, z)) + 3.0, z)
	var camera: Camera3D = player.get("camera")
	camera.look_at(Vector3(-397.0, 31.0, -358.0), Vector3.UP)
	for _i in range(12):
		await process_frame
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var image = root.get_viewport().get_texture().get_image()
		var result: Error = image.save_png("res://dist/verification/pc-terrain-edits-only.png")
		print("PC_TERRAIN_RENDER_CAPTURE=", result)
	else:
		print("PC_TERRAIN_RENDER_CAPTURE=SKIPPED_HEADLESS")
	quit(0)
