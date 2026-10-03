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
