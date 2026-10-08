extends Node
# Runs identically against editor/source and the packed exported game.
var world: Node
var failures: Array[String] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().create_timer(90.0, true, false, true).timeout.connect(func():
		printerr("[FAIL] PC probe watchdog timeout")
		get_tree().quit(1))
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	print("[PASS] " if ok else "[FAIL] ", label)
	if not ok:
		failures.append(label)

func key(code: int, pressed := true, echo := false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	get_viewport().push_input(event, true)
	if pressed:
		event = event.duplicate()
		event.pressed = false
		get_viewport().push_input(event, true)

func click(at: Vector2) -> void:
	for pressed in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = at
		event.global_position = at
		get_viewport().push_input(event, true)

func touch(at: Vector2, pressed: bool, index := 3) -> void:
	var event := InputEventScreenTouch.new()
	event.position = at
	event.index = index
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func button_named(menu: Node, label: String) -> Button:
	for child in menu.column.get_children():
		if child is Button and child.text == label:
			return child
	return null

func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var folder := OS.get_environment("SPIRAL_PC_CAPTURE_DIR")
	if folder.is_empty():
		folder = ProjectSettings.globalize_path("res://dist/pc-review-20261008")
	DirAccess.make_dir_recursive_absolute(folder)
	check(get_viewport().get_texture().get_image().save_png(folder.path_join(label + ".png")) == OK, "rendered capture " + label)

func run() -> void:
	for i in range(180):
		await get_tree().physics_frame
	var player = world.player
	var hud = world.hud
	var menu = world.session_menu
	var npc = get_tree().get_first_node_in_group("npc")
	npc.set_physics_process(false)
	npc.global_position = Vector3.ZERO
	player.set_physics_process(false)
	player.global_position = Vector3(0, 0, -3.2)
	player.rotation.y = PI
	player.pivot.rotation.x = -0.08
	player.select_tool("field_hammer")
	await get_tree().physics_frame
	var before: float = npc.health
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	click(get_viewport().get_visible_rect().size * 0.5)
	check(npc.health == before - 25.0, "actual LMB dispatch damages aimed NPC exactly once")
	key(KEY_E, true, true)
	check(npc.health == before - 25.0, "E keyboard echo cannot spam tool use")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	click(Vector2(900, 400))
	check(npc.health == before - 25.0 and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "uncaptured click only recaptures")
	key(KEY_I)
	await get_tree().process_frame
	check(hud.inventory_panel.visible and player.gameplay_blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "inventory owns pointer and blocks gameplay")
	var old_yaw: float = player.yaw
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120, 80)
	get_viewport().push_input(motion, true)
	key(KEY_7)
	click(Vector2(950, 400))
	check(npc.health == before - 25.0 and player.yaw == old_yaw, "modal keys/look/outside click cannot act on world")
	await capture("inventory")
	key(KEY_ESCAPE)
	check(not hud.has_modal() and not menu.is_open() and not player.gameplay_blocked, "Escape closes inventory before opening pause")
	var buggy = world.get_node("SandboxBuggy")
	player.enter_vehicle(buggy)
	check(hud.view_button.visible and hud.use_button.visible, "PC vehicle VIEW and EXIT are visible")
	for i in range(4):
		key(KEY_F5)
		check(buggy.camera_mode == (i + 1) % 4 and get_viewport().get_camera_3d() == buggy.camera_nodes[(i + 1) % 4], "F5 current camera mode " + str((i + 1) % 4))
	click(Vector2(640, 360))
	check(player.riding == buggy, "driving LMB does not exit vehicle")
	key(KEY_R)
	check(buggy.camera_mode == 1, "R retains alternate vehicle view shortcut")
	await capture("vehicle-view")
	buggy.set_drive_input(Vector2(0, -1))
	npc.set_physics_process(true)
	key(KEY_ESCAPE)
	await get_tree().process_frame
	var car_position: Vector3 = buggy.global_position
	var npc_position: Vector3 = npc.global_position
	var elapsed: float = world.spiral_world.guidance_timer
	for i in range(30):
		await get_tree().process_frame
	check(get_tree().paused and player.gameplay_blocked and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Escape opens paused session menu")
	check(buggy.global_position == car_position and npc.global_position == npc_position and world.spiral_world.guidance_timer == elapsed, "pause freezes car, NPC and encounter simulation")
	check(buggy.drive_input == Vector2.ZERO, "opening pause clears throttle")
	await capture("pause-menu")
	click(button_named(menu, "Options...").get_global_rect().get_center())
	await get_tree().process_frame
	check(menu.screen == "options", "actual GUI click opens options")
	menu.sensitivity_slider.value = 0.005
	menu.volume_slider.value = 0.5
	check(absf(player.look_sensitivity - menu.sensitivity_slider.value) < 0.00001, "sensitivity option updates authoritative look input")
	check(absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - 0.5) < 0.02, "volume option updates audio bus")
	await capture("options-menu")
	key(KEY_ESCAPE)
	check(menu.screen == "pause", "Escape from options returns to pause")
	await get_tree().process_frame
	await get_tree().process_frame
	click(button_named(menu, "Back to Game").get_global_rect().get_center())
	await get_tree().process_frame
	check(not get_tree().paused and not menu.is_open() and player.riding == buggy and buggy.camera_mode == 1, "GUI resume preserves car/current view without leaked click")
	var old_orbit: float = buggy.chase_arm.rotation_degrees.y
	player.add_look_delta(Vector2(10, 0))
	check(absf(buggy.chase_arm.rotation_degrees.y - (old_orbit - 1.2 * player.look_sensitivity / 0.0032)) < 0.001, "options sensitivity reaches actual chase camera orbit")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	click(hud.view_button.get_global_rect().get_center())
	check(buggy.camera_mode == 2, "PC VIEW button actually cycles camera")
	click(hud.use_button.get_global_rect().get_center())
	check(player.riding == null and player.camera.current, "PC EXIT button restores player camera")
	key(KEY_ESCAPE)
	await get_tree().process_frame
	var valid_path: String = world.terrain_slice.persistence.save_path
	world.terrain_slice.persistence.save_path = "user://nonexistent_pc_probe_%d/state.json" % Time.get_ticks_usec()
	print("[EXPECTED SAVE FAILURE PROBE BEGIN]")
	click(button_named(menu, "Save and Return to Title").get_global_rect().get_center())
	check(menu.screen == "pause" and menu.status.text.contains("Save failed"), "failed save prevents return to title")
	print("[EXPECTED SAVE FAILURE PROBE END]")
	world.terrain_slice.persistence.save_path = valid_path
	world.terrain_slice.inventory.add_item("stone", 5)
	click(button_named(menu, "Save and Return to Title").get_global_rect().get_center())
	await get_tree().process_frame
	check(menu.screen == "title" and get_tree().paused, "save returns to title without destroying current world")
	check(FileAccess.file_exists(world.terrain_slice.persistence.save_path) and FileAccess.file_exists(world.spiral_world.state_save_path()), "title save flushes both existing persistence owners")
	var payload: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(valid_path))
	check(int(payload.inventory.get("stone", 0)) == 5, "title save contains current authoritative inventory payload")
	await capture("title-menu")
	menu.resume()
	# Drop conservation stress: disable player collection, spread drops then overflow.
	player.global_position = Vector3(100, 80, 100)
	var inventory = world.terrain_slice.inventory
	var count_before: int = inventory.count_item("stone")
	for i in range(80):
		world.terrain_slice._spawn_resource_pickup(Vector3i(i * 3, 8, 20), "stone", 1)
	var active := get_tree().get_nodes_in_group("terrain_pickup")
	var total: int = inventory.count_item("stone") - count_before
	for drop in active:
		total += drop.amount
	check(active.size() <= 64 and total == 80, "80 mined resources bounded to 64 bodies with exact count conservation")
	check(active[0].get_child(0).mesh is BoxMesh, "drops use compact textured block models")
	var lost_drop = active[0]
	var lost_amount: int = lost_drop.amount
	var previous_count: int = inventory.count_item("stone")
	lost_drop.global_position.y = -21.0
	lost_drop._physics_process(0.01)
	check(inventory.count_item("stone") == previous_count + lost_amount and lost_drop.is_queued_for_deletion(), "escaped drop credits resources instead of deleting them")
	hud.mobile_ui = true
	hud._apply_mode_visibility()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.emulate_mouse_from_touch = true
	touch(hud.inventory_button.get_global_rect().get_center(), true)
	touch(hud.inventory_button.get_global_rect().get_center(), false)
	await get_tree().process_frame
	await get_tree().process_frame
	check(hud.inventory_panel.visible, "actual touch opens inventory GUI")
	var return_button: Button = hud.inventory_panel.get_child(hud.inventory_panel.get_child_count() - 1)
	touch(return_button.get_global_rect().get_center(), true)
	touch(return_button.get_global_rect().get_center(), false)
	await get_tree().process_frame
	check(not hud.inventory_panel.visible and not player.gameplay_blocked, "modal touch reaches GUI return button")
	player.enter_vehicle(buggy)
	touch(hud.move_center + Vector2(30, -55), true, 0)
	player._process_vehicle()
	check(hud.move_base.visible and buggy.drive_input.length() > 0.8 and hud.view_button.visible, "mobile movement and camera controls remain usable")
	touch(hud.move_center, false, 0)
	player.exit_vehicle()
	print("[ALL PC INPUT MENU GATES PASSED]" if failures.is_empty() else "[PC INPUT MENU GATES FAILED] " + str(failures))
	get_tree().quit(0 if failures.is_empty() else 1)
