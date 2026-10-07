extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _fail(message: String) -> void:
	failures.append(message)
	print("[FAIL] ", message)

func _pass(message: String) -> void:
	print("[PASS] ", message)

func _run() -> void:
	var packed := load("res://scenes/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn failed to load")
		_finish()
		return

	var world := packed.instantiate()
	root.add_child(world)

	for i in range(36):
		await physics_frame

	var player := world.get_node_or_null("Player") as CharacterBody3D
	var luca := world.get_node_or_null("Luca") as CharacterBody3D
	var hud := world.get_node_or_null("SandboxHUD") as CanvasLayer

	if player == null:
		_fail("player missing")
	if luca == null:
		_fail("Luca missing")
	if hud == null:
		_fail("HUD missing")
	if not failures.is_empty():
		_finish()
		return

	if player.is_on_floor():
		_pass("player settles onto continuous ground")
	else:
		_fail("player never reached floor")

	var hud_root = hud.get("root") as Control
	var viewport_size: Vector2 = hud_root.size
	if viewport_size.x <= 1.0:
		viewport_size = Vector2(1280.0, 720.0)

	var right_look := Vector2(viewport_size.x * 0.68, viewport_size.y * 0.46)
	var left_look := Vector2(viewport_size.x * 0.32, viewport_size.y * 0.46)
	if bool(hud.call("_point_in_look_zone", right_look)):
		_pass("right half accepts camera look")
	else:
		_fail("right half rejected camera look")

	if not bool(hud.call("_point_in_look_zone", left_look)):
		_pass("left half is reserved away from camera look")
	else:
		_fail("left half incorrectly accepts camera look")

	if not bool(hud.call("_touch_in_ui", right_look)):
		_pass("open right-side look area is not swallowed by UI")
	else:
		_fail("right-side look area still swallowed by UI")

	var start_y := player.global_position.y
	player.call("request_jump")
	for i in range(4):
		await physics_frame
	if player.global_position.y > start_y + 0.04 or player.velocity.y > 0.1:
		_pass("buffered jump produces upward movement")
	else:
		_fail("jump request did not move player upward")

	var horizontal_delta := luca.global_position - player.global_position
	horizontal_delta.y = 0.0
	if horizontal_delta.length() >= 4.5:
		_pass("Luca maintains personal-space radius")
	else:
		_fail("Luca entered personal-space radius")

	for eye_name in ["EyeWhite_L", "EyeWhite_R", "Pupil_L", "Pupil_R"]:
		if luca.get_node_or_null(eye_name) == null:
			_fail("Luca eye part missing: " + eye_name)
	if not failures.any(func(item: String): return item.begins_with("Luca eye part missing")):
		_pass("Luca has two eyes and two pupils")

	var road := world.get_node_or_null("MainRoadNS")
	var pad := world.get_node_or_null("SandboxPad")
	var skate := world.get_node_or_null("SkateFloor")
	if road is MeshInstance3D and pad is MeshInstance3D and skate is MeshInstance3D:
		_pass("roads/pad/skate floor are visual skins, not collision curbs")
	else:
		_fail("one or more flat surfaces still create collision curbs")

	var north := world.get_node_or_null("NorthBoundary")
	if north is StaticBody3D and north.get_child_count() == 1 and north.get_child(0) is CollisionShape3D:
		_pass("outer boundary is collision-only and visually hidden")
	else:
		_fail("outer boundary still has visible wall geometry")

	var fail_safe_ground := world.get_node_or_null("WorldGround")
	if (
		fail_safe_ground is StaticBody3D
		and fail_safe_ground.get_child_count() == 1
		and fail_safe_ground.get_child(0) is CollisionShape3D
	):
		_pass("legacy flat WorldGround is collision-only")
	else:
		_fail("legacy flat WorldGround still renders or changed shape")

	var macro := world.get_node_or_null("MacroTerrain")
	if macro == null:
		_fail("continuous terrain missing")
	else:
		var north_peak := maxf(
			float(macro.call("height_at", -150.0, -372.0)),
			float(macro.call("height_at", 150.0, -354.0))
		)
		var north_pass := float(macro.call("height_at", 0.0, -360.0))
		var south_wall := maxf(
			float(macro.call("height_at", -170.0, 390.0)),
			float(macro.call("height_at", 170.0, 390.0))
		)
		var south_floor := float(macro.call("height_at", 0.0, 390.0))
		if north_peak >= 16.0 and north_peak - north_pass >= 14.0:
			_pass("north mountain pass has visible elevation relief")
		else:
			_fail("north mountain relief too flat: peak=%s pass=%s" % [north_peak, north_pass])
		if south_wall >= 15.0 and south_wall - south_floor >= 12.0:
			_pass("south valley has measurable wall-to-floor relief")
		else:
			_fail("south valley relief too flat: wall=%s floor=%s" % [south_wall, south_floor])

		var shoulder_heights: Array[float] = []
		for x in [18.0, 30.0, 42.0, 54.0, 66.0, 78.0, 90.0]:
			shoulder_heights.append(float(macro.call("height_at", x, -360.0)))
		var max_step := 0.0
		for i in range(1, shoulder_heights.size()):
			max_step = maxf(max_step, absf(shoulder_heights[i] - shoulder_heights[i - 1]))
		if max_step <= 9.5:
			_pass("mountain road shoulder rises without cliff steps")
		else:
			_fail("mountain shoulder still cliffs between samples: " + str(max_step))

		var terrain_bodies := get_nodes_in_group("macro_terrain")
		var collision_ready := terrain_bodies.size() == 1
		if collision_ready:
			var terrain_body = terrain_bodies[0]
			collision_ready = (
				terrain_body.name == "WorldTerrain"
				and terrain_body.get_node_or_null("TerrainMesh") is MeshInstance3D
				and terrain_body.get_node_or_null("TerrainCollision") is CollisionShape3D
			)
		if collision_ready:
			_pass("one continuous visible/collidable terrain owns the world surface")
		else:
			_fail("continuous terrain ownership contract failed")

	var egg_hunt := world.get_node_or_null("EggHunt")
	var eggs_before := get_nodes_in_group("easter_egg").size()
	if egg_hunt != null and int(egg_hunt.call("total_eggs")) == 24 and eggs_before == 24:
		_pass("twenty-four Easter eggs are physically present in the world")
		if bool(egg_hunt.call("collect_for_test", 0)):
			await process_frame
			if int(egg_hunt.call("found_eggs")) == 1 and get_nodes_in_group("easter_egg").size() == 23:
				_pass("Easter egg collection updates count and removes pickup")
			else:
				_fail("Easter egg collection state did not update")
		else:
			_fail("Easter egg test pickup could not be collected")
	else:
		_fail("Easter egg population contract failed: " + str(eggs_before))

	var before := get_nodes_in_group("sandbox_prop").size()
	world.call("spawn_from_menu", "crate")
	world.call("spawn_from_menu", "crate")
	world.call("spawn_from_menu", "crate")
	await process_frame

	var props := get_nodes_in_group("sandbox_prop")
	if props.size() >= before + 3:
		var newest: Array[Node3D] = []
		for node in props:
			if node is Node3D and str(node.name).begins_with("Prop_crate_"):
				newest.append(node)
		newest.sort_custom(func(a: Node3D, b: Node3D): return str(a.name) < str(b.name))
		if newest.size() >= 3:
			var a := newest[newest.size() - 3].global_position
			var b := newest[newest.size() - 2].global_position
			var c := newest[newest.size() - 1].global_position
			if a.distance_to(b) > 0.5 and b.distance_to(c) > 0.5 and a.distance_to(c) > 0.5:
				_pass("repeated spawns use separated positions")
			else:
				_fail("repeated spawns still overlap")
		else:
			_fail("spawned crates could not be identified")
	else:
		_fail("spawn menu did not create three props")

	# Companion smoothing: nearby follow motion must never teleport or snap-turn.
	var last_luca_pos := luca.global_position
	var last_luca_yaw := luca.rotation.y
	var max_luca_step := 0.0
	var max_luca_turn := 0.0
	player.global_position += Vector3(10.0, 0.0, 0.0)
	for i in range(40):
		await physics_frame
		max_luca_step = maxf(max_luca_step, luca.global_position.distance_to(last_luca_pos))
		max_luca_turn = maxf(max_luca_turn, absf(angle_difference(last_luca_yaw, luca.rotation.y)))
		last_luca_pos = luca.global_position
		last_luca_yaw = luca.rotation.y
	if max_luca_step < 0.30 and max_luca_turn < 0.20:
		_pass("Luca follow movement is acceleration/turn-rate bounded")
	else:
		_fail("Luca follow still snaps: step=%s turn=%s" % [max_luca_step, max_luca_turn])

	# No permanent 3D name plates should hover over actors/vehicles.
	# Physical world signage is allowed when explicitly tagged.
	var floating_labels: Array[Node] = []
	for label in world.find_children("*", "Label3D", true, false):
		if not label.is_in_group("world_sign"):
			floating_labels.append(label)
	if floating_labels.is_empty():
		_pass("world contains no unapproved persistent floating Label3D text")
	else:
		_fail("unapproved persistent floating Label3D text remains: " + str(floating_labels.size()))

	# Vehicle forward input must agree with the camera-facing -Z direction.
	var buggy := world.get_node_or_null("SandboxBuggy") as VehicleBody3D
	if buggy == null:
		_fail("initial buggy missing")
	else:
		var start_pos := buggy.global_position
		var expected_forward := -buggy.global_transform.basis.z
		buggy.call("set_driver_active", true)
		buggy.call("set_drive_input", Vector2(0.0, -1.0))
		for i in range(30):
			await physics_frame
		buggy.call("set_drive_input", Vector2.ZERO)
		var displacement := buggy.global_position - start_pos
		displacement.y = 0.0
		if displacement.dot(expected_forward) > 0.5:
			_pass("buggy forward input moves toward visual/driver forward")
		else:
			_fail("buggy forward input is reversed")

		var driver_cam := buggy.get_node_or_null("DriverCamera") as Camera3D
		var chase_arm := buggy.get_node_or_null("ChaseSpringArm") as SpringArm3D
		var chase_cam := buggy.get_node_or_null("ChaseSpringArm/ChaseCamera") as Camera3D
		var hood_cam := buggy.get_node_or_null("HoodCamera") as Camera3D
		var overhead_cam := buggy.get_node_or_null("OverheadCamera") as Camera3D
		if (
			driver_cam != null
			and chase_arm != null
			and chase_cam != null
			and hood_cam != null
			and overhead_cam != null
			and driver_cam.current
		):
			_pass("buggy driver camera activates with four-view rig present")
		else:
			_fail("buggy four-view camera rig missing or driver inactive")

		var mode := str(buggy.call("cycle_camera"))
		if mode == "CHASE" and chase_cam.current and chase_arm.spring_length >= 7.0:
			_pass("buggy switches to collision-safe chase camera")
		else:
			_fail("buggy chase camera switch/spring arm failed")
		var yaw_before := chase_arm.rotation_degrees.y
		buggy.call("add_camera_look", Vector2(80.0, 0.0))
		if absf(chase_arm.rotation_degrees.y - yaw_before) > 1.0:
			_pass("chase camera supports orbit look")
		else:
			_fail("chase camera orbit input did not move")
		mode = str(buggy.call("cycle_camera"))
		if mode == "HOOD" and hood_cam.current:
			_pass("buggy switches to hood camera")
		else:
			_fail("buggy hood camera switch failed")
		mode = str(buggy.call("cycle_camera"))
		if mode == "OVERHEAD" and overhead_cam.current:
			_pass("buggy switches to overhead camera")
		else:
			_fail("buggy overhead camera switch failed")
		buggy.call("set_driver_active", false)

		# Full player/HUD integration: walking camera -> driver -> chase -> hood -> overhead -> walking.
		var player_camera = player.get("camera") as Camera3D
		player.call("enter_vehicle", buggy)
		await process_frame
		var view_button = hud.get("view_button") as Button
		var mobile_ui := bool(hud.get("mobile_ui"))
		var view_visibility_ok: bool = view_button.visible if mobile_ui else not view_button.visible
		if player_camera != null and not player_camera.current and driver_cam.current and view_visibility_ok:
			_pass("entering buggy activates driver camera with platform-appropriate HUD")
		else:
			_fail("vehicle entry camera/HUD integration failed")
		player.call("toggle_vehicle_view")
		await process_frame
		if chase_cam.current and view_button.text == "VIEW: CHASE":
			_pass("vehicle VIEW control reaches chase camera")
		else:
			_fail("vehicle VIEW chase control failed")
		player.call("toggle_vehicle_view")
		await process_frame
		if hood_cam.current and view_button.text == "VIEW: HOOD":
			_pass("vehicle VIEW control reaches hood camera")
		else:
			_fail("vehicle VIEW hood control failed")
		player.call("toggle_vehicle_view")
		await process_frame
		if overhead_cam.current and view_button.text == "VIEW: OVERHEAD":
			_pass("vehicle VIEW control reaches overhead camera")
		else:
			_fail("vehicle VIEW overhead control failed")
		player.call("exit_vehicle")
		await process_frame
		if player_camera.current and not view_button.visible:
			_pass("vehicle exit restores walking camera and HUD")
		else:
			_fail("vehicle exit did not restore walking camera/HUD")

	# Reproduce the cyan-underworld failure from physical playtest screenshots.
	var recovery_xz := Vector2(player.global_position.x, player.global_position.z)
	player.global_position.y = -2.0
	player.velocity = Vector3.ZERO
	for _i in range(3):
		await physics_frame
	if (
		player.global_position.y > -0.75
		and Vector2(player.global_position.x, player.global_position.z).distance_to(recovery_xz) < 40.0
	):
		_pass("player recovers immediately from below-world camera state")
	else:
		_fail("player remained below terrain after forced underworld state: " + str(player.global_position))

	# HUD notifications are toasts, not permanent hovering messages.
	hud.call("flash", "toast regression", 0.08)
	hud.call("_process", 0.40)
	var status_label = hud.get("status_label") as Label
	if status_label != null and not status_label.visible:
		_pass("HUD toast expires instead of hovering forever")
	else:
		_fail("HUD toast still persists")

	_finish()

func _finish() -> void:
	if failures.is_empty():
		print("[ALL PLAYABILITY GATES PASSED]")
		quit(0)
	else:
		print("[PLAYABILITY FAILURES] ", failures.size())
		for item in failures:
			print(" - ", item)
		quit(1)
