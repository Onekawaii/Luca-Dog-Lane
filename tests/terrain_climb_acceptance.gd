extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://scenes/Main.tscn").instantiate()
	root.add_child(game)
	var player: CharacterBody3D = game.get("player")
	var slice: Node = game.get("terrain_slice")
	player.global_position = Vector3(310.0, 3.0, 329.0)
	player.velocity = Vector3.ZERO

	var tool
	for i in range(600):
		await physics_frame
		tool = slice.call("get_voxel_tool_for_test")
		if tool != null and bool(tool.call("is_area_editable", AABB(Vector3(304, -1, 294), Vector3(12, 40, 38)))):
			break
	if tool == null:
		print("[FAIL] mountain traversal corridor never became editable")
		quit(1)
		return

	var start := player.global_position
	var max_y := start.y
	var min_z := start.z
	player.call("set_touch_move", Vector2(0.0, -1.0))
	for i in range(900):
		if i % 24 == 0:
			player.call("request_jump")
		await physics_frame
		max_y = maxf(max_y, player.global_position.y)
		min_z = minf(min_z, player.global_position.z)
		if player.global_position.z <= 300.0 and player.global_position.y >= 10.0:
			break
	player.call("set_touch_move", Vector2.ZERO)

	print("CLIMB_START=", start)
	print("CLIMB_END=", player.global_position)
	print("CLIMB_MAX_Y=", max_y, " MIN_Z=", min_z, " NOCLIP=", player.get("noclip"))

	var climbed := min_z <= 305.0 and max_y >= 10.0 and not bool(player.get("noclip"))
	var store: Node = slice.call("get_persistence_for_test")
	store.call("clear_save")
	game.queue_free()
	await process_frame

	if climbed:
		print("[ALL ENG-003 CLIMB GATES PASSED]")
		quit(0)
	else:
		print("[FAIL] voxel mountain is not meaningfully climbable")
		quit(1)
