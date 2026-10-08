extends SceneTree
func _initialize() -> void:
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_lantern_render_{seed}.json")
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_lantern_render_story.json")
	call_deferred("_run")

func _brightness(img: Image) -> float:
	var total := 0.0
	var n := 0
	for y in range(190, 460, 30):
		for x in range(340, 840, 30):
			var c: Color = img.get_pixel(x, y)
			total += c.r + c.g + c.b
			n += 3
	return total / float(n)

func _run() -> void:
	var world = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	var player = world.get("player")
	var camera: Camera3D = player.get("camera")
	for _i in range(110):
		await physics_frame
	player.set_physics_process(false)
	player.global_position = Vector3(314.0, 8.0, 282.0)
	player.rotation = Vector3.ZERO
	player.get("pivot").rotation = Vector3.ZERO
	camera.look_at(Vector3(330.0, 9.0, 282.0))
	for _i in range(160):
		await physics_frame
	if DisplayServer.get_name() == "headless":
		printerr("Must render with PC OpenGL window")
		quit(2)
		return
	await RenderingServer.frame_post_draw
	var off_image := root.get_viewport().get_texture().get_image()
	off_image.save_png("res://dist/verification/lantern-quarry-off.png")
	var dark := _brightness(off_image)
	player.call("select_hotbar_slot", 7)
	for _i in range(15):
		await physics_frame
	await RenderingServer.frame_post_draw
	var on_image := root.get_viewport().get_texture().get_image()
	on_image.save_png("res://dist/verification/lantern-quarry-on.png")
	var lit := _brightness(on_image)
	print("LANTERN_RENDER off_mean=", dark, " on_mean=", lit, " delta=", lit-dark)
	quit(0 if lit > dark + 0.012 else 1)
