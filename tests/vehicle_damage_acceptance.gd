extends SceneTree

func _initialize() -> void:
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_vehicle_%d.json" % Time.get_ticks_usec())
	OS.set_environment("LUCA_V013_SLICE_SAVE_PATH", "user://qa_vehicle_terrain_%d.json" % Time.get_ticks_usec())
	call_deferred("_run")

func _run() -> void:
	var world := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in range(180):
		await physics_frame
	var car := world.get_node("SandboxBuggy") as VehicleBody3D
	var wall := StaticBody3D.new()
	wall.position = Vector3(13, 1.5, 0)
	wall.collision_layer = 1
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(8, 3, 0.5)
	collider.shape = box
	wall.add_child(collider)
	world.add_child(wall)
	var before: float = car.get("health")
	car.call("set_driver_active", true)
	car.call("set_drive_input", Vector2(0, -1))
	for i in range(200):
		await physics_frame
	car.call("set_drive_input", Vector2.ZERO)
	var after: float = car.get("health")
	var passed: bool = after < before and car.get("damage_feedback").get("scars").get_child_count() > 0
	print("[PASS] " if passed else "[FAIL] ", "physical wall collision produces vehicle damage health=", before, " -> ", after)
	world.queue_free()
	await process_frame
	quit(0 if passed else 1)
