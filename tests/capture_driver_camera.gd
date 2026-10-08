extends SceneTree

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	var world := packed.instantiate()
	root.add_child(world)
	for _i in range(36):
		await physics_frame

	var player := world.get_node("Player") as CharacterBody3D
	var buggy := world.get_node("SandboxBuggy") as VehicleBody3D
	player.call("enter_vehicle", buggy)
	for _i in range(4):
		await process_frame

	var output_dir := ProjectSettings.globalize_path("res://dist/verification")
	DirAccess.make_dir_recursive_absolute(output_dir)
	var output_path := output_dir.path_join("driver-camera.png")
	var result := root.get_viewport().get_texture().get_image().save_png(output_path)
	if result == OK:
		print("[PASS] driver camera frame captured: ", output_path)
		quit(0)
	else:
		print("[FAIL] driver camera frame capture error: ", result)
		quit(1)
