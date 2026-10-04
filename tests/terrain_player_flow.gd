extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed: PackedScene = load("res://scenes/Main.tscn")
	var game = packed.instantiate()
	root.add_child(game)

	var slice: Node = game.get("terrain_slice")
	var player: CharacterBody3D = game.get("player")
	_check(slice != null, "real game owns terrain slice")
	_check(player != null, "real game owns player")
	if slice == null or player == null:
		_finish(game, slice)
		return

	player.global_position = Vector3(310.5, 40.0, 282.5)
	player.velocity = Vector3.ZERO
	for i in range(4):
		await physics_frame

	var tool
	for i in range(600):
		await process_frame
		tool = slice.call("get_voxel_tool_for_test")
		if tool != null and bool(tool.call("is_area_editable", AABB(Vector3(306, -1, 278), Vector3(10, 48, 10)))):
			break
	_check(tool != null, "real game terrain streams")
	if tool == null:
		_finish(game, slice)
		return

	tool.set("channel", 0)
	player.process_mode = Node.PROCESS_MODE_DISABLED

	var pivot: Node3D = player.get_node("ViewPivot")
	var camera: Camera3D = pivot.get_node("Camera")
	camera.global_transform = Transform3D(
		Basis(Vector3.RIGHT, -PI * 0.5),
		Vector3(310.5, 40.0, 282.5)
	)
	var direction := -camera.global_transform.basis.z
	var expected_hit = tool.call("raycast", camera.global_position, direction, 64.0)
	_check(expected_hit != null, "player camera aims at voxel terrain")
	if expected_hit == null:
		_finish(game, slice)
		return

	var target: Vector3i = expected_hit.call("get_position")
	player.set("tool_index", 4)
	player.call("use_tool")
	_check(int(tool.call("get_voxel", target)) == 0, "Player MINE mode reaches terrain mutation")

	var inventory: Node = slice.call("get_inventory_for_test")
	inventory.call("add_item", "stone", 3)
	player.set("tool_index", 6)
	player.call("use_tool")
	_check(int(inventory.call("count_item", "stone_brick")) == 1, "Player CRAFT mode reaches inventory recipe")

	player.set("tool_index", 5)
	player.call("use_tool")
	_check(int(tool.call("get_voxel", target)) == 3, "Player PLACE mode restores mined cell with brick")
	_check(int(inventory.call("count_item", "stone_brick")) == 0, "Player PLACE mode consumes brick")

	var hud: CanvasLayer = game.get("hud")
	_check(hud != null, "real game HUD remains active")
	if hud != null:
		var status: Label = hud.get("status_label")
		_check(status != null and status.text.contains("PLACED"), "HUD reports terrain action result")

	_finish(game, slice)

func _finish(game: Node, slice: Node) -> void:
	if slice != null:
		var store: Node = slice.call("get_persistence_for_test")
		if store != null:
			store.call("clear_save")
	if game != null and is_instance_valid(game):
		game.queue_free()
	await process_frame
	if failures.is_empty():
		print("[ALL ENG-003 PLAYER FLOW GATES PASSED]")
		quit(0)
	else:
		print("[ENG-003 PLAYER FLOW FAILURES] ", failures.size())
		quit(1)

func _check(condition: bool, label: String) -> void:
	if condition:
		print("[PASS] ", label)
	else:
		failures.append(label)
		print("[FAIL] ", label)
