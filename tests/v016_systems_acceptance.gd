extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _pass(message: String) -> void:
	print("[PASS] ", message)

func _fail(message: String) -> void:
	failures.append(message)
	print("[FAIL] ", message)

func _run() -> void:
	ProjectSettings.set_setting("luca/session_map", "lucas_field")
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn missing")
		_finish()
		return

	var world := packed.instantiate()
	root.add_child(world)
	for _i in range(120):
		await physics_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var luca := world.get_node_or_null("Luca") as CharacterBody3D
	var buggy := world.get_node_or_null("SandboxBuggy") as VehicleBody3D
	var registry := world.get_node_or_null("ContentRegistry")
	var terrain_slice := world.get_node_or_null("V013TerrainSlice")

	if player == null or luca == null or buggy == null or registry == null or terrain_slice == null:
		_fail("required v0.16 runtime nodes missing")
		_finish()
		return

	if bool(registry.call("is_valid")):
		_pass("content registry validates at runtime")
	else:
		_fail("content registry invalid at runtime")

	var tool_ids: Array = registry.call("get_tool_ids")
	var map_options: Array = registry.call("get_map_options")
	if tool_ids.has("field_hammer") and tool_ids.size() >= 8:
		_pass("catalog-driven tool belt includes field hammer")
	else:
		_fail("field hammer/tool catalog missing")
	if map_options.size() == 3:
		_pass("three map profiles are runtime-selectable")
	else:
		_fail("map profile count mismatch: " + str(map_options.size()))

	# Luca must not orbit merely because the player's/camera yaw changes.
	var anchor_before := Vector3(luca.call("get_follow_anchor_for_test"))
	var player_pos_before := player.global_position
	for i in range(24):
		player.rotation.y = float(i) / 24.0 * TAU
		await physics_frame
	var anchor_after_rotation := Vector3(luca.call("get_follow_anchor_for_test"))
	if (
		player.global_position.distance_to(player_pos_before) < 0.05
		and anchor_before.distance_to(anchor_after_rotation) < 0.08
	):
		_pass("Luca formation anchor ignores camera-only rotation")
	else:
		_fail(
			"Luca anchor still orbits on yaw: player_delta=%s anchor_delta=%s"
			% [
				player.global_position.distance_to(player_pos_before),
				anchor_before.distance_to(anchor_after_rotation),
			]
		)

	player.global_position += Vector3(6.0, 0.0, 0.0)
	for _i in range(8):
		await physics_frame
	var anchor_after_move := Vector3(luca.call("get_follow_anchor_for_test"))
	if anchor_after_move.distance_to(anchor_after_rotation) > 3.0:
		_pass("Luca formation anchor updates after real translation")
	else:
		_fail("Luca anchor failed to respond to player translation")

	# Once the player is stationary, Luca must arrive and settle rather than orbiting
	# endlessly around an anchor.
	for _i in range(180):
		await physics_frame
	var settle_start := luca.global_position
	var settle_travel := 0.0
	var last_settle_pos := luca.global_position
	for _i in range(90):
		await physics_frame
		settle_travel += luca.global_position.distance_to(last_settle_pos)
		last_settle_pos = luca.global_position
	var final_anchor := Vector3(luca.call("get_follow_anchor_for_test"))
	var final_anchor_distance := Vector2(
		luca.global_position.x - final_anchor.x,
		luca.global_position.z - final_anchor.z
	).length()
	if settle_travel < 0.65 and final_anchor_distance < 1.75:
		_pass("Luca settles at formation instead of circling")
	else:
		_fail(
			"Luca still wanders/orbits while player is stationary travel=%s anchor_distance=%s start_delta=%s"
			% [
				settle_travel,
				final_anchor_distance,
				settle_start.distance_to(luca.global_position),
			]
		)

	# Spawn a stationary anatomical NPC directly in front of the player and hit it
	# through the actual catalog-driven hammer tool path.
	player.rotation = Vector3.ZERO
	var hammer_at := player.global_position + Vector3(0.0, 0.0, -3.0)
	hammer_at.y = 1.1
	world.call("_spawn_npc", hammer_at, "Hammer Dummy")
	await physics_frame
	var hammer_dummy := world.get_node_or_null("Hammer_Dummy") as CharacterBody3D
	if hammer_dummy == null:
		_fail("hammer dummy failed to spawn")
	else:
		hammer_dummy.set("target_direction", Vector3.ZERO)
		hammer_dummy.set("think_time", 999.0)
		var anatomy := hammer_dummy.get_node_or_null("Anatomy")
		var anatomy_ok := anatomy != null
		for part in [
			"Pelvis", "Torso", "Head",
			"UpperArm_L", "UpperArm_R",
			"Forearm_L", "Forearm_R",
			"Hand_L", "Hand_R",
			"Leg_L", "Leg_R",
			"Foot_L", "Foot_R"
		]:
			if anatomy == null or anatomy.get_node_or_null(part) == null:
				anatomy_ok = false
		if anatomy_ok:
			_pass("NPC runtime body has readable bilateral anatomy")
		else:
			_fail("NPC anatomical body parts missing")

		var player_tool_ids: Array = player.get("tool_ids")
		var hammer_index := player_tool_ids.find("field_hammer")
		if hammer_index >= 0:
			player.set("tool_index", hammer_index)
			player.call("_sync_tool_label")
			player.call("use_tool")
			await physics_frame
			var hp := float(hammer_dummy.call("get_health_for_test"))
			if is_equal_approx(hp, 75.0):
				_pass("field hammer deals catalog-defined 25 NPC damage")
			else:
				_fail("hammer damage pipeline expected 75 HP, got " + str(hp))
		else:
			_fail("player tool belt cannot select field hammer")

	# Vehicle must rest on wheel contacts, move by traction, and stop instead of
	# continuing the old scripted glide.
	var rest_speed := buggy.linear_velocity.length()
	var contacts := int(buggy.call("get_wheel_contact_count_for_test"))
	if contacts == 4 and rest_speed < 0.10:
		_pass("buggy rests on four wheel contacts without idle glide")
	else:
		_fail("buggy rest contract contacts=%d speed=%s" % [contacts, rest_speed])

	var start := buggy.global_position
	var expected_forward := -buggy.global_transform.basis.z
	expected_forward.y = 0.0
	expected_forward = expected_forward.normalized()
	buggy.call("set_driver_active", true)
	buggy.call("set_drive_input", Vector2(0.0, -1.0))
	for _i in range(120):
		await physics_frame
	var drive_displacement := buggy.global_position - start
	drive_displacement.y = 0.0
	var drive_speed := buggy.linear_velocity.length()
	buggy.call("set_drive_input", Vector2.ZERO)

	if drive_displacement.dot(expected_forward) > 7.0 and drive_speed > 6.0:
		_pass("buggy engine drives through wheel physics in visual-forward direction")
	else:
		_fail(
			"buggy traction/forward failed dot=%s speed=%s"
			% [drive_displacement.dot(expected_forward), drive_speed]
		)

	for _i in range(90):
		await physics_frame
	var coast_speed := buggy.linear_velocity.length()
	if coast_speed < 0.30 and int(buggy.call("get_wheel_contact_count_for_test")) >= 3:
		_pass("buggy coast braking kills the old ice-glide behavior")
	else:
		_fail("buggy keeps gliding after throttle release speed=" + str(coast_speed))

	# Actual rigid-body impact must route through NPC damage, not merely expose a
	# method that nothing calls.
	var impact_forward := -buggy.global_transform.basis.z
	impact_forward.y = 0.0
	impact_forward = impact_forward.normalized()
	var impact_at := buggy.global_position + impact_forward * 6.0
	impact_at.y = 1.1
	world.call("_spawn_npc", impact_at, "Impact Dummy")
	await physics_frame
	var impact_dummy := world.get_node_or_null("Impact_Dummy") as CharacterBody3D
	if impact_dummy == null:
		_fail("impact dummy failed to spawn")
	else:
		impact_dummy.set("target_direction", Vector3.ZERO)
		impact_dummy.set("think_time", 999.0)
		var hp_before := float(impact_dummy.call("get_health_for_test"))
		buggy.call("set_drive_input", Vector2(0.0, -1.0))
		for _i in range(100):
			await physics_frame
		buggy.call("set_drive_input", Vector2.ZERO)
		var hp_after := float(impact_dummy.call("get_health_for_test"))
		if hp_after < hp_before:
			_pass("buggy collision applies NPC impact damage")
		else:
			_fail("vehicle collision did not damage NPC")
	buggy.call("set_driver_active", false)

	# Map profile must change live world authority and persistence namespace.
	var first_persistence = terrain_slice.call("get_persistence_for_test")
	var first_save := str(first_persistence.get("save_path"))
	var first_height := float(world.get_node("MacroTerrain").call("height_at", 160.0, -360.0))

	ProjectSettings.set_setting("luca/session_map", "red_pine_highlands")
	var world2 := packed.instantiate()
	root.add_child(world2)
	for _i in range(50):
		await physics_frame
	var terrain2 := world2.get_node_or_null("V013TerrainSlice")
	var macro2 := world2.get_node_or_null("MacroTerrain")
	if (
		str(world2.call("get_active_map_id")) == "red_pine_highlands"
		and int(world2.get("world_seed")) == 7719
		and terrain2 != null
		and macro2 != null
	):
		var second_persistence = terrain2.call("get_persistence_for_test")
		var second_save := str(second_persistence.get("save_path"))
		var second_height := float(macro2.call("height_at", 160.0, -360.0))
		if first_save != second_save and "6060" in first_save and "7719" in second_save:
			_pass("map profiles use isolated seed-scoped persistence")
		else:
			_fail("map persistence namespaces collide: %s // %s" % [first_save, second_save])
		if absf(second_height - first_height) > 1.0:
			_pass("map profile changes generated terrain, not only HUD text")
		else:
			_fail("alternate map terrain is not materially different")
	else:
		_fail("red pine map did not become authoritative")

	ProjectSettings.set_setting("luca/session_map", "lucas_field")
	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL V016 SYSTEM GATES PASSED]")
		quit(0)
	else:
		print("[V016 SYSTEM FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
