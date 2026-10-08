extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	OS.set_environment("SPIRAL_STATE_SAVE_PATH", "user://qa_presentation_%d.json" % Time.get_ticks_usec())
	call_deferred("_run")

func check(value: bool, label: String) -> void:
	print("[PASS] " if value else "[FAIL] ", label)
	if not value:
		failures.append(label)

func _run() -> void:
	var world := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
	root.add_child(world)
	for i in range(90):
		await physics_frame
	var player := world.get_node("Player")
	player.set_process_unhandled_input(false)
	var tool: Node3D = player.get("equipped_tool")
	var icons: Dictionary = {}
	for i in range(player.get("tool_ids").size()):
		player.set("tool_index", i)
		player.call("_sync_tool_label")
		var id: String = player.call("_current_tool_id")
		check(tool.get_child_count() >= 2, "held model for " + id)
		var texture: ImageTexture = tool.get("icon")
		var digest := texture.get_image().get_data().hex_encode().sha256_text()
		check(not icons.has(digest), "distinct icon for " + id)
		icons[digest] = true
	var npc := get_first_node_in_group("npc")
	npc.set_physics_process(false)
	npc.global_position = Vector3(0, 0, 0)
	player.global_position = Vector3(0, 0, -3.2)
	player.rotation.y = PI
	player.get("pivot").rotation.x = -0.08
	player.set("tool_index", player.get("tool_ids").find("field_hammer"))
	player.call("_sync_tool_label")
	await physics_frame
	var old_health: float = npc.get("health")
	player.call("use_tool")
	check(npc.get("health") == old_health - 25.0, "hammer decreases NPC health")
	var feedback: Node3D = npc.get("damage_feedback")
	check(feedback.get("timer") > 0.0 and feedback.get("scars").get_child_count() == 1, "NPC hit flash and persistent mark")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://dist/verification/presentation-npc-damage.png")
	var buggy := world.get_node("SandboxBuggy")
	buggy.freeze = true
	buggy.global_position = Vector3(13, 0.18, 10)
	buggy.global_rotation = Vector3.ZERO
	player.global_position = Vector3(13, 0.1, 6.0)
	player.get("pivot").rotation.x = -0.23
	await physics_frame
	player.call("use_tool")
	check(buggy.get("health") == 175.0, "hammer decreases buggy health")
	check(player.get("riding") == null, "hammer USE damages car instead of entering")
	check(buggy.get("damage_feedback").get("scars").get_child_count() == 1, "buggy persistent damage mark")
	var hud: CanvasLayer = player.get("hud")
	hud.set("mobile_ui", true)
	player.call("enter_vehicle", buggy)
	check(hud.get("move_base").visible, "mobile joystick remains visible in vehicle")
	player.call("set_touch_move", Vector2(0.5, -0.8))
	player.call("_process_vehicle")
	check(buggy.get("drive_input").length() > 0.8, "mobile movement reaches steering/throttle")
	player.call("exit_vehicle")
	player.call("set_touch_move", Vector2.ZERO)
	hud.set("mobile_ui", false)
	hud.call("_apply_mode_visibility")
	player.global_position = Vector3(13, 0.1, 6.0)
	player.rotation.y = PI
	player.get("pivot").rotation.x = -0.23
	if DisplayServer.get_name() != "headless":
		for i in range(45):
			await physics_frame
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://dist/verification/presentation-car-damage.png")
	for i in range(8):
		buggy.call("take_damage", 25.0)
	check(buggy.get("health") == 0.0, "buggy health clamps at zero")
	buggy.call("set_driver_active", true)
	buggy.call("set_drive_input", Vector2(0, -1))
	await physics_frame
	await physics_frame
	check(buggy.engine_force == 0.0, "destroyed buggy cannot accelerate")
	var director = world.get("spiral_world")
	var sites: Dictionary = director.get("site_nodes")
	check(sites["witnessing"].has_node("SpiralStone"), "continuous spiral mesh integrated")
	check(sites["tabbytulhu"].has_node("Tail_00") and sites["tabbytulhu"].has_node("Nose"), "cat anatomy and continuous tail integrated")
	if not DisplayServer.get_name() == "headless":
		buggy.call("set_driver_active", false)
		player.set("tool_index", player.get("tool_ids").find("field_hammer"))
		player.call("_sync_tool_label")
		player.global_position = sites["tabbytulhu"].global_position + Vector3(0, 0.3, -5)
		player.rotation.y = PI
		player.get("pivot").rotation.x = -0.04
		for i in range(180):
			await physics_frame
		player.get("camera").look_at(sites["tabbytulhu"].global_position + Vector3.UP * 0.95)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://dist/verification/presentation-cat.png")
		player.global_position = sites["witnessing"].global_position + Vector3(0, 1, -18)
		player.get("pivot").rotation.x = 0.12
		for i in range(180):
			await physics_frame
		player.get("camera").look_at(sites["witnessing"].global_position + Vector3.UP * 4.5)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://dist/verification/presentation-spiral.png")
	world.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
